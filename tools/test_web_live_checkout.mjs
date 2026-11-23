import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createLiveCheckoutService,LIVE_ORIGIN,LIVE_CHECKOUT_ENDPOINT,LIVE_PORTAL_ENDPOINT,LIVE_PURCHASE_ENABLED} from '../public/assets/live-checkout-service.mjs';
import {projectLiveCheckoutReview,projectLiveCheckoutSession,projectLiveCheckoutStatus,projectLiveBilling,projectLivePortalSession} from '../public/assets/live-checkout-model.mjs';
const PROJECT='synthetic-live-adapter';
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
function harness({apple=false,fetcher,billing}={}) {
  const uid='synthetic-owner',calls=[],reads=[];
  const user={uid,email:apple?null:'synthetic@example.test',emailVerified:!apple,providerData:apple?[{providerId:'apple.com',uid:'synthetic-subject'}]:[{providerId:'password'}]};
  user.getIdTokenResult=async()=>({token:'synthetic-bearer',signInProvider:apple?'apple.com':'password',claims:{sub:uid,aud:PROJECT,iss:'https://securetoken.google.com/'+PROJECT,email_verified:!apple,firebase:{sign_in_provider:apple?'apple.com':'password',identities:{'apple.com':['synthetic-subject']}}}});
  const auth={app:{options:{projectId:PROJECT}},currentUser:user};
  const service=createLiveCheckoutService({auth,origin:LIVE_ORIGIN,readOwnProfiles:async()=>({ownerExists:true,petExists:true}),readOwnBilling:async target=>{reads.push(target);return billing??{kind:'missing'};},fetchRequest:async(url,options)=>{calls.push({url,options});return fetcher?fetcher(url,options):{ok:true,status:200,json:async()=>({result:{ok:true,checkoutStatus:'open',billingState:'pending'}})};}});
  return {auth,user,service,calls,reads};
}
const review=()=>({ok:true,planKey:'premium_monthly',unitAmount:550,currency:'jpy',interval:'month',reviewToken:'synthetic_review_proof_123',termsVersion:'web550-v1',maskedEmail:'go***@example.com',nickname:'テスト',chargeTiming:'immediate',firstChargeAtSeconds:1795374000});
const billing=(overrides={})=>({kind:'found',data:{firebaseUid:'synthetic-owner',provider:'stripe',stripeLivemode:true,billingSyncVersion:1,stripeCustomerId:'cus_synthetic',stripeSubscriptionId:'sub_synthetic',plan:'paid',status:'active',amount:550,currency:'jpy',interval:'month',cancelAtPeriodEnd:false,currentPeriodEnd:{seconds:1798000000},syncedAtMillis:1795374000000,...overrides}});
test('canonical factory has fixed Live origin and requires own-billing reader',()=>{
  assert.equal(LIVE_PURCHASE_ENABLED,false);
  for(const origin of [undefined,'https://hamster-breeding-app--web-first-task1-lco08m60.web.app',LIVE_ORIGIN+'.evil.test','http://localhost:1234'])assert.throws(()=>createLiveCheckoutService({auth:{},origin,readOwnBilling:async()=>{}}));
  assert.throws(()=>createLiveCheckoutService({auth:{},origin:LIVE_ORIGIN}));
});
test('general purchase review/create remain locally closed, without creating Stripe requests',async()=>{
  const h=harness();await assert.rejects(h.service.reviewPreviewCheckout(),e=>e.code==='live/purchase_closed');
  await assert.rejects(async()=>h.service.createPreviewCheckout({reviewToken:'arbitrary',termsAccepted:true}),e=>e.code==='live/review_mismatch');
  assert.equal(h.calls.length,0);
});
test('status uses exact Live callable envelope and same authenticated session only',async()=>{
  const h=harness();await h.service.getPreviewCheckoutStatus();
  assert.equal(h.calls[0].url,LIVE_CHECKOUT_ENDPOINT);const o=h.calls[0].options;
  assert.deepEqual(JSON.parse(o.body),{data:{flow:'web',action:'status'}});assert.equal(o.headers.Authorization,'Bearer synthetic-bearer');
  assert.equal(o.credentials,'omit');assert.equal(o.cache,'no-store');assert.equal(o.referrerPolicy,'no-referrer');
  assert.doesNotMatch(o.body,/synthetic-owner|price|customer|return|trial/);
});
test('cancellation uses the exact action, never a caller-selected Session',async()=>{const h=harness();await h.service.cancelPreviewCheckout({sessionId:'untrusted'});assert.deepEqual(JSON.parse(h.calls[0].options.body),{data:{flow:'web',action:'cancel'}});});
test('Portal callable is independent of purchase/contact and sends an empty data object',async()=>{
  const h=harness({apple:true,fetcher:async()=>({ok:true,json:async()=>({result:{ok:true,portalUrl:'https://billing.stripe.com/p/session/live_synthetic'}})})});
  const r=await h.service.createPreviewPortalSession({uid:'untrusted',customer:'untrusted',returnUrl:'https://evil.test'});
  assert.equal(h.calls[0].url,LIVE_PORTAL_ENDPOINT);assert.deepEqual(JSON.parse(h.calls[0].options.body),{data:{}});assert.equal(projectLivePortalSession(r),'https://billing.stripe.com/p/session/live_synthetic');
});
test('stopped or missing Live settings make one request and never use Preview fallback',async()=>{
  const h=harness({fetcher:async()=>({ok:false,status:503,json:async()=>({error:{status:'UNAVAILABLE',message:'must not expose'}})})});
  await assert.rejects(h.service.getPreviewCheckoutStatus(),e=>e.code==='live/purchase_closed');assert.equal(h.calls.length,1);assert.equal(h.calls[0].url,LIVE_CHECKOUT_ENDPOINT);
});
test('unknown mutation outcome is not automatically retried and error payload is discarded',async()=>{
  const h=harness({fetcher:async()=>{throw new TypeError('synthetic-private-payload');}});
  await assert.rejects(h.service.createPreviewPortalSession(),e=>e.code==='network_error'&&Object.keys(e).length===1);assert.equal(h.calls.length,1);
});
test('unverified/absent user cannot call production APIs',async()=>{
  for(const user of [null,{uid:'synthetic',emailVerified:false}]){const h=harness();h.auth.currentUser=user;await assert.rejects(h.service.getPreviewCheckoutStatus());assert.equal(h.calls.length,0);}
});
test('identity change during token refresh prevents any network dispatch',async()=>{
  const h=harness(),wait=deferred();h.user.getIdTokenResult=()=>wait.promise;
  const p=h.service.getPreviewCheckoutStatus();h.auth.currentUser={uid:'synthetic-other'};wait.resolve({});await assert.rejects(p,e=>e.code==='session_changed');assert.equal(h.calls.length,0);
});
test('identity change or clear during response discards result and aborts transport',async()=>{
  for(const clear of [false,true]){const wait=deferred(),h=harness({fetcher:()=>wait.promise});const p=h.service.getPreviewCheckoutStatus();await new Promise(r=>setImmediate(r));
    if(clear){h.service.clear();assert.equal(h.calls[0].options.signal.aborted,true);}else h.auth.currentUser={uid:'synthetic-other'};
    wait.resolve({ok:true,json:async()=>({result:{ok:true,checkoutStatus:'complete',billingState:'confirmed'}})});await assert.rejects(p,e=>e.code==='session_changed');}
});
test('plain Preview or malformed callable envelopes never become Live success',async()=>{
  for(const value of [{testMode:true,state:'complete'},{result:{ok:true,testMode:true}},{data:{ok:true}}]){const h=harness({fetcher:async()=>({ok:true,json:async()=>value})});await assert.rejects(h.service.getPreviewCheckoutStatus(),e=>e.code==='live/invalid_response');}
});
test('same-UID billing read supports Apple without Auth email and strips IDs',async()=>{
  const h=harness({apple:true,billing:billing()});const raw=await h.service.getPreviewBilling();const model=projectLiveBilling(raw);
  assert.deepEqual(h.reads,['synthetic-owner']);assert.equal(h.calls.length,0);assert.equal(model.statusLabel,'契約中');assert.equal(model.portalManageable,true);
  assert.doesNotMatch(JSON.stringify(raw)+JSON.stringify(model),/synthetic-owner|cus_synthetic|sub_synthetic|firebaseUid|stripeCustomerId/);
});
test('absent contact doc is irrelevant to ordinary billing reads and existing management',async()=>{const h=harness({billing:billing()});const m=projectLiveBilling(await h.service.getPreviewBilling());assert.equal(m.portalManageable,true);assert.equal(h.calls.length,0);});
test('Preview billing or another UID binding is rejected instead of displayed',async()=>{
  for(const value of [{firebaseUid:'synthetic-other'},{testMode:true},{previewFirebaseUid:'synthetic-owner'},{stripeLivemode:false}]){
    const h=harness({billing:billing(value)});await assert.rejects(h.service.getPreviewBilling(),e=>e.code==='live/invalid_response');}
});
test('same UID required after Firestore read as well as before',async()=>{
  const wait=deferred(),h=harness();const service=createLiveCheckoutService({auth:h.auth,origin:LIVE_ORIGIN,readOwnBilling:()=>wait.promise});
  const p=service.getPreviewBilling();await new Promise(r=>setImmediate(r));h.auth.currentUser={uid:'synthetic-other'};wait.resolve(billing());await assert.rejects(p,e=>e.code==='session_changed');
});
test('flat Live review strictly requires 550/month/jpy and rejects fabricated missing-email evidence',()=>{
  const value=projectLiveCheckoutReview(review());assert.equal(value.amountLabel,'月額550円');assert.equal(value.firstChargeLabel,'申込時（即時）');assert.doesNotMatch(value.trialNote,/テスト|Preview/);
  for(const change of [{unitAmount:500},{currency:'usd'},{interval:'year'},{reviewToken:'bad'},{maskedEmail:'未設定'},{maskedEmail:'synthetic-uid'},{maskedEmail:' '},{chargeTiming:'unknown'}])assert.throws(()=>projectLiveCheckoutReview({...review(),...change},()=>true));
});
test('Live session rejects Test keys/secrets and accepts only matching Live prefixes',()=>{
  const raw={ok:true,publishableKey:'pk_live_synthetic123456',clientSecret:'cs_live_synthetic_secret_synthetic'};assert.equal(projectLiveCheckoutSession(raw).publishableKey,raw.publishableKey);
  for(const change of [{testMode:true},{publishableKey:'pk_test_synthetic123456'},{clientSecret:'cs_test_synthetic_secret_synthetic'}])assert.throws(()=>projectLiveCheckoutSession({...raw,...change}));
});
test('complete URL/Stripe status without confirmed same-UID billing never establishes success',()=>{
  assert.equal(projectLiveCheckoutStatus({ok:true,checkoutStatus:'complete',billingState:'pending'}).state,'processing');
  assert.equal(projectLiveCheckoutStatus({ok:true,checkoutStatus:'complete',billingState:'confirmed'}).state,'complete');
  assert.equal(projectLiveCheckoutStatus({ok:true,checkoutStatus:'open',billingState:'confirmed'}).state,'open');
  for(const raw of [{ok:true},{ok:true,checkoutStatus:'complete',testMode:true},{ok:true,checkoutStatus:'complete',billingState:'success'}])assert.throws(()=>projectLiveCheckoutStatus(raw));
});
test('old review contract amount is never misreported as a new 550 invoice',()=>{
  const m=projectLiveBilling({live:true,syncState:'synced',billing:billing({amount:500,latestInvoiceTotal:0}).data,verifiedBinding:false,portalManageable:true});
  assert.doesNotMatch(m.amountLabel,/550|500/);assert.equal(m.portalManageable,true);assert.notEqual(m.outcome,'active');
});
test('period-end cancellation keeps saved deadline and separate refund conditions',()=>{
  const m=projectLiveBilling({live:true,syncState:'synced',billing:billing({cancelAtPeriodEnd:true}).data,verifiedBinding:true,portalManageable:true});assert.equal(m.cancelLabel,'期間末に解約予定');assert.match(m.periodEndLabel,/日本時間/);assert.match(m.accessLabel,/契約期間の終了まで/);
});
test('Portal links reject Test mode, credentials, alternate origins, fragments and redirect parameters',()=>{
  for(const url of ['https://billing.stripe.com/p/session/test_synthetic','https://billing.stripe.com.evil.test/p/session/live_x','https://user@billing.stripe.com/p/session/live_x','https://billing.stripe.com/p/session/live_x?next=x','https://billing.stripe.com/p/session/live_x#x'])assert.throws(()=>projectLivePortalSession({ok:true,portalUrl:url}));
});
test('production CSP permits exact Live endpoints and excludes Preview, webhook, inline/eval',async()=>{
  const c=JSON.parse(await readFile(new URL('../firebase.json',import.meta.url),'utf8'));const rule=c.hosting.headers.find(r=>r.source==='/account/**');const p=rule.headers.find(h=>h.key==='Content-Security-Policy').value;
  assert.ok(p.includes(LIVE_CHECKOUT_ENDPOINT));assert.ok(p.includes(LIVE_PORTAL_ENDPOINT));assert.doesNotMatch(p,/us-central1|Preview|stripeWebhook|unsafe-inline|unsafe-eval/);
  assert.ok(p.includes("form-action 'none'"));const r=c.hosting.headers.find(r=>r.source==='/billing/success/**');assert.match(r.headers[0].value,/connect-src 'none'/);
});
test('success entry uses a fixed local return and makes no success claim from URL data',async()=>{
  const html=await readFile(new URL('../public/billing/success/index.html',import.meta.url),'utf8');const js=await readFile(new URL('../public/assets/billing-return.mjs',import.meta.url),'utf8');
  assert.doesNotMatch(html,/支払いが完了しました|登録が完了しました|✅/);assert.match(html,/完了とは扱いません/);assert.equal(js.trim().split('\n').at(-1),"location.replace('/account/?checkout=return');");assert.doesNotMatch(js,/searchParams|localStorage|sessionStorage|fetch\(/);
});
test('stale active/trialing billing never claims current use or completes return sync',()=>{
 const nowMs=1795374000000;
 for(const change of [{currentPeriodEnd:{seconds:1}},{currentPeriodEnd:null},{status:'trialing',trialEnd:{seconds:1}},{status:'trialing',trialEnd:null}]){
  const model=projectLiveBilling({live:true,syncState:'synced',billing:billing({...change,cancelAtPeriodEnd:true}).data,verifiedBinding:true,portalManageable:true},{nowMs});
  assert.equal(model.outcome,'stored');assert.doesNotMatch(model.accessLabel,/利用できます/);assert.equal(model.portalManageable,true);
 }
 const model=projectLiveBilling({live:true,syncState:'synced',billing:billing({status:'trialing',trialEnd:{seconds:1798000000}}).data,verifiedBinding:true},{nowMs});assert.equal(model.outcome,'active');
});
test('Live Portal query-secret format matches server without allowing Test or redirect data',()=>{
 assert.equal(projectLivePortalSession({ok:true,portalUrl:'https://billing.stripe.com/p/session?secret=live_synthetic'}),'https://billing.stripe.com/p/session?secret=live_synthetic');
 for(const suffix of ['?secret=test_synthetic','?secret=preview_synthetic','?secret=live_x&next=x','?secret=live_x&secret=other','?secret=live%5Fx'])assert.throws(()=>projectLivePortalSession({ok:true,portalUrl:'https://billing.stripe.com/p/session'+suffix}));
});
test('public Privacy preserves existing audio purposes, processing and non-retention disclosures',async()=>{
 const html=await readFile(new URL('../public/privacy/index.html',import.meta.url),'utf8');
 for(const copy of ['音声入力情報（任意）','任意の音声入力の文字起こし','音声入力は任意です。','録音音声や未送信の変換結果を運営者のデータベースやログへ保存しません。','連絡先確認トークンはハッシュで保存','90日','30日'])assert.ok(html.includes(copy));
 assert.doesNotMatch(html,/本番向け通知は未実装|現在の実装は本人限定Preview/);
});
