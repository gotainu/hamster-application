import type {Identity} from './engine';

export class PreviewAuthenticationError extends Error {
  constructor(public code: 'unauthenticated' | 'email_unverified') {super(code);}
}
type Data = Record<string, unknown>;
const object = (value: unknown): value is Data => !!value && typeof value === 'object' && !Array.isArray(value);
export const validPreviewUid = (value: unknown): value is string => typeof value === 'string' && value.length <= 128 && /^[^/\s\u0000-\u001f\u007f]+$/u.test(value);
const validProviderUid = (value: unknown): value is string => typeof value === 'string' && value.length > 0 && value.length <= 1024 && !/[\s\u0000-\u001f\u007f]/u.test(value);
function reject(code: 'unauthenticated' | 'email_unverified'): never {throw new PreviewAuthenticationError(code);}
/** Caller must first verify this Firebase ID token with Admin verifyIdToken(...,
 * true), then read the same UID via Admin getUser. Token signature, aud/iss/sub
 * and revocation are Admin SDK responsibilities, never client assertions.
 * No Auth or application record is changed; emailVerified keeps its real value. */
export function authorizePreviewIdentity(verifiedToken: unknown, adminUser: unknown): Identity {
  if (!object(verifiedToken) || !object(adminUser) || !validPreviewUid(verifiedToken.uid) ||
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
