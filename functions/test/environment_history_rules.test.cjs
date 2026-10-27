"use strict";
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {before, after, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, Timestamp} = require('firebase/firestore');
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated localhost emulator required');
const port = Number(process.env.FIRESTORE_EMULATOR_HOST.split(':')[1]);
assert.notEqual(port, 8080, 'Do not use an existing default emulator');
let env;
const base = uid => `users/${uid}/breeding_environments/main_env`;
const paths = uid => [base(uid), `${base(uid)}/revisions/0000000001`, `${base(uid)}/mutations/environment-mutation-0001`];
const owners = ['paid', 'trial', 'expired', 'unpaid'];
const client = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-hamcare-environment-rules', firestore:{host:'127.0.0.1', port, rules:fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db=context.firestore();
    for (const uid of owners) {
      for (const p of paths(uid)) await setDoc(doc(db,p), {ownerUid:uid, revision:1, cageWidth:'60'});
      await setDoc(doc(db, `${base(uid)}/private/secret`), {private:true});
      await setDoc(doc(db, `users/${uid}/daily_care_actions/2026-10-12`), {revision:1});
      await setDoc(doc(db, `users/${uid}/rewards/continuity`), {balance:8});
      await setDoc(doc(db, `users/${uid}/personalized_reports/first`), {generation:{status:'generated'}});
      await setDoc(doc(db, `users/${uid}/personality_reports/personality_v1_body`), {readyMetrics:['body']});
    }
    await setDoc(doc(db,'users/paid/billing/subscription'),{plan:'paid',status:'active'});
    await setDoc(doc(db,'users/trial/feature_access/initial_trial_v2'),{status:'active',endsAt:Timestamp.fromMillis(Date.now()+86400000)});
    await setDoc(doc(db,'users/expired/feature_access/initial_trial_v2'),{status:'active',endsAt:Timestamp.fromMillis(Date.now()-86400000)});
  });
});
after(async () => {if(env) await env.cleanup();});
for (const uid of owners) {
  test(`${uid}: environment/current/history/receipts readable by owner independent of entitlement`, async () => {
    for(const p of paths(uid)) await assertSucceeds(getDoc(doc(client(uid),p)));
    for(const c of ['revisions','mutations']) await assertSucceeds(getDocs(collection(client(uid), `${base(uid)}/${c}`)));
    await assertSucceeds(getDocs(collection(client(uid), `users/${uid}/breeding_environments`)));
    await assertFails(getDoc(doc(client(uid),`${base(uid)}/private/secret`)));
  });
  for (const actor of [uid, 'other', null]) test(`${actor??'anonymous'} cannot forge current/history/receipt for ${uid}`, async () => {
    for(const p of paths(uid)) {
      const db=client(actor), ref=doc(db,p);
      await assertFails(updateDoc(ref,{acceptedAt:Timestamp.now(),revision:99}));
      await assertFails(setDoc(ref,{cageWidth:'99'}));
      await assertFails(deleteDoc(ref));
      await assertFails(setDoc(doc(db,p+'_new'),{ownerUid:uid,revision:1}));
    }
  });
  for (const actor of ['other',null]) test(`${actor??'anonymous'} cannot read another owner's environment/history/receipt`, async () => {
    for(const p of paths(uid)) await assertFails(getDoc(doc(client(actor),p)));
    for(const c of ['revisions','mutations']) await assertFails(getDocs(collection(client(actor), `${base(uid)}/${c}`)));
  });
}
test('history under a different environment document and arbitrary nested paths remain denied',async()=>{
  const db=client('trial');
  for(const p of ['users/trial/breeding_environments/other_env/revisions/0000000001',`${base('trial')}/revisions/0000000001/private/hidden`]) {
    await assertFails(getDoc(doc(db,p)));
    await assertFails(setDoc(doc(db,p),{revision:1}));
  }
});
for (const uid of ['paid','trial']) test(`${uid}: settings permissions preserved; profile and accepted records are callable-owned`,async()=>{
  const db=client(uid);
  for(const c of ['weight_records','distance_records']) {
    const ref=doc(db,`users/${uid}/${c}/2026-10-12`);
    await assertFails(setDoc(ref,{dayKey:'2026-10-12'}));
    await assertFails(updateDoc(ref,{revision:2}));
  }
  await assertFails(setDoc(doc(db,`users/${uid}/pet_profiles/main_pet`),{species:'ゴールデン'}));
  await assertFails(setDoc(doc(db,`users/${uid}/daily_checkins/2026-10-12`),{dayKey:'2026-10-12'}));
  await assertSucceeds(setDoc(doc(db,`users/${uid}/owner_profiles/main`),{displayName:'owner'}));
});
for (const uid of ['expired','unpaid']) test(`${uid}: recording entitlement remains unchanged`,async()=>{
  for(const c of ['weight_records','distance_records','daily_checkins']) await assertFails(setDoc(doc(client(uid),`users/${uid}/${c}/2026-10-12`),{dayKey:'2026-10-12'}));
});
test('care/rewards/frozen reports remain server-owned and owner-readable',async()=>{
  const db=client('trial');
  for(const p of ['daily_care_actions/2026-10-12','rewards/continuity','personalized_reports/first','personality_reports/personality_v1_body']) {
    const ref=doc(db,`users/trial/${p}`);
    await assertSucceeds(getDoc(ref));
    await assertFails(updateDoc(ref,{modified:true}));
    await assertFails(deleteDoc(ref));
  }
});
