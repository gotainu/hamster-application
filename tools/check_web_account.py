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
CHECKOUT_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/createPreviewStripeCheckoutSession'

def baseline(path, revision=AUTH_BASE):
    return subprocess.check_output(['git','show',f'{revision}:{path}'],cwd=ROOT)

def auth_entry_without_checkout(source):
    """Only the reviewed Task 4 mount/return integration may change Auth entry."""
    return (source
        .replace("import { createPreviewCheckoutService } from './checkout-service.mjs';\n", '')
        .replace('  const checkoutService = createPreviewCheckoutService({auth});\n', '')
        .replace("  const resumeCheckout = new URLSearchParams(location.search).get('checkout') === 'return';\n", '')
        .replace("  if (resumeCheckout) history.replaceState(null, '', '/account/');\n", '')
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
    check('loading and safe guidance exist','準備中' in html and 'Apple' in html and 'ログアウト' in html)
    check('no custom card controls or signup form',not re.search(r'type=["\'](?:tel|number)["\']|createUserWithEmailAndPassword|card-number|CVC',html))
    check('only original inputs and consent checkbox', {(a.get('id'),a.get('type')) for t,a in nodes if t=='input'} == {('email','email'),('password','password'),('premium-monthly','radio'),('checkout-terms','checkbox')})
    check('only original login form', [a.get('id') for t,a in nodes if t=='form']==['email-form'])
    scripts=sorted((PUBLIC/'assets').glob('account*.mjs'))+sorted((PUBLIC/'assets').glob('plan*.mjs'))+sorted((PUBLIC/'assets').glob('checkout*.mjs'))+[PUBLIC/'assets/firebase-web-config.mjs']
    code='\n'.join(p.read_text() for p in scripts)
    check('no business writers or linking',not re.search(r'\b(?:setDoc|updateDoc|addDoc|deleteDoc|writeBatch|runTransaction|httpsCallable|linkWithCredential|linkWithPopup|createUserWithEmailAndPassword|sendEmailVerification|sendPasswordResetEmail)\s*\(',code))
    check('no custom persistence or raw DOM injection',not re.search(r'localStorage|sessionStorage|\.innerHTML|insertAdjacentHTML|document\.write',code))
    check('no credential or error logging',not re.search(r'console\s*\.|onLog\s*\(',code))
    non_checkout='\n'.join(p.read_text() for p in scripts if p.name not in {'checkout-service.mjs','checkout-view.mjs'})
    check('no business API outside isolated Checkout modules',not re.search(r'checkout\.stripe|api\.stripe|firebase-functions|firebase-analytics|cloudfunctions\.net|run\.app',non_checkout))
    check('no direct Stripe API or Analytics',not re.search(r'api\.stripe|firebase-functions|firebase-analytics',code))
    network=r'\b(?:fetch|fetchRequest|XMLHttpRequest|WebSocket|EventSource)\s*\(|\.sendBeacon\s*\('
    check('backend transport exists only in checkout-service',not re.search(network,'\n'.join(p.read_text() for p in scripts if p.name!='checkout-service.mjs')))
    check('no secret keys or real Price/Product IDs in public modules',not re.search(r'\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{12,}\b|\b(?:price|prod)_[A-Z0-9][A-Za-z0-9]{7,}\b',code))
    check('no permanent test card numbers in public modules',not re.search(r'\b(?:4242424242424242|4000002500003155|4000000000000002)\b',code))
    check('standard session persistence only','browserSessionPersistence' in code and 'browserLocalPersistence' not in code)
    check('read-only Firestore Lite', 'firebase-firestore-lite.js' in code and 'sdk.getDoc(' in code)
    projections='\n'.join((PUBLIC/'assets'/name).read_text() for name in ('account-model.mjs','plan-model.mjs'))
    check('no timestamp-based Web entitlement decision',not re.search(r'Date\.now|isPaid|canUsePaidFeatures|isActiveAt|isInitialTrialActive',projections))
    for path in ['public/assets/firebase-web-config.mjs','public/assets/account-service.mjs']:
        before=baseline(path)
        check('protected Auth/config unchanged '+path,(ROOT/path).read_bytes()==before)
    entry=(PUBLIC/'assets/account.mjs').read_text()
    check('Auth entry unchanged except exact Checkout mount integration',auth_entry_without_checkout(entry)==baseline('public/assets/account.mjs').decode())
    plan_model=(PUBLIC/'assets/plan-model.mjs').read_text()
    plan_view=(PUBLIC/'assets/account-view.mjs').read_text()
    check('pure plan projection has no SDK or credential access',not re.search(r'\b(?:import|document|window|navigator|auth|sdk)\b|idToken|getIdToken|accessToken|refreshToken|firebaseUid',plan_model))
    check('plan choice itself sends no request', 'const onPlanChoice' in plan_view and not re.search(r'\b(?:fetch|createPreviewCheckout|reviewPreviewCheckout)\s*\(',plan_view.split('const onPlanChoice',1)[1].split("element('premium-monthly').addEventListener",1)[0]))
    checkout_service=(PUBLIC/'assets/checkout-service.mjs').read_text()
    check('fixed isolated backend endpoint',CHECKOUT_ENDPOINT in checkout_service and 'endpoint !== PREVIEW_CHECKOUT_ENDPOINT' in checkout_service and checkout_service.count('.cloudfunctions.net/')==1)
    check('only five defined backend operations', all(value in checkout_service for value in ("request('review')","request('session'","request('status')","request('cancel')","request('billing')")))
    check('bearer POST is not a URL credential',all(value in checkout_service for value in ("getIdToken()","'Authorization':'Bearer '+token","method:'POST'","credentials:'omit'","cache:'no-store'","referrerPolicy:'no-referrer'")) and re.search(r"fetchRequest\(endpoint\s*\+\s*['\"]/['\"]\s*\+\s*operation\s*,",checkout_service) is not None and not re.search(r'URLSearchParams|encodeURIComponent\(token',checkout_service))
    check('Checkout request body is allowlisted plan plus confirmation only',"body:JSON.stringify({planKey:'premium_monthly',...extra})" in checkout_service and 'request(\'session\',{reviewToken,termsAccepted})' in checkout_service)
    check('Checkout responses guard identity generation and abort on clear',all(value in checkout_service for value in ('started !== generation','auth.currentUser?.uid !== uid','new AbortController()','generation++','controller.abort()')))
    checkout_view=(PUBLIC/'assets/checkout-view.mjs').read_text()
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
    check('Preview uses only dedicated Test secrets',set(re.findall(r"defineSecret\('([^']+)'\)",backend))=={'HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS','HAMCARE_PREVIEW_STRIPE_TEST_PRICE','HAMCARE_PREVIEW_STRIPE_WEBHOOK_CONFIG'})
    webhook=(ROOT/'preview-functions/src/webhook.ts').read_text()
    verification=(ROOT/'preview-functions/src/webhook-verification.ts').read_text()
    sync=(ROOT/'preview-functions/src/subscription-sync.ts').read_text()
    store=(ROOT/'preview-functions/src/subscription-store.ts').read_text()
    check('Webhook uses raw body and bounded signature verification','verifyPreviewEvent(stripe,req.rawBody,signature,cfg.signingSecret)' in webhook and 'constructEvent(raw,signature,secret,300)' in verification and 'event.livemode!==false' in verification)
    check('Webhook endpoint URL and signing value are not public or tracked literals','/stripePreviewWebhook' not in code and not re.search(r'https://[^\s\"\']+/stripePreviewWebhook|whsec_[A-Za-z0-9]{12,}',backend+webhook+code))
    check('Webhook writes only isolated namespace via atomic adapter',"subjectRef(subjectHash)" in store and "db.collection(PREVIEW_NAMESPACE)" not in sync and not re.search(r'users/|collection\([\"\']users',store+webhook))
    check('Webhook idempotency and latest Stripe re-read are explicit',all(x in sync for x in ('claimEvent','claimSubject','subscriptions.retrieve','invoices.retrieve','store.commit')) and 'tx.set(receipt' in store and 'tx.set(root.collection(\'billing\')' in store)
    check('Test credential prefixes and false livemode are required', all(value in backend for value in ("startsWith('sk_test_')","startsWith('pk_test_')")) and 'value.livemode !== false' in engine)
    check('server verifies revoked tokens and confirmed email',all(value in backend for value in ('verifyIdToken(bearer.slice(7),true)','getUser(token.uid)','token.email_verified!==true','!user.emailVerified','user.disabled')))
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
