#!/usr/bin/env python3
"""Offline Auth and isolated Test Checkout boundaries; not a live payment test."""
from pathlib import Path
from html.parser import HTMLParser
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'public'
AUTH_BASE = 'd969c1955e2861a8eea4a3a4b5a101561532b7b3'
CHECKOUT_BASE = '98f3fb8a6cd8a3fdcee91149ea3a72f2fe404b9a'
APPLE_BASE = 'a2e73511ecef6c3d82aef396fa83fb7286e889a4'
CHECKOUT_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/createPreviewStripeCheckoutSession'
PORTAL_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/createPreviewStripeCustomerPortalSession'
CONTACT_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/previewBillingContactEmail'

def baseline(path, revision=AUTH_BASE):
    return subprocess.check_output(['git','show',f'{revision}:{path}'],cwd=ROOT)

def auth_entry_without_checkout(source):
    """Only exact reviewed Checkout/contact mounts and profile reads may differ."""
    source=(source
        .replace("import { resolveBillingContactEnvironment } from './billing-contact-environment.mjs';\n", '')
        .replace('  const deployment = resolveBillingContactEnvironment(location.origin);\n', '')
        .replace('name: deployment.appName,', "name: 'hamcare-web-preview',")
        .replace("""  // Live purchase/Portal activation is a separate approved rollout. A canonical
  // contact flow must never fall back to the Preview billing endpoints.
  const checkoutService = deployment.testMode ? createPreviewCheckoutService""", '  const checkoutService = createPreviewCheckoutService')
        .replace('  }}) : null;\n', '  }});\n')
        .replace("  const resumePlan = contactReturn && new URLSearchParams(location.search).get('view') === 'plan';\n", '')
        .replace('createBillingContactService({auth,environment:deployment.environment,origin:location.origin})', 'createBillingContactService({auth})')
        .replace('resumeCheckout:deployment.testMode && resumeCheckout,resumePlan', 'resumeCheckout'))
    return (source
        .replace('appleSignInEnabled: true, ', '')
        .replace("import { createPreviewCheckoutService } from './checkout-service.mjs';\n", '')
        .replace("import { createBillingContactService } from './billing-contact-service.mjs';\n", '')
        .replace('  const checkoutService = createPreviewCheckoutService({auth});\n', '')
        .replace("""  const checkoutService = createPreviewCheckoutService({auth, readOwnProfiles: async uid => {
    const [owner, pet] = await Promise.all([
      dbSDK.getDoc(dbSDK.doc(db, 'users', uid, 'owner_profiles', 'main')),
      dbSDK.getDoc(dbSDK.doc(db, 'users', uid, 'pet_profiles', 'main_pet')),
    ]);
    return {ownerExists: owner.exists(), petExists: pet.exists()};
  }});
""", '')
        .replace("  const resumeCheckout = new URLSearchParams(location.search).get('checkout') === 'return';\n", '')
        .replace("  if (resumeCheckout) history.replaceState(null, '', '/account/');\n", '')
        .replace("  const contactReturn = new URLSearchParams(location.search).get('contact') === 'verified';\n", '')
        .replace("  if (resumeCheckout || contactReturn) history.replaceState(null, '', '/account/');\n", '')
        .replace('  const contactService = createBillingContactService({auth});\n', '')
        .replace('await mountAccountPage(service, {checkoutService, contactService, resumeCheckout});', 'await mountAccountPage(service);')
        .replace('await mountAccountPage(service, {checkoutService, resumeCheckout});', 'await mountAccountPage(service);'))
class Page(HTMLParser):
    def __init__(self): super().__init__(); self.nodes=[]
    def handle_starttag(self, tag, attrs): self.nodes.append((tag,dict(attrs)))

def main():
    checks=[]
    def check(name, condition): checks.append((name,bool(condition)))
    page=Page(); html=(PUBLIC/'account/index.html').read_text();page.feed(html)
    nodes=page.nodes
    ids=[a['id'] for _,a in nodes if 'id' in a]
    check('unique IDs',len(ids)==len(set(ids)))
    check('Japanese and mobile viewport',('html',{'lang':'ja'}) in nodes and 'width=device-width' in html)
    check('zoom remains available','user-scalable=no' not in html and 'maximum-scale=1' not in html)
    check('local module entry only',[(a.get('type'),a.get('src')) for t,a in nodes if t=='script']==[('module','/assets/account.mjs')])
    check('no inline events',all(not k.lower().startswith('on') for _,a in nodes for k in a))
    check('credentials cannot use native GET',all(a.get('method')=='post' for t,a in nodes if t=='form'))
    check('credentials never have native form names',all('name' not in a for t,a in nodes if t=='input'))
    check('inputs start disabled until handlers exist',any(t=='fieldset' and 'disabled' in a for t,a in nodes))
    for t,a in nodes:
        if t=='input':check('input has label '+a['id'],any(x=='label' and y.get('for')==a['id'] for x,y in nodes))
        for attr in ['for','aria-controls','aria-labelledby','aria-describedby']:
            if attr in a:check('accessible references '+attr,all(value in ids for value in a[attr].split()))
        if t in ['script','link','img']:
            resource=a.get('src',a.get('href',''))
            if resource.startswith('/'):check('resource exists '+resource,(PUBLIC/resource.lstrip('/')).is_file())
    check('errors are announced',any(a.get('role')=='alert' for _,a in nodes))
    check('loading and safe guidance exist','Appleログインは設定確認中' in html and 'Apple' in html and 'ログアウト' in html)
    # Card-processing explanations may name CVC; payment controls must never collect it.
    check('no custom card controls or signup form',not re.search(r'type=["\'](?:tel|number)["\']|createUserWithEmailAndPassword|card-number',html) and not any(re.search(r'cc-number|cc-exp|cc-csc|cvc',json.dumps(a),re.I) for t,a in nodes if t in {'input','select','textarea'}))
    check('only original inputs and scoped Checkout/Apple consent checkboxes', {(a.get('id'),a.get('type')) for t,a in nodes if t=='input'} == {('email','email'),('password','password'),('premium-monthly','radio'),('checkout-terms','checkbox'),('apple-linking-consent','checkbox')})
    check('only original login form', [a.get('id') for t,a in nodes if t=='form']==['email-form'])
    scripts=sorted((PUBLIC/'assets').glob('account*.mjs'))+sorted((PUBLIC/'assets').glob('plan*.mjs'))+sorted((PUBLIC/'assets').glob('checkout*.mjs'))+sorted((PUBLIC/'assets').glob('billing-contact*.mjs'))+[PUBLIC/'assets/firebase-web-config.mjs']
    code='\n'.join(p.read_text() for p in scripts)
    check('no business writers or linking',not re.search(r'\b(?:setDoc|updateDoc|addDoc|deleteDoc|writeBatch|runTransaction|httpsCallable|linkWithCredential|linkWithPopup|createUserWithEmailAndPassword|sendEmailVerification|sendPasswordResetEmail)\s*\(',code))
    auth_service=(PUBLIC/'assets/account-service.mjs').read_text()
    other_modules='\n'.join(p.read_text() for p in scripts if p.name!='account-service.mjs')
    check('no credential persistence or raw DOM injection outside scoped consent marker',not re.search(r'localStorage|\.innerHTML|insertAdjacentHTML|document\.write',code) and 'sessionStorage' not in other_modules and 'sessionStorage' not in auth_service.replace('globalThis.sessionStorage',''))
    check('only the short-lived Apple consent marker may use tab storage',all(value in auth_service for value in ("APPLE_REDIRECT_CONSENT_KEY = 'hamcare.apple-redirect-consent.v1'","APPLE_CONSENT_VERSION = 'apple-linking-v1'",'APPLE_REDIRECT_CONSENT_TTL = 15 * 60 * 1000',"Object.keys(marker).sort().join(',') === 'accepted,method,startedAt,version'",'now - marker.startedAt < APPLE_REDIRECT_CONSENT_TTL','marker.startedAt <= now',"JSON.stringify({version: APPLE_CONSENT_VERSION, accepted: true, method: 'redirect', startedAt: appleContext.now()})",'storage.setItem(APPLE_REDIRECT_CONSENT_KEY, marker)','removeItem(APPLE_REDIRECT_CONSENT_KEY)','finally {clearRedirectConsent();')))
    storage_calls=re.findall(r'(?:appleContext\.)?storage\??\.(?:getItem|setItem|removeItem)\(([^)]*)\)',auth_service)
    check('every consent storage access uses its one fixed key',bool(storage_calls) and all(arguments.split(',')[0].strip()=='APPLE_REDIRECT_CONSENT_KEY' for arguments in storage_calls))
    check('no credential or error logging',not re.search(r'console\s*\.|onLog\s*\(',code))
    non_checkout='\n'.join(p.read_text() for p in scripts if p.name not in {'checkout-service.mjs','checkout-view.mjs','billing-contact-service.mjs','billing-contact-environment.mjs'})
    check('no business API outside isolated Checkout/contact modules',not re.search(r'checkout\.stripe|api\.stripe|firebase-functions|firebase-analytics|cloudfunctions\.net|run\.app',non_checkout))
    check('no direct Stripe API or Analytics',not re.search(r'api\.stripe|firebase-functions|firebase-analytics',code))
    network=r'\b(?:fetch|fetchRequest|XMLHttpRequest|WebSocket|EventSource)\s*\(|\.sendBeacon\s*\('
    check('backend transport exists only in fixed Checkout/contact services',not re.search(network,'\n'.join(p.read_text() for p in scripts if p.name not in {'checkout-service.mjs','billing-contact-service.mjs'})))
    check('no secret keys or real Price/Product IDs in public modules',not re.search(r'\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{12,}\b|\b(?:price|prod)_[A-Z0-9][A-Za-z0-9]{7,}\b',code))
    check('no permanent test card numbers in public modules',not re.search(r'\b(?:4242424242424242|4000002500003155|4000000000000002)\b',code))
    check('standard session persistence only','browserSessionPersistence' in code and 'browserLocalPersistence' not in code)
    check('read-only Firestore Lite', 'firebase-firestore-lite.js' in code and 'sdk.getDoc(' in code)
    projections='\n'.join((PUBLIC/'assets'/name).read_text() for name in ('account-model.mjs','plan-model.mjs'))
    check('no timestamp-based Web entitlement decision',not re.search(r'Date\.now|isPaid|canUsePaidFeatures|isActiveAt|isInitialTrialActive',projections))
    config_path='public/assets/firebase-web-config.mjs'
    check('protected Firebase project/config unchanged',(ROOT/config_path).read_bytes()==baseline(config_path))
    auth_service=(PUBLIC/'assets/account-service.mjs').read_text()
    # Task7 deliberately extends the reviewed service. Keep its transport/API and
    # fixed UID-read surface explicit instead of silently freezing a new baseline.
    allowed_sdk={'OAuthProvider','GoogleAuthProvider','signOut','signInWithPopup','getAdditionalUserInfo','onAuthStateChanged','setPersistence','signInWithEmailAndPassword','signInWithRedirect','getRedirectResult','reload','getIdTokenResult','getDoc','doc'}
    check('Auth SDK surface has only existing methods and standard Apple provider',set(re.findall(r'sdk\.([A-Za-z]+)\s*\(',auth_service))==allowed_sdk)
    check('Apple capability defaults off and is strictly opt-in',all(value in auth_service for value in ('appleSignInEnabled = false','appleSignInEnabled === true',"kind === 'apple' && !appleEnabled","new sdk.OAuthProvider('apple.com')",'sdk.signInWithPopup(auth, provider)')))
    path_source=re.search(r'const paths = (.*?);',auth_service)
    fixed_paths=dict((key,(collection,document)) for key,collection,document in re.findall(r"(\w+): \['([^']+)', '([^']+)'\]",path_source[1] if path_source else ''))
    check('only four current-UID account documents are read',fixed_paths=={'owner':('owner_profiles','main'),'billing':('billing','subscription'),'trial':('feature_access','initial_trial_v2'),'pet':('pet_profiles','main_pet')} and "sdk.doc(db, 'users', uid, collection, document)" in auth_service)
    check('pet registration exposes existence only',"name === 'pet' ? {kind: 'found'}" in auth_service)
    check('social and email reads retain UID/epoch/logout guards',all(value in auth_service for value in ('socialPending','emailPending','startedBeforeLogout !== logoutGeneration','auth.currentUser?.uid !== uid','epoch !== generation','isVerifiedAccountIdentity(identity)','auth.currentUser !== user')))
    check('Apple identity must match the SDK current UID',all(value in auth_service for value in ('validateAppleResult(result)','result.user.uid === auth.currentUser.uid','hasAppleProvider(result.user)','hasAppleProvider(auth.currentUser)')))
    check('Apple service also refuses missing or malformed explicit consent',all(value in auth_service for value in ('consent.linkingConsent !== true',"Object.keys(consent).some(key => key !== 'linkingConsent')","signInApple(consent) { return signInSocial('apple', consent); }")))
    check('Redirect is limited to same-origin mobile Safari with recoverable consent state',all(value in auth_service for value in ('redirectStateAvailable !== true',"page.protocol !== 'https:'",'page.origin !== `https://${authDomain}`',"return ios && safari ? 'redirect' : 'popup'",'sdk.getRedirectResult(auth)','sdk.signInWithRedirect(auth, provider)')))
    check('Task7 does not change Preview CSP or hosting configuration',(ROOT/'firebase.preview.json').read_bytes()==baseline('firebase.preview.json',APPLE_BASE))
    entry=(PUBLIC/'assets/account.mjs').read_text()
    check('Auth entry unchanged except exact Checkout/contact mounts, profile reads and Apple opt-in',auth_entry_without_checkout(entry)==baseline('public/assets/account.mjs').decode())
    check('real account entry always supplies environment-bound verified contact service',all(value in entry for value in ("import { createBillingContactService } from './billing-contact-service.mjs';",'createBillingContactService({auth,environment:deployment.environment,origin:location.origin})','await mountAccountPage(service, {checkoutService, contactService, resumeCheckout:deployment.testMode && resumeCheckout,resumePlan});','deployment.testMode ? createPreviewCheckoutService')))
    check('configured Apple provider is explicitly enabled only at the public entry','appleSignInEnabled: true' in entry and 'appleSignInEnabled: false' not in entry and entry.count('appleSignInEnabled:')==1)
    apple=next((a for t,a in nodes if t=='button' and a.get('id')=='apple-signin'),{})
    check('Apple button is a disabled official local image with safe explanation',apple.get('type')=='button' and 'disabled' in apple and 'apple-signin-note' in apple.get('aria-describedby','').split() and any(t=='img' and a.get('src')=='/assets/landing/apple-sign-in-ja.png' and a.get('alt')=='Appleでサインイン' for t,a in nodes))
    consent=next((a for t,a in nodes if t=='input' and a.get('id')=='apple-linking-consent'),{})
    check('Apple association consent starts required and disabled',consent.get('type')=='checkbox' and 'required' in consent and 'disabled' in consent and any(t=='label' and a.get('for')=='apple-linking-consent' for t,a in nodes))
    check('Apple pre-auth explanation covers standard association and private relay',all(value in html for value in ('Appleログイン方法が追加される場合があります','別アカウントのデータを自動で統合・コピーすることはありません','Appleが発行する中継メールアドレス')))
    plan_model=(PUBLIC/'assets/plan-model.mjs').read_text()
    plan_view=(PUBLIC/'assets/account-view.mjs').read_text()
    check('pure plan projection has no SDK or credential access',not re.search(r'\b(?:import|document|window|navigator|auth|sdk)\b|idToken|getIdToken|accessToken|refreshToken|firebaseUid',plan_model))
    check('plan choice itself sends no request', 'const onPlanChoice' in plan_view and not re.search(r'\b(?:fetch|createPreviewCheckout|reviewPreviewCheckout)\s*\(',plan_view.split('const onPlanChoice',1)[1].split("element('premium-monthly').addEventListener",1)[0]))
    check('Apple UI/API require fresh explicit consent before authentication',all(value in plan_view for value in ("appleConsent.checked !== true","service.signInApple({linkingConsent: true})",'resetAppleConsent()',"appleConsent.addEventListener('change', onAppleConsent)")))
    guarded_handlers = {
        'plan entry': plan_view.split('const onPlan =',1)[1].split("element('review-plan').addEventListener",1)[0],
        'plan choice': plan_view.split('const onPlanChoice =',1)[1].split("element('premium-monthly').addEventListener",1)[0],
        'checkout entry': plan_view.split('const onCheckout =',1)[1].split("element('plan-checkout').addEventListener",1)[0],
        'Portal entry': plan_view.split('async function openPortal()',1)[1].split('async function renderUser',1)[0],
    }
    for name, handler in guarded_handlers.items():
        check('unregistered or unreadable app account cannot enter '+name,all(value in handler for value in ('!isVerifiedAccountIdentity(currentUser)','currentUser.isNewUser','currentSummary?.appAccountExists !== true')))
    check('contract rendering also requires registered app account','summary.appAccountExists === true' in plan_view)
    checkout_service=(PUBLIC/'assets/checkout-service.mjs').read_text()
    check('only two fixed isolated backend endpoints',CHECKOUT_ENDPOINT in checkout_service and PORTAL_ENDPOINT in checkout_service and 'endpoint !== PREVIEW_CHECKOUT_ENDPOINT' in checkout_service and checkout_service.count('.cloudfunctions.net/')==2)
    check('only five Checkout operations and dedicated empty Portal operation', all(value in checkout_service for value in ("request('review')","request('session'","request('status')","request('cancel')","request('billing')","createPreviewPortalSession:()=>request(null, {}, true)")))
    check('bearer POST is not a URL credential',all(value in checkout_service for value in ("getIdTokenResult(true)","'Authorization':'Bearer '+token","method:'POST'","credentials:'omit'","cache:'no-store'","referrerPolicy:'no-referrer'","fetchRequest(portal ? PREVIEW_PORTAL_ENDPOINT : endpoint+'/'+operation")) and not re.search(r'URLSearchParams|encodeURIComponent\(token',checkout_service))
    check('Checkout body is allowlisted confirmation and Portal body is empty',"body:JSON.stringify(portal ? {} : {planKey:'premium_monthly',...extra})" in checkout_service and 'request(\'session\',{reviewToken,termsAccepted})' in checkout_service)
    check('Checkout responses guard identity generation and abort on clear',all(value in checkout_service for value in ('started === generation','auth.currentUser === user','auth.currentUser?.uid === uid','new AbortController()','generation++','controller.abort()')))
    contact_service=(PUBLIC/'assets/billing-contact-service.mjs').read_text()
    contact_model=(PUBLIC/'assets/billing-contact-model.mjs').read_text()
    contact_view=(PUBLIC/'assets/billing-contact-view.mjs').read_text()
    contact_entry=(PUBLIC/'assets/billing-contact.mjs').read_text()
    contact_environment=(PUBLIC/'assets/billing-contact-environment.mjs').read_text()
    check('contact transport binds exact Live/Preview endpoints without fallback',CONTACT_ENDPOINT in contact_environment and contact_environment.count('.cloudfunctions.net/')==2 and 'https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/billingContactEmail' in contact_environment and 'endpoint !== deployment.endpoint' in contact_service and 'resolveBillingContactEnvironment(origin).environment !== environment' in contact_service and "origin===BILLING_CONTACT_LIVE_ORIGIN" in contact_environment and "origin===BILLING_CONTACT_PREVIEW_ORIGIN" in contact_environment)
    check('contact transport allows only status/request/confirm',all(value in contact_service for value in ("['status','request','confirm'].includes(operation)","request('status')","mutate('request', {email})","mutate('confirm', {token})")))
    check('contact transport uses fresh verified SDK identity and revokes stale reads',all(value in contact_service for value in ('getIdTokenResult(true)','projectAccountIdentity(user, tokenResult, auth.app?.options?.projectId)','started === generation','auth.currentUser === user','auth.currentUser?.uid === uid','new AbortController()','controller.abort()','generation++')))
    check('contact bearer and confirmation proof stay in allowlisted POST bodies',all(value in contact_service for value in ("method:'POST'","credentials:'omit'","cache:'no-store'","referrerPolicy:'no-referrer'","Authorization:'Bearer '+tokenResult.token",'body:JSON.stringify(body)')) and not re.search(r'URLSearchParams|encodeURIComponent|customerId|priceId|subscriptionId|firebaseUid',contact_service))
    check('contact mutations do not retry unknown outcomes','response.status === 401 && attempt === 0' in contact_service and 'mutationPending === started' in contact_service and not re.search(r'setTimeout|setInterval',contact_service))
    check('contact projection exposes only environment-matched masked contact and delivery status',all(value in contact_model for value in ("raw.testMode !== (environment === 'preview')",'raw.canCheckout && (!validMaskedEmail(raw.maskedEmail)',"raw.state !== 'verified'",'raw.source === null',"['invalid', 'unverified'].includes(raw.category) && raw.canCheckout","![undefined,null,'sent','uncertain','failed'].includes(raw.deliveryState)")) and not re.search(r'raw\.(?:uid|email|token|customerId)\b',contact_model))
    check('confirmation fragment is cleared before remote SDK imports',contact_entry.index('consumeVerificationFragment(location, history)') < contact_entry.index("import('https://") and "history?.replaceState(null, '', '/account/contact/')" in contact_model and "values.getAll('token').length !== 1" in contact_model and contact_entry.count('confirmation.token=null;')==2)
    confirm_handler=contact_view.split("listen('contact-confirm','click'",1)[1].split("listen('contact-login-form'",1)[0]
    check('contact confirmation requires explicit authenticated click',"contactService.confirmVerification(confirmationToken)" in confirm_handler and 'if(busy || !token || !currentUser)return;' in confirm_handler and contact_view.count('contactService.confirmVerification(')==1 and 'summary?.appAccountExists!==true' in contact_view and '!isVerifiedAccountIdentity(currentUser)' in contact_view)
    check('contact page reuses gated Apple auth without altering Auth identity',all(value in contact_view for value in ("el('contact-apple-consent').checked",'accountService.signInApple({linkingConsent:true})','await accountService.ready()','accountService.onAuthChanged(user=>')) and not re.search(r'updateEmail|updateProfile|linkWith|createUser',contact_entry+contact_service+contact_view))
    check('contact success never claims uncertain delivery',"next.deliveryState!=='sent'" in contact_view and "const deliverySent=model.deliveryState==='sent'" in contact_view and '送信結果を確認しています' in contact_view and '確認メールを送信できませんでした' in contact_view)
    check('contact gate is fresh at plan and checkout and keeps identity guards',all('checkContactBeforePurchase()' in guarded_handlers[name] for name in ('plan entry','checkout entry')) and "if (!model.canCheckout) { window.location.assign('/account/contact/'); return false; }" in plan_view and 'request !== contactRead || user !== currentUser' in plan_view)
    check('existing Portal never depends on additional contact eligibility','contactService' not in guarded_handlers['Portal entry'] and 'checkContactBeforePurchase' not in guarded_handlers['Portal entry'] and '!previewModel?.portalManageable && !(await checkContactBeforePurchase())' in guarded_handlers['plan entry'])
    check('contact view is separate from readonly Auth email',all(value in html for value in ('id="account-contact-panel"','id="account-contact-email"','id="account-email"','href="/account/contact/"')) and "element('account-contact-email').textContent = model.maskedEmail" in plan_view and 'contactService?.clear();' in plan_view)
    contact_html=(PUBLIC/'account/contact/index.html').read_text()
    contact_page=Page();contact_page.feed(contact_html)
    contact_nodes=contact_page.nodes
    contact_ids=[a['id'] for _,a in contact_nodes if 'id' in a]
    check('contact page has unique Japanese mobile IDs',len(contact_ids)==len(set(contact_ids)) and ('html',{'lang':'ja'}) in contact_nodes and 'width=device-width' in contact_html)
    check('contact page has only its local script entry',[(a.get('type'),a.get('src')) for t,a in contact_nodes if t=='script']==[('module','/assets/billing-contact.mjs')])
    check('contact credentials have no native names or GET forms',all('name' not in a for t,a in contact_nodes if t=='input') and all(a.get('method')=='post' and a.get('action')=='/account/contact/' for t,a in contact_nodes if t=='form'))
    check('contact page has no inline events or custom card controls',all(not k.lower().startswith('on') for _,a in contact_nodes for k in a) and not re.search(r'card-number|CVC|type=["\'](?:tel|number)["\']',contact_html))
    check('contact page inputs and ARIA references have labels',all(any(t=='label' and a.get('for')==item.get('id') for t,a in contact_nodes) for tag,item in contact_nodes if tag=='input') and all(value in contact_ids for _,a in contact_nodes for name in ('for','aria-controls','aria-labelledby','aria-describedby') if name in a for value in a[name].split()))
    check('contact fields initially disabled and links disclose no identity',all('disabled' in a for t,a in contact_nodes if t=='fieldset') and all(not re.search(r'[?#].*(?:token|email|uid)=',a.get('href',''),re.I) for t,a in contact_nodes if t=='a'))
    check('contact page offers relay contact without marketing or account merging',all(value in contact_html for value in ('Appleの非公開メールアドレスもご利用いただけます','個人の実メールである必要はありません','広告配信には使用しません','アカウントの統合','新しいメールの確認が終わるまでは、以前の確認済み連絡先を維持')))
    check('contact page has no-referrer and noindex metadata',any(t=='meta' and a.get('name')=='referrer' and a.get('content')=='no-referrer' for t,a in contact_nodes) and any(t=='meta' and a.get('name')=='robots' and 'noindex' in a.get('content','') for t,a in contact_nodes))
    check('contact account destinations remain fixed and local',all(any(t=='a' and a.get('href')==url for t,a in contact_nodes) for url in ('/account/','/account/?contact=verified&view=plan')) and "BILLING_CONTACT_PLAN_RETURN = '/account/?contact=verified&view=plan'" in contact_environment and "setAttribute('href',BILLING_CONTACT_PLAN_RETURN)" in contact_view)
    check('contact legal destinations use existing live documents excluded from Preview',all(any(t=='a' and a.get('href')=='https://hamster-breeding-app.web.app/'+path+'/' for t,a in contact_nodes) and not any(t=='a' and a.get('href')=='/'+path+'/' for t,a in contact_nodes) for path in ('terms','privacy','commercial-transactions','support')))
    checkout_view=(PUBLIC/'assets/checkout-view.mjs').read_text()
    identity=(PUBLIC/'assets/account-identity.mjs').read_text()
    check('client preflight binds fresh SDK result to project and current UID',all(value in identity for value in ('claims.aud !== projectId',"claims.iss !== 'https://securetoken.google.com/' + projectId",'claims.sub !== user.uid','tokenResult.signInProvider !== claims.firebase.sign_in_provider')) and 'sdk.getIdTokenResult(user, true)' in auth_service)
    check('Apple proof requires this session and one exact provider/subject binding',all(value in identity for value in ("tokenResult.signInProvider === 'apple.com'","claims.firebase.identities?.['apple.com']",'subjects.length !== 1','providers.length !== 1','providers[0].uid !== subjects[0]',"authenticationBasis: 'apple_provider'")))
    check('confirmed email is not replaced or spoofed by an Apple flag',all(value in identity for value in ('user.emailVerified === true && claims.email_verified === true',"authenticationBasis: 'verified_email'")) and not re.search(r'emailVerified\s*=(?!=)',auth_service+identity+checkout_service))
    check('identity projection never retains or renders token claims',not re.search(r'localStorage|sessionStorage|document|innerHTML|console\s*\.|JSON\.stringify|tokenResult\.token',identity) and 'isVerifiedAccountIdentity' in plan_view)
    check('Checkout revalidates fresh identity per request and one 401 refresh only',all(value in checkout_service for value in ('attempt < 2','getIdTokenResult(true)','projectAccountIdentity(user, tokenResult, projectId)','auth.currentUser === user','response.status === 401 && attempt === 0')))
    auth_policy=(ROOT/'preview-functions/src/auth-policy.ts').read_text()
    check('server Apple policy binds Admin UID/disabled and exact current token provider',all(value in auth_policy for value in ('adminUser.uid !== verifiedToken.uid','adminUser.disabled !== false',"firebase.sign_in_provider === 'apple.com'",'subjects.length !== 1','apple.length !== 1','apple[0].uid !== subjects[0]',"authBasis: 'apple_provider'")))
    check('server non-Apple policy retains both actual verified-email checks',all(value in auth_policy for value in ('verifiedToken.email_verified !== true || adminUser.emailVerified !== true',"authBasis: 'verified_email'")))
    check('Stripe.js loads directly from approved SDK origin',"https://js.stripe.com/v3/" in checkout_view and 'initEmbeddedCheckout' in checkout_view and not re.search(r'api\.stripe|checkout\.stripe',checkout_service+checkout_view))
    check('existing SDK version pinned',set(re.findall(r'https://www\.gstatic\.com/firebasejs/([^/]+)/',code))=={'12.17.1'})
    check('public config only',set(json.loads((PUBLIC/'assets/firebase-web-config.mjs').read_text().split('Object.freeze(',1)[1].rsplit(');',1)[0]))=={'apiKey','authDomain','projectId','appId'})
    config=json.loads((ROOT/'firebase.preview.json').read_text())
    original_config=json.loads(baseline('firebase.preview.json'))
    normalized_config=json.loads(json.dumps(config))
    old_account={h['key']:h['value'] for r in original_config['hosting']['headers'] if r['source']=='/account/**' for h in r['headers']}
    for rule in normalized_config['hosting']['headers']:
        if rule['source']=='/account/**':
            for header in rule['headers']:
                if header['key']=='Content-Security-Policy':header['value']=old_account['Content-Security-Policy']
    check('Preview config changes only account CSP',normalized_config==original_config)
    rules=config['hosting']['headers']
    account={h['key']:h['value'] for r in rules if r['source']=='/account/**' for h in r['headers']}
    csp=account.get('Content-Security-Policy','')
    check('account page is not stored',account.get('Cache-Control')=='no-store, max-age=0')
    check('CSP blocks form submission/base/frame embedding',all(s in csp for s in ["form-action 'none'","base-uri 'none'","frame-ancestors 'none'","object-src 'none'"]))
    check('CSP excludes inline/eval and all but approved Stripe subdomain wildcards',not any(s in csp.replace('https://*.js.stripe.com','').replace('https://*.stripe.com','') for s in ['unsafe-inline','unsafe-eval','*']))
    directives={p[0]:p[1:] for d in csp.split(';') if (p:=d.split())}
    original_connect={'https://identitytoolkit.googleapis.com','https://securetoken.googleapis.com','https://firestore.googleapis.com'}
    approved_connect=original_connect|{'https://us-central1-hamster-breeding-app.cloudfunctions.net','https://api.stripe.com','https://checkout.stripe.com'}
    actual_connect=set(directives.get('connect-src',[]))
    check('only required Auth and fixed Test Checkout API origins',original_connect|{'https://us-central1-hamster-breeding-app.cloudfunctions.net'} <= actual_connect <= approved_connect)
    check('only pinned Auth helpers and direct Stripe SDK scripts',set(directives.get('script-src',[]))=={"'self'",'https://www.gstatic.com/firebasejs/12.17.1/','https://apis.google.com','https://js.stripe.com','https://*.js.stripe.com','https://checkout.stripe.com'})
    original_frames={'https://hamster-breeding-app.firebaseapp.com','https://accounts.google.com'}
    approved_frames=original_frames|{'https://js.stripe.com','https://*.js.stripe.com','https://checkout.stripe.com','https://hooks.stripe.com'}
    actual_frames=set(directives.get('frame-src',[]))
    check('fixed Auth and Stripe payment frames',original_frames|{'https://js.stripe.com'} <= actual_frames <= approved_frames)
    check('image origins limited to local and Stripe',set(directives.get('img-src',[]))=={"'self'",'https://*.stripe.com'})
    check('auth CSP is isolated from landing',any(r['source']=='/' and any(h['key']=='Content-Security-Policy' and "connect-src 'none'" in h['value'] for h in r['headers']) for r in rules))
    for path in ['firebase.json','firestore.rules','functions/package.json','functions/package-lock.json','functions/src/index.ts','functions/src/stripeSubscriptionSync.ts','functions/src/stripeSubscriptionPriority.ts','functions/src/featureTrials.ts','functions/src/trialPolicy.ts']:
        check('production billing/Auth source unchanged '+path,(ROOT/path).read_bytes()==baseline(path,CHECKOUT_BASE))
    backend=(ROOT/'preview-functions/src/index.ts').read_text()
    engine=(ROOT/'preview-functions/src/engine.ts').read_text()
    portal=(ROOT/'preview-functions/src/portal.ts').read_text()
    portal_engine=(ROOT/'preview-functions/src/portal-engine.ts').read_text()
    check('Preview uses only dedicated Test secrets',set(re.findall(r"defineSecret\('([^']+)'\)",backend+portal))=={'HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS','HAMCARE_PREVIEW_STRIPE_TEST_PRICE','HAMCARE_PREVIEW_STRIPE_WEBHOOK_CONFIG','HAMCARE_PREVIEW_STRIPE_PORTAL_CONFIG'})
    check('Portal verifies Firebase ID token revocation and shared current-UID identity policy',all(value in portal for value in ('verifyIdToken(bearer.slice(7),true)','getUser(token.uid)','authorizePreviewIdentity(token,user)')))
    check('Portal HTTP rejects identifiers and arbitrary redirects',all(value in portal for value in ("req.get('Origin')!==PREVIEW_ORIGIN","req.is('application/json')",'Object.keys(req.query).length','Object.keys(req.body).length','req.rawBody.length>512')))
    check('Portal resolves Customer from UID without email search or creation',all(value in portal_engine for value in ('hash(uid)','stored.previewFirebaseUid !== uid','customers.retrieve(customerId)','verifyBinding(customer.metadata')) and not re.search(r'customers\.(search|create|update)|subscriptions\.(create|update|cancel)|billingPortal\.configurations\.(create|update)',portal_engine))
    check('Portal is Test mode and fixed configuration and return only',all(value in portal_engine for value in ("value.livemode !== false","configuration: d.configurationId","return_url: PREVIEW_PORTAL_RETURN_URL","locale: 'ja'","'/account/?portal=return'")))
    check('Portal disables identity and plan editing and immediate cancellation',all(value in portal_engine for value in ("f.customer_update?.enabled !== false","f.subscription_update?.enabled !== false","f.subscription_cancel.mode !== 'at_period_end'","f.subscription_cancel.proration_behavior !== 'none'","config.login_page?.enabled !== false")))
    check('Portal has no logging, URL persistence or billing mutation',not re.search(r'console\s*\.|logger\s*\.|sessionStorage|localStorage|\.set\(|\.update\(',portal_engine) and 'tx.set(rate,' in portal and not re.search(r'\.doc\([\"\']subscription[\"\']\).*\.set',portal))
    webhook=(ROOT/'preview-functions/src/webhook.ts').read_text()
    verification=(ROOT/'preview-functions/src/webhook-verification.ts').read_text()
    sync=(ROOT/'preview-functions/src/subscription-sync.ts').read_text()
    store=(ROOT/'preview-functions/src/subscription-store.ts').read_text()
    check('Webhook uses raw body and bounded signature verification','verifyPreviewEvent(stripe,req.rawBody,signature,cfg.signingSecret)' in webhook and 'constructEvent(raw,signature,secret,300)' in verification and 'event.livemode!==false' in verification)
    check('Webhook endpoint URL and signing value are not public or tracked literals','/stripePreviewWebhook' not in code and not re.search(r'https://[^\s\"\']+/stripePreviewWebhook|whsec_[A-Za-z0-9]{12,}',backend+webhook+code))
    check('Webhook writes only isolated namespace via atomic adapter',"subjectRef(subjectHash)" in store and "db.collection(PREVIEW_NAMESPACE)" not in sync and not re.search(r'users/|collection\([\"\']users',store+webhook))
    check('Webhook idempotency and latest Stripe re-read are explicit',all(x in sync for x in ('claimEvent','claimSubject','subscriptions.retrieve','invoices.retrieve','store.commit')) and 'tx.set(receipt' in store and 'tx.set(root.collection(\'billing\')' in store)
    check('Test credential prefixes and false livemode are required', all(value in backend for value in ("startsWith('sk_test_')","startsWith('pk_test_')")) and 'value.livemode !== false' in engine)
    check('server verifies revoked tokens and shared confirmed-email or current-Apple identity',all(value in backend for value in ('verifyIdToken(bearer.slice(7),true)','getUser(token.uid)','authorizePreviewIdentity(token,user)')))
    check('strict Origin, JSON body, size and query boundary',all(value in backend for value in ('origin!==PREVIEW_ORIGIN',"req.is('application/json')",'Object.keys(req.query).length','req.rawBody.length>2048','Object.keys(body).some(k=>!keys.includes(k))',"body.planKey!=='premium_monthly'")))
    check('Preview store stays outside app users path',"const NAMESPACE='preview_checkout_task4'" in backend and 'db.collection(NAMESPACE).doc(subject)' in backend and 'db.collection(NAMESPACE).doc(\'_limits_\'+day)' in backend and not re.search(r'\b(?:getFirestore|firestore)\s*\(|\.collection\s*\(|firebase-admin',engine))
    check('backend does not load production index or keys',not re.search(r"from ['\"][^'\"]*functions/src/index|STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET",backend+engine))
    check('new backend never logs errors or personal request data',not re.search(r'console\s*\.|logger\s*\.|JSON\.stringify\((?:req|identity|user|error)|String\(error',backend+engine))
    check('Preview metadata cannot activate legacy billing webhook',not re.search(r'client_reference_id\s*:|firebaseUid\s*:',backend+engine) and 'previewSubjectHash:subject' in engine)
    check('price, tax and automatic tax are checked server-side',all(value in engine for value in ("price.unit_amount !== 550","price.currency !== 'jpy'","price.recurring?.interval !== 'month'","price.recurring.interval_count !== 1","price.tax_behavior !== 'inclusive'","automatic_tax:{enabled:false}","allow_promotion_codes:false")))
    deployment=json.loads((ROOT/'firebase.checkout-preview.json').read_text())
    function_config=deployment.get('functions')
    function_configs=[function_config] if isinstance(function_config,dict) else function_config
    check('deployment config contains only dedicated Preview codebase',set(deployment)=={'functions'} and isinstance(function_configs,list) and len(function_configs)==1 and function_configs[0].get('source')=='preview-functions' and function_configs[0].get('codebase')=='hamcare-checkout-preview')
    preview_package=json.loads((ROOT/'preview-functions/package.json').read_text())
    old_package=json.loads(baseline('functions/package.json',CHECKOUT_BASE))
    check('Preview dependencies reuse existing approved versions',all(preview_package.get(key)==old_package.get(key) for key in ('dependencies','devDependencies','engines')))
    check('Preview lockfile reuses existing lock exactly',(ROOT/'preview-functions/package-lock.json').read_bytes()==baseline('functions/package-lock.json',CHECKOUT_BASE))
    print(f'Web account static checks: {sum(ok for _,ok in checks)}/{len(checks)} PASS')
    for name,ok in checks:
        if not ok:print('FAIL:',name)
    return 0 if all(ok for _,ok in checks) else 1
if __name__=='__main__':raise SystemExit(main())
