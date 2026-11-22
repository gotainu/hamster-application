'use strict';
const assert=require('node:assert/strict');
const {test,after}=require('node:test');
const admin=require('firebase-admin');
const {createBillingContactEngine}=require('../lib/billingContact');
const {createLiveBillingContactStore}=require('../lib/billingContactStore');
const {readVerifiedBillingContact}=require('../lib/webBillingShared');
const {resolveBillingNotificationRecipient}=require('../lib/billingNotificationRecipient');
const {runAccountDeletion}=require('../lib/accountDeletion');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:18689','dedicated localhost contact emulator only');
const app=admin.initializeApp({projectId:'demo-hamcare-live-contact'},'live-contact-tests');
const db=app.firestore();
after(async()=>{await db.terminate();await app.delete();});
function fixture(uid) {
  let now=1800000000000,n=0;const sent=[];
  const user={uid,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-subject'}]};
  const context={identity:{uid,emailVerified:false,authBasis:'apple_provider'},adminUser:user,appAccountExists:true};
  const engine=createBillingContactEngine({environment:'live',store:createLiveBillingContactStore(db),now:()=>new Date(now),
    randomToken:()=>Buffer.alloc(32,++n).toString('base64url'),sendMail:async message=>sent.push(message)});
  return{engine,context,user,uid,now:()=>now,advance:ms=>now+=ms,sent,
    token:()=>new URL(sent.at(-1).verificationUrl).hash.slice(7)};
}
test('real transaction confirms one proof once and publishes exact shared Live consumer schema',async()=>{
  const f=fixture('synthetic_contact_one');
  await f.engine.request(f.context,'synthetic@privaterelay.appleid.com');const token=f.token();
  const results=await Promise.allSettled([f.engine.confirm(f.context,token),f.engine.confirm(f.context,token)]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.find(r=>r.status==='rejected').reason.code,'contact_token_used');
  const state=(await db.doc('billing_contacts/'+f.uid).get()).data();
  assert.equal(readVerifiedBillingContact(state,f.uid,'live',f.now()),'synthetic@privaterelay.appleid.com');
  assert.equal(readVerifiedBillingContact(state,f.uid,'preview',f.now()),null);
  assert.deepEqual(resolveBillingNotificationRecipient({uid:f.uid,authUser:f.user,mode:'live',nowMillis:f.now(),
    supplementalContact:{uid:f.uid,state}}),{kind:'resolved',email:'synthetic@privaterelay.appleid.com',source:'user_supplied'});
  assert.equal((await db.doc('preview_billing_contacts/'+f.uid).get()).exists,false);
});
test('real deletion core removes Live contact; delayed confirmation cannot resurrect it',async()=>{
  const f=fixture('synthetic_contact_delete');
  await f.engine.request(f.context,'old@example.test');await f.engine.confirm(f.context,f.token());f.advance(60001);
  await f.engine.request(f.context,'new@example.test');const pending=f.token();
  assert.equal((await db.doc('billing_contacts/'+f.uid).get()).get('email'),'old@example.test');
  assert.deepEqual(await runAccountDeletion({db,now:f.now,livemode:false,stripe:()=>assert.fail('free account no Stripe'),
    deleteData:async uid=>{assert.equal(uid,f.uid);await db.doc('billing_contacts/'+uid).delete();}},f.uid,
    {kind:'request',stopBillingConfirmed:true}),{ok:true});
  await assert.rejects(f.engine.confirm(f.context,pending),{code:'contact_account_unavailable'});
  assert.equal((await db.doc('billing_contacts/'+f.uid).get()).exists,false);
});
