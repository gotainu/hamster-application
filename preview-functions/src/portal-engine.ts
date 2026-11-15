import Stripe from 'stripe';
import {AppFacts, CheckoutError, hash, Identity, PREVIEW_ORIGIN, PreviewStore, SCOPE} from './engine';
import {selectPreferredPaidSubscription} from '../../functions/src/stripeSubscriptionPriority';

export const PREVIEW_PORTAL_PURPOSE = 'customer-portal-task6';
export const PREVIEW_PORTAL_RETURN_URL = PREVIEW_ORIGIN + '/account/?portal=return';
export const PREVIEW_PORTAL_MANAGEABLE_STATUSES = [
  'trialing', 'active', 'past_due', 'unpaid', 'paused', 'incomplete',
] as const;
const KNOWN_STATUSES = new Set<string>([...PREVIEW_PORTAL_MANAGEABLE_STATUSES, 'canceled', 'incomplete_expired']);
const REASON_OPTIONS = new Set(['too_expensive', 'unused', 'missing_features', 'too_complex', 'switched_service', 'other']);
type Data = Record<string, any>;
export interface PreviewPortalDependencies {
  stripe: Stripe;
  /** Read-only UID-to-Customer binding. Portal URLs must never be stored here. */
  store: Pick<PreviewStore, 'read'>;
  readFacts(uid: string): Promise<AppFacts>;
  now(): Date;
  priceId: string;
  configurationId: string;
  allowedWebhook: {id: string; url: string; events: readonly string[]};
}
function fail(code: string): never {throw new CheckoutError(code);}
function record(value: unknown): value is Data {return !!value && typeof value === 'object' && !Array.isArray(value);}
function ref(value: unknown, prefix: string): string {
  const id = typeof value === 'string' ? value : record(value) ? value.id : null;
  if (typeof id !== 'string' || !new RegExp('^' + prefix + '_[A-Za-z0-9_]{1,240}$').test(id)) fail('portal_unavailable');
  return id;
}
function testOnly(value: unknown): asserts value is Data {
  if (!record(value) || value.livemode !== false) fail('test_mode_required');
}
function verifyBinding(metadata: unknown, uid: string, subject: string, requirePlan: boolean, legacyTerminal = false): void {
  const matchingUid = record(metadata) && (metadata.previewFirebaseUid === uid ||
    (legacyTerminal && !Object.prototype.hasOwnProperty.call(metadata, 'previewFirebaseUid')));
  if (!record(metadata) || metadata.previewScope !== SCOPE ||
      !matchingUid || metadata.previewSubjectHash !== subject ||
      (requirePlan && metadata.previewPlan !== 'premium_monthly') ||
      (metadata.previewPlan !== undefined && metadata.previewPlan !== 'premium_monthly')) fail('customer_unresolved');
}
function verifyApplicationBilling(app: AppFacts): void {
  if (!record(app) || app.appAccountExists !== true) fail('app_account_required');
  const source = app.billing;
  if (!record(source)) fail('billing_unresolved');
  if (source.kind === 'missing') return;
  if (source.kind !== 'found' || !record(source.data)) fail('billing_unresolved');
  const data = source.data;
  // Never mistake the isolated Test Portal for management of an existing app contract.
  if (data.plan === 'paid' && ['active', 'trialing'].includes(data.status)) fail('existing_subscription');
  if (data.plan !== 'none' || !['none', 'canceled'].includes(data.status) ||
      (data.cancelAtPeriodEnd !== undefined && typeof data.cancelAtPeriodEnd !== 'boolean') ||
      (data.status === 'none' && data.cancelAtPeriodEnd === true)) fail('billing_unresolved');
}
/** Accept only Stripe's two documented TEST session URL forms. No arbitrary redirects. */
export function isPreviewPortalSessionUrl(value: unknown): value is string {
  if (typeof value !== 'string' || value.length > 4096 || !value.startsWith('https://billing.stripe.com/') || value.includes('#') || value !== value.trim() || /[\u0000-\u0020\u007f]/u.test(value)) return false;
  let url: URL;
  try {url = new URL(value);} catch {return false;}
  if (url.protocol !== 'https:' || url.hostname !== 'billing.stripe.com' || url.port ||
      url.username || url.password || url.hash) return false;
  if (/^\/p\/session\/test_[A-Za-z0-9_-]+$/.test(url.pathname)) return !url.search;
  const keys = [...url.searchParams.keys()];
  return url.pathname === '/p/session' && keys.length === 1 && keys[0] === 'secret' &&
    /^test_[A-Za-z0-9_-]+$/.test(url.searchParams.get('secret') || '');
}
/** All mutable financial state is Stripe Test Mode. No Customer search, creation,
 * contract mutation, entitlement write, or stored Portal URL is available here. */
export function createPreviewPortalEngine(d: PreviewPortalDependencies) {
  if (!/^price_[A-Za-z0-9_]+$/.test(d.priceId) || !/^bpc_[A-Za-z0-9_]+$/.test(d.configurationId) ||
      !record(d.allowedWebhook) || !/^we_[A-Za-z0-9_]+$/.test(d.allowedWebhook.id) ||
      !Array.isArray(d.allowedWebhook.events) || d.allowedWebhook.events.length === 0) fail('test_configuration_invalid');
  async function verifyWebhook() {
    const endpoints = await d.stripe.webhookEndpoints.list({limit: 100});
    const enabled = endpoints.data.filter(e => e.status === 'enabled');
    if (endpoints.has_more || enabled.length !== 1 || enabled.some(e =>
      e.id !== d.allowedWebhook.id || e.url !== d.allowedWebhook.url || e.livemode !== false ||
      e.api_version !== '2025-02-24.acacia' ||
      JSON.stringify([...e.enabled_events].sort()) !== JSON.stringify([...d.allowedWebhook.events].sort()))) fail('test_webhook_unresolved');
  }
  async function verifyPrice() {
    const price = await d.stripe.prices.retrieve(d.priceId); testOnly(price);
    if (price.id !== d.priceId || price.active !== true || price.metadata.previewScope !== SCOPE ||
        price.type !== 'recurring' || price.unit_amount !== 550 || price.currency !== 'jpy' ||
        price.tax_behavior !== 'inclusive' || price.recurring?.interval !== 'month' ||
        price.recurring.interval_count !== 1) fail('price_mismatch');
    const product = typeof price.product === 'string' ? await d.stripe.products.retrieve(price.product) : price.product;
    testOnly(product);
    if (product.deleted || product.metadata?.previewScope !== SCOPE) fail('price_mismatch');
  }
  async function verifyConfiguration() {
    const config = await d.stripe.billingPortal.configurations.retrieve(d.configurationId); testOnly(config);
    if (config.id !== d.configurationId || config.active !== true ||
        config.metadata?.previewScope !== SCOPE || config.metadata?.previewPurpose !== PREVIEW_PORTAL_PURPOSE ||
        config.login_page?.enabled !== false ||
        (config.default_return_url !== null && config.default_return_url !== PREVIEW_ORIGIN + '/account/' &&
          config.default_return_url !== PREVIEW_PORTAL_RETURN_URL)) fail('portal_configuration_invalid');
    const f = config.features;
    if (!record(f) || f.customer_update?.enabled !== false || f.subscription_update?.enabled !== false ||
        f.payment_method_update?.enabled !== true || f.invoice_history?.enabled !== true ||
        f.subscription_cancel?.enabled !== true || f.subscription_cancel.mode !== 'at_period_end' ||
        f.subscription_cancel.proration_behavior !== 'none') fail('portal_configuration_invalid');
    // A future enabled Portal feature must not silently expand the approved surface.
    const known = new Set(['customer_update', 'subscription_update', 'payment_method_update', 'invoice_history', 'subscription_cancel']);
    for (const [key, value] of Object.entries(f)) if (!known.has(key) && (!record(value) || value.enabled !== false)) fail('portal_configuration_invalid');
    const cancel = f.subscription_cancel as typeof f.subscription_cancel & Data;
    if (cancel.retention !== undefined && cancel.retention !== null) fail('portal_configuration_invalid');
    if (Object.entries(cancel).some(([key, value]) => /coupon|promotion|offer|discount/i.test(key) &&
        value !== undefined && value !== null)) fail('portal_configuration_invalid');
    const reasons = cancel.cancellation_reason;
    if (!record(reasons) || typeof reasons.enabled !== 'boolean' || (reasons.enabled &&
        (!Array.isArray(reasons.options) || reasons.options.length === 0 ||
         new Set(reasons.options).size !== reasons.options.length || reasons.options.some((reason: unknown) => !REASON_OPTIONS.has(String(reason)))))) fail('portal_configuration_invalid');
    return config;
  }
  function verifySubscription(sub: Stripe.Subscription, customer: string, uid: string, subject: string) {
    testOnly(sub); ref(sub.id, 'sub');
    if (ref(sub.customer, 'cus') !== customer) fail('customer_unresolved');
    // Task4 terminal Test history predates previewFirebaseUid. Recognize only
    // absent UID on same-Customer scoped terminal records; never manage them,
    // infer ownership from email, or rewrite historical Stripe metadata.
    const legacyTerminal = sub.status === 'canceled' || sub.status === 'incomplete_expired';
    verifyBinding(sub.metadata, uid, subject, true, legacyTerminal);
    // The approved cancel_at_period_end contract is classic billing. Older
    // pinned API responses omit billing_mode; explicit flexible mode is not equivalent.
    const billingMode = (sub as any).billing_mode;
    if (billingMode !== undefined && billingMode !== null && billingMode.type !== 'classic') fail('subscription_unresolved');
    if (typeof sub.metadata.previewAttempt !== 'string' || !sub.metadata.previewAttempt ||
        sub.metadata.previewAttempt.length > 200 || !KNOWN_STATUSES.has(sub.status)) fail('subscription_unresolved');
    if (!Array.isArray(sub.items?.data) || sub.items.data.length !== 1 || sub.items.has_more ||
        sub.items.data[0].quantity !== 1 || sub.items.data[0].price?.id !== d.priceId ||
        sub.items.data[0].price?.unit_amount !== 550 || sub.items.data[0].price?.currency !== 'jpy' ||
        sub.items.data[0].price?.tax_behavior !== 'inclusive' ||
        sub.items.data[0].price?.recurring?.interval !== 'month' ||
        sub.items.data[0].price?.recurring?.interval_count !== 1 ||
        sub.automatic_tax?.enabled !== false || sub.discount || sub.discounts?.length ||
        sub.default_tax_rates?.length) fail('price_mismatch');
    const item = sub.items.data[0] as Stripe.SubscriptionItem & Data;
    const start = (sub as any).current_period_start ?? item.current_period_start;
    const end = (sub as any).current_period_end ?? item.current_period_end;
    if ((sub.trial_end !== null && sub.trial_end !== undefined &&
          (!Number.isSafeInteger(sub.trial_end) || sub.trial_end <= 0)) ||
        (sub.status === 'trialing' && !sub.trial_end)) fail('subscription_unresolved');
    if (!Number.isSafeInteger(start) || start <= 0 || !Number.isSafeInteger(end) || end <= start ||
        typeof sub.cancel_at_period_end !== 'boolean') fail('subscription_unresolved');
    // Portal management is not an entitlement grant. An expired paid period must
    // still allow payment-method management rather than inventing a grace period.
  }
  return {
    async create(identity: (Pick<Identity, 'uid' | 'emailVerified'> & Partial<Pick<Identity, 'email'>>) | null | undefined): Promise<{testMode: true; url: string}> {
      try {
        if (!identity || typeof identity.uid !== 'string' || identity.uid.length > 128 ||
            !/^[^/\s\u0000-\u001f\u007f]+$/u.test(identity.uid)) fail('unauthenticated');
        if (identity.emailVerified !== true) fail('email_unverified');
        const now = d.now();
        if (!(now instanceof Date) || !Number.isSafeInteger(now.getTime()) || now.getTime() <= 0) fail('server_clock_invalid');
        const uid = identity.uid; const subject = hash(uid);
        verifyApplicationBilling(await d.readFacts(uid));
        const stored = await d.store.read(subject);
        if (!record(stored) || stored.previewFirebaseUid !== uid || typeof stored.customerId !== 'string') fail('customer_unresolved');
        const customerId = ref(stored.customerId, 'cus');
        const customer = await d.stripe.customers.retrieve(customerId);
        if ('deleted' in customer && customer.deleted) fail('customer_unresolved');
        testOnly(customer);
        if (customer.id !== customerId) fail('customer_unresolved');
        verifyBinding(customer.metadata, uid, subject, false);
        if (customer.balance !== 0 || customer.discount || (customer as any).discounts?.length) fail('price_mismatch');
        await verifyWebhook(); await verifyPrice(); await verifyConfiguration();
        const listed = await d.stripe.subscriptions.list({customer: customerId, status: 'all', limit: 100});
        if (listed.has_more || !Array.isArray(listed.data)) fail('subscription_unresolved');
        for (const sub of listed.data) verifySubscription(sub, customerId, uid, subject);
        const manageable = listed.data.filter(sub => (PREVIEW_PORTAL_MANAGEABLE_STATUSES as readonly string[]).includes(sub.status));
        const selected = selectPreferredPaidSubscription(manageable) ??
          [...manageable].sort((a, b) => b.created - a.created)[0];
        if (!selected) fail('portal_not_available');
        // Retrieve after selection: a cancel racing the list must not resurrect management eligibility.
        const canonical = await d.stripe.subscriptions.retrieve(selected.id);
        verifySubscription(canonical, customerId, uid, subject);
        if (canonical.id !== selected.id) fail('subscription_unresolved');
        if (!(PREVIEW_PORTAL_MANAGEABLE_STATUSES as readonly string[]).includes(canonical.status)) fail('portal_not_available');
        // Stripe owns URL expiry. Each action creates a fresh Session without
        // idempotency reuse; no URL is retained in application storage or logs.
        const session = await d.stripe.billingPortal.sessions.create({
          customer: customerId, configuration: d.configurationId,
          return_url: PREVIEW_PORTAL_RETURN_URL, locale: 'ja',
        });
        testOnly(session);
        if (session.customer !== customerId || ref(session.configuration, 'bpc') !== d.configurationId ||
            session.return_url !== PREVIEW_PORTAL_RETURN_URL || session.locale !== 'ja' ||
            session.flow !== null || session.on_behalf_of !== null ||
            !isPreviewPortalSessionUrl(session.url)) fail('portal_unavailable');
        return {testMode: true, url: session.url};
      } catch (error) {
        if (error instanceof CheckoutError) throw error;
        // Never leak Stripe errors, account data, object references, or Session URLs.
        fail('portal_unavailable');
      }
    },
  };
}
