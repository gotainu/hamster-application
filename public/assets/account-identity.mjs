// Display/transport preflight only. The server independently verifies signature,
// revocation, the current UID and its Admin-side Apple binding before access.
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const validUid = value => typeof value === 'string' && value.length <= 128 && /^[^/\s\u0000-\u001f\u007f]+$/u.test(value);
const validSubject = value => typeof value === 'string' && value.length <= 1024 && /^[^\s\u0000-\u001f\u007f]+$/u.test(value);
const denied = failed => Object.freeze({identityVerified: false, authenticationBasis: null, identityCheckFailed: failed});

/** Consume only a fresh Firebase SDK token result; never persist claims/subjects. */
export function projectAccountIdentity(user, tokenResult, projectId) {
  const claims = tokenResult?.claims;
  if (!validUid(user?.uid) || typeof projectId !== 'string' || !/^[a-z][a-z0-9-]{4,62}$/.test(projectId) || !object(claims) ||
      claims.aud !== projectId || claims.iss !== 'https://securetoken.google.com/' + projectId || claims.sub !== user.uid ||
      (claims.user_id !== undefined && claims.user_id !== user.uid) || !object(claims.firebase) ||
      typeof tokenResult.signInProvider !== 'string' || tokenResult.signInProvider !== claims.firebase.sign_in_provider) return denied(true);
  if (tokenResult.signInProvider === 'apple.com') {
    const subjects = claims.firebase.identities?.['apple.com'];
    const providers = Array.isArray(user.providerData) ? user.providerData.filter(item => item?.providerId === 'apple.com') : [];
    if (!Array.isArray(subjects) || subjects.length !== 1 || !validSubject(subjects[0]) ||
        !Array.isArray(user.providerData) || user.providerData.some(item => !object(item) || typeof item.providerId !== 'string') ||
        providers.length !== 1 || !validSubject(providers[0].uid) || providers[0].uid !== subjects[0]) return denied(true);
    return Object.freeze({identityVerified: true, authenticationBasis: 'apple_provider', identityCheckFailed: false});
  }
  // A linked Apple identity does not verify this email/Google session.
  if (user.emailVerified === true && claims.email_verified === true && typeof user.email === 'string' && user.email.trim()) {
    return Object.freeze({identityVerified: true, authenticationBasis: 'verified_email', identityCheckFailed: false});
  }
  return denied(false);
}

export function isVerifiedAccountIdentity(value) {
  return value?.identityVerified === true && ['verified_email', 'apple_provider'].includes(value.authenticationBasis);
}
