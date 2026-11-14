const test=require('node:test');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8287')throw new Error('Dedicated local Emulator required');
const {initializeApp,deleteApp}=require('firebase-admin/app');const app=initializeApp({projectId:'demo-hamcare-preview-sync'});const {getFirestore,Timestamp}=require('firebase-admin/firestore');const db=getFirestore();
const {hash}=require('../lib/preview-functions/src/engine');const {createPreviewSyncStore}=require('../lib/preview-functions/src/subscription-store');const {subjectRef,readPreviewFacts,FIXTURE_TAG}=require('../lib/preview-functions/src/preview-runtime');const {readPreviewBilling}=require('../lib/preview-functions/src/billing-view');
const store=createPreviewSyncStore();const meta={eventType:'invoice.paid',createdSeconds:100,version:1};const now=Date.now();
async function fixture(){const uid='synthetic-'+randomUUID(),subject=hash(uid),event=hash(randomUUID()),ref=subjectRef(subject);await ref.set({previewFirebaseUid:uid,customerId:'cus_synthetic',attempt:{id:'synthetic-attempt',phase:'complete'}});return {uid,subject,event,ref};}
function input(f,lease,n=now){return {subjectHash:f.subject,eventHash:f.event,lease,nowMs:n,billing:{testMode:true,version:1,previewFirebaseUid:f.uid,stripeCustomerId:'cus_synthetic',stripeSubscriptionId:'sub_synthetic',previewAttempt:'synthetic-attempt',planKey:'premium_monthly',amount:550,currency:'jpy',interval:'month',status:'active',plan:'paid',currentPeriodStartSeconds:Math.floor(now/1000)-100,currentPeriodEndSeconds:Math.floor(now/1000)+1000,firstChargeAtSeconds:Math.floor(now/1000)-100,nextChargeAtSeconds:Math.floor(now/1000)+1000,cancelAtPeriodEnd:false,syncedAtMillis:now},eventRecord:{...meta,result:'synced',processedAtMillis:n,subscriptionHash:hash('sub_synthetic')}};}
test('same Event ID concurrent claims elect one worker',async()=>{const f=await fixture();const results=await Promise.all(['one','two'].map(l=>store.claimEvent(f.event,l,now,now+1000,meta)));assert.deepEqual(results.sort(),['busy','claimed']);});
test('billing and processed receipt commit atomically; resend does not change billing',async()=>{const f=await fixture();await store.claimEvent(f.event,'a',now,now+1000,meta);await store.claimSubject(f.subject,'a',now,now+1000);await store.commit(input(f,'a'));const before=await f.ref.collection('billing').doc('subscription').get();assert.equal(await store.claimEvent(f.event,'b',now,now+1000,meta),'processed');assert.equal((await f.ref.collection('billing').doc('subscription').get()).updateTime.toMillis(),before.updateTime.toMillis());});
test('expired subject lease is reclaimable and old commit cannot overwrite',async()=>{const f=await fixture();await store.claimEvent(f.event,'a',now,now+1000,meta);await store.claimSubject(f.subject,'a',now,now+10);assert.equal(await store.claimSubject(f.subject,'b',now+11,now+1000),true);await assert.rejects(()=>store.commit(input(f,'a',now+12)),e=>e.code==='sync_conflict');assert.equal((await f.ref.collection('billing').doc('subscription').get()).exists,false);});
test('expired event lease cannot commit; interrupted handler can retry',async()=>{const f=await fixture();await store.claimEvent(f.event,'a',now,now+1,meta);await store.claimSubject(f.subject,'a',now,now+1000);await assert.rejects(()=>store.commit(input(f,'a',now+2)));assert.equal(await store.claimEvent(f.event,'b',now+2,now+1000,meta),'claimed');});
test('release only affects the owning invocation and permits retry',async()=>{const f=await fixture();await store.claimEvent(f.event,'a',now,now+1000,meta);await store.claimSubject(f.subject,'a',now,now+1000);await store.release({subjectHash:f.subject,eventHash:f.event,lease:'other',errorCode:'sync_unavailable'});assert.equal(await store.claimSubject(f.subject,'b',now,now+1000),false);await store.release({subjectHash:f.subject,eventHash:f.event,lease:'a',errorCode:'sync_unavailable'});assert.equal(await store.claimEvent(f.event,'b',now,now+1000,meta),'claimed');assert.equal(await store.claimSubject(f.subject,'b',now,now+1000),true);});
test('missing subject never gains a sync lease',async()=>assert.equal(await store.claimSubject(hash(randomUUID()),'a',now,now+1000),false));
test('authenticated projection omits all internal references and honors existing guard',async()=>{const f=await fixture();await f.ref.collection('billing').doc('subscription').set(input(f,'a').billing);const value=await readPreviewBilling(f.uid);assert.equal(value.syncState,'synced');assert.equal(value.billing.entitlementMirror,true);assert.doesNotMatch(JSON.stringify(value),/cus_synthetic|sub_synthetic|synthetic-attempt|previewFirebaseUid/);for(const status of ['past_due','unpaid','paused','incomplete','incomplete_expired','canceled']){await f.ref.collection('billing').doc('subscription').update({status,plan:'none'});assert.equal((await readPreviewBilling(f.uid)).billing.entitlementMirror,false);}});
test('expired active period mirrors existing denial instead of granting new grace',async()=>{const f=await fixture();await f.ref.collection('billing').doc('subscription').set({...input(f,'a').billing,currentPeriodEndSeconds:Math.floor(now/1000)-1});assert.equal((await readPreviewBilling(f.uid)).billing.entitlementMirror,false);});
test('another UID state never leaks; corrupted binding is unavailable',async()=>{const f=await fixture();await f.ref.collection('billing').doc('subscription').set({...input(f,'a').billing,previewFirebaseUid:'synthetic-other'});assert.deepEqual(await readPreviewBilling(f.uid),{testMode:true,syncState:'unavailable',billing:null});assert.equal((await readPreviewBilling('synthetic-unrelated')).billing,null);});
test('previous attempt billing cannot resolve a new checkout as success',async()=>{const f=await fixture();await f.ref.collection('billing').doc('subscription').set({...input(f,'a').billing,previewAttempt:'old'});assert.deepEqual(await readPreviewBilling(f.uid),{testMode:true,syncState:'pending',billing:null});});
test('operator fixture is explicit and expiring; application trial is untouched',async()=>{const f=await fixture();const production=db.doc('users/'+f.uid+'/feature_access/initial_trial_v2');await production.set({status:'active',sentinel:'unchanged'});await f.ref.collection('fixture').doc('facts').set({tag:FIXTURE_TAG,previewFirebaseUid:f.uid,expiresAt:Timestamp.fromMillis(Date.now()+3600000),scenario:'unstarted',appAccountExists:true});const facts=await readPreviewFacts(f.uid);assert.equal(facts.trial.kind,'missing');assert.equal(facts.testDataSource,'preview_fixture');assert.equal((await production.get()).get('sentinel'),'unchanged');await f.ref.collection('fixture').doc('facts').update({expiresAt:Timestamp.fromMillis(Date.now()-1)});await assert.rejects(()=>readPreviewFacts(f.uid));});
test('late signed-WebHook sync alone may read disabled or expired Auth-Emulator fixture; UID and tag stay mandatory',async()=>{
  const f=await fixture();const ref=f.ref.collection('fixture').doc('facts');
  const originalEnd=Timestamp.fromMillis(Date.now()+3*86400000);
  const facts={tag:FIXTURE_TAG,previewFirebaseUid:f.uid,enabled:false,
    authSource:'firebase-auth-emulator',expiresAt:Timestamp.fromMillis(Date.now()+3600000),
    scenario:'trialing',appAccountExists:true,
    trial:{status:'active',startedAt:Timestamp.fromMillis(originalEnd.toMillis()-21*86400000),
      endsAt:originalEnd,durationDays:21,policyVersion:'initial_trial_v2',trialId:'initial_trial_v2'}};
  await ref.set(facts);
  // Ordinary checkout requests must not revive the disabled fixture or invent an app account.
  for(const forSync of [undefined,false]){
    const appFacts=await readPreviewFacts(f.uid,forSync);
    assert.equal(appFacts.testDataSource,'app');assert.equal(appFacts.appAccountExists,false);
    assert.equal(appFacts.trial.kind,'missing');
  }
  for(const expiry of [facts.expiresAt,Timestamp.fromMillis(Date.now()-1000)]){
    await ref.update({expiresAt:expiry});
    const canonical=await readPreviewFacts(f.uid,true);
    assert.equal(canonical.testDataSource,'preview_fixture');
    assert.equal(canonical.appAccountExists,true);assert.equal(canonical.trial.kind,'found');
    assert.equal(canonical.trial.data.endsAt.toMillis(),originalEnd.toMillis());
    assert.equal(canonical.trial.data.status,'active');
    assert.equal((await readPreviewFacts(f.uid)).testDataSource,'app');
  }
  for(const corrupt of [{tag:'untrusted-tag'},{previewFirebaseUid:'synthetic-different-uid'}]){
    await ref.set({...facts,expiresAt:Timestamp.fromMillis(Date.now()-1000),...corrupt});
    await assert.rejects(()=>readPreviewFacts(f.uid,true),e=>e.code==='test_configuration_invalid');
  }
  await ref.set({...facts,authSource:'untrusted-source',expiresAt:Timestamp.fromMillis(Date.now()-1000)});
  assert.equal((await readPreviewFacts(f.uid,true)).testDataSource,'app');
  // Enabled-but-expired facts still fail closed on regular checkout; sync preserves canonical dates.
  await ref.set({...facts,enabled:true,expiresAt:Timestamp.fromMillis(Date.now()-1000)});
  assert.equal((await readPreviewFacts(f.uid,true)).trial.data.endsAt.toMillis(),originalEnd.toMillis());
  await assert.rejects(()=>readPreviewFacts(f.uid),e=>e.code==='test_configuration_invalid');
});
test('existing Rules deny guest, own and other clients every Preview root, billing, receipt and operator-fixture operation',async()=>{
  const {initializeTestEnvironment,assertFails}=require('@firebase/rules-unit-testing');
  const {doc,collection,getDoc,getDocs,setDoc,updateDoc,deleteDoc,setLogLevel}=require('firebase/firestore');
  const fs=require('node:fs');const path=require('node:path');
  const rules=await initializeTestEnvironment({projectId:'demo-hamcare-preview-rules',
    firestore:{host:'127.0.0.1',port:8287,rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});
  setLogLevel('silent');
  try{
    const owner='synthetic-rules-'+randomUUID();const subject=hash(owner);const event=hash(randomUUID());
    const paths=['preview_checkout_task4/'+subject,
      'preview_checkout_task4/'+subject+'/billing/subscription',
      'preview_checkout_task4/_events/events/'+event,
      'preview_checkout_task4/'+subject+'/fixture/facts'];
    await rules.withSecurityRulesDisabled(async context=>{
      const admin=context.firestore();
      for(const target of paths)await setDoc(doc(admin,target),{previewFirebaseUid:owner,serverOnly:true});
    });
    let denied=0;
    for(const actor of [null,owner,'synthetic-other-'+randomUUID()]){
      const client=(actor?rules.authenticatedContext(actor):rules.unauthenticatedContext()).firestore();
      for(const target of paths){
        const existing=doc(client,target);
        await assertFails(getDoc(existing));denied++;
        await assertFails(setDoc(doc(client,target+'-new'),{serverOnly:false}));denied++;
        await assertFails(setDoc(existing,{serverOnly:false}));denied++;
        await assertFails(updateDoc(existing,{serverOnly:false}));denied++;
        await assertFails(deleteDoc(existing));denied++;
      }
      for(const target of ['preview_checkout_task4',
        'preview_checkout_task4/'+subject+'/billing',
        'preview_checkout_task4/_events/events',
        'preview_checkout_task4/'+subject+'/fixture']){
        await assertFails(getDocs(collection(client,target)));denied++;
      }
    }
    assert.equal(denied,72);
  }finally{await rules.cleanup();}
});
test.after(async()=>deleteApp(app));
