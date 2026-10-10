'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const { before, after, test } = require('node:test');
// An existing installation of the same SDK versions may be selected without
// copying, reinstalling, or changing this working tree's dependencies.
const sdkRequire = process.env.HAMCARE_RULES_TEST_DEPENDENCY_PACKAGE
  ? createRequire(process.env.HAMCARE_RULES_TEST_DEPENDENCY_PACKAGE) : require;
const { initializeTestEnvironment, assertFails, assertSucceeds } = sdkRequire('@firebase/rules-unit-testing');
const { collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc } = sdkRequire('firebase/firestore');

// Never fall back to the production service or another developer's emulator.
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(emulatorHost ?? '', /^127\.0\.0\.1:\d+$/, 'A dedicated loopback Firestore emulator is required');
const emulatorPort = Number(emulatorHost.split(':')[1]);
assert.notEqual(emulatorPort, 8080, 'Do not use the existing shared emulator');
const PROJECT_ID = 'demo-hamcare-personality-rules';
const ROOT = path.resolve(__dirname, '../..');
const OWNER_STATES = ['paid', 'trial', 'expired', 'unpaid'];
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1', port: emulatorPort,
      rules: fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8'),
    },
  });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of OWNER_STATES) {
      await setDoc(doc(db, `users/${uid}/personality_reports/existing`), { status: 'generated', snapshot: { body: true } });
      await setDoc(doc(db, `users/${uid}/report_pointers/personality`), { reportId: 'existing' });
      for (const kind of ['weight_records', 'daily_checkins', 'distance_records']) {
        await setDoc(doc(db, `users/${uid}/${kind}/existing`), { dayKey: '2026-10-08' });
      }
    }
    await setDoc(doc(db, 'users/paid/billing/subscription'), { plan: 'paid', status: 'active', currentPeriodEnd: new Date(Date.now() + 86400000) });
    await setDoc(doc(db, 'users/trial/feature_access/initial_trial_v2'), { status: 'active', endsAt: new Date(Date.now() + 86400000) });
    await setDoc(doc(db, 'users/expired/feature_access/initial_trial_v2'), { status: 'active', endsAt: new Date(Date.now() - 86400000) });
    await setDoc(doc(db, 'reference_cohorts/example'), { currentVersion: 'v1' });
    await setDoc(doc(db, 'reference_cohorts/example/versions/v1'), { sampleCount: 10 });
    await setDoc(doc(db, 'users/paid/report_pointers/unknown'), { reportId: 'existing' });
    await setDoc(doc(db, 'users/paid/personality_reports/existing/private/detail'), { serverOnly: true });
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

function client(uid) {
  return uid ? testEnv.authenticatedContext(uid).firestore() : testEnv.unauthenticatedContext().firestore();
}

for (const uid of OWNER_STATES) {
  test(`${uid} owner can read the saved report regardless of entitlement expiry`, async () => {
    await assertSucceeds(getDoc(doc(client(uid), `users/${uid}/personality_reports/existing`)));
    await assertSucceeds(getDocs(collection(client(uid), `users/${uid}/personality_reports`)));
  });
  test(`${uid} owner can read the personality report pointer`, () =>
    assertSucceeds(getDoc(doc(client(uid), `users/${uid}/report_pointers/personality`))));

  for (const actor of [uid, 'another-user', null]) {
    const actorName = actor ?? 'guest';
    for (const resource of ['report', 'pointer']) {
      test(`${actorName} cannot create/update/delete ${uid}'s ${resource}`, async () => {
        const db = client(actor);
        const existingPath = resource === 'report'
          ? `users/${uid}/personality_reports/existing`
          : `users/${uid}/report_pointers/personality`;
        const newPath = resource === 'report'
          ? `users/${uid}/personality_reports/new-report`
          : `users/${uid}-absent/report_pointers/personality`;
        await assertFails(setDoc(doc(db, newPath), { reportId: 'forged' }));
        if (resource === 'pointer' && actor === uid) {
          await assertFails(setDoc(doc(client(`${uid}-absent`), newPath), { reportId: 'forged' }));
        }
        await assertFails(setDoc(doc(db, existingPath), { reportId: 'forged' }, { merge: true }));
        await assertFails(updateDoc(doc(db, existingPath), { reportId: 'forged' }));
        await assertFails(deleteDoc(doc(db, existingPath)));
      });
    }
  }
  for (const actor of ['another-user', null]) {
    test(`${actor ?? 'guest'} cannot read or list ${uid}'s reports or read its pointer`, async () => {
      const db = client(actor);
      await assertFails(getDoc(doc(db, `users/${uid}/personality_reports/existing`)));
      await assertFails(getDocs(collection(db, `users/${uid}/personality_reports`)));
      await assertFails(getDoc(doc(db, `users/${uid}/report_pointers/personality`)));
    });
  }
}

for (const actor of ['paid', 'trial', 'expired', 'unpaid', null]) {
  test(`${actor ?? 'guest'} has no client access to reference cohort roots or versions`, async () => {
    const db = client(actor);
    for (const root of ['reference_cohorts', 'reference_cohorts/example/versions']) {
      const id = root === 'reference_cohorts' ? 'example' : 'v1';
      await assertFails(getDoc(doc(db, `${root}/${id}`)));
      await assertFails(getDocs(collection(db, root)));
      await assertFails(setDoc(doc(db, `${root}/new`), { sampleCount: 1 }));
      await assertFails(updateDoc(doc(db, `${root}/${id}`), { sampleCount: 1 }));
      await assertFails(deleteDoc(doc(db, `${root}/${id}`)));
    }
  });
}

test('new owner read grants do not expose other pointers or report descendants', async () => {
  const db = client('paid');
  await assertFails(getDoc(doc(db, 'users/paid/report_pointers/unknown')));
  await assertFails(setDoc(doc(db, 'users/paid/report_pointers/unknown'), { reportId: 'forged' }));
  await assertFails(getDoc(doc(db, 'users/paid/personality_reports/existing/private/detail')));
  await assertFails(setDoc(doc(db, 'users/paid/personality_reports/existing/private/detail'), { serverOnly: false }));
});

for (const uid of OWNER_STATES) {
  for (const kind of ['weight_records', 'daily_checkins', 'distance_records']) {
    test(`${uid} existing ${kind} create/update entitlement is preserved`, async () => {
      const db = client(uid);
      const operation = (uid === 'paid' || uid === 'trial') ? assertSucceeds : assertFails;
      await operation(setDoc(doc(db, `users/${uid}/${kind}/new`), { dayKey: '2026-10-08' }));
      await operation(updateDoc(doc(db, `users/${uid}/${kind}/existing`), { updated: true }));
    });
  }
}
