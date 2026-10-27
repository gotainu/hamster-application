'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs'),os=require('node:os');
const root=path.resolve(__dirname,'..');
const {loadTypeScript}=require('../../prediction_dataset/tools/load-typescript.cjs');
const {materialize}=loadTypeScript(path.join(root,'src/materialize.ts'));
const source=()=>JSON.parse(fs.readFileSync(path.join(root,'fixtures/source.json'),'utf8'));
const config=()=>JSON.parse(fs.readFileSync(path.join(root,'fixtures/config.json'),'utf8'));
const {aliasAudit}=loadTypeScript(path.join(root,'src/table.ts'));
const {writeMaterialization}=require('../writer.cjs');

test('audit preserves feature vocabulary while aliasing actual source identifiers',()=>{
 const audited=aliasAudit({sourceId:'synthetic_private_source',featureIds:['past_condition','weight_last_g']});
 assert.notEqual(audited.sourceId,'synthetic_private_source');
 assert.deepEqual(audited.featureIds,['past_condition','weight_last_g']);
});
test('partial observation history cannot finalize first-response labels',()=>{
 const s=source();s.sourceCompleteness.observations={status:'partial',reasonCodes:['synthetic_observation_page_missing']};
 const r=materialize(s,config(),'synthetic_code');
 assert.equal(r.rows.some(x=>x.row_status==='candidate'),false);
 assert.ok(r.rows.every(x=>x.row_status==='hold'));
 assert.ok(r.rows.every(x=>x.label_initial===null&&x.label_corrected===null&&x.selected_observation_id===null));
 assert.ok(r.rows.every(x=>x.exclusion_reason.includes('observation_history_partial')));
});
test('history not reconstructable is ineligible; omitted completeness is held',()=>{
 for(const status of ['not_reconstructable',null]){
  const s=source();if(status)s.sourceCompleteness.observations={status,reasonCodes:['synthetic_old_history']};else delete s.sourceCompleteness.observations;
  const r=materialize(s,config(),'synthetic_code');
  assert.ok(r.rows.every(x=>x.row_status===(status?'ineligible':'hold')));
  assert.ok(r.rows.every(x=>x.label_initial===null));
 }
});
test('complete observation scan with zero records is genuine label-missing, never normal',()=>{
 const s=source();s.sources.observations=[];
 const r=materialize(s,config(),'synthetic_code');
 assert.equal(r.manifest.state_counts.candidate,0);
 assert.equal(r.manifest.state_counts.label_missing,6);
 assert.equal(r.manifest.state_counts.hold,1);
});
test('duplicate prediction subjects/times and repeated run IDs are rejected without overwrite',()=>{
 const c=config();c.points.push({...c.points[0],id:'synthetic_duplicate'});
 assert.throws(()=>materialize(source(),c,'synthetic_code'),/duplicate_prediction_point/);
 const r=materialize(source(),config(),'synthetic_code'),out=fs.mkdtempSync(path.join(os.tmpdir(),'hamcare-materializer-immutable-'));
 const first=writeMaterialization(r,{outputRoot:out,runId:'synthetic_run',generatedAt:'2031-01-01T00:00:00Z'});
 const bytes=fs.readFileSync(path.join(first.directory,'rows.jsonl'));
 assert.throws(()=>writeMaterialization(r,{outputRoot:out,runId:'synthetic_run',generatedAt:'2031-01-02T00:00:00Z'}),{code:'EEXIST'});
 assert.deepEqual(fs.readFileSync(path.join(first.directory,'rows.jsonl')),bytes);
 assert.throws(()=>writeMaterialization(r,{outputRoot:out,runId:'../escape',generatedAt:'2031-01-01T00:00:00Z'}),/invalid_run_id/);
});
test('non-synthetic source classification is fail-closed without cloud access',()=>{
 for(const classification of ['test','production']){
  const s=source();s.classification=classification;
  assert.throws(()=>materialize(s,config(),'synthetic_code'),/non_synthetic_materialization_not_enabled/);
 }
});
test('missing identity at prediction time remains ineligible rather than inferred from owner',()=>{
 const s=source();s.subjects=[];const r=materialize(s,config(),'synthetic_code');
 assert.equal(r.rows.filter(x=>x.row_status==='candidate').length,0);
 assert.ok(r.rows.filter(x=>x.row_status!=='hold').every(x=>x.row_status==='ineligible'&&x.subject_id===null));
 assert.equal(new Set(r.rows.map(x=>x.row_id)).size,r.rows.length);
});
test('source watermark limits label availability and run metadata stays outside content hash',()=>{
 const s=source();s.dataAvailableThrough='2030-04-02T00:00:00Z';
 const r=materialize(s,config(),'synthetic_code');assert.ok(r.rows.every(x=>x.row_status==='hold'));
 assert.ok(r.manifest.windows.every(x=>x.data_available_through==='2030-04-02T00:00:00.000000000Z'));
 const base=materialize(source(),config(),'synthetic_code');
 const out=fs.mkdtempSync(path.join(os.tmpdir(),'hamcare-materializer-time-'));
 const a=writeMaterialization(base,{outputRoot:out,runId:'synthetic_first',generatedAt:'2031-01-01T00:00:00Z'});
 const b=writeMaterialization(base,{outputRoot:out,runId:'synthetic_second',generatedAt:'2031-01-02T00:00:00Z'});
 assert.equal(a.manifest.content_hash,b.manifest.content_hash);
 assert.notDeepEqual(fs.readFileSync(path.join(a.directory,'audit.json')),fs.readFileSync(path.join(b.directory,'audit.json')));
});
