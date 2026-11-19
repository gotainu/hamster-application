import { createPreviewCheckoutService } from './checkout-service.mjs';
import { firebaseConfig } from './firebase-web-config.mjs';
import { createAccountService } from './account-service.mjs';
import { mountAccountPage } from './account-view.mjs';
import { safeAuthError } from './account-model.mjs';
import { createBillingContactService } from './billing-contact-service.mjs';

try {
  // Pin the existing project SDK version. No Analytics or custom credential storage.
  const [appSDK, authSDK, dbSDK] = await Promise.all([
    import('https://www.gstatic.com/firebasejs/12.17.1/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/12.17.1/firebase-auth.js'),
    import('https://www.gstatic.com/firebasejs/12.17.1/firebase-firestore-lite.js'),
  ]);
  appSDK.setLogLevel('silent');
  dbSDK.setLogLevel('silent');
  const app = appSDK.initializeApp(firebaseConfig, { name: 'hamcare-web-preview', automaticDataCollectionEnabled: false });
  const auth = authSDK.initializeAuth(app, { persistence: authSDK.browserSessionPersistence, popupRedirectResolver: authSDK.browserPopupRedirectResolver });
  auth.languageCode = 'ja';
  const db = dbSDK.getFirestore(app);
  const service = createAccountService({ auth, db, appleSignInEnabled: true, sdk: { ...authSDK, getDoc: dbSDK.getDoc, doc: dbSDK.doc } });
  const checkoutService = createPreviewCheckoutService({auth, readOwnProfiles: async uid => {
    const [owner, pet] = await Promise.all([
      dbSDK.getDoc(dbSDK.doc(db, 'users', uid, 'owner_profiles', 'main')),
      dbSDK.getDoc(dbSDK.doc(db, 'users', uid, 'pet_profiles', 'main_pet')),
    ]);
    return {ownerExists: owner.exists(), petExists: pet.exists()};
  }});
  const resumeCheckout = new URLSearchParams(location.search).get('checkout') === 'return';
  const contactReturn = new URLSearchParams(location.search).get('contact') === 'verified';
  if (resumeCheckout || contactReturn) history.replaceState(null, '', '/account/');
  const contactService = createBillingContactService({auth});
  await mountAccountPage(service, {checkoutService, contactService, resumeCheckout});
} catch (error) {
  // Never print Firebase errors, identifiers, addresses, or tokens.
  document.getElementById('loading-title').textContent = '現在ログインできません';
  document.getElementById('loading-copy').textContent = '通信を確認して、ページを再読込してください。';
  const notice = document.getElementById('auth-error');
  notice.textContent = safeAuthError(error);
  notice.hidden = false;
}
