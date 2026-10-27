'use strict';

// The only file/clock boundary. No SDK, DB, HTTP, auth, or arbitrary input path.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {loadTypeScript, loadedSourceFiles, typescriptVersion} = require('./tools/load-typescript.cjs');
const ROOT = __dirname;
const REPOSITORY_ROOT = path.resolve(ROOT, '../..');
const FIXTURE = path.join(ROOT, 'fixtures/representative.json');
const POLICY = path.join(ROOT, 'fixtures/policy.json');

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function canonical(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}';
}

function assertSyntheticFixture(value) {
  if (!value || value.syntheticOnly !== true) throw new Error('syntheticOnly declaration is required');
  const visit = (item, key) => {
    if (typeof item === 'string') {
      if ((['id', 'ownerId', 'subjectId', 'revisionId', 'logicalId', 'sourceObservationId'].includes(key)) && !item.startsWith('synthetic_')) {
        throw new Error('Fixture identifiers must use the synthetic_ namespace');
      }
      if (/^\d{4}-\d\d-\d\d(?:T|$)/.test(item) && !item.startsWith('2030-')) {
        throw new Error('Representative fixture dates must use the invented 2030 period');
      }
    } else if (Array.isArray(item)) {
      item.forEach(child => visit(child, key));
    } else if (item && typeof item === 'object') {
      Object.entries(item).forEach(([childKey, child]) => visit(child, childKey));
    }
  };
  visit(value, '');
}

function recursivelyList(directory, extension) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const filename = path.join(directory, entry.name);
    return entry.isDirectory() ? recursivelyList(filename, extension) : filename.endsWith(extension) ? [filename] : [];
  });
}

function codeIdentity() {
  const files = [...new Set([
    ...recursivelyList(path.join(ROOT, 'src'), '.ts'),
    ...loadedSourceFiles(),
    __filename,
    path.join(ROOT, 'tools/load-typescript.cjs'),
  ])].sort();
  const sources = files.map(filename => ({
    path: path.relative(REPOSITORY_ROOT, filename).split(path.sep).join('/'),
    sha256: sha256(fs.readFileSync(filename)),
  }));
  const nodeVersion = process.version;
  return {sha256: sha256(canonical({sources, typescriptVersion, nodeVersion})), sources, typescriptVersion, nodeVersion};
}

function createImmutable(filename, bytes) {
  try {
    fs.writeFileSync(filename, bytes, {encoding: 'utf8', flag: 'wx'});
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
    if (fs.readFileSync(filename, 'utf8') !== bytes) throw new Error('Existing generated artifact differs; refusing overwrite');
  }
}

// run() is intentionally defined after the pure generator's contract is fixed.
function run() {
  if (process.argv.length !== 2) throw new Error('This runner accepts no arguments; only the checked-in synthetic fixture is supported');
  const fixtureBytes = fs.readFileSync(FIXTURE);
  const policyBytes = fs.readFileSync(POLICY);
  const fixture = JSON.parse(fixtureBytes.toString('utf8'));
  const policy = JSON.parse(policyBytes.toString('utf8'));
  assertSyntheticFixture(fixture);
  const api = loadTypeScript(path.join(ROOT, 'src/generate.ts'));
  const identity = codeIdentity();
  const result = api.generateDataset(fixture, policy, identity.sha256);
  const contentHash = result.manifest.contentHash;
  if (!/^[a-f0-9]{64}$/.test(contentHash)) throw new Error('Generator did not return a deterministic content hash');
  const directory = path.join(ROOT, 'output', contentHash);
  fs.mkdirSync(directory, {recursive: true});
  createImmutable(path.join(directory, 'dataset.json'), JSON.stringify(result, null, 2) + '\n');
  createImmutable(path.join(directory, 'manifest.json'), JSON.stringify(result.manifest, null, 2) + '\n');
  const executedAt = new Date().toISOString();
  const audit = {
    synthetic_only: true,
    executedAt,
    fixtureFileSha256: sha256(fixtureBytes),
    policyFileSha256: sha256(policyBytes),
    code: identity,
    reproducibleContentHash: contentHash,
    productionConnections: false,
  };
  const auditName = `audit-${executedAt.replace(/[:.]/g, '-')}-${process.pid}-${process.hrtime.bigint()}.json`;
  createImmutable(path.join(directory, auditName), JSON.stringify(audit, null, 2) + '\n');
  process.stdout.write(JSON.stringify({synthetic_only: true, contentHash, directory, manifest: result.manifest}, null, 2) + '\n');
  return {result, audit, directory};
}

if (require.main === module) run();
module.exports = {run, assertSyntheticFixture, codeIdentity, canonical};
