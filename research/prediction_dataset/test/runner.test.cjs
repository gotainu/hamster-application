'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const runnerPath = path.join(root, 'runner.cjs');
const runner = require(runnerPath);
const fixturePath = path.join(root, 'fixtures/representative.json');
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

test('runner admits only explicitly synthetic fixture identities and dates', () => {
  assert.doesNotThrow(() => runner.assertSyntheticFixture(fixture));
  const undeclared = structuredClone(fixture);
  delete undeclared.syntheticOnly;
  assert.throws(() => runner.assertSyntheticFixture(undeclared), /syntheticOnly/);
  const unscopedIdentity = structuredClone(fixture);
  unscopedIdentity.anchors[0].subjectId = 'unapproved_real_identity';
  assert.throws(() => runner.assertSyntheticFixture(unscopedIdentity), /synthetic_/);
  const escapedDate = structuredClone(fixture);
  escapedDate.anchors[0].referenceDateKey = '2031-04-01';
  assert.throws(() => runner.assertSyntheticFixture(escapedDate), /2030/);
});

test('source loader rejects production entrypoint before SDK initialization', () => {
  const {loadTypeScript} = require('../tools/load-typescript.cjs');
  assert.throws(() => loadTypeScript(path.resolve(root, '../../functions/src/index.ts')), /Only isolated research source/);
});

test('runner rejects arbitrary input paths and arguments', () => {
  assert.throws(() => execFileSync(process.execPath, [runnerPath, '--input', 'unapproved.json'], {stdio:'pipe'}), /Command failed/);
});

test('repeated runner preserves content artifacts, separates execution audit, and does not mutate fixture', () => {
  const fixtureBefore = fs.readFileSync(fixturePath);
  const first = JSON.parse(execFileSync(process.execPath, [runnerPath], {encoding:'utf8'}));
  const datasetPath = path.join(first.directory, 'dataset.json');
  const manifestPath = path.join(first.directory, 'manifest.json');
  const datasetBefore = fs.readFileSync(datasetPath);
  const manifestBefore = fs.readFileSync(manifestPath);
  const auditBefore = new Set(fs.readdirSync(first.directory).filter(name => name.startsWith('audit-')));
  const second = JSON.parse(execFileSync(process.execPath, [runnerPath], {encoding:'utf8'}));
  assert.equal(second.contentHash, first.contentHash);
  assert.equal(second.directory, first.directory);
  assert.equal(digest(fs.readFileSync(datasetPath)), digest(datasetBefore));
  assert.equal(digest(fs.readFileSync(manifestPath)), digest(manifestBefore));
  assert.equal(digest(fs.readFileSync(fixturePath)), digest(fixtureBefore));
  const newAuditNames = fs.readdirSync(first.directory).filter(name => name.startsWith('audit-') && !auditBefore.has(name));
  assert.equal(newAuditNames.length, 1);
  const audit = JSON.parse(fs.readFileSync(path.join(first.directory, newAuditNames[0]), 'utf8'));
  const dataset = JSON.parse(datasetBefore.toString('utf8'));
  assert.equal(audit.synthetic_only, true);
  assert.equal(audit.reproducibleContentHash, dataset.manifest.contentHash);
  assert.equal(audit.code.sha256, dataset.manifest.codeIdentity);
  assert.match(audit.code.nodeVersion, /^v\d+/);
  assert.match(audit.code.typescriptVersion, /^\d+/);
  assert.ok(audit.code.sources.some(file => file.path.endsWith('functions/src/health/dateKey.ts')));
  assert.ok(audit.code.sources.some(file => file.path.endsWith('functions/src/careActions/careActionCatalog.generated.ts')));
  assert.ok(!Object.hasOwn(dataset, 'executedAt'));
  assert.ok(!Object.hasOwn(dataset.manifest, 'executedAt'));
  assert.equal(audit.productionConnections, false);
});
