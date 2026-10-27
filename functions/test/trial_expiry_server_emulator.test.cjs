'use strict';

// Local-only acceptance coverage for the four production record handlers.
// No Firebase production project, real AI, or Stripe request is permitted.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {test, before, after} = require('node:test');
const admin = require('firebase-admin');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, serverTimestamp} = require('firebase/firestore');
const {loadStarSource} = require('./support/star_source_loader.cjs');

const HOST = process.env.FIRESTORE_EMULATOR_HOST;
const PROJECT = 'demo-hamcare-trial-expiry';
assert.match(HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated loopback Firestore emulator required');
assert.notEqual(HOST, '127.0.0.1:8080', 'Do not reuse the shared emulator');
assert.equal(process.env.GCLOUD_PROJECT, PROJECT, 'Explicit demo project required');
const END = new Date('2026-10-22T00:00:00.000Z');
const DAY = '2026-10-21';
const SUBJECT = 'synthetic-trial-subject-01';
let app, db, rules, measurement, observation, care, access;
let clock = new Date(END.getTime() - 1);
const ref = (uid, p) => db.doc(`users/${uid}/${p}`);
const timing = {precision: 'date_only', dateKey: DAY, confirmation: 'date_confirmed'};
const base = {dayKey: DAY, date: '2026-10-20T15:00:00Z', subjectId: SUBJECT,
  expectedRevision: 0, mutationId: 'synthetic-trial-mutation-0001'};
const cases = {
  weight: {
    current: `weight_records/${DAY}`,
    receipt: 'weight_record_mutations/synthetic-trial-mutation-0001',
    invoke: (uid, extra = {}) => measurement.saveWeightRecord({auth: {uid}, data: {...base,
      operation: 'save', inputUiVersion: 'measurement_history_v1', timing, weightGrams: 43, memo: '', ...extra}}),
  },
  distance: {
    current: `distance_records/${DAY}`,
    receipt: 'distance_record_mutations/synthetic-trial-mutation-0001',
    invoke: (uid, extra = {}) => measurement.saveDistanceRecord({auth: {uid}, data: {...base,
      operation: 'save', inputUiVersion: 'measurement_history_v1',
      timing: {precision: 'unknown', confirmation: 'unknown'}, mode: 'rotations', rotations: 100, ...extra}}),
  },
  observation: {
    current: `daily_checkins/${DAY}`,
    receipt: `observation_days/${DAY}/mutations/synthetic-trial-mutation-0001`,
    invoke: (uid, extra = {}) => observation.saveDailyCheckin({auth: {uid}, data: {...base,
      operation: 'new_observation', condition: 'normal', concernTags: [], memo: '', timing,
      observationCatalogVersion: 'observation_catalog_v1', inputUiVersion: 'daily_checkin_history_v1', ...extra}}),
  },
  care: {
    current: `daily_care_actions/${DAY}`,
    receipt: `daily_care_actions/${DAY}/mutations/synthetic-trial-mutation-0001`,
    invoke: (uid, extra = {}) => care.saveDailyCareActions({auth: {uid}, data: {
      dayKey: DAY, expectedRevision: 0, mutationId: base.mutationId, operation: 'save',
      inputUiVersion: 'care_actions_input_v2', inputRoute: 'daily_checkin',
      actions: {roomWalk: {answer: 'not_performed', answerProvenance: 'item_selection'}}, ...extra}}),
  },
};

function canonical(x) {
  if (x && typeof x.toMillis === 'function') return [x.seconds, x.nanoseconds];
  if (Array.isArray(x)) return x.map(canonical);
  return x && typeof x === 'object'
    ? Object.fromEntries(Object.keys(x).sort().map(k => [k, canonical(x[k])])) : x;
}
async function allUserDocuments(uid) {
  const found = {};
  async function visit(root) {
    const snapshot = await root.get();
    if (snapshot.exists) found[root.path] = {data: canonical(snapshot.data()), updateTime: canonical(snapshot.updateTime)};
    for (const c of await root.listCollections()) for (const d of (await c.get()).docs) await visit(d.ref);
  }
  await visit(db.doc(`users/${uid}`));
  return found;
}
async function seed(uid, {paid = false, aiUsed = 0} = {}) {
  const b = db.batch();
  b.set(ref(uid, 'pet_profiles/main_pet'), {name: 'Synthetic hamster', species: 'syrian', subjectId: SUBJECT, ownerUid: uid, revision: 1});
  b.set(ref(uid, `pet_subjects/${SUBJECT}`), {subjectId: SUBJECT, ownerUid: uid, petId: 'main_pet', active: true});
  b.set(ref(uid, 'breeding_environments/main_env'), {wheelDiameter: '21'});
  b.set(ref(uid, 'feature_access/initial_trial_v2'), {status: 'active',
    startedAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')),
    endsAt: admin.firestore.Timestamp.fromDate(END), aiRequestLimit: 20, aiRequestUsed: aiUsed,
    aiCostMicrosLimit: 1000000, aiCostMicrosUsed: aiUsed * 50000, aiReservationCostMicros: 50000});
  if (paid) b.set(ref(uid, 'billing/subscription'), {plan: 'paid', status: 'active',
    cancelAtPeriodEnd: true, currentPeriodEnd: admin.firestore.Timestamp.fromDate(new Date('2026-11-22T00:00:00Z'))});
  b.set(ref(uid, 'personalized_reports/first'), {generation: {status: 'generated'}, readyMetrics: ['body'], frozen: true});
  b.set(ref(uid, 'personality_reports/daily_2026-10-20'), {reportId: 'daily_2026-10-20', frozen: true});
  b.set(ref(uid, 'report_pointers/personality_daily'), {reportId: 'daily_2026-10-20'});
  await b.commit();
}

before(async () => {
  rules = await initializeTestEnvironment({projectId: PROJECT, firestore: {host: '127.0.0.1',
    port: Number(HOST.split(':')[1]), rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  await rules.clearFirestore();
  app = admin.initializeApp({projectId: PROJECT}, 'trial-expiry-' + process.pid);
  db = app.firestore();
  const load = loadStarSource({admin: {...admin, firestore: Object.assign(() => db, admin.firestore)}, now: () => clock});
  measurement = load('measurementHistory/measurementHistory');
  observation = load('observationHistory/observationHistory');
  care = load('careActions/careActions');
  access = load('featureTrials');
});
after(async () => {if (rules) await rules.cleanup(); if (db) await db.terminate(); if (app) await app.delete();});

for (const [state, offset, paid, allowed] of [
  ['one_ms_before', -1, false, true], ['at_expiry', 0, false, false],
  ['after_expiry', 1, false, false], ['paid_after_expiry', 1, true, true],
]) for (const [kind, item] of Object.entries(cases)) {
  test(`${state}: server ${kind} save ${allowed ? 'commits atomically' : 'denies without any write'}`, async () => {
    const uid = `synthetic-${state}-${kind}`;
    clock = new Date(END.getTime() + offset);
    await seed(uid, {paid});
    assert.equal((await access.getFeatureAccess(uid, clock)).allowed, allowed);
    const before = await allUserDocuments(uid);
    if (!allowed) {
      await assert.rejects(item.invoke(uid), e => e.code === 'permission-denied');
      assert.deepEqual(await allUserDocuments(uid), before, 'Denial must leave current, revisions, receipts and rewards unchanged');
      return;
    }
    const result = await item.invoke(uid);
    assert.equal(result.saved, true);
    assert.equal(result.revision, 1);
    assert.equal((await ref(uid, item.current).get()).exists, true);
    assert.equal((await ref(uid, item.receipt).get()).exists, true);
    const accepted = await allUserDocuments(uid);
    const replay = await item.invoke(uid);
    assert.equal(replay.replayed, true);
    assert.deepEqual(await allUserDocuments(uid), accepted, 'Exact replay cannot create evidence or reward');
    for (const p of ['personalized_reports/first', 'personality_reports/daily_2026-10-20', 'report_pointers/personality_daily']) {
      assert.deepEqual((await allUserDocuments(uid))[`users/${uid}/${p}`], before[`users/${uid}/${p}`]);
    }
  });
}

test('AI count/cost exhaustion does not end the still-active 21-day record permission', async () => {
  clock = new Date(END.getTime() - 1);
  for (const [kind, item] of Object.entries(cases)) {
    const uid = `synthetic-ai-exhausted-${kind}`;
    await seed(uid, {aiUsed: 20});
    assert.deepEqual(await access.getFeatureAccess(uid, clock), {allowed: true, source: 'initial_trial'});
    assert.equal((await item.invoke(uid)).saved, true);
    assert.equal((await ref(uid, 'feature_access/initial_trial_v2').get()).get('aiRequestUsed'), 20);
  }
});

test('accepted request replay after expiry remains read-only while a distinct new mutation is denied', async () => {
  for (const [kind, item] of Object.entries(cases)) {
    const uid = `synthetic-expired-replay-${kind}`;
    clock = new Date(END.getTime() - 1);
    await seed(uid);
    await item.invoke(uid);
    const before = await allUserDocuments(uid);
    clock = new Date(END.getTime() + 1);
    assert.equal((await item.invoke(uid)).replayed, true);
    await assert.rejects(item.invoke(uid, {expectedRevision: 1, mutationId: 'synthetic-trial-mutation-0002'}), e => e.code === 'permission-denied');
    assert.deepEqual(await allUserDocuments(uid), before);
  }
});

test('expired owner retains saved report/history and read marker access; direct write and another owner stay denied', async () => {
  const uid = 'synthetic-expired-read';
  await seed(uid);
  // Rules use the emulator server request time, so an explicitly past expiry
  // is used here; exact boundary timing was tested in the server handlers above.
  await ref(uid, 'feature_access/initial_trial_v2').update({endsAt: admin.firestore.Timestamp.fromDate(new Date('2000-01-01T00:00:00Z'))});
  const client = rules.authenticatedContext(uid).firestore();
  for (const p of ['personalized_reports/first', 'personality_reports/daily_2026-10-20', 'report_pointers/personality_daily']) {
    await assertSucceeds(getDoc(doc(client, `users/${uid}/${p}`)));
  }
  await assertSucceeds(getDocs(collection(client, `users/${uid}/personality_reports`)));
  await assertSucceeds(setDoc(doc(client, `users/${uid}/report_view_states/daily_2026-10-20`), {reportId: 'daily_2026-10-20', viewedAt: serverTimestamp()}));
  for (const c of ['weight_records', 'distance_records', 'daily_checkins', 'daily_care_actions']) {
    await assertFails(setDoc(doc(client, `users/${uid}/${c}/${DAY}`), {dayKey: DAY, condition: 'normal'}));
  }
  await assertFails(getDoc(doc(rules.authenticatedContext('synthetic-other').firestore(), `users/${uid}/personality_reports/daily_2026-10-20`)));
});
