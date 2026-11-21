import Stripe from 'stripe';
import {assertLiveObject, parseWebBillingConfig, WebBillingConfig} from './webBillingConfig';
import {isWebBillingIdentityConfirmed, validWebBillingUid, WebBillingManagementIdentity} from './webBillingShared';
import {selectPreferredPaidSubscription} from './stripeSubscriptionPriority';

export const WEB_PORTAL_MANAGEABLE_STATUSES = ['trialing', 'active', 'past_due', 'unpaid', 'paused', 'incomplete'] as const;
const KNOWN_STATUSES = new Set<string>([...WEB_PORTAL_MANAGEABLE_STATUSES, 'canceled', 'incomplete_expired']);
const REASONS = new Set(['too_expensive', 'unused', 'missing_features', 'too_complex', 'switched_service', 'other']);
type Data = Record<string, any>;

export class WebBillingPortalError extends Error {
  constructor(public readonly code: 'unauthenticated' | 'email_unverified' | 'portal_not_available' | 'unavailable') {
    super(code); this.name = 'WebBillingPortalError';
  }
}
export interface WebPortalBillingSource {kind: 'found' | 'missing' | 'unavailable'; data?: Data;}
export interface WebBillingPortalDependencies {
  stripe: Stripe;
  config: WebBillingConfig;
  /** The resolver MUST be read-only in this mode, including deleted Customers. */
  resolveCustomer(input: {uid: string; mode: 'require-existing'}): Promise<{customerId: string}>;
  readBilling(uid: string): Promise<WebPortalBillingSource>;
}
function fail(code: 'unauthenticated' | 'email_unverified' | 'portal_not_available' | 'unavailable' = 'unavailable'): never {throw new WebBillingPortalError(code);}
function object(v: unknown): v is Data {return !!v && typeof v === 'object' && !Array.isArray(v);}
function ref(v: unknown, prefix: string): string {
  const id = typeof v === 'string' ? v : object(v) ? v.id : null;
  if (typeof id !== 'string' || !new RegExp('^' + prefix + '_[A-Za-z0-9_]{1,240}$').test(id)) fail();
  return id;
}
function noPreview(metadata: unknown): metadata is Data {
  return object(metadata) && !Object.keys(metadata).some(key => /^preview/i.test(key));
}
/** The UID comes from server verification. An exact current billing anchor is
 * the only compatibility path for old records whose UID metadata is absent. */
function binding(metadata: unknown, uid: string, anchored: boolean): void {
  if (!noPreview(metadata) || (metadata.firebaseUid !== uid &&
      !(anchored && !Object.prototype.hasOwnProperty.call(metadata, 'firebaseUid')))) fail();
}

/** Stripe's Live Portal URL is an opaque bearer URL. Validate its destination
 * and mode without persisting, logging or returning any underlying IDs. */
export function isWebBillingPortalSessionUrl(value: unknown): value is string {
  if (typeof value !== 'string' || value.length > 4096 || value !== value.trim() ||
      !value.startsWith('https://billing.stripe.com/') || /[\\\u0000-\u0020\u007f#]/u.test(value)) return false;
  let url: URL;
  try {url = new URL(value);} catch {return false;}
  if (url.protocol !== 'https:' || url.hostname !== 'billing.stripe.com' || url.port || url.username || url.password || url.hash) return false;
  if (/^\/p\/session\/[A-Za-z0-9_-]+$/.test(url.pathname)) {
    return !url.search && !/^\/p\/session\/(?:test|preview)(?:_|$)/i.test(url.pathname);
  }
  const keys = [...url.searchParams.keys()];
  const secret = url.searchParams.get('secret') || '';
  return url.pathname === '/p/session' && keys.length === 1 && keys[0] === 'secret' &&
    /^[A-Za-z0-9_-]+$/.test(secret) && !/^(?:test|preview)(?:_|$)/i.test(secret);
}

/** Existing-contract management only. No Customer/Subscription creation,
 * application write, email lookup, entitlement sync or Checkout is available. */
export function createWebBillingPortalEngine(d: WebBillingPortalDependencies) {
  // Validate even injected/hand-built objects; the runtime must never substitute
  // a default configuration when the dedicated production one is absent.
  parseWebBillingConfig(d.config as unknown as Record<string, unknown>);
  async function configuration(config: WebBillingConfig) {
    const portal = await d.stripe.billingPortal.configurations.retrieve(config.portalConfigurationId);
    assertLiveObject(portal);
    if (portal.id !== config.portalConfigurationId || portal.active !== true || !noPreview(portal.metadata) ||
        portal.login_page?.enabled !== false ||
        (portal.default_return_url !== null && portal.default_return_url !== config.returnUrl)) fail();
    const f = portal.features;
    if (!object(f) || f.customer_update?.enabled !== false || f.subscription_update?.enabled !== false ||
        f.payment_method_update?.enabled !== true || f.invoice_history?.enabled !== true ||
        f.subscription_cancel?.enabled !== true || f.subscription_cancel.mode !== 'at_period_end' ||
        f.subscription_cancel.proration_behavior !== 'none') fail();
    const known = new Set(['customer_update', 'subscription_update', 'payment_method_update', 'invoice_history', 'subscription_cancel']);
    for (const [key, value] of Object.entries(f)) if (!known.has(key) && (!object(value) || value.enabled !== false)) fail();
    const cancel = f.subscription_cancel as Data;
    if (cancel.retention !== undefined && cancel.retention !== null) fail();
    if (Object.entries(cancel).some(([key, value]) => /coupon|promotion|offer|discount/i.test(key) && value !== null && value !== undefined)) fail();
    const reason = cancel.cancellation_reason;
    if (!object(reason) || typeof reason.enabled !== 'boolean' || (reason.enabled &&
        (!Array.isArray(reason.options) || !reason.options.length || new Set(reason.options).size !== reason.options.length ||
        reason.options.some((v: unknown) => !REASONS.has(String(v)))))) fail();
  }

  return {
    async create(identity: WebBillingManagementIdentity | null | undefined): Promise<{url: string}> {
      try {
        // This is deliberately first: incomplete configuration must not reach
        // either the read-only resolver/Firestore or any Stripe operation.
        const config = parseWebBillingConfig(d.config as unknown as Record<string, unknown>);
        if (!identity || !validWebBillingUid(identity.uid)) fail('unauthenticated');
        // Existing management preserves the older verified-Firebase-session
        // boundary, including users without a verified/contact email. The
        // runtime produces this proof after revocation and same-UID checks;
        // caller data may never supply it. New purchases keep their own policy.
        if (identity.authBasis === 'firebase_session') {
          if (typeof identity.emailVerified !== 'boolean') fail('unauthenticated');
        } else if (!['verified_email', 'apple_provider'].includes(identity.authBasis || '') ||
            !isWebBillingIdentityConfirmed(identity)) fail('email_unverified');
        const uid = identity.uid;
        const source = await d.readBilling(uid);
        if (!object(source) || !['found', 'missing'].includes(source.kind) ||
            (source.kind === 'found' && !object(source.data))) fail();
        const billing = source.kind === 'found' ? source.data! : null;
        if (billing && ((billing.stripeLivemode !== undefined && billing.stripeLivemode !== true) ||
            (billing.firebaseUid !== undefined && billing.firebaseUid !== uid))) fail();
        const resolved = await d.resolveCustomer({uid, mode: 'require-existing'});
        const customerId = ref(resolved.customerId, 'cus');
        const anchoredCustomer = billing?.stripeCustomerId === customerId;
        const customer = await d.stripe.customers.retrieve(customerId);
        if ('deleted' in customer && customer.deleted) fail();
        assertLiveObject(customer);
        if (customer.id !== customerId) fail();
        binding(customer.metadata, uid, anchoredCustomer);
        await configuration(config);

        const checkedPrices = new Map<string, Stripe.Price>();
        async function verifyPrice(embedded: Stripe.Price, subscriptionId: string): Promise<void> {
          assertLiveObject(embedded);
          const priceId = ref(embedded.id, 'price');
          const legacy = priceId === config.legacyPriceId;
          if (priceId !== config.priceId && !legacy) fail();
          if (legacy && !(anchoredCustomer && billing?.stripeSubscriptionId === subscriptionId)) fail();
          function shape(price: Stripe.Price) {
            assertLiveObject(price);
            if (price.id !== priceId || price.type !== 'recurring' || price.unit_amount !== (legacy ? 500 : 550) ||
                price.currency !== 'jpy' || price.recurring?.interval !== 'month' || price.recurring.interval_count !== 1 ||
                (!legacy && price.tax_behavior !== 'inclusive') ||
                !noPreview(price.metadata)) fail();
          }
          shape(embedded);
          if (!checkedPrices.has(priceId)) {
            const price = await d.stripe.prices.retrieve(priceId);
            shape(price);
            const product = typeof price.product === 'string' ? await d.stripe.products.retrieve(ref(price.product, 'prod')) : price.product;
            assertLiveObject(product);
            if (product.deleted || !noPreview(product.metadata)) fail();
            checkedPrices.set(priceId, price);
          }
        }
        async function verifySubscription(sub: Stripe.Subscription) {
          assertLiveObject(sub); ref(sub.id, 'sub');
          if (ref(sub.customer, 'cus') !== customerId || !KNOWN_STATUSES.has(sub.status)) fail();
          binding(sub.metadata, uid, anchoredCustomer && billing?.stripeSubscriptionId === sub.id);
          const mode = (sub as Stripe.Subscription & Data).billing_mode;
          if (mode !== undefined && mode !== null && mode.type !== 'classic') fail();
          if (!Array.isArray(sub.items?.data) || sub.items.data.length !== 1 || sub.items.has_more ||
              sub.items.data[0].quantity !== 1 || typeof sub.cancel_at_period_end !== 'boolean') fail();
          const item = sub.items.data[0] as Stripe.SubscriptionItem & Data;
          const start = (sub as Stripe.Subscription & Data).current_period_start ?? item.current_period_start;
          const end = (sub as Stripe.Subscription & Data).current_period_end ?? item.current_period_end;
          if (!Number.isSafeInteger(start) || start <= 0 || !Number.isSafeInteger(end) || end <= start ||
              (sub.trial_end !== undefined && sub.trial_end !== null && (!Number.isSafeInteger(sub.trial_end) || sub.trial_end <= 0)) ||
              (sub.status === 'trialing' && !sub.trial_end)) fail();
          await verifyPrice(item.price, sub.id);
        }
        const listed = await d.stripe.subscriptions.list({customer: customerId, status: 'all', limit: 100});
        if (listed.has_more || !Array.isArray(listed.data)) fail();
        // A Portal is Customer-wide; every visible historical subscription must
        // belong to this UID and an explicitly recognized Live contract.
        for (const sub of listed.data) await verifySubscription(sub);
        const manageable = listed.data.filter(s => (WEB_PORTAL_MANAGEABLE_STATUSES as readonly string[]).includes(s.status));
        const selected = selectPreferredPaidSubscription(manageable) ?? [...manageable].sort((a, b) => b.created - a.created)[0];
        if (!selected) fail('portal_not_available');
        const canonical = await d.stripe.subscriptions.retrieve(selected.id);
        await verifySubscription(canonical);
        if (canonical.id !== selected.id) fail();
        if (!(WEB_PORTAL_MANAGEABLE_STATUSES as readonly string[]).includes(canonical.status)) fail('portal_not_available');
        const session = await d.stripe.billingPortal.sessions.create({customer: customerId,
          configuration: config.portalConfigurationId, return_url: config.returnUrl, locale: 'ja'});
        assertLiveObject(session);
        if (session.customer !== customerId || ref(session.configuration, 'bpc') !== config.portalConfigurationId ||
            session.return_url !== config.returnUrl || session.locale !== 'ja' || session.flow !== null ||
            session.on_behalf_of !== null || !isWebBillingPortalSessionUrl(session.url)) fail();
        return {url: session.url};
      } catch (error) {
        if (error instanceof WebBillingPortalError) throw error;
        // SDK/configuration/resolver failures never serialize PII, IDs or URLs.
        fail();
      }
    },
  };
}
