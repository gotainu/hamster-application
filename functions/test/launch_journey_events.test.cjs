'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), ts = require('typescript');
function loadSources(admin = {}) {
  const cache = new Map();
  const trigger = (options, fn) => Object.assign(fn, {__triggerOptions: options});
  function load(file) {
    if (cache.has(file)) return cache.get(file).exports;
    const mod = {exports: {}}; cache.set(file, mod);
    const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {target:ts.ScriptTarget.ES2020, module:ts.ModuleKind.CommonJS, esModuleInterop:true}}).outputText;
    const req = name => name === 'firebase-admin' ? admin : name === 'firebase-functions/v1' ?
      {region: () => ({runWith:options => ({auth:{user:() => ({onCreate:fn => trigger(options, fn)})}})})} :
      name === 'firebase-functions/v2/firestore' ? {onDocumentCreated:trigger, onDocumentUpdated:trigger, onDocumentWritten:trigger} :
        name.startsWith('.') ? load(path.resolve(path.dirname(file), name+'.ts')) : require(name);
    vm.runInThisContext(`(function(exports,require,module){${code}\n})`,{filename:file})(mod.exports,req,mod);
    return mod.exports;
  }
  return name => load(path.resolve(__dirname, '../src', name+'.ts'));
}
const load = loadSources();
const journey = load('analyticsJourneyEvents'), {classifyAnalytics} = load('analyticsClassification');
function env(values, fn) {
  const names = ['ANALYTICS_ENVIRONMENT','ANALYTICS_TEST_UIDS','TRIAL_TEST_UIDS','FUNCTIONS_EMULATOR','FIRESTORE_EMULATOR_HOST'];
  const before = Object.fromEntries(names.map(k=>[k,process.env[k]]));
  for (const k of names) {if (values[k] === undefined) delete process.env[k]; else process.env[k] = values[k];}
  try {return fn();} finally {for(const k of names) {if(before[k]===undefined)delete process.env[k]; else process.env[k]=before[k];}}
}
const at = new Date('2026-10-01T03:00:00Z');
const base = {ownerUid:'synthetic_user',acceptedAt:at,recordRevision:1,inputRoute:'weight_manual',operation:'create',values:{weightGrams:100}};
test('classification defaults unknown, live must be explicit and test identities are server classified',()=>{
  env({},()=>assert.deepEqual(classifyAnalytics('synthetic_user'),{environment:'unknown',accountClassification:'unknown',billingLivemode:null}));
  env({ANALYTICS_ENVIRONMENT:'live'},()=>assert.equal(classifyAnalytics('synthetic_user').accountClassification,'general'));
  env({ANALYTICS_ENVIRONMENT:'live',ANALYTICS_TEST_UIDS:'synthetic_user'},()=>assert.equal(classifyAnalytics('synthetic_user').environment,'test'));
  env({ANALYTICS_ENVIRONMENT:'live',TRIAL_TEST_UIDS:'synthetic_user'},()=>assert.equal(classifyAnalytics('synthetic_user').environment,'test'));
  env({ANALYTICS_ENVIRONMENT:'live'},()=>assert.equal(classifyAnalytics('synthetic_user',{billingLivemode:false}).environment,'test'));
  env({ANALYTICS_ENVIRONMENT:'live',FUNCTIONS_EMULATOR:'true'},()=>assert.equal(classifyAnalytics('synthetic_user').environment,'emulator'));
});
test('metadata of real manual save contains only record kind and trusted acceptance, no measurement or answer',()=>{
  const result=journey.validRecordMetadata('weight',{...base,memo:'private health note'},'synthetic_user');
  assert.deepEqual(result,{eventName:'valid_record_saved',actor:'user_client',source:'manual',recordType:'weight',occurredAt:at,serverReceivedAt:at});
  assert.ok(!JSON.stringify(result).includes('100'));assert.ok(!JSON.stringify(result).includes('private'));
});
test('cancellation, other owner, malformed acceptance, sensor route and invalid numeric values are not active use',()=>{
  for(const change of [{operation:'cancel'},{ownerUid:'another'},{acceptedAt:null},{inputRoute:'switchbot'},{values:{weightGrams:NaN}},{values:{weightGrams:0}}])
    assert.equal(journey.validRecordMetadata('weight',{...base,...change},'synthetic_user'),null);
});
test('zero manual distance is active use, absent distance is not',()=>{
  assert.ok(journey.validRecordMetadata('activity',{...base,inputRoute:'wheel_rotations_manual',values:{distance:0}},'synthetic_user'));
  assert.equal(journey.validRecordMetadata('activity',{...base,inputRoute:'wheel_rotations_manual',values:{}},'synthetic_user'),null);
});
test('explicit observation works while cancellation fallback and auto normal alone do not',()=>{
  const obs={...base,revision:2,operation:'correction',answer:{condition:'normal',answerProvenance:{overall:'explicit_submission'}}};
  assert.ok(journey.validRecordMetadata('daily_checkin',obs,'synthetic_user'));
  assert.equal(journey.validRecordMetadata('daily_checkin',{...obs,operation:'cancel'},'synthetic_user'),null);
  assert.equal(journey.validRecordMetadata('daily_checkin',{...obs,answer:{condition:'normal'}},'synthetic_user'),null);
});
test('care explicit non-performance counts, unconfirmed default and cancelled care do not',()=>{
  const care={...base,revision:2,status:'active',inputRoute:'daily_checkin',actions:{synthetic_care:{answer:'not_performed',answerProvenance:'batch_confirmation'}}};
  assert.ok(journey.validRecordMetadata('care_action',care,'synthetic_user'));
  assert.equal(journey.validRecordMetadata('care_action',{...care,status:'cancelled'},'synthetic_user'),null);
  assert.equal(journey.validRecordMetadata('care_action',{...care,actions:{x:{answer:'unanswered',answerProvenance:'unanswered'}}},'synthetic_user'),null);
  assert.equal(journey.validRecordMetadata('care_action',{...care,actions:{x:{answer:'not_performed',answerProvenance:'legacy_unspecified'}}},'synthetic_user'),null);
});
test('billing events derive committed status transitions, duplicate sync is not activation',()=>{
  const active={provider:'stripe',stripeSubscriptionId:'synthetic_sub',stripeLivemode:false,plan:'paid',status:'active',cancelAtPeriodEnd:false};
  assert.deepEqual(journey.billingJourneyTransitions(null,active,at),['subscription_activated']);
  assert.deepEqual(journey.billingJourneyTransitions(active,{...active,updatedAt:at},at),[]);
  const cancel={...active,cancelAtPeriodEnd:true};
  assert.deepEqual(journey.billingJourneyTransitions(active,cancel,at),['subscription_cancel_scheduled']);
  assert.deepEqual(journey.billingJourneyTransitions(cancel,cancel,at),[]);
  assert.deepEqual(journey.billingJourneyTransitions(cancel,{...cancel,plan:'none',status:'canceled'},at),['subscription_ended']);
  assert.deepEqual(journey.billingJourneyTransitions(active,{...active,plan:'none',status:'past_due'},at),['subscription_payment_failed']);
  assert.deepEqual(journey.billingJourneyTransitions(null,{...active,status:'trialing'},at),[]);
  assert.deepEqual(journey.billingJourneyTransitions(active,null,at),[]);
});
test('immutable revision paths avoid day-index copies, projection fallback and background streams',()=>{
  assert.equal(journey.analyticsObservationRevisionAccepted.__triggerOptions.document,'users/{uid}/observation_days/{dayKey}/revisions/{revisionId}');
  assert.match(journey.analyticsWeightRevisionAccepted.__triggerOptions.document,/weight_record_history/);
  assert.ok(!journey.analyticsWeightRevisionAccepted.__triggerOptions.document.includes('weight_record_days'));
});
function fakeDb() {
  const docs=new Map();let tail=Promise.resolve();
  return {docs,doc:path=>({path}),runTransaction(fn){const run=tail.then(async()=>{const pending=[];await fn({get:async ref=>({exists:docs.has(ref.path),get:key=>docs.get(ref.path)?.[key]}),set:(ref,data,opt)=>pending.push(['set',ref.path,opt?.merge?{...docs.get(ref.path),...data}:data]),create:(ref,data)=>pending.push(['create',ref.path,data])});for(const[op,p,d]of pending){if(op==='create')assert.ok(!docs.has(p));docs.set(p,d);}});tail=run.catch(()=>{});return run;}};
}
test('same retry and parallel delivery create one metadata row, unique source revisions remain distinct',async()=>{
  const db=fakeDb(),p={db,uid:'synthetic_user',id:'fixed',sourcePath:'users/synthetic_user/synthetic_source/accepted',data:{eventName:'valid_record_saved',occurredAt:at}};
  db.docs.set(p.sourcePath,{acceptedAt:at});
  await Promise.all([journey.saveJourneyMetadata(p),journey.saveJourneyMetadata(p),journey.saveJourneyMetadata(p)]);
  assert.equal(db.docs.size,2);assert.equal(db.docs.get('users/synthetic_user/journey_events/fixed').occurredAt,at);
  await journey.saveJourneyMetadata({...p,id:'next_revision'});assert.equal(db.docs.size,3);
});
test('billing observer replay emits one row and uses committed update time rather than trigger time',async()=>{
  const db=fakeDb(),sdk=loadSources({firestore:()=>db})('analyticsJourneyEvents');
  const after={provider:'stripe',stripeSubscriptionId:'synthetic_sub',plan:'paid',status:'active',stripeLivemode:false};
  db.docs.set('users/synthetic_user/billing/subscription',after);
  const event={id:'synthetic_cloud_event',params:{uid:'synthetic_user'},data:{before:{data:()=>undefined},after:{data:()=>after,updateTime:at,ref:{path:'users/synthetic_user/billing/subscription'}}}};
  await Promise.all([sdk.analyticsSubscriptionCommitted(event),sdk.analyticsSubscriptionCommitted(event)]);
  assert.equal(db.docs.size,2);const data=[...db.docs.entries()].find(([p])=>p.includes('/journey_events/'))[1];assert.equal(data.billingLivemode,false);assert.equal(data.occurredAt,at);
  assert.ok(!JSON.stringify(data).includes('synthetic_sub'));
});
test('BQ row exports classification and join metadata without arbitrary source fields',()=>{
  const {serverEventRow}=loadSources()('bigqueryServerEvents');
  env({ANALYTICS_ENVIRONMENT:'live'},()=>{
    const row=serverEventRow({uid:'synthetic_user',sourceCollection:'journey_events',eventId:'a',data:{eventName:'subscription_activated',occurredAt:at,billingLivemode:false,memo:'private',response:{text:'private'}}});
    assert.equal(row.environment,'test');assert.equal(row.account_classification,'test');assert.equal(row.billing_livemode,false);assert.equal(row.event_at,at.toISOString());
    assert.ok(!JSON.stringify(row).includes('private'));assert.ok(!Object.keys(row).includes('response'));
  });
});
test('registration uses Auth creation time and fixed event ID without writing profile or trial',async()=>{
  const db=fakeDb(),sdk=loadSources({firestore:()=>db,auth:()=>({getUser:async()=>({metadata:{creationTime:at.toISOString()},disabled:false})})})('analyticsJourneyEvents');
  const user={uid:'synthetic_user',metadata:{creationTime:at.toISOString()},email:'private@example.invalid'};
  await Promise.all([sdk.analyticsAccountRegistered(user),sdk.analyticsAccountRegistered(user)]);
  assert.equal(db.docs.size,1);const data=[...db.docs.values()][0];assert.equal(data.eventName,'account_registered');assert.equal(data.occurredAt.toISOString(),at.toISOString());assert.ok(!JSON.stringify(data).includes('private'));
});
test('Stripe sync records trusted remote livemode metadata without changing authorization semantics',async()=>{
  for(const mode of [false,true,undefined]) {
    let saved;
    const admin={firestore:{Timestamp:{fromMillis:ms=>({toMillis:()=>ms})},FieldValue:{serverTimestamp:()=>at}}};
    const sync=loadSources(admin)('stripeSubscriptionSync').syncStripeSubscription;
    const sub={id:'synthetic_sub',status:'active',livemode:mode,customer:'synthetic_customer',cancel_at_period_end:false,cancel_at:null,current_period_end:1918425600,items:{data:[{price:{id:'synthetic_price',product:'synthetic_product'}}]}};
    const db={doc:()=>({get:async()=>({exists:false}),create:async data=>{saved=data;}})};
    await sync({db,stripe:{subscriptions:{retrieve:async()=>sub}},uid:'synthetic_user',subscriptionId:sub.id});
    assert.equal(saved.stripeLivemode,mode??null);assert.equal(saved.plan,'paid');assert.equal(saved.status,'active');
  }
});
test('late record or billing metadata after source deletion is skipped without recreating journey data',async()=>{
  for(const sourcePath of ['users/synthetic_user/weight_record_history/r/revisions/0000000001','users/synthetic_user/billing/subscription']) {
    const db=fakeDb();
    await journey.saveJourneyMetadata({db,uid:'synthetic_user',id:'late_event',sourcePath,data:{eventName:'valid_record_saved',occurredAt:at}});
    assert.equal(db.docs.size,0);
  }
});
test('late Auth event after deletion or changed Auth identity does not recreate registration metadata',async()=>{
  for(const getUser of [async()=>{throw Object.assign(new Error('deleted'),{code:'auth/user-not-found'});},async()=>({metadata:{creationTime:'2026-10-02T03:00:00Z'},disabled:false}),async()=>({metadata:{creationTime:at.toISOString()},disabled:true})]) {
    const db=fakeDb(),sdk=loadSources({firestore:()=>db,auth:()=>({getUser})})('analyticsJourneyEvents');
    await sdk.analyticsAccountRegistered({uid:'synthetic_user',metadata:{creationTime:at.toISOString()}});
    assert.equal(db.docs.size,0);
  }
});
test('transient Auth lookup errors fail for retry rather than writing unverified registration',async()=>{
  const db=fakeDb(),sdk=loadSources({firestore:()=>db,auth:()=>({getUser:async()=>{throw new Error('temporary');}})})('analyticsJourneyEvents');
  await assert.rejects(()=>sdk.analyticsAccountRegistered({uid:'synthetic_user',metadata:{creationTime:at.toISOString()}}),/temporary/);
  assert.equal(db.docs.size,0);
});
test('deletion-start fence blocks new record/billing and Auth rows while sources and Auth still exist',async()=>{
  const db=fakeDb();
  const sdk=loadSources({firestore:Object.assign(()=>db,{FieldValue:{serverTimestamp:()=>at}}),auth:()=>({getUser:async()=>({metadata:{creationTime:at.toISOString()},disabled:false})})})('analyticsJourneyEvents');
  const sourcePath='users/synthetic_user/billing/subscription';db.docs.set(sourcePath,{provider:'stripe'});
  await sdk.blockAnalyticsEventsForDeletion(db,'synthetic_user');
  await sdk.blockAnalyticsEventsForDeletion(db,'synthetic_user');
  assert.equal(db.docs.get('users/synthetic_user').analyticsDeletionStartedAt,at);
  await sdk.saveJourneyMetadata({db,uid:'synthetic_user',id:'blocked',sourcePath,data:{eventName:'subscription_activated'}});
  await sdk.analyticsAccountRegistered({uid:'synthetic_user',metadata:{creationTime:at.toISOString()}});
  assert.equal([...db.docs.keys()].filter(p=>p.includes('/journey_events/')).length,0);
});
test('owner-root transaction dependency retries safely if deletion begins during Auth verification',async()=>{
  const sourcePath='users/synthetic_user';const docs=new Map();let attempt=0,authReads=0;
  const db={doc:path=>({path}),async runTransaction(fn){
    while(++attempt<=2) {
      const pending=[],reads=[];
      await fn({get:async ref=>{reads.push(ref.path);return{exists:docs.has(ref.path),get:key=>docs.get(ref.path)?.[key]};},create:(ref,value)=>pending.push([ref.path,value])});
      assert.ok(reads.includes(sourcePath),'owner root must participate in every transaction attempt');
      if(attempt===1){docs.set(sourcePath,{analyticsDeletionStartedAt:at});continue;}
      for(const[p,v]of pending)docs.set(p,v);
    }
  }};
  const sdk=loadSources({firestore:()=>db,auth:()=>({getUser:async()=>{authReads++;return{metadata:{creationTime:at.toISOString()},disabled:false};}})})('analyticsJourneyEvents');
  await sdk.analyticsAccountRegistered({uid:'synthetic_user',metadata:{creationTime:at.toISOString()}});
  assert.equal(authReads,1);assert.equal([...docs.keys()].filter(p=>p.includes('/journey_events/')).length,0);
});
function loadDeletionHelper(deleteCollectionDeep) {
  const file=path.resolve(__dirname,'../src/index.ts');
  const source=ts.createSourceFile(file,fs.readFileSync(file,'utf8'),ts.ScriptTarget.ES2020,true);
  const declaration=source.statements.find(n=>ts.isFunctionDeclaration(n)&&n.name?.text==='deleteDocumentDeep');
  assert.ok(declaration,'exercise real production cleanup helper, not a duplicated implementation');
  const code=ts.transpileModule(declaration.getText(source),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  return vm.runInNewContext(`${code}\ndeleteDocumentDeep`,{deleteCollectionDeep});
}
test('account root deletion waits for descendant cleanup and Auth deletion callback',async()=>{
  const calls=[],helper=loadDeletionHelper(async sub=>calls.push('descendant:'+sub.id));
  const doc={path:'users/synthetic_user',listCollections:async()=>[{id:'journey_events'}],delete:async()=>calls.push('root_deleted')};
  const stats={deletedDocuments:0,deletedRootDocuments:[]};
  await helper(doc,stats,async()=>{calls.push('auth_deleted');return true;});
  assert.deepEqual(calls,['descendant:journey_events','auth_deleted','root_deleted']);assert.equal(stats.deletedDocuments,1);
});
test('data-only cleanup or Auth deletion failure retains deletion fence and cannot reopen metadata writes',async()=>{
  for(const callback of [async()=>false,async()=>{throw new Error('auth_failed');}]) {
    const calls=[],helper=loadDeletionHelper(async()=>{});
    const doc={path:'users/synthetic_user',listCollections:async()=>[],delete:async()=>calls.push('root_deleted')};
    const stats={deletedDocuments:0,deletedRootDocuments:[]};
    try{await helper(doc,stats,callback);}catch(error){assert.equal(error.message,'auth_failed');}
    assert.deepEqual(calls,[]);assert.equal(stats.deletedDocuments,0);
  }
});
test('BQ retries preserve historical unknown/test/emulator stamps after configuration or registry changes',()=>{
  const {serverEventRow}=loadSources()('bigqueryServerEvents');
  function row(stamp) {return serverEventRow({uid:'synthetic_user',sourceCollection:'journey_events',eventId:'stamped',data:{eventName:'account_registered',occurredAt:at,...stamp}});}
  env({ANALYTICS_ENVIRONMENT:'live'},()=>{
    const unknown=row({environment:'unknown',accountClassification:'unknown'});
    assert.equal(unknown.environment,'unknown');assert.equal(unknown.account_classification,'unknown');
    const priorTest=row({environment:'test',accountClassification:'test'});
    assert.equal(priorTest.environment,'test');assert.equal(priorTest.account_classification,'test');assert.equal(priorTest.test_only,true);
    assert.equal(row({environment:'emulator',accountClassification:'test'}).environment,'emulator');
    assert.equal(row({environment:'live',accountClassification:'unknown'}).account_classification,'unknown');
  });
  env({ANALYTICS_ENVIRONMENT:'unknown',ANALYTICS_TEST_UIDS:'synthetic_user'},()=>{
    const previouslyLive=row({environment:'live',accountClassification:'general'});
    assert.equal(previouslyLive.environment,'test');assert.equal(previouslyLive.account_classification,'test');
  });
  env({ANALYTICS_ENVIRONMENT:'unknown'},()=>{
    assert.equal(row({environment:'live',accountClassification:'general'}).environment,'live');
  });
});
test('billing activation respects committed-time expiry and can recover active state with a renewed valid period',()=>{
  const active={provider:'stripe',stripeSubscriptionId:'synthetic_sub',plan:'paid',status:'active',cancelAtPeriodEnd:false};
  const before=new Date(at.getTime()-1),after=new Date(at.getTime()+1);
  assert.deepEqual(journey.billingJourneyTransitions(null,{...active,currentPeriodEnd:before},at),[]);
  assert.deepEqual(journey.billingJourneyTransitions(null,{...active,currentPeriodEnd:at},at),[]);
  assert.deepEqual(journey.billingJourneyTransitions(null,{...active,currentPeriodEnd:after},at),['subscription_activated']);
  assert.deepEqual(journey.billingJourneyTransitions(null,{...active,currentPeriodEnd:'invalid'},at),[]);
  assert.deepEqual(journey.billingJourneyTransitions({...active,currentPeriodEnd:before},{...active,currentPeriodEnd:after},at),['subscription_activated']);
  assert.deepEqual(journey.billingJourneyTransitions({...active,currentPeriodEnd:after},{...active,currentPeriodEnd:new Date(at.getTime()+1000)},at),[]);
  assert.deepEqual(journey.billingJourneyTransitions(null,{...active,currentPeriodEnd:null},at),['subscription_activated']);
});
