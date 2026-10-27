#!/usr/bin/env node
'use strict';
// Loopback-only connection to the existing aggregate SQL. No cloud writes.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {spawn}=require('node:child_process');
const {renderDashboard}=require('./render-dashboard.cjs');
const ROOT=__dirname, HASH_FILES=['serve.cjs','dashboard_queries.sql','../../docs/analytics/trial_journey.sql'];
const PRIVATE_KEYS=/"(?:user_id|uid|email|question|answer|memo|customer_id|subscription_id|token|secret|authorization)"\s*:/i;
const hash=v=>crypto.createHash('sha256').update(typeof v==='string'?v:JSON.stringify(v)).digest('hex');
function iso(value,name){if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value)||!Number.isFinite(Date.parse(value)))throw Error(`Invalid ${name}`);return new Date(value).toISOString()}
function validateConfig(input){
 const allowed=['project_id','location','cohort_days','server_complete_through','ga4_complete_through','conversion_horizon_days','landmark_days','landmark_followup_day','max_bytes_billed','refresh_seconds','stale_after_seconds','source_classification','excluded_user_ids'];
 if(Object.keys(input).some(k=>!allowed.includes(k)))throw Error('Unsupported connection configuration field');
 if(!Object.hasOwn(input,'excluded_user_ids'))throw Error('Explicit test account exclusion list is required');
 const c={project_id:'hamster-breeding-app',location:'asia-northeast1',cohort_days:179,server_complete_through:null,ga4_complete_through:null,conversion_horizon_days:28,landmark_days:14,landmark_followup_day:21,max_bytes_billed:100000000,refresh_seconds:900,stale_after_seconds:1800,source_classification:'production_metadata_export',excluded_user_ids:[],...input};
 if(c.project_id!=='hamster-breeding-app'||c.location!=='asia-northeast1'||c.source_classification!=='production_metadata_export')throw Error('Use the existing approved production metadata source');
 for(const k of ['cohort_days','conversion_horizon_days','landmark_days','landmark_followup_day','max_bytes_billed','refresh_seconds','stale_after_seconds'])if(!Number.isSafeInteger(c[k]))throw Error(`Invalid ${k}`);
 if(c.cohort_days<1||c.cohort_days>179||c.max_bytes_billed<10485760||c.max_bytes_billed>1000000000||c.refresh_seconds<60||c.stale_after_seconds<c.refresh_seconds)throw Error('Unsafe connection limits');
 if(c.conversion_horizon_days<=c.landmark_days||c.landmark_days<=0||c.landmark_followup_day<c.landmark_days)throw Error('Invalid evaluation horizons');
 for(const k of ['server_complete_through','ga4_complete_through'])if(c[k]!==null)c[k]=iso(c[k],k);
 if(!Array.isArray(c.excluded_user_ids)||c.excluded_user_ids.length>1000||c.excluded_user_ids.some(v=>typeof v!=='string'||v.length<1||v.length>128||v.startsWith('REPLACE_')||/[\x00-\x1f]/.test(v)))throw Error('Invalid test account exclusion list');
 c.excluded_user_ids=[...new Set(c.excluded_user_ids)].sort();return c;
}
function queryConfig(config,at){
 const as_of=iso(at,'as_of'),end=new Date(Date.parse(as_of)+9*3600000).toISOString().slice(0,10),start=new Date(Date.parse(end+'T00:00:00Z')-config.cohort_days*86400000).toISOString().slice(0,10);
 for(const k of ['server_complete_through','ga4_complete_through'])if(config[k]&&Date.parse(config[k])>Date.parse(as_of))throw Error('Completeness exceeds query cutoff');
 return {...config,as_of,cohort_start:start,cohort_end:end};
}
function buildQuery(sql,panels){
 const sections=panels.split(/^-- query: (\w+)\n/m),ctes=[],fields=[];
 for(let i=1;i<sections.length;i+=2){const name=sections[i];ctes.push(`${name} AS (${sections[i+1].trim().replace(/;$/,'')})`);fields.push(`(SELECT IFNULL(ARRAY_AGG(t),[]) FROM ${name} t) AS ${name}`)}
 if(fields.length!==5)throw Error('Expected the existing five aggregate panels');
 return sql+'\nWITH '+ctes.join(',\n')+'\nSELECT TO_JSON_STRING(STRUCT('+fields.join(',')+')) AS metrics_json;\n';
}
function bqArgs(q){
 const a=['query','--quiet','--use_legacy_sql=false','--format=json','--max_rows=1',`--project_id=${q.project_id}`,`--location=${q.location}`,`--maximum_bytes_billed=${q.max_bytes_billed}`];
 const params={as_of:'TIMESTAMP',server_complete_through:'TIMESTAMP',ga4_complete_through:'TIMESTAMP',cohort_start:'DATE',cohort_end:'DATE',conversion_horizon_days:'INT64',landmark_days:'INT64',landmark_followup_day:'INT64'};
 for(const [k,t] of Object.entries(params))a.push(`--parameter=${k}:${t}:${q[k]===null?'NULL':q[k]}`);
 a.push(`--parameter=excluded_user_ids:ARRAY<STRING>:${JSON.stringify(q.excluded_user_ids)}`);return a;
}
function parseBqResult(output){
 const parsed=JSON.parse(output),matches=[];
 function visit(value){
  if(Array.isArray(value)){for(const item of value)visit(item);return}
  if(typeof value==='string'&&/^(?:Assertion successful[.!]?|Created(?: temporary| temp)? table(?:\s.*)?[.!]?|Created hamster-breeding-app\._script[a-f0-9]+\.journey_users)$/i.test(value.trim()))return;
  if(value&&typeof value==='object'&&Object.keys(value).length===1&&typeof value.metrics_json==='string'){matches.push(value.metrics_json);return}
  throw Error('BQ_RESULT_INVALID');
 }
 visit(parsed);if(matches.length!==1)throw Error('BQ_RESULT_INVALID');return JSON.parse(matches[0]);
}
function executeBq(query,args,{spawnImpl=spawn,timeoutMs=120000}={}){
 return new Promise((resolve,reject)=>{
  const p=spawnImpl('bq',args,{stdio:['pipe','pipe','pipe'],env:process.env});let output='',size=0,finished=false;
  const finish=(error,value)=>{if(finished)return;finished=true;clearTimeout(timer);error?reject(error):resolve(value)};
  const timer=setTimeout(()=>{p.kill();finish(Error('BQ_QUERY_TIMEOUT'))},timeoutMs);
  p.on('error',()=>finish(Error('BQ_COMMAND_UNAVAILABLE')));
  p.stdout.on('data',chunk=>{size+=chunk.length;if(size>2000000){p.kill();finish(Error('BQ_RESULT_TOO_LARGE'))}else output+=chunk});
  p.stderr.on('data',()=>{}); // Never echo credential or raw-query failures into the dashboard.
  p.on('close',code=>{if(code!==0)return finish(Error('BQ_QUERY_FAILED'));try{finish(null,parseBqResult(output))}catch{finish(Error('BQ_RESULT_INVALID'))}});
  p.stdin.end(query);
 });
}
function assertAggregate(d){
 if(!d||!Array.isArray(d.funnel)||!Array.isArray(d.retention)||!Array.isArray(d.conversion_cohorts)||!Array.isArray(d.landmark_segments)||!d.a3||typeof d.a3!=='object')throw Error('BQ_AGGREGATE_INVALID');
 if(PRIVATE_KEYS.test(JSON.stringify(d)))throw Error('BQ_AGGREGATE_PRIVATE_FIELD');
 return d;
}
function packageDashboard(raw,q,updatedAt){
 const d={...raw,a3:Array.isArray(raw.a3)?raw.a3[0]:raw.a3};assertAggregate(d);
 const content_hash=hash(d),code_hash=hash(HASH_FILES.map(f=>fs.readFileSync(path.join(ROOT,f),'utf8')));
 return {...d,metadata:{schema_version:'journey_dashboard_v1',metric_policy_version:'journey_metrics_v1',source_classification:'production_metadata_export',synthetic_only:false,audience:'general',as_of:q.as_of,updated_at:updatedAt,watermark:{server:q.server_complete_through,ga4:q.ga4_complete_through},config:{conversion_horizon_days:q.conversion_horizon_days,landmark_days:q.landmark_days,landmark_followup_day:q.landmark_followup_day},timezone:'Asia/Tokyo',cohort_start:q.cohort_start,cohort_end:q.cohort_end,connection_config_hash:hash(Object.fromEntries(Object.entries(q).filter(([k])=>!['as_of','cohort_start','cohort_end'].includes(k)))),content_hash,code_hash,excluded_account_count:q.excluded_user_ids.length,readiness:'BigQuery集計接続済み / 収集完了はwatermarkを別途確認'},diagnostics:{source:'existing_bigquery_aggregate_sql',source_completeness_confirmed:q.server_complete_through!==null&&q.ga4_complete_through!==null,unknown_classification_excluded:true,excluded_test_accounts:q.excluded_user_ids.length},methodology:{missing:'Unknown source completeness preserves N/A denominators; query success is not ingestion completeness.',retention:'Existing server-confirmed meaningful activity policy; background events excluded.',causality:'Observational associations only; no causal effect inferred.'}};
}
function makeController({config,cacheDir,query,now=()=>new Date().toISOString(),execute=executeBq}){
 let snapshot=null,failure=null,inFlight=null,lastAttemptAt=null;
 fs.mkdirSync(cacheDir,{recursive:true,mode:0o700});fs.chmodSync(cacheDir,0o700);
 const cacheFile=path.join(cacheDir,'last-success.json');
 if(fs.existsSync(cacheFile))try{const loaded=JSON.parse(fs.readFileSync(cacheFile,'utf8'));assertAggregate(loaded);if(loaded.metadata?.source_classification==='production_metadata_export'&&loaded.metadata.connection_config_hash===hash(config)&&Number.isFinite(Date.parse(loaded.metadata.updated_at))&&Number.isFinite(Date.parse(loaded.metadata.as_of)))snapshot=loaded}catch{failure={code:'CACHE_INVALID',at:now()}}
 function state(){const current=now(),age=snapshot?Math.max(0,(Date.parse(current)-Date.parse(snapshot.metadata.updated_at))/1000):null;return {connection:{state:failure?'error':snapshot?'connected':'unconnected',updated_at:snapshot?.metadata.updated_at||null,query_as_of:snapshot?.metadata.as_of||null,last_attempt_at:lastAttemptAt,checked_at:current,stale:age===null||age>config.stale_after_seconds,age_seconds:age,stale_after_seconds:config.stale_after_seconds,refresh_seconds:config.refresh_seconds,failure,refreshing:!!inFlight,source_classification:'production_metadata_export',cohort_start:snapshot?.metadata.cohort_start||null,cohort_end:snapshot?.metadata.cohort_end||null},dashboard:snapshot}}
 function refresh(){
  if(inFlight)return inFlight;
  lastAttemptAt=now();
  inFlight=(async()=>{try{const q=queryConfig(config,lastAttemptAt),raw=await execute(query,bqArgs(q));const next=packageDashboard(raw,q,now());const temp=cacheFile+'.tmp';fs.writeFileSync(temp,JSON.stringify(next)+'\n',{mode:0o600});fs.chmodSync(temp,0o600);fs.renameSync(temp,cacheFile);snapshot=next;failure=null}catch(error){const code=/^(?:BQ_[A-Z_]+)$/.test(error.message)?error.message:'AGGREGATE_REFRESH_FAILED';failure={code,at:now()}}finally{inFlight=null}return state()})();
  return inFlight;
 }
 return {state,refresh};
}
function makeServer({controller,config,port=8877,template,synthetic}){
 const base=renderDashboard({general:{funnel:[],retention:[],conversion_cohorts:[],landmark_segments:[],a3:{registered_users:null,trial_starts:null,viewed:null,checkout:null,cancel_scheduled:null,ended:null},metadata:{source_classification:'unconnected_live_query',synthetic_only:false}},synthetic},template).replace('/*LIVE_CONNECTION*/false','true');
 return http.createServer(async(req,res)=>{
  const address=`127.0.0.1:${port}`,origin=`http://${address}`;
  const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Frame-Options':'DENY','Content-Security-Policy':"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'"};
  const respond=(code,body,type='application/json; charset=utf-8')=>{res.writeHead(code,{...headers,'Content-Type':type});res.end(typeof body==='string'?body:JSON.stringify(body))};
  if(req.headers.host!==address||req.headers.origin&&req.headers.origin!==origin||req.headers['sec-fetch-site']==='cross-site')return respond(403,{error:'LOCAL_SAME_ORIGIN_REQUIRED'});
  if(req.method==='GET'&&req.url==='/')return respond(200,base,'text/html; charset=utf-8');
  if(req.method==='GET'&&req.url==='/api/dashboard')return respond(200,controller.state());
  if(req.method==='POST'&&req.url==='/api/refresh'){
   if(req.headers.origin!==origin||req.headers['content-type']!=='application/json'||req.headers['x-hamcare-dashboard']!=='local')return respond(403,{error:'LOCAL_SAME_ORIGIN_REQUIRED'});
   req.resume();await controller.refresh();return respond(200,controller.state());
  }
  return respond(404,{error:'NOT_FOUND'});
 });
}
async function main(){
 const argv=process.argv.slice(2),args={};if(argv.length%2)throw Error('Use --config FILE --cache-dir DIRECTORY [--port PORT] [--once FILE]');
 for(let i=0;i<argv.length;i+=2){if(!['--config','--cache-dir','--port','--once'].includes(argv[i])||args[argv[i]])throw Error('Invalid argument');args[argv[i]]=argv[i+1]}
 if(!args['--config']||!args['--cache-dir'])throw Error('Explicit config and private cache directory are required');
 const config=validateConfig(JSON.parse(fs.readFileSync(args['--config'],'utf8'))),query=buildQuery(fs.readFileSync(path.join(ROOT,'../../docs/analytics/trial_journey.sql'),'utf8'),fs.readFileSync(path.join(ROOT,'dashboard_queries.sql'),'utf8'));
 const controller=makeController({config,cacheDir:path.resolve(args['--cache-dir']),query});
 if(args['--once']){const result=await controller.refresh();fs.writeFileSync(args['--once'],JSON.stringify(result,null,2)+'\n',{flag:'wx',mode:0o600});console.log(JSON.stringify({connection_state:result.connection.state,stale:result.connection.stale,general_users:result.dashboard?.a3.registered_users??null,query_as_of:result.connection.query_as_of,updated_at:result.connection.updated_at,failure_code:result.connection.failure?.code||null}));process.exitCode=result.connection.state==='connected'?0:1;return}
 const port=Number(args['--port']||8877);if(!Number.isInteger(port)||port<1024||port>65535)throw Error('Invalid local port');
 const server=makeServer({controller,config,port,template:fs.readFileSync(path.join(ROOT,'dashboard-template.html'),'utf8'),synthetic:JSON.parse(fs.readFileSync(path.join(ROOT,'output/synthetic-dashboard.json'),'utf8'))});
 server.listen(port,'127.0.0.1',()=>console.log(JSON.stringify({url:`http://127.0.0.1:${port}`,binding:'loopback_only',aggregate_only:true,refresh_seconds:config.refresh_seconds})));
 const timer=setInterval(()=>controller.refresh(),config.refresh_seconds*1000);timer.unref();void controller.refresh();
 for(const s of ['SIGTERM','SIGINT'])process.on(s,()=>{clearInterval(timer);server.close(()=>process.exit(0))});
}
if(require.main===module)main().catch(()=>{console.error('Dashboard connection failed. Check the private configuration, local BigQuery authentication and query permissions.');process.exitCode=1});
module.exports={validateConfig,queryConfig,buildQuery,bqArgs,parseBqResult,executeBq,packageDashboard,makeController,makeServer,assertAggregate};
