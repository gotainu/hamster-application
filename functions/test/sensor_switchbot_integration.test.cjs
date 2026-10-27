'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript'),crypto=require('node:crypto');
const {SensorRequestError,deriveSchedulerContext}=require('../lib/sensorQuality/acquisition');
const source=fs.readFileSync(path.resolve(__dirname,'../src/index.ts'),'utf8');
function load(overrides={}) {
 const a=source.indexOf('async function getMeterStatus('),b=source.indexOf('type PollAllResult =',a);
 const code=ts.transpileModule(source.slice(a,b),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
 const context={SensorRequestError,crypto,db:{},logger:{warn(){}},buildHeaders:()=>({}),saveEnvironmentAssessmentLatest:async()=>{},...overrides};
 return vm.runInNewContext(`(function(){${code};return {getMeterStatus,sensorPollingContext,acquireSwitchbotForUser};})()`,context);
}
test('status API preserves legacy extracted values even for invalid quality, with no real request',async()=>{
 let calls=0;const api=load({fetch:async url=>{calls++;assert.match(url,/\/v1\.1\/devices\/meter\/status$/);return {ok:true,status:200,json:async()=>({statusCode:190,body:{temperature:22,humidity:'50',battery:0}})};}});
 const result=await api.getMeterStatus('meter','not-real-token','not-real-secret');
 assert.deepEqual(JSON.parse(JSON.stringify(result.reading)),{temperature:22,humidity:null,battery:0});
 assert.equal(result.api.providerStatusCode,190);assert.equal(calls,1);
});
test('request errors retain only safe codes, never response body or transport secrets',async()=>{
 for(const [response,expected] of [[async()=>{throw Error('token secret rawbody');},'network_error'],[async()=>({ok:false,status:503,text:async()=>{throw Error('must not read private body');}}),'http_error'],[async()=>({ok:true,status:200,json:async()=>{throw Error('private payload');}}),'parse_error']]){
  const api=load({fetch:response});await assert.rejects(api.getMeterStatus('meter','token','secret'),e=>e.code===expected&&!/token|secret|rawbody|payload/.test(e.message));
 }
});
test('signing preflight failure is unknown, not a confirmed communication failure',async()=>{
 let requested=0;const api=load({buildHeaders:()=>{throw Error('secret preflight');},fetch:async()=>{requested++;}});
 await assert.rejects(api.getMeterStatus('meter','x','y'),e=>e.code==='unknown_error');assert.equal(requested,0);
});
test('shared acquisition wrapper uses one request and existing assessment, candidate retries have stable identity only',async()=>{
 let request=0,assess=0;const captures=[];
 const api=load({fetch:async()=>{request++;return {ok:true,status:200,json:async()=>({statusCode:100,body:{temperature:22,humidity:50,battery:90}})};},
  saveEnvironmentAssessmentLatest:async uid=>{assert.equal(uid,'owner');assess++;},
  runSensorAcquisition:async o=>{captures.push(o);const result=await o.request();await o.assess();return {reading:result.reading,evidenceStatus:'verified'};}});
 const scheduler=deriveSchedulerContext({jobName:'scheduler-job',scheduleTime:'2026-10-16T01:14:04Z'});
 const one=api.sensorPollingContext('scheduled',scheduler),two=api.sensorPollingContext('scheduled',scheduler);
 assert.equal(one.invocationId,two.invocationId);assert.equal(scheduler.logicalSlotId,null);
 await api.acquireSwitchbotForUser('owner',{meterDeviceId:'meter',token:'x',secret:'y'},one);
 await api.acquireSwitchbotForUser('owner',{meterDeviceId:'meter',token:'x',secret:'y'},two);
 assert.equal(captures[0].attemptId,captures[1].attemptId);assert.equal(captures[0].route,'scheduled');assert.equal(request,2);assert.equal(assess,2);
 const manual=api.sensorPollingContext('manual_owner'),manual2=api.sensorPollingContext('manual_owner');assert.notEqual(manual.invocationId,manual2.invocationId);
});
test('scheduled export retains 60-minute options, no retry change; SDK manual fallback cannot verify slot',async()=>{
 const a=source.indexOf('export const switchbotPoller = onSchedule('),b=source.indexOf('\n\nexport {',a);
 const fragment=ts.transpileModule(source.slice(a,b),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
 let options,handler,context;const scheduler=deriveSchedulerContext({scheduleTime:'2026-10-16T01:14:04Z'});
 const api=load();vm.runInNewContext(fragment,{exports:{},ENVELOPE_KEY_SECRET:'secret-reference-only',deriveSchedulerContext,sensorPollingContext:api.sensorPollingContext,pollAllUsersOnce:async c=>{context=c;},onSchedule:(o,h)=>{options=o;handler=h;return h;}});
 assert.equal(options.schedule,'every 60 minutes');assert.equal(options.region,'asia-northeast1');assert.equal('retryCount' in options,false);assert.equal('timeZone' in options,false);
 await handler({scheduleTime:'2026-10-16T01:14:04Z'});assert.equal(context.route,'unknown');assert.equal(context.scheduler.logicalSlotId,null);assert.equal(scheduler.slotIdentityStatus,'not_applicable');
});
test('all-user selection and entitlement decisions are unchanged, prepared-only replay is not counted saved',async()=>{
 const a=source.indexOf('async function pollAllUsersOnce('),b=source.indexOf('export const disableSwitchbotIntegration',a);
 const code=ts.transpileModule(source.slice(a,b),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
 const acquired=[];const context={route:'scheduled',invocationId:'test'};
 const poll=vm.runInNewContext(`(function(){${code};return pollAllUsersOnce;})()`,{
  db:{collection:name=>{assert.equal(name,'switchbot_users');return {where:(field,op,value)=>{assert.deepEqual([field,op,value],['hasSwitchbot','==',true]);return {get:async()=>({size:4,docs:['valid','unpaid','missing','pending'].map(id=>({id}))})};}};}},
  assertPaidFeatureAccess:async uid=>{if(uid==='unpaid')throw Error('denied');},
  loadUserConfig:async uid=>uid==='missing'?{}:{token:'x',secret:'y',meterDeviceId:'meter'},
  acquireSwitchbotForUser:async(uid,config,c)=>{assert.equal(c,context);acquired.push(uid);return {evidenceStatus:uid==='pending'?'pending':'verified'};},logger:{info(){},error(){}},sensorPollingContext:()=>context,
 });
 const result=await poll(context);assert.deepEqual(JSON.parse(JSON.stringify(result)),{total:4,saved:1,skipped:3,failed:0});assert.deepEqual(acquired,['valid','pending']);
});
