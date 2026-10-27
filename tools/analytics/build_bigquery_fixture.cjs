'use strict';
// Produces a synthetic-only BigQuery script. It contains no cloud table reads.
const fs=require('node:fs'),path=require('node:path');
const {fixture}=require('./fixtures/make_synthetic.cjs');
const {DEFAULT_CONFIG}=require('./run.cjs');
const src=fixture();const quote=v=>v==null?'NULL':typeof v==='boolean'?(v?'TRUE':'FALSE'):typeof v==='number'?String(v):"'"+v.replaceAll('\\','\\\\').replaceAll("'","\\'")+"'";
const cols={source_event_id:'STRING',user_id:'STRING',event_name:'STRING',event_at:'TIMESTAMP',ingested_at:'TIMESTAMP',environment:'STRING',account_classification:'STRING',billing_livemode:'BOOL',test_only:'BOOL',trial_id:'STRING',actor:'STRING',record_source:'STRING',record_type:'STRING',metric:'STRING',current_status:'STRING',pet_id:'STRING',report_id:'STRING',report_revision:'INT64'};
const typed=(v,t)=>v==null?`CAST(NULL AS ${t})`:t==='TIMESTAMP'?`TIMESTAMP(${quote(v)})`:quote(v);
const server=src.server.map(r=>'SELECT '+Object.entries(cols).map(([k,t])=>`${typed(r[k],t)} AS ${k}`).join(',')).join('\nUNION ALL\n');
const ga4=src.ga4.filter(r=>Date.parse(r.ingested_at)<=Date.parse(DEFAULT_CONFIG.as_of)).map(r=>{
 const params=Object.keys(r).filter(k=>!['user_id','event_name','event_at','ingested_at'].includes(k)).map(k=>`STRUCT(${quote(k==='report_revision'?'analysis_revision':k)} AS key,STRUCT(${typeof r[k]==='string'?quote(r[k]):'CAST(NULL AS STRING)'} AS string_value,${typeof r[k]==='number'?r[k]:'CAST(NULL AS INT64)'} AS int_value) AS value)`).join(',');
 return `SELECT ${quote(r.user_id)} AS user_id,${quote(r.event_name)} AS event_name,${Date.parse(r.event_at)*1000} AS event_timestamp,[${params}] AS event_params,${quote(r.event_at.slice(0,10).replaceAll('-',''))} AS _TABLE_SUFFIX`;
}).join('\nUNION ALL\n');
let query=fs.readFileSync(path.join(__dirname,'../../docs/analytics/trial_journey.sql'),'utf8');
const declarations=`DECLARE excluded_user_ids ARRAY<STRING> DEFAULT [];\nDECLARE as_of TIMESTAMP DEFAULT TIMESTAMP('${DEFAULT_CONFIG.as_of}');\nDECLARE server_complete_through TIMESTAMP DEFAULT TIMESTAMP('${DEFAULT_CONFIG.server_complete_through}');\nDECLARE ga4_complete_through TIMESTAMP DEFAULT TIMESTAMP('${DEFAULT_CONFIG.ga4_complete_through}');\nDECLARE cohort_start DATE DEFAULT DATE('2026-10-01');\nDECLARE cohort_end DATE DEFAULT DATE('2026-10-31');\nDECLARE conversion_horizon_days INT64 DEFAULT 28;\nDECLARE landmark_days INT64 DEFAULT 14;\nDECLARE landmark_followup_day INT64 DEFAULT 21;\n`;
query=query.replaceAll(/@(excluded_user_ids|as_of|server_complete_through|ga4_complete_through|cohort_start|cohort_end|conversion_horizon_days|landmark_days|landmark_followup_day)\b/g,'$1').replace('WITH server_dedup AS (',`WITH synthetic_server AS (${server}),synthetic_ga4 AS (${ga4}),server_dedup AS (`).replace('`hamster-breeding-app.hamcare_trial_analytics.server_events_raw`','synthetic_server').replace('`hamster-breeding-app.analytics_549839505.events_*`','synthetic_ga4');
const sections=fs.readFileSync(path.join(__dirname,'dashboard_queries.sql'),'utf8').split(/^-- query: (\w+)\n/m);const ctes=[],fields=[];
for(let i=1;i<sections.length;i+=2){const name=sections[i];ctes.push(`${name} AS (${sections[i+1].trim().replace(/;$/,'')})`);fields.push(`(SELECT ARRAY_AGG(t) FROM ${name} t) AS ${name}`);}
query=declarations+query+'\nWITH '+ctes.join(',\n')+'\nSELECT TO_JSON_STRING(STRUCT('+fields.join(',')+')) AS synthetic_metrics_json;\n';
if(query.includes('`hamster-breeding-app.'))throw Error('Synthetic SQL must not reference cloud tables.');
const out=process.argv[2]||path.join(__dirname,'../../audit/bigquery-synthetic-query.sql');fs.writeFileSync(out,query);console.log(JSON.stringify({file:out,synthetic_only:true,cloud_table_references:0}));
