import {consumeVerificationFragment} from './billing-contact-model.mjs';

// The link proof never enters query strings, browser storage, Firebase, or logs.
const confirmation = consumeVerificationFragment(location, history);
try {
  const [appSDK, authSDK, dbSDK, configModule, accountModule, contactModule, viewModule] = await Promise.all([
    import('https://www.gstatic.com/firebasejs/12.17.1/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/12.17.1/firebase-auth.js'),
    import('https://www.gstatic.com/firebasejs/12.17.1/firebase-firestore-lite.js'),
    import('./firebase-web-config.mjs'), import('./account-service.mjs'),
    import('./billing-contact-service.mjs'), import('./billing-contact-view.mjs'),
  ]);
  appSDK.setLogLevel('silent');dbSDK.setLogLevel('silent');
  const app=appSDK.initializeApp(configModule.firebaseConfig,{name:'hamcare-web-preview',automaticDataCollectionEnabled:false});
  const auth=authSDK.initializeAuth(app,{persistence:authSDK.browserSessionPersistence,popupRedirectResolver:authSDK.browserPopupRedirectResolver});
  auth.languageCode='ja';
  const db=dbSDK.getFirestore(app);
  const accountService=accountModule.createAccountService({auth,db,appleSignInEnabled:true,sdk:{...authSDK,getDoc:dbSDK.getDoc,doc:dbSDK.doc}});
  const contactService=contactModule.createBillingContactService({auth});
  await viewModule.mountBillingContactPage(contactService,{accountService,initialToken:confirmation.token,initialError:confirmation.error});
  confirmation.token=null;
} catch {
  confirmation.token=null;
  document.getElementById('contact-loading-title').textContent='連絡先の確認を開始できません';
  document.getElementById('contact-loading-copy').textContent='通信を確認して、メールの確認リンクを開き直してください。';
}
