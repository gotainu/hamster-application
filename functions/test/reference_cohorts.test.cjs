'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const {spawnSync} = require('node:child_process');
const ts = require('typescript');
const ROOT = path.resolve(__dirname, '..');
function loadReferences() {
  const filename = path.join(ROOT, 'src/health/referenceCohorts.ts');
  const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: filename, reportDiagnostics: true,
    compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS},
  });
  assert.deepEqual((compiled.diagnostics || []).filter(d => d.category === ts.DiagnosticCategory.Error), []);
  const module = {exports: {}};
  const run = vm.runInThisContext(`(function(exports, require, module) {\n${compiled.outputText}\n})`, {filename});
  run(module.exports, name => {throw new Error('Unexpected dependency: ' + name);}, module);
  return module.exports;
}
function adult(overrides = {}) {
  const ref = loadReferences();
  return {species: 'シリアン', birthDateKey: '2026-01-01', assessmentDateKey: '2026-10-08', observationStartDateKey: '2026-09-01', weightGrams: 133, cohort: ref.getReferenceCohort('syrian'), ...overrides};
}
test('four seeded species reproduce Table 1 without treating species population as weight sample size', () => {
  const {REFERENCE_COHORTS, REFERENCE_COHORT_VERSION} = loadReferences();
  assert.equal(REFERENCE_COHORTS.length, 4);
  const expected = {syrian: [133, 100, 160, 12197], djungarian: [45, 34.5, 58, 2286], roborovski: [25, 20, 30, 1054], campbell: [46, 38, 50, 52]};
  for (const c of REFERENCE_COHORTS) {
    assert.deepEqual([c.median, c.p25, c.p75, c.speciesPopulationN], expected[c.speciesCode]);
    assert.equal(c.weightSampleN, null);
    assert.equal(c.referenceVersion, REFERENCE_COHORT_VERSION);
    assert.equal(c.sourceDOI, '10.1111/jsap.13527');
    assert.equal(c.measurementDefinition, 'mean_of_each_animals_recorded_weights_over_3_months');
    assert.ok(Object.isFrozen(c));
  }
});
test('Japanese species normalization is exact and unknown or mixed species never gets a default', () => {
  const {normalizeReferenceSpecies: n} = loadReferences();
  for (const [raw, expected] of [['シリアン', 'syrian'], ['ゴールデンハムスター', 'syrian'], ['ジャンガリアン', 'djungarian'], ['ロボロフスキー', 'roborovski'], ['チャイニーズ', 'chinese'], ['キャンベル', 'campbell'], [' Phodopus sungorus ', 'djungarian']]) assert.equal(n(raw), expected);
  for (const raw of [null, undefined, 20, '', '不明', 'ドワーフ', 'Russian dwarf', 'ジャンガリアンとキャンベルのハイブリッド']) assert.equal(n(raw), null);
});
test('adult applicability is strict after three calendar months and preserves month-end semantics', () => {
  const {buildPopulationWeightContext: build} = loadReferences();
  assert.equal(build({...adult(), birthDateKey: '2026-07-08', observationStartDateKey: '2026-10-08'}).applicability, 'not_applicable');
  assert.equal(build({...adult(), birthDateKey: '2026-07-07', observationStartDateKey: '2026-10-08'}).applicability, 'applicable');
  assert.equal(build({...adult(), birthDateKey: '2026-01-31', assessmentDateKey: '2026-04-30', observationStartDateKey: '2026-04-30'}).applicability, 'not_applicable');
  assert.equal(build({...adult(), birthDateKey: '2026-01-31', assessmentDateKey: '2026-05-01', observationStartDateKey: '2026-05-01'}).applicability, 'applicable');
  for (const birthDateKey of [null, undefined, '', '2026-02-30', '2026-10-09']) {
    const result = build({...adult(), birthDateKey});
    assert.equal(result.applicability, 'not_applicable');
    assert.equal(result.position, null);
  }
});
test('comparison uses only IQR categories, supports boundaries, and never invents percentile or health verdict', () => {
  const {buildPopulationWeightContext: build} = loadReferences();
  for (const [weightGrams, position] of [[99, 'below_iqr'], [100, 'within_iqr'], [133, 'within_iqr'], [160, 'within_iqr'], [161, 'above_iqr']]) {
    const c = build({...adult(), weightGrams});
    assert.equal(c.position, position);
    assert.ok(!Object.keys(c).some(k => /percentile|healthy|diagnos/i.test(k)));
    assert.match(c.expressionJa, /公開研究/);
    assert.ok(c.limitations.some(x => x.includes('健康な個体')));
  }
  for (const weightGrams of [null, 0, -2, NaN, Infinity]) assert.equal(build({...adult(), weightGrams}).applicability, 'not_applicable');
  assert.equal(build({...adult(), species: '不明'}).cohort, null);
});
test('Campbell warns that 52 is overall species population and weight sample n is unreported', () => {
  const c = loadReferences().buildPopulationWeightContext(adult({species: 'キャンベル', weightGrams: 46, cohort: loadReferences().getReferenceCohort('campbell')}));
  assert.equal(c.cohort.sampleSizeCaution, true);
  assert.ok(c.limitations.some(x => x.includes('52') && x.includes('体重')));
});
test('seed default is offline dry-run and write is rejected before any client initialization', () => {
  const script = path.join(ROOT, 'scripts/seed_reference_cohorts.cjs');
  const dry = spawnSync(process.execPath, [script], {cwd: ROOT, encoding: 'utf8', env: {PATH: process.env.PATH}});
  assert.equal(dry.status, 0, dry.stderr);
  const plan = JSON.parse(dry.stdout);
  assert.equal(plan.mode, 'dry_run'); assert.equal(plan.offline, true); assert.equal(plan.documents.length, 4);
  for (const [args, env] of [[['--write', '--project=hamster-breeding-app'], {FIRESTORE_EMULATOR_HOST: 'localhost:8080'}], [['--write', '--project=demo-reference-tests'], {}], [['--write', '--project=demo-reference-tests'], {FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443'}]]) {
    const r = spawnSync(process.execPath, [script, ...args], {cwd: ROOT, encoding: 'utf8', env: {PATH: process.env.PATH, ...env}});
    assert.notEqual(r.status, 0); assert.match(r.stderr, /demo-|emulator|localhost/i);
  }
});
test('seed is immutable and idempotent; conflicts prevent all writes', async () => {
  const {buildSeedPlan, seedReferenceCohorts} = require('../scripts/seed_reference_cohorts.cjs');
  const plan = buildSeedPlan(); const data = new Map(); let writes = 0;
  const db = {projectId: 'demo-reference-tests', doc: path => ({path}), runTransaction: async callback => {
    const pending = [];
    const result = await callback({get: async ref => ({exists: data.has(ref.path), data: () => data.get(ref.path)}), create: (ref, value) => pending.push([ref.path, value])});
    for (const [key, value] of pending) {data.set(key, value); writes++;}
    return result;
  }};
  const target = {projectId: 'demo-reference-tests', emulatorHost: 'localhost:8080'};
  assert.equal((await seedReferenceCohorts(db, plan, target)).created, 8);
  assert.equal((await seedReferenceCohorts(db, plan, target)).unchanged, 8); assert.equal(writes, 8);
  data.set(plan.documents[0].path, {...plan.documents[0].data, median: 999});
  data.delete(plan.documents[1].path);
  await assert.rejects(seedReferenceCohorts(db, plan, target), /immutable/i); assert.equal(writes, 8);
  await assert.rejects(seedReferenceCohorts({...db, projectId: 'hamster-breeding-app'}, plan, target), /project/i);
});

test('database reference is required and juvenile or missing earliest observations block adult comparisons', () => {
  const {buildPopulationWeightContext: build, getReferenceCohort} = loadReferences();
  assert.equal(build(adult({cohort: null})).reason, 'reference_unavailable');
  assert.equal(build(adult({cohort: undefined})).applicability, 'not_applicable');
  assert.equal(build(adult({cohort: getReferenceCohort('campbell')})).reason, 'reference_mismatch');
  assert.equal(build(adult({species: 'チャイニーズ', cohort: null})).applicability, 'not_applicable');
  assert.equal(getReferenceCohort('chinese'), null);
  assert.equal(build(adult({birthDateKey: '2026-05-01', observationStartDateKey: '2026-08-01'})).reason, 'juvenile_observations');
  assert.equal(build(adult({observationStartDateKey: null})).reason, 'observation_age_unknown');
  assert.equal(build(adult({observationStartDateKey: '2026-10-09'})).applicability, 'not_applicable');
  assert.ok(build(adult()).limitations.some(x => x.includes('平均') && x.includes('中央値')));
});

test('Firestore cohort parsing rejects malformed definitions and never carries arbitrary fields into report metadata', () => {
  const {parseReferenceCohort: parse, getReferenceCohort} = loadReferences();
  const valid = JSON.parse(JSON.stringify(getReferenceCohort('syrian')));
  assert.equal(parse(valid, 'syrian').median, 133);
  assert.equal(parse({...valid, extraHealthVerdict: 'healthy'}, 'syrian').extraHealthVerdict, undefined);
  for (const bad of [null, [], {...valid, unit: 'kg'}, {...valid, metric: 'activity'}, {...valid, referenceVersion: ''}, {...valid, sourceVersion: undefined}, {...valid, ageBand: 'juvenile'}, {...valid, p25: '100'}, {...valid, median: NaN}, {...valid, p25: 134}, {...valid, p75: 132}, {...valid, p25: 0}, {...valid, weightSampleN: 12197}, {...valid, usableComparisonExpressions: ['25th percentile']}, {...valid, dataQuality: {...valid.dataQuality, healthyReferenceRange: true}}]) assert.equal(parse(bad, 'syrian'), null);
  assert.equal(parse(valid, 'campbell'), null);
});
test('seed does not switch an existing currentReferenceVersion and remains fully offline when imported', async () => {
  const {buildSeedPlan, seedReferenceCohorts, validateWriteTarget} = require('../scripts/seed_reference_cohorts.cjs');
  const plan = buildSeedPlan(); let writes = 0;
  const db = {projectId: 'demo-reference-tests', doc: path => ({path}), runTransaction: callback => callback({
    get: async ref => ({exists: ref.path === plan.pointers[0].path, data: () => ({...plan.pointers[0].data, currentReferenceVersion: 'some_other_version'})}),
    create: () => {writes++;},
  })};
  await assert.rejects(seedReferenceCohorts(db, plan, {projectId: db.projectId, emulatorHost: '127.0.0.1:8080'}), /immutable/i);
  assert.equal(writes, 0);
  for (const emulatorHost of ['localhost:0', 'localhost:65536', 'https://localhost:8080', 'firestore.googleapis.com:443']) assert.throws(() => validateWriteTarget({projectId: db.projectId, emulatorHost}));
});
