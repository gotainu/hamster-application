'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const {before, after, test} = require('node:test');
const HOST = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(HOST ?? '', /^127\.0\.0\.1:\d+$/, 'Dedicated emulator only; production fallback forbidden');
assert.notEqual(HOST, '127.0.0.1:8080');
const PROJECT='demo-hamcare-checkin-insights';
const dep=process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE?createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE):require;
const sdk=process.env.HAMCARE_RULES_TEST_DEPENDENCY_PACKAGE?createRequire(process.env.HAMCARE_RULES_TEST_DEPENDENCY_PACKAGE):dep;
const ts=dep('typescript'); const admin=dep('firebase-admin');
const {initializeTestEnvironment,assertFails,assertSucceeds}=sdk('@firebase/rules-unit-testing');
const {doc,setDoc,Timestamp}=sdk('firebase/firestore');
let app,db,env,pipeline,readers,builder,insights,daily,catalog,holdRead=null;
const DAY='2026-10-14'; let clock=new Date('2026-10-14T02:00:00Z');
function load(file,cache=new Map()){
 if(cache.has(file))return cache.get(file).exports;
 const mod={exports:{}};cache.set(file,mod);
 const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
 const req=name=>name==='firebase-functions/logger'?{info:()=>{},error:()=>{}}:
 name==='./goldHealthNotification'?{executeGoldHealthNotificationPipeline:async()=>({sentCount:0}),executePendingResolvedHealthNotifications:async()=>({})}:
 name==='./firestoreReaders'&&file.endsWith('healthPipeline.ts')?{fetchHealthSourceData:async params=>{const source=await readers.fetchHealthSourceData(params);if(holdRead){const hold=holdRead;holdRead=null;await hold();}return source;}}:
 name.startsWith('.')?load(path.resolve(path.dirname(file),`${name}.ts`),cache):dep(name);
 const clockDate=file.endsWith('healthPipeline.ts')?class extends Date{constructor(...args){super(...(args.length?args:[clock]));}}:Date;
 vm.runInThisContext(`(function(exports, require, module, Date){${code}\n})`,{filename:file})(mod.exports,req,mod,clockDate);return mod.exports;
}
const user=uid=>db.collection('users').doc(uid);
const gold=uid=>user(uid).collection('individual_insights').doc(DAY);
const silver=uid=>user(uid).collection('daily_health_features').doc(DAY);
const first=uid=>user(uid).collection('personalized_reports').doc('first');
const oldReport=uid=>user(uid).collection('personality_reports').doc('personality_v1_body');
const dailyReport=uid=>user(uid).collection('personality_reports').doc(`daily_${DAY}`);
const stamp=key=>admin.firestore.Timestamp.fromDate(new Date(`${key}T00:00:00Z`));
function canonical(x){if(x&&typeof x.toDate==='function')return[x.seconds,x.nanoseconds];if(Array.isArray(x))return x.map(canonical);if(x&&typeof x==='object')return Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])]));return x;}
async function snap(ref){const s=await ref.get();return{hash:crypto.createHash('sha256').update(JSON.stringify(canonical(s.data()??null))).digest('hex'),time:s.updateTime&&[s.updateTime.seconds,s.updateTime.nanoseconds]};}
const rebuild=uid=>pipeline.rebuildHealthForDate({db,uid,dateKey:DAY,reason:'manual_rebuild'});
function checkin(key,tags=[],condition=tags.length?'slightlyConcerned':'normal'){
 return {dayKey:key,date:stamp(key),schemaVersion:2,condition,concernTags:tags,
 observationLevels:Object.fromEntries(catalog.observationCatalog.filter(x=>x.defaultNormal).map(x=>[x.id,tags.includes(x.id)?condition==='veryConcerned'?'concerning':'changed':'normal'])),
 observationCatalogVersion:catalog.OBSERVATION_CATALOG_VERSION,observationResponseMode:'overall_with_selected_tags',memo:'secret observation memo'};
}
async function seed(uid){const batch=db.batch();
 for(const key of ['2026-09-22','2026-09-29','2026-09-30','2026-10-01','2026-10-02','2026-10-03','2026-10-04','2026-10-05','2026-10-13'])batch.set(user(uid).collection('weight_records').doc(key),{dayKey:key,weightGrams:100,date:stamp(key)});
 for(let i=1;i<=7;i++){const key=`2026-10-${String(i).padStart(2,'0')}`;batch.set(user(uid).collection('daily_checkins').doc(key),checkin(key,i<=3?['appetite']:[]));}
 batch.set(first(uid),{generation:{status:'generated',generatedAt:stamp('2026-10-07')},readyMetrics:['body'],analysisRevision:1});
 batch.set(oldReport(uid),{schemaVersion:1,reportId:'personality_v1_body',petId:'main_pet',readyMetrics:['body'],evaluationDateKey:'2026-10-08',silverDateKey:'2026-10-08',metrics:{body:{latestDateKey:'2026-10-05',latestValue:100}},immutable:true});
 batch.set(user(uid).collection('report_pointers').doc('personality'),{reportId:'personality_v1_body',readyMetrics:['body'],evaluationDateKey:'2026-10-08'});
 batch.set(user(uid).collection('pet_profiles').doc('main_pet'),{species:'シリアン',birthday:stamp('2026-01-01')});await batch.commit();
}
before(async()=>{
 const cleared=await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,{method:'DELETE'});assert.ok(cleared.ok);
 env=await initializeTestEnvironment({projectId:PROJECT,firestore:{host:'127.0.0.1',port:Number(HOST.split(':')[1]),rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});
 app=admin.initializeApp({projectId:PROJECT},`checkin-insights-${process.pid}`);db=admin.firestore(app);db.settings({host:HOST,ssl:false});
 const cache=new Map();const root=path.resolve(__dirname,'../src/health');readers=load(path.join(root,'firestoreReaders.ts'),cache);builder=load(path.join(root,'dailyHealthFeatures.ts'),cache);insights=load(path.join(root,'weightInsights.ts'),cache);catalog=load(path.join(root,'observationCatalog.ts'),cache);pipeline=load(path.join(root,'healthPipeline.ts'),cache);daily=load(path.join(root,'personalityDaily.ts'),cache);
});
after(async()=>{if(env)await env.cleanup();if(db)await db.terminate();if(app)await app.delete();});
test('current schema2 observation projection remains server-owned for paid/trial owners',async()=>{
 const until=admin.firestore.Timestamp.fromDate(new Date('2099-01-01'));
 await user('paid').collection('billing').doc('subscription').set({plan:'paid',status:'active'});
 await user('trial').collection('feature_access').doc('initial_trial_v2').set({status:'active',endsAt:until});
 const payload={...checkin('2026-10-01',['appetite']),date:Timestamp.fromDate(new Date('2026-09-30T15:00:00Z'))};
 for(const uid of ['paid','trial'])await assertFails(setDoc(doc(env.authenticatedContext(uid).firestore(),`users/${uid}/daily_checkins/2026-10-01`),payload));
 await assertFails(setDoc(doc(env.authenticatedContext('unpaid').firestore(),'users/unpaid/daily_checkins/2026-10-01'),payload));
 await assertFails(setDoc(doc(env.authenticatedContext('stranger').firestore(),'users/trial/daily_checkins/2026-10-01'),payload));
});
test('pipeline pairs Silver and mixed Gold, preserving weight API and frozen first/v1',async()=>{
 const uid='checkin-pipeline';await seed(uid);const frozen=[await snap(first(uid)),await snap(oldReport(uid))];await rebuild(uid);
 const s=(await silver(uid).get()).data(),g=(await gold(uid).get()).data();assert.equal(s.schemaVersion,5);assert.equal(s.checkinInsightEvidence.validRecordDayCount,7);
 assert.equal(g.checkinInsights.insights[0].evidence.itemLabel,'食欲');assert.equal(g.insights[0].evidence.minimumGrams,100);
 assert.equal(g.checkinInsights.evidenceHash,s.checkinInsightEvidence.evidenceHash);assert.ok(g.source.silverGeneratedAt.isEqual(s.generatedAt));
 assert.equal(g.checkinInsights.insights[0].evidence.itemAnsweredDayCount,null);assert.ok(!JSON.stringify(g).includes('secret observation memo'));
 assert.deepEqual([await snap(first(uid)),await snap(oldReport(uid))],frozen);
});
test('same day duplicates, historical corrections and deletes refresh one day fact',async()=>{
 const uid='checkin-correction';await seed(uid);await rebuild(uid);const frozen=[await snap(first(uid)),await snap(oldReport(uid))];
 await user(uid).collection('daily_checkins').doc('20261001').set(checkin('2026-10-01'));
 clock=new Date('2026-10-14T02:01:00Z');await rebuild(uid);
 let value=(await gold(uid).get()).data().checkinInsights.insights[0];assert.equal(value.kind,'checkin_concern_frequency');assert.equal(value.evidence.validRecordDayCount,7);
 await user(uid).collection('daily_checkins').doc('20261001').delete();await user(uid).collection('daily_checkins').doc('2026-10-01').update({condition:'normal',concernTags:[],observationLevels:Object.fromEntries(catalog.observationCatalog.filter(x=>x.defaultNormal).map(x=>[x.id,'normal']))});
 clock=new Date('2026-10-14T02:02:00Z');await rebuild(uid);value=(await gold(uid).get()).data().checkinInsights.insights[0];assert.equal(value.kind,'checkin_concern_frequency');
 await user(uid).collection('daily_checkins').doc('2026-10-02').delete();clock=new Date('2026-10-14T02:03:00Z');await rebuild(uid);
 assert.equal((await gold(uid).get()).data().checkinInsights.insights.length,0);assert.deepEqual([await snap(first(uid)),await snap(oldReport(uid))],frozen);
});
test('parallel duplicate transactions are idempotent and a delayed old job cannot replace Silver or Gold',async()=>{
 const uid='checkin-concurrent';await seed(uid);clock=new Date('2026-10-14T03:00:00Z');await rebuild(uid);
 const source=await readers.fetchHealthSourceData({db,uid,dateKey:DAY});const features=builder.buildDailyHealthFeatures({dateKey:DAY,source,generatedAt:clock}).features;
 const current=insights.buildCurrentInsightSet({features,generatedAt:clock});const before=await snap(gold(uid));
 const outcomes=await Promise.all(Array.from({length:6},()=>db.runTransaction(async transaction=>insights.persistCurrentInsightSet({transaction,reference:gold(uid),snapshot:await transaction.get(gold(uid)),current}))));
 assert.ok(outcomes.every(x=>x==='unchanged'));assert.deepEqual(await snap(gold(uid)),before);
 let release;let readDone;const done=new Promise(r=>{readDone=r});const gate=new Promise(r=>{release=r});holdRead=async()=>{readDone();await gate;};
 clock=new Date('2026-10-14T03:01:00Z');const old=rebuild(uid);await done;
 await user(uid).collection('daily_checkins').doc('2026-10-01').update({condition:'normal',concernTags:[],observationLevels:{}});
 clock=new Date('2026-10-14T03:02:00Z');await rebuild(uid);const newer=[await snap(silver(uid)),await snap(gold(uid))];release();await old;
 assert.deepEqual([await snap(silver(uid)),await snap(gold(uid))],newer);assert.equal((await user(uid).collection('individual_insights').get()).size,1);
});
test('only future daily report captures D-14..D-1; existing daily report cannot be enriched or rewritten',async()=>{
 const uid='checkin-daily';await seed(uid);await user(uid).collection('daily_checkins').doc('2026-09-30').set(checkin('2026-09-30',['appetite']));
 await user(uid).collection('daily_checkins').doc(DAY).set(checkin(DAY,['appetite']));await rebuild(uid);
 const frozen=[await snap(first(uid)),await snap(oldReport(uid))];await db.collection('personality_report_queue').doc(uid).set({schemaVersion:1,uid,dueDateKey:DAY,dueAt:stamp(DAY),latestValidDates:{body:'2026-10-13'}});
 const result=await daily.publishDailyPersonalityReport({db,uid,evaluationDateKey:DAY,now:clock});assert.equal(result.status,'created');
 const report=(await dailyReport(uid).get()).data();assert.equal(report.insightSnapshot.checkinInsights.windowStartDateKey,'2026-09-30');assert.equal(report.insightSnapshot.checkinInsights.windowEndDateKey,'2026-10-13');
 assert.equal(report.insightSnapshot.checkinInsights.insights[0].evidence.matchingDayCount,4);assert.equal(report.insightSnapshot.insights[0].evidence.minimumGrams,100);
 const before=await snap(dailyReport(uid));await user(uid).collection('daily_checkins').doc('2026-10-01').update({concernTags:[],observationLevels:{}});
 await db.collection('personality_report_queue').doc(uid).set({schemaVersion:1,uid,dueDateKey:DAY,dueAt:stamp(DAY),latestValidDates:{body:'2026-10-13'}});
 assert.equal((await daily.publishDailyPersonalityReport({db,uid,evaluationDateKey:DAY,now:clock})).status,'existing');assert.deepEqual(await snap(dailyReport(uid)),before);assert.deepEqual([await snap(first(uid)),await snap(oldReport(uid))],frozen);
});

for (const initiallyExists of [false,true]) test(`same-millisecond delayed reader cannot overwrite the winning ${initiallyExists?'existing':'first-created'} Silver/Gold pair`,async()=>{
 const uid=`checkin-same-millisecond-${initiallyExists}`;await seed(uid);clock=new Date('2026-10-14T04:00:00Z');
 if(initiallyExists)await rebuild(uid);
 let release;let readDone;const done=new Promise(resolve=>{readDone=resolve;});const gate=new Promise(resolve=>{release=resolve;});
 holdRead=async()=>{readDone();await gate;};
 const delayed=rebuild(uid);await done;
 await user(uid).collection('daily_checkins').doc('2026-10-01').update({condition:'normal',concernTags:[],observationLevels:Object.fromEntries(catalog.observationCatalog.filter(item=>item.defaultNormal).map(item=>[item.id,'normal']))});
 // The newer Bronze calculation deliberately starts at exactly the same ms.
 await rebuild(uid);const winning=[await snap(silver(uid)),await snap(gold(uid))];
 assert.equal((await gold(uid).get()).data().checkinInsights.insights[0].kind,'checkin_concern_frequency');
 release();await delayed;
 assert.deepEqual([await snap(silver(uid)),await snap(gold(uid))],winning);
});

test('same-millisecond newer correction retries fresh Bronze when the old reader commits first',async()=>{
 const uid='checkin-same-ms-old-commits-first';await seed(uid);clock=new Date('2026-10-14T05:00:00Z');await rebuild(uid);
 const frozen=[await snap(first(uid)),await snap(oldReport(uid))];
 let releaseOld,releaseNew,oldReadDone,newReadDone;
 const oldReady=new Promise(resolve=>{oldReadDone=resolve;});const oldGate=new Promise(resolve=>{releaseOld=resolve;});
 const newReady=new Promise(resolve=>{newReadDone=resolve;});const newGate=new Promise(resolve=>{releaseNew=resolve;});
 holdRead=async()=>{oldReadDone();await oldGate;};const old=rebuild(uid);await oldReady;
 await user(uid).collection('daily_checkins').doc('2026-10-01').update({condition:'normal',concernTags:[],observationLevels:Object.fromEntries(catalog.observationCatalog.filter(item=>item.defaultNormal).map(item=>[item.id,'normal']))});
 holdRead=async()=>{newReadDone();await newGate;};const correction=rebuild(uid);await newReady;
 releaseOld();await old;assert.equal((await gold(uid).get()).data().checkinInsights.insights[0].kind,'checkin_item_repetition');
 releaseNew();await correction;
 assert.equal((await gold(uid).get()).data().checkinInsights.insights[0].kind,'checkin_concern_frequency');
 assert.equal((await silver(uid).get()).data().checkinInsightEvidence.concernDayCount,2);
 assert.deepEqual([await snap(first(uid)),await snap(oldReport(uid))],frozen);
});
