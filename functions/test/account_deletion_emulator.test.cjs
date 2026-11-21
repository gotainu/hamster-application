'use strict';
const assert = require('node:assert/strict');
const {test,after} = require('node:test');
const {createHash} = require('node:crypto');
const {readFileSync} = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const admin = require('firebase-admin');
const {runAccountDeletion,retryDueAccountDeletions,accountDeletionRef} = require('../lib/accountDeletion');

assert.match(process.env.FIRESTORE_EMULATOR_HOST || '',/^127\.0\.0\.1:\d+$/,'dedicated local emulator only');
assert.notEqual(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8080');
const app=admin.initializeApp({projectId:'demo-hamcare-account-deletion'},'account-deletion-tests');
const db=app.firestore();
after(async()=>{await db.terminate();await app.delete();});
const hash=uid=>createHash('sha256').update(uid).digest('hex');
const req=(paid=false)=>({kind:'request',stopBillingConfirmed:paid});
const clock=()=>{let time=1_800_000_000_000;return {now:()=>time,advance:ms=>time+=ms};};
const ref=uid=>accountDeletionRef(db,uid);
function deps(uid,clock,extra={}) {
  return {db,now:clock.now,livemode:false,stripe:()=>assert.fail('free path loaded Stripe'),
    deleteData:async id=>{assert.equal(id,uid);await db.recursiveDelete(db.doc('users/'+id));},...extra};
}
test('free account with a 21-day trial deletes own account, no Stripe, stable tombstone',async()=>{
  const uid='free_with_trial',trial=db.doc('users/'+uid+'/feature_access/initial_trial_v2');
  await trial.set({status:'active'});await db.doc('users/other').set({name:'retained'});
  const d=deps(uid,clock());
  assert.deepEqual(await runAccountDeletion(d,uid,req()),{ok:true});
  assert.equal((await trial.get()).exists,false);
  assert.equal((await db.doc('users/other').get()).get('name'),'retained');
  assert.deepEqual(Object.keys((await ref(uid).get()).data()).sort(),['completedAt','status','version']);
  assert.deepEqual(await runAccountDeletion(d,uid,req()),{ok:true});
});
test('two concurrent requests have one delete, process can resume after Firebase failure',async()=>{
  const uid='concurrent',c=clock();let finish,start,started=new Promise(r=>start=r);
  const hold=new Promise(r=>finish=r);let calls=0;
  const d=deps(uid,c,{deleteData:async()=>{
    if (++calls===1){start();await hold;throw new Error('Auth failure');}
  }});
  const first=runAccountDeletion(d,uid,req());
  await started;
  assert.deepEqual(await runAccountDeletion(d,uid,req()),{ok:false,reason:'processing'});
  finish();await first;
  assert.equal((await ref(uid).get()).get('billingStopped'),true);
  c.advance(65_000);
  assert.deepEqual(await retryDueAccountDeletions(d),{checked:1,manual:0});
  assert.equal((await ref(uid).get()).get('status'),'completed');
  assert.equal(calls,2);
});
test('after confirmed payment cancellation Firebase failure retries cleanup without re-cancel',async()=>{
  const uid='paid_retry',c=clock(),cus='cus_retry',sid='sub_retry';let cancel=0,cleanup=0,reads=0;
  const sub={id:sid,customer:cus,status:'active',livemode:false,metadata:{firebaseUid:uid},
    items:{has_more:false,data:[{price:{id:'price_550'}}]}};
  const empty=async()=>({has_more:false,data:[]});
  const stripe={customers:{retrieve:async()=>({id:cus,livemode:false,metadata:{firebaseUid:uid}})},
    checkout:{sessions:{list:empty}},subscriptionSchedules:{list:empty},invoices:{list:empty},invoiceItems:{list:empty},
    subscriptions:{list:async()=>({has_more:false,data:[sub]}),
      retrieve:async()=>{reads++;return sub;},cancel:async(id,params)=>{
        assert.equal(id,sid);assert.deepEqual(params,{invoice_now:false,prorate:false});cancel++;sub.status='canceled';
      }}};
  await db.doc('users/'+uid+'/billing/subscription').set({firebaseUid:uid,stripeCustomerId:cus,stripeSubscriptionId:sid});
  const d=deps(uid,c,{stripe:()=>({stripe,livemode:false,priceId:'price_550'}),
    deleteData:async()=>{assert.ok(reads>=1);if(++cleanup===1)throw Error('Auth failed');}});
  await assert.rejects(runAccountDeletion(d,uid,req()),{reason:'paid_confirmation_required'});
  assert.equal((await ref(uid).get()).exists,false);assert.equal(cancel,0);assert.equal(cleanup,0);
  assert.equal((await runAccountDeletion(d,uid,req(true))).reason,'processing');
  c.advance(65000);
  assert.deepEqual(await runAccountDeletion(d,uid,{kind:'retry'}),{ok:true});
  assert.equal(cancel,1);assert.equal(cleanup,2);
});
test('lost worker lease reclaimed without login and final manual handoff is bounded',async()=>{
  const uid='worker_lease',c=clock();let calls=0;
  await ref(uid).set({uid,version:1,status:'running',lease:'lost',billingStopped:true,paidConfirmed:true,
    attempt:11,requestedAt:c.now()-700000,dueAt:c.now()-1});
  const d=deps(uid,c,{deleteData:async()=>{calls++;throw new Error('unavailable');}});
  assert.deepEqual(await retryDueAccountDeletions(d),{checked:1,manual:1});
  assert.equal((await ref(uid).get()).get('status'),'manual_review');
  assert.deepEqual(await retryDueAccountDeletions(d),{checked:0,manual:0});assert.equal(calls,1);
});
test('unsafe binding preserves all Firebase data and stops request for operator review',async()=>{
  const uid='mismatch',c=clock();
  await db.doc('billing_customers/'+hash(uid)).set({firebaseUid:'different',customerId:'cus_other'});
  let deleted=0;
  const d=deps(uid,c,{deleteData:async()=>deleted++});
  assert.deepEqual(await runAccountDeletion(d,uid,req(true)),{ok:false,reason:'manual_review'});
  assert.equal(deleted,0);
});
test('actual cleanup traverses owned pet and records, deletes only fixed photo before Auth', async()=>{
  const source=readFileSync(path.resolve(__dirname,'../src/index.ts'),'utf8');
  const helpers=source.slice(source.indexOf('function createDeepDeleteStats()'),source.indexOf('function mean('));
  const start=source.indexOf('  async deleteData(uid:string)');
  const finish=source.indexOf('\n};',start);
  assert.ok(start>=0 && finish>start);
  const code=ts.transpileModule(helpers+'\nreturn ({'+source.slice(start,finish)+'}).deleteData;',
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
  const uid='own_cleanup',other='other_cleanup';
  const dbPaths=id=>['users/'+id,'users/'+id+'/pet_profiles/main_pet','users/'+id+'/care_records/day','switchbot_users/'+id,'billing_contacts/'+id];
  for(const id of [uid,other])for(const p of dbPaths(id))await db.doc(p).set({keep:id===other});
  const trace=[];
  let fail=true;
  const fakeAdmin={storage:()=>({bucket:()=>({file:object=>({delete:async options=>{
    trace.push(object);assert.deepEqual(options,{ignoreNotFound:true});if(fail)throw new Error('retry storage');
  }})})}),auth:()=>({deleteUser:async id=>trace.push('auth:'+id)})};
  const clean=vm.runInThisContext('(function(db,admin,blockAnalyticsEventsForDeletion,blockSensorCaptureForDeletion){'+code+'})')(
    db,fakeAdmin,async()=>{},async()=>{});
  await assert.rejects(clean(uid),/retry storage/);
  assert.deepEqual(trace,['hamster_images/'+uid+'-main_pet.jpg']);
  assert.equal((await db.doc('users/'+uid).get()).exists,true);
  fail=false;await clean(uid);
  assert.equal(trace.at(-1),'auth:'+uid);
  for(const p of dbPaths(uid))assert.equal((await db.doc(p).get()).exists,false);
  for(const p of dbPaths(other))assert.equal((await db.doc(p).get()).exists,true);
});
