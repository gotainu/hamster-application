// The caller passes a server-selected mode and client. No client-supplied Stripe IDs.
import type Stripe from 'stripe';
import {WEB_BILLING_SCOPE} from './webBillingCheckout';

export class DeletionStop extends Error {
  constructor(readonly reason: 'billing_unresolved' | 'checkout_pending' | 'paid_confirmation_required' |
    'invoice_review' | 'in_progress' | 'retryable' | 'manual_review') {
    super(reason);
  }
}
const unresolved = (): never => {throw new DeletionStop('billing_unresolved');};
type Row = Record<string, any>;
const idOf = (raw: any): string | undefined => typeof raw === 'string' ? raw : raw?.id;
const validId = (raw: unknown, prefix: string): raw is string =>
  typeof raw === 'string' && new RegExp('^' + prefix + '_[A-Za-z0-9_]{1,240}$').test(raw);

export interface BillingDeletionSource {
  billing: Row;
  customer: Row;
  checkout: Row;
}

function billingCustomer(uid: string, source: BillingDeletionSource, now: number, live: boolean) {
  const {billing, customer, checkout} = source;
  for (const row of [billing, customer, checkout]) {
    if ((row.firebaseUid !== undefined && row.firebaseUid !== uid) ||
        (row.stripeLivemode !== undefined && row.stripeLivemode !== live) ||
        row.testMode === true || Object.keys(row).some(k => /^preview/i.test(k))) unresolved();
  }
  if ((Object.keys(customer).length && customer.firebaseUid !== uid) ||
      (Object.keys(checkout).length && checkout.firebaseUid !== uid)) unresolved();
  if (customer.customerOperation || customer.customerLease) throw new DeletionStop('billing_unresolved');
  const op = checkout.operation;
  if (checkout.lease && (!Number.isSafeInteger(checkout.lease.until) || !op)) unresolved();
  if (checkout.lease?.until > now) throw new DeletionStop('checkout_pending');
  if (op && (!validId(op.customerId, 'cus') || !Number.isSafeInteger(op.expiresAt))) unresolved();
  const ids = [billing.stripeCustomerId, customer.customerId, op?.customerId].filter(id => id != null);
  if (ids.some(id => !validId(id, 'cus')) || new Set(ids).size > 1) unresolved();
  const sub = billing.stripeSubscriptionId;
  if (sub != null && sub !== '' && !validId(sub, 'sub')) unresolved();
  if (!ids.length && (sub || (billing.plan != null && billing.plan !== 'none') ||
      (billing.status != null && !['none', 'canceled'].includes(billing.status)) ||
      (billing.cancelAtPeriodEnd != null && billing.cancelAtPeriodEnd !== false))) unresolved();
  return ids[0] as string | undefined;
}

function safePage<T>(page: {data:T[]; has_more:boolean}): T[] {
  // A partial list cannot establish that every subscription and invoice is safe.
  if (!Array.isArray(page.data) || page.has_more !== false) unresolved();
  return page.data;
}

export interface DeletionStripe {
  stripe: Stripe;
  livemode: boolean;
  priceId: string;
  legacyPriceId?: string;
}

export async function stopAccountBilling(uid: string, source: BillingDeletionSource,
  allowPaid: boolean, connection: () => DeletionStripe, now = Date.now(), live = true): Promise<void> {
  const customerId = billingCustomer(uid, source, now, live);
  if (!customerId) return; // Exclusive billing fence held; no Stripe footprint or secret access.
  const {stripe, livemode, priceId, legacyPriceId} = connection();
  if (live !== livemode) unresolved();
  const customer = await stripe.customers.retrieve(customerId);
  if (customer.deleted || customer.id !== customerId || customer.livemode !== live ||
      customer.metadata.firebaseUid !== uid) return unresolved();
  // Sources for a not-yet-returned Stripe create may not be list-visible yet.
  // Waiting until the Checkout expiry closes the in-flight purchase window.
  const op = source.checkout.operation;
  if (op && !op.sessionId && now <= op.expiresAt + 60_000) throw new DeletionStop('checkout_pending');
  const terminal = (s: Stripe.Subscription) => ['canceled', 'incomplete_expired'].includes(s.status);
  const validateSub = (s: Stripe.Subscription) => {
    const rows = s.items?.data;
    const p = rows?.[0]?.price?.id;
    if (s.livemode !== live || !validId(s.id, 'sub') || idOf(s.customer) !== customerId ||
        s.metadata?.firebaseUid !== uid || s.schedule || !Array.isArray(rows) || rows.length !== 1 || s.items.has_more !== false ||
        (p !== priceId && (!legacyPriceId || p !== legacyPriceId)) ||
        (s.metadata.webBillingScope !== WEB_BILLING_SCOPE && source.billing.stripeSubscriptionId !== s.id) ||
        !['canceled','incomplete_expired','active','trialing','paused','incomplete','past_due','unpaid'].includes(s.status)) unresolved();
  };
  const listSubs = async () => {
    const rows = safePage(await stripe.subscriptions.list({customer:customerId, status:'all', limit:100}));
    for (const row of rows) validateSub(row);
    if (source.billing.stripeSubscriptionId && !rows.some(s => s.id === source.billing.stripeSubscriptionId)) unresolved();
    return rows;
  };
  // A schedule can start after the last subscription ended. Do not release or
  // cancel nonstandard schedules automatically; ownership and liabilities need review.
  const schedules = safePage(await stripe.subscriptionSchedules.list({customer:customerId, limit:100}));
  if (schedules.some(s => s.livemode !== live || idOf(s.customer) !== customerId ||
      !['released','completed','canceled'].includes(s.status))) unresolved();
  const sessions = safePage(await stripe.checkout.sessions.list({customer:customerId, status:'open', limit:100}));
  const verifySession = (s: Stripe.Checkout.Session) => {
    if (s.livemode !== live || !validId(s.id,'cs') || idOf(s.customer) !== customerId ||
        s.mode !== 'subscription' || s.client_reference_id !== uid ||
        s.metadata?.firebaseUid !== uid || s.metadata.webBillingScope !== WEB_BILLING_SCOPE) unresolved();
  };
  for (const session of sessions) verifySession(session);
  // Establish ownership of the whole customer before any Stripe mutation.
  const initial = await listSubs();
  async function checkInvoices(subscriptions: Stripe.Subscription[], afterStop: boolean) {
    for (const status of ['open','draft'] as const) {
      const invoices = safePage(await stripe.invoices.list({
        customer:customerId, status, limit:100, expand:['data.payment_intent'],
      }));
      for (const inv of invoices) {
        if (inv.livemode !== live || idOf(inv.customer) !== customerId || inv.status !== status ||
            !subscriptions.some(s => s.id === idOf(inv.subscription)) ||
            (afterStop && (inv.auto_advance !== false || inv.next_payment_attempt != null)) ||
            (inv.payment_intent && (typeof inv.payment_intent !== 'object' ||
              !['requires_payment_method','canceled'].includes(inv.payment_intent.status)))) {
          // Never collect, finalize, void or refund an accounting document here.
          throw new DeletionStop('invoice_review');
        }
      }
    }
  }
  if (!allowPaid && (sessions.length || initial.some(s => !terminal(s)))) {
    throw new DeletionStop('paid_confirmation_required');
  }
  await checkInvoices(initial, false);
  for (const session of sessions) {
    await stripe.checkout.sessions.expire(session.id);
    const fresh = await stripe.checkout.sessions.retrieve(session.id);
    verifySession(fresh);
    if (fresh.id !== session.id || fresh.status !== 'expired') throw new DeletionStop('checkout_pending');
  }
  // A session could have completed just before its expiry. Re-read after closing admission.
  const subscriptions = await listSubs();
  if (!allowPaid && subscriptions.some(s => !terminal(s))) throw new DeletionStop('paid_confirmation_required');
  for (const sub of subscriptions) {
    if (!terminal(sub)) {
      await stripe.subscriptions.cancel(sub.id, {invoice_now:false, prorate:false});
    }
    const fresh = await stripe.subscriptions.retrieve(sub.id);
    validateSub(fresh);
    if (fresh.id !== sub.id || !terminal(fresh)) throw new DeletionStop('retryable');
  }
  if ((await listSubs()).some(s => !terminal(s))) throw new DeletionStop('retryable');
  await checkInvoices(subscriptions,true);
  // Pending line items can roll into a later invoice even after cancellation.
  // Keep their accounting history intact and surface them for reconciliation.
  const pending = await stripe.invoiceItems.list({customer:customerId, pending:true, limit:1});
  if (pending.has_more !== false || !Array.isArray(pending.data) || pending.data.length) {
    throw new DeletionStop('invoice_review');
  }
}
