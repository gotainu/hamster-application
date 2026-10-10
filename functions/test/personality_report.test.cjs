'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const test=require('node:test');
const ts=require('typescript');
const ROOT='users/personality-unit';
const DAY='2026-10-08';
const NOW=new Date('2026-10-08T02:00:00Z');
function load(){
 const cache=new Map();
 function read(file){
  if(cache.has(file))return cache.get(file).exports;
  const output=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
  const mod={exports:{}};cache.set(file,mod);
  const req=(name)=>name==='firebase-admin'?{firestore:{Timestamp:{fromDate:d=>d.toISOString()}}}:name.startsWith('.')?read(path.resolve(path.dirname(file),name+'.ts')):require(name);
  vm.runInThisContext('(function(exports,require,module){'+output+'\n})',{filename:file})(mod.exports,req,mod);return mod.exports;
 }
 return {report:read(path.resolve(__dirname,'../src/health/personalityReport.ts')),cohort:read(path.resolve(__dirname,'../src/health/referenceCohorts.ts'))};
}
function fakeDb(){
 const docs=new Map();const writes=[];let queue=Promise.resolve();
 const ref=p=>({path:p,collection:n=>ref(p+'/'+n),doc:n=>ref(p+'/'+n)});
 return {docs,writes,collection:n=>ref(n),runTransaction(action){
  const pending=queue.then(async()=>{
   const changes=[];
   const value=await action({get:async r=>{assert.equal(changes.length,0,'reads before writes');const d=docs.get(r.path);return {exists:d!==undefined,data:()=>structuredClone(d)};},create(r,d){assert.ok(!docs.has(r.path));changes.push([r,d,'create']);},set(r,d){changes.push([r,d,'set']);}});
   for(const [r,d,mode] of changes){docs.set(r.path,structuredClone(d));writes.push({path:r.path,data:structuredClone(d),mode});}
   return value;
  });queue=pending.catch(()=>{});return pending;
 }};
}
function baseline(ready=true,metric='body'){
 return {status:ready?'ready':'learning',median:metric==='body'?100:628.3185,mad:0,ewma:metric==='body'?100:628.3185,ewmaAlpha:0.3,recordCount:ready?8:2,requiredRecordCount:7,spanDays:ready?14:2,requiredSpanDays:14,firstDateKey:ready?'2026-09-23':'2026-10-05',lastDateKey:'2026-10-06',method:'median_mad_ewma_v1',deviationPct:10,robustZScore:null};
}
function features(body=true,activity=false,dateKey=DAY){return {schemaVersion:5,dateKey,generatedAt:NOW,updatedAt:NOW,body:{personalBaseline:baseline(body),latestWeightGrams:110,latestWeightDate:new Date('2026-10-06T00:00:00Z'),memo:'do not copy'},activity:{personalBaseline:baseline(activity,'activity'),distanceMeters:700,sourceDateKey:'2026-10-07',memo:'private'},condition:{memo:'private content'}};}
function fixture(body=true,activity=false){const db=fakeDb();db.docs.set(ROOT+'/daily_health_features/'+DAY,features(body,activity));db.docs.set(ROOT+'/pet_profiles/main_pet',{name:'private pet',species:'シリアン',birthday:new Date('2026-01-01T00:00:00Z'),memo:'private'});db.docs.set(ROOT+'/personalized_reports/first',{generation:{status:'generated'},readyMetrics:['body'],analysisRevision:1});return db;}
const publish=(db,module,dateKey=DAY)=>module.syncPersonalityReport({db,uid:'personality-unit',evaluationDateKey:dateKey,now:NOW});
const reports=db=>[...db.docs].filter(([p])=>p.startsWith(ROOT+'/personality_reports/')).map(([,v])=>v);
test('body only publishes numeric evidence and a body-only report',async()=>{const {report}=load();const db=fixture();await publish(db,report);const r=reports(db)[0];assert.deepEqual(r.readyMetrics,['body']);assert.equal(r.reportType,'weight_only');assert.equal(r.metrics.body.baseline.median,100);assert.equal(r.metrics.body.latestValue,110);assert.equal(r.metrics.body.difference.absolute,10);assert.equal(r.metrics.activity,undefined);assert.equal(r.readinessSnapshot.activity.status,'learning');assert.ok(r.metrics.body.interpretations[0].text.includes('100'));assert.ok(!JSON.stringify(r).includes('private'));assert.equal(r.schemaVersion,1);});
test('activity only has meaningful individual explanation without species ranking',async()=>{const {report}=load();const db=fixture(false,true);await publish(db,report);const r=reports(db)[0];assert.equal(r.reportType,'activity_only');assert.equal(r.metrics.activity.baseline.median,628.3185);assert.equal(r.metrics.body,undefined);assert.equal(r.metrics.activity.populationComparison,null);assert.ok(r.metrics.activity.interpretations.some(x=>x.code==='individual_activity'));assert.ok(!r.metrics.activity.interpretations.some(x=>/夜型です|深夜に活発です/.test(x.text)));});
test('both ready publishes both metrics',async()=>{const {report}=load();const db=fixture(true,true);await publish(db,report);assert.deepEqual(reports(db)[0].readyMetrics,['body','activity']);assert.equal(reports(db)[0].reportType,'both');});
test('learning does not issue a report or pointer',async()=>{const {report}=load();const db=fixture(false,false);await publish(db,report);assert.equal(reports(db).length,0);assert.equal(db.docs.has(ROOT+'/report_pointers/personality'),false);});
test('absent reference publishes personal facts with comparison unavailable',async()=>{const {report}=load();const db=fixture();await publish(db,report);assert.equal(reports(db)[0].metrics.body.populationComparison.applicability,'not_applicable');});
test('valid stored reference is pinned with version/source and IQR context',async()=>{const {report,cohort}=load();const db=fixture();const c=cohort.getReferenceCohort('シリアン');db.docs.set('reference_cohorts/'+c.cohortId,{currentReferenceVersion:c.referenceVersion});db.docs.set('reference_cohorts/'+c.cohortId+'/versions/'+c.referenceVersion,c);await publish(db,report);const x=reports(db)[0].metrics.body.populationComparison;assert.equal(x.applicability,'applicable');assert.equal(x.cohort.median,133);assert.equal(x.cohort.sourceDOI,'10.1111/jsap.13527');assert.equal(x.position,'within_iqr');assert.equal(x.cohort.weightSampleN,null);});
test('unknown species and missing/young birthday never make population comparison',async()=>{const {report,cohort}=load();for(const profile of [{species:'unknown',birthday:NOW},{species:'シリアン'},{species:'シリアン',birthday:new Date('2026-09-01')}]){const db=fixture();db.docs.set(ROOT+'/pet_profiles/main_pet',profile);const c=cohort.getReferenceCohort('シリアン');db.docs.set('reference_cohorts/'+c.cohortId,{currentReferenceVersion:c.referenceVersion});db.docs.set('reference_cohorts/'+c.cohortId+'/versions/'+c.referenceVersion,c);await publish(db,report);assert.equal(reports(db)[0].metrics.body.populationComparison.applicability,'not_applicable');}});
test('MAD zero explains limits without claiming all observations were equal',async()=>{const {report}=load();const db=fixture(true,true);await publish(db,report);const r=reports(db)[0];assert.ok(r.limitations.some(x=>x.includes('MAD')&&x.includes('すべて')));assert.ok(!r.metrics.body.interpretations.some(x=>x.text.includes('変動がなかった')));});
test('duplicates and concurrent deliveries issue only once',async()=>{const {report}=load();const db=fixture();await Promise.all(Array.from({length:8},()=>publish(db,report)));assert.equal(reports(db).length,1);assert.equal(db.writes.filter(x=>x.mode==='create'&&x.path.startsWith(ROOT+'/personality_reports/')).length,1);});
test('ready gain creates new snapshot and preserves old report',async()=>{const {report}=load();const db=fixture();await publish(db,report);const first=structuredClone(reports(db)[0]);db.docs.set(ROOT+'/daily_health_features/'+DAY,features(true,true));await publish(db,report);assert.equal(reports(db).length,2);assert.deepEqual(reports(db)[0],first);const pointer=db.docs.get(ROOT+'/report_pointers/personality');assert.deepEqual(pointer.readyMetrics,['body','activity']);assert.equal(pointer.reportId,reports(db)[1].reportId);});
test('regression, regained readiness and research changes do not reissue',async()=>{const {report}=load();const db=fixture(true,true);await publish(db,report);const frozen=structuredClone(reports(db));db.docs.set(ROOT+'/daily_health_features/'+DAY,features(false,false));await publish(db,report);db.docs.set(ROOT+'/daily_health_features/'+DAY,features(true,true));await publish(db,report);assert.deepEqual(reports(db),frozen);assert.equal(db.writes.filter(x=>x.mode==='create'&&x.path.startsWith(ROOT+'/personality_reports/')).length,1);});
test('historical ready and historical backfill cannot issue transient reports',async()=>{const {report}=load();const db=fixture(false,false);db.docs.set(ROOT+'/daily_health_features/2026-09-24',features(true,true,'2026-09-24'));await publish(db,report,'2026-09-24');assert.equal(reports(db).length,0);await publish(db,report);assert.equal(reports(db).length,0);});
test('already-ready current Silver backfill is idempotent and uses server snapshot',async()=>{const {report}=load();const db=fixture(true,true);await publish(db,report);await publish(db,report);assert.equal(reports(db).length,1);assert.equal(reports(db)[0].silverDateKey,DAY);});
test('first report, trial, billing, readiness and Bronze receive zero writes',async()=>{const {report}=load();const db=fixture(true,true);const first=structuredClone(db.docs.get(ROOT+'/personalized_reports/first'));await publish(db,report);assert.deepEqual(db.docs.get(ROOT+'/personalized_reports/first'),first);assert.ok(db.writes.every(x=>x.path.startsWith(ROOT+'/personality_reports/')||x.path===ROOT+'/report_pointers/personality'||x.path.startsWith(ROOT+'/analysis_events/personality_report_')));});

test('dry-run on current ready Silver leaves all documents unchanged',async()=>{const {report}=load();const db=fixture(true,true);const before=structuredClone([...db.docs]);const result=await report.syncPersonalityReport({db,uid:'personality-unit',evaluationDateKey:DAY,now:NOW,dryRun:true});assert.equal(result.status,'would_create');assert.deepEqual([...db.docs],before);assert.equal(db.writes.length,0);});

test('delayed previous-day evaluation cannot replace a newer publication pointer',async()=>{const {report}=load();const db=fixture(true,true);const pointer={reportId:'newer',evaluationDateKey:'2026-10-09',publishedReadyMetrics:['body'],readyMetrics:['body']};db.docs.set(ROOT+'/report_pointers/personality',pointer);const result=await publish(db,report);assert.equal(result.status,'stale_evaluation');assert.deepEqual(db.docs.get(ROOT+'/report_pointers/personality'),pointer);assert.equal(reports(db).length,0);});
test('recovering a missing pointer reuses the immutable report dates and rejects conflicting snapshots',async()=>{const {report}=load();const db=fixture();await publish(db,report);const original=structuredClone(reports(db)[0]);original.evaluationDateKey='2026-10-07';original.silverDateKey='2026-10-07';db.docs.set(ROOT+'/personality_reports/'+original.reportId,original);db.docs.delete(ROOT+'/report_pointers/personality');await publish(db,report);const pointer=db.docs.get(ROOT+'/report_pointers/personality');assert.equal(pointer.evaluationDateKey,original.evaluationDateKey);assert.equal(pointer.silverDateKey,original.silverDateKey);assert.deepEqual(reports(db)[0],original);db.docs.delete(ROOT+'/report_pointers/personality');db.docs.set(ROOT+'/personality_reports/'+original.reportId,{...original,petId:'other_pet'});const writesBefore=db.writes.length;const result=await publish(db,report);assert.equal(result.status,'existing_report_conflict');assert.equal(db.writes.length,writesBefore);});

test('generation metadata is atomic, idempotent and joins the actual personality report without health text',async()=>{const {report}=load();const db=fixture();db.docs.set(ROOT+'/feature_access/initial_trial_v2',{trialId:'initial_trial_v2',policyVersion:'initial_trial_v2',endsAt:'2026-10-28T00:00:00Z',testOnly:true,aiRequestUsed:1});await Promise.all([publish(db,report),publish(db,report)]);const events=[...db.docs].filter(([p])=>p.startsWith(ROOT+'/analysis_events/personality_report_'));assert.equal(events.length,1);const event=events[0][1];assert.equal(event.eventName,'personality_report_generated');assert.equal(event.reportId,reports(db)[0].reportId);assert.equal(event.reportRevision,1);assert.equal(event.petId,'main_pet');assert.equal(event.trialId,'initial_trial_v2');assert.equal(event.testOnly,true);assert.ok(!JSON.stringify(event).includes('private'));assert.equal(event.median,undefined);assert.equal(event.aiRequestUsed,undefined);assert.deepEqual(event.readyMetrics,['body']);});


test('fresh preview is read-only, never bypasses committed current Silver and rejects stale features',async()=>{
 const {report}=load();const db=fixture(false,false);const preview=features(true,true);
 await assert.rejects(report.syncPersonalityReport({db,uid:'personality-unit',evaluationDateKey:DAY,now:NOW,previewFeatures:preview}),/read-only/);
 const current=await report.syncPersonalityReport({db,uid:'personality-unit',evaluationDateKey:DAY,now:NOW,dryRun:true,previewFeatures:preview});
 assert.equal(current.status,'learning');assert.equal(db.writes.length,0);
 db.docs.delete(ROOT+'/daily_health_features/'+DAY);
 const before=structuredClone([...db.docs]);
 const fresh=await report.syncPersonalityReport({db,uid:'personality-unit',evaluationDateKey:DAY,now:NOW,dryRun:true,previewFeatures:preview});
 assert.equal(fresh.status,'would_create');assert.deepEqual([...db.docs],before);assert.equal(db.writes.length,0);
 const stale=await report.syncPersonalityReport({db,uid:'personality-unit',evaluationDateKey:DAY,now:NOW,dryRun:true,previewFeatures:features(true,true,'2026-10-07')});
 assert.equal(stale.status,'current_silver_unavailable');assert.equal(db.writes.length,0);
});
