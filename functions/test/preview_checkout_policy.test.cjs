'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {loadStarSource} = require('./support/star_source_loader.cjs');
const {assessPreviewCheckout, PreviewCheckoutPolicyError, MIN_PREVIEW_TRIAL_REMAINING_SECONDS} = loadStarSource()('previewCheckoutPolicy');

const DAY = 86400000;
const NOW = new Date('2026-11-14T10:00:00.321Z');
const missing = () => ({kind: 'missing'});
const found = data => ({kind: 'found', data});
const stamp = millis => Object.freeze({toMillis: () => millis});
const trial = (overrides = {}) => found({
  trialId: 'initial_trial_v2', policyVersion: 'initial_trial_v2', durationDays: 21,
  status: 'active', startedAt: stamp(NOW.getTime() - 10 * DAY),
  endsAt: stamp(NOW.getTime() + 11 * DAY),
  aiRequestUsed: 20, aiRequestLimit: 20, aiCostMicrosUsed: 1000000,
  ...overrides,
});
const fixture = overrides => ({
  identity: {uid: 'synthetic-owner', emailVerified: true},
  appAccountExists: true,
  billing: missing(), trial: missing(), planKey: 'premium_monthly', now: new Date(NOW),
  ...overrides,
});
function rejected(overrides, code) {
  assert.throws(() => assessPreviewCheckout(fixture(overrides)), error => {
    assert.ok(error instanceof PreviewCheckoutPolicyError);
    assert.equal(error.code, code);
    assert.match(error.message, /[ぁ-んァ-ヶ一-龠]/);
    assert.doesNotMatch(error.message, /synthetic-owner|cus_|sub_|price_|@example|secret/);
    return true;
  });
}
function immediate(overrides = {}) {
  const decision = assessPreviewCheckout(fixture(overrides));
  assert.deepEqual(decision, {
    planKey: 'premium_monthly', currency: 'jpy', unitAmount: 550, interval: 'month',
    chargeTiming: 'immediate', firstChargeAtSeconds: Math.floor(NOW.getTime() / 1000),
  });
}

test('unstarted trial and missing billing produce a 550JPY monthly immediate decision without starting trial', () => immediate());
test('coherent none billing can proceed without creating or rewriting billing', () => immediate({billing: found({plan: 'none', status: 'none'})}));
test('canonical canceled history can proceed without claiming a Stripe lookup', () => immediate({billing: found({plan: 'none', status: 'canceled', cancelAtPeriodEnd: true})}));

for (const [name, identity] of [
  ['missing', null], ['undefined', undefined], ['empty UID', {uid: '', emailVerified: true}],
  ['nonstring UID', {uid: 123, emailVerified: true}], ['whitespace UID', {uid: ' synthetic ', emailVerified: true}],
  ['path UID', {uid: 'other/owner', emailVerified: true}], ['control UID', {uid: 'owner\u0000', emailVerified: true}],
  ['overlong UID', {uid: 'x'.repeat(129), emailVerified: true}],
]) test(`authentication rejects ${name}`, () => rejected({identity}, 'unauthenticated'));
for (const value of [false, undefined, 'true', 1]) {
  test(`email verification must be server boolean true, not ${String(value)}`, () => rejected({identity: {uid: 'synthetic-owner', emailVerified: value}}, 'email_unverified'));
}
for (const value of [false, undefined]) {
  test(`server app-profile existence is required: ${String(value)}`, () => rejected({appAccountExists: value}, 'app_account_required'));
}
for (const value of [undefined, '', 'annual', 'price_arbitrary', {planKey: 'premium_monthly', amount: 1}, 'premium_monthly ']) {
  test(`plan allowlist rejects ${typeof value === 'object' ? 'client pricing object' : String(value)}`, () => rejected({planKey: value}, 'plan_not_allowed'));
}
for (const [name, value] of [['invalid Date', new Date(NaN)], ['missing clock', undefined], ['string clock', NOW.toISOString()], ['numeric clock', NOW.getTime()], ['Timestamp clock', stamp(NOW.getTime())]]) {
  test(`server clock rejects ${name}`, () => rejected({now: value}, 'server_clock_invalid'));
}

for (const status of ['active', 'trialing']) {
  test(`saved paid/${status} blocks a new Session, including a stale saved period`, () => {
    rejected({billing: found({plan: 'paid', status, currentPeriodEnd: new Date('2000-01-01'), cancelAtPeriodEnd: true})}, 'existing_subscription');
  });
}
for (const [plan, status] of [
  ['none', 'active'], ['paid', 'canceled'], ['none', 'past_due'], ['none', 'unpaid'],
  ['none', 'incomplete'], ['none', 'incomplete_expired'], ['none', 'paused'], ['none', 'future_status'],
]) test(`unresolved billing ${plan}/${status} cannot start Checkout`, () => rejected({billing: found({plan, status})}, 'billing_unresolved'));
for (const [name, billing] of [['denied', {kind: 'denied'}], ['unavailable', {kind: 'unavailable'}], ['partial checkout', found({stripeCustomerId: 'cus_synthetic', checkoutSessionId: 'cs_synthetic'})], ['null data', found(null)], ['array data', found([])], ['bad cancellation flag', found({plan: 'none', status: 'none', cancelAtPeriodEnd: 'false'})], ['inconsistent cancellation', found({plan: 'none', status: 'none', cancelAtPeriodEnd: true})]]) {
  test(`billing source blocks ${name}`, () => rejected({billing}, 'billing_unresolved'));
}

for (const [name, value] of [['denied', {kind: 'denied'}], ['unavailable', {kind: 'unavailable'}], ['missing data', found(undefined)], ['array data', found([])]]) {
  test(`trial source ${name} never means unstarted`, () => rejected({trial: value}, 'trial_unresolved'));
}
for (const status of [undefined, 'none', 'ended', 'trialing']) {
  test(`unknown trial status ${String(status)} is not converted into immediate charging`, () => rejected({trial: trial({status})}, 'trial_unresolved'));
}
for (const [name, overrides] of [
  ['missing start', {startedAt: undefined}], ['missing end', {endsAt: undefined}],
  ['browser date string', {endsAt: new Date(NOW.getTime() + DAY).toISOString()}],
  ['browser numeric date', {endsAt: NOW.getTime() + DAY}],
  ['throwing timestamp', {endsAt: {toMillis() { throw new Error('synthetic secret'); }}}],
  ['invalid timestamp', {endsAt: stamp(NaN)}], ['fractional timestamp', {endsAt: stamp(NOW.getTime() + DAY + .5)}],
  ['negative timestamp', {startedAt: stamp(-1)}],
  ['future start', {startedAt: stamp(NOW.getTime() + 1)}],
  ['end before start', {endsAt: stamp(NOW.getTime() - 11 * DAY)}],
  ['zero trial duration', {endsAt: stamp(NOW.getTime() - 10 * DAY)}],
  ['longer than immutable 21 days', {endsAt: stamp(NOW.getTime() + 11 * DAY + 1)}],
  ['expired status with future end', {status: 'expired'}],
]) test(`trial timestamp validation rejects ${name}`, () => rejected({trial: trial(overrides)}, 'trial_invalid'));
for (const overrides of [{trialId: 'other_trial'}, {policyVersion: 'initial_trial_v3'}, {durationDays: 22}]) {
  test(`trial immutable policy metadata rejects ${Object.keys(overrides)[0]}`, () => rejected({trial: trial(overrides)}, 'trial_invalid'));
}

for (const [name, status, endOffset] of [
  ['active equality', 'active', 0], ['expired equality', 'expired', 0],
  ['active past boundary', 'active', -1], ['expired past boundary', 'expired', -DAY],
]) {
  test(`${name} is immediate and never sends a past trial_end`, () => immediate({trial: trial({status, startedAt: stamp(NOW.getTime() - 21 * DAY), endsAt: stamp(NOW.getTime() + endOffset)})}));
}
for (const [name, remaining] of [
  ['one millisecond remaining', 1], ['48 hours minus one millisecond', 48 * 3600000 - 1],
  ['exactly 48 hours', 48 * 3600000], ['processing buffer short by one millisecond', MIN_PREVIEW_TRIAL_REMAINING_SECONDS * 1000 - 1],
]) {
  test(`${name} blocks instead of extending trial or charging immediately`, () => rejected({trial: trial({startedAt: stamp(NOW.getTime() - DAY), endsAt: stamp(NOW.getTime() + remaining)})}, 'trial_too_short'));
}

test('exact 48 hours plus the processing minute is the allowed lower boundary', () => {
  const end = NOW.getTime() + MIN_PREVIEW_TRIAL_REMAINING_SECONDS * 1000;
  const decision = assessPreviewCheckout(fixture({trial: trial({startedAt: stamp(NOW.getTime() - DAY), endsAt: stamp(end)})}));
  assert.equal(decision.chargeTiming, 'trial_end');
  assert.equal(decision.trialEndSeconds, Math.ceil(end / 1000));
  assert.equal(decision.hamcareTrialEndsAtMillis, end);
});
test('existing whole-second trial end is preserved exactly for Stripe', () => {
  const end = Math.floor((NOW.getTime() + 11 * DAY) / 1000) * 1000;
  const decision = assessPreviewCheckout(fixture({trial: trial({endsAt: stamp(end)})}));
  assert.equal(decision.firstChargeAtSeconds, end / 1000);
  assert.equal(decision.trialEndSeconds, end / 1000);
});
test('millisecond trial end only rounds up by under one second, never appends 21 days', () => {
  const end = NOW.getTime() + 11 * DAY;
  const decision = assessPreviewCheckout(fixture({trial: trial()}));
  assert.equal(decision.hamcareTrialEndsAtMillis, end);
  assert.equal(decision.trialEndSeconds, decision.firstChargeAtSeconds);
  assert.ok(decision.trialEndSeconds * 1000 >= end);
  assert.ok(decision.trialEndSeconds * 1000 - end < 1000);
});
test('server Date timestamps and older shorter periods preserve their existing end', () => {
  const end = NOW.getTime() + 3 * DAY;
  const decision = assessPreviewCheckout(fixture({trial: found({status: 'active', startedAt: new Date(NOW.getTime() - DAY), endsAt: new Date(end)})}));
  assert.equal(decision.hamcareTrialEndsAtMillis, end);
});
test('trial counters, used-up budgets and original records are never mutated or reset', () => {
  const record = trial(); Object.freeze(record.data); Object.freeze(record);
  const billing = found(Object.freeze({plan: 'none', status: 'none'})); Object.freeze(billing);
  const original = {...record.data};
  const one = assessPreviewCheckout(fixture({billing, trial: record}));
  const two = assessPreviewCheckout(fixture({billing, trial: record}));
  assert.deepEqual(one, two); assert.deepEqual(record.data, original);
  assert.equal(record.data.aiRequestUsed, 20); assert.equal(record.data.aiCostMicrosUsed, 1000000);
});
test('policy uses the explicitly injected server clock without Date.now', () => {
  const old = Date.now; Date.now = () => { throw new Error('implicit clock forbidden'); };
  try { immediate(); }
  finally { Date.now = old; }
});
test('policy result has approved non-sensitive fields only', () => {
  const billing = found({plan: 'none', status: 'canceled', stripeCustomerId: 'cus_private_fixture', stripeSubscriptionId: 'sub_private_fixture', stripePriceId: 'price_private_fixture'});
  const result = assessPreviewCheckout(fixture({billing, trial: trial()}));
  assert.deepEqual(Object.keys(result).sort(), ['planKey','currency','unitAmount','interval','chargeTiming','firstChargeAtSeconds','trialEndSeconds','hamcareTrialEndsAtMillis'].sort());
  assert.doesNotMatch(JSON.stringify(result), /cus_|sub_|price_|synthetic-owner|email|token/i);
  assert.equal(result.unitAmount, 550); assert.equal(result.currency, 'jpy'); assert.equal(result.interval, 'month');
});
