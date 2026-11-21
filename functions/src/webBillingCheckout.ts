import {createHash, randomUUID} from 'crypto';
import Stripe from 'stripe';
import {assertLiveObject, parseWebBillingConfig, WebBillingConfig} from './webBillingConfig';
import {assessWebCheckout, isWebBillingIdentityConfirmed, maskBillingEmail, normalizeBillingEmail, validWebBillingUid,
  WebBillingIdentity, WebCheckoutDecision, WebCheckoutSourceDocument} from './webBillingShared';

export const WEB_BILLING_SCOPE = 'hamcare-web-live-v1';
export const WEB_BILLING_TERMS = 'hamcare-web-monthly-550-v1';
export const WEB_BILLING_CONTACT_PURPOSE = 'billing_contact_live';
export const WEB_BILLING_QUOTES_MS = 3 * 60 * 1000;
const LEASE_MS = 120000;
const SESSION_MS = 31 * 60 * 1000;
const IDEMPOTENCY_MS = 23 * 60 * 60 * 1000;
type Data = Record<string, any>;
export interface WebBillingCheckoutStore {
  read(uid: string): Promise<Data>;
  mutate<T>(uid: string, update: (state: Data) => {state: Data; result: T}): Promise<T>;
}
export interface WebBillingFacts {
  appAccountExists: boolean;
  billing: WebCheckoutSourceDocument;
  trial: WebCheckoutSourceDocument;
  nickname: string;
}
export interface WebBillingCheckoutDependencies {
  config: WebBillingConfig;
  stripe: Stripe;
  store: WebBillingCheckoutStore;
  readFacts(uid: string): Promise<WebBillingFacts>;
  /** Auth-verified/Apple Relay or independently verified production contact.
   * Never read this from the request body or the Preview contact namespace. */
  readContact(identity: WebBillingIdentity): Promise<string | null>;
  resolveCustomer(input: {uid: string; mode: 'create-if-missing'; email: string}): Promise<{customerId: string}>;
  now(): Date;
  randomToken?(): string;
}
export class WebBillingCheckoutError extends Error {
  constructor(readonly code: string) {
    super('現在お申し込みを受け付けていません。');
    this.name = 'WebBillingCheckoutError';
  }
}
function fail(code: string): never {throw new WebBillingCheckoutError(code);}
const object = (v: unknown): v is Data => !!v && typeof v === 'object' && !Array.isArray(v);
const hash = (v: string) => createHash('sha256').update(v).digest('hex');
const validId = (v: unknown, prefix: string): v is string => typeof v === 'string' && new RegExp('^'+prefix+'_[A-Za-z0-9_]{1,240}$').test(v);
const idOf = (v: any) => typeof v === 'string' ? v : v?.id;
const policyKey = (v: WebCheckoutDecision) => hash(JSON.stringify([v.planKey,v.unitAmount,v.chargeTiming,v.trialEndSeconds ?? null]));

/** Production orchestration. The fixed plan/trial/identity policies are shared
 * with Preview; this module owns only Live coordination and Live Stripe calls.
 * It has no capability for writing users/{uid}/billing/subscription. */
export function createWebBillingCheckout(d: WebBillingCheckoutDependencies) {
  const config = parseWebBillingConfig(d.config as unknown as Record<string, unknown>);
  const token = () => {
    const value = (d.randomToken ?? randomUUID)();
    if (!/^[A-Za-z0-9_-]{16,128}$/.test(value)) fail('token_invalid');
    return value;
  };
  const clock = () => {
    const n = d.now().getTime();
    if (!Number.isSafeInteger(n) || n <= 0) fail('clock_invalid');
    return n;
  };
  const state = (s: Data, uid: string): Data => {
    if (!object(s) || (s.firebaseUid !== undefined && s.firebaseUid !== uid)) fail('uid_mismatch');
    if ((s.quote || s.operation || s.lease) && s.firebaseUid !== uid) fail('uid_mismatch');
    return s;
  };
  function identity(i: WebBillingIdentity) {
    if (!i || !validWebBillingUid(i.uid) || !['verified_email','apple_provider'].includes(i.authBasis ?? '')) fail('unauthenticated');
    if (!isWebBillingIdentityConfirmed(i)) fail('email_unverified');
  }
  async function price() {
    const p = await d.stripe.prices.retrieve(config.priceId, {expand:['product']});
    assertLiveObject(p);
    if (p.id !== config.priceId || p.active !== true || p.unit_amount !== 550 || p.currency !== 'jpy' ||
      p.type !== 'recurring' || p.recurring?.interval !== 'month' || p.recurring.interval_count !== 1 ||
      p.tax_behavior !== 'inclusive' || p.recurring.usage_type !== 'licensed') fail('price_invalid');
    assertLiveObject(p.product);
    if (p.product.active !== true || p.product.deleted) fail('product_invalid');
  }
  async function assessment(i: WebBillingIdentity) {
    identity(i);
    const facts = await d.readFacts(i.uid);
    const decision = assessWebCheckout({identity:i,appAccountExists:facts.appAccountExists,
      billing:facts.billing,trial:facts.trial,planKey:'premium_monthly',now:new Date(clock())});
    const email = normalizeBillingEmail(await d.readContact(i));
    if (!email) fail('contact_required');
    return {facts,decision,email};
  }
  async function customerReady(uid: string, customerId: string) {
    if (!validId(customerId,'cus')) fail('customer_invalid');
    const c = await d.stripe.customers.retrieve(customerId);
    assertLiveObject(c);
    if (c.id !== customerId || c.deleted || c.metadata?.firebaseUid !== uid || c.balance !== 0 || c.discount ||
        (Array.isArray(c.discounts) && c.discounts.length)) fail('customer_invalid');
    const list = await d.stripe.subscriptions.list({customer:customerId,status:'all',limit:100});
    if (list.has_more !== false || !Array.isArray(list.data)) fail('subscription_unresolved');
    for (const sub of list.data) {
      assertLiveObject(sub);
      if (idOf(sub.customer) !== customerId || (sub.metadata?.firebaseUid && sub.metadata.firebaseUid !== uid)) fail('uid_mismatch');
      if (!['canceled','incomplete_expired'].includes(sub.status)) fail('existing_subscription');
    }
  }
  function operation(s: Data, uid: string): Data {
    state(s,uid);
    const op = s.operation;
    if (!object(op) || !/^[A-Za-z0-9_-]{16,128}$/.test(op.id) || !validId(op.customerId,'cus') ||
      !Number.isSafeInteger(op.startedAt) || !Number.isSafeInteger(op.expiresAt) || op.expiresAt !== op.startedAt+SESSION_MS ||
      !/^[a-f0-9]{64}$/.test(op.policyKey) || !/^[a-f0-9]{64}$/.test(op.contactHash) ||
      !object(op.decision) || policyKey(op.decision as WebCheckoutDecision) !== op.policyKey) fail('operation_invalid');
    return op;
  }
  async function session(uid: string, op: Data, sessionId: string) {
    if (!validId(sessionId,'cs')) fail('session_invalid');
    const s = await d.stripe.checkout.sessions.retrieve(sessionId, {expand:['line_items.data.price','subscription']});
    assertLiveObject(s);
    const rows = s.line_items;
    if (s.id !== sessionId || s.mode !== 'subscription' || s.ui_mode !== 'embedded' ||
      s.return_url !== config.origin+'/billing/success/' || idOf(s.customer) !== op.customerId ||
      s.client_reference_id !== uid || s.metadata?.firebaseUid !== uid || s.metadata?.webBillingScope !== WEB_BILLING_SCOPE ||
      s.metadata?.webBillingAttempt !== op.id || !rows || rows.has_more !== false || rows.data.length !== 1 ||
      rows.data[0].quantity !== 1 || idOf(rows.data[0].price) !== config.priceId || s.currency !== 'jpy' ||
      s.amount_total !== (op.decision.chargeTiming==='trial_end'?0:550) ||
      s.automatic_tax?.enabled !== false || s.allow_promotion_codes === true ||
      (s.total_details?.amount_discount ?? 0) !== 0 || (s.total_details?.amount_tax ?? 0) !== 0 ||
      !['open','complete','expired'].includes(s.status ?? '')) fail('session_invalid');
    assertLiveObject(rows.data[0].price);
    const linePrice = rows.data[0].price;
    if (linePrice.unit_amount !== 550 || linePrice.currency !== 'jpy' || linePrice.type !== 'recurring' ||
        linePrice.recurring?.interval !== 'month' || linePrice.recurring.interval_count !== 1 ||
        linePrice.recurring.usage_type !== 'licensed' || linePrice.tax_behavior !== 'inclusive') fail('price_invalid');
    if (s.status === 'complete' && !s.subscription) fail('subscription_invalid');
    if (s.subscription) {
      assertLiveObject(s.subscription);
      const sub = s.subscription;
      if (idOf(sub.customer) !== op.customerId || sub.metadata?.firebaseUid !== uid ||
          sub.metadata?.webBillingScope !== WEB_BILLING_SCOPE || sub.metadata?.webBillingAttempt !== op.id ||
          sub.trial_end !== (op.decision.trialEndSeconds ?? null) || sub.automatic_tax?.enabled !== false ||
          sub.discount || sub.discounts?.length || sub.default_tax_rates?.length ||
          (sub.billing_mode !== undefined && sub.billing_mode !== null && sub.billing_mode.type !== 'classic') ||
          !Array.isArray(sub.items?.data) || sub.items.has_more !== false || sub.items.data.length !== 1 ||
          sub.items.data[0].quantity !== 1 || idOf(sub.items.data[0].price) !== config.priceId) fail('subscription_invalid');
      assertLiveObject(sub.items.data[0].price);
      const p = sub.items.data[0].price;
      if (p.unit_amount !== 550 || p.currency !== 'jpy' || p.type !== 'recurring' ||
          p.recurring?.interval !== 'month' || p.recurring.interval_count !== 1 || p.tax_behavior !== 'inclusive') fail('price_invalid');
      if (s.status === 'complete') {
        const invoiceId = idOf(sub.latest_invoice);
        if (!validId(invoiceId,'in')) fail('invoice_invalid');
        const invoice = await d.stripe.invoices.retrieve(invoiceId);
        assertLiveObject(invoice);
        const invoiceSubscription = idOf(invoice.subscription) ?? idOf(invoice.parent?.subscription_details?.subscription);
        const expected = op.decision.chargeTiming==='trial_end' && invoice.billing_reason==='subscription_create' ? 0 : 550;
        if (invoice.id !== invoiceId || idOf(invoice.customer) !== op.customerId || invoiceSubscription !== sub.id ||
            invoice.currency !== 'jpy' || invoice.total !== expected || invoice.amount_due !== expected ||
            !Number.isSafeInteger(invoice.amount_paid) || invoice.amount_paid < 0 ||
            (invoice.status === 'paid' && invoice.amount_paid !== expected) || invoice.amount_paid > expected ||
            invoice.total_discount_amounts?.some((v: Data)=>v.amount !== 0) || invoice.default_tax_rates?.length ||
            invoice.automatic_tax?.enabled === true || invoice.total_tax_amounts?.some((v: Data)=>v.amount !== 0)) fail('invoice_invalid');
      }
    }
    return s;
  }
  function response(s: Stripe.Checkout.Session) {
    if (s.status !== 'open' || typeof s.client_secret !== 'string' || !s.client_secret.startsWith(s.id+'_secret_')) fail('checkout_not_open');
    return {clientSecret:s.client_secret,publishableKey:config.publishableKey};
  }
  async function review(i: WebBillingIdentity, input: {planKey: unknown}) {
    if (!object(input) || Object.keys(input).some(k=>k!=='planKey') || input.planKey !== 'premium_monthly') fail('plan_not_allowed');
    const {facts,decision,email} = await assessment(i);
    await price();
    const raw = token(), expiresAt = clock()+WEB_BILLING_QUOTES_MS;
    await d.store.mutate(i.uid,s=>({state:{...state(s,i.uid),firebaseUid:i.uid,
      quote:{hash:hash(raw),expiresAt,policyKey:policyKey(decision),contactHash:hash(email),termsVersion:WEB_BILLING_TERMS}},result:null}));
    return {reviewToken:raw,expiresAt:new Date(expiresAt).toISOString(),termsVersion:WEB_BILLING_TERMS,
      planKey:'premium_monthly',unitAmount:550,currency:'jpy',interval:'month',
      chargeTiming:decision.chargeTiming,firstChargeAtSeconds:decision.firstChargeAtSeconds,
      nickname:facts.nickname,maskedEmail:maskBillingEmail(email)};
  }
  async function create(i: WebBillingIdentity, input: {planKey:unknown;reviewToken:unknown;termsAccepted:unknown;termsVersion:unknown}) {
    if (!object(input) || Object.keys(input).some(k=>!['planKey','reviewToken','termsAccepted','termsVersion'].includes(k)) ||
      input.planKey !== 'premium_monthly' || typeof input.reviewToken !== 'string' || !/^[A-Za-z0-9_-]{16,128}$/.test(input.reviewToken) ||
      input.termsAccepted !== true || input.termsVersion !== WEB_BILLING_TERMS) fail('confirmation_required');
    const {decision,email} = await assessment(i);
    await price();
    const validateQuote = (s: Data) => {
      state(s,i.uid);
      if (!object(s.quote) || s.quote.hash !== hash(input.reviewToken as string) ||
        !Number.isSafeInteger(s.quote.expiresAt) || s.quote.expiresAt <= clock() ||
        s.quote.policyKey !== policyKey(decision) || s.quote.contactHash !== hash(email) || s.quote.termsVersion !== WEB_BILLING_TERMS) fail('review_expired');
    };
    validateQuote(await d.store.read(i.uid));
    const {customerId} = await d.resolveCustomer({uid:i.uid,mode:'create-if-missing',email});
    await customerReady(i.uid,customerId);
    const lease = token(), time = clock(), attempt = token();
    const op = await d.store.mutate(i.uid,s=>{
      validateQuote(s);
      if (s.lease?.until > time) fail('checkout_busy');
      const old = s.operation ? operation(s,i.uid) : null;
      if (old && (old.customerId !== customerId || old.policyKey !== policyKey(decision) || old.contactHash !== hash(email))) fail('checkout_unresolved');
      const current = old ?? {id:attempt,customerId,startedAt:time,expiresAt:time+SESSION_MS,
        decision,policyKey:policyKey(decision),contactHash:hash(email)};
      return {state:{...s,operation:current,lease:{token:lease,until:time+LEASE_MS}},result:current};
    });
    try {
      // Unknown outcomes reuse exactly the original attempt. Stripe may prune
      // idempotency keys after 24h; an unresolved old operation is never retried
      // as a fresh creation. An operator must reconcile it first.
      let sessionId = op.sessionId;
      if (!sessionId) {
        const found = await d.stripe.checkout.sessions.list({customer:customerId,limit:100});
        if (found.has_more !== false || !Array.isArray(found.data)) fail('session_unresolved');
        const matches = found.data.filter(s=>s.metadata?.webBillingScope===WEB_BILLING_SCOPE && s.metadata?.webBillingAttempt===op.id);
        if (matches.length > 1) fail('session_unresolved');
        if (matches.length) sessionId = matches[0].id;
        else if (clock() >= op.expiresAt || clock()-op.startedAt >= IDEMPOTENCY_MS) fail('session_unresolved');
      }
      if (!sessionId) {
        // Re-read every authority after Customer resolution and recovery work.
        // A contact change, new contract or expiring original trial invalidates
        // this quote without resetting its existing operation or trial end.
        const fresh = await assessment(i);
        if (policyKey(fresh.decision) !== op.policyKey || hash(fresh.email) !== op.contactHash) fail('review_expired');
        await price();
        await customerReady(i.uid,customerId);
        const latest = await d.store.read(i.uid), createTime = clock();
        validateQuote(latest);
        if (latest.lease?.token !== lease || latest.lease.until <= createTime || operation(latest,i.uid).id !== op.id ||
            createTime >= op.expiresAt || createTime-op.startedAt >= IDEMPOTENCY_MS) fail('checkout_unresolved');
        const metadata = {firebaseUid:i.uid,webBillingScope:WEB_BILLING_SCOPE,webBillingAttempt:op.id};
        const created = await d.stripe.checkout.sessions.create({ui_mode:'embedded',mode:'subscription',locale:'ja',
          customer:customerId,client_reference_id:i.uid,line_items:[{price:config.priceId,quantity:1}],
          payment_method_types:['card'],allow_promotion_codes:false,automatic_tax:{enabled:false},
          return_url:config.origin+'/billing/success/',expires_at:Math.floor(op.expiresAt/1000),metadata,
          subscription_data:{metadata,...(op.decision.trialEndSeconds ? {trial_end:op.decision.trialEndSeconds}: {})}},
          {idempotencyKey:WEB_BILLING_SCOPE+':checkout:'+hash(i.uid)+':'+op.id});
        assertLiveObject(created);
        sessionId = created.id;
      }
      const canonical = await session(i.uid,op,sessionId);
      await d.store.mutate(i.uid,s=>{
        const saved = operation(s,i.uid);
        if (s.lease?.token !== lease || saved.id !== op.id) fail('checkout_busy');
        const next: Data = {...s,operation:{...saved,sessionId}}; delete next.lease;
        return {state:next,result:null};
      });
      return response(canonical);
    } finally {
      // Keep the original operation on every failure, including network
      // timeout; releasing the local lease does not authorize a new attempt.
      await d.store.mutate(i.uid,s=>{
        if (s.lease?.token !== lease) return {state:s,result:null};
        const next = {...s}; delete next.lease; return {state:next,result:null};
      });
    }
  }
  async function status(i: WebBillingIdentity) {
    identity(i);
    const op = operation(await d.store.read(i.uid),i.uid);
    const s = await session(i.uid,op,op.sessionId);
    const {billing} = await d.readFacts(i.uid);
    const b = billing.kind === 'found' && object(billing.data) ? billing.data : null;
    const reflected = s.status==='complete' && b?.stripeLivemode===true && b.firebaseUid===i.uid &&
      b.stripeCustomerId===op.customerId && b.stripeSubscriptionId===idOf(s.subscription) && ['active','trialing'].includes(b.status);
    return {checkoutStatus:s.status,billingState:reflected?'confirmed':'pending'};
  }
  async function cancel(i: WebBillingIdentity) {
    identity(i);
    const saved = await d.store.read(i.uid), op = operation(saved,i.uid);
    if (saved.lease?.until > clock()) fail('checkout_busy');
    let s = await session(i.uid,op,op.sessionId);
    if (s.status==='open') {
      await d.stripe.checkout.sessions.expire(s.id,{}, {idempotencyKey:WEB_BILLING_SCOPE+':expire:'+op.id});
      s = await session(i.uid,op,s.id);
    }
    if (s.status!=='expired') fail('checkout_completed');
    await customerReady(i.uid,op.customerId);
    await d.store.mutate(i.uid,current=>{
      if (current.lease?.until>clock() || operation(current,i.uid).id!==op.id) fail('checkout_busy');
      const next = {...current}; delete next.operation; delete next.quote;
      return {state:next,result:null};
    });
    return {checkoutStatus:'expired'};
  }
  return {review,create,status,cancel};
}
