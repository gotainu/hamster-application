'use strict';
// Offline synthetic configuration only. No credentials or environment reads.
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {loadStarSource} = require('./support/star_source_loader.cjs');
const load = loadStarSource();
const {parseWebBillingConfig, BillingConfigurationError, assertLiveObject,
  WEB_BILLING_ORIGIN, WEB_BILLING_RETURN_URL, WEB_BILLING_PORTAL_RETURN_URL} = load('webBillingConfig');
const fixture = overrides => ({
  secretKey:'sk_live_' + 'synthetic', publishableKey:'pk_live_' + 'synthetic',
  priceId:'price_syntheticNew550', webhookSecret:'whsec_' + 'synthetic',
  portalConfigurationId:'bpc_syntheticRestricted', origin:WEB_BILLING_ORIGIN,
  returnUrl:WEB_BILLING_RETURN_URL, ...overrides,
});
function denied(raw) {
  assert.throws(() => parseWebBillingConfig(raw), error => {
    assert.ok(error instanceof BillingConfigurationError);
    assert.equal(error.code, 'unavailable');
    assert.equal(error.message, '現在お申し込みを受け付けていません。');
    assert.match(error.message, /[ぁ-んァ-ヶ一-龠]/);
    assert.doesNotMatch(error.message, /secret|publishable|price|webhook|portal|origin|returnUrl|sk_|pk_|whsec_|synthetic|https?:|localhost/i);
    assert.deepEqual(Object.keys(error).sort(), ['code', 'name']);
    return true;
  });
}

test('unconfigured module imports safely and only operation parsing fails closed', () => {
  assert.equal(typeof loadStarSource()('webBillingConfig').parseWebBillingConfig, 'function');
  denied({});
});
test('only explicit complete Live configuration is accepted without mutation', () => {
  const raw = fixture(), before = structuredClone(raw), config = parseWebBillingConfig(raw);
  assert.deepEqual(config, raw); assert.deepEqual(raw, before); assert.equal(Object.isFrozen(config), true);
  assert.equal(WEB_BILLING_ORIGIN, 'https://hamster-breeding-app.web.app');
  assert.equal(WEB_BILLING_RETURN_URL, WEB_BILLING_ORIGIN + '/account/');
});
for (const key of ['secretKey', 'publishableKey', 'priceId', 'webhookSecret', 'portalConfigurationId', 'origin', 'returnUrl']) {
  for (const [name, value] of [['missing', undefined], ['null', null], ['empty', ''], ['number', 123], ['object', {}]]) {
    test(key + ' rejects ' + name + ' without revealing configuration', () => denied(fixture({[key]:value})));
  }
}
for (const raw of [null, undefined, [], 'synthetic']) test('invalid configuration boundary rejects ' + String(raw), () => denied(raw));
for (const [key, value] of [
  ['secretKey','sk_test_synthetic'], ['secretKey','rk_live_synthetic'], ['secretKey','sk_live_'],
  ['secretKey',' sk_live_synthetic'], ['secretKey','sk_live_synthetic\n'],
  ['publishableKey','pk_test_synthetic'], ['publishableKey','pk_live_'],
  ['publishableKey','pk_live_synthetic\r\n'], ['webhookSecret','synthetic'],
  ['webhookSecret','whsec_'], ['webhookSecret','whsec_synthetic\n'],
  ['priceId','price_test_synthetic'], ['priceId','price_preview_synthetic'],
  ['priceId','prod_synthetic'], ['priceId','price_synthetic/value'],
  ['portalConfigurationId','bpc_preview_synthetic'], ['portalConfigurationId','bpc_test_synthetic'],
  ['portalConfigurationId','bpc_synthetic?redirect=other'],
]) test('Live configuration rejects invalid ' + key + ' case ' + value.replace(/\s/g,'_'), () => denied(fixture({[key]:value})));
test('Preview or legacy environment names cannot silently supply production fields', () => {
  denied({HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS:JSON.stringify(fixture()),
    STRIPE_SECRET_KEY:'sk_live_' + 'synthetic', STRIPE_PRICE_ID_MONTHLY:'price_syntheticLegacy500'});
});
test('unknown environment or redirect fields cannot silently expand production configuration', () => {
  for (const extra of [{environment:'preview'}, {mode:'test'}, {successUrl:'https://example.test/'}, {STRIPE_SECRET_KEY:'sk_test_synthetic'}]) denied(fixture(extra));
});
for (const origin of [
  'http://hamster-breeding-app.web.app', 'http://localhost:5000', 'https://localhost',
  'https://hamster-breeding-app.firebaseapp.com',
  'https://hamster-breeding-app--preview-synthetic.web.app',
  'https://hamster-breeding-app.web.app.evil.test',
  'https://hamster-breeding-app.web.app/', 'https://hamster-breeding-app.web.app:443',
  'https://synthetic@hamster-breeding-app.web.app',
]) test('production origin rejects ' + origin, () => denied(fixture({origin})));
for (const returnUrl of [
  'http://localhost:5000/account/', 'https://example.test/account/', '//example.test/account/',
  'https://hamster-breeding-app--preview-synthetic.web.app/account/',
  WEB_BILLING_ORIGIN + '/account', WEB_BILLING_ORIGIN + '/account/contact/',
  WEB_BILLING_ORIGIN + '/account/?next=https://example.test',
  WEB_BILLING_ORIGIN + '/account/?portal=return&next=https://example.test',
  WEB_BILLING_ORIGIN + '/account/#token=synthetic', WEB_BILLING_ORIGIN + '/%61ccount/',
  WEB_BILLING_ORIGIN + '/elsewhere/../account/',
]) test('fixed account return rejects ' + returnUrl, () => denied(fixture({returnUrl})));
test('only the fixed Portal return variant is also allowed', () => {
  assert.equal(parseWebBillingConfig(fixture({returnUrl:WEB_BILLING_PORTAL_RETURN_URL})).returnUrl, WEB_BILLING_PORTAL_RETURN_URL);
});
test('legacy Price recognition is explicit, optional and cannot equal the new Price', () => {
  assert.equal(Object.hasOwn(parseWebBillingConfig(fixture()), 'legacyPriceId'), false);
  assert.equal(parseWebBillingConfig(fixture({legacyPriceId:'price_syntheticLegacy500'})).legacyPriceId, 'price_syntheticLegacy500');
  for (const legacyPriceId of ['', null, 'price_test_synthetic', 'price_syntheticNew550']) denied(fixture({legacyPriceId}));
});
test('every Stripe response must independently prove boolean Live mode', () => {
  assert.doesNotThrow(() => assertLiveObject({livemode:true}));
  for (const value of [null, [], {}, {livemode:false}, {livemode:'true'}, {livemode:1}]) {
    assert.throws(() => assertLiveObject(value), error => error instanceof BillingConfigurationError && error.code === 'unavailable');
  }
});
