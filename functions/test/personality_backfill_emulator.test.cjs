'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const { createRequire } = require('node:module');
const { before, after, test } = require('node:test');

// No ADC or production fallback. This suite owns only its dedicated demo server.
const HOST = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(HOST ?? '', /^127\.0\.0\.1:\d+$/);
assert.notEqual(Number(HOST.split(':')[1]), 8080);
const PROJECT_ID = 'demo-hamcare-personality-backfill';
const dependencyRequire = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE
  ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dependencyRequire('typescript');
const admin = dependencyRequire('firebase-admin');
const sourceRoot = path.resolve(__dirname, '../src/health');
const DAY = '2026-10-08';
const NOW = new Date('2026-10-08T02:00:00Z');
const DISTANCE = 1000 * Math.PI * 20 / 100;
const BODY_DAYS = ['2026-09-22', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06'];
const ACTIVITY_DAYS = ['2026-09-23', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06', '2026-10-07'];
let app;
let db;
let prepare;
let seedReferences;
let backfillScript;

function loadTypeScript(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = { exports: {} };
  cache.set(file, mod);
  const compiled = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    fileName: file,
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true },
  }).outputText;
  const localRequire = name => name.startsWith('.')
    ? loadTypeScript(path.resolve(path.dirname(file), `${name}.ts`), cache) : dependencyRequire(name);
  vm.runInThisContext(`(function(exports, require, module) {${compiled}\n})`, { filename: file })(mod.exports, localRequire, mod);
  return mod.exports;
}

function loadScript(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = { exports: {} };
  cache.set(file, mod);
  const localRequire = name => name.startsWith('.')
    ? loadScript(path.resolve(path.dirname(file), name), cache) : dependencyRequire(name);
  const source = fs.readFileSync(file, 'utf8').replace(/^#![^\n]*\n/, '');
  vm.runInThisContext(`(function(exports, require, module, __filename, __dirname) {${source}\n})`, { filename: file })(mod.exports, localRequire, mod, file, path.dirname(file));
  return mod.exports;
}

function canonical(value) {
  if (value && typeof value.toDate === 'function' && Number.isInteger(value.seconds)) {
    return { timestamp: `${value.seconds}.${String(value.nanoseconds).padStart(9, '0')}` };
  }
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  return value;
}
const hash = value => crypto.createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
const user = uid => db.collection('users').doc(uid);
const silverRef = uid => user(uid).collection('daily_health_features').doc(DAY);
const firstRef = uid => user(uid).collection('personalized_reports').doc('first');
const pointerRef = uid => user(uid).collection('report_pointers').doc('personality');
const goldRef = (uid, id) => user(uid).collection('personality_reports').doc(id);
const eventRef = (uid, id) => user(uid).collection('analysis_events').doc(`personality_report_${id}`);
const run = (uid, options = {}) => prepare({ db, uid, evaluationDateKey: DAY, now: NOW, ...options });
const timestamp = day => admin.firestore.Timestamp.fromDate(new Date(`${day}T00:00:00Z`));

function auditWrites() {
  const writes = [];
  const store = new Proxy(db, {
    get(target, key) {
      if (key === 'runTransaction') return action => target.runTransaction(tx => action(new Proxy(tx, {
        get(transaction, method) {
          const value = Reflect.get(transaction, method);
          if (['create', 'set', 'update', 'delete'].includes(method)) {
            return (...args) => { writes.push({ method, path: args[0].path }); return value.apply(transaction, args); };
          }
          return typeof value === 'function' ? value.bind(transaction) : value;
        },
      })));
      const value = Reflect.get(target, key);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  return { db: store, writes };
}

async function snapshot(ref) {
  const doc = await ref.get();
  return { hash: hash(doc.data()), updateTime: doc.updateTime };
}
async function assertUnchanged(ref, before) {
  const after = await snapshot(ref);
  assert.equal(after.hash, before.hash, `${ref.path} changed data`);
  assert.ok(after.updateTime.isEqual(before.updateTime), `${ref.path} received a write`);
}

async function seedBronze(uid, { bodyDays = BODY_DAYS, activityDays = [] } = {}) {
  const batch = db.batch();
  for (const dayKey of bodyDays) batch.set(user(uid).collection('weight_records').doc(dayKey), {
    dayKey, weightGrams: 100, date: timestamp(dayKey), source: 'manual', createdAt: timestamp(dayKey), updatedAt: timestamp(dayKey),
  });
  for (const dayKey of activityDays) batch.set(user(uid).collection('distance_records').doc(dayKey), {
    dayKey, distance: DISTANCE, rotations: 1000, wheelDiameterCm: 20, date: timestamp(dayKey), source: 'manual', createdAt: timestamp(dayKey), updatedAt: timestamp(dayKey),
  });
  batch.set(user(uid).collection('pet_profiles').doc('main_pet'), {
    species: 'シリアン', birthday: timestamp('2026-01-01'), name: 'Synthetic private pet name',
  });
  batch.set(user(uid).collection('personalized_reports').doc('first'), {
    readyMetrics: ['body'], analysisRevision: 1,
    generation: { status: 'generated', generatedAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-07T02:52:29.627Z')) },
    firstGeneratedAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-07T02:52:28.499Z')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-07T02:52:30.777Z')),
    metricStates: [{ metric: 'body', status: 'ready' }, { metric: 'activity', status: 'learning' }],
  });
  batch.set(user(uid).collection('feature_access').doc('initial_trial_v2'), {
    trialId: `trial-${uid}`, status: 'active', policyVersion: 'initial_trial_v2', testOnly: true,
    endsAt: timestamp('2026-10-29'), aiRequestUsed: 1, aiCostMicrosUsed: 50000,
  });
  batch.set(user(uid).collection('analysis_readiness').doc('body'), { currentStatus: 'ready', firstReadyAt: timestamp('2026-10-07') });
  batch.set(user(uid).collection('analysis_readiness').doc('activity'), { currentStatus: 'learning', validRecordCount: 0 });
  batch.set(user(uid).collection('health_assessments').doc('latest'), { marker: 'Legacy health is outside backfill scope', dateKey: '2026-10-07' });
  batch.set(user(uid).collection('health_assessments_history').doc('2026-10-07'), { marker: 'Legacy history' });
  batch.set(user(uid).collection('app_state').doc('onboarding'), { firstMonitoringDataSource: 'daily_checkin', firstMonitoringDataRecordedAt: timestamp('2026-10-07') });
  batch.set(user(uid).collection('analysis_events').doc('old-first-ready'), { eventName: 'analysis_first_ready', marker: 'Existing event' });
  await batch.commit();
  assert.equal((await silverRef(uid).get()).exists, false, 'Fixture must have no current Silver');
}

async function publication(uid, reportId, expectedMetrics) {
  const report = await goldRef(uid, reportId).get();
  assert.equal(report.exists, true);
  assert.deepEqual(report.data().readyMetrics, expectedMetrics);
  assert.equal(report.data().silverDateKey, DAY);
  assert.equal(report.data().silverSchemaVersion, 5);
  const pointer = (await pointerRef(uid).get()).data();
  assert.equal(pointer.reportId, reportId);
  assert.deepEqual(pointer.readyMetrics, expectedMetrics);
  assert.equal(pointer.evaluationDateKey, DAY);
  const event = (await eventRef(uid, reportId).get()).data();
  assert.equal(event.eventName, 'personality_report_generated');
  assert.equal(event.reportId, reportId);
  assert.deepEqual(event.readyMetrics, expectedMetrics);
  assert.ok(!JSON.stringify(event).includes('Synthetic private pet name'));
  assert.equal(Object.keys(event).includes('metrics'), false);
  assert.equal((await user(uid).collection('personality_reports').get()).size, 1);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 2); // New metadata event plus protected old event.
  return report.data();
}

function saveSyntheticReport(report, kind) {
  const stable = value => {
    if (value && typeof value.toDate === 'function') return value.toDate().toISOString();
    if (Array.isArray(value)) return value.map(stable);
    if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, stable(value[key])]));
    return value;
  };
  fs.writeFileSync(`/private/tmp/hamcare-personality-backfill-${kind}.json`, `${JSON.stringify(stable(report), null, 2)}\n`, { mode: 0o600 });
}

before(async () => {
  const response = await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
  assert.ok(response.ok, 'Clear only this explicitly named local demo project');
  app = admin.initializeApp({ projectId: PROJECT_ID }, `personality-backfill-${process.pid}`);
  db = admin.firestore(app);
  db.settings({ host: HOST, ssl: false });
  prepare = loadTypeScript(path.join(sourceRoot, 'personalityBackfill.ts')).backfillPersonalityReport;
  seedReferences = loadScript(path.resolve(__dirname, '../scripts/seed_reference_cohorts.cjs'));
  backfillScript = loadScript(path.resolve(__dirname, '../scripts/personality_backfill.cjs'));
  const result = await seedReferences.seedReferenceCohorts(db, seedReferences.buildSeedPlan(), { projectId: PROJECT_ID, emulatorHost: HOST });
  assert.equal(result.created, 8);
});
after(async () => {
  if (db) await db.terminate();
  if (app) await app.delete();
});

test('missing current Silver: real Bronze produces a body-only report and preserves first hash/updateTime', async () => {
  const uid = 'bronze-body-only';
  await seedBronze(uid);
  const first = await snapshot(firstRef(uid));
  const result = await run(uid);
  assert.equal(result.silverStatus, 'created');
  assert.equal(result.status, 'created');
  assert.deepEqual(result.readyMetrics, ['body']);
  const silver = (await silverRef(uid).get()).data();
  assert.equal(silver.dateKey, DAY);
  assert.equal(silver.schemaVersion, 5);
  assert.equal(silver.triggerReason, 'personality_backfill');
  assert.equal(silver.body.personalBaseline.recordCount, 8);
  assert.equal(silver.body.personalBaseline.spanDays, 14);
  assert.equal(silver.body.personalBaseline.median, 100);
  assert.equal(silver.activity.personalBaseline.status, 'learning');
  const report = await publication(uid, 'personality_v1_body', ['body']);
  assert.equal(report.metrics.activity, undefined);
  assert.equal(report.metrics.body.baseline.median, 100);
  await assertUnchanged(firstRef(uid), first);
  saveSyntheticReport(report, 'body');
});

test('missing current Silver: 100g and 1000 rotations on a 20cm wheel produce a both report', async () => {
  const uid = 'bronze-both';
  await seedBronze(uid, { activityDays: ACTIVITY_DAYS });
  const first = await snapshot(firstRef(uid));
  const result = await run(uid);
  assert.equal(result.silverStatus, 'created');
  assert.deepEqual(result.readyMetrics, ['body', 'activity']);
  const silver = (await silverRef(uid).get()).data();
  assert.equal(silver.activity.sourceDateKey, '2026-10-07');
  assert.equal(silver.activity.rotations, 1000);
  assert.equal(silver.activity.wheelDiameterCm, 20);
  assert.equal(silver.activity.personalBaseline.recordCount, 8);
  assert.equal(silver.activity.personalBaseline.spanDays, 14);
  assert.ok(Math.abs(silver.activity.distanceMeters - 628.3185307179587) < 1e-9);
  assert.ok(Math.abs(silver.activity.personalBaseline.median - DISTANCE) < 1e-9);
  const report = await publication(uid, 'personality_v1_body_activity', ['body', 'activity']);
  assert.ok(Math.abs(report.metrics.activity.baseline.median - DISTANCE) < 1e-9);
  assert.equal(report.metrics.activity.unit, 'm');
  assert.equal(report.metrics.body.baseline.median, 100);
  await assertUnchanged(firstRef(uid), first);
  saveSyntheticReport(report, 'both');
});

test('exact Test B UID in demo: both readiness ready and no current Silver still publish once from real Bronze', async () => {
  // This UID is used only inside the explicitly guarded demo emulator project.
  const uid = '4sD1MUmi9OTM5SaRq66qGWW8q2p2';
  await seedBronze(uid, { activityDays: ACTIVITY_DAYS });
  await user(uid).collection('analysis_readiness').doc('activity').set({ currentStatus: 'ready', firstReadyAt: timestamp('2026-10-08'), validRecordCount: 8, observationSpanDays: 14 });
  assert.equal((await user(uid).collection('analysis_readiness').doc('body').get()).data().currentStatus, 'ready');
  assert.equal((await user(uid).collection('analysis_readiness').doc('activity').get()).data().currentStatus, 'ready');
  assert.equal((await silverRef(uid).get()).exists, false);
  const first = await snapshot(firstRef(uid));
  const readinessRefs = ['body', 'activity'].map(metric => user(uid).collection('analysis_readiness').doc(metric));
  const readinessBefore = await Promise.all(readinessRefs.map(snapshot));
  const result = await run(uid);
  assert.equal(result.silverStatus, 'created');
  assert.equal(result.status, 'created');
  assert.deepEqual(result.readyMetrics, ['body', 'activity']);
  const reportId = 'personality_v1_body_activity';
  const report = await publication(uid, reportId, ['body', 'activity']);
  assert.equal(report.metrics.body.baseline.median, 100);
  assert.ok(Math.abs(report.metrics.activity.baseline.median - 628.3185307179587) < 1e-9);
  assert.equal(report.metrics.activity.latestValue, DISTANCE);
  const publicationRefs = [silverRef(uid), goldRef(uid, reportId), pointerRef(uid), eventRef(uid, reportId)];
  const publicationBefore = await Promise.all(publicationRefs.map(snapshot));
  const audited = auditWrites();
  const retry = await run(uid, { db: audited.db });
  assert.equal(retry.status, 'unchanged');
  assert.deepEqual(audited.writes, []);
  for (let i = 0; i < publicationRefs.length; i++) await assertUnchanged(publicationRefs[i], publicationBefore[i]);
  for (let i = 0; i < readinessRefs.length; i++) await assertUnchanged(readinessRefs[i], readinessBefore[i]);
  await assertUnchanged(firstRef(uid), first);
  assert.equal((await firstRef(uid).get()).data().analysisRevision, 1);
  assert.deepEqual((await firstRef(uid).get()).data().readyMetrics, ['body']);
  saveSyntheticReport(report, 'both');
});

test('10 concurrent missing-Silver backfills publish one Silver, report, pointer and metadata event', async () => {
  const uid = 'bronze-concurrent';
  await seedBronze(uid, { activityDays: ACTIVITY_DAYS });
  const first = await snapshot(firstRef(uid));
  const results = await Promise.all(Array.from({ length: 10 }, () => run(uid)));
  assert.equal(results.filter(result => result.silverStatus === 'created').length, 1);
  assert.equal(results.filter(result => result.status === 'created').length, 1);
  assert.ok(results.every(result => ['created', 'unchanged'].includes(result.status)));
  assert.ok(results.every(result => ['created', 'existing'].includes(result.silverStatus)));
  assert.equal((await user(uid).collection('daily_health_features').get()).size, 1);
  await publication(uid, 'personality_v1_body_activity', ['body', 'activity']);
  await assertUnchanged(firstRef(uid), first);
});

test('retry leaves Silver/report/event/pointer and first canonical hashes and updateTimes unchanged', async () => {
  const uid = 'bronze-retry';
  await seedBronze(uid, { activityDays: ACTIVITY_DAYS });
  const first = await snapshot(firstRef(uid));
  await run(uid);
  const refs = [silverRef(uid), goldRef(uid, 'personality_v1_body_activity'), eventRef(uid, 'personality_v1_body_activity'), pointerRef(uid)];
  const before = await Promise.all(refs.map(snapshot));
  const audited = auditWrites();
  const result = await run(uid, { db: audited.db });
  assert.equal(result.silverStatus, 'existing');
  assert.equal(result.status, 'unchanged');
  assert.deepEqual(audited.writes, []);
  for (let i = 0; i < refs.length; i++) await assertUnchanged(refs[i], before[i]);
  await assertUnchanged(firstRef(uid), first);
  await publication(uid, 'personality_v1_body_activity', ['body', 'activity']);
});

test('default script dry-run computes fresh body/both previews without any Firestore write', async () => {
  for (const both of [false, true]) {
    const uid = both ? 'bronze-dry-both' : 'bronze-dry-body';
    await seedBronze(uid, { activityDays: both ? ACTIVITY_DAYS : [] });
    const first = await snapshot(firstRef(uid));
    const audited = auditWrites();
    const results = await backfillScript.backfillUsers({ db: audited.db, target: { projectId: PROJECT_ID, emulatorHost: HOST }, uids: [uid, uid], evaluationDateKey: DAY, now: NOW, sync: prepare });
    assert.equal(results.length, 1);
    assert.equal(results[0].silverStatus, 'would_create');
    assert.equal(results[0].status, 'would_create');
    assert.deepEqual(results[0].readyMetrics, both ? ['body', 'activity'] : ['body']);
    assert.deepEqual(audited.writes, []);
    assert.equal((await silverRef(uid).get()).exists, false);
    assert.equal((await user(uid).collection('personality_reports').get()).size, 0);
    assert.equal((await pointerRef(uid).get()).exists, false);
    assert.equal((await user(uid).collection('analysis_events').get()).size, 1);
    await assertUnchanged(firstRef(uid), first);
  }
});

test('historical ready Silver cannot publish when freshly rebuilt current Bronze is learning', async () => {
  const uid = 'historical-ready-fresh-learning';
  await seedBronze(uid, { bodyDays: ['2026-10-05', '2026-10-06'], activityDays: ['2026-10-06', '2026-10-07'] });
  const historical = user(uid).collection('daily_health_features').doc('2026-10-07');
  const ready = { status: 'ready', recordCount: 8, requiredRecordCount: 7, spanDays: 14, requiredSpanDays: 14, median: 100, firstDateKey: '2026-09-22', lastDateKey: '2026-10-05' };
  await historical.set({ dateKey: '2026-10-07', schemaVersion: 5, body: { personalBaseline: ready }, activity: { personalBaseline: { ...ready, median: DISTANCE } } });
  const first = await snapshot(firstRef(uid));
  const old = await snapshot(historical);
  const result = await run(uid);
  assert.equal(result.silverStatus, 'created');
  assert.equal(result.status, 'learning');
  const silver = (await silverRef(uid).get()).data();
  assert.equal(silver.body.personalBaseline.status, 'learning');
  assert.equal(silver.activity.personalBaseline.status, 'learning');
  assert.equal((await user(uid).collection('personality_reports').get()).size, 0);
  assert.equal((await pointerRef(uid).get()).exists, false);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 1);
  await assertUnchanged(historical, old);
  await assertUnchanged(firstRef(uid), first);
});

test('existing current-day Silver wins over changed Bronze and is never recalculated or overwritten', async () => {
  const uid = 'committed-silver-wins';
  await seedBronze(uid, { bodyDays: ['2026-10-05', '2026-10-06'] });
  const baseline = { status: 'learning', recordCount: 1, requiredRecordCount: 7, spanDays: 1, requiredSpanDays: 14, median: 100, firstDateKey: '2026-10-05', lastDateKey: '2026-10-05' };
  await silverRef(uid).set({ dateKey: DAY, schemaVersion: 5, body: { personalBaseline: baseline }, activity: { personalBaseline: baseline }, generatedAt: timestamp(DAY) });
  const before = await snapshot(silverRef(uid));
  const batch = db.batch();
  for (const dayKey of BODY_DAYS) batch.set(user(uid).collection('weight_records').doc(dayKey), { dayKey, weightGrams: 100, date: timestamp(dayKey) });
  await batch.commit();
  const audited = auditWrites();
  const result = await run(uid, { db: audited.db });
  assert.equal(result.silverStatus, 'existing');
  assert.equal(result.status, 'learning');
  assert.deepEqual(audited.writes, []);
  await assertUnchanged(silverRef(uid), before);
});

test('backfill writes only new Silver/personality report/pointer/metadata event; all legacy resources stay frozen', async () => {
  const uid = 'backfill-scope';
  await seedBronze(uid, { activityDays: ACTIVITY_DAYS });
  const budget = db.collection('system').doc('ai_validation_budget_prelaunch_202610');
  await budget.set({ requestCount: 5, reservedCostMicros: 250000 });
  const collections = ['weight_records', 'distance_records', 'pet_profiles', 'personalized_reports', 'feature_access', 'analysis_readiness', 'health_assessments', 'health_assessments_history', 'app_state', 'analysis_events'];
  const protectedRefs = [budget];
  for (const name of collections) protectedRefs.push(...(await user(uid).collection(name).get()).docs.map(doc => doc.ref));
  const before = await Promise.all(protectedRefs.map(snapshot));
  const audited = auditWrites();
  const result = await run(uid, { db: audited.db });
  assert.equal(result.status, 'created');
  const reportId = 'personality_v1_body_activity';
  assert.deepEqual([...new Set(audited.writes.map(write => write.path))].sort(), [silverRef(uid).path, goldRef(uid, reportId).path, pointerRef(uid).path, eventRef(uid, reportId).path].sort());
  assert.deepEqual(audited.writes.map(write => write.method).sort(), ['create', 'create', 'create', 'set'].sort());
  for (let i = 0; i < protectedRefs.length; i++) await assertUnchanged(protectedRefs[i], before[i]);
  assert.equal((await user(uid).collection('billing').get()).size, 0);
  assert.equal((await user(uid).collection('notifications').get()).size, 0);
  assert.equal((await user(uid).collection('health_incidents').get()).size, 0);
});

test('historical backfill request skips without creating Silver or publishing even with ready Bronze', async () => {
  const uid = 'historical-request';
  await seedBronze(uid, { activityDays: ACTIVITY_DAYS });
  const audited = auditWrites();
  const result = await run(uid, { db: audited.db, evaluationDateKey: '2026-10-07' });
  assert.deepEqual(result, { status: 'historical_skipped', silverStatus: 'historical_skipped' });
  assert.deepEqual(audited.writes, []);
  assert.equal((await user(uid).collection('daily_health_features').get()).size, 0);
  assert.equal((await user(uid).collection('personality_reports').get()).size, 0);
});
