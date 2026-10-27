'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test, after} = require('node:test');
const ts = require('typescript');
const admin = require('firebase-admin');
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/);
assert.notEqual(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
const app = admin.initializeApp({projectId: 'demo-hamcare-measurement-profile-delete'}, 'measurement-profile-delete');
const db = app.firestore();
after(async () => {await db.terminate(); await app.delete();});
test('existing legitimate recursive account deletion removes measurements, revisions, routes, receipts and nested attributes while preserving another owner', async () => {
  const uid = 'deleted-measurement-owner', other = 'kept-measurement-owner';
  const paths = [
    ...['weight', 'distance'].flatMap(kind => [`${kind}_records/2026-10-13`, `${kind}_record_history/record-1`, `${kind}_record_history/record-1/revisions/0000000001`, `${kind}_record_days/2026-10-13`, `${kind}_record_days/2026-10-13/revisions/0000000001`, `${kind}_record_mutations/mutation-1`]),
    'pet_profiles/main_pet', 'pet_profiles/main_pet/mutations/profile-save', 'pet_subjects/subject-1', 'pet_subjects/subject-1/profile_history/main_profile', 'pet_subjects/subject-1/profile_history/main_profile/revisions/0000000001',
  ];
  for (const owner of [uid, other]) {
    await db.doc(`users/${owner}`).set({has_subcollections: true});
    for (const p of paths) await db.doc(`users/${owner}/${p}`).set({ownerUid: owner, subjectId: 'subject-1'});
  }
  const source = fs.readFileSync(path.resolve(__dirname, '../src/index.ts'), 'utf8');
  assert.match(source, /deleteDocumentDeep\(db\.collection\('users'\)\.doc\(uid\)/);
  const start = source.indexOf('function createDeepDeleteStats()'), end = source.indexOf('function mean(', start);
  assert.ok(start >= 0 && end > start);
  const code = ts.transpileModule(source.slice(start, end), {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}}).outputText;
  const api = vm.runInThisContext(`(function(db){${code}\nreturn {deleteDocumentDeep,createDeepDeleteStats};})`)(db);
  await api.deleteDocumentDeep(db.doc(`users/${uid}`), api.createDeepDeleteStats());
  assert.equal((await db.doc(`users/${uid}`).get()).exists, false);
  for (const p of paths) {
    assert.equal((await db.doc(`users/${uid}/${p}`).get()).exists, false, `deleted ${p}`);
    assert.equal((await db.doc(`users/${other}/${p}`).get()).exists, true, `preserved ${p}`);
  }
});
