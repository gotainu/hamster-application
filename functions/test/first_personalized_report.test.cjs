'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const ts = require('typescript');

const UID = 'first-report-unit-user';
const USER = `users/${UID}`;
const REPORT = `${USER}/personalized_reports/first`;
const TRIAL = `${USER}/feature_access/initial_trial_v2`;
const BODY = `${USER}/analysis_readiness/body`;
const ACTIVITY = `${USER}/analysis_readiness/activity`;

// Execute current TypeScript in memory; no build, Firebase client, or credentials.
function loadReportModule(specVersion = 'personal_baseline_v1') {
  const cache = new Map();
  const entry = path.resolve(__dirname, '../src/health/firstPersonalizedReport.ts');
  const admin = {
    firestore: {
      Timestamp: { fromDate: (date) => date.toISOString() },
      FieldValue: { serverTimestamp: () => ({ __serverTimestamp: true }) },
    },
  };
  function load(filename) {
    if (cache.has(filename)) return cache.get(filename).exports;
    let source = fs.readFileSync(filename, 'utf8');
    if (filename === entry && specVersion !== 'personal_baseline_v1') {
      const original = "export const PERSONALIZED_ANALYSIS_SPEC_VERSION = 'personal_baseline_v1';";
      assert.ok(source.includes(original));
      source = source.replace(original,
        `export const PERSONALIZED_ANALYSIS_SPEC_VERSION = '${specVersion}';`);
    }
    const compiled = ts.transpileModule(source, {
      fileName: filename,
      reportDiagnostics: true,
      compilerOptions: {
        target: ts.ScriptTarget.ES2020,
        module: ts.ModuleKind.CommonJS,
        esModuleInterop: true,
      },
    });
    assert.deepEqual((compiled.diagnostics ?? []).filter(
      (item) => item.category === ts.DiagnosticCategory.Error), []);
    const module = { exports: {} };
    cache.set(filename, module);
    const localRequire = (name) => {
      if (name === 'firebase-admin') return admin;
      if (name === '../validationIdentity') {
        return { isValidationUid: (uid) => uid === UID };
      }
      assert.ok(name.startsWith('.'), `Unexpected external dependency: ${name}`);
      return load(path.resolve(path.dirname(filename), `${name}.ts`));
    };
    const execute = vm.runInThisContext(
      `(function(exports, require, module, __filename, __dirname) {\n${compiled.outputText}\n})`,
      { filename },
    );
    execute(module.exports, localRequire, module, filename, path.dirname(filename));
    return module.exports;
  }
  return load(entry);
}

function fakeFirestore() {
  const documents = new Map();
  const writes = [];
  function ref(value) {
    return {
      path: value,
      collection: (name) => ref(`${value}/${name}`),
      doc: (id) => ref(`${value}/${id}`),
    };
  }
  function resolve(value, commitTime) {
    if (value?.__serverTimestamp === true) return commitTime;
    if (Array.isArray(value)) return value.map((item) => resolve(item, commitTime));
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(
        ([key, item]) => [key, resolve(item, commitTime)]));
    }
    return value;
  }
  function merge(old, next) {
    const result = structuredClone(old ?? {});
    for (const [key, value] of Object.entries(next)) {
      result[key] = value && typeof value === 'object' && !Array.isArray(value)
        ? merge(result[key], value) : structuredClone(value);
    }
    return result;
  }
  return {
    documents,
    writes,
    commitTime: null,
    collection: (name) => ref(name),
    async runTransaction(action) {
      const pending = [];
      const result = await action({
        async get(reference) {
          assert.equal(pending.length, 0, 'Firestore reads must precede writes');
          const data = structuredClone(documents.get(reference.path));
          return { exists: data !== undefined, data: () => structuredClone(data) };
        },
        set(reference, data, options) {
          pending.push({ path: reference.path, data: structuredClone(data), options });
        },
      });
      for (const write of pending) {
        const data = resolve(write.data, this.commitTime);
        documents.set(write.path, write.options?.merge
          ? merge(documents.get(write.path), data) : structuredClone(data));
        writes.push({ ...write, data });
      }
      return result;
    },
  };
}

function baseline(recordCount, spanDays) {
  return {
    status: recordCount >= 7 && spanDays >= 14 ? 'ready' : 'learning',
    recordCount,
    requiredRecordCount: 7,
    spanDays,
    requiredSpanDays: 14,
    firstDateKey: recordCount ? '2026-09-22' : null,
    lastDateKey: recordCount ? '2026-10-05' : null,
  };
}

function features(bodyCount = 8, bodySpan = 14, activityCount = 0, activitySpan = 0) {
  return {
    body: { personalBaseline: baseline(bodyCount, bodySpan) },
    activity: { personalBaseline: baseline(activityCount, activitySpan) },
  };
}

async function sync(db, module, current = features(), dayOffset = 0) {
  const now = new Date(Date.UTC(2026, 9, 7 + dayOffset, 2, 52, 28));
  db.commitTime = new Date(now.getTime() + 1000).toISOString();
  await module.syncPersonalizedAnalysis({
    db, uid: UID, dateKey: now.toISOString().slice(0, 10), features: current, now,
  });
  return now.toISOString();
}

async function generatedFixture() {
  const module = loadReportModule();
  const db = fakeFirestore();
  db.documents.set(TRIAL, {
    trialId: 'initial_trial_v2', policyVersion: 'initial_trial_v2',
    endsAt: '2026-10-26T12:00:59.426Z',
  });
  const firstTime = await sync(db, module);
  return { db, module, firstTime, frozen: structuredClone(db.documents.get(REPORT)) };
}

function assertFrozen(db, frozen, writeStart) {
  assert.deepEqual(db.documents.get(REPORT), frozen);
  assert.equal(db.writes.slice(writeStart).filter((write) => write.path === REPORT).length, 0,
    'A generated first report must receive no writes, including unchanged writes');
}

function generationWrites(db) {
  return db.writes.filter((write) =>
    write.data.eventName === 'first_personalized_report_generated');
}

test('zero ready metrics leaves the first report absent while saving readiness', async () => {
  const db = fakeFirestore();
  await sync(db, loadReportModule(), features(6, 14));
  assert.equal(db.documents.has(REPORT), false);
  assert.equal(db.documents.get(BODY).currentStatus, 'learning');
  assert.equal(db.documents.get(ACTIVITY).currentStatus, 'learning');
  assert.equal(generationWrites(db).length, 0);
});

test('body-only readiness creates the complete first report and one generation event', async () => {
  const { db, firstTime, frozen } = await generatedFixture();
  assert.deepEqual(frozen.readyMetrics, ['body']);
  assert.equal(frozen.generation.status, 'generated');
  assert.equal(frozen.analysisRevision, 1);
  assert.equal(frozen.generation.analysisRevision, 1);
  assert.equal(frozen.generation.generatedAt, firstTime);
  assert.equal(frozen.firstGeneratedAt, firstTime);
  assert.equal(frozen.generation.sourceDateKey, '2026-10-07');
  assert.equal(frozen.analysisSpecVersion, 'personal_baseline_v1');
  assert.equal(frozen.reportId, 'first');
  assert.equal(frozen.logicalId, 'first');
  assert.equal(frozen.reportKind, 'initial_personalized');
  assert.equal(frozen.petId, 'main_pet');
  assert.equal(frozen.userId, UID);
  assert.equal(frozen.testOnly, true);
  assert.equal(frozen.trialId, 'initial_trial_v2');
  assert.equal(frozen.policyVersion, 'initial_trial_v2');
  assert.equal(frozen.trialEndsAt, '2026-10-26T12:00:59.426Z');
  assert.equal(frozen.reportJoinKey, `${UID}:main_pet:first:1`);
  assert.deepEqual(frozen.access, { mode: 'read_only', requiresSubscription: false });
  assert.equal(frozen.updatedAt, db.commitTime);
  assert.deepEqual(frozen.metricStates.map(({ metric, status }) => ({ metric, status })),
    [{ metric: 'body', status: 'ready' }, { metric: 'activity', status: 'learning' }]);
  assert.equal(generationWrites(db).length, 1);
  assert.equal(generationWrites(db)[0].path, `${USER}/analysis_events/first_report_1`);
});

test('later activity readiness and trial changes cannot write or expand the first report', async () => {
  const { db, module, frozen } = await generatedFixture();
  db.documents.set(TRIAL, { trialId: 'changed', policyVersion: 'changed', endsAt: null });
  const writeStart = db.writes.length;
  await sync(db, module, features(9, 15, 7, 14), 1);
  assertFrozen(db, frozen, writeStart);
  assert.equal(db.documents.get(ACTIVITY).currentStatus, 'ready');
  assert.equal(db.documents.get(ACTIVITY).validRecordCount, 7);
  assert.equal(db.documents.get(BODY).validRecordCount, 9);
  assert.equal(generationWrites(db).length, 1);
});

test('ready-to-learning regression updates current readiness but never the first report', async () => {
  const { db, module, frozen } = await generatedFixture();
  const firstReadyAt = db.documents.get(BODY).firstReadyAt;
  const writeStart = db.writes.length;
  await sync(db, module, features(6, 14), 1);
  assertFrozen(db, frozen, writeStart);
  assert.equal(db.documents.get(BODY).currentStatus, 'learning');
  assert.deepEqual(db.documents.get(BODY).missingConditions, ['valid_record_count']);
  assert.equal(db.documents.get(BODY).firstReadyAt, firstReadyAt);
});

test('a future analysis spec updates readiness without changing the frozen report spec', async () => {
  const { db, frozen } = await generatedFixture();
  const writeStart = db.writes.length;
  await sync(db, loadReportModule('personal_baseline_v2'), features(8, 14, 7, 14), 1);
  assertFrozen(db, frozen, writeStart);
  assert.equal(db.documents.get(BODY).analysisSpecVersion, 'personal_baseline_v2');
  assert.equal(db.documents.get(ACTIVITY).analysisSpecVersion, 'personal_baseline_v2');
  assert.equal(db.documents.get(REPORT).analysisSpecVersion, 'personal_baseline_v1');
});

test('repeated syncs and metric changes produce exactly one report-generation write', async () => {
  const { db, module, frozen } = await generatedFixture();
  const writeStart = db.writes.length;
  await sync(db, module, features(), 1);
  await sync(db, module, features(8, 14, 7, 14), 2);
  await sync(db, module, features(0, 0), 3);
  await sync(db, module, features(), 4);
  assertFrozen(db, frozen, writeStart);
  assert.equal(generationWrites(db).length, 1);
  assert.equal(db.writes.filter((write) => write.path === REPORT).length, 1);
});

test('readiness transitions, firstReadyAt, and unknown snapshot fields survive the freeze', async () => {
  const { db, module } = await generatedFixture();
  db.documents.get(REPORT).futureSnapshot = { content: 'keep', version: 42 };
  const frozen = structuredClone(db.documents.get(REPORT));
  const firstReadyAt = db.documents.get(BODY).firstReadyAt;
  const writeStart = db.writes.length;
  await sync(db, module, features(6, 14), 1);
  await sync(db, module, features(8, 14, 7, 14), 2);
  assertFrozen(db, frozen, writeStart);
  const current = db.documents.get(BODY);
  assert.equal(current.currentStatus, 'ready');
  assert.equal(current.transitionSequence, 3);
  assert.equal(current.firstReadyAt, firstReadyAt);
  assert.equal(current.sourceDateKey, '2026-10-09');
  assert.equal(current.updatedAt, db.commitTime);
  assert.equal(db.documents.get(ACTIVITY).currentStatus, 'ready');
  assert.equal(db.documents.get(`${USER}/analysis_events/readiness_body_transition_3`).currentStatus, 'ready');
});

for (const status of ['failed', 'generating']) {
  test(`existing ${status} reports retain the previous recovery behavior`, async () => {
    const db = fakeFirestore();
    db.documents.set(REPORT, {
      generation: { status }, readyMetrics: [], analysisRevision: 1,
      analysisSpecVersion: 'personal_baseline_v1', retainedSnapshotField: 'legacy',
    });
    await sync(db, loadReportModule());
    const report = db.documents.get(REPORT);
    assert.equal(report.generation.status, 'generated');
    assert.deepEqual(report.readyMetrics, ['body']);
    assert.equal(report.analysisRevision, 2);
    assert.equal(report.retainedSnapshotField, 'legacy');
    assert.equal(generationWrites(db).length, 1);
  });
}
