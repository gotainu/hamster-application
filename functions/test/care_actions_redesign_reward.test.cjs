'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {loadStarSource, fakeFirestore} = require('./support/star_source_loader.cjs');
const NOW = new Date('2026-10-12T01:00:00Z');
const request = (actions, extra = {}) => ({dayKey: '2026-10-12', expectedRevision: 0,
  mutationId: 'redesign-reward-0001', operation: 'save', inputUiVersion: 'care_actions_input_v2',
  inputRoute: 'daily_checkin', actions, ...extra});
const batch = () => ({answer: 'not_performed', answerProvenance: 'batch_confirmation'});
function fixture(uid) {
  const {db, admin} = fakeFirestore({clock: () => NOW});
  db.documents.set(`users/${uid}/billing/subscription`, {plan: 'paid', status: 'active'});
  const load = loadStarSource({admin, now: () => NOW});
  return {db, care: load('careActions/careActions'), stars: load('stars/starAwards')};
}
function directCount(db, uid, collection) {
  const prefix = `users/${uid}/${collection}/`;
  return [...db.documents.keys()].filter(key => key.startsWith(prefix) && !key.slice(prefix.length).includes('/')).length;
}
function assertOneReward(db, uid) {
  assert.equal(db.documents.get(`users/${uid}/rewards/stars`).balance, 1);
  assert.equal(db.documents.get(`users/${uid}/rewards/stars`).lifetimeEarned, 1);
  assert.equal(db.documents.get(`users/${uid}/rewards/continuity`).periodEarned, 1);
  assert.equal(db.documents.get(`users/${uid}/rewards/continuity`).lifetimeAchievementDays, 1);
  for (const collection of ['star_awards', 'condition_award_days', 'continuity_credits', 'continuity_award_links', 'continuity_days'])
    assert.equal(directCount(db, uid, collection), 1);
}
test('confirmed none/zero, cleaning details and unknown walk use identical shared reward amount; exact retries never duplicate', async () => {
  const cases = [
    {cageCleaning: batch(), roomWalk: batch()},
    {cageCleaning: {answer: 'performed', answerProvenance: 'item_selection', details: {cleaningType: 'deep_cleaning', beddingReplacement: 'partial'}},
      roomWalk: {answer: 'performed', answerProvenance: 'item_selection', details: {durationMinutes: 121}}},
    {roomWalk: {answer: 'performed', answerProvenance: 'item_selection'}},
  ];
  for (const [index, actions] of cases.entries()) {
    const uid = `redesign-${index}`, {db, care} = fixture(uid), data = request(actions);
    const replies = await Promise.all(Array.from({length: 6}, () => care.saveDailyCareActions({auth: {uid}, data})));
    assert.ok(replies.every(reply => reply.saved && ['processed', 'failed'].includes(reply.reward.status)));
    // An in-flight reward reconciliation may remain retryable; retry only the accepted receipt.
    const retry = await care.retryDailyCareActionReward({auth: {uid}, data: {dayKey: data.dayKey, mutationId: data.mutationId}});
    assert.equal(retry.reward.status, 'processed');
    assertOneReward(db, uid);
    assert.equal(directCount(db, uid, 'daily_care_actions/2026-10-12/revisions'), 1);
    assert.equal(directCount(db, uid, 'care_reward_receipts'), 0);
  }
});
test('v2 care and healthy observation remain one condition category even when processed together', async () => {
  const uid = 'redesign-health-care', {db, care, stars} = fixture(uid);
  const source = db.doc(`users/${uid}/daily_checkins/2026-10-12`);
  db.documents.set(source.path, {condition: 'normal'});
  await Promise.all([
    care.saveDailyCareActions({auth: {uid}, data: request({cageCleaning: batch(), roomWalk: batch()})}),
    stars.processStarRecord({db, uid, kind: 'condition', sourceDateKey: '2026-10-12', snapshot: await source.get(), now: NOW}),
  ]);
  assertOneReward(db, uid);
});
test('v2 correction and cancel retain original immutable receipt and reward without a second issue', async () => {
  const uid = 'redesign-correct', {db, care} = fixture(uid);
  await care.saveDailyCareActions({auth: {uid}, data: request({cageCleaning: batch(), roomWalk: batch()})});
  const revisionPath = `users/${uid}/daily_care_actions/2026-10-12/revisions/0000000001`;
  const original = JSON.stringify(db.documents.get(revisionPath));
  await care.saveDailyCareActions({auth: {uid}, data: request({cageCleaning: {answer: 'performed', answerProvenance: 'item_selection', details: {cleaningType: 'partial_cleaning'}}},
    {expectedRevision: 1, mutationId: 'redesign-correction-0002'})});
  await care.saveDailyCareActions({auth: {uid}, data: request({},
    {expectedRevision: 2, mutationId: 'redesign-cancellation-0003', operation: 'cancel'})});
  assertOneReward(db, uid);
  assert.equal(JSON.stringify(db.documents.get(revisionPath)), original);
  assert.equal(directCount(db, uid, 'daily_care_actions/2026-10-12/revisions'), 3);
  assert.equal(db.documents.get(`users/${uid}/daily_care_actions/2026-10-12`).status, 'cancelled');
});
