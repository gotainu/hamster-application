import {INITIAL_TRIAL_DURATION_DAYS, INITIAL_TRIAL_POLICY_VERSION} from './trialPolicy';

/** Pure policy for the isolated Stripe Test Mode backend. No external calls,
 * data writes, credentials, Customer identifiers, or application access grant. */
export type PreviewCheckoutPolicyErrorCode =
  | 'unauthenticated' | 'email_unverified' | 'app_account_required'
  | 'plan_not_allowed' | 'billing_unresolved' | 'existing_subscription'
  | 'trial_unresolved' | 'trial_invalid' | 'trial_too_short' | 'server_clock_invalid';

const SAFE_MESSAGES: Record<PreviewCheckoutPolicyErrorCode, string> = {
  unauthenticated: 'HamCareアカウントへログインしてください。',
  email_unverified: 'メールアドレスの確認を完了してください。',
  app_account_required: '先にHamCareアプリでアカウントとペット情報を準備してください。',
  plan_not_allowed: 'このプランは選択できません。',
  billing_unresolved: '現在の契約状態を確認できませんでした。HamCareアプリまたはサポートでご確認ください。',
  existing_subscription: '既存の契約が保存されています。新しい申込ではなく、HamCareアプリで契約をご確認ください。',
  trial_unresolved: '体験状態を確認できませんでした。時間をおいて再度お試しいただくか、サポートへお問い合わせください。',
  trial_invalid: '体験終了日時を確認できませんでした。時間をおいて再度お試しいただくか、サポートへお問い合わせください。',
  trial_too_short: '現在の体験終了日を変更せずにカード登録できる期限を過ぎています。体験終了後に再度お試しください。',
  server_clock_invalid: '現在、申込日時を確認できません。時間をおいて再度お試しください。',
};

export class PreviewCheckoutPolicyError extends Error {
  readonly code: PreviewCheckoutPolicyErrorCode;
  constructor(code: PreviewCheckoutPolicyErrorCode) {
    super(SAFE_MESSAGES[code]);
    this.name = 'PreviewCheckoutPolicyError';
    this.code = code;
  }
}

export interface PreviewCheckoutIdentity {
  /** Firebase Admin-verified identity, never the request body's UID. */
  uid: unknown;
  emailVerified: unknown;
}
export interface PreviewCheckoutSourceDocument {
  kind: 'found' | 'missing' | 'denied' | 'unavailable';
  data?: unknown;
}
export interface PreviewCheckoutPolicyInput {
  identity: PreviewCheckoutIdentity | null | undefined;
  /** Server-read existence of users/{verified uid}/pet_profiles/main_pet. */
  appAccountExists: boolean;
  billing: PreviewCheckoutSourceDocument;
  trial: PreviewCheckoutSourceDocument;
  planKey: unknown;
  /** Server clock, never a browser-supplied timestamp. */
  now: Date;
}
export interface PreviewCheckoutDecision {
  planKey: 'premium_monthly';
  currency: 'jpy';
  unitAmount: 550;
  interval: 'month';
  chargeTiming: 'immediate' | 'trial_end';
  firstChargeAtSeconds: number;
  trialEndSeconds?: number;
  hamcareTrialEndsAtMillis?: number;
}

const PLAN = Object.freeze({
  planKey: 'premium_monthly' as const, currency: 'jpy' as const,
  unitAmount: 550 as const, interval: 'month' as const,
});
const MAX_TRIAL_MILLIS = INITIAL_TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000;
// Stripe API requires >=48h. Allow one minute for request processing instead of
// extending the existing HamCare trial to meet Stripe's minimum.
export const MIN_PREVIEW_TRIAL_REMAINING_SECONDS = 48 * 60 * 60 + 60;
function fail(code: PreviewCheckoutPolicyErrorCode): never {
  throw new PreviewCheckoutPolicyError(code);
}
function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
/** Accept server-native Date or Firestore Timestamp-style values only. */
function timestampMillis(value: unknown): number | null {
  try {
    const millis = value instanceof Date ? value.getTime()
      : isRecord(value) && typeof value.toMillis === 'function' ? value.toMillis() : null;
    return typeof millis === 'number' && Number.isSafeInteger(millis) &&
      millis > 0 && millis <= 8_640_000_000_000_000 ? millis : null;
  } catch { return null; }
}
function requireBillingReady(source: PreviewCheckoutSourceDocument): void {
  if (!isRecord(source)) fail('billing_unresolved');
  if (source.kind === 'missing') return;
  if (source.kind !== 'found' || !isRecord(source.data)) fail('billing_unresolved');
  const data = source.data;
  // A stale period-end does not prove cancellation. The HTTP layer must also
  // recheck Test Mode subscriptions before creating any new Session.
  if (data.plan === 'paid' && (data.status === 'active' || data.status === 'trialing')) fail('existing_subscription');
  if (data.plan !== 'none') fail('billing_unresolved');
  if (data.cancelAtPeriodEnd !== undefined && typeof data.cancelAtPeriodEnd !== 'boolean') fail('billing_unresolved');
  if (data.status === 'canceled') return;
  if (data.status === 'none' && data.cancelAtPeriodEnd !== true) return;
  fail('billing_unresolved');
}
function immediate(nowMillis: number): PreviewCheckoutDecision {
  return {...PLAN, chargeTiming: 'immediate', firstChargeAtSeconds: Math.floor(nowMillis / 1000)};
}

export function assessPreviewCheckout(input: PreviewCheckoutPolicyInput): PreviewCheckoutDecision {
  const identity = input.identity;
  if (!identity || typeof identity.uid !== 'string' || identity.uid.length > 128 ||
      !/^[^/\s\u0000-\u001f\u007f]+$/u.test(identity.uid)) fail('unauthenticated');
  if (identity.emailVerified !== true) fail('email_unverified');
  if (input.appAccountExists !== true) fail('app_account_required');
  if (input.planKey !== PLAN.planKey) fail('plan_not_allowed');
  const nowMillis = timestampMillis(input.now);
  if (nowMillis === null || !(input.now instanceof Date)) fail('server_clock_invalid');
  requireBillingReady(input.billing);
  const source = input.trial;
  if (!isRecord(source)) fail('trial_unresolved');
  if (source.kind === 'missing') return immediate(nowMillis);
  if (source.kind !== 'found' || !isRecord(source.data)) fail('trial_unresolved');
  const data = source.data;
  if (data.status !== 'active' && data.status !== 'expired') fail('trial_unresolved');
  const startMillis = timestampMillis(data.startedAt);
  const endMillis = timestampMillis(data.endsAt);
  if (startMillis === null || endMillis === null || startMillis > nowMillis ||
      endMillis <= startMillis || endMillis - startMillis > MAX_TRIAL_MILLIS) fail('trial_invalid');
  if ((data.trialId !== undefined && data.trialId !== INITIAL_TRIAL_POLICY_VERSION) ||
      (data.policyVersion !== undefined && data.policyVersion !== INITIAL_TRIAL_POLICY_VERSION) ||
      (data.durationDays !== undefined && data.durationDays !== INITIAL_TRIAL_DURATION_DAYS)) fail('trial_invalid');
  if (data.status === 'expired' && endMillis > nowMillis) fail('trial_invalid');
  // Matches isInitialTrialActive: now == endsAt is already expired.
  if (endMillis <= nowMillis) return immediate(nowMillis);
  if (endMillis - nowMillis < MIN_PREVIEW_TRIAL_REMAINING_SECONDS * 1000) fail('trial_too_short');
  // Stripe accepts Unix seconds. Round up by at most 999ms to avoid an early
  // charge; never append another trial period or rewrite HamCare trial data.
  const trialEndSeconds = Math.ceil(endMillis / 1000);
  return {
    ...PLAN, chargeTiming: 'trial_end', firstChargeAtSeconds: trialEndSeconds,
    trialEndSeconds, hamcareTrialEndsAtMillis: endMillis,
  };
}
