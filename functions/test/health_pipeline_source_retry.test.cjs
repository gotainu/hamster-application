'use strict';
const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');const vm=require('node:vm');const {test}=require('node:test');const {createRequire}=require('node:module');
const dep=process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE?createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE):require;const ts=dep('typescript');
const NOW='2026-10-14T06:00:00Z';
test('source-version conflicts retry fresh Bronze at most three times and propagate without writes or side effects',async()=>{
 let bronzeReads=0,writes=0,syncs=0,versions=0,transactions=0;
 const stamp=version=>({version,isEqual(other){return this.version===other.version;}});
 const snapshot=version=>({exists:true,updateTime:stamp(version),data:()=>({generatedAt:new Date(NOW)})});
 class Ref{constructor(path){this.path=path;}collection(name){return new Ref(`${this.path}/${name}`);}doc(name){return new Ref(`${this.path}/${name}`);}async get(){return snapshot(++versions);}}
 const db={collection:name=>new Ref(name),runTransaction:async cb=>{transactions++;versions++;return cb({get:async()=>snapshot(versions),set:()=>{writes++;}});}};
 const root=path.resolve(__dirname,'../src/health');const cache=new Map();function load(file){if(cache.has(file))return cache.get(file).exports;const mod={exports:{}};cache.set(file,mod);const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
 const req=name=>name==='firebase-admin'?{firestore:{FieldValue:{serverTimestamp:()=>null}}}:name==='firebase-functions/logger'?{info:()=>{},error:()=>{}}:name==='./firestoreReaders'?{fetchHealthSourceData:async()=>{bronzeReads++;return {};}}:name==='./dailyHealthFeatures'?{buildDailyHealthFeatures:()=>({features:{dateKey:'2026-10-14',schemaVersion:5,generatedAt:new Date(NOW)},bodyAssessment:{}})}:name==='./healthAssessment'?{buildHealthAssessment:()=>({})}:name==='./weightInsights'?{buildCurrentInsightSet:()=>null,persistCurrentInsightSet:()=>{writes++;}}:name==='./firstPersonalizedReport'?{syncPersonalizedAnalysis:()=>{syncs++;}}:name==='./goldHealthNotification'?{}:name==='./healthIncidentLifecycle'?{}:name.startsWith('.')?load(path.resolve(path.dirname(file),`${name}.ts`)):dep(name);
 class FixedDate extends Date{constructor(...args){super(...(args.length?args:[NOW]));}}
 vm.runInThisContext(`(function(exports,require,module,Date){${code}\n})`)(mod.exports,req,mod,FixedDate);return mod.exports;}
 const pipeline=load(path.join(root,'healthPipeline.ts'));
 await assert.rejects(pipeline.rebuildHealthForDate({uid:'source-conflict-unit',dateKey:'2026-10-14',reason:'manual_rebuild',db}),/Health source version changed/);
 assert.equal(bronzeReads,3);assert.equal(transactions,3);assert.equal(writes,0);assert.equal(syncs,0);
});
