'use strict';
// Fake transaction objects only; no Firebase initialization or network.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createFirestoreBillingContactStore}=require('../lib/preview-functions/src/billing-contact-store');
function fake() {
  const seen=[], values=new Map();
  const db={
    collection(name) {
      seen.push(['collection',name]);
      return {doc(uid) {
        const path=name+'/'+uid; seen.push(['doc',uid]);
        return {path,async get() {
          seen.push(['get',path]); return {data:()=>structuredClone(values.get(path))};
        }};
      }};
    },
    async runTransaction(fn) {
      return fn({
        async get(ref) {seen.push(['txget',ref.path]);return {data:()=>structuredClone(values.get(ref.path))};},
        set(ref,state) {seen.push(['txset',ref.path]);values.set(ref.path,structuredClone(state));},
      });
    },
  };
  return {db,seen,values,store:createFirestoreBillingContactStore(db)};
}
test('store reads only the exact isolated own UID document',async()=>{const f=fake();f.values.set('preview_billing_contacts/synthetic-owner',{purpose:'billing_contact_preview'});assert.deepEqual(await f.store.read('synthetic-owner'),{purpose:'billing_contact_preview'});assert.deepEqual(f.seen,[['collection','preview_billing_contacts'],['doc','synthetic-owner'],['get','preview_billing_contacts/synthetic-owner']]);});
test('missing own contact is empty and does not search by email or other UID',async()=>{const f=fake();assert.deepEqual(await f.store.read('synthetic-owner'),{});assert.equal(f.values.size,0);assert.equal(f.seen.filter(x=>x[0]==='collection').length,1);});
test('store transaction reads and writes the same isolated document',async()=>{const f=fake();f.values.set('preview_billing_contacts/synthetic-owner',{counter:1});const result=await f.store.mutate('synthetic-owner',state=>({state:{...state,counter:state.counter+1},result:'synthetic-result'}));assert.equal(result,'synthetic-result');assert.equal(f.values.get('preview_billing_contacts/synthetic-owner').counter,2);assert.deepEqual(f.seen.filter(x=>/^tx/.test(x[0])),[['txget','preview_billing_contacts/synthetic-owner'],['txset','preview_billing_contacts/synthetic-owner']]);assert.doesNotMatch(JSON.stringify(f.seen),/users\/|billing\/|firebase-auth|stripe/);});
test('malformed owner paths cannot touch Firestore',async()=>{for(const uid of ['',null,123,'synthetic/other','synthetic owner','synthetic\nowner','x'.repeat(129)]){const f=fake();await assert.rejects(f.store.read(uid),e=>e.code==='unauthenticated');await assert.rejects(f.store.mutate(uid,()=>({state:{},result:null})),e=>e.code==='unauthenticated');assert.equal(f.seen.length,0);}});
