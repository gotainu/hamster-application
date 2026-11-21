/** Pure identity, email and checkout policy shared by Preview and production.
 * This module has no credentials, storage, mail delivery or Stripe SDK calls. */
export interface WebBillingIdentity {
  uid: string;
  emailVerified: boolean;
  email?: string;
  authBasis?: 'verified_email' | 'apple_provider';
}

/** Server-produced account ownership for existing-contract management only.
 * firebase_session is deliberately excluded from every purchase/contact proof. */
export type WebBillingManagementIdentity = WebBillingIdentity | {
  uid: string;
  emailVerified: boolean;
  authBasis: 'firebase_session';
};

export class BillingAuthenticationError extends Error {
  constructor(public code: 'unauthenticated' | 'email_unverified') {super(code);}
}
type Data = Record<string, unknown>;
const object = (value: unknown): value is Data => !!value && typeof value === 'object' && !Array.isArray(value);
export const validWebBillingUid = (value: unknown): value is string => typeof value === 'string' && value.length <= 128 && /^[^/\s\u0000-\u001f\u007f]+$/u.test(value);
const validProviderUid = (value: unknown): value is string => typeof value === 'string' && value.length > 0 && value.length <= 1024 && !/[\s\u0000-\u001f\u007f]/u.test(value);
function reject(code: 'unauthenticated' | 'email_unverified'): never {throw new BillingAuthenticationError(code);}
/** Caller must first verify this Firebase ID token with Admin verifyIdToken(...,
 * true), then read the same UID via Admin getUser. Token signature, aud/iss/sub
 * and revocation are Admin SDK responsibilities, never client assertions.
 * No Auth or application record is changed; emailVerified keeps its real value. */
export function authorizeWebBillingIdentity(verifiedToken: unknown, adminUser: unknown): WebBillingIdentity {
  if (!object(verifiedToken) || !object(adminUser) || !validWebBillingUid(verifiedToken.uid) ||
      adminUser.uid !== verifiedToken.uid || adminUser.disabled !== false) reject('unauthenticated');
  const firebase = verifiedToken.firebase;
  const email = typeof adminUser.email === 'string' && adminUser.email.trim() ? adminUser.email : undefined;
  if (object(firebase) && firebase.sign_in_provider === 'apple.com') {
    const identities = firebase.identities;
    const subjects = object(identities) && Object.prototype.hasOwnProperty.call(identities, 'apple.com') ? identities['apple.com'] : undefined;
    const providers = adminUser.providerData;
    if (!Array.isArray(subjects) || subjects.length !== 1 || !validProviderUid(subjects[0]) ||
        !Array.isArray(providers) || providers.some(item => !object(item) || typeof item.providerId !== 'string')) reject('unauthenticated');
    const apple = providers.filter(item => object(item) && item.providerId === 'apple.com');
    if (apple.length !== 1 || !object(apple[0]) || !validProviderUid(apple[0].uid) ||
        apple[0].uid !== subjects[0] || typeof adminUser.emailVerified !== 'boolean') reject('unauthenticated');
    return Object.freeze({uid: verifiedToken.uid, emailVerified: adminUser.emailVerified,
      authBasis: 'apple_provider',
      // Apple identity proof does not prove an unverified email is reachable.
      ...(email && verifiedToken.email_verified === true && adminUser.emailVerified === true ? {email} : {})});
  }
  // A linked Apple provider alone is not evidence that this session used Apple.
  // Email/password, Google and existing non-Apple sessions keep both checks.
  if (!email) reject('unauthenticated');
  if (verifiedToken.email_verified !== true || adminUser.emailVerified !== true) reject('email_unverified');
  return Object.freeze({uid: verifiedToken.uid, emailVerified: true, email, authBasis: 'verified_email'});
}

/** Caller must first perform Admin verifyIdToken(token, true), then getUser for
 * that verified UID, exactly as for purchase authorization. A signed existing
 * Firebase principal owns its UID even when its email is absent/unverified.
 * Current Apple sessions still need the original provider-subject binding.
 * This proof cannot authorize Checkout or establish a reachable contact. */
export function authorizeWebBillingManagementIdentity(verifiedToken: unknown, adminUser: unknown): WebBillingManagementIdentity {
  if (!object(verifiedToken) || !object(adminUser) || !validWebBillingUid(verifiedToken.uid) ||
      adminUser.uid !== verifiedToken.uid || adminUser.disabled !== false ||
      typeof adminUser.emailVerified !== 'boolean') reject('unauthenticated');
  if (object(verifiedToken.firebase) && verifiedToken.firebase.sign_in_provider === 'apple.com') {
    return authorizeWebBillingIdentity(verifiedToken, adminUser);
  }
  // Do not call this verified_email or forward an unverified contact address.
  return Object.freeze({uid:verifiedToken.uid, emailVerified:adminUser.emailVerified, authBasis:'firebase_session'});
}

/** Syntax is not proof of identity or deliverability. Neither relay domain is special here. */
export function normalizeBillingEmail(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const email = value.trim();
  if (email.length > 254 || /[^\x21-\x7e]/.test(email)) return null;
  const parts = email.split('@');
  if (parts.length !== 2) return null;
  const [local, domain] = parts;
  if (!local || local.length > 64 || local.startsWith('.') || local.endsWith('.') || local.includes('..') ||
      !/^[A-Za-z0-9.!#$%&'*+\-/=?^_`{|}~]+$/.test(local)) return null;
  if (!domain || domain.length > 253 || !domain.includes('.') || domain.split('.').some(label =>
      !/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(label)) || !/[A-Za-z]{2,}$/.test(domain)) return null;
  return local + '@' + domain.toLowerCase();
}
export function maskBillingEmail(email: string): string {
  const at = email.lastIndexOf('@');
  return email.slice(0, Math.min(2, at)) + '***' + email.slice(at);
}
const relay = (email: string) => ['privaterelay.appleid.com', 'private.icloud.com'].includes(email.slice(email.lastIndexOf('@') + 1).toLowerCase());
const validContactUid = (v: unknown): v is string => typeof v === 'string' && v.length > 0 && v.length <= 128 && !/[\\/\s\u0000-\u001f\u007f]/u.test(v);
export interface BillingEmailClassification {kind: 'A'|'B'|'C'|'unverified'|'invalid'; email?: string; source?: 'auth_verified'|'apple_relay';}

/** Identity must already come from authorizeWebBillingIdentity after Admin token verification. */
export function classifyBillingEmail(identity: WebBillingIdentity, adminUser: unknown): BillingEmailClassification {
  if (!object(adminUser) || !validContactUid(identity?.uid) || adminUser.uid !== identity.uid || adminUser.disabled !== false ||
      !['verified_email', 'apple_provider'].includes(identity.authBasis || '') || !Array.isArray(adminUser.providerData) ||
      adminUser.providerData.some((p: unknown) => !object(p) || typeof p.providerId !== 'string')) return {kind:'invalid'};
  const apple = adminUser.providerData.filter((p: any) => p.providerId === 'apple.com');
  if (identity.authBasis === 'apple_provider' && (apple.length !== 1 || typeof apple[0].uid !== 'string' || !apple[0].uid || /\s/.test(apple[0].uid))) return {kind:'invalid'};
  const absent = adminUser.email === undefined || adminUser.email === null || adminUser.email === '';
  if (absent) {
    // An existing provider email without verified current-session evidence is not "no email".
    if (adminUser.providerData.some((p: any) => p.email !== undefined && p.email !== null && p.email !== '')) return {kind:'unverified'};
    return identity.authBasis === 'apple_provider' && identity.email === undefined ? {kind:'C'} : {kind:'invalid'};
  }
  const email = normalizeBillingEmail(adminUser.email);
  if (!email) return {kind:'invalid'};
  if (adminUser.emailVerified !== true || identity.emailVerified !== true || normalizeBillingEmail(identity.email) !== email) return {kind:'unverified'};
  return identity.authBasis === 'apple_provider' && relay(email)
    ? {kind:'B', email, source:'apple_relay'} : {kind:'A', email, source:'auth_verified'};
}

// Keep one implementation of the fixed 550 JPY plan and original trial boundary.
export {
  assessPreviewCheckout as assessWebCheckout,
  isPreviewIdentityConfirmed as isWebBillingIdentityConfirmed,
  PreviewCheckoutPolicyError as WebCheckoutPolicyError,
  MIN_PREVIEW_TRIAL_REMAINING_SECONDS as MIN_WEB_TRIAL_REMAINING_SECONDS,
} from './previewCheckoutPolicy';
export type {
  PreviewCheckoutPolicyErrorCode as WebCheckoutPolicyErrorCode,
  PreviewCheckoutPolicyInput as WebCheckoutPolicyInput,
  PreviewCheckoutDecision as WebCheckoutDecision,
  PreviewCheckoutSourceDocument as WebCheckoutSourceDocument,
} from './previewCheckoutPolicy';
