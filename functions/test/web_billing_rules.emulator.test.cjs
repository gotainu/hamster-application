'use strict';
// Dedicated demo emulator only. Never load credentials or address production.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {createHash}=require('node:crypto');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,collection,getDoc,getDocs,setDoc,updateDoc,deleteDoc,setLogLevel}=require('firebase/firestore');

assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8297','Dedicated production billing Rules emulator required');
const uid='synthetic-production-billing-owner';
const subject=createHash('sha256').update(uid).digest('hex');
const billing=`users/${uid}/billing/subscription`;

test('current application Rules restrict billing reads to the owner and deny every client write',async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-hamcare-production-billing',
    firestore:{host:'127.0.0.1',port:8297,rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});
  setLogLevel('silent');
  try{
    await env.withSecurityRulesDisabled(async c=>{
      await setDoc(doc(c.firestore(),`users/${uid}`),{has_subcollections:true});
      await setDoc(doc(c.firestore(),billing),{provider:'stripe',plan:'paid',status:'active',stripeLivemode:true});
    });
    for(const actor of [uid,'synthetic-production-billing-other',null]){
      const db=(actor?env.authenticatedContext(actor):env.unauthenticatedContext()).firestore();
      const result=getDoc(doc(db,billing));
      await (actor===uid?assertSucceeds(result):assertFails(result));
      await assertFails(setDoc(doc(db,billing),{plan:'paid',status:'active'}));
      await assertFails(updateDoc(doc(db,billing),{plan:'paid',status:'trialing',stripeCustomerId:'cus_synthetic_other'}));
      await assertFails(deleteDoc(doc(db,billing)));
      await assertFails(setDoc(doc(db,`users/${uid}/billing/new`),{plan:'paid',status:'active'}));
      await assertFails(updateDoc(doc(db,`users/${uid}`),{plan:'paid',stripeCustomerId:'cus_synthetic_other'}));
    }
  }finally{await env.cleanup();}
});

test('current Rules deny all Preview and server billing coordination namespace access',async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-hamcare-production-billing',
    firestore:{host:'127.0.0.1',port:8297,rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});
  setLogLevel('silent');
  const targets=[
    `preview_checkout_task4/${subject}`,
    `preview_checkout_task4/${subject}/billing/subscription`,
    `preview_billing_contacts/${uid}`,
    `preview_billing_contacts/${uid}/status/current`,
    'preview_billing_contact_delivery_limits/2026-11-21',
    `billing_customers/${subject}`,
    `billing_checkout_sessions/${subject}`,
    `billing_contacts/${uid}`,
    `billing_webhook_subjects/${subject}`,
    'billing_webhook_events/synthetic-event',
    'billing_notification_outbox/synthetic-notification',
  ];
  try{
    await env.withSecurityRulesDisabled(async c=>{
      for(const target of targets)await setDoc(doc(c.firestore(),target),{firebaseUid:uid,value:'synthetic-private'});
    });
    for(const actor of [uid,'synthetic-production-billing-other',null]){
      const db=(actor?env.authenticatedContext(actor):env.unauthenticatedContext()).firestore();
      for(const target of targets){
        await assertFails(getDoc(doc(db,target)));
        await assertFails(getDocs(collection(db,target.slice(0,target.lastIndexOf('/')))));
        await assertFails(setDoc(doc(db,target),{firebaseUid:actor,plan:'paid'}));
        await assertFails(updateDoc(doc(db,target),{verified:true}));
        await assertFails(deleteDoc(doc(db,target)));
      }
    }
  }finally{await env.cleanup();}
});
