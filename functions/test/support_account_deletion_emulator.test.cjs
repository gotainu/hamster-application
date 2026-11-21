'use strict';
const assert=require('node:assert/strict');
const {test,after}=require('node:test');
const admin=require('firebase-admin');
const core=require('../lib/supportAccountDeletion');
const {runAccountDeletion}=require('../lib/accountDeletion');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:18687','dedicated local emulator only');
const app=admin.initializeApp({projectId:'demo-support-delete'},'support-deletion-tests');
const db=app.firestore();
after(async()=>{await db.terminate();await app.delete();});
function fixture(uid) {
  let now=1800000000000,deleted=0;
  const user={uid,disabled:false,metadata:{creationTime:new Date(now-86400000).toISOString()},providerData:[{providerId:'apple.com',uid:'existing-subject'}]};
  let authExists=true,failCleanup=false;
  const d={db,now:()=>now,getUser:async target=>target===uid&&authExists?user:null,
    runDeletion:target=>runAccountDeletion({db,now:()=>now,livemode:false,
      stripe:()=>assert.fail('profileless free account must not load Stripe'),
      deleteData:async target=>{assert.equal(target,uid);if(failCleanup)throw Error('temporary Auth failure');
        await db.recursiveDelete(db.doc('users/'+uid));authExists=false;deleted++;}},target,
    {kind:'request',stopBillingConfirmed:true})};
  return{d,advance:ms=>now+=ms,fail:v=>failCleanup=v,deleted:()=>deleted,
    identity:()=>({uid,authTime:Math.floor(now/1000),appleLinked:true})};
}
const confirm=(f,t)=>core.confirmSupportDeletion(f.d,{...t,confirmText:'DELETE_MY_ACCOUNT',stopBillingConfirmed:true,
  appleRevocation:'manual_acknowledged'},f.identity());
test('real Firestore transaction consumes a verified challenge only once concurrently',async()=>{
  const f=fixture('emulator_existing_concurrent'),t=await core.createSupportDeletion(f.d,{targetUid:'emulator_existing_concurrent',intakeRef:'mail_concurrent'});
  const results=await Promise.allSettled([confirm(f,t),confirm(f,t)]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.find(r=>r.status==='rejected').reason.reason,'reused');
  assert.equal((await db.doc(core.SUPPORT_DELETION_COLLECTION+'/'+t.requestId).get()).get('status'),'verified');
});
test('real Firestore: profileless Apple-no-email UID resumes existing deletion after cleanup failure',async()=>{
  const uid='emulator_profileless_resume',f=fixture(uid),t=await core.createSupportDeletion(f.d,{targetUid:uid,intakeRef:'mail_resume'});
  assert.deepEqual(await core.inspectSupportDeletion(f.d,t,f.identity()),{ok:true,appleLinked:true});
  await confirm(f,t);f.fail(true);
  let review=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.deepEqual(await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:review.reviewDigest}),
    {status:'processing',completionConfirmed:false});
  assert.equal(f.deleted(),0);assert.equal((await f.d.getUser(uid)).uid,uid);
  f.fail(false);f.advance(65000);review=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.deepEqual(await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:review.reviewDigest}),
    {status:'completed',completionConfirmed:true});
  assert.equal(f.deleted(),1);assert.equal(await f.d.getUser(uid),null);
  assert.equal((await db.doc(core.SUPPORT_DELETION_COLLECTION+'/'+t.requestId).get()).get('status'),'completed');
});
