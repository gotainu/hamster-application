'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {before, after, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, collectionGroup, getDoc, getDocs, setDoc, updateDoc, deleteDoc, Timestamp} = require('firebase/firestore');
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^127\.0\.0\.1:\d+$/);
assert.notEqual(host, '127.0.0.1:8080');
let env;
const states = ['paid', 'trial', 'expired', 'unpaid'];
const day = '2026-10-13';
const paths = uid => [
  ...['weight', 'distance'].flatMap(kind => [
    `users/${uid}/${kind}_records/${day}`,
    `users/${uid}/${kind}_record_history/record-1`,
    `users/${uid}/${kind}_record_history/record-1/revisions/0000000001`,
    `users/${uid}/${kind}_record_days/${day}`,
    `users/${uid}/${kind}_record_days/${day}/revisions/0000000001`,
    `users/${uid}/${kind}_record_mutations/mutation-1`,
  ]),
  `users/${uid}/pet_subjects/subject-1/profile_history/main_profile`,
  `users/${uid}/pet_subjects/subject-1/profile_history/main_profile/revisions/0000000001`,
];
const client = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-hamcare-measurement-profile-rules', firestore: {host: '127.0.0.1', port: Number(host.split(':')[1]), rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    for (const uid of states) {
      for (const p of paths(uid)) await setDoc(doc(c.firestore(), p), {ownerUid: uid, subjectId: 'subject-1', revision: 1, acceptedAt: Timestamp.now()});
      await setDoc(doc(c.firestore(), `users/${uid}/pet_profiles/main_pet`), {subjectId: 'subject-1'});
    }
    await setDoc(doc(c.firestore(), 'users/paid/billing/subscription'), {plan: 'paid', status: 'active'});
    await setDoc(doc(c.firestore(), 'users/trial/feature_access/initial_trial_v2'), {status: 'active', endsAt: Timestamp.fromMillis(Date.now() + 86400000)});
    await setDoc(doc(c.firestore(), 'users/expired/feature_access/initial_trial_v2'), {status: 'active', endsAt: Timestamp.fromMillis(Date.now() - 86400000)});
  });
});
after(async () => {if (env) await env.cleanup();});
for (const uid of states) {
  test(`${uid} owner can read current measurement, revision, routes, receipts and profile history`, async () => {
    for (const p of paths(uid)) await assertSucceeds(getDoc(doc(client(uid), p)));
    for (const kind of ['weight', 'distance']) {
      for (const collectionName of [`${kind}_records`, `${kind}_record_history`, `${kind}_record_days`, `${kind}_record_mutations`]) await assertSucceeds(getDocs(collection(client(uid), `users/${uid}/${collectionName}`)));
      await assertSucceeds(getDocs(collection(client(uid), `users/${uid}/${kind}_record_history/record-1/revisions`)));
    }
    await assertSucceeds(getDocs(collection(client(uid), `users/${uid}/pet_subjects/subject-1/profile_history/main_profile/revisions`)));
  });
  test(`${uid} owner cannot bypass receipt/history or forge subject, revision or acceptance even with active entitlement`, async () => {
    for (const p of paths(uid)) {
      const ref = doc(client(uid), p);
      await assertFails(setDoc(ref, {subjectId: 'forged'}));
      await assertFails(updateDoc(ref, {acceptedAt: Timestamp.now(), revision: 999}));
      await assertFails(deleteDoc(ref));
      await assertFails(setDoc(doc(client(uid), `${p}_new`), {ownerUid: uid, revision: 1}));
    }
  });
}
for (const actor of ['other', null]) test(`${actor ?? 'anonymous'} cannot read/list/write another owner's source or history`, async () => {
  for (const p of paths('paid')) {
    const ref = doc(client(actor), p);
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, {subjectId: 'forged'}));
    await assertFails(updateDoc(ref, {revision: 2}));
    await assertFails(deleteDoc(ref));
  }
  for (const kind of ['weight', 'distance']) for (const c of [`${kind}_records`, `${kind}_record_history`, `${kind}_record_days`, `${kind}_record_mutations`]) await assertFails(getDocs(collection(client(actor), `users/paid/${c}`)));
});
test('explicit grants do not expose arbitrary descendants, other profile-history slots or cross-owner collection groups', async () => {
  for (const p of [
    `users/paid/weight_records/${day}/private/secret`,
    'users/paid/weight_record_history/record-1/private/secret',
    'users/paid/distance_record_history/record-1/revisions/0000000001/private/secret',
    'users/paid/weight_record_mutations/mutation-1/private/secret',
    `users/paid/distance_record_days/${day}/private/secret`,
    'users/paid/pet_subjects/subject-1/profile_history/other',
    'users/paid/pet_subjects/subject-1/profile_history/main_profile/private/secret',
  ]) {
    await assertFails(getDoc(doc(client('paid'), p)));
    await assertFails(setDoc(doc(client('paid'), p), {value: 1}));
  }
  await assertFails(getDocs(collectionGroup(client('paid'), 'revisions')));
});
