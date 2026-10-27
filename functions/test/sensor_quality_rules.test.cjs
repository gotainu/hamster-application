'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {before, after, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, collectionGroup, getDoc, getDocs, setDoc, updateDoc, deleteDoc, Timestamp} = require('firebase/firestore');

const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^127\.0\.0\.1:\d+$/, 'A dedicated loopback Firestore Emulator is required');
assert.notEqual(host, '127.0.0.1:8080', 'Do not use a possibly shared application Emulator');
const projectId = 'demo-hamcare-sensor-quality-rules';
const owner = 'sensor-owner';
const internalCollections = ['sensor_acquisition_attempts', 'sensor_polling_state', 'sensor_quality_snapshots'];
const paths = internalCollections.flatMap(name => [
  `users/${owner}/${name}/existing`,
  `users/${owner}/${name}/existing/private/detail`,
]);
let env;
const client = actor => actor ? env.authenticatedContext(actor).firestore() : env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: Number(host.split(':')[1]), rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const p of paths) await setDoc(doc(db, p), {ownerUid: owner, acceptedAt: Timestamp.now(), result: 'confirmed'});
    await setDoc(doc(db, `users/${owner}`), {has_subcollections: true});
    await setDoc(doc(db, `users/${owner}/billing/subscription`), {plan: 'paid', status: 'active'});
    await setDoc(doc(db, `users/${owner}/switchbot_readings/2026-10-15T15:14:04.000Z`), {ts: '2026-10-15T15:14:04.000Z', temperature: 22, humidity: 50, source: 'status'});
    await setDoc(doc(db, `users/${owner}/integrations/switchbot`), {meterDeviceId: 'registered-device', enabled: true, hasSecrets: true});
  });
});
after(async () => {if (env) await env.cleanup();});

for (const actor of [owner, 'other-owner', null]) {
  test(`${actor ?? 'anonymous'} cannot read/list or create/update/delete internal sensor evidence or quality`, async () => {
    const db = client(actor);
    for (const p of paths) {
      const ref = doc(db, p);
      await assertFails(getDoc(ref));
      await assertFails(setDoc(doc(db, `${p}-new`), {acceptedAt: Timestamp.now(), result: 'confirmed'}));
      await assertFails(setDoc(ref, {acceptedAt: Timestamp.now(), result: 'forged'}));
      await assertFails(updateDoc(ref, {acceptedAt: Timestamp.now(), result: 'forged'}));
      await assertFails(deleteDoc(ref));
    }
    for (const name of internalCollections) {
      await assertFails(getDocs(collection(db, `users/${owner}/${name}`)));
      await assertFails(getDocs(collection(db, `users/${owner}/${name}/existing/private`)));
      await assertFails(getDocs(collectionGroup(db, name)));
    }
  });
}

test('existing owner root and raw reading access do not grant recursive evidence access', async () => {
  const db = client(owner);
  await assertSucceeds(getDoc(doc(db, `users/${owner}`)));
  const reading = doc(db, `users/${owner}/switchbot_readings/2026-10-15T15:14:04.000Z`);
  await assertSucceeds(getDoc(reading));
  await assertSucceeds(getDocs(collection(db, `users/${owner}/switchbot_readings`)));
  await assertFails(updateDoc(reading, {temperature: 0}));
  await assertFails(getDoc(doc(client('other-owner'), reading.path)));
});

test('existing device metadata selection remains limited; clients cannot forge server polling state', async () => {
  const db = client(owner);
  const integration = doc(db, `users/${owner}/integrations/switchbot`);
  await assertSucceeds(updateDoc(integration, {meterDeviceId: 'replacement-device', meterDeviceName: 'Meter', meterDeviceType: 'Meter', updatedAt: Timestamp.now()}));
  await assertFails(updateDoc(integration, {enabled: false}));
  await assertFails(updateDoc(integration, {hasSecrets: false}));
  await assertFails(updateDoc(integration, {sensorCaptureBlockedForDeletion: false}));
  await assertFails(updateDoc(integration, {sensorCaptureBlockedForDeletion: true}));
  await assertFails(setDoc(doc(db, `users/${owner}/sensor_polling_state/current`), {eligibleSince: Timestamp.now()}));
});
