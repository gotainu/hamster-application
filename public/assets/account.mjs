import { createPreviewCheckoutService } from './checkout-service.mjs';
import { firebaseConfig } from './firebase-web-config.mjs';
import { createAccountService } from './account-service.mjs';
import { mountAccountPage } from './account-view.mjs';
import { safeAuthError } from './account-model.mjs';

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
  const service = createAccountService({ auth, db, sdk: { ...authSDK, getDoc: dbSDK.getDoc, doc: dbSDK.doc } });
  const checkoutService = createPreviewCheckoutService({auth});
  const resumeCheckout = new URLSearchParams(location.search).get('checkout') === 'return';
  if (resumeCheckout) history.replaceState(null, '', '/account/');
  await mountAccountPage(service, {checkoutService, resumeCheckout});
} catch (error) {
  // Never print Firebase errors, identifiers, addresses, or tokens.
  document.getElementById('loading-title').textContent = '現在ログインできません';
  document.getElementById('loading-copy').textContent = '通信を確認して、ページを再読込してください。';
  const notice = document.getElementById('auth-error');
  notice.textContent = safeAuthError(error);
  notice.hidden = false;
}
