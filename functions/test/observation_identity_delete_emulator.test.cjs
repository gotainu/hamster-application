'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {before, after, test} = require('node:test');
const ts = require('typescript');
const admin = require('firebase-admin');

assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated loopback emulator required');
assert.notEqual(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
let app, db;
before(() => {
  app = admin.initializeApp({projectId: 'demo-hamcare-observation-account-delete'}, 'observation-account-delete');
  db = app.firestore();
});
after(async () => {if (app) await app.delete();});

test('the existing authenticated account-deletion tree walk removes persisted identity, ledger, events, revisions and receipts', async () => {
  const uid = 'observation-deleted-account', kept = 'observation-kept-account';
  const paths = [
    'pet_profiles/main_pet', 'pet_profiles/main_pet/mutations/profile-save',
    'pet_subjects/subject-1',
    'daily_checkins/2026-10-13',
    'observation_days/2026-10-13',
    'observation_days/2026-10-13/events/event-1',
    'observation_days/2026-10-13/revisions/0000000001',
    'observation_days/2026-10-13/mutations/checkin-save',
  ];
  await db.doc(`users/${uid}`).set({has_subcollections: true});
  for (const p of paths) {
    await db.doc(`users/${uid}/${p}`).set({ownerUid: uid, subjectId: 'subject-1'});
    await db.doc(`users/${kept}/${p}`).set({ownerUid: kept, subjectId: 'subject-1'});
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
    assert.equal((await db.doc(`users/${kept}/${p}`).get()).exists, true, `preserved ${p}`);
  }
});
