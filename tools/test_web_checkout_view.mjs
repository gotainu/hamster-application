import test, { afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createCheckoutController } from '../public/assets/checkout-view.mjs';

const originalDocument = globalThis.document;
afterEach(() => { globalThis.document = originalDocument; });
const ids = ['checkout-panel', 'checkout-title', 'checkout-error', 'checkout-status', 'checkout-review', 'checkout-account-name', 'checkout-account-email', 'checkout-plan-name', 'checkout-amount', 'checkout-card-date', 'checkout-first-charge-date', 'checkout-first-charge-amount', 'checkout-trial-note', 'checkout-terms', 'checkout-start', 'checkout-payment', 'checkout-embed', 'checkout-result', 'checkout-result-title', 'checkout-result-copy', 'checkout-refresh', 'checkout-back', 'checkout-cancel'];
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
function setup(overrides = {}) {
  const elements = Object.fromEntries(ids.map(id => [id,new Element()]));
  globalThis.document = { getElementById: id => { assert.ok(elements[id], id); return elements[id]; } };
  const calls = { review: 0, create: [], status: 0, cancel: 0, show: 0, back: 0, loads: [], mounts: 0, destroys: 0, stripeOptions: null };
  const service = {
    async reviewPreviewCheckout() { calls.review++; return quote(); },
    async createPreviewCheckout(body) { calls.create.push(body); return session(); },
    async getPreviewCheckoutStatus() { calls.status++; return { testMode: true, state: 'open' }; },
    async cancelPreviewCheckout() { calls.cancel++; return { testMode: true, state: 'canceled' }; },
    ...overrides.service,
  };
  const instance = { mount(target) { assert.equal(target,elements['checkout-embed']); calls.mounts++; }, destroy() { calls.destroys++; } };
  const loadStripe = overrides.loadStripe || (async key => { calls.loads.push(key); return { async initEmbeddedCheckout(options) { calls.stripeOptions = options; return instance; } }; });
  const controller = createCheckoutController({ service, onShow() { calls.show++; }, onBack() { calls.back++; }, loadStripe });
  const consent = () => { elements['checkout-terms'].checked = true; elements['checkout-terms'].event('change'); };
  const start = async () => { consent(); elements['checkout-start'].event(); await settle(); };
  return { elements, calls, service, controller, consent, start, instance };
}

test('opening only reviews server facts; consent is required before any Stripe call', async () => {
  const x = setup(); await x.controller.open();
  assert.equal(x.calls.review,1); assert.equal(x.calls.create.length,0); assert.equal(x.calls.loads.length,0);
  assert.equal(x.elements['checkout-start'].disabled,true); assert.equal(x.elements['checkout-account-email'].textContent,'te***@example.test');
  x.elements['checkout-start'].event(); await settle(); assert.equal(x.calls.create.length,0);
});
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
