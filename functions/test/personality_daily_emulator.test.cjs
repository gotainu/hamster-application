'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const {before, after, test} = require('node:test');
const HOST = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated local emulator required');
assert.notEqual(HOST, '127.0.0.1:8080');
const PROJECT = 'demo-hamcare-personality-daily';
const dep = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dep('typescript');
const admin = dep('firebase-admin');
let app, db, daily, legacy, readers, builder, triggers, schedulerOptions;
const DAY = '2026-10-10';
const MORNING = new Date('2026-10-10T00:00:00Z');
const PREVIOUS = new Date('2026-10-09T03:00:00Z');
const WEIGHTS = ['2026-09-22', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-08'];
const DISTANCE = 628.3185307179587;
function load(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = {exports: {}}; cache.set(file, mod);
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true}}).outputText;
  const req = name => name === 'firebase-functions/v2/firestore' ? {onDocumentWritten: (_options, handler) => handler}
    : name === 'firebase-admin' && file.endsWith('personalityTriggers.ts') ? {firestore: () => db}
    : name === 'firebase-functions/v2/scheduler' ? {onSchedule: (options, handler) => {schedulerOptions = options; return handler;}}
    : name.startsWith('.') ? load(path.resolve(path.dirname(file), `${name}.ts`), cache) : dep(name);
  const dateClass = file.endsWith('personalityTriggers.ts') ? class extends Date {constructor(...args) {super(...(args.length ? args : [MORNING]));}} : Date;
  vm.runInThisContext(`(function(exports, require, module, Date) {${code}\n})`, {filename: file})(mod.exports, req, mod, dateClass);
  return mod.exports;
}
const user = uid => db.collection('users').doc(uid);
const queue = uid => db.collection('personality_report_queue').doc(uid);
const stamp = key => admin.firestore.Timestamp.fromDate(new Date(`${key}T00:00:00Z`));
const report = (uid, key = DAY) => user(uid).collection('personality_reports').doc(`daily_${key}`);
const pointer = uid => user(uid).collection('report_pointers').doc('personality');
const dailyPointer = uid => user(uid).collection('report_pointers').doc('personality_daily');
const run = (uid, options = {}) => daily.publishDailyPersonalityReport({db, uid, evaluationDateKey: DAY, now: MORNING, ...options});
const enqueue = (uid, now = PREVIOUS) => daily.enqueueDailyPersonalityReport({db, uid, sourceDateKey: now < MORNING ? '2026-10-09' : DAY, now});
function canonical(x) {
  if (x && typeof x.toDate === 'function') return [x.seconds, x.nanoseconds];
  if (Array.isArray(x)) return x.map(canonical);
  if (x && typeof x === 'object') return Object.fromEntries(Object.keys(x).sort().map(k => [k, canonical(x[k])]));
  return x;
}
async function snap(ref) {const doc = await ref.get(); return {hash: crypto.createHash('sha256').update(JSON.stringify(canonical(doc.data() ?? null))).digest('hex'), time: doc.updateTime ? [doc.updateTime.seconds, doc.updateTime.nanoseconds] : null};}
async function unchanged(ref, before) {assert.deepEqual(await snap(ref), before, ref.path);}
async function seed(uid, {newDay = '2026-10-08', activity = false, existingSilver = false} = {}) {
  const batch = db.batch();
  const u = user(uid);
  for (const key of [...WEIGHTS.filter(k => k !== '2026-10-08'), newDay]) batch.set(u.collection('weight_records').doc(key), {dayKey: key, weightGrams: 100, date: stamp(key)});
  if (activity) for (const key of ['2026-09-23', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06', '2026-10-09']) batch.set(u.collection('distance_records').doc(key), {dayKey: key, distance: DISTANCE, rotations: 1000, wheelDiameterCm: 20, date: stamp(key)});
  batch.set(u.collection('pet_profiles').doc('main_pet'), {species: 'シリアン', birthday: stamp('2026-01-01'), name: 'private name', memo: 'private memo'});
  batch.set(u.collection('personalized_reports').doc('first'), {generation: {status: 'generated', generatedAt: stamp('2026-10-07')}, readyMetrics: ['body'], analysisRevision: 1});
  batch.set(u.collection('feature_access').doc('initial_trial_v2'), {status: 'active', aiRequestUsed: 1, aiCostMicrosUsed: 50000, trialId: 'initial_trial_v2', policyVersion: 'initial_trial_v2', testOnly: true});
  batch.set(u.collection('analysis_readiness').doc('body'), {currentStatus: 'ready', validRecordCount: 8});
  batch.set(u.collection('personality_reports').doc('personality_v1_body'), {schemaVersion: 1, reportId: 'personality_v1_body', petId: 'main_pet', evaluationDateKey: '2026-10-08', silverDateKey: '2026-10-08', readyMetrics: ['body'], generatedAt: stamp('2026-10-08'), metrics: {body: {latestDateKey: '2026-10-07', latestValue: 100}}, preserved: true});
  batch.set(pointer(uid), {reportId: 'personality_v1_body', petId: 'main_pet', evaluationDateKey: '2026-10-08', readyMetrics: ['body'], publishedReadyMetrics: ['body']});
  await batch.commit();
  await currentSilver(uid, '2026-10-09', PREVIOUS);
  if (existingSilver) await currentSilver(uid, DAY, MORNING);
}
async function currentSilver(uid, day, now) {
  const source = await readers.fetchHealthSourceData({db, uid, dateKey: day});
  const features = builder.buildDailyHealthFeatures({dateKey: day, source, generatedAt: now}).features;
  await user(uid).collection('daily_health_features').doc(day).set({...features, updatedAt: admin.firestore.Timestamp.fromDate(now)});
}
before(async () => {
  const cleared = await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, {method: 'DELETE'});
  assert.ok(cleared.ok);
  app = admin.initializeApp({projectId: PROJECT}, `personality-daily-${process.pid}`);
  db = admin.firestore(app); db.settings({host: HOST, ssl: false});
  const cache = new Map(); const root = path.resolve(__dirname, '../src/health');
  daily = load(path.join(root, 'personalityDaily.ts'), cache);
  legacy = load(path.join(root, 'personalityReport.ts'), cache);
  readers = load(path.join(root, 'firestoreReaders.ts'), cache);
  builder = load(path.join(root, 'dailyHealthFeatures.ts'), cache);
  triggers = load(path.join(root, 'personalityTriggers.ts'), cache);
});
after(async () => {if (db) await db.terminate(); if (app) await app.delete();});

test('schedule uses JST 09:00 and bounded queue-only processing', () => {
  assert.equal(schedulerOptions.schedule, '0 9 * * *');
  assert.equal(schedulerOptions.timeZone, 'Asia/Tokyo');
  assert.equal(daily.PERSONALITY_DAILY_BATCH_LIMIT, 100);
  assert.equal(daily.jstReportMorning(DAY).toISOString(), '2026-10-10T00:00:00.000Z');
});
test('new valid observation queues one next-morning daily snapshot with compatible metrics', async () => {
  const uid = 'daily-new'; await seed(uid); const before = await snap(user(uid).collection('personalized_reports').doc('first'));
  const q = await enqueue(uid); assert.equal(q.status, 'queued'); assert.equal(q.dueDateKey, DAY);
  const result = await run(uid); assert.equal(result.status, 'created'); assert.equal(result.silverStatus, 'created');
  const value = (await report(uid).get()).data();
  assert.equal(value.reportKind, 'daily'); assert.equal(value.reportId, 'daily_2026-10-10');
  assert.equal(value.cutoffDateKey, '2026-10-09'); assert.equal(value.analysisSpecVersion, 'personality_v1');
  assert.equal(value.metrics.body.baseline.median, 100); assert.equal(value.latestValidDates.body, '2026-10-08');
  assert.match(value.inputFingerprint, /^[a-f0-9]{64}$/); assert.equal(value.featureSnapshotSource, 'fresh_bronze_cutoff_rebuild');
  assert.ok(!JSON.stringify(value).includes('private')); assert.equal((await queue(uid).get()).exists, false);
  await unchanged(user(uid).collection('personalized_reports').doc('first'), before);
});
test('no new record day does not queue or publish', async () => {
  const uid = 'daily-none'; await seed(uid, {newDay: '2026-10-07'});
  assert.equal((await enqueue(uid)).status, 'unchanged'); assert.equal((await run(uid)).status, 'not_queued');
  assert.equal((await report(uid).get()).exists, false);
});
test('same-date numeric update and historical backfill do not create another request', async () => {
  const uid = 'daily-old-input'; await seed(uid, {newDay: '2026-10-07'});
  await user(uid).collection('weight_records').doc('2026-10-07').update({weightGrams: 101});
  await user(uid).collection('weight_records').doc('2026-09-21').set({dayKey: '2026-09-21', weightGrams: 100});
  await currentSilver(uid, '2026-10-09', PREVIOUS);
  assert.equal((await enqueue(uid)).status, 'unchanged');
  assert.equal((await daily.enqueueDailyPersonalityReport({db, uid, sourceDateKey: '2026-09-21', now: PREVIOUS})).status, 'historical_skipped');
  assert.equal((await queue(uid).get()).exists, false);
});
test('duplicate Silver triggers preserve the same queue/updateTime', async () => {
  const uid = 'daily-queue-dedup'; await seed(uid); await enqueue(uid); const before = await snap(queue(uid));
  await Promise.all(Array.from({length: 8}, () => enqueue(uid)));
  await unchanged(queue(uid), before);
});
test('parallel publishers create exactly one report/event and a consistent pointer', async () => {
  const uid = 'daily-concurrent'; await seed(uid); await enqueue(uid);
  const results = await Promise.all(Array.from({length: 8}, () => run(uid)));
  assert.equal(results.filter(x => x.status === 'created').length, 1);
  assert.equal((await user(uid).collection('personality_reports').get()).size, 2);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 1);
  assert.equal((await dailyPointer(uid).get()).data().reportId, 'daily_2026-10-10');
  assert.equal((await pointer(uid).get()).data().reportId, 'personality_v1_body');
});
test('same evaluation day never updates an existing daily snapshot even if new inputs arrive', async () => {
  const uid = 'daily-one-per-day'; await seed(uid); await enqueue(uid); await run(uid); const old = await snap(report(uid));
  await user(uid).collection('weight_records').doc('2026-10-09').set({dayKey: '2026-10-09', weightGrams: 100});
  await currentSilver(uid, DAY, MORNING); await enqueue(uid, new Date('2026-10-10T00:30:00Z'));
  const q = (await queue(uid).get()).data(); assert.equal(q.dueDateKey, '2026-10-11');
  assert.equal((await run(uid, {now: new Date('2026-10-10T03:00:00Z')})).status, 'not_queued');
  await unchanged(report(uid), old);
});
test('next-day new observation with identical values publishes another immutable report', async () => {
  const uid = 'daily-next'; await seed(uid); await enqueue(uid); await run(uid); const old = await snap(report(uid));
  await user(uid).collection('weight_records').doc('2026-10-10').set({dayKey: '2026-10-10', weightGrams: 100});
  await currentSilver(uid, DAY, MORNING); await enqueue(uid, new Date('2026-10-10T03:00:00Z'));
  const next = await run(uid, {evaluationDateKey: '2026-10-11', now: new Date('2026-10-11T00:00:00Z')});
  assert.equal(next.status, 'created'); assert.equal(next.reportId, 'daily_2026-10-11');
  assert.equal((await report(uid, '2026-10-11').get()).data().metrics.body.baseline.median, 100);
  await unchanged(report(uid), old);
});
test('JST midnight and 08:59 do not publish; 09:00 releases the queue', async () => {
  const uid = 'daily-jst'; await seed(uid); await enqueue(uid);
  for (const instant of ['2026-10-09T15:00:00Z', '2026-10-09T23:59:59Z']) assert.equal((await run(uid, {now: new Date(instant)})).status, 'not_due');
  assert.equal((await run(uid)).status, 'created');
});
test('today measurement is excluded by previous-day cutoff without rewriting current Silver', async () => {
  const uid = 'daily-cutoff'; await seed(uid);
  await user(uid).collection('weight_records').doc(DAY).set({dayKey: DAY, weightGrams: 200});
  await currentSilver(uid, DAY, MORNING); const silver = user(uid).collection('daily_health_features').doc(DAY); const before = await snap(silver);
  await enqueue(uid); await run(uid);
  const value = (await report(uid).get()).data(); assert.equal(value.metrics.body.latestValue, 100); assert.equal(value.metrics.body.latestDateKey, '2026-10-08');
  assert.equal((await silver.get()).data().body.latestWeightGrams, 200); await unchanged(silver, before);
});
test('missing/stale Silver adopts fresh valid Bronze without changing existing Silver statistics', async () => {
  const uid = 'daily-stale'; await seed(uid, {existingSilver: true}); await enqueue(uid);
  const silver = user(uid).collection('daily_health_features').doc(DAY); const before = await snap(silver);
  await user(uid).collection('weight_records').doc('2026-10-09').set({dayKey: '2026-10-09', weightGrams: 101});
  assert.equal((await run(uid)).status, 'created');
  assert.equal((await report(uid).get()).data().metrics.body.latestValue, 101);
  await unchanged(silver, before);
});
test('body+activity snapshot follows valid data without population ranking', async () => {
  const uid = 'daily-both'; await seed(uid, {activity: true}); await enqueue(uid); await run(uid);
  const value = (await report(uid).get()).data(); assert.deepEqual(value.readyMetrics, ['body', 'activity']);
  assert.equal(value.metrics.activity.latestValue, DISTANCE); assert.equal(value.metrics.activity.baseline.median, DISTANCE);
  assert.equal(value.metrics.activity.populationComparison, null);
});
test('missing previous-day activity preserves latest valid activity in the Gold snapshot', async () => {
  const uid = 'daily-lag-gap'; await seed(uid, {activity: true});
  await user(uid).collection('distance_records').doc('2026-10-09').delete();
  await user(uid).collection('distance_records').doc('2026-10-08').set({dayKey: '2026-10-08', distance: DISTANCE, rotations: 1000, wheelDiameterCm: 20});
  await currentSilver(uid, '2026-10-09', PREVIOUS); await enqueue(uid); await run(uid);
  const value = (await report(uid).get()).data(); assert.equal(value.metrics.activity.latestDateKey, '2026-10-08'); assert.equal(value.metrics.activity.latestValue, DISTANCE);
});
test('daily retry/dry-run and legacy backfill cannot mutate existing first or v1 reports', async () => {
  const uid = 'daily-protection'; await seed(uid, {existingSilver: true}); await enqueue(uid);
  const refs = ['personalized_reports/first', 'personality_reports/personality_v1_body', 'analysis_readiness/body', 'feature_access/initial_trial_v2', 'report_pointers/personality', `daily_health_features/${DAY}`].map(key => db.doc(`users/${uid}/${key}`));
  const before = await Promise.all(refs.map(snap)); const queued = await snap(queue(uid));
  assert.equal((await run(uid, {dryRun: true})).status, 'would_create'); assert.equal((await report(uid).get()).exists, false); await unchanged(queue(uid), queued);
  await run(uid); const published = await snap(report(uid));
  assert.equal((await run(uid)).status, 'not_queued');
  const old = await legacy.syncPersonalityReport({db, uid, evaluationDateKey: DAY, now: MORNING});
  assert.equal(old.status, 'unchanged'); assert.equal((await pointer(uid).get()).data().reportId, 'personality_v1_body');
  assert.equal((await dailyPointer(uid).get()).data().reportId, `daily_${DAY}`);
  await unchanged(report(uid), published); for (let i = 0; i < refs.length; i++) await unchanged(refs[i], before[i]);
  const event = (await user(uid).collection('analysis_events').get()).docs[0].data(); assert.equal(event.reportId, `daily_${DAY}`); assert.equal(event.median, undefined); assert.equal(event.memo, undefined);
});
test('historical publisher requests and delayed evaluation do not write any document', async () => {
  const uid = 'daily-history'; await seed(uid); await enqueue(uid); const before = await snap(queue(uid));
  assert.equal((await run(uid, {evaluationDateKey: '2026-10-09'})).status, 'historical_skipped'); await unchanged(queue(uid), before);
  await pointer(uid).update({evaluationDateKey: '2026-10-11'});
  assert.equal((await run(uid)).status, 'stale_evaluation'); assert.equal((await report(uid).get()).exists, false);
});
test('scheduler only scans queued due users and respects bounded sequential batch size', async () => {
  for (const uid of ['bounded-a', 'bounded-b', 'bounded-c']) {await seed(uid); await enqueue(uid);}
  // Real SDK query applies the limit; publication remains serial inside the loop.
  const result = await daily.processPersonalityDailyQueue({db, now: MORNING, limit: 2});
  assert.equal(result.processed, 2); assert.equal(result.results.length, 2);
  assert.ok((await db.collection('personality_report_queue').get()).size >= 1);
});


test('activity-only user creates daily Gold from new activity without body data', async () => {
  const uid = 'daily-activity-only'; await seed(uid, {activity: true});
  for (const doc of (await user(uid).collection('weight_records').get()).docs) await doc.ref.delete();
  await currentSilver(uid, '2026-10-09', PREVIOUS); await enqueue(uid); await run(uid);
  const value = (await report(uid).get()).data();
  assert.deepEqual(value.readyMetrics, ['activity']); assert.equal(value.reportType, 'activity_only');
  assert.equal(value.metrics.body, undefined); assert.equal(value.metrics.activity.baseline.median, DISTANCE);
});

test('legacy generated snapshot is the no-new-data watermark even after explicit queue replay', async () => {
  const uid = 'daily-v1-watermark'; await seed(uid, {newDay: '2026-10-07'});
  await queue(uid).set({uid, dueDateKey: DAY, dueAt: stamp(DAY), latestValidDates: {body: '2026-10-07'}});
  assert.equal((await run(uid)).status, 'no_new_data');
  assert.equal((await report(uid).get()).exists, false); assert.equal((await queue(uid).get()).exists, false);
});

test('queue advanced while fresh inputs are being prepared retains next-day observations', async () => {
  const uid = 'daily-racing-next-day'; await seed(uid, {existingSilver: true}); await enqueue(uid);
  let raced = false;
  const racing = new Proxy(db, {get(target, key) {
    if (key === 'runTransaction') return async action => {
      if (!raced) {
        raced = true;
        await user(uid).collection('weight_records').doc(DAY).set({dayKey: DAY, weightGrams: 100});
        await currentSilver(uid, DAY, MORNING);
        await enqueue(uid, new Date('2026-10-10T00:01:00Z'));
      }
      return target.runTransaction(action);
    };
    const value = Reflect.get(target, key); return typeof value === 'function' ? value.bind(target) : value;
  }});
  assert.equal((await run(uid, {db: racing})).status, 'created');
  assert.equal((await report(uid).get()).data().metrics.body.latestDateKey, '2026-10-08');
  assert.equal((await queue(uid).get()).data().dueDateKey, '2026-10-11');
  assert.equal((await queue(uid).get()).data().latestValidDates.body, DAY);
  assert.equal((await run(uid, {now: new Date('2026-10-11T00:00:00Z'), evaluationDateKey: '2026-10-11'})).status, 'created');
  assert.equal((await report(uid, '2026-10-11').get()).data().metrics.body.latestDateKey, DAY);
});

test('one failed queued user is deferred and does not stop the next user', async () => {
  for (const uid of ['aaa-broken-user', 'aab-healthy-user']) {await seed(uid); await enqueue(uid);}
  const guarded = new Proxy(db, {get(target, key) {
    if (key === 'runTransaction') return action => target.runTransaction(tx => action(new Proxy(tx, {get(transaction, method) {
      if (method === 'get') return ref => {if (ref.path.startsWith('users/aaa-broken-user/')) throw new Error('fixture user failure'); return transaction.get(ref);};
      const value = Reflect.get(transaction, method); return typeof value === 'function' ? value.bind(transaction) : value;
    }})));
    const value = Reflect.get(target, key); return typeof value === 'function' ? value.bind(target) : value;
  }});
  const result = await daily.processPersonalityDailyQueue({db: guarded, now: MORNING, limit: 2});
  assert.equal(result.processed, 2); assert.equal(result.failed, 1);
  assert.deepEqual(result.results.map(value => value.status), ['failed', 'created']);
  const retry = (await queue('aaa-broken-user').get()).data();
  assert.equal(retry.dueDateKey, '2026-10-11'); assert.equal(retry.attemptCount, 1); assert.equal(retry.lastAttemptStatus, 'failed');
  assert.ok(!JSON.stringify(retry).includes('fixture user failure'));
  assert.equal((await report('aab-healthy-user').get()).exists, true);
});

test('today distance only/no current Silver queues tomorrow without health or Silver writes', async () => {
  const uid = 'distance-queue-only'; await seed(uid, {activity: true});
  for (const doc of (await user(uid).collection('weight_records').get()).docs) await doc.ref.delete();
  await user(uid).collection('daily_health_features').doc('2026-10-09').delete();
  await user(uid).collection('distance_records').doc('2026-10-09').delete();
  const legacyRef = user(uid).collection('personality_reports').doc('personality_v1_body');
  const firstRef = user(uid).collection('personalized_reports').doc('first');
  const firstBefore = await snap(firstRef); const legacyBefore = await snap(legacyRef);
  await user(uid).collection('distance_records').doc('2026-10-09').set({dayKey: '2026-10-09', distance: DISTANCE, rotations: 1000, wheelDiameterCm: 20});
  const result = await daily.enqueueDailyPersonalityRecord({db, uid, recordDateKey: '2026-10-09', now: PREVIOUS});
  assert.equal(result.status, 'queued'); assert.equal(result.dueDateKey, DAY);
  assert.equal((await user(uid).collection('daily_health_features').get()).size, 0);
  assert.equal((await user(uid).collection('personality_reports').get()).size, 1);
  const queuedBefore = await snap(queue(uid));
  assert.equal((await daily.enqueueDailyPersonalityRecord({db, uid, recordDateKey: '2026-10-09', now: PREVIOUS})).status, 'unchanged');
  await unchanged(queue(uid), queuedBefore);
  assert.equal((await run(uid)).status, 'created');
  const value = (await report(uid).get()).data(); assert.deepEqual(value.readyMetrics, ['activity']);
  assert.equal(value.metrics.activity.latestDateKey, '2026-10-09'); assert.equal(value.metrics.activity.latestValue, DISTANCE);
  await unchanged(firstRef, firstBefore); await unchanged(legacyRef, legacyBefore);
  assert.equal((await user(uid).collection('health_assessments').get()).size, 0);
  assert.equal((await user(uid).collection('notifications').get()).size, 0);
});


async function clearPendingQueues() {
  const docs = (await db.collection('personality_report_queue').get()).docs;
  for (let offset = 0; offset < docs.length; offset += 400) {
    const batch = db.batch(); for (const doc of docs.slice(offset, offset + 400)) batch.delete(doc.ref); await batch.commit();
  }
}

test('daily pointer stays independent while v1 publishes a newly ready metric', async () => {
  const uid = 'pointer-independent'; await seed(uid, {activity: true, existingSilver: true});
  const oldFirst = await snap(user(uid).collection('personalized_reports').doc('first'));
  const oldV1 = await snap(user(uid).collection('personality_reports').doc('personality_v1_body'));
  const oldPointer = await snap(pointer(uid));
  await enqueue(uid); assert.equal((await run(uid)).status, 'created');
  await unchanged(pointer(uid), oldPointer);
  const frozenDaily = await snap(report(uid)); const frozenDailyPointer = await snap(dailyPointer(uid));
  const upgrade = await legacy.syncPersonalityReport({db, uid, evaluationDateKey: DAY, now: MORNING});
  assert.equal(upgrade.status, 'created'); assert.equal(upgrade.reportId, 'personality_v1_body_activity');
  assert.equal((await pointer(uid).get()).data().reportId, 'personality_v1_body_activity');
  await unchanged(report(uid), frozenDaily); await unchanged(dailyPointer(uid), frozenDailyPointer);
  await unchanged(user(uid).collection('personalized_reports').doc('first'), oldFirst);
  await unchanged(user(uid).collection('personality_reports').doc('personality_v1_body'), oldV1);
});

test('daily frontier wins over legacy watermark after its first publication', async () => {
  const uid = 'pointer-daily-watermark'; await seed(uid); await enqueue(uid); await run(uid);
  const before = await snap(pointer(uid));
  await currentSilver(uid, DAY, MORNING);
  assert.equal((await enqueue(uid, MORNING)).status, 'unchanged');
  assert.equal((await queue(uid).get()).exists, false);
  await unchanged(pointer(uid), before);
  await queue(uid).set({uid, dueDateKey: DAY, dueAt: stamp(DAY), latestValidDates: {body: '2026-10-08'}});
  assert.equal((await run(uid)).status, 'existing');
  await unchanged(pointer(uid), before);
});

test('103 due users retain overflow and failures across same-day reruns, retry and next morning', async () => {
  await clearPendingQueues();
  const uids = Array.from({length: 103}, (_, index) => `overflow-${String(index).padStart(3, '0')}`);
  for (let offset = 0; offset < uids.length; offset += 8) await Promise.all(uids.slice(offset, offset + 8).map(async uid => {await seed(uid, {existingSilver: true}); await enqueue(uid);}));
  const before = await Promise.all(uids.map(uid => snap(pointer(uid))));
  const guarded = new Proxy(db, {get(target, key) {
    if (key === 'runTransaction') return action => target.runTransaction(tx => action(new Proxy(tx, {get(transaction, method) {
      if (method === 'get') return ref => {if (ref.path.startsWith(`users/${uids[0]}/`)) throw new Error('bounded fixture failure'); return transaction.get(ref);};
      const value = Reflect.get(transaction, method); return typeof value === 'function' ? value.bind(transaction) : value;
    }})));
    const value = Reflect.get(target, key); return typeof value === 'function' ? value.bind(target) : value;
  }});
  const first = await daily.processPersonalityDailyQueue({db: guarded, now: MORNING, limit: 1000});
  assert.equal(first.processed, 100); assert.equal(first.failed, 1);
  assert.equal(first.results.filter(result => result.status === 'created').length, 99);
  assert.equal((await db.collection('personality_report_queue').get()).size, 4);
  const second = await daily.processPersonalityDailyQueue({db, now: MORNING});
  assert.equal(second.processed, 3); assert.equal(second.results.filter(result => result.status === 'created').length, 3);
  assert.equal((await db.collection('personality_report_queue').get()).size, 1);
  assert.equal((await queue(uids[0]).get()).data().dueDateKey, '2026-10-11');
  assert.equal((await daily.processPersonalityDailyQueue({db, now: MORNING})).processed, 0);
  const next = await daily.processPersonalityDailyQueue({db, now: new Date('2026-10-11T00:00:00Z')});
  assert.equal(next.processed, 1); assert.equal(next.results[0].status, 'created');
  assert.equal((await daily.processPersonalityDailyQueue({db, now: new Date('2026-10-11T00:00:00Z')})).processed, 0);
  assert.equal((await db.collection('personality_report_queue').get()).size, 0);
  for (let index = 0; index < uids.length; index++) {
    const uid = uids[index];
    const docs = (await user(uid).collection('personality_reports').get()).docs;
    assert.equal(docs.filter(doc => doc.id.startsWith('daily_')).length, 1, uid);
    assert.equal((await user(uid).collection('analysis_events').get()).size, 1, uid);
    await unchanged(pointer(uid), before[index]);
  }
});

test('concurrent bounded runs and their retry do not drop or duplicate queued users', async () => {
  await clearPendingQueues();
  const uids = Array.from({length: 6}, (_, index) => `bounded-parallel-${index}`);
  for (const uid of uids) {await seed(uid, {existingSilver: true}); await enqueue(uid);}
  await Promise.all(Array.from({length: 2}, () => daily.processPersonalityDailyQueue({db, now: MORNING, limit: 5})));
  await daily.processPersonalityDailyQueue({db, now: MORNING, limit: 5});
  assert.equal((await db.collection('personality_report_queue').get()).size, 0);
  for (const uid of uids) {
    assert.equal((await user(uid).collection('personality_reports').get()).docs.filter(doc => doc.id.startsWith('daily_')).length, 1);
    assert.equal((await user(uid).collection('analysis_events').get()).size, 1);
  }
});

test('stale failing runner cannot defer or relabel a newer queue after another runner succeeds', async () => {
  await clearPendingQueues();
  const uid = 'failure-defer-race'; await seed(uid, {existingSilver: true}); await enqueue(uid);
  let newerQueue; let raced = false;
  const stale = new Proxy(db, {get(target, key) {
    if (key === 'runTransaction') return async action => {
      if (!raced) {
        raced = true; assert.equal((await run(uid)).status, 'created');
        await user(uid).collection('weight_records').doc(DAY).set({dayKey: DAY, weightGrams: 100});
        await currentSilver(uid, DAY, MORNING); await enqueue(uid, new Date('2026-10-10T00:01:00Z'));
        newerQueue = await snap(queue(uid));
        throw new Error('stale runner fixture failure');
      }
      return target.runTransaction(action);
    };
    const value = Reflect.get(target, key); return typeof value === 'function' ? value.bind(target) : value;
  }});
  const result = await daily.processPersonalityDailyQueue({db: stale, now: MORNING});
  assert.equal(result.failed, 1); await unchanged(queue(uid), newerQueue);
  assert.equal((await run(uid, {now: new Date('2026-10-11T00:00:00Z'), evaluationDateKey: '2026-10-11'})).status, 'created');
  assert.equal((await user(uid).collection('analysis_events').get()).size, 2);
});


test('actual current Silver trigger still publishes v1 for a newly ready owner', async () => {
  const uid = 'trigger-new-v1-owner'; await seed(uid, {existingSilver: true});
  await pointer(uid).delete(); await user(uid).collection('personality_reports').doc('personality_v1_body').delete();
  const before = await snap(user(uid).collection('personalized_reports').doc('first'));
  await triggers.personalityHealthFeaturesWritten({params: {uid, dateKey: DAY}, data: {after: {exists: true}}});
  assert.equal((await pointer(uid).get()).data().reportId, 'personality_v1_body');
  assert.equal((await user(uid).collection('personality_reports').doc('personality_v1_body').get()).data().reportType, 'weight_only');
  assert.equal((await dailyPointer(uid).get()).exists, false);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 1);
  const legacyBefore = await snap(pointer(uid));
  await triggers.personalityHealthFeaturesWritten({params: {uid, dateKey: DAY}, data: {after: {exists: true}}});
  await unchanged(pointer(uid), legacyBefore); await unchanged(user(uid).collection('personalized_reports').doc('first'), before);
});

test('actual current Silver trigger continues daily enqueue without changing v1 ready set', async () => {
  const uid = 'trigger-existing-daily-owner'; await seed(uid, {existingSilver: true});
  await dailyPointer(uid).set({reportId: 'daily_2026-10-09', reportKind: 'daily', petId: 'main_pet', evaluationDateKey: '2026-10-09', readyMetrics: ['body']});
  await report(uid, '2026-10-09').set({reportId: 'daily_2026-10-09', latestValidDates: {body: '2026-10-07'}, metrics: {body: {latestDateKey: '2026-10-07'}}});
  const legacyBefore = await snap(pointer(uid)); const dailyBefore = await snap(dailyPointer(uid));
  await triggers.personalityHealthFeaturesWritten({params: {uid, dateKey: DAY}, data: {after: {exists: true}}});
  assert.equal((await queue(uid).get()).data().dueDateKey, '2026-10-11');
  await unchanged(pointer(uid), legacyBefore); await unchanged(dailyPointer(uid), dailyBefore);
  const queuedBefore = await snap(queue(uid));
  await triggers.personalityHealthFeaturesWritten({params: {uid, dateKey: DAY}, data: {after: {exists: true}}});
  await unchanged(queue(uid), queuedBefore);
});
