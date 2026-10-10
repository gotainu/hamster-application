'use strict';
const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');const vm=require('node:vm');const test=require('node:test');const ts=require('typescript');
function load(){
 const calls=[];const legacyCalls=[];const definitions=[];const fixed='2026-10-08T02:00:00Z';class FixedDate extends Date{constructor(...args){super(...(args.length?args:[fixed]));}}
 const file=path.resolve(__dirname,'../src/health/personalityTriggers.ts');const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
 const mod={exports:{}};const req=name=>{
  if(name==='firebase-functions/v2/firestore')return {onDocumentWritten:(config,handler)=>{definitions.push(config);return handler;}};
  if(name==='firebase-admin')return {firestore:()=>({emulatorFixture:true})};
  if(name==='./dateKey')return {formatDateKey:()=> '2026-10-08',normalizeDateKey:key=>key};
  if(name==='./personalityReport')return {syncPersonalityReport:async params=>legacyCalls.push(params)};
  if(name==='./personalityDaily')return {enqueueDailyPersonalityReport:async params=>calls.push(params),enqueueDailyPersonalityRecord:async params=>calls.push(params)};
  throw new Error(name);
 };
 vm.runInNewContext('(function(exports,require,module){'+code+'\n})',{Date:FixedDate})(mod.exports,req,mod);
 return {run:mod.exports.personalityHealthFeaturesWritten,runDistance:mod.exports.personalityDistanceRecordWritten,calls,legacyCalls,options:definitions[0],distanceOptions:definitions[1]};
}
test('current Silver trigger preserves v1 publication before independent daily enqueue',async()=>{
 const m=load();assert.equal(m.options.document,'users/{uid}/daily_health_features/{dateKey}');assert.equal(m.options.retry,true);
 await m.run({params:{uid:'fixture',dateKey:'2026-10-08'},data:{after:{exists:true}}});
 assert.equal(m.legacyCalls.length,1);assert.equal(m.legacyCalls[0].uid,'fixture');assert.equal(m.legacyCalls[0].evaluationDateKey,'2026-10-08');
 assert.equal(m.calls.length,1);assert.equal(m.calls[0].uid,'fixture');assert.equal(m.calls[0].sourceDateKey,'2026-10-08');assert.equal(m.calls[0].now.toISOString(),'2026-10-08T02:00:00.000Z');
});
test('historical, future and deleted Silver events do not run the publisher',async()=>{
 const m=load();for(const dateKey of ['2026-09-23','2026-10-09'])await m.run({params:{uid:'fixture',dateKey},data:{after:{exists:true}}});
 await m.run({params:{uid:'fixture',dateKey:'2026-10-08'},data:{after:{exists:false}}});assert.equal(m.calls.length,0);assert.equal(m.legacyCalls.length,0);
});


test('today distance Bronze trigger bridges the deferred health assessment using a queue-only API',async()=>{
 const m=load();assert.equal(m.distanceOptions.document,'users/{uid}/distance_records/{recordId}');assert.equal(m.distanceOptions.retry,true);
 await m.runDistance({params:{uid:'fixture',recordId:'2026-10-08'},data:{after:{exists:true,data:()=>({dayKey:'2026-10-08',distance:0})}}});
 assert.equal(m.calls.length,1);assert.equal(m.calls[0].recordDateKey,'2026-10-08');assert.equal(m.legacyCalls.length,0);
});
test('past/future/deleted/invalid distance records do not queue Bronze work',async()=>{
 const m=load();for(const key of ['2026-10-07','2026-10-09'])await m.runDistance({params:{uid:'fixture',recordId:key},data:{after:{exists:true,data:()=>({dayKey:key,distance:1})}}});
 for(const distance of [-1,NaN,'100'])await m.runDistance({params:{uid:'fixture',recordId:'2026-10-08'},data:{after:{exists:true,data:()=>({dayKey:'2026-10-08',distance})}}});
 await m.runDistance({params:{uid:'fixture',recordId:'2026-10-08'},data:{after:{exists:false}}});assert.equal(m.calls.length,0);assert.equal(m.legacyCalls.length,0);
});
