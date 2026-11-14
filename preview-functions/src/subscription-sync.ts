import {createHash, randomUUID} from 'crypto';
import Stripe from 'stripe';
import {selectPreferredPaidSubscription} from '../../functions/src/stripeSubscriptionPriority';
import {SCOPE} from './engine';

export const PREVIEW_SYNC_EVENT_TYPES = [
  'checkout.session.completed', 'customer.subscription.created',
  'customer.subscription.updated', 'customer.subscription.deleted',
  'invoice.paid', 'invoice.payment_failed',
] as const;
export const PREVIEW_SYNC_VERSION = 1;
export class PreviewSyncError extends Error {
  constructor(public code: string, public retryable = false) { super(code); this.name = 'PreviewSyncError'; }
}
type Data = Record<string, any>;
export interface PreviewSyncSubject {
  previewFirebaseUid?: string;
  customerId?: string;
  attempt?: {id?: string; trialEndSeconds?: number | null};
}
export interface PreviewSyncEventMeta {eventType: string; createdSeconds: number; version: number;}
export interface PreviewSyncBilling {
  version: number; testMode: true; previewFirebaseUid: string;
  stripeCustomerId: string; stripeSubscriptionId: string; previewAttempt: string;
  planKey: 'premium_monthly'; amount: 550; currency: 'jpy'; interval: 'month';
  status: string; plan: 'paid' | 'none'; entitlementMirror: boolean;
  trialStartSeconds: number | null; trialEndSeconds: number | null;
  originalTrialEndsAtMillis: number | null;
  currentPeriodStartSeconds: number | null; currentPeriodEndSeconds: number | null;
  cancelAtPeriodEnd: boolean; canceledAtSeconds: number | null;
  firstChargeAtSeconds: number | null; nextChargeAtSeconds: number | null;
  latestInvoiceStatus: string | null; latestInvoicePaymentStatus: 'paid' | 'unpaid' | 'no_payment_required' | 'unknown';
  latestInvoicePaidAtSeconds: number | null;
  latestInvoiceTotal: number | null; latestInvoiceAmountDue: number | null; latestInvoiceAmountPaid: number | null;
  sourceEventType: string; sourceEventCreatedSeconds: number;
  stripeObservedAtMillis: number; syncedAtMillis: number;
}
export interface PreviewSyncCommit {
  subjectHash: string; eventHash: string; lease: string; nowMs: number;
  billing: PreviewSyncBilling;
  eventRecord: PreviewSyncEventMeta & {processedAtMillis: number; result: 'synced'; subscriptionHash: string;};
}
export interface PreviewSyncStore {
  claimEvent(eventHash: string, lease: string, nowMs: number, untilMs: number, meta: PreviewSyncEventMeta): Promise<'claimed' | 'processed' | 'busy'>;
  readSubject(subjectHash: string): Promise<PreviewSyncSubject | null>;
  claimSubject(subjectHash: string, lease: string, nowMs: number, untilMs: number): Promise<boolean>;
  /** Atomically verify both unexpired leases, write isolated billing, mark event
   * processed, and release both leases. A stale lease must never commit. */
  commit(input: PreviewSyncCommit): Promise<void>;
  /** Release only leases still owned by this invocation; keep processed events. */
  release(input: {subjectHash?: string; eventHash: string; lease: string; errorCode: string}): Promise<void>;
}
export interface PreviewSyncOriginalFacts {
  appAccountExists: boolean;
  trial: {kind: 'found' | 'missing' | 'denied' | 'unavailable'; data?: unknown};
}
export interface PreviewSyncDependencies {
  stripe: Stripe; priceId: string; store: PreviewSyncStore;
  readOriginalFacts(uid: string): Promise<PreviewSyncOriginalFacts>;
  now(): Date;
}
const digest = (value: string) => createHash('sha256').update(value).digest('hex');
const LEASE_MS = 120000;
function fail(code: string, retryable = false): never {throw new PreviewSyncError(code, retryable);}
const record = (value: unknown): value is Data => value !== null && typeof value === 'object' && !Array.isArray(value);
function id(value: unknown, prefix: string): string {
  const valueId = typeof value === 'string' ? value : record(value) ? value.id : null;
  if (typeof valueId !== 'string' || !new RegExp('^' + prefix + '_[A-Za-z0-9_]{1,240}$').test(valueId)) fail('invalid_reference');
  return valueId;
}
function seconds(value: unknown): number | null {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0 ? value : null;
}
function timestamp(value: unknown): number | null {
  try {
    const ms = value instanceof Date ? value.getTime() : record(value) && typeof value.toMillis === 'function' ? value.toMillis() : null;
    return typeof ms === 'number' && Number.isSafeInteger(ms) && ms > 0 ? ms : null;
  } catch {return null;}
}
function testMode(value: unknown): asserts value is Data {
  if (!record(value) || value.livemode !== false) fail('test_mode_required');
}
function binding(metadata: unknown, requirePlan: boolean): {uid: string; subject: string; attempt?: string} {
  if (!record(metadata) || metadata.previewScope !== SCOPE ||
      typeof metadata.previewFirebaseUid !== 'string' || metadata.previewFirebaseUid.length > 128 ||
      !/^[^/\s\u0000-\u001f\u007f]+$/u.test(metadata.previewFirebaseUid)) fail('uid_binding_invalid');
  const uid = metadata.previewFirebaseUid;
  const subject = digest(uid);
  if (metadata.previewSubjectHash !== subject ||
      (requirePlan && metadata.previewPlan !== 'premium_monthly') ||
      (metadata.previewPlan !== undefined && metadata.previewPlan !== 'premium_monthly')) fail('uid_binding_invalid');
  return {uid, subject, attempt: typeof metadata.previewAttempt === 'string' ? metadata.previewAttempt : undefined};
}
function sameBinding(metadata: unknown, uid: string, subject: string, requirePlan: boolean): {attempt?: string} {
  const found = binding(metadata, requirePlan);
  if (found.uid !== uid || found.subject !== subject) fail('uid_binding_mismatch');
  return found;
}
const SUB_STATUSES = new Set(['incomplete', 'incomplete_expired', 'trialing', 'active', 'past_due', 'unpaid', 'paused', 'canceled']);
const INVOICE_STATUSES = new Set(['draft', 'open', 'paid', 'uncollectible', 'void']);

/** Caller must pass only a successfully signature-verified Stripe Event. The
 * event payload supplies routing references, never canonical billing state. */
export function createPreviewSubscriptionSync(d: PreviewSyncDependencies) {
  if (!/^price_[A-Za-z0-9_]+$/.test(d.priceId)) fail('price_configuration_invalid');
  async function validatePrice(price: Stripe.Price) {
    testMode(price);
    if (price.id !== d.priceId || !price.active || price.metadata?.previewScope !== SCOPE ||
        price.type !== 'recurring' || price.unit_amount !== 550 || price.currency !== 'jpy' ||
        price.tax_behavior !== 'inclusive' || price.recurring?.interval !== 'month' || price.recurring.interval_count !== 1) fail('price_mismatch');
    const product = typeof price.product === 'string' ? await d.stripe.products.retrieve(price.product) : price.product;
    testMode(product);
    if (product.deleted || product.metadata?.previewScope !== SCOPE) fail('price_mismatch');
  }
  return {
    async process(event: Stripe.Event): Promise<{result: 'synced' | 'duplicate'}> {
      testMode(event);
      if (!(PREVIEW_SYNC_EVENT_TYPES as readonly string[]).includes(event.type)) fail('event_not_supported');
      const eventId = id(event.id, 'evt');
      const created = seconds(event.created); if (created === null) fail('event_invalid');
      const payload = event.data?.object as unknown;
      if (!record(payload)) fail('event_invalid');
      const eventHash = digest(eventId); const lease = randomUUID();
      const started = d.now().getTime(); if (!Number.isSafeInteger(started) || started <= 0) fail('clock_invalid', true);
      const meta = {eventType: event.type, createdSeconds: created, version: PREVIEW_SYNC_VERSION};
      const claimed = await d.store.claimEvent(eventHash, lease, started, started + LEASE_MS, meta);
      if (claimed === 'processed') return {result: 'duplicate'};
      if (claimed !== 'claimed') fail('event_busy', true);
      let subjectHash: string | undefined;
      try {
        const isInvoice = event.type.startsWith('invoice.');
        const routingMetadata = isInvoice
          ? payload.subscription_details?.metadata ?? payload.parent?.subscription_details?.metadata
          : payload.metadata;
        const routed = binding(routingMetadata, true); subjectHash = routed.subject;
        const initial = await d.store.readSubject(subjectHash);
        if (!initial || initial.previewFirebaseUid !== routed.uid || typeof initial.customerId !== 'string') fail('subject_binding_invalid');
        if (!(await d.store.claimSubject(subjectHash, lease, started, started + LEASE_MS))) fail('subject_busy', true);
        const state = await d.store.readSubject(subjectHash);
        if (!state || state.previewFirebaseUid !== routed.uid || state.customerId !== initial.customerId) fail('subject_binding_invalid');
        const customerId = id(state.customerId, 'cus');
        const customer = await d.stripe.customers.retrieve(customerId); testMode(customer);
        if ('deleted' in customer && customer.deleted) fail('customer_unresolved');
        const currentCustomer = customer as Stripe.Customer & Data;
        if (currentCustomer.balance !== 0 || currentCustomer.discount || currentCustomer.discounts?.length) fail('customer_unresolved');
        sameBinding(currentCustomer.metadata, routed.uid, subjectHash, false);
        let sourceSubscriptionId: string;
        if (event.type === 'checkout.session.completed') {
          const session = await d.stripe.checkout.sessions.retrieve(id(payload.id, 'cs'));
          testMode(session); sameBinding(session.metadata, routed.uid, subjectHash, true);
          if (session.customer !== customerId || session.mode !== 'subscription' || session.ui_mode !== 'embedded' || session.status !== 'complete') fail('session_unresolved');
          sourceSubscriptionId = id(session.subscription, 'sub');
        } else if (isInvoice) {
          const invoice = await d.stripe.invoices.retrieve(id(payload.id, 'in')); testMode(invoice);
          if (id(invoice.customer, 'cus') !== customerId) fail('customer_binding_mismatch');
          sourceSubscriptionId = id((invoice as any).subscription ?? (invoice as any).parent?.subscription_details?.subscription, 'sub');
        } else sourceSubscriptionId = id(payload.id, 'sub');
        const source = await d.stripe.subscriptions.retrieve(sourceSubscriptionId); testMode(source);
        if (id(source.customer, 'cus') !== customerId) fail('customer_binding_mismatch');
        sameBinding(source.metadata, routed.uid, subjectHash, true);
        const listed = await d.stripe.subscriptions.list({customer: customerId, status: 'all', limit: 100});
        if (listed.has_more) fail('subscription_unresolved', true);
        for (const item of listed.data) {testMode(item); if (id(item.customer, 'cus') !== customerId) fail('customer_binding_mismatch');}
        // Reuse the existing server preference for active/trialing subscriptions.
        // With no paid candidate, use newest history, not the old event target.
        const candidates = listed.data.some(item => item.id === source.id) ? listed.data : [...listed.data, source];
        const preferred = selectPreferredPaidSubscription(candidates) ?? [...candidates].sort((a, b) => b.created - a.created)[0];
        const subscription = await d.stripe.subscriptions.retrieve(preferred.id); testMode(subscription);
        if (id(subscription.customer, 'cus') !== customerId) fail('customer_binding_mismatch');
        const subBinding = sameBinding(subscription.metadata, routed.uid, subjectHash, true);
        if (!subBinding.attempt) fail('attempt_binding_invalid');
        if (!SUB_STATUSES.has(subscription.status)) fail('subscription_status_unknown');
        if (subscription.items.data.length !== 1 || subscription.items.data[0].quantity !== 1 ||
            subscription.items.data[0].price.id !== d.priceId || subscription.automatic_tax?.enabled ||
            subscription.discount || subscription.discounts?.length || subscription.default_tax_rates?.length) fail('price_mismatch');
        const price = await d.stripe.prices.retrieve(d.priceId); await validatePrice(price);
        const facts = await d.readOriginalFacts(routed.uid); if (facts.appAccountExists !== true) fail('app_account_required');
        const stripeTrialEnd = seconds(subscription.trial_end);
        if ((subscription.trial_end !== null && subscription.trial_end !== undefined && stripeTrialEnd === null) ||
            (subscription.status === 'trialing' && stripeTrialEnd === null)) fail('trial_mismatch');
        let originalTrialEnd: number | null = null;
        if (stripeTrialEnd !== null) {
          if (state.attempt?.id !== subBinding.attempt || state.attempt.trialEndSeconds !== stripeTrialEnd ||
              facts.trial.kind !== 'found' || !record(facts.trial.data) ||
              !['active', 'expired'].includes(facts.trial.data.status)) fail('trial_mismatch');
          originalTrialEnd = timestamp(facts.trial.data.endsAt);
          if (originalTrialEnd === null || Math.ceil(originalTrialEnd / 1000) !== stripeTrialEnd) fail('trial_mismatch');
        } else if (state.attempt?.id === subBinding.attempt && state.attempt.trialEndSeconds) fail('trial_mismatch');
        const start = seconds((subscription as any).current_period_start ?? (subscription.items.data[0] as any).current_period_start);
        const end = seconds((subscription as any).current_period_end ?? (subscription.items.data[0] as any).current_period_end);
        if (!start || !end || end <= start) fail('period_invalid');
        let invoiceTotal: number | null = null, invoiceDue: number | null = null, invoicePaid: number | null = null;
        let invoiceStatus: string | null = null, invoicePayment: PreviewSyncBilling['latestInvoicePaymentStatus'] = 'unknown', paidAt: number | null = null;
        if (subscription.latest_invoice) {
          const invoice = await d.stripe.invoices.retrieve(id(subscription.latest_invoice, 'in')); testMode(invoice);
          if (id(invoice.customer, 'cus') !== customerId || id((invoice as any).subscription ?? (invoice as any).parent?.subscription_details?.subscription, 'sub') !== subscription.id || invoice.currency !== 'jpy') fail('invoice_binding_mismatch');
          if (!invoice.status || !INVOICE_STATUSES.has(invoice.status)) fail('invoice_status_unknown');
          const zeroInitialTrial = invoice.total === 0 && stripeTrialEnd !== null && invoice.billing_reason === 'subscription_create';
          const expectedInvoiceAmount = zeroInitialTrial ? 0 : 550;
          if (invoice.total !== expectedInvoiceAmount || invoice.amount_due !== expectedInvoiceAmount ||
              (invoice.status === 'paid' && invoice.amount_paid !== expectedInvoiceAmount) ||
              invoice.total_discount_amounts?.some(item => item.amount !== 0) || invoice.default_tax_rates?.length) fail('invoice_price_mismatch');
          invoiceTotal = invoice.total; invoiceDue = invoice.amount_due; invoicePaid = invoice.amount_paid;
          invoiceStatus = invoice.status;
          invoicePayment = invoice.status === 'paid' ? invoice.total === 0 ? 'no_payment_required' : 'paid' : 'unpaid';
          paidAt = seconds(invoice.status_transitions?.paid_at);
        } else if (subscription.status === 'active' || subscription.status === 'trialing') fail('invoice_unresolved', true);
        const now = d.now().getTime();
        const paidStatus = subscription.status === 'active' || subscription.status === 'trialing';
        const canceled = subscription.cancel_at_period_end === true;
        const billing: PreviewSyncBilling = {
          version: PREVIEW_SYNC_VERSION, testMode: true, previewFirebaseUid: routed.uid,
          stripeCustomerId: customerId, stripeSubscriptionId: subscription.id, previewAttempt: subBinding.attempt,
          planKey: 'premium_monthly', amount: 550, currency: 'jpy', interval: 'month', status: subscription.status,
          plan: paidStatus ? 'paid' : 'none', entitlementMirror: paidStatus && now < end * 1000,
          trialStartSeconds: seconds(subscription.trial_start), trialEndSeconds: stripeTrialEnd,
          originalTrialEndsAtMillis: originalTrialEnd, currentPeriodStartSeconds: start, currentPeriodEndSeconds: end,
          cancelAtPeriodEnd: canceled, canceledAtSeconds: seconds(subscription.canceled_at),
          firstChargeAtSeconds: stripeTrialEnd ?? seconds(subscription.start_date),
          nextChargeAtSeconds: canceled ? null : subscription.status === 'trialing' ? stripeTrialEnd : subscription.status === 'active' ? end : null,
          latestInvoiceStatus: invoiceStatus, latestInvoicePaymentStatus: invoicePayment, latestInvoicePaidAtSeconds: paidAt,
          latestInvoiceTotal: invoiceTotal, latestInvoiceAmountDue: invoiceDue, latestInvoiceAmountPaid: invoicePaid,
          sourceEventType: event.type, sourceEventCreatedSeconds: created, stripeObservedAtMillis: now, syncedAtMillis: now,
        };
        await d.store.commit({subjectHash, eventHash, lease, nowMs: now, billing,
          eventRecord: {...meta, processedAtMillis: now, result: 'synced', subscriptionHash: digest(subscription.id)}});
        return {result: 'synced'};
      } catch (error) {
        const safe = error instanceof PreviewSyncError ? error : new PreviewSyncError('sync_unavailable', true);
        try {await d.store.release({subjectHash, eventHash, lease, errorCode: safe.code});}
        catch {throw new PreviewSyncError('store_unavailable', true);}
        throw safe;
      }
    },
  };
}
