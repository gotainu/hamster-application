import {createHash, randomUUID} from 'node:crypto';
import Stripe from 'stripe';
import {selectPreferredPaidSubscription} from './stripeSubscriptionPriority';
import {parseWebBillingConfig, WebBillingConfig} from './webBillingConfig';

export const WEB_BILLING_EVENT_TYPES = [
  'checkout.session.completed', 'customer.subscription.created',
  'customer.subscription.updated', 'customer.subscription.deleted',
  'invoice.paid', 'invoice.payment_failed',
  // The existing Live endpoint also receives this success alias. Apply the
  // same canonical guards and invoice-based hook deduplication as invoice.paid.
  'invoice.payment_succeeded',
] as const;
export class WebBillingWebhookError extends Error {
  constructor(public readonly code: string, public readonly retryable = false) {
    super('Billing synchronization could not complete.');
    this.name = 'WebBillingWebhookError';
  }
}
type Data = Record<string, any>;
export interface WebBillingSubject {
  mapping: {firebaseUid?: string; customerId?: string; stripeLivemode?: boolean} | null;
  billing: Data | null;
  /** Opaque database update versions; commit must compare both under lease. */
  mappingVersion: string | null;
  billingVersion: string | null;
  deletionRequested?: boolean;
}
export interface WebBillingWebhookFacts {
  appAccountExists: boolean;
  trial?: {kind: 'found' | 'missing' | 'denied' | 'unavailable'; data?: unknown};
}
export interface WebBillingWebhookDependencies {
  stripe: Stripe; store: WebBillingWebhookStore; config: WebBillingConfig;
  now(): Date; readFacts?(uid: string): Promise<WebBillingWebhookFacts>;
}
export interface WebBillingEventMeta {eventType: string; createdSeconds: number; version: 1;}
export interface WebBillingSubscription {
  provider: 'stripe'; stripeLivemode: true; billingSyncVersion: 1;
  firebaseUid: string; stripeCustomerId: string; stripeSubscriptionId: string;
  stripePriceId: string; stripeProductId: string; legacyPrice: boolean;
  plan: 'paid' | 'none'; status: string; planKey: 'premium_monthly';
  amount: 550 | 500; currency: 'jpy'; interval: 'month';
  currentPeriodStartSeconds: number | null; currentPeriodEndSeconds: number | null;
  cancelAtPeriodEnd: boolean; cancelAtSeconds: number | null; canceledAtSeconds: number | null;
  trialStartSeconds: number | null; trialEndSeconds: number | null;
  firstChargeAtSeconds: number | null; nextChargeAtSeconds: number | null;
  latestInvoiceId: string | null; latestInvoiceStatus: string | null;
  latestInvoicePaymentStatus: 'paid' | 'unpaid' | 'no_payment_required' | 'unknown';
  latestInvoicePaidAtSeconds: number | null; latestInvoiceTotal: number | null;
  latestInvoiceAmountDue: number | null; latestInvoiceAmountPaid: number | null;
  checkoutSessionId: string | null; sourceEventType: string;
  sourceEventCreatedSeconds: number; stripeObservedAtMillis: number; syncedAtMillis: number;
}
export type WebBillingHookType = 'contract_started' | 'trial_started' | 'first_charge' |
  'renewal' | 'payment_failed' | 'cancel_reserved' | 'resumed' | 'canceled';
export interface WebBillingHook {
  id: string; transitionKey: string; type: WebBillingHookType;
  firebaseUid: string; subscriptionId: string; invoiceId: string | null;
  eventHash: string; status: 'pending'; createdAtMillis: number;
}
export interface WebBillingCommit {
  uid: string; eventHash: string; lease: string; nowMs: number;
  before: WebBillingSubject; billing: WebBillingSubscription; hooks: WebBillingHook[];
  eventRecord: WebBillingEventMeta & {processedAtMillis: number; subscriptionHash: string;};
}
export interface WebBillingWebhookStore {
  claimEvent(eventHash: string, lease: string, nowMs: number, untilMs: number, meta: WebBillingEventMeta): Promise<'claimed' | 'processed' | 'busy'>;
  readSubject(uid: string): Promise<WebBillingSubject>;
  claimSubject(uid: string, lease: string, nowMs: number, untilMs: number): Promise<boolean>;
  /** ACK a valid event without recreating billing after a deletion fence. */
  ignoreDeletedSubject?(input: {uid:string;eventHash:string;lease:string;nowMs:number}): Promise<void>;
  /** Atomically recheck leases, stored UID mapping and both snapshot versions;
   * write the normalized billing, pending hooks and processed receipt together. */
  commit(input: WebBillingCommit): Promise<void | 'ignored'>;
  release(input: {uid?: string; eventHash: string; lease: string; errorCode: string}): Promise<void>;
}
const digest = (value: string) => createHash('sha256').update(value).digest('hex');
const LEASE_MS = 120000;
const record = (v: unknown): v is Data => !!v && typeof v === 'object' && !Array.isArray(v);
function fail(code: string, retryable = false): never {throw new WebBillingWebhookError(code, retryable);}
function reference(v: unknown, prefix: string): string {
  const value = typeof v === 'string' ? v : record(v) ? v.id : null;
  if (typeof value !== 'string' || !new RegExp('^' + prefix + '_[A-Za-z0-9_]{1,240}$').test(value)) fail('reference_invalid');
  return value;
}
function live(v: unknown): asserts v is Data {if (!record(v) || v.livemode !== true) fail('live_mode_required');}
function seconds(v: unknown): number | null {return typeof v === 'number' && Number.isSafeInteger(v) && v > 0 ? v : null;}
function uidOf(v: unknown): string {
  if (!record(v) || typeof v.firebaseUid !== 'string' || v.firebaseUid.length > 128 || !/^[^/\s\u0000-\u001f\u007f]+$/u.test(v.firebaseUid)) fail('uid_binding_invalid');
  return v.firebaseUid;
}
function metadataMatches(metadata: unknown, uid: string, required: boolean): void {
  if (!record(metadata) || !metadata.firebaseUid) {if (required) fail('uid_binding_invalid'); return;}
  if (uidOf(metadata) !== uid) fail('uid_binding_mismatch');
}
function webMetadata(metadata: unknown, uid: string, legacy: boolean): string | null {
  metadataMatches(metadata, uid, !legacy);
  if (legacy) return null;
  if (!record(metadata) || metadata.webBillingScope !== 'hamcare-web-live-v1' ||
      typeof metadata.webBillingAttempt !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(metadata.webBillingAttempt)) fail('web_binding_invalid');
  return metadata.webBillingAttempt;
}
function storedBinding(state: WebBillingSubject, uid: string, customer: string): void {
  const m = state.mapping, b = state.billing;
  if (m && (m.firebaseUid !== uid || m.customerId !== customer || m.stripeLivemode === false)) fail('stored_binding_mismatch');
  if (b?.stripeCustomerId && (b.stripeCustomerId !== customer || b.stripeLivemode === false || (b.firebaseUid && b.firebaseUid !== uid))) fail('stored_binding_mismatch');
  if (!m && b?.stripeCustomerId !== customer) fail('stored_binding_missing');
}
function existingLegacy(state: WebBillingSubject, sub: Stripe.Subscription, legacyPriceId?: string): boolean {
  return !!legacyPriceId && state.billing?.stripeCustomerId === reference(sub.customer, 'cus') &&
    state.billing?.stripeSubscriptionId === sub.id && state.billing?.stripePriceId === legacyPriceId &&
    state.billing?.stripeLivemode !== false;
}
function invoiceSubscription(invoice: unknown): string {
  const v = invoice as Data;
  return reference(v.subscription ?? v.parent?.subscription_details?.subscription, 'sub');
}
function status(value: string): string {
  if (value === 'incomplete_expired') return 'incomplete';
  if (value === 'paused') return 'unpaid';
  if (!['active', 'trialing', 'past_due', 'canceled', 'unpaid', 'incomplete'].includes(value)) fail('subscription_status_invalid');
  return value;
}
function millis(d: WebBillingWebhookDependencies): number {
  const value = d.now().getTime();
  if (!Number.isSafeInteger(value) || value <= 0) fail('clock_invalid', true);
  return value;
}
/** Only raw bytes may be verified. SDK errors, payloads and secrets are never
 * included in the public error. Unsupported signed Live events can be ignored. */
export function verifyWebBillingEvent(stripe: Stripe, raw: Buffer, signature: unknown, secret: string, now: () => Date = () => new Date()): Stripe.Event {
  if (!Buffer.isBuffer(raw) || raw.length === 0 || raw.length > 262144 || typeof signature !== 'string' ||
      signature.length === 0 || signature.length > 4096 || !/^whsec_[A-Za-z0-9_]+$/.test(secret)) fail('signature_invalid');
  const receivedAt = now().getTime();
  const time = signature.match(/(?:^|,)t=(\d+)(?:,|$)/);
  if (!Number.isSafeInteger(receivedAt) || !time || !Number.isSafeInteger(Number(time[1])) ||
      Math.abs(receivedAt / 1000 - Number(time[1])) > 300) fail('signature_invalid');
  let event: Stripe.Event;
  try {event = stripe.webhooks.constructEvent(raw, signature, secret, 300, undefined, receivedAt);}
  catch {return fail('signature_invalid');}
  live(event);
  return event;
}

/** Pass only a successfully signature-verified Stripe event. The event payload
 * is used for references; canonical state is fetched again while holding a UID
 * lease. No Stripe mutation, customer creation or mail delivery is performed. */
export function createWebBillingWebhook(d: WebBillingWebhookDependencies) {
  // Revalidate even a dependency-injected object; callers cannot bypass the
  // production-only key/Price/URL boundary by constructing the DTO directly.
  const config = parseWebBillingConfig({...d.config});
  if (!/^price_[A-Za-z0-9_]+$/.test(config.priceId) ||
      (config.legacyPriceId && (!/^price_[A-Za-z0-9_]+$/.test(config.legacyPriceId) || config.legacyPriceId === config.priceId))) fail('configuration_invalid');
  async function route(event: Stripe.Event): Promise<{customerId: string; subscriptionId: string; session?: Stripe.Checkout.Session}> {
    const payload: unknown = event.data?.object;
    if (!record(payload)) return fail('event_invalid');
    if (event.type === 'checkout.session.completed') {
      const session = await d.stripe.checkout.sessions.retrieve(reference(payload.id, 'cs')); live(session);
      if (session.mode !== 'subscription' || session.status !== 'complete') fail('session_invalid');
      return {customerId: reference(session.customer, 'cus'), subscriptionId: reference(session.subscription, 'sub'), session};
    }
    if (event.type.startsWith('invoice.')) {
      const invoice = await d.stripe.invoices.retrieve(reference(payload.id, 'in')); live(invoice);
      return {customerId: reference(invoice.customer, 'cus'), subscriptionId: invoiceSubscription(invoice)};
    }
    const sub = await d.stripe.subscriptions.retrieve(reference(payload.id, 'sub')); live(sub);
    return {customerId: reference(sub.customer, 'cus'), subscriptionId: sub.id};
  }
  async function customerUid(customerId: string): Promise<string> {
    const customer = await d.stripe.customers.retrieve(customerId); live(customer);
    if ('deleted' in customer && customer.deleted) fail('customer_unresolved');
    return uidOf((customer as Stripe.Customer).metadata);
  }
  return {
    async process(event: Stripe.Event): Promise<{result: 'synced' | 'duplicate' | 'ignored'}> {
      live(event);
      if (!(WEB_BILLING_EVENT_TYPES as readonly string[]).includes(event.type)) return {result: 'ignored'};
      const eventHash = digest(reference(event.id, 'evt'));
      const created = seconds(event.created); if (created === null) fail('event_invalid');
      const lease = randomUUID(), started = millis(d);
      const meta: WebBillingEventMeta = {eventType: event.type, createdSeconds: created, version: 1};
      const claim = await d.store.claimEvent(eventHash, lease, started, started + LEASE_MS, meta);
      if (claim === 'processed') return {result: 'duplicate'};
      if (claim !== 'claimed') fail('event_busy', true);
      let uid: string | undefined;
      try {
        const initialRoute = await route(event);
        uid = await customerUid(initialRoute.customerId);
        if (!(await d.store.claimSubject(uid, lease, started, started + LEASE_MS))) fail('subject_busy', true);
        // All authority reads happen after the subject lock. A prior network
        // response can never be committed after another synchronization.
        const before = await d.store.readSubject(uid);
        if (before.deletionRequested) {
          if (!d.store.ignoreDeletedSubject) fail('deletion_fence_unavailable',true);
          await d.store.ignoreDeletedSubject({uid,eventHash,lease,nowMs:millis(d)});
          return {result:'ignored'};
        }
        const currentRoute = await route(event);
        if (currentRoute.customerId !== initialRoute.customerId || await customerUid(currentRoute.customerId) !== uid) fail('uid_binding_mismatch');
        storedBinding(before, uid, currentRoute.customerId);
        const facts = d.readFacts ? await d.readFacts(uid) : null;
        const source = await d.stripe.subscriptions.retrieve(currentRoute.subscriptionId); live(source);
        if (reference(source.customer, 'cus') !== currentRoute.customerId) fail('customer_binding_mismatch');
        const listed = await d.stripe.subscriptions.list({customer: currentRoute.customerId, status: 'all', limit: 100});
        if (listed.has_more) fail('subscription_unresolved', true);
        for (const item of listed.data) {live(item); if (reference(item.customer, 'cus') !== currentRoute.customerId) fail('customer_binding_mismatch');}
        // Use the existing active/trialing preference. If all have ended, pick
        // the newest contract so an old deletion cannot replace newer history.
        const candidates = listed.data.some(item => item.id === source.id) ? listed.data : [...listed.data, source];
        const preferred = selectPreferredPaidSubscription(candidates) ?? [...candidates].sort((a,b) => b.created - a.created || b.id.localeCompare(a.id))[0];
        const sub = await d.stripe.subscriptions.retrieve(preferred.id); live(sub);
        if (reference(sub.customer, 'cus') !== currentRoute.customerId) fail('customer_binding_mismatch');
        // Profile deletion must not block an already owned contract's payment
        // or cancellation updates. It never authorizes a new subscription.
        const existingContract = before.billing?.stripeCustomerId === currentRoute.customerId &&
          before.billing?.stripeSubscriptionId === sub.id && before.billing?.stripeLivemode !== false;
        if (facts && facts.appAccountExists !== true && !existingContract) fail('account_missing');
        const legacy = existingLegacy(before, sub, config.legacyPriceId);
        const sourceAttempt = webMetadata(source.metadata, uid, existingLegacy(before, source, config.legacyPriceId));
        webMetadata(sub.metadata, uid, legacy);
        const session = currentRoute.session;
        if (session) {
          const sessionAttempt = webMetadata(session.metadata, uid, existingLegacy(before, source, config.legacyPriceId));
          if (sessionAttempt !== sourceAttempt) fail('session_binding_mismatch');
          if ((session.client_reference_id && session.client_reference_id !== uid) || (!legacy && session.ui_mode !== 'embedded')) fail('session_binding_mismatch');
        }
        if (sub.items?.data?.length !== 1 || sub.items.data[0].quantity !== 1) fail('subscription_price_invalid');
        const priceId = reference(sub.items.data[0].price, 'price');
        if (priceId !== config.priceId && !(legacy && priceId === config.legacyPriceId)) fail('subscription_price_invalid');
        const price = await d.stripe.prices.retrieve(priceId); live(price);
        const amount = legacy ? 500 : 550;
        if (price.id !== priceId || price.type !== 'recurring' || price.unit_amount !== amount || price.currency !== 'jpy' ||
            price.recurring?.interval !== 'month' || price.recurring.interval_count !== 1 || (!legacy && price.tax_behavior !== 'inclusive')) fail('price_invalid');
        const productId = reference(price.product, 'prod');
        const product = await d.stripe.products.retrieve(productId); live(product);
        if ('deleted' in product && product.deleted) fail('price_invalid');
        if (!legacy && (sub.automatic_tax?.enabled || (sub as Data).discount || (sub as Data).discounts?.length)) fail('subscription_price_invalid');
        const mappedStatus = status(sub.status), paid = ['active','trialing'].includes(mappedStatus);
        const trialEnd = seconds(sub.trial_end);
        const previouslyVerifiedTrial = existingContract && before.billing?.billingSyncVersion===1 &&
          seconds(before.billing?.trialEndSeconds)===trialEnd;
        if (!legacy && trialEnd && !previouslyVerifiedTrial) {
          const trial = facts?.trial;
          const endAt = trial?.kind === 'found' && record(trial.data) ? trial.data.endsAt : null;
          let originalEnd: number | null = null;
          try {originalEnd = endAt instanceof Date ? endAt.getTime() : endAt && typeof endAt.toMillis === 'function' ? endAt.toMillis() : null;} catch {fail('trial_unresolved', true);}
          if (!originalEnd || Math.ceil(originalEnd / 1000) !== trialEnd) fail('trial_binding_mismatch');
        }
        const start = seconds((sub as Data).current_period_start ?? (sub.items.data[0] as Data).current_period_start);
        const end = seconds((sub as Data).current_period_end ?? (sub.items.data[0] as Data).current_period_end);
        if (paid && end === null) fail('period_unresolved', true);
        let invoice: Stripe.Invoice | null = null;
        if (sub.latest_invoice) {
          invoice = await d.stripe.invoices.retrieve(reference(sub.latest_invoice, 'in')); live(invoice);
          if (reference(invoice.customer, 'cus') !== currentRoute.customerId || invoiceSubscription(invoice) !== sub.id || invoice.currency !== 'jpy') fail('invoice_binding_mismatch');
          if (!invoice.status || !['draft','open','paid','uncollectible','void'].includes(invoice.status)) fail('invoice_status_invalid');
          if (![invoice.total, invoice.amount_due, invoice.amount_paid].every(n => Number.isSafeInteger(n) && n >= 0)) fail('invoice_price_invalid');
          const expected = trialEnd && invoice.billing_reason === 'subscription_create' && invoice.total === 0 ? 0 : 550;
          if (!legacy && (invoice.total !== expected || invoice.amount_due !== expected || (invoice.status === 'paid' && invoice.amount_paid !== expected) ||
              invoice.total_discount_amounts?.some(v => v.amount !== 0) || invoice.default_tax_rates?.length)) fail('invoice_price_invalid');
        } else if (paid) fail('invoice_unresolved', true);
        const now = millis(d), cancelReserved = sub.cancel_at_period_end === true;
        const priorFirstCharge = before.billing?.stripeSubscriptionId === sub.id ? seconds(before.billing?.firstChargeAtSeconds) : null;
        const invoicePaid = invoice?.status === 'paid' && invoice.amount_paid > 0;
        const paidAt = seconds(invoice?.status_transitions?.paid_at);
        const billing: WebBillingSubscription = {
          provider:'stripe', stripeLivemode:true, billingSyncVersion:1, firebaseUid:uid,
          stripeCustomerId:currentRoute.customerId, stripeSubscriptionId:sub.id,
          stripePriceId:priceId, stripeProductId:productId, legacyPrice:legacy,
          plan:paid?'paid':'none',status:mappedStatus,planKey:'premium_monthly',amount,currency:'jpy',interval:'month',
          currentPeriodStartSeconds:start,currentPeriodEndSeconds:end,cancelAtPeriodEnd:cancelReserved,
          cancelAtSeconds:seconds(sub.cancel_at),canceledAtSeconds:seconds(sub.canceled_at) ?? (mappedStatus==='canceled' ? seconds(before.billing?.canceledAtSeconds) : null),
          trialStartSeconds:seconds(sub.trial_start),trialEndSeconds:trialEnd,
          firstChargeAtSeconds:priorFirstCharge ?? (invoicePaid ? paidAt : null),
          nextChargeAtSeconds:cancelReserved?null:sub.status==='trialing'?trialEnd:sub.status==='active'?end:null,
          latestInvoiceId:invoice?.id??null,latestInvoiceStatus:invoice?.status??null,
          latestInvoicePaymentStatus:invoice?.status==='paid'?invoice.total===0?'no_payment_required':'paid':invoice?'unpaid':'unknown',
          latestInvoicePaidAtSeconds:paidAt,latestInvoiceTotal:invoice?.total??null,
          latestInvoiceAmountDue:invoice?.amount_due??null,latestInvoiceAmountPaid:invoice?.amount_paid??null,
          checkoutSessionId:session?.id ?? (typeof before.billing?.checkoutSessionId==='string'?before.billing.checkoutSessionId:null),
          sourceEventType:event.type,sourceEventCreatedSeconds:created,stripeObservedAtMillis:now,syncedAtMillis:now,
        };
        const hooks: WebBillingHook[] = [];
        const add = (type: WebBillingHookType, transition: string) => {
          const transitionKey = [type, sub.id, transition].join(':');
          hooks.push({id:digest(transitionKey),transitionKey,type,firebaseUid:uid!,subscriptionId:sub.id,
            invoiceId:invoice?.id??null,eventHash,status:'pending',createdAtMillis:now});
        };
        const previous = before.billing;
        const sameContract = previous?.stripeSubscriptionId === sub.id;
        if (!sameContract && paid) add('contract_started', sub.id);
        if (sub.status==='trialing' && (!sameContract || previous?.status!=='trialing')) add('trial_started', String(trialEnd));
        const paymentEvent = ['invoice.paid','invoice.payment_succeeded'].includes(event.type) &&
          invoice && record(event.data.object) && (event.data.object as Data).id===invoice.id;
        if (invoicePaid && invoice && paymentEvent) {
          // A metadata/internal subscription sync may observe an old paid
          // invoice for the first time. That observation is not a new payment.
          // Conversely, the real payment event can arrive after subscription
          // sync already recorded the invoice. Enqueue it then and let the
          // semantic invoice key deduplicate success aliases and re-delivery.
          // Stripe calls the first invoice after a trial subscription_cycle too.
          // A previously observed zero-charge trial still needs first_charge.
          const renewal = !!priorFirstCharge || (invoice.billing_reason==='subscription_cycle' &&
            (!sameContract || seconds(previous?.trialEndSeconds)===null));
          add(renewal?'renewal':'first_charge',invoice.id);
        }
        if (event.type==='invoice.payment_failed' && invoice && (event.data.object as Data).id===invoice.id && invoice.status!=='paid' && invoice.amount_due>0)
          add('payment_failed',invoice.id+':'+String(invoice.attempt_count));
        if (cancelReserved && (!sameContract || previous?.cancelAtPeriodEnd!==true)) add('cancel_reserved',eventHash);
        if (sameContract && previous?.cancelAtPeriodEnd===true && !cancelReserved && paid) add('resumed',eventHash);
        if (mappedStatus==='canceled' && (!sameContract || previous?.status!=='canceled')) add('canceled',String(seconds(sub.canceled_at)??sub.id));
        const committed = await d.store.commit({uid,eventHash,lease,nowMs:now,before,billing,hooks,
          eventRecord:{...meta,processedAtMillis:now,subscriptionHash:digest(sub.id)}});
        return {result:committed === 'ignored' ? 'ignored' : 'synced'};
      } catch (error) {
        const safe = error instanceof WebBillingWebhookError ? error : new WebBillingWebhookError('sync_unavailable',true);
        try {await d.store.release({uid,eventHash,lease,errorCode:safe.code});}
        catch {throw new WebBillingWebhookError('store_unavailable',true);}
        throw safe;
      }
    },
  };
}
