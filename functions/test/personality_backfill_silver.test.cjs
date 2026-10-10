'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const ts = require('typescript');
const NOW = new Date('2026-10-08T02:00:00Z');
const DAY = '2026-10-08';
function fixture(existing) {
  const docs = new Map(); const writes = []; const reads = []; const builds = []; const publications = [];
  const currentPath = 'users/unit-backfill/daily_health_features/' + DAY;
  if (existing) docs.set(currentPath, existing);
  const snap = p => ({exists:docs.has(p),data:()=>docs.get(p)});
  const ref = p => ({path:p,collection:n=>ref(p+'/'+n),doc:n=>ref(p+'/'+n),get:async()=>snap(p)});
  let queue = Promise.resolve();
  const db = {collection:n=>ref(n),runTransaction:action=>{
    const result=queue.then(()=>action({get:async r=>snap(r.path),create:(r,d)=>{assert.ok(!docs.has(r.path));docs.set(r.path,d);writes.push(r.path);}}));
    queue=result.catch(()=>{});return result;
  }};
  const file=path.resolve(__dirname,'../src/health/personalityBackfill.ts');
  const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const mod={exports:{}};
  const fresh={schemaVersion:5,dateKey:DAY,generatedAt:NOW,body:{personalBaseline:{status:'ready',median:100}}};
  const req=name=>{
    if(name==='firebase-admin')return {firestore:{FieldValue:{serverTimestamp:()=> 'server-now'}}};
    if(name==='./dateKey')return {formatDateKey:()=>DAY,normalizeDateKey:d=>d};
    if(name==='./firestoreReaders')return {fetchHealthSourceData:async p=>{reads.push(p);return {freshBronze:true};}};
    if(name==='./dailyHealthFeatures')return {buildDailyHealthFeatures:p=>{builds.push(p);return {features:fresh};}};
    if(name==='./personalityReport')return {syncPersonalityReport:async p=>{publications.push(p);return {status:p.dryRun?'would_create':'created',reportId:'fixture',readyMetrics:['body']};}};
    throw Error('Unexpected import '+name);
  };
  vm.runInThisContext('(function(exports,require,module){'+code+'\n})',{filename:file})(mod.exports,req,mod);
  const run=(extra={})=>mod.exports.backfillPersonalityReport({db,uid:'unit-backfill',evaluationDateKey:DAY,now:NOW,...extra});
  return {docs,writes,reads,builds,publications,currentPath,fresh,run};
}
test('missing today Silver is rebuilt from current Bronze via the existing reader and feature builder',async()=>{
 const f=fixture(); const result=await f.run();
 assert.equal(result.silverStatus,'created');assert.equal(result.status,'created');
 assert.equal(f.reads.length,1);assert.equal(f.reads[0].dateKey,DAY);
 assert.equal(f.builds[0].dateKey,DAY);assert.deepEqual(f.builds[0].source,{freshBronze:true});assert.equal(f.builds[0].generatedAt,NOW);
 assert.equal(f.docs.get(f.currentPath).body.personalBaseline.median,100);
 assert.deepEqual(f.writes,[f.currentPath]);assert.equal(f.publications[0].previewFeatures,undefined);
});
test('existing current Silver is preserved and never replaced by stale or reconstructed data',async()=>{
 const original={dateKey:DAY,schemaVersion:5,sentinel:'current'};const f=fixture(original);
 assert.equal((await f.run()).silverStatus,'existing');assert.equal(f.reads.length,0);assert.equal(f.builds.length,0);assert.equal(f.writes.length,0);assert.equal(f.docs.get(f.currentPath),original);
});
test('dry-run computes fresh current features and previews a report without any writes',async()=>{
 const f=fixture();const result=await f.run({dryRun:true});
 assert.equal(result.silverStatus,'would_create');assert.equal(result.status,'would_create');assert.equal(f.writes.length,0);assert.equal(f.docs.size,0);
 assert.equal(f.publications[0].previewFeatures,f.fresh);assert.equal(f.publications[0].dryRun,true);
});
test('historical evaluations never rebuild or relabel old Silver as current',async()=>{
 const f=fixture();const result=await f.run({evaluationDateKey:'2026-09-23'});
 assert.equal(result.status,'historical_skipped');assert.equal(f.reads.length,0);assert.equal(f.builds.length,0);assert.equal(f.writes.length,0);
});
test('concurrent missing-Silver preparations create once and reread committed current Silver for publication',async()=>{
 const f=fixture();await Promise.all([f.run(),f.run()]);
 assert.equal(f.writes.length,1);assert.equal(f.docs.size,1);assert.ok(f.publications.every(p=>!p.previewFeatures));
});
