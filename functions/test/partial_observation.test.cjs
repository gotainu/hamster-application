'use strict';
// Source-level pure tests and a transactional in-memory Firestore. No Emulator,
// Firebase initialization, messaging, network or changes to real account data.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test, after} = require('node:test');
const {createRequire} = require('node:module');
const dep = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE
  ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dep('typescript');
const actualAdmin = dep('firebase-admin');
const NOW = new Date('2026-11-08T05:00:00Z');
const DAY = '2026-11-08';
const UID = 'synthetic-partial-owner';
const SUBJECT = 'synthetic-partial-pet-0001';
let forbiddenSdkCalls = 0;
const stamp = Object.freeze({partialTestFieldValue: 'serverTimestamp'});
const remove = Object.freeze({partialTestFieldValue: 'delete'});
const firestore = Object.assign(() => {
  forbiddenSdkCalls++;
  throw new Error('Real Firestore is forbidden');
}, {
  Timestamp: actualAdmin.firestore.Timestamp,
  FieldValue: {serverTimestamp: () => stamp, delete: () => remove},
});
const admin = {
  firestore,
  initializeApp() {forbiddenSdkCalls++; throw new Error('No real Firebase app');},
  messaging() {forbiddenSdkCalls++; throw new Error('No real notification');},
};
class TestHttpsError extends Error {
  constructor(code, message) {super(message); this.code = code;}
}
function load(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = {exports: {}};
  cache.set(file, mod);
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true},
  }).outputText;
  const req = name => name === 'firebase-admin' ? admin
    : name === 'firebase-functions/v2/https' ? {HttpsError: TestHttpsError, onCall: (_options, handler) => handler}
    : name === 'firebase-functions/v2/firestore' ? {onDocumentWritten: (_options, handler) => handler}
    : name === 'firebase-functions/logger' ? {info() {}, error() {}}
    : name.startsWith('.') ? load(path.resolve(path.dirname(file), `${name}.ts`), cache) : dep(name);
  vm.runInThisContext(`(function(exports,require,module){${code}\n})`, {filename: file})(mod.exports, req, mod);
  return mod.exports;
}
const root = path.resolve(__dirname, '../src');
const history = load(path.join(root, 'observationHistory/observationHistory.ts'));
const daily = load(path.join(root, 'health/dailyHealthFeatures.ts'));
const health = load(path.join(root, 'health/healthAssessment.ts'));
const lifecycle = load(path.join(root, 'health/healthIncidentLifecycle.ts'));
const notifications = load(path.join(root, 'health/goldHealthNotification.ts'));
const insights = load(path.join(root, 'health/checkinInsights.ts'));
const catalog = load(path.join(root, 'health/observationCatalog.ts'));
const care = load(path.join(root, 'careActions/careActions.ts'));
const partial = (extra = {}) => ({
  dayKey: DAY, date: '2026-11-07T15:00:00Z', subjectId: SUBJECT,
  expectedRevision: 0, mutationId: 'partial-mutation-0001', operation: 'new_observation',
  observationCatalogVersion: catalog.OBSERVATION_CATALOG_VERSION,
  inputUiVersion: 'daily_checkin_partial_v1',
  timing: {precision: 'unknown', confirmation: 'unknown'},
  ...extra,
});
const legacy = (extra = {}) => partial({
  inputUiVersion: 'daily_checkin_history_v1', condition: 'normal', concernTags: [], memo: '', ...extra,
});
const normalize = data => history.normalizeObservationMutation(data, NOW);
function clone(value) {
  if (value instanceof Date) return new Date(value);
  if (value instanceof firestore.Timestamp) return value;
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, clone(item)]));
  return value;
}
function resolve(value) {
  if (value?.partialTestFieldValue === 'serverTimestamp') return firestore.Timestamp.fromDate(NOW);
  if (value instanceof Date || value instanceof firestore.Timestamp) return value;
  if (Array.isArray(value)) return value.map(resolve);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).filter(([, item]) => item?.partialTestFieldValue !== 'delete').map(([key, item]) => [key, resolve(item)]));
  return value;
}
class MemorySnapshot {
  constructor(ref, data) {this.ref = ref; this.id = ref.id; this.exists = data !== undefined; this.value = clone(data);}
  data() {return clone(this.value);}
  get(key) {return key.split('.').reduce((value, part) => value?.[part], this.value);}
}
class MemoryRef {
  constructor(db, key) {this.db = db; this.path = key; this.id = key.split('/').at(-1);}
  collection(name) {return new MemoryQuery(this.db, `${this.path}/${name}`);}
  get() {return Promise.resolve(new MemorySnapshot(this, this.db.documents.get(this.path)));}
}
class MemoryQuery {
  constructor(db, key, filters = [], order = null, limit = Infinity) {this.db = db; this.path = key; this.filters = filters; this.order = order; this.maximum = limit;}
  doc(id) {return new MemoryRef(this.db, `${this.path}/${id}`);}
  where(field, operator, value) {assert.equal(operator, '=='); return new MemoryQuery(this.db, this.path, [...this.filters, [field, value]], this.order, this.maximum);}
  orderBy(field) {return new MemoryQuery(this.db, this.path, this.filters, field, this.maximum);}
  limit(count) {return new MemoryQuery(this.db, this.path, this.filters, this.order, count);}
  async get() {
    let docs = [...this.db.documents.entries()].filter(([key]) => key.startsWith(`${this.path}/`) && !key.slice(this.path.length + 1).includes('/'))
      .map(([key, data]) => new MemorySnapshot(this.db.doc(key), data));
    for (const [field, value] of this.filters) docs = docs.filter(doc => doc.get(field) === value);
    if (this.order) docs.sort((a, b) => a.get(this.order) - b.get(this.order));
    docs = docs.slice(0, this.maximum);
    return {docs, size: docs.length, empty: docs.length === 0};
  }
}
class MemoryDb {
  constructor() {this.documents = new Map(); this.writes = [];}
  doc(key) {assert.ok(key === `users/${UID}` || key.startsWith(`users/${UID}/`), 'Synthetic owner paths only'); return new MemoryRef(this, key);}
  collection(key) {assert.equal(key, 'users'); return new MemoryQuery(this, key);}
  seed(key, data) {this.documents.set(key, clone(data));}
  async runTransaction(callback) {
    const pending = [];
    const tx = {
      get: ref => ref.get(),
      getAll: (...refs) => Promise.all(refs.map(ref => ref.get())),
      set: (ref, data, options) => pending.push({kind: 'set', ref, data, options}),
      create: (ref, data) => pending.push({kind: 'create', ref, data}),
      delete: ref => pending.push({kind: 'delete', ref}),
    };
    const value = await callback(tx);
    for (const write of pending) {
      this.writes.push({kind: write.kind, path: write.ref.path});
      if (write.kind === 'create') assert.ok(!this.documents.has(write.ref.path));
      if (write.kind === 'delete') this.documents.delete(write.ref.path);
      else {
        const data = write.options?.merge ? {...this.documents.get(write.ref.path), ...clone(write.data)} : clone(write.data);
        this.documents.set(write.ref.path, resolve(data));
      }
    }
    return value;
  }
}
function seededDb() {
  const db = new MemoryDb();
  db.seed(`users/${UID}/pet_profiles/main_pet`, {ownerUid: UID, subjectId: SUBJECT});
  db.seed(`users/${UID}/pet_subjects/${SUBJECT}`, {ownerUid: UID, petId: 'main_pet', active: true});
  db.seed(`users/${UID}/billing/subscription`, {plan: 'paid', status: 'active'});
  return db;
}
const save = (db, data) => history.saveObservationMutation({db, uid: UID, data, now: NOW});
function source(answer = null, exists = answer != null) {
  return {
    environment: {
      sourceKind: 'none', sourceDateKey: null, status: null, level: null, headline: null, todayAction: null, why: null,
      avgTemp: null, avgHum: null, tempRatio: null, humRatio: null, dangerMinutes: null, spikesTemp: null, spikesHum: null,
      sourceDocCount: 0, version: null, evaluatedAt: null, windowDays: 7, windowRecordCount: 0,
      highTemperatureDays: 0, lowTemperatureDays: 0, highHumidityDays: 0, lowHumidityDays: 0,
      latestDailyTemp: null, latestDailyHum: null, temperatureTrend: 'unknown', humidityTrend: 'unknown',
    },
    activitySourceDateKey: '2026-11-07', distanceWindow: [], weightRecords: [],
    dailyCheckin: {exists, dayKey: DAY, condition: answer?.condition ?? null, concernTags: answer?.concernTags ?? [],
      observationLevels: answer?.observationLevels ?? {}, memo: answer?.memo ?? '', date: null},
    nutrition: {exists: false, dayKey: DAY, foodOfferedGrams: null, foodRemainingGrams: null, foodConsumedGrams: null, memo: '', date: null},
  };
}
function assess(answer, complete = false) {
  const input = source(answer);
  const built = daily.buildDailyHealthFeatures({source: input, dateKey: DAY, generatedAt: NOW});
  if (complete) {
    Object.assign(built.features.environment, {avgTemp: 23, avgHum: 50, tempRatio: 1, humRatio: 1, dangerMinutes: 0,
      spikesTemp: 0, spikesHum: 0, windowRecordCount: 7});
    Object.assign(built.features.activity, {hasRecord: true, distanceMeters: 1000, avg7DistanceMeters: 1000, deltaPct: 0,
      personalBaseline: {status: 'ready', method: 'median_mad_ewma_v1', recordCount: 7, requiredRecordCount: 7,
        spanDays: 14, requiredSpanDays: 14, firstDateKey: '2026-10-20', lastDateKey: '2026-11-06', median: 1000,
        mad: 0, ewma: 1000, ewmaAlpha: 0.3, deviationPct: 0, robustZScore: null}});
    built.bodyAssessment = {state: 'good', score: 100, flags: [], summary: 'Synthetic body context', recommendedActions: [], sourceUpdatedAt: null};
  }
  return {features: built.features, assessment: health.buildHealthAssessment({features: built.features, bodyAssessment: built.bodyAssessment, evaluatedAt: NOW})};
}
function activeCondition(db, extra = {}) {
  const key = `users/${UID}/health_incidents/condition__previous_concern`;
  db.seed(key, {incidentId: 'condition:previous_concern', domain: 'condition', status: 'active', stateVersion: 4,
    lastNotifiedAt: firestore.Timestamp.fromDate(NOW), currentState: 'alert', ...extra});
  return key;
}
after(() => assert.equal(forbiddenSdkCalls, 0, 'No real Firebase or messaging path may run'));

test('new partial empty or whitespace-only observations are rejected', () => {
  for (const value of [partial(), partial({condition: null}), partial({memo: '  \n\t ', concernTags: []})]) {
    assert.throws(() => normalize(value), error => error.code === 'invalid-argument');
  }
});
test('tag-only partial input keeps null overall and never generates unselected normals', () => {
  const row = normalize(partial({concernTags: ['appetite']}));
  assert.equal(row.answer.condition, null);
  assert.deepEqual(row.answer.concernTags, ['appetite']);
  assert.deepEqual(row.answer.observationLevels, {appetite: 'changed'});
  assert.equal(row.answer.answerProvenance.overall, 'unanswered');
  assert.equal(row.answer.answerProvenance.normalLevels, 'not_generated');
  assert.equal(row.answer.observationResponseMode, 'partial_overall_with_selected_tags');
  assert.equal(row.answer.schemaVersion, 2);
  assert.equal(row.inputUiVersion, 'daily_checkin_partial_v1');
});
test('memo-only partial input trims content without inventing a health answer', () => {
  const row = normalize(partial({memo: '  Synthetic observation note  '}));
  assert.equal(row.answer.memo, 'Synthetic observation note');
  assert.equal(row.answer.condition, null);
  assert.deepEqual(row.answer.concernTags, []);
  assert.deepEqual(row.answer.observationLevels, {});
  assert.equal(row.timing.timePrecision, 'unknown');
  assert.equal(row.timing.observedAt, null);
});
test('explicit partial overall responses keep existing meaning without automatic item values', () => {
  for (const condition of ['normal', 'slightlyConcerned', 'veryConcerned']) {
    const row = normalize(partial({condition}));
    assert.equal(row.answer.condition, condition);
    assert.deepEqual(row.answer.observationLevels, {});
    assert.equal(row.answer.answerProvenance.overall, 'explicit_submission');
  }
});
test('partial requests still reject invalid enums, unknown tags, contradictions and missing timing', () => {
  for (const value of [partial({condition: 'fine'}), partial({concernTags: ['made-up']}), partial({concernTags: false}),
    partial({concernTags: null}), partial({memo: 123}), partial({condition: 'normal', concernTags: ['appetite']}),
    partial({memo: 'note', timing: undefined}), partial({memo: 'note', timing: {precision: 'instant', confirmation: 'now_confirmed'}}),
    partial({memo: 'note', inputUiVersion: 'unknown'}), partial({memo: 'note', observationLevels: {appetite: 'normal'}})]) {
    assert.throws(() => normalize(value), error => error.code === 'invalid-argument');
  }
});
test('legacy normalization and explicit date unknown instant timing remain unchanged', () => {
  const old = normalize(legacy());
  assert.equal(old.answer.observationResponseMode, 'overall_with_selected_tags');
  assert.equal(old.answer.observationLevels.appetite, 'normal');
  assert.equal(old.answer.answerProvenance.normalLevels, 'automatic_normal');
  assert.equal(old.inputUiVersion, 'daily_checkin_history_v1');
  assert.equal(old.answer.answeredObservationIds, undefined);
  for (const absent of [{condition: undefined}, {condition: null}, {concernTags: undefined}]) assert.throws(() => normalize(legacy(absent)));
  const dated = normalize(legacy({timing: {precision: 'date_only', dateKey: DAY, confirmation: 'date_confirmed'}}));
  assert.equal(dated.timing.observedAt, null); assert.equal(dated.timing.timePrecision, 'date_only');
  const instant = normalize(partial({memo: 'note', timing: {precision: 'instant', observedAt: '2026-11-08T04:00:00Z', confirmation: 'time_confirmed'}}));
  assert.equal(instant.timing.observedAt, '2026-11-08T04:00:00.000Z');
  assert.equal(instant.timing.clockSource, 'user_reported');
});
test('partial Raw projection and receipt replay preserve answers and add no duplicate revision', async () => {
  const db = seededDb(), request = partial({concernTags: ['appetite']});
  const first = await save(db, request), beforeWrites = db.writes.length;
  const replay = await save(db, request);
  assert.equal(replay.replayed, true); assert.equal(replay.revision, first.revision);
  assert.equal(db.writes.length, beforeWrites);
  const projection = db.documents.get(`users/${UID}/daily_checkins/${DAY}`);
  assert.equal(projection.condition, null);
  assert.deepEqual(projection.observationLevels, {appetite: 'changed'});
  assert.equal(projection.inputUiVersion, 'daily_checkin_partial_v1');
  const receipt = db.documents.get(`users/${UID}/observation_days/${DAY}/mutations/${request.mutationId}`);
  assert.equal(receipt.requestFingerprint, care.careActionMutationFingerprint(request));
  await assert.rejects(save(db, {...request, memo: 'Different retry'}), error => error.code === 'already-exists');
});
test('legacy retry fingerprints and cancellation keep the previous contract', async () => {
  const db = seededDb(), request = legacy();
  const first = await save(db, request), writes = db.writes.length;
  assert.equal((await save(db, request)).replayed, true); assert.equal(db.writes.length, writes);
  assert.equal(db.documents.get(`users/${UID}/daily_checkins/${DAY}`).observationLevels.appetite, 'normal');
  const cancel = legacy({mutationId: 'legacy-cancel-0001', expectedRevision: 1, operation: 'cancel',
    targetEventId: first.eventId, targetRevision: 1, condition: null, concernTags: null, memo: null, timing: null});
  assert.equal((await save(db, cancel)).recordStatus, 'cancelled');
  assert.equal(db.documents.has(`users/${UID}/daily_checkins/${DAY}`), false);
  assert.equal((await save(db, cancel)).replayed, true);
});
test('memo-only Silver preserves memo but missing condition stays unscored and non-notifiable', () => {
  const answer = normalize(partial({memo: 'Synthetic note'})).answer;
  const {features, assessment} = assess(answer);
  assert.equal(features.condition.recorded, false);
  assert.equal(features.condition.memo, 'Synthetic note');
  assert.ok(features.dataQuality.missingDomains.includes('condition'));
  assert.equal(assessment.domains.condition.state, 'insufficientData');
  assert.equal(assessment.domains.condition.score, null);
  assert.equal(assessment.overall.observedState, 'insufficientData');
  assert.equal(assessment.overall.score, null);
  assert.equal(notifications.buildGoldHealthNotificationCandidate(assessment), null);
});
test('all absent condition input never becomes false zero or normal evidence', () => {
  const {features, assessment} = assess({condition: null, concernTags: [], observationLevels: {}, memo: ''});
  assert.equal(features.condition.recorded, false);
  assert.equal(features.condition.condition, null);
  assert.deepEqual(features.condition.observationLevels, {});
  assert.equal(assessment.domains.condition.score, null);
  assert.equal(assessment.overall.score, null);
  assert.equal(assessment.overall.observedScore, null);
});
test('tag-only partial concerns keep the existing caution score and an unanswered marker', () => {
  const answer = normalize(partial({concernTags: ['appetite']})).answer;
  const {features, assessment} = assess(answer);
  assert.equal(features.condition.recorded, true);
  assert.equal(assessment.domains.condition.state, 'caution');
  assert.equal(assessment.domains.condition.score, 70);
  assert.ok(assessment.domains.condition.flags.includes('conditionOverallUnanswered'));
  assert.equal(assessment.overall.score, null);
  assert.equal(notifications.buildGoldHealthNotificationCandidate(assessment), null, 'Existing confidence policy is retained');
});
test('explicit full overall answers retain the exact existing domain severity and scores', () => {
  for (const [condition, tags, state, score] of [
    ['normal', [], 'good', 100], ['slightlyConcerned', ['appetite'], 'caution', 70], ['veryConcerned', ['appetite'], 'alert', 40],
  ]) {
    const old = assess(normalize(legacy({condition, concernTags: tags})).answer, true).assessment;
    const current = assess(normalize(partial({condition, concernTags: tags})).answer, true).assessment;
    assert.equal(current.domains.condition.state, state); assert.equal(current.domains.condition.score, score);
    assert.deepEqual(current.domains.condition, old.domains.condition);
    assert.equal(current.overall.score, old.overall.score);
    assert.equal(current.overall.scoreCoverage, old.overall.scoreCoverage);
    assert.equal(current.overall.confidence, old.overall.confidence);
  }
});
test('checkin evidence never counts a null overall as normal or expands the denominator', () => {
  const tags = normalize(partial({concernTags: ['appetite']})).answer;
  const memo = normalize(partial({memo: 'note'})).answer;
  const evidence = insights.buildCheckinInsightEvidence({evaluationDateKey: DAY, records: [
    {id: DAY, data: {...tags, dayKey: DAY}}, {id: '2026-11-07', data: {...memo, dayKey: '2026-11-07'}},
  ]});
  assert.equal(evidence.validRecordDayCount, 0); assert.equal(evidence.concernDayCount, 0);
  assert.deepEqual(evidence.records, []);
  const normal = normalize(partial({condition: 'normal'})).answer;
  const explicit = insights.buildCheckinInsightEvidence({evaluationDateKey: DAY, records: [{id: DAY, data: {...normal, dayKey: DAY}}]});
  assert.equal(explicit.validRecordDayCount, 1);
  assert.equal(explicit.records[0].items.appetite.origin, 'unanswered');
  assert.equal(explicit.records[0].items.appetite.level, null);
});
test('missing condition evidence cannot resolve a previously notified condition incident', async () => {
  for (const assessment of [assess(normalize(partial({memo: 'note'})).answer).assessment,
    {...assess(null).assessment, domains: {...assess(null).assessment.domains, condition: {state: 'unknown', score: null, flags: ['conditionUnknown'], summary: '', recommendedActions: [], sourceUpdatedAt: null}}}]) {
    const db = seededDb(), key = activeCondition(db), before = clone(db.documents.get(key));
    await lifecycle.syncHealthIncidentLifecycle({db, uid: UID, assessment, now: NOW});
    assert.deepEqual(db.documents.get(key), before);
    assert.equal(db.documents.get(key).resolvedNotificationStatus, undefined);
    assert.equal(notifications.buildGoldHealthNotificationCandidate(assessment), null);
  }
});
test('partial concern can notify normally without resolving an unobserved older concern', async () => {
  const {assessment} = assess(normalize(partial({concernTags: ['appetite']})).answer, true);
  const candidate = notifications.buildGoldHealthNotificationCandidate(assessment);
  assert.ok(candidate); assert.notEqual(candidate.primaryFlag, 'conditionOverallUnanswered');
  const db = seededDb(), key = activeCondition(db), previous = clone(db.documents.get(key));
  await lifecycle.syncHealthIncidentLifecycle({db, uid: UID, assessment, now: NOW});
  assert.deepEqual(db.documents.get(key), previous);
  const current = lifecycle.buildActiveHealthIncidents(assessment);
  assert.ok(current.length > 0);
  assert.equal(current.some(row => row.conditionType.toLowerCase().includes('unanswered')), false);
  assert.ok(db.writes.some(row => row.path.startsWith(`users/${UID}/health_incidents/`)));
});
test('a confirmed normal overall still resolves a previous concern as before', async () => {
  const db = seededDb(), key = activeCondition(db);
  const {assessment} = assess(normalize(partial({condition: 'normal'})).answer, true);
  await lifecycle.syncHealthIncidentLifecycle({db, uid: UID, assessment, now: NOW});
  assert.equal(db.documents.get(key).status, 'resolved');
  assert.equal(db.documents.get(key).resolvedNotificationStatus, 'pending');
});
