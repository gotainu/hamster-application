'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');
const {createRequire} = require('node:module');
const {test} = require('node:test');
const dep = process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE ? createRequire(process.env.HAMCARE_TEST_DEPENDENCY_PACKAGE) : require;
const ts = dep('typescript');
function load(file, cache = new Map()) {
  if (cache.has(file)) return cache.get(file).exports;
  const mod = {exports: {}}; cache.set(file, mod);
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true}}).outputText;
  const req = name => name.startsWith('.') ? load(path.resolve(path.dirname(file), `${name}.ts`), cache) : dep(name);
  vm.runInThisContext(`(function(exports, require, module) {${code}\n})`, {filename: file})(mod.exports, req, mod);
  return mod.exports;
}
const root = path.resolve(__dirname, '../src/health');
const checkins = load(path.join(root, 'checkinInsights.ts'));
const catalog = load(path.join(root, 'observationCatalog.ts'));
const weight = load(path.join(root, 'weightInsights.ts'));
const day = '2026-10-14'; const now = new Date('2026-10-14T02:00:00Z');
const input = (dateKey, tags=[], condition=tags.length?'slightlyConcerned':'normal', extra={}) => ({id:dateKey,data:{dayKey:dateKey,schemaVersion:2,condition,concernTags:tags,observationLevels:Object.fromEntries(catalog.observationCatalog.filter(x=>x.defaultNormal).map(x=>[x.id,tags.includes(x.id)?'changed':'normal'])),...extra}});
const records = (count=7,tags=[]) => Array.from({length:count},(_,i)=>input(`2026-10-${String(i+1).padStart(2,'0')}`,i<3?tags:[]));
const evidence = (source, extra={}) => checkins.buildCheckinInsightEvidence({records:source,evaluationDateKey:day,...extra});
const envelope = (source,extra={}) => checkins.buildCheckinInsights({evidence:evidence(source,extra),generatedAt:now,catalog:extra.catalog});
test('catalog governs every item and normal defaults never become explicit responses',()=>{
 const value=evidence([input('2026-10-01')]);
 assert.equal(value.records[0].items.appetite.origin,'automatic_normal');
 assert.equal(value.itemAnsweredDayCount,null);
 assert.equal(value.validRecordDayCount,1); assert.equal(value.missingDayCount,13);
 assert.equal(value.selectionVerifiedDayCount,1);
 assert.ok(!JSON.stringify(value).includes('secret memo'));
});
test('A needs seven verifiable selection days and three distinct positive days, suppressing B',()=>{
 assert.equal(envelope(records(6,['appetite'])).insights.length,0);
 const value=envelope(records(7,['appetite']));
 assert.equal(value.insights.length,1); assert.equal(value.insights[0].kind,'checkin_item_repetition');
 assert.equal(value.insights[0].evidence.matchingDayCount,3);
 assert.equal(value.insights[0].evidence.selectionVerifiedDayCount,7);
 assert.equal(value.insights[0].evidence.itemLabel,'食欲');
 assert.equal(value.insights[0].discovery,true);
});
test('B needs seven conditions and two concerns; C is recording status, not a discovery',()=>{
 const base=records(); base[0]=input('2026-10-01',['other']); base[1]=input('2026-10-02',['other'],'veryConcerned');
 assert.equal(envelope(base).insights[0].kind,'checkin_concern_frequency');
 assert.equal(envelope(base).insights[0].evidence.concernDayCount,2);
 base[1]=input('2026-10-02'); assert.equal(envelope(base).insights[0].kind,'checkin_record_continuity');
 assert.equal(envelope(base).insights[0].discovery,false);
});
test('old schema preserves known selected tags, aliases and retired items without invented normals',()=>{
 const value=evidence([{id:'2026-10-01',data:{condition:'slightlyConcerned',concernTags:['poop','elimination','chewing']}}]);
 assert.deepEqual(value.records[0].selectedItemIds,['elimination','chewing']);
 assert.equal(value.records[0].items.elimination.origin,'selected_tag');
 assert.equal(value.records[0].items.appetite.origin,'unanswered');
 assert.equal(value.records[0].legacy,true);
});
test('unknown conditions and missing/invalid values never fall back to normal',()=>{
 const value=evidence([input('2026-10-01',[], 'unknown'),input('2026-10-02',[], 'normal',{dayKey:'2026-10-03'}),input('2026-10-04',[], 'normal',{concernTags:['unknown']})]);
 assert.equal(value.validRecordDayCount,1); assert.equal(value.invalidDayCount,2);
 assert.equal(value.selectionVerifiedDayCount,0);
 assert.equal(value.records[0].items.appetite.origin,'automatic_normal');
});
test('same-day duplicates count once and latest correction deterministically wins',()=>{
 const a=input('2026-10-01',['appetite']); a.updatedAt=new Date('2026-10-01T01:00:00Z');
 const b={...input('2026-10-01'),id:'20261001',updatedAt:new Date('2026-10-01T02:00:00Z')};
 const value=evidence([a,b]); assert.equal(value.validRecordDayCount,1); assert.equal(value.duplicateRecordCount,1);
 assert.deepEqual(value.records[0].selectedItemIds,[]);
});
test('Current and Report have distinct inclusive fourteen-calendar-day windows',()=>{
 const source=[input('2026-09-30'),input('2026-10-01'),input('2026-10-13'),input('2026-10-14'),input('2026-10-15')];
 assert.deepEqual(evidence(source).records.map(x=>x.dateKey),['2026-10-01','2026-10-13','2026-10-14']);
 const report=evidence(source,{windowEndDateKey:'2026-10-13'});
 assert.deepEqual(report.records.map(x=>x.dateKey),['2026-09-30','2026-10-01','2026-10-13']);
 assert.equal(report.windowStartDateKey,'2026-09-30');
});
test('added renamed reordered and retired catalog entries need no aggregation special cases',()=>{
 const changed=catalog.observationCatalog.map(x=>({...x,aliases:[...x.aliases],legacyNames:[...x.legacyNames]}));
 changed.push({id:'new_item',label:'新しい項目',order:0,active:true,insightEligible:true,defaultNormal:false,aliases:[],legacyNames:[]});
 const source=records(7,['new_item']);
 let value=envelope(source,{catalog:changed}); assert.equal(value.insights[0].evidence.itemId,'new_item');
 changed.find(x=>x.id==='new_item').label='名称変更';
 value=envelope(source,{catalog:changed}); assert.equal(value.insights[0].evidence.itemLabel,'名称変更');
 changed.find(x=>x.id==='new_item').active=false;
 value=envelope(source,{catalog:changed}); assert.equal(value.insights[0].kind,'checkin_concern_frequency');
 assert.ok(evidence(source,{catalog:changed}).records[0].selectedItemIds.includes('new_item'));
});
test('semantic discovery identity does not change merely because evaluation/generated date advances',()=>{
 const source=records(7,['appetite']).map((x,i)=>input(`2026-10-${String(i+2).padStart(2,'0')}`,i<3?['appetite']:[])); const a=envelope(source); const b=envelope(source,{evaluationDateKey:'2026-10-15'});
 assert.equal(a.insights[0].semanticFingerprint,b.insights[0].semanticFingerprint);
 assert.equal(a.insights[0].sourceGeneratedAt.getTime(),now.getTime());
});
test('corrected and deleted observations change current facts while old snapshot remains frozen',()=>{
 const source=records(7,['appetite']); const old=JSON.stringify(envelope(source));
 const corrected=source.map(x=>x.id==='2026-10-01'?input(x.id):x);
 assert.equal(envelope(corrected).insights[0].kind,'checkin_concern_frequency');
 assert.equal(envelope(source.slice(1)).insights.length,0);
 assert.equal(JSON.stringify(envelope(source)),old);
});
test('weight API remains backward compatible and optional checkin-only set works without weight evidence',()=>{
 const features={dateKey:day,schemaVersion:5,generatedAt:now,body:{personalBaseline:{status:'learning'}},checkinInsightEvidence:evidence(records(7,['appetite']))};
 const value=weight.buildCurrentInsightSet({features,generatedAt:now});
 assert.deepEqual(value.insights,[]); assert.equal(value.checkinInsights.insights[0].metric,'condition');
 assert.equal(value.calculationSpecVersion,'weight_insights_v1');
 assert.equal(weight.buildCurrentInsightSet({features:{...features,checkinInsightEvidence:undefined},generatedAt:now}),null);
});

test('normal plus selected known tag is contradictory and excluded rather than counted as no concern',()=>{const value=evidence([input('2026-10-01',['appetite'],'normal')]);assert.equal(value.validRecordDayCount,0);assert.equal(value.invalidDayCount,1);});
test('historical create update and delete affect S..S+13 only, bounded at today',()=>{assert.deepEqual(checkins.affectedCheckinEvaluationDates('2026-10-01','2026-10-14'),Array.from({length:14},(_,i)=>`2026-10-${String(i+1).padStart(2,'0')}`));assert.deepEqual(checkins.affectedCheckinEvaluationDates('2026-10-13','2026-10-14'),['2026-10-13','2026-10-14']);assert.deepEqual(checkins.affectedCheckinEvaluationDates('2026-10-15','2026-10-14'),[]);assert.equal(checkins.affectedCheckinEvaluationDates('2026-09-01','2026-10-14').includes('2026-10-14'),false);});

test('schema2 inconsistent levels or malformed maps cannot verify selection information',()=>{
 for(const extra of [{observationLevels:{appetite:'normal'}},{observationLevels:{appetite:'concerning'}},{observationLevels:{appetite:'changed',water:'changed'}},{observationLevels:[]},{observationLevels:{poop:'normal',elimination:'changed'}}]){
  const value=evidence([input('2026-10-01',['appetite'],'slightlyConcerned',extra)]);
  assert.equal(value.selectionVerifiedDayCount,0); assert.equal(value.invalidObservationRecordDayCount,1);
 }
 const value=evidence([input('2026-10-01',['appetite'],'slightlyConcerned',{observationLevels:{appetite:'normal'}})]);
 assert.equal(value.records[0].items.appetite.level,'normal'); assert.equal(value.records[0].items.appetite.origin,'invalid');
});
test('explicit future response metadata rejects unknown answered IDs rather than partially trusting them',()=>{
 const value=evidence([input('2026-10-01',[],'normal',{observationResponseMode:'explicit_items_v1',answeredObservationIds:['appetite','invented']})]);
 assert.equal(value.records[0].items.appetite.origin,'invalid'); assert.equal(value.selectionVerifiedDayCount,0);
});
test('timestamp validation never replaces malformed dates or converts local observation day to UTC',()=>{
 assert.equal(evidence([input('2026-10-01',[],'normal',{date:'bad'})]).invalidDayCount,1);
 const value=evidence([input('2026-10-01',[],'normal',{date:new Date('2026-09-30T15:00:00Z')})]);
 assert.equal(value.records[0].dateKey,'2026-10-01');
 const legacy={id:'2026-10-01',data:{condition:'normal',concernTags:[]}};
 assert.equal(evidence([legacy]).validRecordDayCount,1);
});

test('conflicting alias levels preserve invalid origin rather than synthesizing a trustworthy selected level',()=>{const value=evidence([input('2026-10-01',['elimination'],'slightlyConcerned',{observationLevels:{poop:'concerning',elimination:'changed'}})]);assert.equal(value.records[0].items.elimination.origin,'invalid');assert.equal(value.selectionVerifiedDayCount,0);});
