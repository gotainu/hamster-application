'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const { createRequire } = require('node:module');
const { before, after, test } = require('node:test');

const HOST = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated loopback emulator required; production fallback prohibited');
assert.notEqual(Number(HOST.split(':')[1]), 8080, 'Never use another task\'s shared emulator');
const PROJECT_ID = 'demo-hamcare-personality-rules';
const dependencyRequire = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE
  ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dependencyRequire('typescript');
const admin = dependencyRequire('firebase-admin');
const sourceRoot = path.resolve(__dirname, '../src/health');
const DAY = '2026-10-08';
const NOW = new Date('2026-10-08T02:00:00Z');
let app;
let db;
let publish;
let getReferenceCohort;
let referenceSeed;
let backfill;

// Compile into memory only. Never read or rewrite pre-existing compiled lib.
function loadTypeScript(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = { exports: {} };
  cache.set(file, mod);
  const output = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true },
  }).outputText;
  const localRequire = name => name.startsWith('.')
    ? loadTypeScript(path.resolve(path.dirname(file), `${name}.ts`), cache)
    : dependencyRequire(name);
  vm.runInThisContext(`(function(exports, require, module) {${output}\n})`, { filename: file })(mod.exports, localRequire, mod);
  return mod.exports;
}

function loadScript(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = { exports: {} };
  cache.set(file, mod);
  const localRequire = name => name.startsWith('.')
    ? loadScript(path.resolve(path.dirname(file), name), cache) : dependencyRequire(name);
  vm.runInThisContext(`(function(exports, require, module, __filename, __dirname) {${fs.readFileSync(file, 'utf8').replace(/^#![^\n]*\n/, '')}\n})`, { filename: file })(mod.exports, localRequire, mod, file, path.dirname(file));
  return mod.exports;
}

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

function canonical(value) {
  if (value && typeof value.toDate === 'function' && Number.isInteger(value.seconds)) {
    return { timestamp: `${value.seconds}.${String(value.nanoseconds).padStart(9, '0')}` };
  }
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  }
  return value;
}
const hash = value => crypto.createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
const user = uid => db.collection('users').doc(uid);
const reportCollection = uid => user(uid).collection('personality_reports');
const pointer = uid => user(uid).collection('report_pointers').doc('personality');
const generationEvent = (uid, reportId) => user(uid).collection('analysis_events').doc(`personality_report_${reportId}`);
const run = (uid, day = DAY, now = NOW, dryRun = false) => publish({ db, uid, evaluationDateKey: day, now, dryRun });

async function assertGenerationMetadata(uid, reportId) {
  const eventDoc = await generationEvent(uid, reportId).get();
  assert.equal(eventDoc.exists, true);
  const event = eventDoc.data();
  assert.deepEqual(Object.keys(event).sort(), ['actor', 'analysisSpecVersion', 'eventId', 'eventName', 'occurredAt', 'petId', 'policyVersion', 'readyMetrics', 'reportId', 'reportRevision', 'source', 'testOnly', 'trialEndsAt', 'trialId'].sort());
  assert.equal(event.eventName, 'personality_report_generated');
  assert.equal(event.eventId, `personality_report_${reportId}`);
  assert.equal(event.reportId, reportId);
  assert.equal(event.reportRevision, 1);
  assert.equal(event.petId, 'main_pet');
  assert.equal(event.analysisSpecVersion, 'personality_v1');
  assert.equal(event.trialId, `trial-${uid}`);
  assert.equal(event.policyVersion, 'initial_trial_v2');
  assert.equal(event.testOnly, true);
  assert.ok(!JSON.stringify(event).includes('private source text'));
  assert.ok(!JSON.stringify(event).includes('private pet name'));
  // Exact metadata fields above exclude memo/name, all measurement values,
  // baselines, readiness counts, and interpretation text.
}

function baseline(ready, metric = 'body') {
  return {
    status: ready ? 'ready' : 'learning', method: 'median_mad_ewma_v1',
    median: metric === 'body' ? 100 : 628.3185, mad: 0, ewma: metric === 'body' ? 100 : 628.3185,
    ewmaAlpha: 0.3, recordCount: ready ? 8 : 2, requiredRecordCount: 7,
    spanDays: ready ? 14 : 2, requiredSpanDays: 14,
    firstDateKey: ready ? '2026-09-23' : '2026-10-05', lastDateKey: '2026-10-06',
    deviationPct: 0, robustZScore: null,
  };
}
function silver(body = true, activity = false, day = DAY) {
  return {
    dateKey: day, schemaVersion: 5, generatedAt: admin.firestore.Timestamp.fromDate(NOW),
    updatedAt: admin.firestore.Timestamp.fromDate(NOW),
    body: { personalBaseline: baseline(body), latestWeightGrams: 100, latestWeightDate: admin.firestore.Timestamp.fromDate(new Date('2026-10-06T00:00:00Z')) },
    activity: { personalBaseline: baseline(activity, 'activity'), distanceMeters: 628.3185, sourceDateKey: '2026-10-07' },
    condition: { memo: 'private source text must not appear in a report' },
  };
}
async function seed(uid, body = true, activity = false) {
  await user(uid).collection('daily_health_features').doc(DAY).set(silver(body, activity));
  await user(uid).collection('pet_profiles').doc('main_pet').set({ name: 'private pet name must not appear in an event', species: 'シリアン', birthday: admin.firestore.Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')) });
  await user(uid).collection('feature_access').doc('initial_trial_v2').set({ trialId: `trial-${uid}`, policyVersion: 'initial_trial_v2', testOnly: true, status: 'active', endsAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-29T00:00:00Z')), aiRequestUsed: 1, aiCostMicrosUsed: 50000 });
  await user(uid).collection('personalized_reports').doc('first').set({
    readyMetrics: ['body'], analysisRevision: 1,
    generation: { status: 'generated', generatedAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-07T02:52:29.627Z')) },
    firstGeneratedAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-07T02:52:28.499Z')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2026-10-07T02:52:30.777Z')),
    metricStates: [{ metric: 'body', status: 'ready' }, { metric: 'activity', status: 'learning' }],
  });
}
async function snapshot(ref) {
  const doc = await ref.get();
  return { dataHash: hash(doc.data()), updateTime: doc.updateTime };
}
async function unchanged(ref, before) {
  const after = await snapshot(ref);
  assert.equal(after.dataHash, before.dataHash);
  assert.ok(after.updateTime.isEqual(before.updateTime), `${ref.path} received a write`);
}

before(async () => {
  const cleared = await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
  assert.ok(cleared.ok, 'Only the dedicated demo emulator may be cleared');
  app = admin.initializeApp({ projectId: PROJECT_ID }, `personality-emulator-${process.pid}`);
  db = admin.firestore(app);
  db.settings({ host: HOST, ssl: false });
  const cache = new Map();
  publish = loadTypeScript(path.join(sourceRoot, 'personalityReport.ts'), cache).syncPersonalityReport;
  getReferenceCohort = loadTypeScript(path.join(sourceRoot, 'referenceCohorts.ts'), cache).getReferenceCohort;
  const scriptCache = new Map();
  referenceSeed = loadScript(path.resolve(__dirname, '../scripts/seed_reference_cohorts.cjs'), scriptCache);
  backfill = loadScript(path.resolve(__dirname, '../scripts/personality_backfill.cjs'), scriptCache);
  const seeded = await referenceSeed.seedReferenceCohorts(db, referenceSeed.buildSeedPlan(), { projectId: PROJECT_ID, emulatorHost: HOST });
  assert.equal(seeded.created, 8);
});
after(async () => {
  if (db) await db.terminate();
  if (app) await app.delete();
});

test('actual Firestore: 10 concurrent deliveries create exactly one immutable body report and a matching pointer', async () => {
  const uid = 'concurrent-body';
  await seed(uid);
  const firstRef = user(uid).collection('personalized_reports').doc('first');
  const firstBefore = await snapshot(firstRef);
  const results = await Promise.all(Array.from({ length: 10 }, () => run(uid)));
  assert.equal(results.filter(result => result.status === 'created').length, 1);
  assert.ok(results.every(result => ['created', 'unchanged'].includes(result.status)));
  const reports = await reportCollection(uid).get();
  assert.equal(reports.size, 1);
  const data = reports.docs[0].data();
  const ptr = (await pointer(uid).get()).data();
  assert.equal(ptr.reportId, reports.docs[0].id);
  assert.deepEqual(data.readyMetrics, ['body']);
  assert.deepEqual(ptr.readyMetrics, data.readyMetrics);
  assert.equal(data.metrics.activity, undefined);
  assert.equal(data.metrics.body.baseline.median, 100);
  assert.equal(data.metrics.body.populationComparison.cohort.referenceVersion, getReferenceCohort('シリアン').referenceVersion);
  assert.equal(data.metrics.body.populationComparison.cohort.sourceDOI, '10.1111/jsap.13527');
  assert.ok(!JSON.stringify(data).includes('private source text'));
  assert.equal((await user(uid).collection('analysis_events').get()).size, 1);
  await assertGenerationMetadata(uid, reports.docs[0].id);
  await unchanged(firstRef, firstBefore);
});

test('historical ready Silver creates neither a report nor a pointer', async () => {
  const uid = 'historical-only';
  await seed(uid, false, false);
  await user(uid).collection('daily_health_features').doc('2026-09-24').set(silver(true, true, '2026-09-24'));
  assert.equal((await run(uid, '2026-09-24')).status, 'historical_skipped');
  assert.equal((await run(uid)).status, 'learning');
  assert.equal((await reportCollection(uid).get()).size, 0);
  assert.equal((await pointer(uid).get()).exists, false);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 0);
});

test('body to both gain creates a new report; 10 competing transactions preserve the body report and legacy first', async () => {
  const uid = 'gain-both';
  await seed(uid);
  const bodyResult = await run(uid);
  const bodyRef = reportCollection(uid).doc(bodyResult.reportId);
  const bodyBefore = await snapshot(bodyRef);
  const bodyEventBefore = await snapshot(generationEvent(uid, bodyResult.reportId));
  const firstRef = user(uid).collection('personalized_reports').doc('first');
  const firstBefore = await snapshot(firstRef);
  const current = silver(true, true);
  current.body.personalBaseline.median = 104;
  await user(uid).collection('daily_health_features').doc(DAY).set(current);
  const results = await Promise.all(Array.from({ length: 10 }, () => run(uid)));
  assert.equal(results.filter(result => result.status === 'created').length, 1);
  assert.equal((await reportCollection(uid).get()).size, 2);
  const ptr = (await pointer(uid).get()).data();
  assert.deepEqual(ptr.readyMetrics, ['body', 'activity']);
  assert.deepEqual(ptr.publishedReadyMetrics, ['body', 'activity']);
  const both = (await reportCollection(uid).doc(ptr.reportId).get()).data();
  assert.equal(both.reportType, 'both');
  assert.equal(both.metrics.body.baseline.median, 104);
  assert.equal(both.metrics.activity.baseline.median, 628.3185);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 2);
  await assertGenerationMetadata(uid, ptr.reportId);
  await unchanged(generationEvent(uid, bodyResult.reportId), bodyEventBefore);
  await unchanged(bodyRef, bodyBefore);
  await unchanged(firstRef, firstBefore);
});

test('retry, next day, regression/regain and changed inputs never rewrite a published report or pointer', async () => {
  const uid = 'frozen-both';
  await seed(uid, true, true);
  const initial = await run(uid);
  const reportRef = reportCollection(uid).doc(initial.reportId);
  const reportBefore = await snapshot(reportRef);
  const pointerBefore = await snapshot(pointer(uid));
  const eventBefore = await snapshot(generationEvent(uid, initial.reportId));
  const audited = auditWrites();
  const retry = (day = DAY, now = NOW) => publish({ db: audited.db, uid, evaluationDateKey: day, now });
  assert.equal((await retry()).status, 'unchanged');
  await user(uid).collection('daily_health_features').doc(DAY).set(silver(true, false));
  assert.equal((await retry()).status, 'unchanged');
  await user(uid).collection('daily_health_features').doc(DAY).set(silver(true, true));
  assert.equal((await retry()).status, 'unchanged');
  const next = silver(true, true, '2026-10-09');
  next.body.personalBaseline.median = 150;
  await user(uid).collection('daily_health_features').doc('2026-10-09').set(next);
  assert.equal((await retry('2026-10-09', new Date('2026-10-09T02:00:00Z'))).status, 'unchanged');
  assert.equal((await reportCollection(uid).get()).size, 1);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 1);
  assert.deepEqual(audited.writes, []);
  await unchanged(reportRef, reportBefore);
  await unchanged(pointer(uid), pointerBefore);
  await unchanged(generationEvent(uid, initial.reportId), eventBefore);
});

test('dry run and invalid current schema write no report or pointer', async () => {
  const uid = 'dry-and-schema';
  await seed(uid, true, true);
  const firstRef = user(uid).collection('personalized_reports').doc('first');
  const firstBefore = await snapshot(firstRef);
  const dry = auditWrites();
  assert.equal((await publish({ db: dry.db, uid, evaluationDateKey: DAY, now: NOW, dryRun: true })).status, 'would_create');
  assert.deepEqual(dry.writes, []);
  assert.equal((await reportCollection(uid).get()).size, 0);
  assert.equal((await pointer(uid).get()).exists, false);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 0);
  await unchanged(firstRef, firstBefore);
  await user(uid).collection('daily_health_features').doc(DAY).update({ schemaVersion: 4 });
  assert.equal((await run(uid)).status, 'current_silver_unavailable');
  assert.equal((await reportCollection(uid).get()).size, 0);
  assert.equal((await pointer(uid).get()).exists, false);
});

test('report publication preserves first, Silver, Bronze, billing, trial, readiness and validation counters byte-for-byte', async () => {
  const uid = 'protected-state';
  await seed(uid, true, true);
  const fixtures = [
    ['feature_access/initial_trial_v2', { status: 'active', aiRequestUsed: 1, aiCostMicrosUsed: 50000 }],
    ['billing/subscription', { plan: 'paid', status: 'active' }],
    ['analysis_readiness/body', { currentStatus: 'ready', validRecordCount: 8 }],
    ['analysis_readiness/activity', { currentStatus: 'ready', validRecordCount: 8 }],
    ['weight_records/2026-10-06', { weightGrams: 100 }],
    ['distance_records/2026-10-07', { distance: 628.3185 }],
    ['daily_checkins/2026-10-08', { condition: 'normal' }],
    ['feature_access/initial_trial_v2/ai_usage/request-1', { status: 'succeeded' }],
    ['analysis_events/first_report_1', { eventName: 'first_personalized_report_generated', readyMetrics: ['body'] }],
    ['analysis_events/readiness_body_first_ready', { eventName: 'analysis_readiness_changed', metric: 'body', currentStatus: 'ready' }],
  ];
  const protectedRefs = fixtures.map(([relative]) => user(uid).collection(relative.split('/')[0]).doc(relative.slice(relative.indexOf('/') + 1)));
  for (let index = 0; index < fixtures.length; index++) await protectedRefs[index].set(fixtures[index][1]);
  const budgetRef = db.collection('system').doc('ai_validation_budget_prelaunch_202610');
  await budgetRef.set({ requestCount: 5, reservedCostMicros: 250000 });
  protectedRefs.push(budgetRef, user(uid).collection('personalized_reports').doc('first'), user(uid).collection('daily_health_features').doc(DAY));
  const before = await Promise.all(protectedRefs.map(snapshot));
  const audited = auditWrites();
  const result = await publish({ db: audited.db, uid, evaluationDateKey: DAY, now: NOW });
  assert.ok(audited.writes.length > 0);
  const allowed = new Set([`users/${uid}/personality_reports/${result.reportId}`, `users/${uid}/report_pointers/personality`, `users/${uid}/analysis_events/personality_report_${result.reportId}`]);
  assert.ok(audited.writes.every(write => allowed.has(write.path)));
  for (let index = 0; index < protectedRefs.length; index++) await unchanged(protectedRefs[index], before[index]);
});

test('real reference seed retry creates zero documents and preserves all eight update times', async () => {
  const plan = referenceSeed.buildSeedPlan();
  const refs = [...plan.pointers, ...plan.documents].map(entry => db.doc(entry.path));
  const before = await Promise.all(refs.map(snapshot));
  const audited = auditWrites();
  const result = await referenceSeed.seedReferenceCohorts(audited.db, plan, { projectId: PROJECT_ID, emulatorHost: HOST });
  assert.equal(result.created, 0);
  assert.equal(result.unchanged, 8);
  assert.deepEqual(audited.writes, []);
  for (let index = 0; index < refs.length; index++) await unchanged(refs[index], before[index]);
});

test('guarded backfill defaults to dry run of current Silver, deduplicates UID and performs zero write calls', async () => {
  const uid = 'backfill-preview';
  await seed(uid, true, true);
  const firstRef = user(uid).collection('personalized_reports').doc('first');
  const firstBefore = await snapshot(firstRef);
  const silverRef = user(uid).collection('daily_health_features').doc(DAY);
  const silverBefore = await snapshot(silverRef);
  const options = backfill.parseOptions([`--project=${PROJECT_ID}`, `--uids=${uid},${uid}`]);
  assert.equal(options.dryRun, true);
  const audited = auditWrites();
  const results = await backfill.backfillUsers({ db: audited.db, target: { projectId: PROJECT_ID, emulatorHost: HOST }, uids: options.uids, evaluationDateKey: DAY, now: NOW, sync: publish });
  assert.equal(results.length, 1);
  assert.equal(results[0].status, 'would_create');
  assert.deepEqual(audited.writes, []);
  assert.equal((await reportCollection(uid).get()).size, 0);
  assert.equal((await pointer(uid).get()).exists, false);
  assert.equal((await user(uid).collection('analysis_events').get()).size, 0);
  await unchanged(firstRef, firstBefore);
  await unchanged(silverRef, silverBefore);
  for (const target of [{ projectId: 'hamster-breeding-app', emulatorHost: HOST }, { projectId: PROJECT_ID, emulatorHost: 'production.example.invalid:443' }, { projectId: PROJECT_ID }]) {
    await assert.rejects(backfill.backfillUsers({ db: audited.db, target, uids: [uid], evaluationDateKey: DAY, now: NOW, sync: publish }));
  }
  assert.deepEqual(audited.writes, []);
});

test('newer pointer dates and malformed existing reports cannot be overwritten or republished', async () => {
  const uid = 'stale-and-conflict';
  await seed(uid, true, true);
  await pointer(uid).set({ reportId: 'existing-future', publishedReadyMetrics: ['body'], evaluationDateKey: '2026-10-09' });
  const pointerBefore = await snapshot(pointer(uid));
  assert.equal((await run(uid)).status, 'stale_evaluation');
  await unchanged(pointer(uid), pointerBefore);
  assert.equal((await reportCollection(uid).get()).size, 0);
  await pointer(uid).delete();
  const badReport = reportCollection(uid).doc('personality_v1_body_activity');
  await badReport.set({ reportId: 'wrong', readyMetrics: ['body'], schemaVersion: 0 });
  const badBefore = await snapshot(badReport);
  assert.equal((await run(uid)).status, 'existing_report_conflict');
  assert.equal((await pointer(uid).get()).exists, false);
  await unchanged(badReport, badBefore);
});
