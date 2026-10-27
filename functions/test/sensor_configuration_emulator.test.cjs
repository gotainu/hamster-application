'use strict';

const assert = require('node:assert/strict');
const {before, after, test} = require('node:test');
const admin = require('firebase-admin');
const {loadStarSource} = require('./support/star_source_loader.cjs');

const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^127\.0\.0\.1:\d+$/, 'A dedicated loopback Firestore Emulator is required');
assert.notEqual(host, '127.0.0.1:8080');
const projectId = 'demo-hamcare-sensor-configuration';
let app, db;
before(() => {
  app = admin.initializeApp({projectId}, `sensor-configuration-${process.pid}`);
  db = app.firestore();
});
after(async () => {if (db) await db.terminate(); if (app) await app.delete();});

const snapshot = async ref => {
  const value = await ref.get();
  return {data: JSON.stringify(value.data()), updateTime: value.updateTime?.toDate().toISOString(), nanos: value.updateTime?.nanoseconds};
};

test('configuration trigger retains immutable transitions across parallel retries, out-of-order device changes and metadata no-ops', async () => {
  const uid = `sensor-configuration-owner-${process.pid}`;
  const configRef = db.doc(`users/${uid}/integrations/switchbot`);
  const states = db.collection(`users/${uid}/sensor_polling_state`);
  const protectedPaths = [
    'daily_health_features/2026-10-16', 'environment_assessments/latest',
    'health_assessments/latest', 'analysis_readiness/body',
    'personalized_reports/first', 'personality_reports/daily_2026-10-15',
    'rewards/continuity', 'billing/subscription',
  ];
  for (const p of protectedPaths) await db.doc(`users/${uid}/${p}`).set({preserved: true});
  const protectedBefore = await Promise.all(protectedPaths.map(p => snapshot(db.doc(`users/${uid}/${p}`))));

  const missing = await configRef.get();
  const secret = 'credential-sentinel-never-copy';
  const a = {meterDeviceId: 'meter-a', enabled: true, hasSecrets: true, token: secret, meterDeviceName: 'ignored name'};
  const b = {...a, meterDeviceId: 'meter-b'};
  const c = {...a, meterDeviceId: 'meter-c'};
  await configRef.set(a); const sourceA = await configRef.get();
  await configRef.set(b); const sourceB = await configRef.get();
  await configRef.set(c); const sourceC = await configRef.get();
  const event = (before, after) => ({params: {uid}, data: {before, after}, time: after.updateTime.toDate().toISOString()});
  const events = [event(missing, sourceA), event(sourceA, sourceB), event(sourceB, sourceC)];

  // Preserve actual Emulator transactions and their retry/locking behavior.
  // The wrapper only refuses unexpected namespaces; it does not serialize work.
  const touched = [];
  const guardedDb = {
    doc(p) {assert.ok(p === configRef.path || p.startsWith(`users/${uid}/sensor_polling_state/`), `Unexpected configuration access: ${p}`); touched.push(p); return db.doc(p);},
    runTransaction: fn => db.runTransaction(fn),
  };
  const firestore = () => guardedDb;
  firestore.FieldValue = admin.firestore.FieldValue;
  firestore.Timestamp = admin.firestore.Timestamp;
  const api = loadStarSource({admin: {firestore}})('sensorQuality/configuration');
  const handler = api.sensorPollingConfigurationWritten;
  assert.equal(handler.__triggerOptions.document, 'users/{uid}/integrations/switchbot');
  assert.equal(handler.__triggerOptions.region, 'asia-northeast1');

  // Newest delivery arrives first; duplicates and older events overlap.
  await Promise.all([events[2], events[0], events[2], events[1], events[0], events[1], events[2]].map(e => handler(e)));
  const recorded = await states.get();
  assert.equal(recorded.size, 3);
  const byDevice = new Map(recorded.docs.map(doc => [doc.get('config.deviceId'), doc]));
  for (const [device, source] of [['meter-a', sourceA], ['meter-b', sourceB], ['meter-c', sourceC]]) {
    const row = byDevice.get(device);
    assert.ok(row, `Missing transition for ${device}`);
    assert.ok(row.get('sourceUpdatedAt').isEqual(source.updateTime));
    assert.ok(row.get('acceptedAt') instanceof admin.firestore.Timestamp);
    assert.equal(row.get('acceptedAt').isEqual(row.get('sourceUpdatedAt')), false);
    assert.equal(row.get('eligibility'), 'unknown');
    assert.equal(row.get('continuity'), 'transition_only');
    assert.equal(row.get('subjectAssociation'), 'unknown');
    assert.equal(row.get('policy.slotAnchor'), null);
    assert.equal(JSON.stringify(row.data()).includes(secret), false);
    assert.equal(JSON.stringify(row.data()).includes('ignored name'), false);
  }
  assert.equal(byDevice.get('meter-a').get('previousConfig.deviceId'), null);
  assert.equal(byDevice.get('meter-b').get('previousConfig.deviceId'), 'meter-a');
  assert.equal(byDevice.get('meter-c').get('previousConfig.deviceId'), 'meter-b');
  const beforeReplay = await Promise.all(recorded.docs.map(doc => snapshot(doc.ref)));
  await Promise.all(events.map(e => handler(e)));
  assert.deepEqual(await Promise.all(recorded.docs.map(doc => snapshot(doc.ref))), beforeReplay);

  await configRef.update({meterDeviceName: 'renamed', updatedAt: admin.firestore.FieldValue.serverTimestamp()});
  const metadataOnly = await configRef.get();
  await handler(event(sourceC, metadataOnly));
  assert.equal((await states.get()).size, 3, 'Metadata-only save must not create a configuration transition');
  assert.deepEqual(await Promise.all(recorded.docs.map(doc => snapshot(doc.ref))), beforeReplay);

  // A version reused for different content must fail explicitly; prior evidence
  // and current configuration stay intact after the rejected delivery.
  const forgedAfter = {exists: true, data: () => ({...c, meterDeviceId: 'conflicting-meter'}), ref: configRef, updateTime: sourceC.updateTime};
  await assert.rejects(handler(event(sourceB, forgedAfter)), /configuration_evidence_collision/);
  assert.equal((await states.get()).size, 3);
  assert.deepEqual(await Promise.all(recorded.docs.map(doc => snapshot(doc.ref))), beforeReplay);
  assert.equal((await configRef.get()).get('meterDeviceId'), 'meter-c');
  assert.ok(touched.length > 3, 'Parallel duplicate paths must exercise transactional replay');
  assert.deepEqual(await Promise.all(protectedPaths.map(p => snapshot(db.doc(`users/${uid}/${p}`)))), protectedBefore);
  assert.equal((await db.collection(`users/${uid}/switchbot_readings`).get()).size, 0, 'Configuration tracking does not poll or create readings');
});

test('physical configuration deletion and delayed duplicate events do not create polling state', async () => {
  const uid = `sensor-configuration-delete-${process.pid}`;
  const configRef = db.doc(`users/${uid}/integrations/switchbot`);
  await configRef.set({meterDeviceId: 'meter-delete', enabled: true, hasSecrets: true});
  const before = await configRef.get();
  await configRef.delete();
  const after = await configRef.get();
  const firestore = () => db;
  firestore.FieldValue = admin.firestore.FieldValue;
  firestore.Timestamp = admin.firestore.Timestamp;
  const api = loadStarSource({admin: {firestore}})('sensorQuality/configuration');
  const sourceTime = '2026-10-15T20:12:34.567Z';
  const event = {params: {uid}, data: {before, after}, time: sourceTime};
  await Promise.all([api.sensorPollingConfigurationWritten(event), api.sensorPollingConfigurationWritten(event)]);
  const rows = await db.collection(`users/${uid}/sensor_polling_state`).get();
  assert.equal(rows.size, 0, 'Physical deletion must not create evidence after account cleanup');
  await api.sensorPollingConfigurationWritten(event);
  assert.equal((await db.collection(`users/${uid}/sensor_polling_state`).get()).size, 0);
  assert.equal((await db.doc(`users/${uid}`).get()).exists, false);
});
