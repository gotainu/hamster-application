"use strict";
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {before, after, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp, runTransaction} = require('firebase/firestore');
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^127\.0\.0\.1:\d+$/);
assert.notEqual(Number(host.split(':')[1]), 8080);
let env;
const ids = ['personality_v1_body', 'personality_v1_activity', 'personality_v1_body_activity', 'daily_2026-10-09', 'daily_2026-10-10', 'daily_2026-10-11'];
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-hamcare-personality-views-v2', firestore:{host:'127.0.0.1', port:Number(host.split(':')[1]), rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    for (const uid of ['owner','expired']) for (const id of ids) await setDoc(doc(c.firestore(),`users/${uid}/personality_reports/${id}`),{reportId:id,petId:'main_pet',generatedAt:new Date('2026-10-10T00:00:00Z')});
    for (const uid of ['owner','expired']) for (const id of ['personality','personality_daily']) await setDoc(doc(c.firestore(),`users/${uid}/report_pointers/${id}`),{reportId:id==='personality'?'personality_v1_body':'daily_2026-10-10',petId:'main_pet'});
    await setDoc(doc(c.firestore(),'users/owner/personality_reports/daily_2026-10-12'),{reportId:'wrong-id'});
    await setDoc(doc(c.firestore(),'users/owner/personality_reports/daily_2026-99-99'),{reportId:'daily_2026-99-99'});
    await setDoc(doc(c.firestore(),'users/expired/feature_access/initial_trial_v2'),{status:'active',endsAt:new Date('2026-01-01')});
    await setDoc(doc(c.firestore(),'personality_report_queue/owner'),{uid:'owner',dueDateKey:'2026-10-10'});
  });
});
after(async()=>{if(env)await env.cleanup();});
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const ref = (store,id,owner='owner') => doc(store,`users/${owner}/report_view_states/${id}`);
const marker = id => ({reportId:id,viewedAt:serverTimestamp()});
for(const id of ids.slice(0,4)) test(`owner can create/read exact marker for existing ${id}`,async()=>{
 const s=db('owner');await assertSucceeds(setDoc(ref(s,id),marker(id)));assert.equal((await assertSucceeds(getDoc(ref(s,id)))).data().reportId,id);
});
test('expired trial owner can mark/read a report without consuming entitlement',async()=>{const s=db('expired');await assertSucceeds(setDoc(ref(s,ids[0],'expired'),marker(ids[0])));await assertSucceeds(getDoc(ref(s,ids[0],'expired')));});
test('owner can list their read markers',async()=>{await assertSucceeds(getDocs(collection(db('owner'),'users/owner/report_view_states')));});
for(const actor of ['other',null]) test(`${actor ?? 'guest'} cannot read/list/create another owner's read state`,async()=>{
 const s=db(actor);await assertFails(getDoc(ref(s,ids[0])));await assertFails(getDocs(collection(s,'users/owner/report_view_states')));await assertFails(setDoc(ref(s,ids[4]),marker(ids[4])));
});
test('missing report is not a valid marker target',async()=>{await assertFails(setDoc(ref(db('owner'),'daily_2026-10-20'),marker('daily_2026-10-20')));});
test('singleton personality watermark is not permitted',async()=>{await assertFails(setDoc(ref(db('owner'),'personality'),marker('personality')));});
test('referenced report ID must match the server report identity',async()=>{await assertFails(setDoc(ref(db('owner'),'daily_2026-10-12'),marker('daily_2026-10-12')));});
test('malformed daily date is refused even if server document exists',async()=>{await assertFails(setDoc(ref(db('owner'),'daily_2026-99-99'),marker('daily_2026-99-99')));});
for(const data of [{reportId:ids[4]}, {viewedAt:serverTimestamp()}, {reportId:12,viewedAt:serverTimestamp()}, {reportId:ids[4],viewedAt:'now'}, {reportId:ids[4],viewedAt:new Date('2020-01-01')}, {...marker(ids[4]),memo:'not permitted'}, marker(ids[5])]) test(`invalid marker schema is refused ${JSON.stringify(Object.keys(data))} ${typeof data.reportId}`,async()=>{
 await assertFails(setDoc(ref(db('owner'),ids[4]),data));
});
test('view state cannot be replaced, edited or deleted',async()=>{const s=db('owner');const r=ref(s,ids[0]);await assertFails(updateDoc(r,{viewedAt:serverTimestamp()}));await assertFails(setDoc(r,marker(ids[0])));await assertFails(deleteDoc(r));});
test('two clients transact concurrently without resetting first marker timestamp',async()=>{
 const s=db('owner');const r=ref(s,ids[5]);let created=0;
 const view=()=>runTransaction(s,async tx=>{if((await tx.get(r)).exists())return false;tx.set(r,marker(ids[5]));return true;});
 const values=await Promise.all([view(),view()]);created=values.filter(Boolean).length;assert.equal(created,1);
 const before=(await getDoc(r)).data().viewedAt;assert.equal(await view(),false);assert.ok((await getDoc(r)).data().viewedAt.isEqual(before));
});
for(const actor of ['owner','other',null]) test(`${actor ?? 'guest'} cannot access the server daily queue`,async()=>{
 const s=db(actor);const r=doc(s,'personality_report_queue/owner');await assertFails(getDoc(r));await assertFails(getDocs(collection(s,'personality_report_queue')));await assertFails(setDoc(r,{uid:'owner'}));await assertFails(updateDoc(r,{uid:'other'}));await assertFails(deleteDoc(r));
});

// v1 keeps its exact pointer; v2 adds an independent owner-read-only pointer.
for (const uid of ['owner','expired']) test(`${uid} can read both independent pointers without entitlement`,async()=>{
 const s=db(uid);for(const id of ['personality','personality_daily']) await assertSucceeds(getDoc(doc(s,`users/${uid}/report_pointers/${id}`)));
});
for(const actor of ['other',null]) test(`${actor ?? 'guest'} cannot read either pointer for another owner`,async()=>{
 const s=db(actor);for(const id of ['personality','personality_daily']) await assertFails(getDoc(doc(s,`users/owner/report_pointers/${id}`)));
});
test('client cannot create, update, delete or list either server pointer',async()=>{
 const s=db('owner');for(const id of ['personality','personality_daily']){
  const r=doc(s,`users/owner/report_pointers/${id}`);await assertFails(setDoc(r,{reportId:'daily_2026-10-11'}));await assertFails(updateDoc(r,{reportId:'daily_2026-10-11'}));await assertFails(deleteDoc(r));
  await assertFails(setDoc(doc(db('fresh'),`users/fresh/report_pointers/${id}`),{reportId:'daily_2026-10-11'}));
 }
 await assertFails(getDocs(collection(s,'users/owner/report_pointers')));
});
test('unknown pointer name is denied rather than broadening the collection',async()=>{
 const r=doc(db('owner'),'users/owner/report_pointers/unrecognized');await assertFails(getDoc(r));await assertFails(setDoc(r,{reportId:'daily_2026-10-11'}));
});
