'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test, after} = require('node:test');
const ts = require('typescript');
const admin = require('firebase-admin');
const {loadStarSource} = require('./support/star_source_loader.cjs');

assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/, 'A dedicated loopback Firestore Emulator is required');
assert.notEqual(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
const projectId = 'demo-hamcare-sensor-quality-delete';
const app = admin.initializeApp({projectId}, 'sensor-quality-account-delete');
const db = app.firestore();
after(async () => {await db.terminate(); await app.delete();});

test('existing legitimate account deletion removes sensor evidence, state and quality recursively without affecting another owner', async () => {
  const uid = 'deleted-sensor-owner', other = 'kept-sensor-owner';
  const paths = [
    'integrations/switchbot',
    'switchbot_readings/2026-10-15T15:14:04.000Z',
    'sensor_acquisition_attempts/attempt-1',
    'sensor_acquisition_attempts/attempt-1/outcomes/confirmed',
    'sensor_polling_state/state-1',
    'sensor_polling_state/state-1/revisions/revision-1',
    'sensor_quality_snapshots/quality-1',
    'sensor_quality_snapshots/quality-1/evidence/source-1',
  ];
  for (const owner of [uid, other]) {
    await db.doc(`users/${owner}`).set({has_subcollections: true});
    for (const p of paths) await db.doc(`users/${owner}/${p}`).set({ownerUid: owner, quality: 'confirmed'});
    await db.doc(`switchbot_users/${owner}`).set({hasSwitchbot: true});
  }
  const configRef = db.doc(`users/${uid}/integrations/switchbot`);
  await configRef.set({meterDeviceId: 'meter-before', enabled: true, hasSecrets: true});
  const configCreated = await configRef.get();
  await configRef.update({meterDeviceId: 'meter-after'});
  const configBefore = await configRef.get();
  const firestore = () => db;
  firestore.FieldValue = admin.firestore.FieldValue;
  firestore.Timestamp = admin.firestore.Timestamp;
  const configuration = loadStarSource({admin: {firestore}})('sensorQuality/configuration');
  const createdEvent = {params: {uid}, data: {before: {exists: false}, after: configCreated}, time: configCreated.updateTime.toDate().toISOString()};
  const updatedEvent = {params: {uid}, data: {before: configCreated, after: configBefore}, time: configBefore.updateTime.toDate().toISOString()};
  const stateRef = db.doc(`users/${uid}/sensor_polling_state/state-1`);
  const stateBefore = await stateRef.get();

  // The barrier is the same exported implementation called before legitimate
  // account cleanup. It is not a new state document under a missing account.
  await configuration.blockSensorCaptureForDeletion(db, uid);
  assert.equal((await configRef.get()).get('sensorCaptureBlockedForDeletion'), true);
  await Promise.all([
    configuration.sensorPollingConfigurationWritten(createdEvent),
    configuration.sensorPollingConfigurationWritten(updatedEvent),
  ]);
  assert.equal((await db.collection(`users/${uid}/sensor_polling_state`).get()).size, 1);
  const stateBlocked = await stateRef.get();
  assert.deepEqual(stateBlocked.data(), stateBefore.data());
  assert.ok(stateBlocked.updateTime.isEqual(stateBefore.updateTime));

  // Execute the same tree-walk helpers used by the authenticated deletion
  // callable, not a test-only deletion implementation or a production user.
  const source = fs.readFileSync(path.resolve(__dirname, '../src/index.ts'), 'utf8');
  assert.match(source, /deleteDocumentDeep\(db\.collection\('users'\)\.doc\(uid\)/);
  assert.match(source, /deleteDocumentDeep\(db\.collection\('switchbot_users'\)\.doc\(uid\)/);
  const deletionCallable = source.slice(source.indexOf('export const deleteMyAccountAndData'));
  assert.ok(deletionCallable.indexOf('blockSensorCaptureForDeletion(db, uid)') >= 0);
  assert.ok(deletionCallable.indexOf('blockSensorCaptureForDeletion(db, uid)') < deletionCallable.indexOf("deleteDocumentDeep(db.collection('users').doc(uid)"));
  const start = source.indexOf('function createDeepDeleteStats()');
  const end = source.indexOf('function mean(', start);
  assert.ok(start >= 0 && end > start);
  const code = ts.transpileModule(source.slice(start, end), {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}}).outputText;
  const api = vm.runInThisContext(`(function(db){${code}\nreturn {deleteDocumentDeep,createDeepDeleteStats};})`)(db);
  const stats = api.createDeepDeleteStats();
  await api.deleteDocumentDeep(db.doc(`users/${uid}`), stats);
  await api.deleteDocumentDeep(db.doc(`switchbot_users/${uid}`), stats);

  // A delete event may arrive after the complete user subtree has been removed.
  // It must not resurrect polling state or any other child of the deleted user.
  const configAfter = await configRef.get();
  const delayedDeleteEvent = {params: {uid}, data: {before: configBefore, after: configAfter}, time: '2026-10-16T01:00:00.000Z'};
  await Promise.all([
    configuration.sensorPollingConfigurationWritten(delayedDeleteEvent),
    configuration.sensorPollingConfigurationWritten(delayedDeleteEvent),
    configuration.sensorPollingConfigurationWritten(createdEvent),
    configuration.sensorPollingConfigurationWritten(updatedEvent),
  ]);
  await configuration.blockSensorCaptureForDeletion(db, uid);

  assert.equal((await db.doc(`users/${uid}`).get()).exists, false);
  assert.equal((await db.doc(`switchbot_users/${uid}`).get()).exists, false);
  assert.equal((await db.doc(`users/${other}`).get()).exists, true);
  assert.equal((await db.doc(`switchbot_users/${other}`).get()).exists, true);
  assert.equal((await db.collection(`users/${uid}/sensor_polling_state`).get()).size, 0);
  for (const p of paths) {
    assert.equal((await db.doc(`users/${uid}/${p}`).get()).exists, false, `deleted ${p}`);
    assert.equal((await db.doc(`users/${other}/${p}`).get()).exists, true, `preserved ${p}`);
  }
  assert.equal(stats.deletedDocuments, paths.length + 2);
});
