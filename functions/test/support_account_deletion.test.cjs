'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {createHash}=require('node:crypto');
const {fakeFirestore,loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource();
const core=load('supportAccountDeletion');
const {runAccountDeletion,accountDeletionRef,accountDeletionFenceDigest}=load('accountDeletion');
const key=x=>createHash('sha256').update(x).digest('hex');
function fixture({apple=false,paid=false}={}) {
  const {db}=fakeFirestore();
  db.getAll=async(...refs)=>Promise.all(refs.map(ref=>ref.get()));
  const old=db.runTransaction.bind(db);
  db.runTransaction=fn=>old(tx=>{tx.update=(r,v)=>tx.set(r,{...db.documents.get(r.path),...v});return fn(tx);});
  let time=1_800_000_000_000,deletes=0,apiCalls=0,stripeFails=false,cleanupFails=false;
  const uid='existing_account',other='unrelated_account';
  const users=new Map([uid,other].map(id=>[id,{uid:id,disabled:false,metadata:{creationTime:new Date(time-86400000).toISOString()},
    providerData:apple?[{providerId:'apple.com',uid:'same_subject'}]:[{providerId:'password'}]}]));
  const sub={id:'sub_owned',customer:'cus_owned',status:'active',livemode:false,metadata:{firebaseUid:uid},
    items:{has_more:false,data:[{price:{id:'price_550'}}]}};
  const empty=async()=>({has_more:false,data:[]});
  const stripe={customers:{retrieve:async()=>({id:'cus_owned',livemode:false,metadata:{firebaseUid:uid}})},
    checkout:{sessions:{list:empty}},subscriptionSchedules:{list:empty},invoices:{list:empty},invoiceItems:{list:empty},
    subscriptions:{list:async()=>{if(stripeFails)throw Error('transient');return{has_more:false,data:[sub]};},retrieve:async()=>sub,
      cancel:async(id,params)=>{assert.equal(id,'sub_owned');assert.deepEqual(params,{invoice_now:false,prorate:false});apiCalls++;sub.status='canceled';}}};
  if(paid)db.documents.set('users/'+uid+'/billing/subscription',{firebaseUid:uid,stripeCustomerId:'cus_owned',stripeSubscriptionId:'sub_owned',status:'active'});
  const deletion={db,now:()=>time,livemode:false,stripe:()=>{assert.equal(paid,true);return{stripe,livemode:false,priceId:'price_550'};},
    deleteData:async target=>{assert.equal(target,uid);deletes++;if(cleanupFails)throw Error('Auth temporary');users.delete(target);
      for(const p of [...db.documents.keys()])if(p==='users/'+target||p.startsWith('users/'+target+'/'))db.documents.delete(p);}};
  const d={db,getUser:async id=>users.get(id)??null,now:()=>time,
    runDeletion:id=>runAccountDeletion(deletion,id,{kind:'request',stopBillingConfirmed:true}),
    resumeDeletion:(id,input)=>runAccountDeletion(deletion,id,{kind:'operator_resume',stopBillingConfirmed:true,...input})};
  const identity=id=>({uid:id??uid,authTime:Math.floor(time/1000),appleLinked:apple});
  const create=()=>core.createSupportDeletion(d,{targetUid:uid,intakeRef:'support_01'});
  const confirm=(ticket,extra={})=>core.confirmSupportDeletion(d,{...ticket,confirmText:'DELETE_MY_ACCOUNT',stopBillingConfirmed:true,
    appleRevocation:apple?'manual_acknowledged':'not_linked',...extra},identity());
  const ticketRef=t=>db.doc(core.SUPPORT_DELETION_COLLECTION+'/'+t.requestId);
  return{d,db,uid,other,users,identity,create,confirm,ticketRef,sub,deletion,
    advance:ms=>time+=ms,now:()=>time,deletes:()=>deletes,apiCalls:()=>apiCalls,
    stripeFails:v=>stripeFails=v,cleanupFails:v=>cleanupFails=v};
}
const denied=(fn,reason)=>assert.rejects(fn,e=>e instanceof core.SupportDeletionError && e.reason===reason);
test('existing profileless free UID: verified intent → dry-run → existing cleanup → confirmed completion',async()=>{
  const f=fixture(),t=await f.create();
  assert.equal((await f.ticketRef(t).get()).get('proofHash'),key(t.requestId+':'+t.proof));
  assert.ok(!JSON.stringify((await f.ticketRef(t).get()).data()).includes(t.proof));
  const before=f.db.writes.length;
  assert.deepEqual(await core.inspectSupportDeletion(f.d,t,f.identity()),{ok:true,appleLinked:false});
  assert.equal(f.db.writes.length,before);
  assert.deepEqual(await f.confirm(t),{status:'verified'});
  const count=f.db.writes.length;
  const review=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.equal(f.db.writes.length,count);assert.equal(f.deletes(),0);assert.equal(review.uidHash,key(f.uid));
  assert.ok(!JSON.stringify(review).includes(f.uid));
  const result=await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:review.reviewDigest});
  assert.equal(result.status,'completed');assert.equal(result.completionConfirmed,true);assert.equal(f.deletes(),1);assert.ok(f.users.has(f.other));
});
test('Apple email-unset / no owner or pet is valid; manual fallback is explicit and recorded',async()=>{
  const f=fixture({apple:true}),t=await f.create();
  await denied(()=>f.confirm(t,{appleRevocation:'not_linked'}),'apple_action_required');
  await f.confirm(t);
  const r=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.equal(r.appleAction,'manual_acknowledged');
  assert.equal((await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest})).status,'completed');
});
test('Apple reported revoke result is clearly client-reported, no OAuth token persisted',async()=>{
  const f=fixture({apple:true}),t=await f.create();await f.confirm(t,{appleRevocation:'revoked_client_reported'});
  assert.equal((await f.ticketRef(t).get()).get('appleAction'),'revoked_client_reported');
});
test('unauthenticated and wrong UID rejected before Apple provider effects',async()=>{
  const f=fixture({apple:true}),t=await f.create();
  await denied(()=>core.inspectSupportDeletion(f.d,t,null),'unauthenticated');
  await denied(()=>core.inspectSupportDeletion(f.d,t,f.identity(f.other)),'wrong_account');
  assert.equal((await f.ticketRef(t).get()).get('status'),'pending');assert.equal(f.deletes(),0);
});
test('unverified ticket cannot be reviewed or executed by operator',async()=>{
  const f=fixture(),t=await f.create();
  await denied(()=>core.reviewSupportDeletion(f.d,t.requestId),'unverified');
  await denied(()=>core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:'v1.'+f.now()+'.'+'0'.repeat(64)}),'unverified');
  assert.equal(f.deletes(),0);
});
test('wrong proof, cross-request proof, malformed proof and replay are rejected',async()=>{
  const f=fixture(),a=await f.create(),b=await f.create();
  for(const proof of ['0'.repeat(64),b.proof,'not-a-proof'])await denied(()=>f.confirm({...a,proof}),'invalid_request');
  await f.confirm(a);await denied(()=>f.confirm(a),'reused');
  assert.equal((await f.ticketRef(b).get()).get('status'),'pending');
});
test('expiration and stale authentication reject, explicit cancellation consent mandatory',async()=>{
  const f=fixture(),t=await f.create();
  await denied(()=>f.confirm(t,{stopBillingConfirmed:false}),'invalid_request');
  const old=f.identity();f.advance(301000);
  await denied(()=>core.inspectSupportDeletion(f.d,t,old),'unauthenticated');
  f.advance(core.SUPPORT_DELETION_PROOF_TTL_MS);
  await denied(()=>f.confirm(t),'expired');
});
test('authentication before ticket and future authentication cannot confirm',async()=>{
  const f=fixture(),t=await f.create();
  for(const authTime of [f.now()/1000-1,f.now()/1000+31])
    await denied(()=>core.inspectSupportDeletion(f.d,t,{...f.identity(),authTime}),'unauthenticated');
});
test('new UID, disabled account and recreation of target UID rejected',async()=>{
  const f=fixture(),t=await f.create();
  await denied(()=>core.createSupportDeletion(f.d,{targetUid:'new_uid',intakeRef:'mail01'}),'wrong_account');
  const user=f.users.get(f.uid);user.metadata.creationTime=new Date(f.now()).toISOString();
  await denied(()=>f.confirm(t),'wrong_account');
  user.metadata.creationTime=new Date(f.now()-86400000).toISOString();user.disabled=true;
  await denied(()=>f.confirm(t),'wrong_account');
});
test('dry-run digest expires, binding changes invalidate it, no direct UID override',async()=>{
  const f=fixture(),t=await f.create();await f.confirm(t);let r=await core.reviewSupportDeletion(f.d,t.requestId);
  f.db.documents.set('users/'+f.uid+'/billing/subscription',{status:'active'});
  await denied(()=>core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),'stale_review');
  r=await core.reviewSupportDeletion(f.d,t.requestId);f.advance(301000);
  await denied(()=>core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),'stale_review');
  assert.equal(f.deletes(),0);
});
test('Stripe failure retains data/Auth; same verified request resumes existing billing state machine',async()=>{
  const f=fixture({paid:true}),t=await f.create();await f.confirm(t);f.stripeFails(true);
  let r=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.deepEqual(await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),{status:'processing',completionConfirmed:false});
  assert.equal(f.deletes(),0);assert.ok(f.users.has(f.uid));
  f.stripeFails(false);f.advance(65000);r=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.equal((await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest})).status,'completed');
  assert.equal(f.apiCalls(),1);assert.equal(f.deletes(),1);
});
test('Stripe cancellation then cleanup failure resumes without second cancellation; duplicate completion idempotent',async()=>{
  const f=fixture({paid:true}),t=await f.create();await f.confirm(t);f.cleanupFails(true);
  let r=await core.reviewSupportDeletion(f.d,t.requestId);
  await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest});assert.equal(f.apiCalls(),1);
  f.cleanupFails(false);f.advance(65000);r=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.equal((await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest})).status,'completed');
  r=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.equal((await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest})).status,'completed');
  assert.equal(f.apiCalls(),1);assert.equal(f.deletes(),2);
});
test('completion requires existing tombstone AND absent Auth, not only run result',async()=>{
  const f=fixture(),t=await f.create();await f.confirm(t);const r=await core.reviewSupportDeletion(f.d,t.requestId);
  f.d.runDeletion=async()=>({ok:true});
  await denied(()=>core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),'completion_unconfirmed');
});
test('completed worker tombstone is reconcilable from same verified ticket, no forced reauthentication',async()=>{
  const f=fixture(),t=await f.create();await f.confirm(t);
  await runAccountDeletion(f.deletion,f.uid,{kind:'request',stopBillingConfirmed:true});
  const r=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.equal(r.completionConfirmed,true);
  assert.equal((await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest})).status,'completed');
  assert.equal(f.deletes(),1);
});
test('changed provider metadata rejects stale Apple preflight',async()=>{
  const f=fixture({apple:true}),t=await f.create();f.users.get(f.uid).providerData=[];
  await denied(()=>core.inspectSupportDeletion(f.d,t,f.identity()),'unauthenticated');
  assert.equal((await f.ticketRef(t).get()).get('status'),'pending');
});
test('concurrent confirmation consumes challenge exactly once',async()=>{
  const f=fixture(),t=await f.create();
  const results=await Promise.allSettled([f.confirm(t),f.confirm(t)]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.find(r=>r.status==='rejected').reason.reason,'reused');
});
test('expired verified request requires fresh confirmation unless existing deletion work already started',async()=>{
  const f=fixture(),t=await f.create();await f.confirm(t);f.advance(core.SUPPORT_DELETION_PROOF_TTL_MS+1);
  await denied(()=>core.reviewSupportDeletion(f.d,t.requestId),'expired');assert.equal(f.deletes(),0);
});

function manualFence(f,extra={}) {
 const value={version:1,uid:f.uid,status:'manual_review',lease:null,dueAt:null,attempt:12,
  paidConfirmed:true,billingStopped:false,requestedAt:f.now()-1000,updatedAt:f.now()-1,reason:'retryable',...extra};
 f.db.documents.set(accountDeletionRef(f.db,f.uid).path,value);return value;
}
test('manual resume: exhausted verified request gets one bounded attempt through existing Stripe stop and cleanup',async()=>{
 const f=fixture({paid:true}),t=await f.create();await f.confirm(t);manualFence(f);
 let r=await core.reviewSupportDeletion(f.d,t.requestId);
 assert.equal(r.manualResumeAllowed,true);assert.equal(r.deletionAttempt,12);assert.equal(r.manualResumeCount,0);
 assert.equal((await core.executeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest})).status,'manual_review');
 assert.equal(f.apiCalls(),0);assert.equal(f.deletes(),0);
 r=await core.reviewSupportDeletion(f.d,t.requestId);
 const out=await core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest});
 assert.deepEqual(out,{status:'completed',completionConfirmed:true});assert.equal(f.apiCalls(),1);assert.equal(f.deletes(),1);
 assert.ok(f.users.has(f.other));assert.equal((await f.ticketRef(t).get()).get('manualResumeAt'),f.now());
 await denied(()=>core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),'stale_review');
 assert.equal(f.apiCalls(),1);assert.equal(f.deletes(),1);
});
test('manual resume: a failed extra attempt preserves cumulative history and does not reopen retry budget',async()=>{
 const f=fixture({paid:true}),t=await f.create();await f.confirm(t);manualFence(f);f.stripeFails(true);
 const r=await core.reviewSupportDeletion(f.d,t.requestId);
 assert.deepEqual(await core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),{status:'manual_review',completionConfirmed:false});
 const after=(await accountDeletionRef(f.db,f.uid).get()).data();
 assert.equal(after.attempt,13);assert.equal(after.operatorResumeCount,1);assert.equal(after.billingStopped,false);
 assert.equal(after.status,'manual_review');assert.equal(after.operatorResumePreviousReason,'retryable');
 assert.equal(after.operatorResumeRequestHash,key(t.requestId));assert.equal(after.dueAt,null);assert.ok(f.users.has(f.uid));assert.equal(f.deletes(),0);
 f.deletion.stripe=assert.fail;f.deletion.deleteData=assert.fail;f.advance(86400000);
 assert.deepEqual(await runAccountDeletion(f.deletion,f.uid,{kind:'retry'}),{ok:false,reason:'manual_review'});
 assert.deepEqual(await runAccountDeletion(f.deletion,f.uid,{kind:'request',stopBillingConfirmed:true}),{ok:false,reason:'manual_review'});
 const next=await core.reviewSupportDeletion(f.d,t.requestId);assert.equal(next.manualResumeAllowed,false);
 const writes=f.db.writes.length;await denied(()=>core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:next.reviewDigest}),'invalid_request');
 assert.equal(f.db.writes.length,writes);
});
test('manual resume: already stopped billing is preserved and cleanup failure remains manual',async()=>{
 const f=fixture(),t=await f.create();await f.confirm(t);manualFence(f,{billingStopped:true,attempt:4});f.cleanupFails(true);
 f.deletion.stripe=assert.fail;let r=await core.reviewSupportDeletion(f.d,t.requestId);
 assert.deepEqual(await core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),{status:'manual_review',completionConfirmed:false});
 const after=(await accountDeletionRef(f.db,f.uid).get()).data();assert.equal(after.billingStopped,true);
 assert.equal(after.attempt,5);assert.equal(after.operatorResumeCount,1);assert.equal(after.status,'manual_review');assert.equal(f.deletes(),1);
 f.cleanupFails(false);r=await core.reviewSupportDeletion(f.d,t.requestId);
 await denied(()=>core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),'invalid_request');assert.equal(f.deletes(),1);
});
test('manual resume: an interrupted extra attempt cannot be retried by worker or normal app',async()=>{
 for(const kind of ['retry','request']) {
  const f=fixture(),t=await f.create();await f.confirm(t);
  manualFence(f,{status:'running',attempt:13,operatorResumeCount:1,billingStopped:true,lease:'interrupted',dueAt:f.now()-1});
  f.deletion.stripe=assert.fail;f.deletion.deleteData=assert.fail;
  assert.deepEqual(await runAccountDeletion(f.deletion,f.uid,kind==='retry'?{kind}:{kind,stopBillingConfirmed:true}),{ok:false,reason:'manual_review'});
  const after=(await accountDeletionRef(f.db,f.uid).get()).data();assert.equal(after.status,'manual_review');
  assert.equal(after.attempt,13);assert.equal(after.operatorResumeInterrupted,true);assert.equal(after.billingStopped,true);
 }
});
test('manual resume: an unverified ticket and a different ticket review cannot grant an attempt',async()=>{
 const f=fixture(),a=await f.create(),b=await f.create();manualFence(f);
 const digest='v1.'+f.now()+'.'+'0'.repeat(64);
 await denied(()=>core.resumeSupportDeletion(f.d,{requestId:a.requestId,reviewDigest:digest}),'unverified');
 await f.confirm(a);await f.confirm(b);const r=await core.reviewSupportDeletion(f.d,a.requestId);
 await denied(()=>core.resumeSupportDeletion(f.d,{requestId:b.requestId,reviewDigest:r.reviewDigest}),'stale_review');
 assert.equal(f.deletes(),0);assert.equal((await accountDeletionRef(f.db,f.uid).get()).get('attempt'),12);
});
test('manual resume: stale review and deleted/recreated Auth are rejected before mutation',async()=>{
 for(const mode of ['expired','recreated']) {
  const f=fixture(),t=await f.create();await f.confirm(t);manualFence(f);const r=await core.reviewSupportDeletion(f.d,t.requestId);
  if(mode==='expired')f.advance(301000);else f.users.get(f.uid).metadata.creationTime=new Date(f.now()).toISOString();
  await denied(()=>core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),mode==='expired'?'stale_review':'wrong_account');
  assert.equal(f.deletes(),0);assert.equal((await accountDeletionRef(f.db,f.uid).get()).get('attempt'),12);
 }
});
test('manual resume: concurrent fence change between review validation and claim is refused atomically',async()=>{
 const f=fixture(),t=await f.create();await f.confirm(t);manualFence(f);const r=await core.reviewSupportDeletion(f.d,t.requestId);
 f.d.resumeDeletion=async(uid,input)=>{const path=accountDeletionRef(f.db,uid).path;f.db.documents.set(path,{...f.db.documents.get(path),updatedAt:f.now()});
  return runAccountDeletion(f.deletion,uid,{kind:'operator_resume',stopBillingConfirmed:true,...input});};
 await assert.rejects(core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),e=>e.reason==='manual_review');
 assert.equal(f.deletes(),0);assert.equal((await accountDeletionRef(f.db,f.uid).get()).get('attempt'),12);
});
test('manual resume: double execution and direct reused fence grant do not delete twice',async()=>{
 const f=fixture(),t=await f.create();await f.confirm(t);const fence=manualFence(f);const r=await core.reviewSupportDeletion(f.d,t.requestId);
 const results=await Promise.allSettled([core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest})]);
 assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(f.deletes(),1);
 await assert.rejects(runAccountDeletion(f.deletion,f.uid,{kind:'operator_resume',stopBillingConfirmed:true,requestId:t.requestId,fenceDigest:accountDeletionFenceDigest(fence)}),e=>e.reason==='manual_review');
 assert.equal(f.deletes(),1);
});
test('manual resume: malformed, foreign and already resumed fences have no available grant',async()=>{
 for(const extra of [{uid:'other_account'},{attempt:13},{attempt:0},{operatorResumeCount:1},{lease:'held'},{dueAt:1},{billingStopped:'true'},{reason:'unknown_reason'},{requestedAt:undefined}]) {
  const f=fixture(),t=await f.create();await f.confirm(t);manualFence(f,extra);const r=await core.reviewSupportDeletion(f.d,t.requestId);
  assert.equal(r.manualResumeAllowed,false);await denied(()=>core.resumeSupportDeletion(f.d,{requestId:t.requestId,reviewDigest:r.reviewDigest}),'invalid_request');assert.equal(f.deletes(),0);
 }
});
