import test, { afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createCheckoutController } from '../public/assets/checkout-view.mjs';
import { createPreviewCheckoutService, PREVIEW_CHECKOUT_ENDPOINT } from '../public/assets/checkout-service.mjs';

const originalDocument = globalThis.document;
afterEach(() => { globalThis.document = originalDocument; });
const ids = ['checkout-panel', 'checkout-title', 'checkout-error', 'checkout-status', 'checkout-review', 'checkout-account-name', 'checkout-account-email', 'checkout-plan-name', 'checkout-amount', 'checkout-card-date', 'checkout-first-charge-date', 'checkout-first-charge-amount', 'checkout-trial-note', 'checkout-terms', 'checkout-start', 'checkout-payment', 'checkout-embed', 'checkout-result', 'checkout-result-title', 'checkout-result-copy', 'checkout-refresh', 'checkout-back', 'checkout-cancel', 'checkout-preview-panel', 'checkout-preview-status', 'checkout-preview-details', ...['state','plan','amount','first-charge','next-charge','period-start','period-end','trial-end','cancel','synced-at','entitlement'].map(suffix => 'checkout-preview-' + suffix)];
class Element {
  constructor() { this.textContent = ''; this.hidden = false; this.disabled = false; this.checked = false; this.listeners = new Map(); this.attributes = new Map(); this.focused = false; this.childrenCleared = 0; }
  addEventListener(name, action) { this.listeners.set(name, action); }
  removeEventListener(name, action) { if (this.listeners.get(name) === action) this.listeners.delete(name); }
  setAttribute(name, value) { this.attributes.set(name, value); }
  focus() { this.focused = true; }
  replaceChildren() { this.childrenCleared++; }
  event(name = 'click') { this.listeners.get(name)?.({ preventDefault() {} }); }
}
const quote = () => ({ testMode: true, planKey: 'premium_monthly', amount: 550, currency: 'jpy', interval: 'month', reviewToken: 'opaque_fixture_review_token_12345', account: { nickname: 'テスト', maskedEmail: 'te***@example.test' }, billing: { kind: 'immediate', cardRegistrationAt: '2026-11-14T09:20:00Z', firstChargeAt: '2026-11-14T09:20:00Z', firstChargeAmount: 550, trialEndsAt: null } });
const session = () => ({ testMode: true, publishableKey: 'pk_test_fixtureKey0000', clientSecret: 'cs_test_fixture_secret_fakeValueOnly' });
const deferred = () => { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b; }); return { promise, resolve, reject }; };
const settle = async () => { for (let i=0;i<5;i++) await new Promise(resolve => setImmediate(resolve)); };
const billing = (status = 'active') => ({testMode:true,syncState:'synced',billing:{planKey:'premium_monthly',amount:550,currency:'jpy',interval:'month',status,currentPeriodStart:'2026-11-14T09:20:00Z',currentPeriodEnd:'2026-12-14T09:20:00Z',trialEnd:null,firstChargeAt:'2026-11-14T09:20:00Z',nextChargeAt:'2026-12-14T09:20:00Z',cancelAtPeriodEnd:false,syncedAt:'2026-11-14T09:20:01Z',entitlementMirror:true}});
class Clock {
  constructor(){this.time=0;this.next=1;this.tasks=new Map();}
  setTimeout(fn,ms){const id=this.next++;this.tasks.set(id,{at:this.time+ms,fn});return id;}
  clearTimeout(id){this.tasks.delete(id);}
  async advance(ms){const end=this.time+ms;for(;;){const item=[...this.tasks.entries()].filter(([,task])=>task.at<=end).sort((a,b)=>a[1].at-b[1].at)[0];if(!item)break;this.time=item[1].at;this.tasks.delete(item[0]);item[1].fn();await settle();}this.time=end;}
}
function setup(overrides = {}) {
  const elements = Object.fromEntries(ids.map(id => [id,new Element()]));
  globalThis.document = { getElementById: id => { assert.ok(elements[id], id); return elements[id]; } };
  const calls = { review: 0, create: [], status: 0, billing: 0, cancel: 0, show: 0, back: 0, loads: [], mounts: 0, destroys: 0, stripeOptions: null };
  const service = {
    async reviewPreviewCheckout() { calls.review++; return quote(); },
    async createPreviewCheckout(body) { calls.create.push(body); return session(); },
    async getPreviewCheckoutStatus() { calls.status++; return { testMode: true, state: 'open' }; },
    async cancelPreviewCheckout() { calls.cancel++; return { testMode: true, state: 'canceled' }; },
    async getPreviewBilling() { calls.billing++; return billing(); },
    ...overrides.service,
  };
  const instance = { mount(target) { assert.equal(target,elements['checkout-embed']); calls.mounts++; }, destroy() { calls.destroys++; } };
  const loadStripe = overrides.loadStripe || (async key => { calls.loads.push(key); return { async initEmbeddedCheckout(options) { calls.stripeOptions = options; return instance; } }; });
  const clock = new Clock();
  const controller = createCheckoutController({ service, onShow() { calls.show++; }, onBack() { calls.back++; }, loadStripe, timers:clock });
  const consent = () => { elements['checkout-terms'].checked = true; elements['checkout-terms'].event('change'); };
  const start = async () => { consent(); elements['checkout-start'].event(); await settle(); };
  return { elements, calls, service, controller, consent, start, instance, clock };
}

test('opening only reviews server facts; consent is required before any Stripe call', async () => {
  const x = setup(); await x.controller.open();
  assert.equal(x.calls.review,1); assert.equal(x.calls.create.length,0); assert.equal(x.calls.loads.length,0);
  assert.equal(x.elements['checkout-start'].disabled,true); assert.equal(x.elements['checkout-account-email'].textContent,'te***@example.test');
  x.elements['checkout-start'].event(); await settle(); assert.equal(x.calls.create.length,0);
});
function appleTransport(profiles = {ownerExists:true,petExists:true}) {
  const calls=[];const user={uid:'synthetic-owner',email:null,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-apple-subject'}]};
  user.getIdTokenResult=async()=>({token:'synthetic-auth-header-only',signInProvider:'apple.com',claims:{aud:'demo-hamcare-no-email',iss:'https://securetoken.google.com/demo-hamcare-no-email',sub:user.uid,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['synthetic-apple-subject']}}}});
  const auth={app:{options:{projectId:'demo-hamcare-no-email'}},currentUser:user};
  const service=createPreviewCheckoutService({auth,readOwnProfiles:async uid=>{assert.equal(uid,'synthetic-owner');return profiles;},fetchRequest:async(url,options)=>{
    calls.push({url,options});return {ok:true,status:200,json:async()=>url.endsWith('/review')?{...quote(),account:{nickname:'テスト',maskedEmail:'未設定'}}:session()};
  }});
  return {service,calls,auth};
}
test('verified Apple without email reaches review while consent still gates Session creation', async () => {
  const transport=appleTransport(),x=setup({service:transport.service});await x.controller.open();
  assert.equal(x.elements['checkout-account-email'].textContent,'未設定');assert.equal(x.elements['checkout-account-name'].textContent,'テスト');
  assert.equal(x.elements['checkout-error'].hidden,true);assert.equal(x.elements['checkout-start'].disabled,true);
  x.elements['checkout-start'].event();await settle();assert.equal(transport.calls.length,1);assert.equal(x.calls.loads.length,0);
  x.consent();assert.equal(x.elements['checkout-start'].disabled,false);assert.equal(transport.calls.length,1);
  x.elements['checkout-start'].event();x.elements['checkout-start'].event();await settle();
  const created=transport.calls.filter(c=>c.url===PREVIEW_CHECKOUT_ENDPOINT+'/session');assert.equal(created.length,1);
  assert.deepEqual(Object.keys(JSON.parse(created[0].options.body)).sort(),['planKey','reviewToken','termsAccepted']);
  const visible=Object.values(x.elements).map(e=>e.textContent).join(' ');
  assert.doesNotMatch(visible,/synthetic-owner|synthetic-apple|synthetic-auth|opaque_fixture|cs_test|pk_test/);
  assert.ok(transport.calls.every(c=>!c.url.includes('synthetic-')));assert.equal(transport.auth.currentUser.email,null);
});
test('invented missing-email display never enables review or loads Stripe', async () => {
  const x=setup({service:{async reviewPreviewCheckout(){return {...quote(),account:{nickname:'Test',maskedEmail:'未設定'}};}}});
  await x.controller.open();x.consent();x.elements['checkout-start'].event();await settle();
  assert.equal(x.elements['checkout-error'].hidden,false);assert.equal(x.elements['checkout-start'].disabled,true);assert.equal(x.calls.create.length,0);assert.equal(x.calls.loads.length,0);
});
test('cloning a verified server review loses its missing-email provenance', async () => {
  const t=appleTransport(),x=setup({service:{...t.service,async reviewPreviewCheckout(){return {...await t.service.reviewPreviewCheckout()};}}});
  await x.controller.open();assert.equal(x.elements['checkout-error'].hidden,false);assert.equal(x.elements['checkout-start'].disabled,true);
  assert.ok(t.calls.every(c=>c.url.endsWith('/review')));assert.equal(x.calls.loads.length,0);
});
for(const [label,profiles] of [['owner absent',{ownerExists:false,petExists:true}],['pet absent',{ownerExists:true,petExists:false}],['new empty account',{ownerExists:false,petExists:false}]]){
  test('email-less Apple '+label+' cannot reach confirmation',async()=>{
    const t=appleTransport(profiles),x=setup({service:t.service});await x.controller.open();x.consent();x.elements['checkout-start'].event();await settle();
    assert.equal(x.elements['checkout-error'].hidden,false);assert.equal(x.elements['checkout-start'].disabled,true);assert.ok(t.calls.every(c=>c.url.endsWith('/review')));assert.equal(x.calls.loads.length,0);
  });
}
test('double clicks send a single allowlisted request and mount Stripe once', async () => {
  const pending = deferred(); const x = setup({ service: { async createPreviewCheckout(body) { x.calls.create.push(body); return pending.promise; } } });
  await x.controller.open(); x.consent(); x.elements['checkout-start'].event(); x.elements['checkout-start'].event();
  assert.equal(x.calls.create.length,1); assert.deepEqual(x.calls.create[0],{ planKey: 'premium_monthly', reviewToken: quote().reviewToken, termsAccepted: true });
  pending.resolve(session()); await settle(); assert.equal(x.calls.mounts,1); assert.equal(x.elements['checkout-terms'].disabled,true);
  assert.equal(x.calls.stripeOptions.clientSecret,session().clientSecret);
  const visible=Object.values(x.elements).map(e=>e.textContent).join(' '); assert.doesNotMatch(visible,/cs_test|pk_test|opaque_fixture/);
});
test('clear during a pending review prevents old account details from reappearing', async () => {
  const pending=deferred(); const x=setup({ service:{ async reviewPreviewCheckout(){return pending.promise;} } });
  const opening=x.controller.open(); x.controller.clear(); pending.resolve(quote()); await opening;
  assert.equal(x.elements['checkout-account-name'].textContent,''); assert.equal(x.elements['checkout-start'].disabled,true);
});
test('clear after session creation destroys a late Stripe instance without mounting', async () => {
  const pending=deferred(); let destroys=0,mounts=0;
  const x=setup({loadStripe:async()=>({initEmbeddedCheckout:()=>pending.promise})}); await x.controller.open(); x.consent(); x.elements['checkout-start'].event(); await settle();
  x.controller.clear(); pending.resolve({destroy(){destroys++;},mount(){mounts++;}}); await settle();
  assert.equal(destroys,1); assert.equal(mounts,0); assert.equal(x.elements['checkout-account-email'].textContent,'');
});
test('Stripe completion rechecks server state and explicitly denies production entitlement reflection', async () => {
  const x=setup({service:{async getPreviewCheckoutStatus(){x.calls.status++;return {testMode:true,state:'complete',paymentStatus:'paid'};}}}); await x.controller.open(); await x.start();
  x.calls.stripeOptions.onComplete(); await settle(); assert.equal(x.calls.status,1); assert.equal(x.calls.destroys,1);
  assert.match(x.elements['checkout-result-title'].textContent,/Test Mode/); assert.match(x.elements['checkout-result-copy'].textContent,/利用権限には反映されません/); assert.equal(x.elements['checkout-payment'].hidden,true);
});
test('complete without a confirmed payment stays pending rather than claiming success', async () => {
  const x=setup({service:{async getPreviewCheckoutStatus(){return {testMode:true,state:'complete',paymentStatus:'unpaid'};}}}); await x.controller.open(); await x.start();
  x.calls.stripeOptions.onComplete(); await settle(); assert.match(x.elements['checkout-result-title'].textContent,/確認しています/); assert.doesNotMatch(x.elements['checkout-result-title'].textContent,/完了しました/);
});
test('cancel closes Stripe and records only a server-confirmed cancellation', async () => {
  const x=setup(); await x.controller.open(); await x.start(); x.elements['checkout-cancel'].event(); await settle();
  assert.equal(x.calls.cancel,1); assert.equal(x.calls.destroys,1); assert.equal(x.elements['checkout-terms'].checked,false); assert.match(x.elements['checkout-result-title'].textContent,/キャンセル/); assert.equal(x.calls.back,0);
});
test('back cancels an open session before returning without logging the user out', async () => {
  const x=setup(); await x.controller.open(); await x.start(); x.elements['checkout-back'].event(); await settle();
  assert.equal(x.calls.cancel,1); assert.equal(x.calls.back,1); assert.equal(x.elements['checkout-account-name'].textContent,'');
});
test('cancellation network failure does not claim cancellation or navigate away', async () => {
  const x=setup({service:{async cancelPreviewCheckout(){throw {code:'preview/network-error',message:'private@example.test'};}}}); await x.controller.open(); await x.start(); x.elements['checkout-back'].event(); await settle();
  assert.equal(x.calls.back,0); assert.match(x.elements['checkout-error'].textContent,/通信に失敗/); assert.doesNotMatch(x.elements['checkout-error'].textContent,/private/); assert.equal(x.elements['checkout-payment'].hidden,true);
});
test('server mode or price mismatch cannot create or load Stripe', async () => {
  const x=setup({service:{async reviewPreviewCheckout(){return {...quote(),amount:605};}}}); await x.controller.open(); x.consent(); x.elements['checkout-start'].event(); await settle();
  assert.equal(x.calls.create.length,0); assert.equal(x.calls.loads.length,0); assert.equal(x.elements['checkout-error'].hidden,false);
});
test('return URL restoration only checks the authenticated current session', async () => {
  const x=setup({service:{async getPreviewCheckoutStatus(){x.calls.status++;return {testMode:true,state:'expired'};}}}); await x.controller.resume();
  assert.equal(x.calls.status,1); assert.equal(x.calls.review,0); assert.equal(x.calls.create.length,0); assert.equal(x.calls.mounts,0); assert.match(x.elements['checkout-result-title'].textContent,/期限が切れ/);
});
test('late status response is ignored after account clearing', async () => {
  const pending=deferred(); const x=setup({service:{async getPreviewCheckoutStatus(){return pending.promise;}}});
  const resuming=x.controller.resume(); x.controller.clear(); pending.resolve({testMode:true,state:'complete',paymentStatus:'paid'}); await resuming;
  assert.equal(x.elements['checkout-result-title'].textContent,''); assert.equal(x.elements['checkout-result-copy'].textContent,'');
});
test('returning to review resets consent and does not reuse a card session', async () => {
  const x=setup(); await x.controller.open(); await x.start(); x.elements['checkout-back'].event(); await settle(); await x.controller.open();
  assert.equal(x.elements['checkout-terms'].checked,false); assert.equal(x.elements['checkout-start'].disabled,true); assert.equal(x.calls.mounts,1); assert.equal(x.calls.review,2);
});
test('destroy removes handlers and prevents future review or payment requests', async () => {
  const x=setup(); await x.controller.open(); x.controller.destroy(); await x.controller.open(); x.consent(); x.elements['checkout-start'].event(); await settle();
  assert.equal(x.calls.review,1); assert.equal(x.calls.create.length,0); assert.equal(x.elements['checkout-account-name'].textContent,'');
  for(const id of ['checkout-terms','checkout-start','checkout-refresh','checkout-cancel','checkout-back'])assert.equal(x.elements[id].listeners.size,0);
});

test('expired quote reconciles the server result before a fresh review and renewed consent', async () => {
  const x=setup({service:{async createPreviewCheckout(body){x.calls.create.push(body);throw {code:'review_expired'};},async getPreviewCheckoutStatus(){x.calls.status++;return {testMode:true,state:'none'};}}});
  await x.controller.open();await x.start();
  assert.equal(x.calls.create.length,1);assert.equal(x.calls.loads.length,0);assert.equal(x.elements['checkout-terms'].checked,false);assert.match(x.elements['checkout-error'].textContent,/有効期限/);
  x.elements['checkout-refresh'].event();await settle();
  assert.equal(x.calls.status,1);assert.equal(x.calls.review,1);assert.equal(x.calls.create.length,1);assert.equal(x.elements['checkout-start'].disabled,true);
  x.elements['checkout-back'].event();await settle();await x.controller.open();
  assert.equal(x.calls.back,1);assert.equal(x.calls.review,2);assert.equal(x.calls.create.length,1);assert.equal(x.elements['checkout-terms'].checked,false);assert.equal(x.elements['checkout-start'].disabled,true);
});
test('no-session return cannot claim completion or attempt cancellation before going back', async () => {
  const x=setup({service:{async getPreviewCheckoutStatus(){x.calls.status++;return {testMode:true,state:'none'};}}});await x.controller.resume();
  assert.match(x.elements['checkout-result-title'].textContent,/作成されていません/);assert.equal(x.elements['checkout-cancel'].disabled,true);
  x.elements['checkout-back'].event();await settle();assert.equal(x.calls.cancel,0);assert.equal(x.calls.back,1);
});
test('server processing can be rechecked but is not a completed payment', async () => {
  const x=setup({service:{async getPreviewCheckoutStatus(){x.calls.status++;return {testMode:true,state:'processing'};}}});await x.controller.resume();
  assert.match(x.elements['checkout-result-title'].textContent,/処理状況を確認/);assert.equal(x.elements['checkout-refresh'].disabled,false);assert.doesNotMatch(x.elements['checkout-result-title'].textContent,/完了しました/);
  x.elements['checkout-refresh'].event();await settle();assert.equal(x.calls.status,2);assert.equal(x.calls.create.length,0);
});
test('completed payment discovered during cancellation is not reported as canceled', async () => {
  const x=setup({service:{async cancelPreviewCheckout(){x.calls.cancel++;return {testMode:true,state:'complete',paymentStatus:'paid'};}}});await x.controller.open();await x.start();
  x.elements['checkout-cancel'].event();await settle();assert.match(x.elements['checkout-result-title'].textContent,/Test Mode/);assert.doesNotMatch(x.elements['checkout-result-title'].textContent,/キャンセル/);assert.equal(x.calls.back,0);assert.match(x.elements['checkout-result-copy'].textContent,/利用権限には反映されません/);
});

test('an uncertain create response must reconcile cancellation before navigating back', async () => {
  const cancellation=deferred();
  const x=setup({service:{
    async createPreviewCheckout(body){x.calls.create.push(body);throw {code:'network_error'};},
    async cancelPreviewCheckout(){x.calls.cancel++;return cancellation.promise;},
  }});
  await x.controller.open();await x.start();
  assert.equal(x.calls.create.length,1);assert.equal(x.calls.loads.length,0);assert.equal(x.elements['checkout-cancel'].disabled,false);assert.match(x.elements['checkout-error'].textContent,/通信に失敗/);
  x.elements['checkout-back'].event();await settle();
  assert.equal(x.calls.cancel,1);assert.equal(x.calls.back,0);assert.equal(x.elements['checkout-back'].disabled,true);
  cancellation.resolve({testMode:true,state:'canceled'});await settle();
  assert.equal(x.calls.back,1);assert.equal(x.elements['checkout-account-email'].textContent,'');assert.equal(x.elements['checkout-terms'].checked,false);
});
test('an uncertain create response can discover completion by status without resubmitting', async () => {
  const x=setup({service:{
    async createPreviewCheckout(body){x.calls.create.push(body);throw {code:'network_error'};},
    async getPreviewCheckoutStatus(){x.calls.status++;return {testMode:true,state:'complete',paymentStatus:'paid'};},
  }});
  await x.controller.open();await x.start();x.elements['checkout-refresh'].event();await settle();
  assert.equal(x.calls.status,1);assert.equal(x.calls.review,1);assert.equal(x.calls.create.length,1);assert.equal(x.calls.loads.length,0);assert.equal(x.calls.back,0);
  assert.match(x.elements['checkout-result-title'].textContent,/Test Mode/);assert.match(x.elements['checkout-result-copy'].textContent,/利用権限には反映されません/);
});

test('Stripe completion waits for a signed-Webhook mirror before showing membership success', async () => {
  let synced=false;
  const x=setup({service:{async getPreviewCheckoutStatus(){return {testMode:true,state:'complete',paymentStatus:'paid'};},async getPreviewBilling(){x.calls.billing++;return synced?billing():{testMode:true,syncState:'pending',billing:null};}}});
  await x.controller.resume();await settle();assert.equal(x.calls.billing,1);assert.equal(x.elements['checkout-result-title'].textContent,'支払い情報を確認しています');assert.equal(x.elements['checkout-preview-details'].hidden,true);
  synced=true;await x.clock.advance(5000);assert.equal(x.calls.billing,2);assert.match(x.elements['checkout-result-title'].textContent,/有料会員登録が完了/);assert.equal(x.elements['checkout-preview-state'].textContent,'有料会員');assert.equal(x.elements['checkout-preview-details'].hidden,false);assert.equal(x.clock.tasks.size,0);
  assert.equal(x.elements['checkout-cancel'].disabled,true);assert.equal(x.calls.cancel,0);assert.match(x.elements['checkout-result-copy'].textContent,/本番利用権限には反映されません/);
});
test('payment-attention Webhook mirror does not show active success', async () => {
  const x=setup({service:{async getPreviewCheckoutStatus(){return {testMode:true,state:'complete',paymentStatus:'paid'};},async getPreviewBilling(){x.calls.billing++;const raw=billing('past_due');raw.billing.entitlementMirror=false;return raw;}}});
  await x.controller.resume();await settle();assert.match(x.elements['checkout-result-title'].textContent,/お支払いを確認できません/);assert.equal(x.elements['checkout-preview-state'].textContent,'お支払いの確認が必要です');assert.match(x.elements['checkout-preview-entitlement'].textContent,/無効として保存/);assert.equal(x.clock.tasks.size,0);
});
test('Webhook polling is bounded to six reads and only manual retry starts a new cycle', async () => {
  let synced=false;
  const x=setup({service:{async getPreviewCheckoutStatus(){return {testMode:true,state:'complete',paymentStatus:'paid'};},async getPreviewBilling(){x.calls.billing++;return synced?billing():{testMode:true,syncState:'pending',billing:null};}}});
  await x.controller.resume();await settle();await x.clock.advance(30000);assert.equal(x.calls.billing,6);assert.match(x.elements['checkout-result-title'].textContent,/時間がかかっています/);assert.equal(x.elements['checkout-refresh'].disabled,false);
  await x.clock.advance(60000);assert.equal(x.calls.billing,6);synced=true;x.elements['checkout-refresh'].event();await settle();assert.equal(x.calls.billing,7);assert.match(x.elements['checkout-result-title'].textContent,/有料会員登録が完了/);assert.equal(x.calls.create.length,0);
});
test('a hung mirror read times out at thirty seconds and cannot paint a late success', async () => {
  const pending=deferred();const x=setup({service:{async getPreviewCheckoutStatus(){return {testMode:true,state:'complete',paymentStatus:'paid'};},async getPreviewBilling(){x.calls.billing++;return pending.promise;}}});
  await x.controller.resume();await settle();await x.clock.advance(30000);assert.equal(x.calls.billing,1);assert.match(x.elements['checkout-result-title'].textContent,/時間がかかっています/);
  pending.resolve(billing());await settle();assert.match(x.elements['checkout-result-title'].textContent,/時間がかかっています/);assert.equal(x.elements['checkout-preview-details'].hidden,true);
});
test('clearing identity cancels mirror timers and prevents old-user billing from appearing', async () => {
  const pending=deferred();const x=setup({service:{async getPreviewCheckoutStatus(){return {testMode:true,state:'complete',paymentStatus:'paid'};},async getPreviewBilling(){x.calls.billing++;return pending.promise;}}});
  await x.controller.resume();await settle();x.controller.clear();assert.equal(x.clock.tasks.size,0);pending.resolve(billing());await settle();await x.clock.advance(60000);
  assert.equal(x.calls.billing,1);assert.equal(x.elements['checkout-preview-state'].textContent,'');assert.equal(x.elements['checkout-result-title'].textContent,'');assert.equal(x.elements['checkout-preview-panel'].hidden,true);
});
test('back during Webhook wait cancels polling without canceling the completed subscription', async () => {
  const x=setup({service:{async getPreviewCheckoutStatus(){return {testMode:true,state:'complete',paymentStatus:'paid'};},async getPreviewBilling(){x.calls.billing++;return {testMode:true,syncState:'pending',billing:null};}}});
  await x.controller.resume();await settle();x.elements['checkout-back'].event();await settle();assert.equal(x.calls.back,1);assert.equal(x.calls.cancel,0);assert.equal(x.clock.tasks.size,0);await x.clock.advance(30000);assert.equal(x.calls.billing,1);
});

test('Live return rechecks status and own billing; stopped API never becomes purchase success',async()=>{
 let reads=0,statusReads=0;
 const x=setup({service:{testMode:false,purchaseEnabled:false,getPreviewCheckoutStatus:async()=>{statusReads++;throw {code:'live/purchase_closed'};},getPreviewBilling:async()=>{reads++;return {live:true,syncState:'none'};}}});
 await x.controller.resume();assert.equal(statusReads,1);assert.equal(reads,1);assert.match(x.elements['checkout-error'].textContent,/停止/);assert.doesNotMatch(x.elements['checkout-result-title'].textContent,/完了/);assert.equal(x.calls.create.length,0);x.controller.destroy();
});
test('Live flat review uses live projector and immutable purchase flag still blocks Session',async()=>{
 const x=setup({service:{testMode:false,purchaseEnabled:false,reviewPreviewCheckout:async()=>({ok:true,planKey:'premium_monthly',unitAmount:550,currency:'jpy',interval:'month',reviewToken:'synthetic_review_123456789',termsVersion:'web550-v1',maskedEmail:'go***@example.com',nickname:'テスト',chargeTiming:'immediate',firstChargeAtSeconds:1795374000})}});
 await x.controller.open();assert.equal(x.elements['checkout-account-email'].textContent,'go***@example.com');x.consent();assert.equal(x.elements['checkout-start'].disabled,true);x.elements['checkout-start'].event();await settle();assert.equal(x.calls.create.length,0);x.controller.destroy();
});
