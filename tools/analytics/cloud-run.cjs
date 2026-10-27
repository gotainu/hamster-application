#!/usr/bin/env node
'use strict';
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {validateConfig,buildQuery,makeController}=require('./serve.cjs');
const {renderDashboard}=require('./render-dashboard.cjs');
const {createIapVerifier}=require('./cloud-iap.cjs');
const {createBigQueryExecutor}=require('./cloud-bigquery.cjs');
function makeLazyController({controller,config,now=()=>Date.now()}){
 function due(){const state=controller.state(),last=state.connection.last_attempt_at||state.connection.updated_at;return !last||now()-Date.parse(last)>=config.refresh_seconds*1000}
 async function ensureFresh(){if(due()||controller.state().connection.refreshing)await controller.refresh();return controller.state()}
 return {state:controller.state,ensureFresh};
}
function makeCloudServer({controller,verify,origin,template,synthetic}){
 const canonical=new URL(origin);if(canonical.protocol!=='https:'||canonical.origin!==origin||canonical.username||canonical.password)throw Error('Exact HTTPS PUBLIC_ORIGIN is required');
 const base=renderDashboard({general:{funnel:[],retention:[],conversion_cohorts:[],landmark_segments:[],a3:{registered_users:null,trial_starts:null,viewed:null,checkout:null,cancel_scheduled:null,ended:null},metadata:{source_classification:'unconnected_live_query',synthetic_only:false}},synthetic},template).replace('/*LIVE_CONNECTION*/false','true');
 return http.createServer(async(req,res)=>{
  const security={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Frame-Options':'DENY','Content-Security-Policy':"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'",'Referrer-Policy':'no-referrer'};
  const respond=(status,value,type='application/json; charset=utf-8')=>{res.writeHead(status,{...security,'Content-Type':type});res.end(typeof value==='string'?value:JSON.stringify(value))};
  try{await verify(req.headers['x-goog-iap-jwt-assertion'])}catch(error){return respond(error.message==='IAP_ACCOUNT_FORBIDDEN'?403:401,{error:'ADMIN_AUTH_REQUIRED'})}
  const landingNavigation=req.method==='GET'&&req.url==='/';
  if(req.headers.host!==canonical.host||req.headers.origin&&req.headers.origin!==origin||req.headers['sec-fetch-site']==='cross-site'&&!landingNavigation)return respond(403,{error:'SAME_ORIGIN_REQUIRED'});
  if(req.method==='GET'&&req.url==='/')return respond(200,base,'text/html; charset=utf-8');
  if(req.method==='GET'&&req.url==='/api/dashboard')return respond(200,await controller.ensureFresh());
  if(req.method==='POST'&&req.url==='/api/refresh'){
   if(req.headers.origin!==origin||req.headers['content-type']!=='application/json'||req.headers['x-hamcare-dashboard']!=='local')return respond(403,{error:'SAME_ORIGIN_REQUIRED'});
   req.resume();return respond(200,await controller.ensureFresh()); // Manual refresh shares the same cost ceiling.
  }
  return respond(404,{error:'NOT_FOUND'});
 });
}
function runtimeSettings(env){
 const port=Number(env.PORT||8080);if(!Number.isInteger(port)||port<1||port>65535)throw Error('Invalid PORT');
 if(!env.ANALYTICS_CONFIG_JSON||!env.ADMIN_EMAILS||!env.IAP_AUDIENCE||!env.PUBLIC_ORIGIN)throw Error('Explicit Cloud Run configuration is required');
 const config=validateConfig(JSON.parse(env.ANALYTICS_CONFIG_JSON));
 if(config.refresh_seconds!==900)throw Error('Approved refresh interval is 900 seconds');
 return {port,config,audience:env.IAP_AUDIENCE,adminEmails:env.ADMIN_EMAILS.split(',').map(value=>value.trim()).filter(Boolean),origin:env.PUBLIC_ORIGIN};
}
function main(env=process.env){
 const settings=runtimeSettings(env),{config}=settings;
 const query=buildQuery(fs.readFileSync(path.join(__dirname,'../../docs/analytics/trial_journey.sql'),'utf8'),fs.readFileSync(path.join(__dirname,'dashboard_queries.sql'),'utf8'));
 const controller=makeLazyController({config,controller:makeController({config,cacheDir:'/tmp/hamcare-analytics-cache',query,execute:createBigQueryExecutor({config})})});
 const server=makeCloudServer({controller,verify:createIapVerifier(settings),origin:settings.origin,template:fs.readFileSync(path.join(__dirname,'dashboard-template.html'),'utf8'),synthetic:JSON.parse(fs.readFileSync(path.join(__dirname,'output/synthetic-dashboard.json'),'utf8'))});
 server.listen(settings.port,'0.0.0.0',()=>console.log(JSON.stringify({service:'hamcare-analytics-admin',aggregate_only:true,authentication:'IAP_signed_JWT',request_driven:true,refresh_seconds:900})));
 process.on('SIGTERM',()=>server.close(()=>process.exit(0)));return server;
}
if(require.main===module)try{main()}catch{console.error('Cloud dashboard configuration failed.');process.exitCode=1}
module.exports={makeLazyController,makeCloudServer,runtimeSettings,main};
