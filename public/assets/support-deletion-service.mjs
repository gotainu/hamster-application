// Reuse the project's pinned Firebase Web Authentication SDK and fixed handler.
// There is deliberately no Firestore/profile/pet reader or account-linking API.
export const SUPPORT_DELETION_ENDPOINT = 'https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/confirmSupportAccountDeletion';
export const SUPPORT_DELETION_ORIGIN = 'https://hamster-breeding-app.web.app';
export const ENABLE_SUPPORT_DELETION = false; // Enable only during a separately approved production rollout.

const failure = code => Object.assign(new Error('Support deletion confirmation unavailable'), {code});
const linkedApple = user => Array.isArray(user?.providerData) && user.providerData.some(item => item?.providerId === 'apple.com');
const appleSubject = user => user?.providerData?.find(item => item?.providerId === 'apple.com')?.uid;
const validUser = user => typeof user?.uid === 'string' && user.uid.length > 0 && user.uid.length <= 128 && !/[\s/\u0000-\u001f\u007f]/u.test(user.uid);

/** Erase the fragment before any SDK import/request; keep the one-use proof in memory only. */
export function consumeSupportDeletionLink(location, history) {
  const fragment = String(location?.hash ?? '');
  history?.replaceState(null, '', location?.pathname || '/account-deletion/confirm/');
  if (fragment.length > 256) return null;
  const params = new URLSearchParams(fragment.replace(/^#/, ''));
  if ([...params.keys()].sort().join(',') !== 'proof,request') return null;
  const requestId = params.get('request'), proof = params.get('proof');
  return /^[a-f0-9]{48}$/.test(requestId ?? '') && /^[a-f0-9]{64}$/.test(proof ?? '') ? Object.freeze({requestId, proof}) : null;
}

export function canUseSupportDeletion(origin, enabled = ENABLE_SUPPORT_DELETION) {
  return enabled === true && origin === SUPPORT_DELETION_ORIGIN;
}

export function createSupportDeletionService({auth, sdk, fetcher = globalThis.fetch, endpoint = SUPPORT_DELETION_ENDPOINT, appleTimeoutMs = 30_000}) {
  let freshUser = null, freshUid = null, appleAccessToken = null, revoked = false, fallbackOffered = false, pending = false;
  const assertSession = user => {
    if (!validUser(user) || auth.currentUser !== user || auth.currentUser?.uid !== user.uid || (freshUser === user && freshUid !== user.uid)) throw failure('session_changed');
  };
  function clear() { freshUser = null; freshUid = null; appleAccessToken = null; revoked = false; fallbackOffered = false; }
  async function signed(result, beforeIdentity) {
    if (sdk.getAdditionalUserInfo(result)?.isNewUser === true) {
      clear(); await sdk.signOut(auth); throw failure('existing_account_required');
    }
    assertSession(result?.user);
    if (beforeIdentity && (result.user.uid !== beforeIdentity.uid || (beforeIdentity.appleSubject && appleSubject(result.user) !== beforeIdentity.appleSubject))) {clear(); throw failure('session_changed');}
    freshUser = result.user;
    freshUid = result.user.uid;
    const credential = sdk.OAuthProvider.credentialFromResult(result);
    appleAccessToken = credential?.providerId === 'apple.com' && typeof credential.accessToken === 'string' ? credential.accessToken : null;
    revoked = false;
    return {appleLinked: linkedApple(freshUser)};
  }
  async function transport(action, link, extra = {}) {
    const user = freshUser;
    assertSession(user);
    const token = await sdk.getIdToken(user, true);
    assertSession(user);
    let response;
    try {
      response = await fetcher(endpoint, {
        method: 'POST', mode: 'cors', credentials: 'omit', cache: 'no-store', referrerPolicy: 'no-referrer',
        headers: {'Content-Type': 'application/json', Authorization: `Bearer ${token}`},
        body: JSON.stringify({action, requestId: link.requestId, proof: link.proof, ...extra}),
      });
    } catch {throw failure('unavailable');}
    assertSession(user);
    let body;
    try {body = await response.json();} catch {throw failure('unavailable');}
    if (!response.ok || (action === 'inspect' ? body?.ok !== true : body?.status !== 'verified')) throw failure('request_unavailable');
    return body;
  }
  async function exclusive(work) {
    if (pending) throw failure('busy');
    pending = true;
    try {return await work();} finally {pending = false;}
  }
  async function revokeWithDeadline(token) {
    let timer;
    const timeout = Number.isSafeInteger(appleTimeoutMs) && appleTimeoutMs > 0 ? Math.min(appleTimeoutMs, 30_000) : 30_000;
    try {
      await Promise.race([sdk.revokeAccessToken(auth, token), new Promise((_, reject) => {
        timer = setTimeout(() => reject(failure('manual_apple_required')), timeout);
      })]);
    } finally {clearTimeout(timer);}
  }
  return {
    async ready() {
      await sdk.setPersistence(auth, sdk.browserSessionPersistence);
      await auth.authStateReady();
      // A persisted login alone is never a fresh ownership confirmation.
      clear();
    },
    async signInEmail(email, password) {
      return exclusive(async () => {
        clear();
        const before = auth.currentUser;
        const beforeIdentity = before ? {uid: before.uid, appleSubject: appleSubject(before)} : null;
        const result = before
          ? await sdk.reauthenticateWithCredential(before, sdk.EmailAuthProvider.credential(email.trim(), password))
          : await sdk.signInWithEmailAndPassword(auth, email.trim(), password);
        return signed(result, beforeIdentity);
      });
    },
    async signInSocial(kind, linkingConsent) {
      return exclusive(async () => {
        clear();
        if (!['apple', 'google'].includes(kind) || (kind === 'apple' && linkingConsent !== true)) throw failure('consent_required');
        const before = auth.currentUser;
        const beforeIdentity = before ? {uid: before.uid, appleSubject: appleSubject(before)} : null;
        const provider = kind === 'apple' ? new sdk.OAuthProvider('apple.com') : new sdk.GoogleAuthProvider();
        if (kind === 'apple') {provider.addScope('email'); provider.setCustomParameters({locale: 'ja'});}
        else provider.setCustomParameters({prompt: 'select_account'});
        const result = before ? await sdk.reauthenticateWithPopup(before, provider) : await sdk.signInWithPopup(auth, provider);
        return signed(result, beforeIdentity);
      });
    },
    inspect(link) {return exclusive(async () => {
      const result = await transport('inspect', link);
      if (typeof result.appleLinked !== 'boolean' || result.appleLinked !== linkedApple(freshUser)) throw failure('request_unavailable');
      return {appleLinked: result.appleLinked};
    });},
    async confirm(link, {intent, manualAppleAcknowledged = false} = {}) {
      return exclusive(async () => {
        if (intent !== true) throw failure('intent_required');
        const user = freshUser;
        const inspection = await transport('inspect', link);
        if (typeof inspection.appleLinked !== 'boolean' || inspection.appleLinked !== linkedApple(user)) throw failure('request_unavailable');
        let appleRevocation = 'not_linked';
        if (inspection.appleLinked) {
          if (manualAppleAcknowledged === true) {
            if (!fallbackOffered) throw failure('manual_apple_unavailable');
            appleAccessToken = null; appleRevocation = 'manual_acknowledged';
          }
          else {
            // Never revoke an arbitrary logged-in account: the server has just
            // matched this fresh Firebase identity to this request's fixed UID.
            try {
              if (!revoked) {
                const subject = appleSubject(user);
                if (!subject || typeof sdk.revokeAccessToken !== 'function') throw failure('manual_apple_required');
                if (!appleAccessToken) {
                  const provider = new sdk.OAuthProvider('apple.com');
                  provider.setCustomParameters({locale: 'ja'});
                  const result = await sdk.reauthenticateWithPopup(user, provider);
                  assertSession(user);
                  if (result?.user?.uid !== user.uid || appleSubject(result.user) !== subject || appleSubject(auth.currentUser) !== subject) throw failure('session_changed');
                  const credential = sdk.OAuthProvider.credentialFromResult(result);
                  appleAccessToken = credential?.providerId === 'apple.com' ? credential.accessToken : null;
                  // Reauthentication must still be this ticket's exact identity.
                  await transport('inspect', link);
                }
                if (typeof appleAccessToken !== 'string' || !appleAccessToken) throw failure('manual_apple_required');
                assertSession(user);
                await revokeWithDeadline(appleAccessToken);
                assertSession(user);
                revoked = true;
              }
              appleRevocation = 'revoked_client_reported';
            } catch (error) {
              if (['session_changed', 'auth/user-mismatch', 'auth/invalid-user-token', 'auth/user-token-expired', 'auth/account-exists-with-different-credential', 'auth/credential-already-in-use'].includes(error?.code)) {clear(); throw failure('session_changed');}
              if (['request_unavailable', 'unavailable'].includes(error?.code)) throw error;
              assertSession(user);
              fallbackOffered = true;
              throw failure('manual_apple_required');
            } finally {appleAccessToken = null;}
          }
        }
        const result = await transport('confirm', link, {confirmText: 'DELETE_MY_ACCOUNT', stopBillingConfirmed: true, appleRevocation});
        if (result.status !== 'verified') throw failure('request_unavailable');
        clear();
        try {await sdk.signOut(auth);} catch { /* The server has already consumed the one-use confirmation. */ }
        return {ok: true, status: 'verified'};
      });
    },
    async signOut() {clear(); await sdk.signOut(auth);},
  };
}
