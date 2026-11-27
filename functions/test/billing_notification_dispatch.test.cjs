'use strict';
// Exercises the actual scheduled entry point with inert Admin/Secret/Gmail
// capabilities. No cloud service, credential or business record is accessed.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const dispatch=loadStarSource()('billingNotificationDispatch');
const NOW=Date.UTC(2030,0,1);
function scheduled(env={}) {
  const calls={secret:0,auth:0,db:0,runtime:0,run:0,info:[],warn:[]};
  const input={...env};
  Object.defineProperty(input,'HAMCARE_LIVE_BILLING_MAIL_CONFIG',{get(){calls.secret++;return 'synthetic-mail-config';}});
  const mod={exports:{}};
  const source=fs.readFileSync(path.resolve(__dirname,'../src/billingNotifications.ts'),'utf8');
  const code=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const req=name=>{
    if(name==='firebase-admin/auth')return {getAuth(){calls.auth++;return {};}};
    if(name==='firebase-admin/firestore')return {getFirestore(){calls.db++;return {};}};
    if(name==='firebase-functions/params')return {defineSecret:()=>({})};
    if(name==='firebase-functions/v2/scheduler')return {onSchedule:(options,fn)=>Object.assign(fn,{options})};
    if(name==='firebase-functions/logger')return {info:(...x)=>calls.info.push(x),warn:(...x)=>calls.warn.push(x)};
    if(name==='./billingNotificationDispatch')return dispatch;
    if(name==='./billingNotificationRuntime')return {createBillingNotificationRuntime(d){calls.runtime++;calls.dependencies=d;d.rawConfig();return {async runOnce(){calls.run++;return {processed:0,counts:{}};}};}};
    throw Error('Unexpected dependency');
  };
  vm.runInThisContext('(function(exports,require,module,process,Date){'+code+'\n})')(mod.exports,req,mod,{env:input},{now:()=>NOW});
  return {run:mod.exports.processBillingNotificationOutbox,calls};
}
function noCapabilities(f){for(const key of ['secret','auth','db','runtime','run'])assert.equal(f.calls[key],0,key);}
for(const enabled of [undefined,'','false'])test('disabled schedule never reads Secret/Auth/queue/counters/Gmail '+String(enabled),async()=>{
  const f=scheduled({HAMCARE_BILLING_NOTIFICATIONS_ENABLED:enabled});await f.run();noCapabilities(f);
  assert.equal(f.calls.warn.length,0);assert.equal(f.calls.info[0][1].state,'disabled');
});
for(const cutoff of [undefined,'','0','-1','not-a-date',String(NOW+1),String(NOW-1),'9999999999999999'])
  test('enabled schedule with missing/invalid/future cutoff stops before capabilities '+String(cutoff),async()=>{
    const f=scheduled({HAMCARE_BILLING_NOTIFICATIONS_ENABLED:'true',HAMCARE_BILLING_NOTIFICATIONS_NOT_BEFORE_MILLIS:cutoff});
    await f.run();noCapabilities(f);assert.equal(f.calls.warn.length,1);
  });
for(const enabled of ['TRUE','1',true])test('noncanonical enabled value cannot start delivery '+String(enabled),async()=>{
  const f=scheduled({HAMCARE_BILLING_NOTIFICATIONS_ENABLED:enabled,HAMCARE_BILLING_NOTIFICATIONS_NOT_BEFORE_MILLIS:String(NOW)});
  await f.run();noCapabilities(f);assert.equal(f.calls.warn.length,1);
});
test('explicit fixed cutoff is passed unchanged to actual runtime boundary',async()=>{
  const start=NOW-60000,f=scheduled({HAMCARE_BILLING_NOTIFICATIONS_ENABLED:'true',HAMCARE_BILLING_NOTIFICATIONS_NOT_BEFORE_MILLIS:String(start),HAMCARE_BILLING_MAIL_DAILY_LIMIT:'50'});
  await f.run();assert.equal(f.calls.run,1);assert.equal(f.calls.dependencies.liveDispatchNotBeforeMillis,start);
  assert.equal(f.calls.dependencies.dailyLimit,50);assert.equal(f.calls.warn.length,0);
  assert.equal(f.run.options.retryCount,0);assert.equal(f.run.options.maxInstances,1);
});
