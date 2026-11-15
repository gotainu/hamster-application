import { projectAccountIdentity, isVerifiedAccountIdentity } from './account-identity.mjs';
import { maskEmail, loginMethods, safeAuthError, summarizeAccount } from './account-model.mjs';

const APPLE_REDIRECT_CONSENT_KEY = 'hamcare.apple-redirect-consent.v1';
const APPLE_CONSENT_VERSION = 'apple-linking-v1';
const APPLE_REDIRECT_CONSENT_TTL = 15 * 60 * 1000;

/** Cross-origin auth helpers cannot reliably use third-party storage in Safari.
 * The current web.app Preview therefore uses Firebase's official Popup option.
 * Redirect is reserved for a same-origin fixed authDomain on mobile Safari. */
export function selectAppleSignInMethod({pageOrigin, authDomain, userAgent = '', platform = '', maxTouchPoints = 0, redirectStateAvailable = false} = {}) {
  if (typeof pageOrigin !== 'string' || typeof authDomain !== 'string' || redirectStateAvailable !== true) return 'popup';
  let page;
  try {page = new URL(pageOrigin);} catch {return 'popup';}
  if (page.protocol !== 'https:' || page.origin !== pageOrigin || page.username || page.password ||
      page.origin !== `https://${authDomain}` || !/^[a-z0-9.-]+$/.test(authDomain)) return 'popup';
  const ios = /iPhone|iPad|iPod/i.test(userAgent) || (platform === 'MacIntel' && maxTouchPoints > 1);
  const safari = /Safari/i.test(userAgent) && !/CriOS|FxiOS|EdgiOS|OPiOS|Chrome|Android/i.test(userAgent);
  return ios && safari ? 'redirect' : 'popup';
}
function browserAppleContext(auth, supplied) {
  let storage = null;
  try {storage = Object.prototype.hasOwnProperty.call(supplied, 'storage') ? supplied.storage : globalThis.sessionStorage;} catch { /* Popup remains available without storage. */ }
  return {
    pageOrigin: supplied.pageOrigin ?? globalThis.location?.origin,
    authDomain: supplied.authDomain ?? auth.config?.authDomain,
    userAgent: supplied.userAgent ?? globalThis.navigator?.userAgent ?? '',
    platform: supplied.platform ?? globalThis.navigator?.platform ?? '',
    maxTouchPoints: supplied.maxTouchPoints ?? globalThis.navigator?.maxTouchPoints ?? 0,
    storage,
    now: supplied.now ?? (() => Date.now()),
  };
}

// Auth owns tokens/persistence; Firestore Lite always reads from the server.
// No Firestore writer, Functions callable, Stripe API, or account-linking API.
export function createAccountService({ auth, db, sdk, appleSignInEnabled = false, appleAuthContext = {} }) {
  const listeners = new Set();
  const appleEnabled = appleSignInEnabled === true;
  const appleContext = browserAppleContext(auth, appleAuthContext);
  let bootstrapPending = appleEnabled;
  let epoch = 0;
  let socialPending = false;
  let emailPending = false;
  let signingOut = false;
  let logoutGeneration = 0;
  let newSocialUser = false;
  let readyPromise;
  let identitySnapshot = null;
  let identityPending = false;
  const validUser = user => user && typeof user.uid === 'string' && user.uid.length <= 128 && /^[^/\s\u0000-\u001f\u007f]+$/u.test(user.uid);
  const hasAppleProvider = user => Array.isArray(user?.providerData) && user.providerData.some(item => item?.providerId === 'apple.com');
  const safeUser = () => validUser(auth.currentUser) && identitySnapshot?.user === auth.currentUser && identitySnapshot.epoch === epoch && !identityPending && !bootstrapPending && !socialPending && !emailPending && !signingOut ? {
    emailVerified: auth.currentUser.emailVerified === true,
    identityVerified: identitySnapshot.identityVerified,
    authenticationBasis: identitySnapshot.authenticationBasis,
    identityCheckFailed: identitySnapshot.identityCheckFailed,
    maskedEmail: maskEmail(auth.currentUser.email),
    methods: loginMethods(auth.currentUser.providerData),
    isNewUser: newSocialUser,
  } : null;
  const emit = () => { for (const listener of listeners) listener(safeUser()); };
  const requireIdle = () => { if (bootstrapPending || identityPending || socialPending || emailPending || signingOut) throw {code: 'account/signin-in-progress'}; };
  function invalidateIdentity() { identitySnapshot = null; identityPending = false; }
  async function freshIdentity(user, generation) {
    const result = await sdk.getIdTokenResult(user, true);
    if (epoch !== generation || auth.currentUser !== user || auth.currentUser?.uid !== user.uid) throw {code: 'account/session-changed'};
    const identity = projectAccountIdentity(user, result, auth.app?.options?.projectId);
    identitySnapshot = {user, epoch: generation, ...identity};
    return identity;
  }
  async function publishIdentity() {
    const user = auth.currentUser;
    const generation = epoch;
    invalidateIdentity();
    if (!validUser(user) || bootstrapPending || socialPending || emailPending || signingOut) { emit(); return; }
    identityPending = true;
    emit();
    try { await freshIdentity(user, generation); }
    catch {
      if (epoch === generation && auth.currentUser === user) identitySnapshot = {user, epoch: generation, identityVerified: false, authenticationBasis: null, identityCheckFailed: true};
    } finally {
      if (epoch === generation && auth.currentUser === user) { identityPending = false; emit(); }
    }
  }
  async function discardLateSignIn() {
    signingOut = true;
    newSocialUser = false;
    epoch++; invalidateIdentity(); emit();
    await sdk.signOut(auth);
    signingOut = false;
  }
  function readRedirectConsent() {
    try {return appleContext.storage?.getItem(APPLE_REDIRECT_CONSENT_KEY) ?? null;} catch {return null;}
  }
  function clearRedirectConsent() {
    try {appleContext.storage?.removeItem(APPLE_REDIRECT_CONSENT_KEY);} catch { /* No credential is stored here. */ }
  }
  function validRedirectConsent(raw) {
    try {
      const marker = JSON.parse(raw);
      const now = appleContext.now();
      return marker?.version === APPLE_CONSENT_VERSION && marker.accepted === true &&
        marker.method === 'redirect' && Object.keys(marker).sort().join(',') === 'accepted,method,startedAt,version' &&
        Number.isSafeInteger(marker.startedAt) && Number.isSafeInteger(now) &&
        marker.startedAt > 0 && marker.startedAt <= now && now - marker.startedAt < APPLE_REDIRECT_CONSENT_TTL;
    } catch {return false;}
  }
  function appleMethod() {
    const storage = appleContext.storage;
    let available = false;
    try {
      available = !!storage && typeof storage.getItem === 'function' && typeof storage.setItem === 'function' && typeof storage.removeItem === 'function';
      if (available) storage.getItem(APPLE_REDIRECT_CONSENT_KEY);
    } catch {available = false;}
    return selectAppleSignInMethod({...appleContext, redirectStateAvailable: available});
  }
  function validateAppleResult(result) {
    return validUser(result?.user) && validUser(auth.currentUser) &&
      result.user.uid === auth.currentUser.uid && hasAppleProvider(result.user) && hasAppleProvider(auth.currentUser);
  }
  async function resumeAppleRedirect() {
    if (!appleEnabled) return;
    const raw = readRedirectConsent();
    if (raw === null) return;
    const startedBeforeLogout = logoutGeneration;
    socialPending = true;
    try {
      // This short-lived nonsecret marker only carries the UI's explicit consent
      // across navigation. It never replaces Firebase's OAuth state/nonce/CSRF.
      if (!validRedirectConsent(raw)) {
        await discardLateSignIn();
        throw {code: 'account/apple-consent-required'};
      }
      if (appleMethod() !== 'redirect') {
        await discardLateSignIn();
        throw {code: 'account/apple-redirect-unavailable'};
      }
      const result = await sdk.getRedirectResult(auth);
      if (startedBeforeLogout !== logoutGeneration) {await discardLateSignIn(); return;}
      if (!validRedirectConsent(raw) || readRedirectConsent() !== raw) {
        await discardLateSignIn();
        throw {code: 'account/apple-consent-required'};
      }
      if (!result) {await discardLateSignIn(); throw {code: 'auth/popup-closed-by-user'};}
      if (!validateAppleResult(result)) {await discardLateSignIn(); throw {code: 'account/apple-identity-invalid'};}
      newSocialUser = sdk.getAdditionalUserInfo(result)?.isNewUser === true;
    } catch (error) {
      if (auth.currentUser && !signingOut) await discardLateSignIn();
      throw error;
    } finally {clearRedirectConsent(); socialPending = false;}
  }
  async function signInSocial(kind, consent) {
    // Standard trusted-provider linking is permitted only after explicit UI
    // consent. This public build capability is not a project-wide Auth firewall.
    if (kind === 'apple' && !appleEnabled) throw {code: 'account/apple-setup-required'};
    if (kind === 'apple' && (!consent || typeof consent !== 'object' || Array.isArray(consent) ||
        !Object.prototype.hasOwnProperty.call(consent, 'linkingConsent') ||
        consent.linkingConsent !== true || Object.keys(consent).some(key => key !== 'linkingConsent'))) throw {code: 'account/apple-consent-required'};
    requireIdle();
    const startedBeforeLogout = logoutGeneration;
    socialPending = true;
    signingOut = false;
    epoch++; invalidateIdentity(); emit();
    let leavingForRedirect = false;
    try {
      const provider = kind === 'apple' ? new sdk.OAuthProvider('apple.com') : new sdk.GoogleAuthProvider();
      if (kind === 'apple') {
        provider.addScope('email');
        provider.addScope('name');
        provider.setCustomParameters({locale: 'ja'});
      } else provider.setCustomParameters({prompt: 'select_account'});
      // Delegate OAuth state/session/nonce to Firebase's standard Popup/handler;
      // the actual Apple flow has not yet been verified. Never extract or persist
      // Apple tokens, authorization codes, subjects or names.
      if (kind === 'apple' && appleMethod() === 'redirect') {
        const marker = JSON.stringify({version: APPLE_CONSENT_VERSION, accepted: true, method: 'redirect', startedAt: appleContext.now()});
        try {
          if (!validRedirectConsent(marker)) throw new Error('invalid-marker');
          appleContext.storage.setItem(APPLE_REDIRECT_CONSENT_KEY, marker);
          if (readRedirectConsent() !== marker) throw new Error('marker-not-retained');
        } catch {clearRedirectConsent(); throw {code: 'account/apple-redirect-unavailable'};}
        await sdk.signInWithRedirect(auth, provider);
        leavingForRedirect = true;
        return {redirecting: true};
      }
      const result = await sdk.signInWithPopup(auth, provider);
      if (startedBeforeLogout !== logoutGeneration) {
        await discardLateSignIn();
        return;
      }
      if (kind === 'apple' && !validateAppleResult(result)) {
        await discardLateSignIn();
        throw {code: 'account/apple-identity-invalid'};
      }
      newSocialUser = sdk.getAdditionalUserInfo(result)?.isNewUser === true;
    } finally {
      if (!leavingForRedirect) {clearRedirectConsent(); socialPending = false; epoch++; await publishIdentity();}
    }
  }
  sdk.onAuthStateChanged(auth, () => { epoch++; if (!auth.currentUser) newSocialUser = false; void publishIdentity(); });
  return {
    get appleSignInEnabled() { return appleEnabled; },
    get appleSignInMethod() { return appleMethod(); },
    ready() {
      readyPromise ??= sdk.setPersistence(auth, sdk.browserSessionPersistence).then(() => auth.authStateReady()).then(async () => {
        try {await resumeAppleRedirect();}
        finally {bootstrapPending = false; epoch++; await publishIdentity();}
      });
      return readyPromise;
    },
    onAuthChanged(callback) { listeners.add(callback); callback(safeUser()); return () => listeners.delete(callback); },
    async signInEmail(email, password) {
      requireIdle();
      const startedBeforeLogout = logoutGeneration;
      newSocialUser = false;
      signingOut = false;
      emailPending = true;
      epoch++; invalidateIdentity(); emit();
      try {
        await sdk.signInWithEmailAndPassword(auth, email.trim(), password);
        if (startedBeforeLogout !== logoutGeneration) await discardLateSignIn();
      } finally { emailPending = false; epoch++; await publishIdentity(); }
    },
    signInGoogle() { return signInSocial('google'); },
    signInApple(consent) { return signInSocial('apple', consent); },
    async signOut() {
      logoutGeneration++;
      clearRedirectConsent();
      signingOut = true;
      epoch++; invalidateIdentity();
      // Clear visible details immediately even if the network sign-out fails.
      for (const listener of listeners) listener(null);
      await sdk.signOut(auth);
      newSocialUser = false;
      signingOut = false;
      epoch++; await publishIdentity();
    },
    async reloadUser() {
      const user = auth.currentUser;
      if (!validUser(user)) { epoch++; await publishIdentity(); return; }
      const uid = user.uid;
      await sdk.reload(user);
      if (auth.currentUser?.uid !== uid) return;
      epoch++; await publishIdentity();
    },
    async readAccountSummary() {
      const user = auth.currentUser;
      if (bootstrapPending || identityPending || socialPending || emailPending || signingOut || !validUser(user)) throw { code: 'account/session-changed' };
      const uid = user.uid;
      const generation = epoch;
      const identity = await freshIdentity(user, generation);
      if (!isVerifiedAccountIdentity(identity)) throw {code: 'account/identity-unverified'};
      // Same account-existence authority as the server's readPreviewFacts.
      // The pet's profile contents are not used, only document existence.
      const paths = { owner: ['owner_profiles', 'main'], billing: ['billing', 'subscription'], trial: ['feature_access', 'initial_trial_v2'], pet: ['pet_profiles', 'main_pet'] };
      const entries = await Promise.all(Object.entries(paths).map(async ([name, [collection, document]]) => {
        try {
          const snap = await sdk.getDoc(sdk.doc(db, 'users', uid, collection, document));
          return [name, snap.exists() ? name === 'pet' ? {kind: 'found'} : { kind: 'found', data: snap.data() } : { kind: 'missing' }];
        } catch (error) { return [name, { kind: error?.code === 'permission-denied' ? 'denied' : 'unavailable' }]; }
      }));
      if (epoch !== generation || auth.currentUser !== user || auth.currentUser?.uid !== uid) throw { code: 'account/session-changed' };
      return {...summarizeAccount(user, Object.fromEntries(entries)), identityVerified: identity.identityVerified, authenticationBasis: identity.authenticationBasis};
    },
    safeError: safeAuthError,
  };
}
