#!/usr/bin/env node
'use strict';
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const {canonicalFacts,hash,stringify}=require('./journey_metrics.cjs');
const {fixture}=require('./fixtures/make_synthetic.cjs');
const ROOT=__dirname;
const DEFAULT_CONFIG=Object.freeze({schema_version:'journey_dashboard_v1',as_of:'2026-11-01T03:00:00.000Z',server_complete_through:'2026-10-31T15:00:00.000Z',ga4_complete_through:'2026-10-31T15:00:00.000Z',audience:'general',conversion_horizon_days:28,landmark_days:14,landmark_followup_day:21,timezone:'Asia/Tokyo',source_classification:'synthetic_only'});
function aggregate(input,config){
 const canonical=canonicalFacts(input,config);
 const result=spawnSync('python3',[path.join(ROOT,'execute_sql.py')],{input:JSON.stringify(canonical),encoding:'utf8',env:{...process.env,PYTHONDONTWRITEBYTECODE:'1'}});
 if(result.status!==0)throw Error(result.stderr||'Local SQL execution failed.');
 const sql=JSON.parse(result.stdout),content={...sql,a3:sql.a3[0],diagnostics:canonical.diagnostics};
 return {
  metadata:{schema_version:'journey_dashboard_v1',metric_policy_version:'journey_metrics_v1',source_classification:config.source_classification,synthetic_only:input.synthetic_only===true,as_of:config.as_of,watermark:{server:config.server_complete_through,ga4:config.ga4_complete_through},config:{conversion_horizon_days:config.conversion_horizon_days,landmark_days:config.landmark_days,landmark_followup_day:config.landmark_followup_day},timezone:config.timezone,audience:config.audience,input_hash:hash({...input,server:[...input.server].sort((a,b)=>stringify(a).localeCompare(stringify(b))),ga4:[...input.ga4].sort((a,b)=>stringify(a).localeCompare(stringify(b)))}),config_hash:hash(config),content_hash:hash(content),code_hash:hash(['journey_metrics.cjs','dashboard_queries.sql','execute_sql.py','run.cjs'].map(f=>fs.readFileSync(path.join(ROOT,f),'utf8'))),not_prediction_ready:true},
  ...content,methodology:{funnel:'Strict ordered milestones; the separate A3 panel shows independent reach.',a1:'First successful AI consultation is a proxy, not proof of perceived value.',retention:'JST calendar days since registration; only server-confirmed manual records, successful user AI answers, and exactly matched rendered reports count. Both source watermarks must close the target day.',conversion:`Paid activation within ${config.conversion_horizon_days} days from trial start; immature trials excluded. Sandbox activation excluded from general metrics.`,a3_landmark:`Viewed by trial day ${config.landmark_days}; compare follow-up day ${config.landmark_followup_day} only after the same observation horizon. Paid before landmark excluded from subsequent conversion risk set.`,causality:'Observational associations; no causal effect is inferred.',missing:'Unknown ingestion completeness leaves eligible denominators zero and rates null (N/A). No health/AI/payment content in output.'}
 };
}
function writeSamples(out){
 fs.mkdirSync(out,{recursive:true});const input=fixture();const dashboard=aggregate(input,DEFAULT_CONFIG);
 const emptyInput={schema_version:'journey_synthetic_input_v1',synthetic_only:true,server:[],ga4:[]};
 const empty=aggregate(emptyInput,{...DEFAULT_CONFIG,as_of:'2026-10-17T00:00:00.000Z',server_complete_through:null,ga4_complete_through:null,source_classification:'declared_zero_general_users_unconnected_preview'});
 for(const [name,value] of [['synthetic-input.json',input],['synthetic-config.json',DEFAULT_CONFIG],['synthetic-dashboard.json',dashboard],['general-dashboard.json',empty]])fs.writeFileSync(path.join(out,name),JSON.stringify(value,null,2)+'\n');
 const manifest={schema_version:'journey_dashboard_manifest_v1',synthetic_only:true,content_hash:dashboard.metadata.content_hash,input_hash:dashboard.metadata.input_hash,config_hash:dashboard.metadata.config_hash,code_hash:dashboard.metadata.code_hash,files:['synthetic-input.json','synthetic-config.json','synthetic-dashboard.json','general-dashboard.json'],generated_at:new Date().toISOString(),generation_time_excluded_from_content_hash:true};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');return dashboard;
}
function writeMetadataExport(inputPath,configPath,out){
 if(fs.existsSync(out))throw Error('Choose a new output directory; metadata runs are immutable.');
 const input=JSON.parse(fs.readFileSync(inputPath,'utf8')),config=JSON.parse(fs.readFileSync(configPath,'utf8'));
 if(input.synthetic_only!==true&&!['test_metadata_export','production_metadata_export'].includes(config.source_classification))throw Error('Explicit source classification is required for metadata exports.');
 const d=aggregate(input,config);fs.mkdirSync(out,{recursive:false});
 fs.writeFileSync(path.join(out,'dashboard.json'),JSON.stringify(d,null,2)+'\n');
 const safeConfig=Object.fromEntries(Object.keys(DEFAULT_CONFIG).map(k=>[k,config[k]]));
 fs.writeFileSync(path.join(out,'config.json'),JSON.stringify(safeConfig,null,2)+'\n');
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({...d.metadata,generated_at:new Date().toISOString(),generation_time_excluded_from_content_hash:true},null,2)+'\n');
 return d;
}
if(require.main===module){
 let out,d;
 if(process.argv.includes('--input')){
  const args=Object.fromEntries(Array.from({length:(process.argv.length-2)/2},(_,i)=>[process.argv[2+i*2],process.argv[3+i*2]]));
  if(Object.keys(args).some(k=>!['--input','--config','--output'].includes(k))||!args['--input']||!args['--config']||!args['--output'])throw Error('Use --input FILE --config FILE --output NEW_DIRECTORY.');
  out=path.resolve(args['--output']);d=writeMetadataExport(args['--input'],args['--config'],out);
 }else{out=process.argv[2]?path.resolve(process.argv[2]):path.join(ROOT,'output');d=writeSamples(out);}
 console.log(JSON.stringify({output_directory:out,content_hash:d.metadata.content_hash,funnel:d.funnel.map(r=>r.users),retention:d.retention,conversion:d.conversion_cohorts}));
}
module.exports={aggregate,DEFAULT_CONFIG,writeSamples,writeMetadataExport};
