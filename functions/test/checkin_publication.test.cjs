
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const vm=require('node:vm');
const {test}=require('node:test');const {createRequire}=require('node:module');
const dep=process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE?createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE):require;
const ts=dep('typescript');
function load(file,cache=new Map()){if(cache.has(file))return cache.get(file).exports;const mod={exports:{}};cache.set(file,mod);const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;const req=name=>name.startsWith('.')?load(path.resolve(path.dirname(file),`${name}.ts`),cache):dep(name);vm.runInThisContext(`(function(exports,require,module){${code}\n})`,{filename:file})(mod.exports,req,mod);return mod.exports;}
const publication=load(path.resolve(__dirname,'../src/health/checkinPublication.ts'));
const candidate=(kind,count=7,itemId='appetite',extra={})=>publication.checkinPublicationCandidate({schemaVersion:1,calculationSpecVersion:'checkin_insights_v1',evaluationDateKey:'2026-10-09',windowEndDateKey:'2026-10-09',insights:[{kind,eligible:true,metric:'condition',evidence:{matchingDayCount:count,itemId},...extra}]});
test('A publication uses stable item identity and material count bands, not evidence dates or wording',()=>{
 const a=candidate('checkin_item_repetition',3);const b=candidate('checkin_item_repetition',6,'appetite',{semanticFingerprint:'changed',observationStartDateKey:'2026-09-27'});
 assert.deepEqual(a.materialityKeys,b.materialityKeys);assert.equal(a.semanticSignature,b.semanticSignature);
 assert.notDeepEqual(a.materialityKeys,candidate('checkin_item_repetition',7).materialityKeys);
 assert.notDeepEqual(a.materialityKeys,candidate('checkin_item_repetition',3,'water').materialityKeys);
});
test('B publication changes only at explicit material count bands',()=>{
 assert.deepEqual(candidate('checkin_concern_frequency',2).materialityKeys,candidate('checkin_concern_frequency',6).materialityKeys);
 assert.notDeepEqual(candidate('checkin_concern_frequency',6).materialityKeys,candidate('checkin_concern_frequency',7).materialityKeys);
 assert.notDeepEqual(candidate('checkin_concern_frequency',10).materialityKeys,candidate('checkin_concern_frequency',11).materialityKeys);
});
test('C milestone is fixed across count increases, rolling dates and evidence changes',()=>{
 assert.deepEqual(candidate('checkin_record_continuity',7).materialityKeys,candidate('checkin_record_continuity',14).materialityKeys);
});
test('published keys suppress retries and later returns to the same observation meaning',()=>{
 const a=candidate('checkin_item_repetition',3);const state=publication.mergeCheckinPublicationState(null,a);
 assert.equal(publication.hasNewCheckinPublication(a,state),false);
 assert.equal(publication.hasNewCheckinPublication(candidate('checkin_item_repetition',7),state),true);
 assert.equal(publication.hasNewCheckinPublication(candidate('checkin_record_continuity',7),state),false);
});
test('only saved publication state is authoritative; unrelated report snapshots do not infer delivery',()=>{
 const a=candidate('checkin_concern_frequency',2);
 const prior={checkinInsights:{schemaVersion:1,calculationSpecVersion:'checkin_insights_v1',evaluationDateKey:'2026-10-09',windowEndDateKey:'2026-10-08',insights:[{kind:'checkin_concern_frequency',eligible:true,metric:'condition',evidence:{matchingDayCount:2}}]}};
 const state=publication.readCheckinPublicationState(null,prior);
 assert.deepEqual(state.seenMaterialityKeys,[]);
 assert.equal(publication.hasNewCheckinPublication(a,state),true);
});
test('missing malformed unknown or below-threshold snapshots cannot publish',()=>{
 for(const x of [null,{},candidate('checkin_record_continuity',6),candidate('checkin_item_repetition',2),candidate('checkin_concern_frequency',1)]){
  const value=x?.materialityKeys?x:publication.checkinPublicationCandidate(x);assert.deepEqual(value.materialityKeys,[]);
 }
 assert.deepEqual(candidate('unknown',8).materialityKeys,[]);
});

test('A consumes its covered concern stage, without hidden evidence counts changing its visible signature',()=>{
 const a=candidate('checkin_item_repetition',3,'appetite',{evidence:{matchingDayCount:3,itemId:'appetite',concernDayCount:3}});
 const state=publication.mergeCheckinPublicationState(null,a);
 assert.equal(publication.hasNewCheckinPublication(candidate('checkin_concern_frequency',3),state),false);
 const moreConcerns=candidate('checkin_item_repetition',3,'appetite',{evidence:{matchingDayCount:3,itemId:'appetite',concernDayCount:7}});
 assert.equal(a.semanticSignature,moreConcerns.semanticSignature);
 assert.equal(publication.hasNewCheckinPublication(candidate('checkin_concern_frequency',7),state),true);
 assert.deepEqual(publication.readCheckinPublicationState(state).seenMaterialityKeys,state.seenMaterialityKeys);
 assert.equal(publication.hasNewCheckinPublication(candidate('checkin_concern_frequency',3),publication.readCheckinPublicationState(state)),false);
});
