"use strict";
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const ts = require('typescript');
const REPO = path.resolve(__dirname, '../..');
const DAY = '2026-10-08';
const NOW = new Date('2026-10-08T02:00:00Z');
const UID = 'personality-analytics-fixture';
const USER = `users/${UID}`;
const EVENTS = ['first_personalized_report_generated', 'personality_report_generated'];
function sql(name) { return fs.readFileSync(path.join(REPO, 'docs/analytics', name), 'utf8'); }
function cte(source, name, next) {
  const start = source.indexOf(`${name} AS (`);
  const end = source.indexOf(`${next} AS (`, start + 1);
  assert.ok(start >= 0 && end > start, `Expected CTE ${name}`);
  return source.slice(start, end);
}
function generationNames(query) {
  const text = cte(query, 'report_generations', 'ga4_events');
  const predicate = text.match(/WHERE event_name (?:IN\s*\(([^)]*)\)|=\s*('([^']+)'))/);
  assert.ok(predicate, 'Explicit generation-event allowlist');
  return [...(predicate[1] || predicate[2]).matchAll(/'([^']+)'/g)].map(m => m[1]);
}
// Execute only the documented equality/time predicates over synthetic rows.
// This is an offline contract fixture, not a BigQuery SQL execution claim.
function matchingViews(query, trials, generations, views) {
  const acceptedNames = generationNames(query);
  const join = cte(query, 'matched_report_views', 'views_by_trial');
  const predicates = [...join.matchAll(/([sgv])\.(\w+)\s*(=|>=)\s*([sgv])\.(\w+)/g)];
  assert.equal(predicates.length, 8, 'All UID/trial/pet/report/revision and time predicates retained');
  assert.match(join, /v\.event_name\s*=\s*'personalized_report_viewed'/);
  const result = [];
  for (const s of trials) for (const g of generations) for (const v of views) {
    if (!acceptedNames.includes(g.event_name) || v.event_name !== 'personalized_report_viewed') continue;
    if (['trial_id', 'pet_id', 'report_id', 'report_revision'].some(k => g[k] == null)) continue;
    if (!v.user_id || v.test_only !== 1 || v.analytics_identity_version !== 'firebase_uid_v1') continue;
    const rows = {s, g, v};
    if (!predicates.every(([, a, ak, op, b, bk]) => {
      const left = rows[a][ak], right = rows[b][bk];
      return left != null && right != null && (op === '=' ? left === right : left >= right);
    })) continue;
    result.push({...v, trial_id: s.trial_id, analysis_spec_version: g.analysis_spec_version});
  }
  return result;
}
function loadReport() {
  const cache = new Map();
  function read(file) {
    if (cache.has(file)) return cache.get(file).exports;
    const compiled = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
      fileName: file, reportDiagnostics: true,
      compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true},
    });
    assert.deepEqual((compiled.diagnostics || []).filter(d => d.category === ts.DiagnosticCategory.Error), []);
    const mod = {exports: {}}; cache.set(file, mod);
    const req = name => name === 'firebase-admin'
      ? {firestore: {Timestamp: {fromDate: d => d.toISOString()}}}
      : name.startsWith('.') ? read(path.resolve(path.dirname(file), `${name}.ts`)) : require(name);
    vm.runInThisContext(`(function(exports,require,module){\n${compiled.outputText}\n})`, {filename: file})(mod.exports, req, mod);
    return mod.exports;
  }
  return read(path.join(REPO, 'functions/src/health/personalityReport.ts'));
}
function fixture() {
  const docs = new Map(), writes = []; let queue = Promise.resolve();
  const ref = p => ({path: p, collection: n => ref(`${p}/${n}`), doc: n => ref(`${p}/${n}`)});
  const db = {docs, writes, collection: n => ref(n), runTransaction(action) {
    const pending = queue.then(async () => {
      const changes = [];
      const result = await action({
        get: async r => {
          assert.equal(changes.length, 0, 'No transaction read after a write');
          const value = docs.get(r.path);
          return {exists: value !== undefined, data: () => structuredClone(value)};
        },
        create: (r, value) => {assert.ok(!docs.has(r.path)); changes.push({path: r.path, value, mode: 'create'});},
        set: (r, value) => changes.push({path: r.path, value, mode: 'set'}),
      });
      for (const change of changes) {docs.set(change.path, structuredClone(change.value)); writes.push(structuredClone(change));}
      return result;
    });
    queue = pending.catch(() => {}); return pending;
  }};
  const baseline = {status: 'ready', median: 100, mad: 3, ewma: 101, ewmaAlpha: 0.3, recordCount: 8,
    requiredRecordCount: 7, spanDays: 14, requiredSpanDays: 14, firstDateKey: '2026-09-23',
    lastDateKey: '2026-10-06', method: 'median_mad_ewma_v1', deviationPct: 10, robustZScore: 1};
  docs.set(`${USER}/daily_health_features/${DAY}`, {schemaVersion: 5, dateKey: DAY, generatedAt: NOW,
    body: {personalBaseline: baseline, latestWeightGrams: 110, memo: 'PRIVATE_MEMO'},
    activity: {personalBaseline: {...baseline, status: 'learning', recordCount: 2}},
    condition: {memo: 'PRIVATE_QUESTION'}});
  docs.set(`${USER}/pet_profiles/main_pet`, {name: 'PRIVATE_PET_NAME', species: 'unknown', memo: 'PRIVATE_PROFILE'});
  docs.set(`${USER}/feature_access/initial_trial_v2`, {trialId: 'trial-fixture', policyVersion: 'initial_trial_v2',
    endsAt: new Date('2026-10-29T02:00:00Z'), testOnly: true, private: 'PRIVATE_BILLING'});
  docs.set(`${USER}/personalized_reports/first`, {generation: {status: 'generated'}, analysisRevision: 1, readyMetrics: ['body']});
  return db;
}
const publish = (db, report, dryRun = false) => report.syncPersonalityReport({db, uid: UID, evaluationDateKey: DAY, now: NOW, dryRun});
const analysisEvents = db => [...db.docs].filter(([p]) => p.startsWith(`${USER}/analysis_events/`));

test('both SQL views include personality generation while retaining legacy generation', () => {
  const journey = sql('trial_journey.sql');
  assert.deepEqual(generationNames(journey), EVENTS);
  for (const field of ['trial_id', 'pet_id', 'report_id', 'report_revision']) {
    assert.match(cte(journey, 'report_generations', 'ga4_events'), new RegExp(`AND ${field} IS NOT NULL`));
  }
  const server = sql('server_events_normalized.sql');
  const predicates = [...server.matchAll(/e\.event_name IN\s*\(([^)]*)\)/g)]
    .filter(m => m[1].includes('personality_report_generated'));
  assert.equal(predicates.length, 4, 'Timestamp, pet, report and revision use the same event set');
  for (const p of predicates) assert.deepEqual([...p[1].matchAll(/'([^']+)'/g)].map(m => m[1]), EVENTS);
});

test('personality views require exact UID, trial, pet, report, revision and chronology', () => {
  const query = sql('trial_journey.sql');
  const trial = {user_id: 'a', trial_id: 'trial-a', trial_started_at: 10};
  const generation = {event_name: 'personality_report_generated', user_id: 'a', trial_id: 'trial-a',
    pet_id: 'main_pet', report_id: 'personality_v1_body', report_revision: 1, generated_at: 20, analysis_spec_version: 'personality_v1'};
  const view = {event_name: 'personalized_report_viewed', user_id: 'a', pet_id: 'main_pet', report_id: 'personality_v1_body',
    report_revision: 1, event_at: 30, presentation_id: 'valid', test_only: 1, analytics_identity_version: 'firebase_uid_v1'};
  assert.equal(matchingViews(query, [trial], [generation], [view]).length, 1);
  for (const patch of [{user_id: 'b'}, {user_id: null}, {pet_id: 'other'}, {report_id: 'personality_v1_activity'},
    {report_id: 'first'}, {report_revision: 2}, {event_at: 19}, {test_only: 0}, {analytics_identity_version: 'unverified'}]) {
    assert.equal(matchingViews(query, [trial], [generation], [{...view, ...patch}]).length, 0, JSON.stringify(patch));
  }
  for (const patch of [{trial_id: 'other-trial'}, {trial_id: null}, {report_id: null}, {report_revision: null}, {user_id: 'b'}]) {
    assert.equal(matchingViews(query, [trial], [{...generation, ...patch}], [view]).length, 0, JSON.stringify(patch));
  }
  assert.equal(matchingViews(query, [{...trial, trial_started_at: 31}], [generation], [view]).length, 0);
  const legacy = {...generation, event_name: 'first_personalized_report_generated', report_id: 'first'};
  assert.equal(matchingViews(query, [trial], [legacy], [{...view, report_id: 'first'}]).length, 1);
});

test('repeat presentations preserve earliest A3 view and count each presentation once', () => {
  const query = sql('trial_journey.sql');
  const aggregate = cte(query, 'views_by_trial', 'paywall_by_trial');
  assert.match(aggregate, /MIN\(event_at\) AS first_report_viewed_at/);
  assert.match(aggregate, /COUNT\(DISTINCT presentation_id\) AS report_view_count/);
  const trial = {user_id: 'a', trial_id: 'trial-a', trial_started_at: 10};
  const generation = {event_name: 'personality_report_generated', user_id: 'a', trial_id: 'trial-a', pet_id: 'main_pet',
    report_id: 'personality_v1_body', report_revision: 1, generated_at: 20};
  const base = {event_name: 'personalized_report_viewed', user_id: 'a', pet_id: 'main_pet', report_id: 'personality_v1_body',
    report_revision: 1, test_only: 1, analytics_identity_version: 'firebase_uid_v1'};
  const matches = matchingViews(query, [trial], [generation], [
    {...base, event_at: 40, presentation_id: 'second', is_first_view: 0},
    {...base, event_at: 30, presentation_id: 'first', is_first_view: 1},
    {...base, event_at: 30, presentation_id: 'first', is_first_view: 1},
  ]);
  assert.equal(Math.min(...matches.map(v => v.event_at)), 30);
  assert.equal(new Set(matches.map(v => v.presentation_id)).size, 2);
});

test('new publication emits one immutable metadata-only server event without changing first or trial', async () => {
  const report = loadReport(), db = fixture();
  const firstBefore = structuredClone(db.docs.get(`${USER}/personalized_reports/first`));
  const trialBefore = structuredClone(db.docs.get(`${USER}/feature_access/initial_trial_v2`));
  await Promise.all(Array.from({length: 6}, () => publish(db, report)));
  assert.equal(analysisEvents(db).length, 1);
  const [eventPath, event] = analysisEvents(db)[0];
  assert.equal(eventPath, `${USER}/analysis_events/personality_report_personality_v1_body`);
  const allowed = new Set(['eventName', 'eventId', 'testOnly', 'trialId', 'policyVersion', 'trialEndsAt', 'actor', 'source',
    'petId', 'reportId', 'reportRevision', 'readyMetrics', 'analysisSpecVersion', 'occurredAt', 'reportJoinKey']);
  for (const key of Object.keys(event)) assert.ok(allowed.has(key), `Unexpected analytics field ${key}`);
  assert.equal(event.eventName, 'personality_report_generated');
  assert.equal(event.reportId, 'personality_v1_body'); assert.equal(event.reportRevision, 1);
  assert.equal(event.petId, 'main_pet'); assert.equal(event.analysisSpecVersion, 'personality_v1');
  assert.deepEqual(event.readyMetrics, ['body']); assert.equal(event.testOnly, true);
  assert.equal(event.trialId, 'trial-fixture'); assert.equal(event.policyVersion, trialBefore.policyVersion);
  assert.deepEqual(event.trialEndsAt, trialBefore.endsAt); assert.equal(event.occurredAt, NOW.toISOString());
  assert.ok(!JSON.stringify(event).includes('PRIVATE_'));
  assert.deepEqual(db.docs.get(`${USER}/personalized_reports/first`), firstBefore);
  assert.deepEqual(db.docs.get(`${USER}/feature_access/initial_trial_v2`), trialBefore);
  db.docs.delete(`${USER}/report_pointers/personality`);
  await publish(db, report);
  assert.equal(analysisEvents(db).length, 1, 'Recovery never fabricates or overwrites historical generation');
  assert.equal(db.writes.filter(w => w.path.startsWith(`${USER}/analysis_events/`)).length, 1);
});

test('dry-run and absent trial cannot fabricate analytics trial attribution', async () => {
  const report = loadReport(), db = fixture();
  await publish(db, report, true);
  assert.equal(db.writes.length, 0); assert.equal(analysisEvents(db).length, 0);
  db.docs.delete(`${USER}/feature_access/initial_trial_v2`);
  await publish(db, report);
  const event = analysisEvents(db)[0][1];
  assert.equal(event.trialId, null); assert.equal(event.policyVersion, null); assert.equal(event.trialEndsAt, null);
});
