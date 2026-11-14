#!/usr/bin/env node
// Synthetic, display-only tests. No Firebase, Stripe, network or real account.
import assert from 'node:assert/strict';
import test from 'node:test';
import {PREMIUM_MONTHLY, projectPlanReview} from '../public/assets/plan-model.mjs';

const found = data => ({kind: 'found', data});
const saved = (plan, status, extras = {}) => found({plan, status, ...extras});
const unchecked = '未照合（決済接続時にサーバーで確認）';

function assertRoute(item, route) {
  const projection = projectPlanReview(item);
  assert.equal(projection.route, route);
  assert.equal(projection.canSelectPlan, route === 'review');
  assert.equal(projection.checkoutCheck, unchecked);
  assert.equal(typeof projection.title, 'string');
  assert.equal(typeof projection.detail, 'string');
  assert.match(projection.title + projection.detail, /[ぁ-んァ-ヶ一-龠]/);
  return projection;
}

test('one immutable monthly preview plan has the approved amount and no Price identifier', () => {
  assert.deepEqual(PREMIUM_MONTHLY, {
    key: 'premium_monthly', name: 'HamCare プレミアム',
    taxExclusiveYen: 500, taxAssumptionPercent: 10, taxInclusiveYen: 550,
    interval: 'month', previewOnly: true,
  });
  assert.ok(Object.isFrozen(PREMIUM_MONTHLY));
  assert.throws(() => { PREMIUM_MONTHLY.taxInclusiveYen = 1; }, TypeError);
  assert.ok(!('priceId' in PREMIUM_MONTHLY));
});

test('missing billing is reviewable without claiming Stripe has no subscription', () => {
  const state = assertRoute({kind: 'missing'}, 'review');
  assert.match(state.detail, /保存記録はありません/);
  assert.match(state.detail, /まだ照合していません/);
  assert.match(state.customerRecord, /保存参照なし/);
});

test('coherent none record is reviewable, including legacy absence of cancellation flag', () => {
  for (const extra of [{}, {cancelAtPeriodEnd: false}]) assertRoute(saved('none', 'none', extra), 'review');
});

test('writer-shaped canceled history is reviewable without claiming cancellation is verified', () => {
  for (const flag of [true, false]) {
    const state = assertRoute(saved('none', 'canceled', {cancelAtPeriodEnd: flag}), 'review');
    assert.match(state.detail, /キャンセル済み.*保存/);
    assert.match(state.detail, /まだ照合していません/);
  }
});

test('saved active and trialing paid records route to existing contract management', () => {
  for (const status of ['active', 'trialing']) assertRoute(saved('paid', status), 'manage');
});

test('scheduled cancellation keeps an active subscription out of a duplicate plan flow', () => {
  const state = assertRoute(saved('paid', 'active', {cancelAtPeriodEnd: true}), 'manage');
  assert.match(state.detail, /期間末の解約予定/);
});

test('past or future dates do not become a client entitlement or expiry evaluator', () => {
  const now = Date.now;
  Date.now = () => { throw new Error('clock must not be used for a presentation projection'); };
  try {
    const past = assertRoute(saved('paid', 'active', {currentPeriodEnd: '2000-01-01T00:00:00Z'}), 'manage');
    const future = assertRoute(saved('paid', 'active', {currentPeriodEnd: '2100-01-01T00:00:00Z'}), 'manage');
    assert.deepEqual(past, future);
    assert.deepEqual(past, projectPlanReview(saved('paid', 'active', {currentPeriodEnd: {toDate() { throw new Error('must not parse dates'); }}})));
  } finally { Date.now = now; }
});

test('payment attention, incomplete and paused statuses require resolution', () => {
  for (const status of ['past_due', 'unpaid', 'incomplete', 'incomplete_expired', 'paused']) {
    for (const plan of ['none', 'paid']) assertRoute(saved(plan, status), 'resolve');
  }
});

test('undefined and unknown stored statuses never become a new subscription invitation', () => {
  for (const status of [undefined, null, '', 'unknown', 'expired', 'future_status']) assertRoute(saved('none', status), 'resolve');
});

test('inconsistent plan and status combinations remain closed', () => {
  for (const [plan, status] of [['none', 'active'], ['none', 'trialing'], ['paid', 'none'], ['paid', 'canceled'], ['annual', 'active']]) {
    assertRoute(saved(plan, status), 'resolve');
  }
  assertRoute(saved('none', 'none', {cancelAtPeriodEnd: true}), 'resolve');
});

test('read failures, malformed documents and partial checkout records are unresolved', () => {
  for (const item of [null, undefined, [], {}, {kind: 'denied'}, {kind: 'unavailable'}, {kind: 'unexpected'}, found(null), found([]), found('active'), found({}), found({stripeCustomerId: 'cus_synthetic', checkoutSessionId: 'cs_synthetic'})]) {
    const state = assertRoute(item, 'resolve');
    assert.doesNotMatch(state.detail, /未契約として保存|保存記録はありません/);
  }
});

test('malformed flags and customer reference types do not open plan selection', () => {
  for (const cancelAtPeriodEnd of ['false', 0, null, [], {}]) assertRoute(saved('none', 'none', {cancelAtPeriodEnd}), 'resolve');
  for (const stripeCustomerId of [123, [], {}]) assertRoute(saved('none', 'none', {stripeCustomerId}), 'resolve');
});

test('customer presence uses only the canonical saved field and stays explicitly unchecked', () => {
  assert.match(projectPlanReview(saved('none', 'none', {stripeCustomerId: 'cus_synthetic_private'})).customerRecord, /保存参照あり.*未照合/);
  for (const extra of [{}, {stripeCustomerId: null}, {stripeCustomerId: '  '}, {customerId: 'cus_noncanonical'}]) {
    assert.match(projectPlanReview(saved('none', 'none', extra)).customerRecord, /保存参照なし.*未照合/);
  }
  assert.match(projectPlanReview({kind: 'denied'}).customerRecord, /取得できませんでした/);
});

test('only allowlisted display metadata leaves the model and never account or contract IDs', () => {
  const fixture = {
    stripeCustomerId: 'cus_private_fixture', stripeSubscriptionId: 'sub_private_fixture',
    stripePriceId: 'price_private_fixture', stripeProductId: 'prod_private_fixture',
    checkoutSessionId: 'cs_private_fixture', uid: 'synthetic_subject',
    email: 'private@example.test', idToken: 'synthetic_secret',
  };
  for (const [plan, status] of [['none', 'none'], ['paid', 'active'], ['none', 'past_due']]) {
    const state = projectPlanReview(saved(plan, status, fixture));
    assert.deepEqual(Object.keys(state).sort(), ['route', 'title', 'detail', 'canSelectPlan', 'customerRecord', 'checkoutCheck'].sort());
    const serialized = JSON.stringify(state);
    for (const value of Object.values(fixture)) assert.ok(!serialized.includes(value));
    assert.ok(Object.isFrozen(state));
  }
});

test('caller supplied prices cannot change the fixed monthly preview offer', () => {
  const state = projectPlanReview(saved('none', 'none', {price: 1, amount: 1, planKey: 'annual', priceId: 'price_untrusted'}));
  assert.equal(state.canSelectPlan, true);
  assert.equal(PREMIUM_MONTHLY.key, 'premium_monthly');
  assert.equal(PREMIUM_MONTHLY.taxInclusiveYen, 550);
  assert.doesNotMatch(JSON.stringify(state), /annual|price_untrusted/);
});
