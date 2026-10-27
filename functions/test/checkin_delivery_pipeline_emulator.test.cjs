'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const crypto=require('node:crypto');
const {before,after,test}=require('node:test');
const {createRequire}=require('node:module');
const HOST=process.env.FIRESTORE_EMULATOR_HOST;
assert.match(HOST??'',/^127\.0\.0\.1:\d+$/,'Dedicated local Emulator required');
assert.notEqual(HOST,'127.0.0.1:8080');
const PROJECT='demo-hamcare-checkin-delivery-pipeline';
const dep=process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE?createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE):require;
const ts=dep('typescript'),admin=dep('firebase-admin');
let app,db,pipeline,healthTriggers,triggers,daily,catalog,clock=new Date('2026-10-07T03:00:00Z');
const rebuiltDates=[];
function load(file,cache=new Map()){
 if(cache.has(file))return cache.get(file).exports;
 const mod={exports:{}};cache.set(file,mod);
 const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
 const req=name=>name==='firebase-functions/logger'?{info:()=>{},error:()=>{}}:
 name==='firebase-functions/v2/firestore'?{onDocumentWritten:(_options,handler)=>handler}:
 name==='firebase-functions/v2/https'?{onCall:(_options,handler)=>handler,HttpsError:class extends Error{}}:
 name==='firebase-functions/v2/scheduler'?{onSchedule:(_options,handler)=>handler}:
 name==='firebase-admin'&&file.endsWith('personalityTriggers.ts')?{firestore:()=>db}:
 name==='./goldHealthNotification'?{executeGoldHealthNotificationPipeline:async()=>({sentCount:0}),executePendingResolvedHealthNotifications:async()=>({})}:
 name==='./healthPipeline'&&file.endsWith('healthTriggers.ts')?{rebuildHealthForDate:async params=>{rebuiltDates.push(params.dateKey);return pipeline.rebuildHealthForDate({...params,db});}}:
 name.startsWith('.')?load(path.resolve(path.dirname(file),`${name}.ts`),cache):dep(name);
 const ClockDate=class extends Date{constructor(...args){super(...(args.length?args:[clock]));}};
 const dateClass = /(?:healthPipeline|healthTriggers|personalityTriggers)\.ts$/.test(file) ? ClockDate : Date;
 vm.runInThisContext(`(function(exports,require,module,Date){${code}\n})`,{filename:file})(mod.exports,req,mod,dateClass);
 return mod.exports;
}
const user=uid=>db.collection('users').doc(uid);
const queue=uid=>db.collection('personality_report_queue').doc(uid);
const first=uid=>user(uid).collection('personalized_reports').doc('first');
const v1=uid=>user(uid).collection('personality_reports').doc('personality_v1_body');
const v1Pointer=uid=>user(uid).collection('report_pointers').doc('personality');
const dailyReport=(uid,day)=>user(uid).collection('personality_reports').doc(`daily_${day}`);
const timestamp=day=>admin.firestore.Timestamp.fromDate(new Date(`${day}T00:00:00Z`));
function canonical(x){if(x&&typeof x.toDate==='function')return [x.seconds,x.nanoseconds];if(Array.isArray(x))return x.map(canonical);if(x&&typeof x==='object')return Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])]));return x;}
async function snapshot(ref){const s=await ref.get();return {hash:crypto.createHash('sha256').update(JSON.stringify(canonical(s.data()??null))).digest('hex'),updateTime:s.updateTime&&[s.updateTime.seconds,s.updateTime.nanoseconds]};}
function checkin(day,tags=[]){return {dayKey:day,date:timestamp(day),schemaVersion:2,condition:tags.length?'slightlyConcerned':'normal',concernTags:tags,
 observationLevels:Object.fromEntries(catalog.observationCatalog.filter(item=>item.defaultNormal).map(item=>[item.id,tags.includes(item.id)?'changed':'normal'])),
 observationResponseMode:'overall_with_selected_tags',observationCatalogVersion:catalog.OBSERVATION_CATALOG_VERSION,memo:'private fixture memo'};}
async function seed(uid){const batch=db.batch();for(let n=1;n<=7;n++){const day=`2026-10-${String(n).padStart(2,'0')}`;batch.set(user(uid).collection('daily_checkins').doc(day),checkin(day,n<=3?['appetite']:[]));}
 batch.set(first(uid),{generation:{status:'generated',generatedAt:timestamp('2026-09-30')},readyMetrics:['body'],analysisRevision:1,immutable:true});
 batch.set(v1(uid),{schemaVersion:1,reportId:'personality_v1_body',readyMetrics:['body'],evaluationDateKey:'2026-09-30',metrics:{body:{latestDateKey:'2026-09-29',latestValue:100}},immutable:true});
 batch.set(v1Pointer(uid),{reportId:'personality_v1_body',readyMetrics:['body'],evaluationDateKey:'2026-09-30'});
 batch.set(user(uid).collection('pet_profiles').doc('main_pet'),{species:'シリアン',birthday:timestamp('2026-01-01'),memo:'private fixture memo'});
 batch.set(user(uid).collection('feature_access').doc('initial_trial_v2'),{status:'active',endsAt:timestamp('2026-10-31'),aiRequestUsed:1,aiCostMicrosUsed:50000});
 batch.set(user(uid).collection('app_state').doc('onboarding'),{firstAiConsultationCompleted:true,firstMonitoringDataSource:'daily_checkin'});await batch.commit();
}
async function deliverSilver(uid,day){const after=await user(uid).collection('daily_health_features').doc(day).get();await triggers.personalityHealthFeaturesWritten({params:{uid,dateKey:day},data:{after}});}
async function rebuildThroughTrigger(uid,source){const start=rebuiltDates.length;await healthTriggers.healthDailyCheckinWritten({params:{uid,sourceDateKey:source}});return rebuiltDates.slice(start);}
const publish=(uid,day)=>daily.publishDailyPersonalityReport({db,uid,evaluationDateKey:day,now:clock});
before(async()=>{
 assert.ok((await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,{method:'DELETE'})).ok);
 app=admin.initializeApp({projectId:PROJECT},`checkin-delivery-pipeline-${process.pid}`);db=admin.firestore(app);db.settings({host:HOST,ssl:false});
 const root=path.resolve(__dirname,'../src/health'),cache=new Map();catalog=load(path.join(root,'observationCatalog.ts'),cache);pipeline=load(path.join(root,'healthPipeline.ts'),cache);
 healthTriggers=load(path.join(root,'healthTriggers.ts'),cache);triggers=load(path.join(root,'personalityTriggers.ts'),cache);daily=load(path.join(root,'personalityDaily.ts'),cache);
});
after(async()=>{if(db)await db.terminate();if(app)await app.delete();});

test('checkin Bronze -> actual health trigger -> current Silver/Gold -> existing queue -> next JST morning observation-only report',async()=>{
 const uid='checkin-e2e-observation-only';clock=new Date('2026-10-07T03:00:00Z');await seed(uid);
 const protectedRefs=[first(uid),v1(uid),v1Pointer(uid),user(uid).collection('feature_access').doc('initial_trial_v2'),user(uid).collection('app_state').doc('onboarding')];const frozen=await Promise.all(protectedRefs.map(snapshot));
 assert.deepEqual(await rebuildThroughTrigger(uid,'2026-10-07'),['2026-10-07']);
 const current=(await user(uid).collection('individual_insights').doc('2026-10-07').get()).data();assert.equal(current.checkinInsights.insights[0].kind,'checkin_item_repetition');
 assert.equal((await user(uid).collection('analysis_readiness').doc('body').get()).data().currentStatus,'learning');
 assert.equal((await user(uid).collection('analysis_readiness').doc('activity').get()).data().currentStatus,'learning');
 await Promise.all(Array.from({length:6},()=>deliverSilver(uid,'2026-10-07')));assert.equal((await queue(uid).get()).data().dueDateKey,'2026-10-08');
 clock=new Date('2026-10-07T23:59:59Z');assert.equal((await publish(uid,'2026-10-08')).status,'not_due');
 clock=new Date('2026-10-08T00:00:00Z');assert.equal((await publish(uid,'2026-10-08')).status,'created');
 const report=(await dailyReport(uid,'2026-10-08').get()).data();assert.equal(report.reportType,'observation_only');assert.deepEqual(report.readyMetrics,[]);assert.deepEqual(report.metrics,{});
 assert.equal(report.insightSnapshot.checkinInsights.windowStartDateKey,'2026-09-24');assert.equal(report.insightSnapshot.checkinInsights.windowEndDateKey,'2026-10-07');assert.equal(report.insightSnapshot.checkinInsights.insights[0].evidence.matchingDayCount,3);
 assert.ok(!JSON.stringify(report).includes('private fixture'));assert.deepEqual(await Promise.all(protectedRefs.map(snapshot)),frozen);assert.equal((await user(uid).collection('weight_records').get()).size,0);assert.equal((await user(uid).collection('distance_records').get()).size,0);
 const output=process.env.HAMCARE_CHECKIN_FIXTURE_OUTPUT;if(output){assert.ok(output.startsWith('/private/tmp/hamcare-checkin-delivery-20261011/'));const wire=x=>x&&typeof x.toDate==='function'?x.toDate().toISOString():Array.isArray(x)?x.map(wire):x&&typeof x==='object'?Object.fromEntries(Object.entries(x).map(([k,v])=>[k,wire(v)])):x;fs.writeFileSync(output,JSON.stringify(wire(report),null,2)+'\n');}
});

test('saving the same meaning on another day does not repeatedly issue the discovery or continuity milestone',async()=>{
 const uid='checkin-e2e-no-spam';clock=new Date('2026-10-07T03:00:00Z');await seed(uid);await rebuildThroughTrigger(uid,'2026-10-07');await deliverSilver(uid,'2026-10-07');clock=new Date('2026-10-08T00:00:00Z');await publish(uid,'2026-10-08');const old=await snapshot(dailyReport(uid,'2026-10-08'));
 clock=new Date('2026-10-08T03:00:00Z');await user(uid).collection('daily_checkins').doc('2026-10-08').set(checkin('2026-10-08'));await rebuildThroughTrigger(uid,'2026-10-08');await deliverSilver(uid,'2026-10-08');assert.equal((await queue(uid).get()).exists,false);clock=new Date('2026-10-09T00:00:00Z');assert.equal((await publish(uid,'2026-10-09')).status,'not_queued');assert.deepEqual(await snapshot(dailyReport(uid,'2026-10-08')),old);
});

test('historical correction follows the unchanged bounded 14-day health window and can deliver a genuinely different observed item',async()=>{
 const uid='checkin-e2e-correction';clock=new Date('2026-10-07T03:00:00Z');await seed(uid);await rebuildThroughTrigger(uid,'2026-10-07');await deliverSilver(uid,'2026-10-07');clock=new Date('2026-10-08T00:00:00Z');await publish(uid,'2026-10-08');const frozen=[await snapshot(first(uid)),await snapshot(v1(uid)),await snapshot(dailyReport(uid,'2026-10-08'))];
 clock=new Date('2026-10-08T03:00:00Z');for(const day of ['2026-10-01','2026-10-02','2026-10-03'])await user(uid).collection('daily_checkins').doc(day).set(checkin(day,['water']));
 const dates=await rebuildThroughTrigger(uid,'2026-10-01');assert.deepEqual(dates,['2026-10-01','2026-10-02','2026-10-03','2026-10-04','2026-10-05','2026-10-06','2026-10-07','2026-10-08']);assert.ok(dates.length<=14);
 await deliverSilver(uid,'2026-10-07');assert.equal((await queue(uid).get()).exists,false);await deliverSilver(uid,'2026-10-08');assert.equal((await queue(uid).get()).data().dueDateKey,'2026-10-09');clock=new Date('2026-10-09T00:00:00Z');assert.equal((await publish(uid,'2026-10-09')).status,'created');assert.equal((await dailyReport(uid,'2026-10-09').get()).data().insightSnapshot.checkinInsights.insights[0].evidence.itemId,'water');assert.deepEqual([await snapshot(first(uid)),await snapshot(v1(uid)),await snapshot(dailyReport(uid,'2026-10-08'))],frozen);
});

test('a delayed Silver reader cannot replace a newer queue candidate',async()=>{
 const uid='checkin-e2e-stale-queue';clock=new Date('2026-10-07T03:00:00Z');await seed(uid);await rebuildThroughTrigger(uid,'2026-10-07');await deliverSilver(uid,'2026-10-07');const before=await snapshot(queue(uid));
 const ref=user(uid).collection('daily_health_features').doc('2026-10-07');let injected=false;const delayedDb={collection:db.collection.bind(db),runTransaction:async fn=>{if(!injected){injected=true;await ref.update({generatedAt:admin.firestore.Timestamp.fromDate(new Date('2026-10-07T03:01:00Z'))});}return db.runTransaction(fn);}};
 const result=await daily.enqueueDailyPersonalityReport({db:delayedDb,uid,sourceDateKey:'2026-10-07',now:clock});assert.equal(result.status,'stale_source');assert.deepEqual(await snapshot(queue(uid)),before);
});
