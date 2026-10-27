'use strict';
// Cloud Run runtime credentials only. No ADC files, user tokens or private keys.
const crypto=require('node:crypto');
const {queryConfig}=require('./serve.cjs');
const METADATA='http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token';
function namedParameters(q){
 const types={as_of:'TIMESTAMP',server_complete_through:'TIMESTAMP',ga4_complete_through:'TIMESTAMP',cohort_start:'DATE',cohort_end:'DATE',conversion_horizon_days:'INT64',landmark_days:'INT64',landmark_followup_day:'INT64'};
 return [...Object.entries(types).map(([name,type])=>({name,parameterType:{type},parameterValue:{value:q[name]===null?null:String(q[name])}})),{name:'excluded_user_ids',parameterType:{type:'ARRAY',arrayType:{type:'STRING'}},parameterValue:{arrayValues:q.excluded_user_ids.map(value=>({value}))}}];
}
function createBigQueryExecutor({config,fetchImpl=fetch,now=()=>Date.now(),sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms)),randomId=()=>crypto.randomBytes(16).toString('hex')}={}){
 let credential=null;
 async function token(){
  if(credential&&credential.expires>now()+60000)return credential.value;
  let response;try{response=await fetchImpl(METADATA,{headers:{'Metadata-Flavor':'Google'},signal:AbortSignal.timeout(5000)})}catch{throw Error('BQ_RUNTIME_CREDENTIAL_UNAVAILABLE')}
  if(!response.ok)throw Error('BQ_RUNTIME_CREDENTIAL_UNAVAILABLE');
  let body;try{body=await response.json()}catch{throw Error('BQ_RUNTIME_CREDENTIAL_UNAVAILABLE')}
  if(typeof body.access_token!=='string'||!body.access_token||!Number.isFinite(Number(body.expires_in)))throw Error('BQ_RUNTIME_CREDENTIAL_UNAVAILABLE');
  credential={value:body.access_token,expires:now()+Number(body.expires_in)*1000};return credential.value;
 }
 async function api(relative,options={}){
  const bearer=await token();let response;
  try{response=await fetchImpl(`https://bigquery.googleapis.com/bigquery/v2/projects/${encodeURIComponent(config.project_id)}/${relative}`,{...options,headers:{Authorization:`Bearer ${bearer}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(30000)})}catch{throw Error('BQ_QUERY_FAILED')}
  if(!response.ok)throw Error('BQ_QUERY_FAILED');
  const raw=await response.text();if(Buffer.byteLength(raw)>2000000)throw Error('BQ_RESULT_TOO_LARGE');
  try{return JSON.parse(raw)}catch{throw Error('BQ_RESULT_INVALID')}
 }
 return async function execute(query,args){
  // The controller's query cutoff is carried through the existing CLI argument contract.
  const asOf=args.find(value=>value.startsWith('--parameter=as_of:TIMESTAMP:'))?.slice('--parameter=as_of:TIMESTAMP:'.length);
  const q=queryConfig(config,asOf),jobId=`hamcare_admin_${randomId()}`,started=now();
  const request={jobReference:{projectId:config.project_id,location:config.location,jobId},configuration:{labels:{application:'hamcare-analytics-admin'},query:{query,useLegacySql:false,useQueryCache:true,maximumBytesBilled:String(config.max_bytes_billed),parameterMode:'NAMED',queryParameters:namedParameters(q)}}};
  let job=await api('jobs',{method:'POST',body:JSON.stringify(request)});
  while(job.status?.state!=='DONE'){
   if(now()-started>=120000)throw Error('BQ_QUERY_TIMEOUT');
   await sleep(500);job=await api(`jobs/${jobId}?location=${encodeURIComponent(config.location)}`);
  }
  if(job.status.errorResult||job.status.errors?.length)throw Error('BQ_QUERY_FAILED');
  const result=await api(`queries/${jobId}?location=${encodeURIComponent(config.location)}&maxResults=1`);
  if(result.jobComplete!==true||result.pageToken||String(result.totalRows)!=='1'||result.schema?.fields?.length!==1||result.schema.fields[0].name!=='metrics_json'||result.rows?.length!==1||result.rows[0].f?.length!==1)throw Error('BQ_RESULT_INVALID');
  try{return JSON.parse(result.rows[0].f[0].v)}catch{throw Error('BQ_RESULT_INVALID')}
 };
}
module.exports={createBigQueryExecutor,namedParameters};
