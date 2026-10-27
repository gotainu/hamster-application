'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const {before, after, test} = require('node:test');
const HOST = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated emulator required; no production fallback');
assert.notEqual(HOST, '127.0.0.1:8080');
const PROJECT = 'demo-hamcare-weight-insights';
const dep = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dep('typescript');
const admin = dep('firebase-admin');
const DAY = '2026-10-11';
let clock = new Date('2026-10-11T02:00:00Z');
let app, db, pipeline, insights, readers, builder, daily;
const DATES = ['2026-09-22', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-10'];
const stamp = key => admin.firestore.Timestamp.fromDate(new Date(`${key}T00:00:00Z`));
const user = uid => db.collection('users').doc(uid);
const silver = uid => user(uid).collection('daily_health_features').doc(DAY);
const gold = uid => user(uid).collection('individual_insights').doc(DAY);
const first = uid => user(uid).collection('personalized_reports').doc('first');
const oldReport = uid => user(uid).collection('personality_reports').doc('personality_v1_body');
const dailyReport = uid => user(uid).collection('personality_reports').doc(`daily_${DAY}`);
function load(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = {exports: {}}; cache.set(file, mod);
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true}}).outputText;
  const req = name => name === 'firebase-functions/logger' ? {info: () => {}, error: () => {}}
    : name === './goldHealthNotification' ? {executeGoldHealthNotificationPipeline: async () => ({sentCount: 0}), executePendingResolvedHealthNotifications: async () => ({})}
    : name.startsWith('.') ? load(path.resolve(path.dirname(file), `${name}.ts`), cache) : dep(name);
  const clockDate = file.endsWith('healthPipeline.ts') ? class extends Date {constructor(...args) {super(...(args.length ? args : [clock]));}} : Date;
  vm.runInThisContext(`(function(exports, require, module, Date) {${code}\n})`, {filename: file})(mod.exports, req, mod, clockDate);
  return mod.exports;
}
function canonical(value) {
  if (value && typeof value.toDate === 'function') return [value.seconds, value.nanoseconds];
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  return value;
}
async function snap(ref) {
  const value = await ref.get();
  return {hash: crypto.createHash('sha256').update(JSON.stringify(canonical(value.data()))).digest('hex'), time: value.updateTime && [value.updateTime.seconds, value.updateTime.nanoseconds]};
}
async function unchanged(ref, before) {assert.deepEqual(await snap(ref), before, ref.path);}
async function seed(uid, {count = 9} = {}) {
  const batch = db.batch();
  for (const key of DATES.slice(0, count)) batch.set(user(uid).collection('weight_records').doc(key), {dayKey: key, weightGrams: 100, date: stamp(key)});
  batch.set(first(uid), {generation: {status: 'generated', generatedAt: stamp('2026-10-07')}, firstGeneratedAt: stamp('2026-10-07'), updatedAt: stamp('2026-10-07'), readyMetrics: ['body'], analysisRevision: 1});
  batch.set(oldReport(uid), {schemaVersion: 1, reportId: 'personality_v1_body', petId: 'main_pet', readyMetrics: ['body'], evaluationDateKey: '2026-10-08', silverDateKey: '2026-10-08', metrics: {body: {latestDateKey: '2026-10-05', latestValue: 100}}, immutable: true});
  batch.set(user(uid).collection('report_pointers').doc('personality'), {reportId: 'personality_v1_body', readyMetrics: ['body'], evaluationDateKey: '2026-10-08'});
  batch.set(user(uid).collection('pet_profiles').doc('main_pet'), {species: 'シリアン', birthday: stamp('2026-01-01'), memo: 'private text should not be copied'});
  await batch.commit();
}
const rebuild = uid => pipeline.rebuildHealthForDate({db, uid, dateKey: DAY, reason: 'manual_rebuild'});
before(async () => {
  const cleared = await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, {method: 'DELETE'});
  assert.ok(cleared.ok);
  app = admin.initializeApp({projectId: PROJECT}, `weight-insight-${process.pid}`);
  db = admin.firestore(app); db.settings({host: HOST, ssl: false});
  const cache = new Map(); const root = path.resolve(__dirname, '../src/health');
  pipeline = load(path.join(root, 'healthPipeline.ts'), cache);
  insights = load(path.join(root, 'weightInsights.ts'), cache);
  readers = load(path.join(root, 'firestoreReaders.ts'), cache);
  builder = load(path.join(root, 'dailyHealthFeatures.ts'), cache);
  daily = load(path.join(root, 'personalityDaily.ts'), cache);
});
after(async () => {if (db) await db.terminate(); if (app) await app.delete();});

test('health pipeline atomically stores dated measurement-only Insights without writing first/v1', async () => {
  const uid = 'insight-pipeline'; await seed(uid);
  const firstBefore = await snap(first(uid)); const oldBefore = await snap(oldReport(uid));
  const result = await rebuild(uid);
  const s = (await silver(uid).get()).data(); const value = (await gold(uid).get()).data();
  assert.equal(value.kind, 'current'); assert.equal(value.evaluationDateKey, DAY);
  assert.ok(value.source.silverGeneratedAt.isEqual(s.generatedAt));
  assert.equal(value.insights[0].evidence.minimumGrams, 100); assert.equal(value.insights[0].evidence.maximumGrams, 100);
  assert.equal(value.insights[0].validRecordCount, 8); assert.equal(value.insights[0].interpretationCode, 'weight_all_equal');
  assert.equal(s.body.personalBaseline.median, 100); assert.equal(s.body.personalBaseline.mad, 0);
  assert.equal(result.overallScore, (await user(uid).collection('health_assessments').doc('latest').get()).data().overall.score);
  assert.ok(!JSON.stringify(value).includes('private text'));
  await unchanged(first(uid), firstBefore); await unchanged(oldReport(uid), oldBefore);
});
test('parallel duplicate calculations and retries preserve one fixed Gold doc and updateTime', async () => {
  const uid = 'insight-retry'; await seed(uid); await rebuild(uid);
  const source = await readers.fetchHealthSourceData({db, uid, dateKey: DAY});
  const features = builder.buildDailyHealthFeatures({dateKey: DAY, source, generatedAt: clock}).features;
  const current = insights.buildCurrentInsightSet({features, generatedAt: clock});
  const before = await snap(gold(uid));
  const results = await Promise.all(Array.from({length: 8}, () => db.runTransaction(async transaction => {
    const snapshot = await transaction.get(gold(uid));
    return insights.persistCurrentInsightSet({transaction, reference: gold(uid), snapshot, current});
  })));
  assert.ok(results.every(x => x === 'unchanged')); assert.equal((await user(uid).collection('individual_insights').get()).size, 1);
  await unchanged(gold(uid), before);
});
test('late older Gold generation cannot overwrite the newer current result', async () => {
  const uid = 'insight-stale-worker'; await seed(uid); await rebuild(uid);
  const source = await readers.fetchHealthSourceData({db, uid, dateKey: DAY});
  const earlier = new Date(clock.getTime() - 60000);
  const features = builder.buildDailyHealthFeatures({dateKey: DAY, source, generatedAt: earlier}).features;
  const before = await snap(gold(uid));
  const result = await db.runTransaction(async transaction => insights.persistCurrentInsightSet({transaction, reference: gold(uid), snapshot: await transaction.get(gold(uid)), current: insights.buildCurrentInsightSet({features, generatedAt: earlier})}));
  assert.equal(result, 'stale'); await unchanged(gold(uid), before);
});
test('same-day update and deletion refresh current evidence without altering old immutable reports', async () => {
  const uid = 'insight-correction'; await seed(uid); await rebuild(uid);
  const firstBefore = await snap(first(uid)); const oldBefore = await snap(oldReport(uid));
  await user(uid).collection('weight_records').doc('2026-10-03').update({weightGrams: 104});
  clock = new Date('2026-10-11T02:01:00Z'); await rebuild(uid);
  let value = (await gold(uid).get()).data(); assert.equal(value.insights.find(x => x.kind === 'weight_observed_range').evidence.maximumGrams, 104);
  await user(uid).collection('weight_records').doc('2026-10-03').delete();
  clock = new Date('2026-10-11T02:02:00Z'); await rebuild(uid);
  value = (await gold(uid).get()).data(); assert.equal(value.insights[0].evidence.maximumGrams, 100); assert.equal(value.insights[0].validRecordCount, 7);
  await unchanged(first(uid), firstBefore); await unchanged(oldReport(uid), oldBefore);
});
test('future daily report snapshots fresh cutoff evidence, not current Gold, and never rewrites existing reports', async () => {
  const uid = 'insight-daily'; await seed(uid); await rebuild(uid);
  const firstBefore = await snap(first(uid)); const oldBefore = await snap(oldReport(uid));
  await gold(uid).set({kind: 'current', maliciousFixture: 999}, {merge: true});
  await db.collection('personality_report_queue').doc(uid).set({schemaVersion: 1, uid, dueDateKey: DAY, dueAt: stamp(DAY), latestValidDates: {body: '2026-10-10'}});
  const result = await daily.publishDailyPersonalityReport({db, uid, evaluationDateKey: DAY, now: clock});
  assert.equal(result.status, 'created');
  const value = (await dailyReport(uid).get()).data();
  assert.equal(value.insightSnapshot.kind, 'report_snapshot'); assert.equal(value.insightSnapshot.insights[0].evidence.minimumGrams, 100);
  assert.ok(!JSON.stringify(value.insightSnapshot).includes('maliciousFixture'));
  const before = await snap(dailyReport(uid));
  await user(uid).collection('weight_records').doc('2026-10-10').update({weightGrams: 103});
  await db.collection('personality_report_queue').doc(uid).set({schemaVersion: 1, uid, dueDateKey: DAY, dueAt: stamp(DAY), latestValidDates: {body: '2026-10-10'}});
  assert.equal((await daily.publishDailyPersonalityReport({db, uid, evaluationDateKey: DAY, now: clock})).status, 'existing');
  await unchanged(dailyReport(uid), before); await unchanged(first(uid), firstBefore); await unchanged(oldReport(uid), oldBefore);
});
test('learning cannot emit an observed-range discovery but two fresh real dates can emit endpoint difference', async () => {
  const uid = 'insight-learning'; await seed(uid, {count: 0});
  await user(uid).collection('weight_records').doc('2026-10-09').set({dayKey: '2026-10-09', weightGrams: 100});
  await user(uid).collection('weight_records').doc('2026-10-10').set({dayKey: '2026-10-10', weightGrams: 103});
  await rebuild(uid);
  const value = (await gold(uid).get()).data(); assert.deepEqual(value.insights.map(x => x.kind), ['weight_period_difference']);
  assert.equal(value.insights[0].evidence.differenceGrams, 3); assert.equal(value.insights[0].evidence.absoluteDifferenceGrams, 3);
  assert.equal(value.insights[0].validRecordCount, 2); assert.equal(value.insights[0].dataQuality.baselineStatus, 'learning');
});
test('historical evaluation is isolated in its dated Gold document and does not replace todays analysis', async () => {
  const uid = 'insight-historical'; await seed(uid); await rebuild(uid); const before = await snap(gold(uid));
  await pipeline.rebuildHealthForDate({db, uid, dateKey: '2026-10-05', reason: 'manual_rebuild'});
  const historical = await user(uid).collection('individual_insights').doc('2026-10-05').get();
  assert.equal(historical.data().evaluationDateKey, '2026-10-05'); await unchanged(gold(uid), before);
});
