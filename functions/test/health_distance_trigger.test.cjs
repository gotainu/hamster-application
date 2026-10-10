'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const ts = require('typescript');

const NOW = '2026-10-07T02:52:28.000Z';
const TODAY = '2026-10-07';
const UID = 'distance-trigger-unit-user';
const USER = `users/${UID}`;
const ACTIVITY = `${USER}/analysis_readiness/activity`;
const REPORT = `${USER}/personalized_reports/first`;
const OLD_RECORD_REBUILDS = [
  '2026-09-23', '2026-09-24', '2026-09-25', '2026-09-26',
  '2026-09-27', '2026-09-28', '2026-09-29', TODAY,
];

class FixedDate extends Date {
  constructor(...args) { super(...(args.length ? args : [NOW])); }
  static now() { return Date.parse(NOW); }
}

// Execute current TS in memory. Every external service import is intercepted;
// this harness never initializes Firebase, loads credentials, or uses a network.
function loadSourceModules(rebuildHealthForDate) {
  const root = path.resolve(__dirname, '../src/health');
  const triggerEntry = path.join(root, 'healthTriggers.ts');
  const cache = new Map();
  const admin = {
    firestore: {
      FieldPath: { documentId: () => '__name__' },
      Timestamp: { fromDate: (date) => date.toISOString() },
      FieldValue: { serverTimestamp: () => ({ __serverTimestamp: true }) },
    },
  };
  const registration = (_options, handler) => handler;
  function load(filename) {
    if (cache.has(filename)) return cache.get(filename).exports;
    const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
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
      if (name === 'firebase-functions/v2/firestore') {
        return { onDocumentWritten: registration };
      }
      if (name === 'firebase-functions/v2/https') {
        return { onCall: registration, HttpsError: class extends Error {} };
      }
      if (name === 'firebase-functions/logger') {
        return { info() {}, error() {} };
      }
      if (name === 'firebase-admin') return admin;
      if (filename === triggerEntry && name === './healthPipeline') {
        return { rebuildHealthForDate };
      }
      if (name === '../validationIdentity') {
        return { isValidationUid: (uid) => uid === UID };
      }
      assert.ok(name.startsWith('.'), `Unexpected external import: ${name}`);
      return load(path.resolve(path.dirname(filename), `${name}.ts`));
    };
    const execute = vm.runInThisContext(
      `(function(exports, require, module, __filename, __dirname, Date) {\n${compiled.outputText}\n})`,
      { filename },
    );
    execute(module.exports, localRequire, module, filename, path.dirname(filename), FixedDate);
    return module.exports;
  }
  return (name) => load(path.join(root, `${name}.ts`));
}

function eventFor(dayKey, operation = 'create') {
  const snapshot = (exists) => ({ exists, data: () => exists ? { distance: 1000 } : undefined });
  return {
    params: { uid: UID, sourceDateKey: dayKey },
    data: {
      before: snapshot(operation !== 'create'),
      after: snapshot(operation !== 'delete'),
    },
  };
}

async function rebuiltDates(dayKey, operation = 'create') {
  const calls = [];
  const load = loadSourceModules(async (params) => {
    calls.push(params);
    return {};
  });
  await load('healthTriggers').healthDistanceRecordWritten(eventFor(dayKey, operation));
  assert.ok(calls.every((call) =>
    call.uid === UID && call.reason === 'distance_record_written'));
  return calls.map((call) => call.dateKey);
}

for (const operation of ['create', 'update', 'delete']) {
  test(`old distance ${operation} rebuilds historical dates then today exactly once`, async () => {
    const dates = await rebuiltDates('2026-09-22', operation);
    assert.deepEqual(dates, OLD_RECORD_REBUILDS);
    assert.equal(dates.filter((date) => date === TODAY).length, 1);
  });
}

test('yesterday already includes today and never rebuilds it twice', async () => {
  assert.deepEqual(await rebuiltDates('2026-10-06'), [TODAY]);
});

test('a recent historical range keeps its dates without duplicating today', async () => {
  assert.deepEqual(await rebuiltDates('2026-10-02'), [
    '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06', TODAY,
  ]);
});

for (const dayKey of [TODAY, '2026-10-08']) {
  test(`distance ${dayKey} keeps the existing early return`, async () => {
    for (const operation of ['create', 'update', 'delete']) {
      assert.deepEqual(await rebuiltDates(dayKey, operation), []);
    }
  });
}

test('a record outside the current 90-day window still finishes with today once', async () => {
  const dates = await rebuiltDates('2026-01-01');
  assert.equal(dates.length, 8);
  assert.equal(dates.at(-1), TODAY);
  assert.equal(dates.filter((date) => date === TODAY).length, 1);
});

function fakeFirestore() {
  const documents = new Map();
  const writes = [];
  function ref(value) {
    return {
      path: value,
      collection: (name) => ref(`${value}/${name}`),
      doc: (id) => ref(`${value}/${id}`),
      orderBy(field) {
        assert.equal(field, '__name__');
        let start;
        let end;
        return {
          startAt(dateKey) { start = dateKey; return this; },
          endAt(dateKey) { end = dateKey; return this; },
          async get() {
            const prefix = `${value}/`;
            const docs = [...documents.entries()].flatMap(([key, data]) => {
              if (!key.startsWith(prefix)) return [];
              const id = key.slice(prefix.length);
              if (id.includes('/') || id < start || id > end) return [];
              return [{ id, data: () => structuredClone(data) }];
            }).sort((a, b) => a.id.localeCompare(b.id));
            return { docs };
          },
        };
      },
    };
  }
  function resolve(value) {
    if (value?.__serverTimestamp === true) return NOW;
    if (Array.isArray(value)) return value.map(resolve);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, resolve(item)]));
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
    collection: (name) => ref(name),
    async runTransaction(action) {
      const pending = [];
      const result = await action({
        async get(reference) {
          assert.equal(pending.length, 0, 'Transaction reads must precede writes');
          const data = structuredClone(documents.get(reference.path));
          return { exists: data !== undefined, data: () => structuredClone(data) };
        },
        set(reference, data, options) {
          pending.push({ path: reference.path, data: structuredClone(data), options });
        },
      });
      for (const write of pending) {
        const data = resolve(write.data);
        documents.set(write.path, write.options?.merge
          ? merge(documents.get(write.path), data) : data);
        writes.push({ ...write, data });
      }
      return result;
    },
  };
}

test('A/B/C, past updates and deletes save today readiness while generated first stays frozen', async () => {
  const db = fakeFirestore();
  const calls = [];
  const weightDates = [
    '2026-09-22', '2026-09-29', '2026-09-30', '2026-10-01',
    '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06',
  ];
  const load = loadSourceModules(async (params) => {
    calls.push(params.dateKey);
    await syncForDate(params.dateKey);
    return {};
  });
  const { addDaysToDateKey } = load('dateKey');
  const { fetchDistanceWindow } = load('firestoreReaders');
  const { buildDailyHealthFeatures } = load('dailyHealthFeatures');
  const { syncPersonalizedAnalysis } = load('firstPersonalizedReport');
  async function syncForDate(dateKey) {
    const activitySourceDateKey = addDaysToDateKey(dateKey, -1);
    const { features } = buildDailyHealthFeatures({
      dateKey,
      generatedAt: new Date(NOW),
      source: {
        environment: { sourceKind: 'none', windowDays: 7, windowRecordCount: 0 },
        activitySourceDateKey,
        distanceWindow: await fetchDistanceWindow({ db, uid: UID, dateKey: activitySourceDateKey, days: 91 }),
        weightRecords: weightDates.map((dayKey) => ({ dayKey, weightGrams: 100, date: null })),
        dailyCheckin: { exists: false, concernTags: [], observationLevels: {}, memo: '', date: null },
        nutrition: { exists: false, memo: '', date: null },
      },
    });
    await syncPersonalizedAnalysis({ db, uid: UID, dateKey, features, now: new Date(NOW) });
  }
  function setDistance(dayKey, distance = 1000) {
    db.documents.set(`${USER}/distance_records/${dayKey}`, { dayKey, distance });
  }
  function assertReadiness(count, span, status) {
    const current = db.documents.get(ACTIVITY);
    assert.equal(current.sourceDateKey, TODAY);
    assert.equal(current.validRecordCount, count);
    assert.equal(current.requiredRecordCount, 7);
    assert.equal(current.observationSpanDays, span);
    assert.equal(current.requiredObservationSpanDays, 14);
    assert.equal(current.currentStatus, status);
  }
  await syncForDate(TODAY);
  db.documents.get(REPORT).futureSnapshot = { retained: true };
  const frozen = structuredClone(db.documents.get(REPORT));
  assert.deepEqual(frozen.readyMetrics, ['body']);
  assert.equal(frozen.generation.status, 'generated');
  assert.equal(frozen.analysisRevision, 1);
  const writeStart = db.writes.length;
  const handler = load('healthTriggers').healthDistanceRecordWritten;

  // Step A: six records; yesterday is the target and is excluded from baseline.
  for (const dayKey of weightDates.slice(3)) setDistance(dayKey);
  await handler(eventFor('2026-10-05'));
  assertReadiness(5, 5, 'learning');

  // Step B: count condition met, calendar span still short.
  setDistance('2026-09-29');
  setDistance('2026-09-30');
  await handler(eventFor('2026-09-30'));
  assertReadiness(7, 7, 'learning');

  // Step C: no yesterday re-save; the old addition must finish at today's ready.
  setDistance('2026-09-22');
  calls.length = 0;
  await handler(eventFor('2026-09-22'));
  assert.deepEqual(calls, OLD_RECORD_REBUILDS);
  assertReadiness(8, 14, 'ready');
  const firstReadyAt = db.documents.get(ACTIVITY).firstReadyAt;
  assert.equal(firstReadyAt, NOW);
  assert.equal(db.documents.get(ACTIVITY).observationStartDateKey, '2026-09-22');
  assert.equal(db.documents.get(ACTIVITY).observationEndDateKey, '2026-10-05');
  assert.deepEqual(db.documents.get(ACTIVITY).missingConditions, []);

  setDistance('2026-09-22', 2000);
  await handler(eventFor('2026-09-22', 'update'));
  assertReadiness(8, 14, 'ready');
  db.documents.delete(`${USER}/distance_records/2026-09-22`);
  await handler(eventFor('2026-09-22', 'delete'));
  assertReadiness(7, 7, 'learning');
  assert.equal(db.documents.get(ACTIVITY).firstReadyAt, firstReadyAt);

  assert.deepEqual(db.documents.get(REPORT), frozen);
  assert.equal(db.writes.slice(writeStart).filter((write) => write.path === REPORT).length, 0,
    'Generated first must receive no writes, including unchanged writes');
});
