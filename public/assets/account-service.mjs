import { maskEmail, loginMethods, safeAuthError, summarizeAccount } from './account-model.mjs';

// Auth owns tokens/persistence; Firestore Lite always reads from the server.
// No Firestore writer, Functions callable, Stripe API, or account-linking API.
export function createAccountService({ auth, db, sdk }) {
  const listeners = new Set();
  let epoch = 0;
  let googlePending = false;
  let signingOut = false;
  let logoutGeneration = 0;
  let newGoogleUser = false;
  let readyPromise;
  const safeUser = () => auth.currentUser && !googlePending && !signingOut ? {
    emailVerified: auth.currentUser.emailVerified === true,
    maskedEmail: maskEmail(auth.currentUser.email),
    methods: loginMethods(auth.currentUser.providerData),
    isNewUser: newGoogleUser,
  } : null;
  const emit = () => { for (const listener of listeners) listener(safeUser()); };
  sdk.onAuthStateChanged(auth, () => { epoch++; if (!auth.currentUser) newGoogleUser = false; emit(); });
  return {
    ready() {
      readyPromise ??= sdk.setPersistence(auth, sdk.browserSessionPersistence).then(() => auth.authStateReady());
      return readyPromise;
    },
    onAuthChanged(callback) { listeners.add(callback); callback(safeUser()); return () => listeners.delete(callback); },
    async signInEmail(email, password) {
      newGoogleUser = false;
      signingOut = false;
      await sdk.signInWithEmailAndPassword(auth, email.trim(), password);
    },
    async signInGoogle() {
      const startedBeforeLogout = logoutGeneration;
      googlePending = true;
      signingOut = false;
      epoch++; emit();
      const provider = new sdk.GoogleAuthProvider();
      provider.setCustomParameters({ prompt: 'select_account' });
      try {
        const result = await sdk.signInWithPopup(auth, provider);
        if (startedBeforeLogout !== logoutGeneration) {
          signingOut = true;
          await sdk.signOut(auth);
          return;
        }
        newGoogleUser = sdk.getAdditionalUserInfo(result)?.isNewUser === true;
      } finally { googlePending = false; epoch++; emit(); }
    },
    async signOut() {
      logoutGeneration++;
      signingOut = true;
      epoch++;
      // Clear visible details immediately even if the network sign-out fails.
      for (const listener of listeners) listener(null);
      await sdk.signOut(auth);
      newGoogleUser = false;
      signingOut = false;
    },
    async reloadUser() {
      const user = auth.currentUser;
      if (!user) { epoch++; emit(); return; }
      const uid = user.uid;
      await sdk.reload(user);
      if (auth.currentUser?.uid !== uid) return;
      await sdk.getIdToken(user, true);
      if (auth.currentUser?.uid !== uid) return;
      epoch++; emit();
    },
    async readAccountSummary() {
      const user = auth.currentUser;
      if (googlePending || signingOut || !user?.emailVerified) throw { code: 'account/session-changed' };
      const uid = user.uid;
      const generation = epoch;
      const paths = { owner: ['owner_profiles', 'main'], billing: ['billing', 'subscription'], trial: ['feature_access', 'initial_trial_v2'] };
      const entries = await Promise.all(Object.entries(paths).map(async ([name, [collection, document]]) => {
        try {
          const snap = await sdk.getDoc(sdk.doc(db, 'users', uid, collection, document));
          return [name, snap.exists() ? { kind: 'found', data: snap.data() } : { kind: 'missing' }];
        } catch (error) { return [name, { kind: error?.code === 'permission-denied' ? 'denied' : 'unavailable' }]; }
      }));
      if (epoch !== generation || auth.currentUser?.uid !== uid || !auth.currentUser?.emailVerified) throw { code: 'account/session-changed' };
      return summarizeAccount(user, Object.fromEntries(entries));
    },
    safeError: safeAuthError,
  };
}
