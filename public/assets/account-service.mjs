import { maskEmail, loginMethods, safeAuthError, summarizeAccount } from './account-model.mjs';

// Auth owns tokens/persistence; Firestore Lite always reads from the server.
// No Firestore writer, Functions callable, Stripe API, or account-linking API.
export function createAccountService({ auth, db, sdk, appleSignInEnabled = false }) {
  const listeners = new Set();
  const appleEnabled = appleSignInEnabled === true;
  let epoch = 0;
  let socialPending = false;
  let emailPending = false;
  let signingOut = false;
  let logoutGeneration = 0;
  let newSocialUser = false;
  let readyPromise;
  const validUser = user => user && typeof user.uid === 'string' && user.uid.length <= 128 && /^[^/\s\u0000-\u001f\u007f]+$/u.test(user.uid);
  const hasAppleProvider = user => Array.isArray(user?.providerData) && user.providerData.some(item => item?.providerId === 'apple.com');
  const safeUser = () => validUser(auth.currentUser) && !socialPending && !emailPending && !signingOut ? {
    emailVerified: auth.currentUser.emailVerified === true,
    maskedEmail: maskEmail(auth.currentUser.email),
    methods: loginMethods(auth.currentUser.providerData),
    isNewUser: newSocialUser,
  } : null;
  const emit = () => { for (const listener of listeners) listener(safeUser()); };
  const requireIdle = () => { if (socialPending || emailPending || signingOut) throw {code: 'account/signin-in-progress'}; };
  async function discardLateSignIn() {
    signingOut = true;
    newSocialUser = false;
    epoch++; emit();
    await sdk.signOut(auth);
    signingOut = false;
  }
  async function signInSocial(kind) {
    // This gate is off until Apple configuration, existing-identity testing,
    // and Firebase's trusted-provider auto-linking constraints are resolved.
    // This public build capability stops the normal UI flow; it is not a
    // project-wide security control. Omitting application linking calls cannot
    // disable Firebase's own trusted-provider auto-linking or custom clients.
    if (kind === 'apple' && !appleEnabled) throw {code: 'account/apple-setup-required'};
    requireIdle();
    const startedBeforeLogout = logoutGeneration;
    socialPending = true;
    signingOut = false;
    epoch++; emit();
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
      const result = await sdk.signInWithPopup(auth, provider);
      if (startedBeforeLogout !== logoutGeneration) {
        await discardLateSignIn();
        return;
      }
      if (kind === 'apple' && (!validUser(result?.user) || !validUser(auth.currentUser) ||
          result.user.uid !== auth.currentUser.uid ||
          !hasAppleProvider(result.user) || !hasAppleProvider(auth.currentUser))) {
        await discardLateSignIn();
        throw {code: 'account/apple-identity-invalid'};
      }
      newSocialUser = sdk.getAdditionalUserInfo(result)?.isNewUser === true;
    } finally { socialPending = false; epoch++; emit(); }
  }
  sdk.onAuthStateChanged(auth, () => { epoch++; if (!auth.currentUser) newSocialUser = false; emit(); });
  return {
    get appleSignInEnabled() { return appleEnabled; },
    ready() {
      readyPromise ??= sdk.setPersistence(auth, sdk.browserSessionPersistence).then(() => auth.authStateReady());
      return readyPromise;
    },
    onAuthChanged(callback) { listeners.add(callback); callback(safeUser()); return () => listeners.delete(callback); },
    async signInEmail(email, password) {
      requireIdle();
      const startedBeforeLogout = logoutGeneration;
      newSocialUser = false;
      signingOut = false;
      emailPending = true;
      epoch++; emit();
      try {
        await sdk.signInWithEmailAndPassword(auth, email.trim(), password);
        if (startedBeforeLogout !== logoutGeneration) await discardLateSignIn();
      } finally { emailPending = false; epoch++; emit(); }
    },
    signInGoogle() { return signInSocial('google'); },
    signInApple() { return signInSocial('apple'); },
    async signOut() {
      logoutGeneration++;
      signingOut = true;
      epoch++;
      // Clear visible details immediately even if the network sign-out fails.
      for (const listener of listeners) listener(null);
      await sdk.signOut(auth);
      newSocialUser = false;
      signingOut = false;
    },
    async reloadUser() {
      const user = auth.currentUser;
      if (!validUser(user)) { epoch++; emit(); return; }
      const uid = user.uid;
      await sdk.reload(user);
      if (auth.currentUser?.uid !== uid) return;
      await sdk.getIdToken(user, true);
      if (auth.currentUser?.uid !== uid) return;
      epoch++; emit();
    },
    async readAccountSummary() {
      const user = auth.currentUser;
      if (socialPending || emailPending || signingOut || !validUser(user) || !user.emailVerified) throw { code: 'account/session-changed' };
      const uid = user.uid;
      const generation = epoch;
      // Same account-existence authority as the server's readPreviewFacts.
      // The pet's profile contents are not used, only document existence.
      const paths = { owner: ['owner_profiles', 'main'], billing: ['billing', 'subscription'], trial: ['feature_access', 'initial_trial_v2'], pet: ['pet_profiles', 'main_pet'] };
      const entries = await Promise.all(Object.entries(paths).map(async ([name, [collection, document]]) => {
        try {
          const snap = await sdk.getDoc(sdk.doc(db, 'users', uid, collection, document));
          return [name, snap.exists() ? name === 'pet' ? {kind: 'found'} : { kind: 'found', data: snap.data() } : { kind: 'missing' }];
        } catch (error) { return [name, { kind: error?.code === 'permission-denied' ? 'denied' : 'unavailable' }]; }
      }));
      if (epoch !== generation || auth.currentUser?.uid !== uid || !auth.currentUser?.emailVerified) throw { code: 'account/session-changed' };
      return summarizeAccount(user, Object.fromEntries(entries));
    },
    safeError: safeAuthError,
  };
}
