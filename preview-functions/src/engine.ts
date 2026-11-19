import {createHash, randomUUID} from 'crypto';
import Stripe from 'stripe';
import {normalizeBillingEmail,maskBillingEmail} from './billing-contact';
import {assessPreviewCheckout,isPreviewIdentityConfirmed} from '../../functions/src/previewCheckoutPolicy';

export const SCOPE = 'hamcare-checkout-preview-task4';
export const PREVIEW_ORIGIN = 'https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
export class CheckoutError extends Error { constructor(public code: string) { super(code); } }
export const hash = (value: string): string => createHash('sha256').update(value).digest('hex');
export type RecordData = Record<string, any>;
export interface PreviewStore {
  read(subject: string): Promise<RecordData>;
  mutate<T>(subject: string, update: (state: RecordData) => {state: RecordData, result: T}): Promise<T>;
  reserveBudget(subject: string, day: string, attempt: string): Promise<void>;
}
export interface Identity { uid: string; emailVerified: boolean; email?: string; authBasis?: 'verified_email' | 'apple_provider'; }
export interface AppFacts { appAccountExists: boolean; billing: any; trial: any; nickname: string; maskedEmail: string; testDataSource?: 'app'|'preview_fixture'; }
export interface EngineDependencies {
  stripe: Stripe; store: PreviewStore; priceId: string; publishableKey: string;
  readFacts(uid: string): Promise<AppFacts>; now(): Date;
  /** Server-only verified contact lookup; never request-body email. */
  requireBillingContact?(identity:Identity):Promise<{email:string;source?:string}>;
  allowedWebhook?: {id:string;url:string;events:readonly string[]};
}
function fail(code: string): never { throw new CheckoutError(code); }
function testObject(value: {livemode?: boolean}): void { if (value.livemode !== false) fail('test_mode_required'); }
function customerId(value: string | {id: string} | null): string | null { return typeof value === 'string' ? value : value?.id || null; }
function assessmentKey(value: RecordData): string { return JSON.stringify([value.chargeTiming, value.trialEndSeconds || null]); }
export function createPreviewEngine(d: EngineDependencies) {
  if (!d.publishableKey.startsWith('pk_test_') || !d.priceId.startsWith('price_')) fail('test_configuration_invalid');
  async function facts(identity: Identity, planKey: unknown) {
    const app = await d.readFacts(identity.uid);
    const policy = assessPreviewCheckout({identity, appAccountExists: app.appAccountExists, billing: app.billing, trial: app.trial, planKey, now: d.now()});
    const endpoints = await d.stripe.webhookEndpoints.list({limit:100});
    const enabled=endpoints.data.filter(e=>e.status==='enabled');
    if (endpoints.has_more || (d.allowedWebhook
      ? enabled.length!==1 || enabled.some(e=>e.id!==d.allowedWebhook!.id || e.url!==d.allowedWebhook!.url || e.livemode!==false || e.api_version!=='2025-02-24.acacia' || JSON.stringify([...e.enabled_events].sort())!==JSON.stringify([...d.allowedWebhook!.events].sort()))
      : enabled.length!==0)) fail('test_webhook_unresolved');
    const price = await d.stripe.prices.retrieve(d.priceId);
    testObject(price);
    if (price.metadata.previewScope !== SCOPE) fail('price_mismatch');
    const product=typeof price.product==='string'?await d.stripe.products.retrieve(price.product):price.product;
    if (!product || ('deleted' in product && product.deleted)) fail('price_mismatch');
    testObject(product as Stripe.Product);
    if ((product as Stripe.Product).metadata.previewScope !== SCOPE) fail('price_mismatch');
    if (!price.active || price.type !== 'recurring' || price.currency !== 'jpy' || price.unit_amount !== 550 || price.recurring?.interval !== 'month' || price.recurring.interval_count !== 1 || price.tax_behavior !== 'inclusive') fail('price_mismatch');
    return {app, policy};
  }
  function ownCustomer(c: Stripe.Customer | Stripe.DeletedCustomer, subject: string): asserts c is Stripe.Customer {
    if ('deleted' in c && c.deleted) fail('customer_unresolved');
    testObject(c as Stripe.Customer);
    const value = c as Stripe.Customer;
    if (value.metadata.previewScope !== SCOPE || value.metadata.previewSubjectHash !== subject) fail('customer_unresolved');
    if (value.metadata.previewFirebaseUid && hash(value.metadata.previewFirebaseUid)!==subject) fail('customer_unresolved');
    if (value.balance !== 0 || value.discount) fail('price_mismatch');
  }
  async function noSubscription(customer: string) {
    const items = await d.stripe.subscriptions.list({customer, status:'all', limit:100});
    if (items.has_more) fail('subscription_unresolved');
    for (const sub of items.data) { testObject(sub); if (!['canceled','incomplete_expired'].includes(sub.status)) fail('already_subscribed'); }
  }
  async function knownCustomer(subject: string, stored: RecordData): Promise<Stripe.Customer | null> {
    if (!stored.customerId) return null;
    const c = await d.stripe.customers.retrieve(stored.customerId); ownCustomer(c, subject); return c;
  }
  async function getCustomer(identity: Identity, subject: string, billingEmail:string): Promise<Stripe.Customer> {
    const stored = await d.store.read(subject);
    if(stored.previewFirebaseUid && stored.previewFirebaseUid!==identity.uid) fail('customer_unresolved');
    const known = await knownCustomer(subject, stored);
    const matches = known ? {data:[known],has_more:false} : await d.stripe.customers.search({query:`metadata['previewScope']:'${SCOPE}' AND metadata['previewSubjectHash']:'${subject}'`,limit:2});
    if (matches.has_more || matches.data.length > 1) fail('customer_unresolved');
    let customer = known || matches.data[0];
    if (!customer) customer = await d.stripe.customers.create({email:billingEmail,metadata:{previewScope:SCOPE,previewSubjectHash:subject,previewFirebaseUid:identity.uid}}, {idempotencyKey:`${SCOPE}:customer:${subject}`});
    ownCustomer(customer,subject);
    // Only an Admin-verified owner may bind the previously hash-only Test Customer.
    if(!customer.metadata.previewFirebaseUid)customer=await d.stripe.customers.update(customer.id,{metadata:{...customer.metadata,previewFirebaseUid:identity.uid}});
    if(customer.metadata.previewFirebaseUid!==identity.uid)fail('customer_unresolved');
    await d.store.mutate(subject,s=>{if(s.previewFirebaseUid && s.previewFirebaseUid!==identity.uid)fail('customer_unresolved');return {state:{...s,customerId:customer.id,previewFirebaseUid:identity.uid},result:null};});
    return customer;
  }
  async function checkSession(session: Stripe.Checkout.Session, subject: string, expectedCustomer: string, attempt: RecordData) {
    testObject(session);
    if (session.customer !== expectedCustomer || session.metadata?.previewScope !== SCOPE || session.metadata?.previewSubjectHash !== subject || session.metadata?.previewAttempt !== attempt.id || session.mode !== 'subscription' || session.ui_mode !== 'embedded' || session.currency !== 'jpy' || session.automatic_tax?.enabled || (session.total_details?.amount_discount || 0) !== 0 || (session.total_details?.amount_tax || 0) !== 0) fail('price_mismatch');
    const lines = await d.stripe.checkout.sessions.listLineItems(session.id,{limit:2});
    if (lines.has_more || lines.data.length !== 1 || lines.data[0].quantity !== 1 || lines.data[0].price?.id !== d.priceId || lines.data[0].price?.unit_amount !== 550) fail('price_mismatch');
    const expectedTotal = attempt.trialEndSeconds ? 0 : 550;
    if (session.amount_total !== expectedTotal) fail('price_mismatch');
    if (session.status === 'complete') {
      const subscriptionId = customerId(session.subscription);
      if (!subscriptionId) fail('subscription_unresolved');
      const sub = await d.stripe.subscriptions.retrieve(subscriptionId);
      testObject(sub);
      if (sub.customer !== expectedCustomer || sub.metadata.previewScope !== SCOPE || sub.metadata.previewSubjectHash !== subject || sub.items.data.length !== 1 || sub.items.data[0].quantity !== 1 || sub.items.data[0].price.id !== d.priceId || sub.items.data[0].price.unit_amount !== 550 || sub.items.data[0].price.currency !== 'jpy' || sub.items.data[0].price.recurring?.interval !== 'month' || sub.items.data[0].price.tax_behavior !== 'inclusive' || sub.automatic_tax.enabled || sub.discount || sub.default_tax_rates?.length || (attempt.trialEndSeconds ? sub.trial_end !== attempt.trialEndSeconds : sub.trial_end !== null)) fail('price_mismatch');
    }
  }
  async function reconcilePending(subject:string,state:RecordData):Promise<RecordData> {
    const attempt=state.attempt; const now=d.now().getTime();
    if(attempt?.phase!=='creating' || attempt.sessionId || attempt.leaseUntil>now) return state;
    let customer=await knownCustomer(subject,state);
    if(!customer) {
      const found=await d.stripe.customers.search({query:`metadata['previewScope']:'${SCOPE}' AND metadata['previewSubjectHash']:'${subject}'`,limit:2});
      if(found.has_more || found.data.length>1) fail('customer_unresolved');
      if(found.data[0]) {ownCustomer(found.data[0],subject);customer=found.data[0];}
    }
    let match:Stripe.Checkout.Session|undefined;
    if(customer) {
      const history=await d.stripe.checkout.sessions.list({customer:customer.id,limit:100});
      if(history.has_more) fail('checkout_unresolved');
      const matches=history.data.filter(s=>s.metadata?.previewAttempt===attempt.id);
      if(matches.length>1) fail('checkout_unresolved');
      match=matches[0];
      if(match) await checkSession(match,subject,customer.id,attempt);
    }
    if(!match && attempt.expiresAt*1000>now) return state;
    const phase=match?match.status==='open'?'open':match.status==='complete'?'complete':'expired':'expired';
    return d.store.mutate(subject,s=>{
      if(s.attempt?.id!==attempt.id || s.attempt.phase!=='creating' || s.attempt.lease!==attempt.lease) fail('processing');
      const next={...s,...(customer?{customerId:customer.id}:{}),attempt:{...s.attempt,...(match?{sessionId:match.id}:{}),phase,leaseUntil:0}};
      return {state:next,result:next};
    });
  }
  async function sessionState(subject: string, state: RecordData) {
    if (!state.attempt?.sessionId) return {testMode:true,state:state.attempt?.phase === 'creating' ? 'processing' : ['expired','canceled'].includes(state.attempt?.phase) ? state.attempt.phase : 'none'};
    const session = await d.stripe.checkout.sessions.retrieve(state.attempt.sessionId);
    await checkSession(session, subject, state.customerId, state.attempt);
    if (session.status !== 'open' || session.expires_at * 1000 <= d.now().getTime()) {
      const phase = session.status === 'complete' ? 'complete' : state.attempt.phase === 'canceled' ? 'canceled' : 'expired';
      await d.store.mutate(subject,s=>{
        if(s.attempt?.id !== state.attempt.id || s.attempt?.sessionId !== state.attempt.sessionId) fail('processing');
        return {state:{...s,attempt:{...s.attempt,phase}},result:null};
      });
      return {testMode:true,state:phase,paymentStatus:session.payment_status};
    }
    return {testMode:true,state:'open',paymentStatus:session.payment_status};
  }
  async function verifiedContact(identity:Identity) {
    if(!identity||!isPreviewIdentityConfirmed(identity))fail('email_unverified');
    const result=d.requireBillingContact?await d.requireBillingContact(identity):identity.emailVerified===true?{email:identity.email}:null;
    const email=normalizeBillingEmail(result?.email);
    if(!email)fail('contact_verification_required');
    return {email};
  }
  return {
    async review(identity: Identity, planKey: unknown) {
      const contact=await verifiedContact(identity);
      const subject = hash(identity.uid); const {app,policy} = await facts(identity,planKey);
      const state = await d.store.read(subject); const c = await knownCustomer(subject,state); if (c) await noSubscription(c.id);
      const token = randomUUID(); const now = d.now();
      await d.store.mutate(subject,s=>{if(s.previewFirebaseUid && s.previewFirebaseUid!==identity.uid)fail('customer_unresolved');return {state:{...s,previewFirebaseUid:identity.uid,quote:{tokenHash:hash(token),expiresAt:now.getTime()+180000,policyKey:assessmentKey(policy)}},result:null};});
      const firstCharge = new Date(policy.firstChargeAtSeconds*1000).toISOString();
      return {testMode:true,testDataSource:app.testDataSource||'app',planKey:'premium_monthly',amount:550,currency:'jpy',interval:'month',reviewToken:token,account:{nickname:app.nickname,maskedEmail:maskBillingEmail(contact.email)},billing:{kind:policy.chargeTiming === 'trial_end' ? 'trial':'immediate',cardRegistrationAt:now.toISOString(),firstChargeAt:firstCharge,firstChargeAmount:550,trialEndsAt:policy.trialEndSeconds ? firstCharge:null}};
    },
    async create(identity: Identity, body: RecordData) {
      if (body.termsAccepted !== true || typeof body.reviewToken !== 'string') fail('confirmation_required');
      const contact=await verifiedContact(identity);
      const subject=hash(identity.uid); const {policy}=await facts(identity,body.planKey); const now=d.now().getTime(); const lease=randomUUID();
      const reserved=await d.store.mutate(subject,s=>{
        if (!s.quote || s.quote.tokenHash !== hash(body.reviewToken) || s.quote.expiresAt <= now || s.quote.policyKey !== assessmentKey(policy)) fail('review_expired');
        if (s.attempt?.phase === 'creating' && s.attempt.leaseUntil > now) fail('processing');
        if (s.attempt?.phase === 'open') return {state:s,result:{existing:true,attempt:s.attempt}};
        const attempt=s.attempt?.phase === 'creating' ? {...s.attempt,lease,leaseUntil:now+120000} : {id:randomUUID(),phase:'creating',lease,leaseUntil:now+120000,createdAt:now,expiresAt:Math.floor(now/1000)+1860,trialEndSeconds:policy.trialEndSeconds || null,confirmedAt:now};
        return {state:{...s,attempt},result:{existing:false,attempt}};
      });
      const attempt=reserved.attempt;
      const customer=await getCustomer(identity,subject,contact.email);
      if (reserved.existing) {
        const session=await d.stripe.checkout.sessions.retrieve(attempt.sessionId);
        await checkSession(session,subject,customer.id,attempt);
        if (session.status !== 'open' || session.expires_at*1000 <= now) { await sessionState(subject,await d.store.read(subject)); fail(session.status === 'complete' ? 'already_subscribed':'session_expired'); }
        await noSubscription(customer.id);
        return {testMode:true,publishableKey:d.publishableKey,clientSecret:session.client_secret};
      }
      if (attempt.expiresAt <= Math.floor(now/1000)+1800) {
        const history=await d.stripe.checkout.sessions.list({customer:customer.id,limit:100});
        if(history.has_more) fail('checkout_unresolved');
        const matches=history.data.filter(s=>s.metadata?.previewAttempt===attempt.id);
        if(matches.length>1) fail('checkout_unresolved');
        if(matches.length===1) {
          const recovered=matches[0]; await checkSession(recovered,subject,customer.id,attempt);
          // A concurrent status/cancel or renewed lease wins over this older Stripe snapshot.
          await d.store.mutate(subject,s=>{if(s.attempt?.id!==attempt.id || s.attempt.phase!=='creating' || s.attempt.lease!==lease)fail('processing');return {state:{...s,attempt:{...s.attempt,sessionId:recovered.id,phase:recovered.status==='open'?'open':recovered.status==='complete'?'complete':'expired',leaseUntil:0}},result:null};});
          if(recovered.status==='open' && recovered.expires_at*1000>now) { await noSubscription(customer.id); return {testMode:true,publishableKey:d.publishableKey,clientSecret:recovered.client_secret}; }
          fail(recovered.status==='complete'?'already_subscribed':'session_expired');
        }
        // Only a complete, bounded Stripe list plus a past 31-minute request
        // deadline can establish that this expired operation made no Session.
        if (attempt.expiresAt*1000 > now) fail('checkout_unresolved');
        await d.store.mutate(subject,s=>{if(s.attempt?.id!==attempt.id || s.attempt.phase!=='creating' || s.attempt.lease!==lease)fail('processing');return {state:{...s,attempt:{...s.attempt,phase:'expired',leaseUntil:0}},result:null};});
        fail('session_expired');
      }
      // An unresolved create keeps the same attempt and idempotency key; never
      // silently starts a second operation after a timeout or expired lease.
      await d.store.reserveBudget(subject,new Date(attempt.createdAt).toISOString().slice(0,10),attempt.id);
      await noSubscription(customer.id);
      const open=await d.stripe.checkout.sessions.list({customer:customer.id,status:'open',limit:100});
      if (open.has_more || open.data.some(s=>s.metadata?.previewAttempt !== attempt.id)) fail('checkout_unresolved');
      const metadata={previewScope:SCOPE,previewSubjectHash:subject,previewFirebaseUid:identity.uid,previewAttempt:attempt.id,previewPlan:'premium_monthly'};
      const session=await d.stripe.checkout.sessions.create({mode:'subscription',ui_mode:'embedded',locale:'ja',customer:customer.id,line_items:[{price:d.priceId,quantity:1}],payment_method_types:['card'],payment_method_collection:'always',automatic_tax:{enabled:false},allow_promotion_codes:false,expires_at:attempt.expiresAt,return_url:PREVIEW_ORIGIN+'/account/?checkout=return',redirect_on_completion:'if_required',metadata,subscription_data:{metadata,...(attempt.trialEndSeconds ? {trial_end:attempt.trialEndSeconds}: {})}}, {idempotencyKey:`${SCOPE}:session:${subject}:${attempt.id}`});
      await checkSession(session,subject,customer.id,attempt);
      await d.store.mutate(subject,s=>{
        if (s.attempt?.id !== attempt.id || s.attempt.phase !== 'creating' || s.attempt.lease !== lease) fail('processing');
        return {state:{...s,attempt:{...attempt,sessionId:session.id,phase:'open',leaseUntil:0}},result:null};
      });
      return {testMode:true,publishableKey:d.publishableKey,clientSecret:session.client_secret};
    },
    async status(identity: Identity) { const subject=hash(identity.uid); return sessionState(subject,await reconcilePending(subject,await d.store.read(subject))); },
    async cancel(identity: Identity) {
      const subject=hash(identity.uid); const state=await reconcilePending(subject,await d.store.read(subject));
      if (state.attempt?.phase === 'creating') fail('processing');
      if (!state.attempt?.sessionId) return {testMode:true,state:'canceled'};
      const current=await d.stripe.checkout.sessions.retrieve(state.attempt.sessionId);
      await checkSession(current,subject,state.customerId,state.attempt);
      if (current.status === 'complete') return sessionState(subject,state);
      if (current.status === 'open') {
        try { await d.stripe.checkout.sessions.expire(current.id); }
        catch { const latest=await d.stripe.checkout.sessions.retrieve(current.id); if(latest.status !== 'expired') return sessionState(subject,state); }
      }
      const after=await d.stripe.checkout.sessions.retrieve(current.id); testObject(after);
      if (after.status !== 'expired') fail('checkout_unresolved');
      await d.store.mutate(subject,s=>{if(s.attempt?.id !== state.attempt.id) fail('processing');return {state:{...s,quote:null,attempt:{...s.attempt,phase:'canceled'}},result:null};});
      return {testMode:true,state:'canceled'};
    },
  };
}
