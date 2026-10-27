"use strict";
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test, before, after} = require('node:test');
const ts = require('typescript');
const admin = require('firebase-admin');
const HOST=process.env.FIRESTORE_EMULATOR_HOST;
assert.match(HOST??'',/^127\.0\.0\.1:\d+$/,'Dedicated localhost emulator required');
assert.notEqual(HOST,'127.0.0.1:8080');
const PROJECT='demo-hamcare-environment-history';
const now=new Date('2026-10-12T01:00:00Z');
let app,db,history;
function load(file,cache=new Map()) {
  if(cache.has(file)) return cache.get(file).exports;
  const mod={exports:{}};cache.set(file,mod);
  const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
  const ownRequire=name=>name==='firebase-functions/v2/https'?{
    HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}},
    onCall:(_options,fn)=>fn,
  }:name.startsWith('.')?load(path.resolve(path.dirname(file),name+'.ts'),cache):require(name);
  vm.runInThisContext(`(function(exports,require,module){${code}\n})`,{filename:file})(mod.exports,ownRequire,mod);
  return mod.exports;
}
const values={cageWidth:'60',cageDepth:'40',cageHeight:'50',beddingThickness:'10',wheelDiameter:'20',temperatureControl:'エアコン',accessoryTags:['隠れ家','砂場']};
const payload=(extra={})=>({values:{...values},expectedRevision:0,mutationId:'environment-mutation-0001',operation:'change',effective:{precision:'unknown'},...extra});
const root=uid=>db.doc(`users/${uid}/breeding_environments/main_env`);
const run=(uid,data=payload(),accepted=now)=>history.saveEnvironmentMutation({db,uid,data,now:accepted});
const canonical=x=>x&&typeof x.toMillis==='function'?[x.seconds,x.nanoseconds]:Array.isArray(x)?x.map(canonical):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])])):x;
const snapshot=async ref=>{const s=await ref.get();return{exists:s.exists,data:canonical(s.data()),updateTime:s.updateTime?canonical(s.updateTime):null};};
// Historical timestamps are fixture data, never a production acceptance override.
async function seedInitial(uid,accepted='2026-10-09T03:00:00Z') {
  const stamp=admin.firestore.Timestamp.fromDate(new Date(accepted));
  const initial={schemaVersion:1,ownerUid:uid,petId:'main_pet',revision:1,previousRevision:0,kind:'initial_snapshot',targetRevision:null,
    effective:{precision:'unknown',dateKey:null,occurredAt:null},acceptedAt:stamp,mutationId:'environment-fixture-initial',
    rawValues:{...values},values:history.normalizeEnvironmentValues(values),changes:{},auxiliaryFieldsChanged:[],initialBatch:false};
  const batch=db.batch();
  batch.set(root(uid),{...values,environmentHistorySchemaVersion:1,ownerUid:uid,petId:'main_pet',revision:1,acceptedAt:stamp,updatedAt:stamp});
  batch.set(root(uid).collection('revisions').doc('0000000001'),initial);await batch.commit();
}
async function seedActualChange(uid,revision,before,after,occurredAt,accepted) {
  const stamp=admin.firestore.Timestamp.fromDate(new Date(accepted));
  const normalizedInstant=new Date(occurredAt).toISOString();
  const normalizedDateKey=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Tokyo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(occurredAt));
  const changes=Object.fromEntries(Object.keys(after).map(key=>[key,{before:history.normalizeEnvironmentValues(before)[key],after:history.normalizeEnvironmentValues(after)[key]}]));
  const event={schemaVersion:1,ownerUid:uid,petId:'main_pet',revision,previousRevision:revision-1,kind:'change',targetRevision:null,
    effective:{precision:'instant',dateKey:normalizedDateKey,occurredAt:normalizedInstant},acceptedAt:stamp,mutationId:'environment-fixture-'+revision,
    beforeRawValues:before,rawValues:after,values:history.normalizeEnvironmentValues(after),changes,auxiliaryFieldsChanged:[],initialBatch:false};
  const batch=db.batch();batch.set(root(uid),{...after,revision,acceptedAt:stamp,updatedAt:stamp},{merge:true});
  batch.set(root(uid).collection('revisions').doc(String(revision).padStart(10,'0')),event);await batch.commit();
}
before(async()=>{
  const response=await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,{method:'DELETE'});assert.ok(response.ok);
  app=admin.initializeApp({projectId:PROJECT},'environment-history-'+process.pid);db=admin.firestore(app);db.settings({host:HOST,ssl:false});
  history=load(path.resolve(__dirname,'../src/environmentHistory/environmentHistory.ts'));
});
after(async()=>{if(db)await db.terminate();if(app)await app.delete();});
test('first explicit save atomically commits current, one initial snapshot and receipt without inventing earlier origin',async()=>{
  const uid='environment-initial';
  await db.doc(`users/${uid}`).set({has_subcollections:false,displayName:'preserved fixture'});
  await root(uid).set({...values,accessoryNote:'private memo',sensorToken:'must not copy',customLegacyField:'preserve'});
  const result=await run(uid);assert.equal(result.saved,true);assert.equal(result.revision,1);
  const current=await root(uid).get();assert.equal(current.get('wheelDiameter'),'20');assert.equal(current.get('customLegacyField'),'preserve');
  const owner=await db.doc(`users/${uid}`).get();assert.equal(owner.get('has_subcollections'),true);assert.equal(owner.get('displayName'),'preserved fixture');
  assert.equal(current.get('revision'),1);
  const revisions=await root(uid).collection('revisions').get(),receipts=await root(uid).collection('mutations').get();
  assert.equal(revisions.size,1);assert.equal(receipts.size,1);
  const text=JSON.stringify(canonical(revisions.docs[0].data()));
  assert.ok(!text.includes('must not copy'));assert.ok(!text.includes('private memo'));
  assert.equal(revisions.docs[0].get('ownerUid'),uid);assert.equal(revisions.docs[0].get('petId'),'main_pet');
  assert.ok(revisions.docs[0].get('acceptedAt') instanceof admin.firestore.Timestamp);
  const past=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-11T01:00:00Z')});
  assert.equal(past.values.wheelDiameter.value,null);assert.ok(past.quality.reasons.includes('before_initial_confirmation'));
});
test('same mutation concurrent retries create one history/receipt and retain immutable acceptance',async()=>{
  const uid='environment-retry';await root(uid).set(values);
  const results=await Promise.all(Array.from({length:6},()=>run(uid)));
  assert.equal(results.filter(x=>!x.replayed).length,1);assert.ok(results.every(x=>x.revision===1));
  assert.equal((await root(uid).collection('revisions').get()).size,1);assert.equal((await root(uid).collection('mutations').get()).size,1);
  const first=await snapshot(root(uid).collection('revisions').doc('0000000001'));
  assert.equal((await run(uid)).replayed,true);assert.deepEqual(await snapshot(root(uid).collection('revisions').doc('0000000001')),first);
});
test('no meaningful change issues receipt without another history revision or current overwrite',async()=>{
  const uid='environment-noop';await root(uid).set(values);await run(uid);
  const before=await snapshot(root(uid));
  const next=await run(uid,payload({expectedRevision:1,mutationId:'environment-mutation-0002'}));
  assert.equal(next.changed,false);assert.equal(next.revision,1);assert.equal((await root(uid).collection('revisions').get()).size,1);
  assert.equal((await root(uid).collection('mutations').get()).size,2);assert.deepEqual(await snapshot(root(uid)),before);
});
test('mutation ID payload mismatch rejected without writes; replay after newer save cannot roll current back',async()=>{
  const uid='environment-id';await root(uid).set(values);const original=payload();await run(uid,original);
  const changed=payload({values:{...values,wheelDiameter:'28'},expectedRevision:1,mutationId:'environment-mutation-0002',effective:{precision:'date_only',dateKey:'2026-10-12'}});
  await run(uid,changed);const before=await snapshot(root(uid));
  await assert.rejects(run(uid,payload({values:{...values,wheelDiameter:'30'}})),x=>x.code==='already-exists');
  assert.equal((await run(uid,original)).replayed,true);assert.deepEqual(await snapshot(root(uid)),before);
});
test('parallel distinct edits detect expectedRevision conflict and do not silently lose a save',async()=>{
  const uid='environment-conflict';await root(uid).set(values);await run(uid);
  const results=await Promise.allSettled([
    run(uid,payload({values:{...values,wheelDiameter:'28'},expectedRevision:1,mutationId:'environment-mutation-race1'})),
    run(uid,payload({values:{...values,beddingThickness:'25'},expectedRevision:1,mutationId:'environment-mutation-race2'})),
  ]);
  assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
  assert.equal(results.find(x=>x.status==='rejected').reason.code,'aborted');
  assert.equal((await root(uid).collection('revisions').get()).size,2);assert.equal((await root(uid).collection('mutations').get()).size,2);
});
test('failed transaction commits neither projection, history nor receipt',async()=>{
  const uid='environment-atomic-failure';await root(uid).set(values);await run(uid);const before=await snapshot(root(uid));
  const failingDb={doc:p=>db.doc(p),collection:p=>db.collection(p),runTransaction:fn=>db.runTransaction(async tx=>{await fn(tx);throw new Error('forced test transaction abort');})};
  await assert.rejects(history.saveEnvironmentMutation({db:failingDb,uid,data:payload({values:{...values,wheelDiameter:'28'},expectedRevision:1,mutationId:'environment-mutation-fail'}),now}),/forced test transaction abort/);
  assert.deepEqual(await snapshot(root(uid)),before);assert.equal((await root(uid).collection('revisions').get()).size,1);assert.equal((await root(uid).collection('mutations').get()).size,1);
});
test('environment saves do not alter care, rewards, distance conversion, assessments or frozen reports',async()=>{
  const uid='environment-protection';await root(uid).set(values);
  const records={
    'daily_care_actions/2026-10-12':{revision:1,actions:{cageCleaning:{details:{beddingReplacement:'partial'}}}},
    'rewards/continuity':{balance:8},'rewards/stars':{total:100},
    'distance_records/2026-10-11':{rotations:1000,wheelDiameterCm:20,distance:628.3185307179587},
    'personalized_reports/first':{generation:{status:'generated'},readyMetrics:['body'],analysisRevision:1},
    'personality_reports/personality_v1_body':{readyMetrics:['body']},
    'personality_reports/daily_2026-10-11':{readyMetrics:['body','activity']},
    'analysis_readiness/body':{currentStatus:'ready'},'analysis_readiness/activity':{currentStatus:'ready'},
    'daily_health_features/2026-10-12':{body:{personalBaseline:{median:100}}},
    'health_assessments/latest':{score:100},'billing/subscription':{plan:'paid',status:'active'},
    'feature_access/initial_trial_v2':{status:'active',aiRequestUsed:1,aiCostMicrosUsed:50000},
    'app_state/onboarding':{firstAiConsultationCompleted:true},'integrations/switchbot_secrets':{token:'unchanged'},
  };
  const refs=Object.keys(records).map(p=>db.doc(`users/${uid}/${p}`));
  for(const [p,data] of Object.entries(records))await db.doc(`users/${uid}/${p}`).set(data);
  const before=await Promise.all(refs.map(snapshot));await run(uid);await run(uid,payload({values:{...values,wheelDiameter:'28'},expectedRevision:1,mutationId:'environment-mutation-0002'}));
  assert.deepEqual(await Promise.all(refs.map(snapshot)),before);
  assert.equal((await db.collection(`users/${uid}/daily_checkins`).get()).size,0);
});
test('existing recursive account deletion covers nested environment history and receipts',async()=>{
  const uid='environment-account-delete';await db.doc(`users/${uid}`).set({has_subcollections:true});await root(uid).set(values);await run(uid);
  await db.doc('users/environment-account-kept/breeding_environments/main_env').set(values);
  const source=fs.readFileSync(path.resolve(__dirname,'../src/index.ts'),'utf8');
  const start=source.indexOf('function createDeepDeleteStats()'),end=source.indexOf('function mean(',start);
  assert.ok(start>=0&&end>start);
  const code=ts.transpileModule(source.slice(start,end),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const api=vm.runInThisContext(`(function(db){${code}\nreturn {deleteDocumentDeep,createDeepDeleteStats};})`)(db);
  await api.deleteDocumentDeep(db.doc(`users/${uid}`),api.createDeepDeleteStats());
  assert.equal((await root(uid).get()).exists,false);assert.equal((await root(uid).collection('revisions').get()).size,0);assert.equal((await root(uid).collection('mutations').get()).size,0);
  assert.equal((await db.doc('users/environment-account-kept/breeding_environments/main_env').get()).exists,true);
});
test('late actual change is available retrospectively and excluded before server knowledge cutoff',async()=>{
  const uid='environment-late-entry';await seedInitial(uid);
  await run(uid,payload({values:{...values,wheelDiameter:'28'},expectedRevision:1,mutationId:'environment-mutation-late',effective:{precision:'instant',occurredAt:'2026-10-10T05:00:00Z'}}));
  const observedAt=new Date('2026-10-11T03:00:00Z');
  const then=await history.readEnvironmentAt({db,uid,observedAt,knowledgeCutoff:new Date('2026-10-11T03:00:00Z')});
  const retrospective=await history.readEnvironmentAt({db,uid,observedAt});
  assert.equal(then.values.wheelDiameter.value,20);assert.equal(retrospective.values.wheelDiameter.value,28);
  assert.ok(!then.evidenceRevisionIds.includes('0000000002'));assert.ok(retrospective.evidenceRevisionIds.includes('0000000002'));
});
test('date-only change retains intra-day ambiguity and known continuation next calendar day',async()=>{
  const uid='environment-date-only';await seedInitial(uid);
  await run(uid,payload({values:{...values,beddingThickness:'25'},expectedRevision:1,mutationId:'environment-mutation-date',effective:{precision:'date_only',dateKey:'2026-10-10'}}));
  const sameDay=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-10T05:00:00Z')});
  assert.equal(sameDay.values.beddingThickness.value,null);assert.ok(sameDay.quality.ambiguousFields.includes('beddingThickness'));
  const nextDay=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-10T15:00:00Z')});
  assert.equal(nextDay.values.beddingThickness.value,25);
  const event=(await root(uid).collection('revisions').doc('0000000002').get()).data();
  assert.equal(event.effective.precision,'date_only');assert.equal(event.effective.occurredAt,null);
});
test('unknown change time cannot unconditionally fill earlier environment with current values',async()=>{
  const uid='environment-unknown';await seedInitial(uid);
  const saved=await run(uid,payload({values:{...values,beddingThickness:'25'},expectedRevision:1,mutationId:'environment-mutation-unknown'}));
  const result=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-11T03:00:00Z')});
  assert.equal(result.values.beddingThickness.value,null);assert.ok(result.quality.ambiguousFields.includes('beddingThickness'));
  assert.equal(result.values.wheelDiameter.value,20);
  const confirmed=await history.readEnvironmentAt({db,uid,observedAt:new Date(new Date(saved.acceptedAt).getTime()+1)});
  assert.equal(confirmed.values.beddingThickness.value,25);
});
test('historical correction appends target revision, preserves later valid change/current and knowledge as-of',async()=>{
  const uid='environment-historical-correction';await seedInitial(uid);
  await seedActualChange(uid,2,{wheelDiameter:'20'},{wheelDiameter:'22'},'2026-10-10T05:00:00Z','2026-10-10T06:00:00Z');
  const originalRef=root(uid).collection('revisions').doc('0000000002'),original=await snapshot(originalRef);
  await seedActualChange(uid,3,{wheelDiameter:'22'},{wheelDiameter:'28'},'2026-10-11T05:00:00Z','2026-10-11T06:00:00Z');
  await run(uid,payload({operation:'correction',targetRevision:2,values:{wheelDiameter:'24'},expectedRevision:3,mutationId:'environment-mutation-correct',effective:{precision:'instant',occurredAt:'2026-10-10T05:00:00Z'}}));
  const correction=(await root(uid).collection('revisions').doc('0000000004').get()).data();
  assert.equal(correction.changes.wheelDiameter.before.value,22);assert.equal(correction.changes.wheelDiameter.after.value,24);assert.equal(correction.beforeValueMeaning,'previous_recorded_input');
  assert.equal((await root(uid).get()).get('wheelDiameter'),'28');assert.deepEqual(await snapshot(originalRef),original);
  const corrected=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-10T06:00:00Z')});assert.equal(corrected.values.wheelDiameter.value,24);
  const previousKnowledge=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-10T06:00:00Z'),knowledgeCutoff:new Date('2026-10-11T06:00:00Z')});assert.equal(previousKnowledge.values.wheelDiameter.value,22);
  const nowResult=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-12T03:00:00Z')});assert.equal(nowResult.values.wheelDiameter.value,28);
  assert.equal((await root(uid).collection('revisions').get()).size,4);
});
test('append-only cancellation retains later current change and every immutable prior revision',async()=>{
  const uid='environment-cancel';await seedInitial(uid);
  await seedActualChange(uid,2,{wheelDiameter:'20'},{wheelDiameter:'22'},'2026-10-10T05:00:00Z','2026-10-10T06:00:00Z');
  await seedActualChange(uid,3,{wheelDiameter:'22'},{wheelDiameter:'28'},'2026-10-11T05:00:00Z','2026-10-11T06:00:00Z');
  const refs=[1,2,3].map(n=>root(uid).collection('revisions').doc(String(n).padStart(10,'0'))),before=await Promise.all(refs.map(snapshot));
  await run(uid,payload({operation:'cancel',targetRevision:2,values:{},expectedRevision:3,mutationId:'environment-mutation-cancel3'}));
  assert.equal((await root(uid).get()).get('wheelDiameter'),'28');assert.deepEqual(await Promise.all(refs.map(snapshot)),before);
  assert.equal((await root(uid).collection('revisions').get()).size,4);
});
test('first changed legacy save records confirmed setting without inferring unchanged historical fields',async()=>{
  const uid='environment-initial-change';await root(uid).set(values);
  const result=await run(uid,payload({values:{...values,beddingThickness:'25'},effective:{precision:'date_only',dateKey:'2026-10-10'}}));
  assert.equal(result.revision,2);assert.equal((await root(uid).get()).get('beddingThickness'),'25');
  const historical=(await root(uid).collection('revisions').doc('0000000002').get()).data();
  assert.equal(historical.changes.beddingThickness.before.value,null);assert.equal(historical.changes.beddingThickness.before.quality,'unknown');
  assert.equal(historical.beforeValueMeaning,'previous_day_confirmed_environment');
  const retrospective=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-11T03:00:00Z')});
  assert.equal(retrospective.values.beddingThickness.value,25);assert.equal(retrospective.values.wheelDiameter.value,null);
  const asOf=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-11T03:00:00Z'),knowledgeCutoff:new Date('2026-10-11T03:00:00Z')});
  assert.equal(asOf.values.beddingThickness.value,null);
});
test('future scheduling and forged acceptance/owner fields are rejected with no partial save',async()=>{
  const uid='environment-invalid';await root(uid).set(values);const before=await snapshot(root(uid));
  const invalid=[
    payload({effective:{precision:'date_only',dateKey:'2099-01-01'}}),
    payload({effective:{precision:'instant',occurredAt:'2099-01-01T03:00:00Z'}}),
    payload({effective:{precision:'instant',occurredAt:'2026-10-10T03:00:00'}}),
    payload({acceptedAt:'2026-10-01T00:00:00Z'}),
    payload({ownerUid:'another-owner'}),
    payload({values:{...values,sensorToken:'forged'}}),
  ];
  for(const data of invalid)await assert.rejects(run(uid,data),x=>x.code==='invalid-argument');
  assert.deepEqual(await snapshot(root(uid)),before);assert.equal((await root(uid).collection('revisions').get()).size,0);assert.equal((await root(uid).collection('mutations').get()).size,0);
});
test('callables reject unauthenticated access before obtaining any Firestore data',async()=>{
  await assert.rejects(history.saveBreedingEnvironment({data:payload()}),x=>x.code==='unauthenticated');
  await assert.rejects(history.readBreedingEnvironmentAt({data:{observedAt:now.toISOString()}}),x=>x.code==='unauthenticated');
});
test('temporal read pages beyond 250 immutable revisions and returns final evidence without truncation',async()=>{
  const uid='environment-paged';await seedInitial(uid);
  let batch=db.batch(),pending=0;
  for(let revision=2;revision<=503;revision++) {
    const value=String(20+revision%10),occurredAt=new Date(new Date('2026-10-10T03:00:00Z').getTime()+revision*60000).toISOString();
    const raw={wheelDiameter:value};
    batch.set(root(uid).collection('revisions').doc(String(revision).padStart(10,'0')),{schemaVersion:1,ownerUid:uid,petId:'main_pet',revision,previousRevision:revision-1,kind:'change',targetRevision:null,effective:{precision:'instant',dateKey:'2026-10-10',occurredAt},acceptedAt:admin.firestore.Timestamp.fromDate(new Date('2026-10-11T03:00:00Z')),rawValues:raw,values:history.normalizeEnvironmentValues(raw),changes:{},auxiliaryFieldsChanged:[],initialBatch:false});
    pending++;if(pending===400){await batch.commit();batch=db.batch();pending=0;}
  }
  if(pending)await batch.commit();await root(uid).set({revision:503,wheelDiameter:'23'},{merge:true});
  const resolved=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-12T03:00:00Z')});
  assert.equal(resolved.values.wheelDiameter.value,23);assert.ok(resolved.evidenceRevisionIds.includes('0000000503'));assert.equal((await root(uid).collection('revisions').get()).size,503);
});
test('unknown-date input correction preserves the original confirmation bound and past knowledge state',async()=>{
  const uid='environment-unknown-correction';await seedInitial(uid);
  await seedActualChange(uid,2,{beddingThickness:'10'},{beddingThickness:'25'},'2026-10-10T05:00:00Z','2026-10-10T06:00:00Z');
  // Finish preparing the fixture before exercising the append-only mutation.
  const original=root(uid).collection('revisions').doc('0000000002');
  await original.set({effective:{precision:'unknown',dateKey:null,occurredAt:null}},{merge:true});
  const before=await snapshot(original);
  await run(uid,payload({operation:'correction',targetRevision:2,values:{beddingThickness:'30'},expectedRevision:2,mutationId:'environment-mutation-unknown-fix'}));
  const retrospective=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-11T03:00:00Z')});
  assert.equal(retrospective.values.beddingThickness.value,30);assert.ok(!retrospective.quality.ambiguousFields.includes('beddingThickness'));
  const then=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-11T03:00:00Z'),knowledgeCutoff:new Date('2026-10-11T03:00:00Z')});
  assert.equal(then.values.beddingThickness.value,25);assert.deepEqual(await snapshot(original),before);
  const earlier=await history.readEnvironmentAt({db,uid,observedAt:new Date('2026-10-09T05:00:00Z')});
  assert.equal(earlier.values.beddingThickness.value,null);assert.ok(earlier.quality.ambiguousFields.includes('beddingThickness'));
});
test('resaving the same known historical event after later valid change adds only a receipt',async()=>{
  const uid='environment-historical-repeat';await seedInitial(uid);
  await seedActualChange(uid,2,{wheelDiameter:'20'},{wheelDiameter:'22'},'2026-10-10T05:00:00Z','2026-10-10T06:00:00Z');
  await seedActualChange(uid,3,{wheelDiameter:'22'},{wheelDiameter:'28'},'2026-10-11T05:00:00Z','2026-10-11T06:00:00Z');
  const before=await snapshot(root(uid));
  const saved=await run(uid,payload({values:{wheelDiameter:'22'},expectedRevision:3,mutationId:'environment-historical-repeat',effective:{precision:'instant',occurredAt:'2026-10-10T05:00:00Z'}}));
  assert.equal(saved.changed,false);assert.equal(saved.revision,3);assert.deepEqual(await snapshot(root(uid)),before);
  assert.equal((await root(uid).collection('revisions').get()).size,3);assert.equal((await root(uid).collection('mutations').get()).size,1);
});
for(const precision of ['unknown','date_only'])test(`${precision}: genuine current back-and-forth is not suppressed by older equal values`,async()=>{
  const uid='environment-reversion-'+precision;await root(uid).set(values);await run(uid);
  const dateKey=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Tokyo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const effective=precision==='unknown'?{precision}:{precision,dateKey};
  for(const [revision,value] of [[1,'28'],[2,'20'],[3,'28']]) {
    const saved=await run(uid,payload({values:{wheelDiameter:value},expectedRevision:revision,mutationId:'environment-reversion-'+precision+'-'+revision,effective}),new Date());
    assert.equal(saved.changed,true);assert.equal(saved.revision,revision+1);assert.equal((await root(uid).get()).get('wheelDiameter'),value);
  }
  assert.equal((await root(uid).collection('revisions').get()).size,4);
});
test('malformed legacy container remains current while history contains only invalid quality without credentials',async()=>{
  const uid='environment-legacy-invalid';const unsafe={nestedToken:'never copy legacy nested secret'};
  await root(uid).set({...values,cageWidth:unsafe});
  const supplied=Object.fromEntries(Object.entries(values).filter(([key])=>key!=='cageWidth'));
  const saved=await run(uid,payload({values:supplied}));
  assert.deepEqual((await root(uid).get()).get('cageWidth'),unsafe);
  const revision=(await root(uid).collection('revisions').doc('0000000001').get()).data();
  assert.equal('cageWidth' in revision.rawValues,false);assert.equal(revision.values.cageWidth.quality,'invalid');assert.ok(!JSON.stringify(canonical(revision)).includes(unsafe.nestedToken));
  const resolved=await history.readEnvironmentAt({db,uid,observedAt:new Date(new Date(saved.acceptedAt).getTime()+1)});
  assert.equal(resolved.values.cageWidth.value,null);assert.equal(resolved.values.cageWidth.quality,'invalid');assert.equal(resolved.values.cageFloorArea.value,null);assert.equal(resolved.values.cageFloorArea.quality,'invalid');
});
