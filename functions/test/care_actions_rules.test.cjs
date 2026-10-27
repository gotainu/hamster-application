"use strict";
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {before, after, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, Timestamp} = require('firebase/firestore');
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/);
const port = Number(process.env.FIRESTORE_EMULATOR_HOST.split(':')[1]);
assert.notEqual(port, 8080);
let env;
const protectedPaths = [
  'daily_care_actions/2026-10-12',
  'daily_care_actions/2026-10-12/revisions/0000000001',
  'daily_care_actions/2026-10-12/mutations/mutation-test-0001',
  'rewards/continuity',
  'continuity_days/2026-10-12',
  'continuity_credits/2026-10-12_condition',
  'continuity_periods/period_2026-10-12',
  'condition_award_days/2026-10-12',
  'continuity_award_links/2026-10-12_condition',
];
const owners = ['paid', 'trial', 'expired', 'unpaid'];
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-hamcare-care-rules', firestore:{host:'127.0.0.1', port, rules:fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db=context.firestore();
    await setDoc(doc(db,'users/trial/care_reward_receipts/2026-10-12_mutation-test-0001'), {pending:true});
    for (const uid of owners) for (const p of protectedPaths) await setDoc(doc(db, `users/${uid}/${p}`), {revision:1, ownerUid:uid, actions:{}});
    await setDoc(doc(db,'users/paid/billing/subscription'),{plan:'paid',status:'active'});
    await setDoc(doc(db,'users/trial/feature_access/initial_trial_v2'),{status:'active', endsAt:Timestamp.fromMillis(Date.now()+86400000)});
    await setDoc(doc(db,'users/expired/feature_access/initial_trial_v2'),{status:'active', endsAt:Timestamp.fromMillis(Date.now()-86400000)});
  });
});
after(async () => {if (env) await env.cleanup();});
const client = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
for (const uid of owners) {
  test(`${uid}: own care/history/continuity remains readable regardless of entitlement`, async () => {
    for(const p of protectedPaths) await assertSucceeds(getDoc(doc(client(uid),`users/${uid}/${p}`)));
    await assertSucceeds(getDocs(collection(client(uid),`users/${uid}/daily_care_actions`)));
    await assertSucceeds(getDocs(collection(client(uid),`users/${uid}/daily_care_actions/2026-10-12/revisions`)));
    await assertFails(getDoc(doc(client(uid),`users/${uid}/daily_care_actions/2026-10-12/private/detail`)));
  });
  for(const actor of [uid,'other',null]) test(`${actor??'guest'} cannot tamper with ${uid}'s care/history/continuity`,async()=>{
    for(const p of protectedPaths){
      const ref=doc(client(actor),`users/${uid}/${p}`);
      await assertFails(updateDoc(ref,{revision:2}));
      await assertFails(deleteDoc(ref));
      await assertFails(setDoc(doc(client(actor),`${ref.path}_new`),{revision:1}));
    }
  });
  for(const actor of ['other',null]) test(`${actor??'guest'} cannot read ${uid}'s care/history/continuity`,async()=>{
    for(const p of protectedPaths) await assertFails(getDoc(doc(client(actor),`users/${uid}/${p}`)));
    await assertFails(getDocs(collection(client(actor),`users/${uid}/daily_care_actions`)));
  });
}
for (const uid of ['paid','trial']) test(`${uid}: weight/distance/health writes use accepted-history callables`,async()=>{
  for(const c of ['weight_records','distance_records']) {
    const ref=doc(client(uid),`users/${uid}/${c}/2026-10-12`);
    await assertFails(setDoc(ref,{dayKey:'2026-10-12'}));
    await assertFails(updateDoc(ref,{revision:2}));
  }
  await assertFails(setDoc(doc(client(uid),`users/${uid}/daily_checkins/2026-10-12`),{dayKey:'2026-10-12'}));
});
for (const uid of ['expired','unpaid']) test(`${uid}: existing record entitlement still enforced`,async()=>{
  for(const c of ['daily_checkins','weight_records','distance_records']) await assertFails(setDoc(doc(client(uid),`users/${uid}/${c}/2026-10-12`),{dayKey:'2026-10-12'}));
});

for(const actor of ['trial','other',null]) test(`${actor??'guest'} cannot read or modify internal reward outbox`,async()=>{
  const db=client(actor),ref=doc(db,'users/trial/care_reward_receipts/2026-10-12_mutation-test-0001');
  await assertFails(getDoc(ref));
  await assertFails(getDocs(collection(db,'users/trial/care_reward_receipts')));
  await assertFails(setDoc(ref,{pending:false}));
  await assertFails(deleteDoc(ref));
});
