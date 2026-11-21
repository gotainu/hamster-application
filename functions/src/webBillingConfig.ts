/** Production Web billing has no credential, Price or URL fallback. Importing
 * this module is safe without configuration; each operation must parse first. */
export const WEB_BILLING_ORIGIN = 'https://hamster-breeding-app.web.app';
export const WEB_BILLING_RETURN_URL = WEB_BILLING_ORIGIN + '/account/';
export const WEB_BILLING_PORTAL_RETURN_URL = WEB_BILLING_RETURN_URL + '?portal=return';

export interface WebBillingConfig {
  secretKey: string;
  publishableKey: string;
  /** The new 550 JPY Price, checked again against the Live Stripe object. */
  priceId: string;
  /** Recognition for existing contract management only; never new Checkout. */
  legacyPriceId?: string;
  webhookSecret: string;
  portalConfigurationId: string;
  origin: string;
  returnUrl: string;
}

export class BillingConfigurationError extends Error {
  readonly code = 'unavailable';
  constructor() {
    super('現在お申し込みを受け付けていません。');
    this.name = 'BillingConfigurationError';
  }
}
function fail(): never {throw new BillingConfigurationError();}
const object = (value: unknown): value is Record<string, unknown> => !!value && typeof value === 'object' && !Array.isArray(value);
const clean = (value: unknown): value is string => typeof value === 'string' && value.length > 0 && value.length <= 4096 && value === value.trim() && !/[\s\u0000-\u001f\u007f]/u.test(value);
function required(value: unknown, pattern: RegExp): string {
  if (!clean(value) || !pattern.test(value)) fail();
  return value;
}
function stripeId(value: unknown, prefix: string): string {
  const id = required(value, new RegExp('^' + prefix + '_[A-Za-z0-9_]{1,240}$'));
  // Stripe IDs do not themselves prove mode. Explicit Test/Preview placeholders
  // are rejected here; every retrieved object must also prove livemode below.
  if (/(?:^|_)(?:test|preview|localhost)(?:_|$)/i.test(id)) fail();
  return id;
}

/** The caller explicitly maps production-only environment values to these
 * fields. No process.env reads, Test credentials or default origin exist here. */
export function parseWebBillingConfig(raw: Record<string, unknown>): WebBillingConfig {
  if (!object(raw)) fail();
  const keys = new Set(['secretKey','publishableKey','priceId','legacyPriceId','webhookSecret','portalConfigurationId','origin','returnUrl']);
  if (Object.keys(raw).some(key=>!keys.has(key))) fail();
  const secretKey = required(raw.secretKey, /^sk_live_[A-Za-z0-9]{1,240}$/);
  const publishableKey = required(raw.publishableKey, /^pk_live_[A-Za-z0-9]{1,240}$/);
  const priceId = stripeId(raw.priceId, 'price');
  const legacyPriceId = raw.legacyPriceId === undefined ? undefined : stripeId(raw.legacyPriceId, 'price');
  if (legacyPriceId === priceId) fail();
  const webhookSecret = required(raw.webhookSecret, /^whsec_[A-Za-z0-9]{1,240}$/);
  const portalConfigurationId = stripeId(raw.portalConfigurationId, 'bpc');
  // Exact string comparison also rejects credentials, ports, fragments, encoded
  // paths, alternate Firebase origins, Preview channels and open redirects.
  if (raw.origin !== WEB_BILLING_ORIGIN ||
      (raw.returnUrl !== WEB_BILLING_RETURN_URL && raw.returnUrl !== WEB_BILLING_PORTAL_RETURN_URL)) fail();
  return Object.freeze({secretKey, publishableKey, priceId,
    ...(legacyPriceId ? {legacyPriceId} : {}), webhookSecret,
    portalConfigurationId, origin:raw.origin, returnUrl:raw.returnUrl});
}

/** A valid key prefix cannot establish the mode of an API response. */
export function assertLiveObject(value: unknown): asserts value is Record<string, any> & {livemode: true} {
  if (!object(value) || value.livemode !== true) fail();
}
