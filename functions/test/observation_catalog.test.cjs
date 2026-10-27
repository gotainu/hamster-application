'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');
const {createRequire} = require('node:module');
const {test} = require('node:test');
const {execFileSync} = require('node:child_process');
const dep = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dep('typescript');
function load(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = {exports: {}}; cache.set(file, mod);
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}}).outputText;
  vm.runInThisContext(`(function(exports, require, module) {${code}\n})`, {filename: file})(mod.exports, name => load(path.resolve(path.dirname(file), `${name}.ts`), cache), mod);
  return mod.exports;
}
const root = path.resolve(__dirname, '../..');
const catalog = load(path.join(root, 'functions/src/health/observationCatalog.ts'));
test('generated TS and Dart bindings match one canonical catalog', () => {
  execFileSync('python3', [path.join(root, 'tool/generate_observation_catalog.py'), '--check']);
  const source = JSON.parse(fs.readFileSync(path.join(root, 'shared/observation_catalog.json')));
  assert.equal(catalog.OBSERVATION_CATALOG_VERSION, source.version);
  assert.deepEqual(catalog.observationCatalog, source.items.map(x => ({...x, aliases: x.legacyIds, legacyIds: undefined})).map(({legacyIds, ...x}) => x));
});
test('active eight choices, seven normal defaults, retired item remains readable', () => {
  assert.deepEqual(catalog.activeObservationItems().map(x => x.id), ['appetite', 'water', 'elimination', 'breathing', 'movement', 'eyesNose', 'coatSkin', 'other']);
  assert.equal(catalog.activeObservationItems().filter(x => x.defaultNormal).length, 7);
  assert.equal(catalog.resolveObservationId('poop'), 'elimination');
  assert.equal(catalog.resolveObservationId('排泄'), 'elimination');
  assert.equal(catalog.observationLabel('chewing'), 'かじり方');
  assert.equal(catalog.resolveObservationId('unknown'), null);
});
test('new item, order change, rename and retirement are catalog driven', () => {
  const modified = catalog.observationCatalog.map(x => x.id === 'appetite' ? {...x, label: '食欲の様子', active: false, legacyNames: ['食欲']} : x);
  modified.push({id: 'futureObservation', label: '追加項目', order: 0, active: true, insightEligible: true, defaultNormal: false, aliases: [], legacyNames: []});
  assert.equal(catalog.activeObservationItems(modified)[0].id, 'futureObservation');
  assert.equal(catalog.activeObservationItems(modified).some(x => x.id === 'appetite'), false);
  assert.equal(catalog.resolveObservationId('食欲', modified), 'appetite');
  assert.equal(catalog.observationLabel('appetite', modified), '食欲の様子');
});

test('equal display orders use locale-independent ID ordering shared with Dart', () => {
  const item = (id) => ({id, label: id, order: 0, active: true, insightEligible: true,
    defaultNormal: false, aliases: [], legacyNames: []});
  assert.deepEqual(catalog.activeObservationItems([item('a'), item('Z')]).map(x => x.id), ['Z', 'a']);
});
