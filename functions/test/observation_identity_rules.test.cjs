'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {before, after, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, collectionGroup, getDoc, getDocs, setDoc, updateDoc, deleteDoc, Timestamp} = require('firebase/firestore');

assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated loopback emulator required');
const port = Number(process.env.FIRESTORE_EMULATOR_HOST.split(':')[1]);
assert.notEqual(port, 8080, 'Do not use a shared default emulator');
const states = ['paid', 'trial', 'expired', 'unpaid'];
const day = '2026-10-13';
let env;
const protectedPaths = uid => [
  `users/${uid}/pet_profiles/main_pet`,
  `users/${uid}/pet_profiles/main_pet/mutations/profile-mutation-0001`,
  `users/${uid}/pet_subjects/subject-server-0001`,
  `users/${uid}/daily_checkins/${day}`,
  `users/${uid}/observation_days/${day}`,
  `users/${uid}/observation_days/${day}/events/observation-original-0001`,
  `users/${uid}/observation_days/${day}/revisions/0000000001`,
  `users/${uid}/observation_days/${day}/mutations/observation-mutation-0001`,
];
const readableCollections = uid => [
  `users/${uid}/pet_profiles`,
  `users/${uid}/pet_profiles/main_pet/mutations`,
  `users/${uid}/pet_subjects`,
  `users/${uid}/daily_checkins`,
  `users/${uid}/observation_days`,
  ...['events', 'revisions', 'mutations'].map(c => `users/${uid}/observation_days/${day}/${c}`),
];
const client = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hamcare-observation-identity-rules',
    firestore: {host: '127.0.0.1', port, rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')},
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const uid of states) {
      for (const p of protectedPaths(uid)) await setDoc(doc(db, p), {
        ownerUid: uid, subjectId: 'subject-server-0001', revision: 1,
        acceptedAt: Timestamp.fromDate(new Date('2026-10-13T04:05:00Z')),
      });
      for (const c of ['weight_records', 'distance_records']) await setDoc(doc(db, `users/${uid}/${c}/existing`), {dayKey: day});
      await setDoc(doc(db, `users/${uid}/personalized_reports/first`), {generation: {status: 'generated'}});
      await setDoc(doc(db, `users/${uid}/daily_care_actions/${day}`), {revision: 1});
      await setDoc(doc(db, `users/${uid}/breeding_environments/main_env`), {wheelDiameter: '20'});
      await setDoc(doc(db, `users/${uid}/rewards/stars`), {total: 8});
    }
    await setDoc(doc(db, 'users/paid/billing/subscription'), {plan: 'paid', status: 'active'});
    await setDoc(doc(db, 'users/trial/feature_access/initial_trial_v2'), {status: 'active', endsAt: Timestamp.fromMillis(Date.now() + 86400000)});
    await setDoc(doc(db, 'users/expired/feature_access/initial_trial_v2'), {status: 'active', endsAt: Timestamp.fromMillis(Date.now() - 86400000)});
  });
});
after(async () => { if (env) await env.cleanup(); });

for (const uid of states) {
  test(`${uid}: owner can read current profile, identity, observations and history after entitlement expiry`, async () => {
    for (const p of protectedPaths(uid)) await assertSucceeds(getDoc(doc(client(uid), p)));
    for (const p of readableCollections(uid)) await assertSucceeds(getDocs(collection(client(uid), p)));
  });
  for (const actor of [uid, 'other', null]) {
    test(`${actor ?? 'anonymous'} cannot bypass atomic saves or forge ${uid}'s identity/receipt/history`, async () => {
      for (const p of protectedPaths(uid)) {
        const ref = doc(client(actor), p);
        await assertFails(updateDoc(ref, {subjectId: 'replacement', acceptedAt: Timestamp.now(), revision: 999}));
        await assertFails(setDoc(ref, {ownerUid: actor, subjectId: 'replacement'}));
        await assertFails(deleteDoc(ref));
        await assertFails(setDoc(doc(client(actor), `${p}_new`), {ownerUid: uid, subjectId: 'forged'}));
      }
    });
  }
  for (const actor of ['other', null]) {
    test(`${actor ?? 'anonymous'} cannot read ${uid}'s current/history/identity`, async () => {
      for (const p of protectedPaths(uid)) await assertFails(getDoc(doc(client(actor), p)));
      for (const p of readableCollections(uid)) await assertFails(getDocs(collection(client(actor), p)));
    });
  }
  test(`${uid}: settings retain permissions; all accepted records use server saves`, async () => {
    const db = client(uid);
    for (const c of ['weight_records', 'distance_records']) {
      const assertion = assertFails;
      await assertion(setDoc(doc(db, `users/${uid}/${c}/new`), {dayKey: day}));
      await assertion(updateDoc(doc(db, `users/${uid}/${c}/existing`), {memo: 'updated'}));
      await assertFails(deleteDoc(doc(db, `users/${uid}/${c}/existing`)));
    }
    await assertSucceeds(setDoc(doc(db, `users/${uid}/owner_profiles/main`), {displayName: 'owner'}));
    await assertSucceeds(setDoc(doc(db, `users/${uid}/app_state/onboarding`), {firstAiConsultationCompleted: true}));
    for (const p of ['personalized_reports/first', `daily_care_actions/${day}`, 'breeding_environments/main_env', 'rewards/stars']) {
      await assertSucceeds(getDoc(doc(db, `users/${uid}/${p}`)));
      await assertFails(updateDoc(doc(db, `users/${uid}/${p}`), {tampered: true}));
    }
  });
}

test('specific read grants never expose arbitrary descendants or another profile receipt', async () => {
  const db = client('paid');
  for (const p of [
    'users/paid/pet_profiles/other_pet/mutations/private',
    'users/paid/pet_profiles/main_pet/private/secret',
    'users/paid/pet_subjects/subject-server-0001/private/secret',
    `users/paid/daily_checkins/${day}/events/private`,
    `users/paid/observation_days/${day}/private/secret`,
    ...['events', 'revisions', 'mutations'].map(c => `users/paid/observation_days/${day}/${c}/record/private/secret`),
  ]) {
    await assertFails(getDoc(doc(db, p)));
    await assertFails(setDoc(doc(db, p), {ownerUid: 'paid'}));
  }
});

test('owner read grants do not authorize cross-user collection-group discovery', async () => {
  for (const c of ['pet_subjects', 'observation_days', 'events', 'revisions', 'mutations']) {
    await assertFails(getDocs(collectionGroup(client('paid'), c)));
  }
});
