'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');
const {createRequire} = require('node:module');
const {test} = require('node:test');
const dep = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dep('typescript');
function load(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = {exports: {}}; cache.set(file, mod);
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true}}).outputText;
  const req = name => name.startsWith('.') ? load(path.resolve(path.dirname(file), `${name}.ts`), cache) : dep(name);
  vm.runInThisContext(`(function(exports, require, module) {${code}\n})`, {filename: file})(mod.exports, req, mod);
  return mod.exports;
}
const root = path.resolve(__dirname, '../src/health');
const weight = load(path.join(root, 'weightAssessment.ts'));
const baseline = load(path.join(root, 'personalBaseline.ts'));
const insights = load(path.join(root, 'weightInsights.ts'));
const DAY = '2026-10-11';
const NOW = new Date('2026-10-11T02:00:00Z');
const DATES = ['2026-09-22', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-10'];
const records = values => DATES.slice(0, values.length).map((dayKey, i) => ({dayKey, weightGrams: values[i]}));
function current(source, day = DAY, now = NOW) {
  const evaluated = weight.evaluateWeightRecords({records: source, referenceDateKey: day});
  const evidence = insights.buildWeightInsightEvidence({records: source, referenceDateKey: day});
  return insights.buildCurrentInsightSet({features: {dateKey: day, schemaVersion: 5, generatedAt: now, body: evaluated.features, weightInsightEvidence: evidence}, generatedAt: now});
}
const range = set => set.insights.find(x => x.kind === 'weight_observed_range');
const difference = set => set.insights.find(x => x.kind === 'weight_period_difference');

test('all equal is determined from every selected measurement, not MAD', () => {
  const set = current(records(Array(9).fill(100)));
  assert.equal(range(set).evidence.minimumGrams, 100);
  assert.equal(range(set).evidence.maximumGrams, 100);
  assert.equal(range(set).interpretationCode, 'weight_all_equal');
  assert.equal(range(set).validRecordCount, 8);
  assert.equal(difference(set), undefined, 'same meaning is not repeated');
});
test('range keeps an interior outlier even when median and MAD remain zero-deviation', () => {
  const source = records([100, 100, 100, 104, 100, 100, 100, 100, 100]);
  assert.equal(weight.evaluateWeightRecords({records: source, referenceDateKey: DAY}).features.personalBaseline.mad, 0);
  const set = current(source);
  assert.equal(range(set).evidence.minimumGrams, 100);
  assert.equal(range(set).evidence.maximumGrams, 104);
  assert.equal(range(set).interpretationCode, 'weight_observed_range');
});
test('period uses first and last real records, keeping gaps without imputing measurements', () => {
  const source = [{dayKey: '2026-09-22', weightGrams: 100}, {dayKey: '2026-10-10', weightGrams: 103}];
  const value = difference(current(source));
  assert.equal(value.evidence.differenceGrams, 3);
  assert.equal(value.evidence.startDateKey, '2026-09-22');
  assert.equal(value.evidence.endDateKey, '2026-10-10');
  assert.equal(value.validRecordCount, 2);
  assert.equal(value.dataQuality.missingDaysNotImputed, true);
  assert.equal(value.interpretationCode, 'weight_increased');
  assert.equal(range(current(source)), undefined, 'learning baseline has no observed-range discovery');
});
test('fewer than two distinct observation dates never creates period difference', () => {
  for (const source of [[], [{dayKey: '2026-10-10', weightGrams: 100}], [{dayKey: '2026-10-10', weightGrams: 100}, {dayKey: '2026-10-10', weightGrams: 103}]]) assert.equal(difference(current(source)), undefined);
});
test('decrease stores a signed difference and its positive absolute magnitude', () => {
  const value = difference(current([{dayKey: '2026-10-09', weightGrams: 103}, {dayKey: '2026-10-10', weightGrams: 100}]));
  assert.equal(value.interpretationCode, 'weight_decreased');
  assert.equal(value.evidence.differenceGrams, -3);
  assert.equal(value.evidence.absoluteDifferenceGrams, 3);
});
test('same-day correction selects the final normalized measurement once', () => {
  const source = [...records(Array(9).fill(100)), {dayKey: '2026-10-10', weightGrams: 103}];
  const value = difference(current(source));
  assert.equal(value.evidence.endWeightGrams, 103);
  assert.equal(value.records.filter(x => x.dateKey === '2026-10-10').length, 1);
});
test('30-day period is inclusive at its first day and excludes future observations', () => {
  const source = [{dayKey: '2026-09-11', weightGrams: 91}, {dayKey: '2026-09-12', weightGrams: 100}, {dayKey: '2026-10-11', weightGrams: 103}, {dayKey: '2026-10-12', weightGrams: 200}];
  const value = difference(current(source));
  assert.deepEqual(value.records.map(x => x.dateKey), ['2026-09-12', '2026-10-11']);
  assert.equal(value.evidence.differenceGrams, 3);
});
test('range shares the original baseline selector including 90-day exclusion, max14 and latest exclusion', () => {
  const source = Array.from({length: 20}, (_, i) => ({dayKey: `2026-09-${String(i + 1).padStart(2, '0')}`, weightGrams: 100 + i}));
  source.push({dayKey: '2026-10-10', weightGrams: 125}, {dayKey: '2026-01-01', weightGrams: 500});
  const selected = weight.selectWeightAnalysisObservations({records: source, referenceDateKey: DAY}).baselineObservations;
  const result = baseline.buildPersonalBaseline({observations: selected});
  const value = range(current(source));
  assert.deepEqual(value.records, selected);
  assert.equal(value.validRecordCount, result.recordCount);
  assert.equal(value.observationStartDateKey, result.firstDateKey);
  assert.equal(value.observationEndDateKey, result.lastDateKey);
  assert.equal(value.records.length, 14);
  assert.ok(!value.records.some(x => x.dateKey === '2026-10-10' || x.dateKey === '2026-01-01'));
});
test('invalid dates, non-finite/zero/negative/over1000 weights do not become evidence', () => {
  const source = [...records(Array(9).fill(100)), ...[0, -1, 1001, NaN, Infinity].map((weightGrams, i) => ({dayKey: `2026-10-0${i+1}`, weightGrams})), {dayKey: 'invalid', weightGrams: 101}];
  const selection = weight.selectWeightAnalysisObservations({records: source, referenceDateKey: DAY});
  assert.ok(selection.periodObservations.every(x => Number.isFinite(x.value) && x.value > 0 && x.value <= 1000));
});
test('learning only permits factual endpoint difference; stale records permit neither discovery', () => {
  assert.equal(range(current([{dayKey: '2026-10-10', weightGrams: 100}])), undefined);
  assert.equal(current(records(Array(9).fill(100)), '2026-11-01', new Date('2026-11-01T02:00:00Z')).insights.length, 0);
});
test('deterministic priority prefers nonzero endpoint difference and retains distinct range evidence', () => {
  const set = current(records([100, 100, 100, 104, 100, 100, 100, 100, 103]));
  assert.deepEqual(set.insights.map(x => x.kind), ['weight_period_difference', 'weight_observed_range']);
});
test('old Silver without evidence and mismatched evaluation/source generation fails closed', () => {
  const source = records(Array(9).fill(100));
  const body = weight.evaluateWeightRecords({records: source, referenceDateKey: DAY}).features;
  const base = {dateKey: DAY, schemaVersion: 5, generatedAt: NOW, body};
  assert.equal(insights.buildCurrentInsightSet({features: base, generatedAt: NOW}), null);
  const evidence = insights.buildWeightInsightEvidence({records: source, referenceDateKey: DAY});
  assert.equal(insights.buildCurrentInsightSet({features: {...base, weightInsightEvidence: {...evidence, evaluationDateKey: '2026-10-10'}}, generatedAt: NOW}), null);
  assert.equal(insights.buildCurrentInsightSet({features: {...base, weightInsightEvidence: evidence}, generatedAt: new Date(NOW.getTime() + 1000)}), null, 'Gold and Silver generation must be the same instant');
});
test('same generation retries share hash; fresh generation and corrected inputs differ, immutable snapshot is separate', () => {
  const source = records(Array(9).fill(100));
  const a = current(source);
  const b = current(source, DAY, new Date('2026-10-11T02:01:00Z'));
  assert.notEqual(a.contentHash, b.contentHash);
  assert.equal(a.contentHash, current(source).contentHash);
  assert.equal(a.source.evidenceHash, b.source.evidenceHash);
  const body = weight.evaluateWeightRecords({records: source, referenceDateKey: DAY}).features;
  const evidence = insights.buildWeightInsightEvidence({records: source, referenceDateKey: DAY});
  const snapshot = insights.buildReportInsightSnapshot({features: {dateKey: DAY, schemaVersion: 5, generatedAt: NOW, body, weightInsightEvidence: evidence}, generatedAt: NOW});
  assert.equal(snapshot.kind, 'report_snapshot');
  const frozen = JSON.stringify(snapshot);
  source[3].weightGrams = 104;
  assert.notEqual(current(source).contentHash, a.contentHash);
  assert.equal(JSON.stringify(snapshot), frozen);
});
