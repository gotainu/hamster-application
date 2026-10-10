#!/usr/bin/env node
'use strict';
// No arguments => offline JSON preview; Firebase is loaded only after explicit
// --write passes both local emulator and demo-project guards.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
let referenceModule;
function references() {
  if (referenceModule) return referenceModule;
  const ts = require('typescript');
  const filename = path.resolve(__dirname, '../src/health/referenceCohorts.ts');
  const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: filename, reportDiagnostics: true,
    compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS},
  });
  if ((compiled.diagnostics || []).some(d => d.category === ts.DiagnosticCategory.Error)) throw new Error('Reference source cannot be transpiled');
  const module = {exports: {}};
  const execute = vm.runInThisContext(`(function(exports, require, module) {\n${compiled.outputText}\n})`, {filename});
  execute(module.exports, name => {throw new Error('Unexpected reference dependency: ' + name);}, module);
  referenceModule = module.exports;
  return referenceModule;
}
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value !== null && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, stable(value[k])]));
  return value;
}
const canonical = value => JSON.stringify(stable(value));
function buildSeedPlan() {
  const {REFERENCE_COHORTS, REFERENCE_COHORT_VERSION} = references();
  return {
    mode: 'dry_run', offline: true, referenceVersion: REFERENCE_COHORT_VERSION,
    pointers: REFERENCE_COHORTS.map(c => ({
      path: `reference_cohorts/${c.cohortId}`,
      data: {cohortId: c.cohortId, speciesCode: c.speciesCode, metric: c.metric, unit: c.unit,
        sourceType: c.sourceType, currentReferenceVersion: c.referenceVersion},
    })),
    documents: REFERENCE_COHORTS.map(c => ({id: c.cohortId,
      path: `reference_cohorts/${c.cohortId}/versions/${c.referenceVersion}`,
      data: JSON.parse(JSON.stringify(c)),
    })),
  };
}
function validateWriteTarget({projectId, emulatorHost}) {
  if (typeof projectId !== 'string' || !/^demo-[a-z0-9][a-z0-9-]*$/.test(projectId)) throw new Error('Writes require an explicit demo- project; production projects are prohibited');
  if (typeof emulatorHost !== 'string' || !/^(localhost|127\.0\.0\.1|\[::1\]):[0-9]+$/.test(emulatorHost)) throw new Error('Writes require FIRESTORE_EMULATOR_HOST on localhost with a port');
  const port = Number(emulatorHost.slice(emulatorHost.lastIndexOf(':') + 1));
  if (port < 1 || port > 65535) throw new Error('Invalid local emulator port');
}
async function seedReferenceCohorts(db, plan, target) {
  validateWriteTarget(target);
  if (db.projectId !== target.projectId) throw new Error('Firestore project does not match the guarded demo project');
  if (canonical(plan) !== canonical(buildSeedPlan())) throw new Error('Immutable seed plan differs from the published version');
  const entries = [...plan.pointers, ...plan.documents];
  const refs = entries.map(e => db.doc(e.path));
  return db.runTransaction(async tx => {
    const snapshots = await Promise.all(refs.map(ref => tx.get(ref)));
    // All existing versions and pointers are checked before scheduling writes.
    for (let i = 0; i < entries.length; i++) {
      if (snapshots[i].exists && canonical(snapshots[i].data()) !== canonical(entries[i].data)) {
        throw new Error('Immutable reference version/current pointer conflict: ' + entries[i].path);
      }
    }
    let created = 0;
    for (let i = 0; i < entries.length; i++) {
      if (!snapshots[i].exists) {tx.create(refs[i], entries[i].data); created++;}
    }
    return {created, unchanged: entries.length - created, referenceVersion: plan.referenceVersion};
  });
}
async function main(argv = process.argv.slice(2), env = process.env) {
  let write = false; let dry = false; let projectId;
  for (const arg of argv) {
    if (arg === '--write') write = true;
    else if (arg === '--dry-run') dry = true;
    else if (arg.startsWith('--project=') && projectId === undefined) projectId = arg.slice('--project='.length);
    else throw new Error('Usage: seed_reference_cohorts.cjs [--dry-run] or --write --project=demo-<name>');
  }
  if (write && dry) throw new Error('Choose --write or --dry-run, not both');
  if (projectId !== undefined && !/^demo-[a-z0-9][a-z0-9-]*$/.test(projectId)) throw new Error('Only demo- projects are permitted');
  if (write) validateWriteTarget({projectId, emulatorHost: env.FIRESTORE_EMULATOR_HOST});
  const plan = buildSeedPlan();
  if (!write) {process.stdout.write(JSON.stringify(plan, null, 2) + '\n'); return;}
  const admin = require('firebase-admin');
  const app = admin.initializeApp({projectId}, 'reference-cohort-seed');
  try {
    const result = await seedReferenceCohorts(app.firestore(), plan, {projectId, emulatorHost: env.FIRESTORE_EMULATOR_HOST});
    process.stdout.write(JSON.stringify({mode: 'emulator_write', projectId, ...result}, null, 2) + '\n');
  } finally {await app.delete();}
}
module.exports = {buildSeedPlan, validateWriteTarget, seedReferenceCohorts};
if (require.main === module) main().catch(error => {process.stderr.write(error.message + '\n'); process.exitCode = 1;});
