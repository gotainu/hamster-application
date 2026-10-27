'use strict';
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
const admin=require('firebase-admin');
const filename=process.env.SENSOR_QUALITY_SOURCE??path.resolve(__dirname,'../src/sensorQuality/quality.ts');
function loadSource(filename){const mod={exports:{}};const localRequire=id=>id.startsWith('.')?loadSource(path.resolve(path.dirname(filename),id+'.ts')):require(id);vm.runInThisContext(`(function(exports,require,module){${ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText}\n})`,{filename})(mod.exports,localRequire,mod);return mod.exports;}
const {readSensorQualityEvidence,aggregateSensorQuality,buildAndSaveSensorQuality,jstSensorQualityWindow}=loadSource(filename);
const host=process.env.FIRESTORE_EMULATOR_HOST;
const available=/^127\.0\.0\.1:\d+$/.test(host??'')&&host!=='127.0.0.1:8080';
let app,db;
before(async()=>{if(!available)return;app=admin.initializeApp({projectId:'demo-hamcare-sensor-window'},'sensor-window-'+process.pid);db=admin.firestore(app);db.settings({host,ssl:false});});
after(async()=>{if(db)await db.terminate();if(app)await app.delete();});
const stamp=t=>admin.firestore.Timestamp.fromDate(new Date(t));
const window=jstSensorQualityWindow('2026-10-16');
const cutoff='2026-10-16T03:20:15.594Z';
const args=uid=>({db,uid,...window,knowledgeCutoff:cutoff,pageSize:2,maxDocuments:3000});
function reading(id,t,accepted=t){return{ts:t,createdAt:stamp(accepted),temperature:24,humidity:50,source:'status',acquisitionId:id,acquisitionVerification:'verified'};}
async function seed(uid,id,t,accepted=t){
  const readingPath=`users/${uid}/switchbot_readings/acq_${id}`;
  await db.doc(`users/${uid}/integrations/switchbot`).set({meterDeviceId:'meter'});
  const terminal={status:'reading_saved',requestAttempted:true,requestStartedAt:t,responseReceivedAt:t,acceptedAt:stamp(accepted),readingPath,readingTs:t,validity:{api:'valid',temperature:'valid',humidity:'valid'}};
  await db.doc(`users/${uid}/sensor_acquisition_attempts/${id}`).set({attemptId:id,route:'scheduled',deviceId:'meter',policyVersion:'policy',preparedAt:stamp(t),binding:{subjectId:'subject',status:'registered_config'},scheduler:{slotIdentityStatus:'unverified'},terminal});
  await db.doc(readingPath).set(reading(id,t,accepted));
}
async function bulk(uid,rows){for(let i=0;i<rows.length;i+=400){const batch=db.batch();for(const row of rows.slice(i,i+400))batch.set(db.doc(`users/${uid}/switchbot_readings/${row.id}`),row.data);await batch.commit();}}
const ids=e=>e.readings.map(row=>row.id).sort();

test('window Emulator: more than3000 historical rows do not consume the requested-day reading budget',{skip:!available},async()=>{
  const uid='window-old-history-'+process.pid;
  const oldTime='2026-10-14T01:00:00.000Z';
  await bulk(uid,Array.from({length:3001},(_,i)=>({id:'000-old-'+String(i).padStart(4,'0'),data:reading('old-'+i,oldTime)})));
  await seed(uid,'new-a','2026-10-16T02:00:00.000Z');
  await seed(uid,'new-b','2026-10-16T03:00:00.000Z');
  const evidence=await readSensorQualityEvidence(args(uid));
  assert.deepEqual(ids(evidence),['acq_new-a','acq_new-b']);
  assert.equal(evidence.completeness.readings,'partial');
  assert.ok(evidence.completeness.reasons.includes('legacy_timestamp_population_unverified'));
  assert.equal(evidence.completeness.reasons.includes('readings_limit_reached'),false);
  assert.deepEqual(evidence.readDiagnostics.queryScope,{utcString:'complete',timestamp:'complete'});
  assert.equal(evidence.readDiagnostics.legacyAudit.status,'unknown');
  assert.equal(evidence.readDiagnostics.matchedDocuments.readings,2);
  assert.ok(evidence.readDiagnostics.scannedDocuments.readings>=2);
  assert.ok(evidence.readDiagnostics.scannedDocuments.readings<=66);
  const quality=aggregateSensorQuality({...args(uid),...evidence});
  assert.equal(quality.readings.count,null);
  assert.equal(quality.readings.observed.count,2);
  assert.deepEqual(quality.readings.observed.validValueCount,{temperature:2,humidity:2});
});

test('window Emulator: equal timestamps across page boundaries retain every document exactly once',{skip:!available},async()=>{
  const uid='window-equal-time-'+process.pid,t='2026-10-16T02:00:00.000Z';
  for(const id of ['e','a','d','b','c'])await seed(uid,id,t);
  const evidence=await readSensorQualityEvidence({...args(uid),pageSize:2});
  assert.deepEqual(ids(evidence),['acq_a','acq_b','acq_c','acq_d','acq_e']);
  assert.equal(new Set(ids(evidence)).size,5);
  assert.equal(evidence.completeness.readings,'complete');
});

test('window Emulator: JST half-open bounds and knowledge cutoff exclude future collections and late receipts',{skip:!available},async()=>{
  const uid='window-bounds-'+process.pid;
  await seed(uid,'before','2026-10-15T14:59:59.999Z');
  await seed(uid,'start','2026-10-15T15:00:00.000Z');
  await seed(uid,'inside','2026-10-16T03:00:00.000Z');
  await seed(uid,'cutoff',cutoff);
  await seed(uid,'late','2026-10-16T03:00:00.000Z','2026-10-16T03:20:15.595Z');
  await seed(uid,'future','2026-10-16T03:20:15.595Z');
  await seed(uid,'end','2026-10-16T15:00:00.000Z');
  const quality=aggregateSensorQuality({...args(uid),...await readSensorQualityEvidence(args(uid))});
  assert.equal(quality.readings.count,3);
  assert.equal(quality.distribution.collectionClock.count,3);
  assert.equal(quality.evaluatedThrough,'2026-10-16T03:20:15.594000000Z');
  assert.equal(quality.distribution.collectionClock.endGapSeconds,0);
  assert.equal(quality.distribution.collectionClock.firstAt,'2026-10-15T15:00:00.000000000Z');
  const fullDay=aggregateSensorQuality({...args(uid),knowledgeCutoff:'2026-10-17T00:00:00.000Z',...await readSensorQualityEvidence({...args(uid),knowledgeCutoff:'2026-10-17T00:00:00.000Z'})});
  assert.equal(fullDay.readings.count,5);
  assert.equal(fullDay.sourceManifest.identifiers.readings.ids.includes('acq_end'),false);
});

test('window Emulator: an actual requested-period cap is partial without raising the limit',{skip:!available},async()=>{
  const uid='window-real-cap-'+process.pid;
  for(let i=0;i<5;i++)await seed(uid,'cap'+i,`2026-10-16T0${i}:00:00.000Z`);
  const evidence=await readSensorQualityEvidence({...args(uid),knowledgeCutoff:'2026-10-16T05:00:00.000Z',maxDocuments:3});
  assert.equal(evidence.completeness.readings,'partial');
  assert.ok(evidence.completeness.reasons.includes('readings_limit_reached'));
  assert.equal(evidence.readLimits.maxDocumentsPerCollection,3);
  assert.ok(evidence.readings.length<=3);
  assert.equal(evidence.readDiagnostics.scannedDocuments.readings,3);
  assert.ok(Object.values(evidence.readDiagnostics.scannedDocuments).reduce((a,b)=>a+b,0)<=evidence.readLimits.maxDocumentsTotal);
});

test('window Emulator: immutable replacement snapshot leaves the earlier partial snapshot unchanged',{skip:!available},async()=>{
  const uid='window-replacement-'+process.pid;
  for(let i=0;i<3;i++)await seed(uid,'s'+i,`2026-10-16T0${i}:00:00.000Z`);
  const first=await buildAndSaveSensorQuality({...args(uid),maxDocuments:1});
  const firstDoc=await db.doc(first.path).get(),before=JSON.stringify(firstDoc.data()),beforeTime=firstDoc.updateTime.toMillis();
  const second=await buildAndSaveSensorQuality({...args(uid),supersedesSnapshotId:first.snapshotId});
  assert.equal(second.created,true);
  assert.notEqual(second.snapshotId,first.snapshotId);
  assert.equal(second.quality.readings.count,3);
  const after=await db.doc(first.path).get();
  assert.equal(JSON.stringify(after.data()),before);
  assert.equal(after.updateTime.toMillis(),beforeTime);
  assert.equal((await db.doc(second.path).get()).get('supersedesSnapshotId'),first.snapshotId);
  assert.equal((await db.collection(`users/${uid}/sensor_quality_snapshots`).get()).size,2);
});

test('window Emulator: missing and offset-formatted timestamps are explicit unknown scope instead of a complete zero',{skip:!available},async()=>{
  const uid='window-legacy-unknown-'+process.pid;
  await seed(uid,'known','2026-10-16T02:00:00.000Z');
  await bulk(uid,[
    {id:'legacy-offset',data:{ts:'2026-10-16T11:00:00+09:00',createdAt:stamp('2026-10-16T02:00:00.000Z'),acquisitionId:'legacy-offset',temperature:24,humidity:50}},
    {id:'legacy-missing',data:{createdAt:stamp('2026-10-16T02:00:00.000Z'),acquisitionId:'legacy-missing',temperature:24,humidity:50}},
    {id:'legacy-malformed',data:{ts:12345,createdAt:stamp('2026-10-16T02:00:00.000Z'),acquisitionId:'legacy-malformed',temperature:24,humidity:50}},
  ]);
  const evidence=await readSensorQualityEvidence(args(uid));
  assert.equal(evidence.completeness.readings,'partial');
  assert.ok(evidence.completeness.reasons.length>0);
  const quality=aggregateSensorQuality({...args(uid),...evidence});
  assert.equal(quality.readings.count,null);
  assert.ok(quality.readings.observed.count>=1);
  assert.equal(quality.distribution.collectionClock.maxGapSeconds,null);
});

test('window Emulator: Timestamp ts remains readable without changing its representation',{skip:!available},async()=>{
  const uid='window-timestamp-'+process.pid,t='2026-10-16T02:00:00.000Z';
  await db.doc(`users/${uid}/integrations/switchbot`).set({meterDeviceId:'meter'});
  await bulk(uid,[{id:'timestamp-reading',data:{ts:stamp(t),createdAt:stamp(t),temperature:24,humidity:50}}]);
  const input={...args(uid),knowledgeCutoff:'2027-01-01T00:00:00.000Z'};
  const evidence=await readSensorQualityEvidence(input);
  assert.deepEqual(ids(evidence),['timestamp-reading']);
  assert.ok(evidence.readings[0].data.ts instanceof admin.firestore.Timestamp);
  const quality=aggregateSensorQuality({...input,...evidence});
  assert.equal(quality.readings.count,1);
  assert.equal(quality.readings.legacyCount,1);
});

test('window Emulator: delayed response outside the collection window still supports the earlier verified slot',{skip:!available},async()=>{
  const uid='window-delayed-reference-'+process.pid,t='2026-10-16T14:14:00.000Z',later='2026-10-16T15:05:00.000Z';
  await seed(uid,'delayed',t,later);
  await db.doc(`users/${uid}/switchbot_readings/acq_delayed`).update({ts:later});
  await db.doc(`users/${uid}/sensor_acquisition_attempts/delayed`).update({
    scheduler:{logicalSlotId:'slot-delayed',scheduledFor:t,slotIdentityStatus:'verified'},
    'terminal.responseReceivedAt':later,'terminal.readingTs':later,
  });
  const input={...args(uid),knowledgeCutoff:'2026-10-17T00:00:00.000Z'};
  const quality=aggregateSensorQuality({...input,...await readSensorQualityEvidence(input)});
  assert.equal(quality.opportunities.validCount.both,1);
  assert.equal(quality.acquisitions.readingSaveUnknownCount,0);
  assert.equal(quality.readings.count,0);
  assert.equal(quality.distribution.collectionClock.count,0);
});

test('window Emulator: selected reading keeps its device association when older attempt history exhausts the context budget',{skip:!available},async()=>{
  const uid='window-attempt-history-'+process.pid,cap=6,t='2026-10-16T02:00:00.000Z';
  const batch=db.batch();
  for(let i=0;i<8;i++)batch.set(db.doc(`users/${uid}/sensor_acquisition_attempts/000-history-${i}`),{
    attemptId:`000-history-${i}`,route:'scheduled',deviceId:'meter',policyVersion:'policy',
    preparedAt:stamp('2026-10-14T01:00:00.000Z'),scheduler:{slotIdentityStatus:'unverified'},
    terminal:{status:'request_failed',requestAttempted:true,requestStartedAt:'2026-10-14T01:00:00.000Z',acceptedAt:stamp('2026-10-14T01:00:00.000Z'),errorCode:'network_error'},
  });
  await batch.commit();
  await seed(uid,'zz-target',t);
  const input={...args(uid),deviceId:'meter',maxDocuments:cap};
  const evidence=await readSensorQualityEvidence(input);
  assert.equal(evidence.completeness.attempts,'partial');
  assert.ok(evidence.completeness.reasons.includes('attempts_limit_reached'));
  assert.equal(evidence.readDiagnostics.scannedDocuments.attempts,cap);
  assert.ok(evidence.attempts.some(row=>row.id==='zz-target'));
  const quality=aggregateSensorQuality({...input,...evidence});
  assert.equal(quality.readings.observed.count,1);
  assert.deepEqual(quality.readings.observed.validValueCount,{temperature:1,humidity:1});
  assert.equal(quality.readings.count,null);
  assert.equal(quality.readings.countStatus,'unknown');
  assert.equal(quality.acquisitions.confirmedAttemptCount,null);
  assert.equal(quality.acquisitions.observed.confirmedAttemptCount,1);
  assert.equal(quality.completeness.reasons.includes('device_membership_unknown'),false);
  assert.deepEqual(quality.binding.subjectIds,['subject']);
});

test('window Emulator: cutoff-later documents cannot enter old-cutoff observations, while lost legacy coverage remains explicit',{skip:!available},async()=>{
  const uid='window-future-inventory-'+process.pid,t='2026-10-16T02:00:00.000Z';
  await seed(uid,'known',t);
  const input={...args(uid),deviceId:'meter'};
  const first=await buildAndSaveSensorQuality(input);
  assert.equal(first.quality.readings.count,1);
  const stored=await db.doc(first.path).get(),before=JSON.stringify(stored.data()),beforeTime=stored.updateTime.toMillis();
  await bulk(uid,Array.from({length:65},(_,i)=>({id:'000-future-'+String(i).padStart(3,'0'),data:reading('future-'+i,'2026-10-16T04:00:00.000Z')})));
  const evidence=await readSensorQualityEvidence(input);
  const quality=aggregateSensorQuality({...input,...evidence});
  assert.equal(quality.readings.observed.count,1);
  assert.deepEqual(quality.readings.observed.validValueCount,{temperature:1,humidity:1});
  assert.equal(quality.readings.count,null);
  assert.equal(quality.readings.countStatus,'unknown');
  assert.equal(quality.completeness.readings,'partial');
  assert.ok(quality.completeness.reasons.includes('legacy_timestamp_population_unverified'));
  assert.deepEqual(quality.sourceManifest.identifiers.readings.ids,['acq_known']);
  assert.equal(quality.distribution.collectionClock.count,null);
  assert.equal(quality.distribution.collectionClock.observed.count,1);
  assert.equal(quality.distribution.collectionClock.observed.lastAt,'2026-10-16T02:00:00.000000000Z');
  const second=await buildAndSaveSensorQuality({...input,supersedesSnapshotId:first.snapshotId});
  assert.equal(second.created,true);
  assert.notEqual(second.snapshotId,first.snapshotId);
  assert.equal((await db.doc(second.path).get()).get('supersedesSnapshotId'),first.snapshotId);
  const after=await db.doc(first.path).get();
  assert.equal(JSON.stringify(after.data()),before);
  assert.equal(after.updateTime.toMillis(),beforeTime);
});
