'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http');
const {validateConfig,queryConfig,bqArgs,buildQuery,makeController}=require('./serve.cjs');
const {makeLazyController,makeCloudServer,runtimeSettings}=require('./cloud-run.cjs');
const {createIapVerifier}=require('./cloud-iap.cjs');
const {createBigQueryExecutor,namedParameters}=require('./cloud-bigquery.cjs');
const config=()=>validateConfig({excluded_user_ids:['synthetic-excluded-account']});
const audience='/projects/123456789/locations/asia-northeast1/services/hamcare-analytics-admin';
const origin='https://synthetic-admin.example.run.app';
const now=Date.parse('2026-10-18T09:00:00Z');
const aggregate=()=>({funnel:[],retention:[],conversion_cohorts:[],landmark_segments:[],a3:[{registered_users:0,trial_starts:0,viewed:0,ready:0,generated:0,checkout:0,cancel_scheduled:0,ended:0,ready_rate:null,generated_rate:null,viewed_rate:null}]});
const response=body=>({ok:true,status:200,json:async()=>body,text:async()=>JSON.stringify(body),headers:{get:()=> 'public, max-age=300'}});
function temp(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'hamcare-cloud-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));return dir}
function signed(claims={},header={},pair=crypto.generateKeyPairSync('ec',{namedCurve:'P-256'})){const {privateKey,publicKey}=pair;const jwk={...publicKey.export({format:'jwk'}),kid:'synthetic-key',alg:'ES256',use:'sig'};const head=Buffer.from(JSON.stringify({alg:'ES256',kid:jwk.kid,...header})).toString('base64url'),body=Buffer.from(JSON.stringify({iss:'https://cloud.google.com/iap',aud:audience,iat:now/1000,exp:now/1000+600,sub:'synthetic-account',email:'admin@example.invalid',...claims})).toString('base64url');return {privateKey,publicKey,jwk,token:`${head}.${body}.${crypto.sign('sha256',Buffer.from(`${head}.${body}`),{key:privateKey,dsaEncoding:'ieee-p1363'}).toString('base64url')}`}}
test('runtime requires exact explicit cloud config, admin allowlist, approved TTL and valid PORT',()=>{
 const env={PORT:'9090',ANALYTICS_CONFIG_JSON:JSON.stringify(config()),ADMIN_EMAILS:'admin@example.invalid',IAP_AUDIENCE:audience,PUBLIC_ORIGIN:origin};
 assert.equal(runtimeSettings(env).port,9090);assert.equal(runtimeSettings({...env,PORT:undefined}).port,8080);
 assert.throws(()=>runtimeSettings({...env,PORT:'0'}),/PORT/);assert.throws(()=>runtimeSettings({...env,ANALYTICS_CONFIG_JSON:JSON.stringify({...config(),refresh_seconds:60})}),/900/);assert.throws(()=>runtimeSettings({...env,ADMIN_EMAILS:''}),/Explicit/);
 assert.throws(()=>createIapVerifier({audience:'https://wrong.example',adminEmails:['admin@example.invalid']}),/audience/);
});
test('IAP rejects missing and malformed assertions before any public-key call; never trusts email headers',async()=>{
 let calls=0;const verify=createIapVerifier({audience,adminEmails:['admin@example.invalid'],now:()=>now,fetchImpl:async()=>{calls++;throw Error('no external network')}});
 for(const value of [undefined,'','abc','a.b.c','not.a.token.extra'])await assert.rejects(verify(value),/IAP_/);
 assert.equal(calls,0);
});
test('IAP verifies ES256 signature/issuer/audience/lifetime and signed email allowlist',async()=>{
 const good=signed();let calls=0;const verify=createIapVerifier({audience,adminEmails:['admin@example.invalid'],now:()=>now,fetchImpl:async url=>{calls++;assert.equal(url,'https://www.gstatic.com/iap/verify/public_key-jwk');return response({keys:[good.jwk]})}});
 assert.deepEqual(await verify(good.token),{subject:'synthetic-account'});await verify(good.token);assert.equal(calls,1);
 const tampered=good.token.split('.');tampered[1]=Buffer.from(JSON.stringify({email:'attacker@example.invalid'})).toString('base64url');await assert.rejects(verify(tampered.join('.')),/IAP_TOKEN_INVALID/);
 for(const claims of [{aud:audience+'wrong'},{iss:'https://attacker.invalid'},{iat:now/1000+31},{exp:now/1000-31,iat:now/1000-100},{exp:now/1000+601},{nbf:now/1000+31},{nbf:'invalid'}]){const item=signed(claims),v=createIapVerifier({audience,adminEmails:['admin@example.invalid'],now:()=>now,fetchImpl:async()=>response({keys:[item.jwk]})});await assert.rejects(v(item.token),/IAP_TOKEN_INVALID/)}
 const forbidden=signed({email:'other@example.invalid'}),deny=createIapVerifier({audience,adminEmails:['admin@example.invalid'],now:()=>now,fetchImpl:async()=>response({keys:[forbidden.jwk]})});await assert.rejects(deny(forbidden.token),/IAP_ACCOUNT_FORBIDDEN/);
});
test('IAP key rotation refreshes once and never fetches attacker-controlled key URLs',async()=>{
 const item=signed(),other=signed({}, {kid:'second-key'});other.jwk.kid='second-key';let clock=now,calls=0;
 const v=createIapVerifier({audience,adminEmails:['admin@example.invalid'],now:()=>clock,fetchImpl:async()=>response({keys:++calls===1?[item.jwk]:[item.jwk,other.jwk]})});
 await v(item.token);await v(other.token);assert.equal(calls,2);
 const bad=signed({}, {jku:'https://attacker.invalid/key'});await assert.rejects(v(bad.token),/IAP_TOKEN_INVALID/);assert.equal(calls,2);
});
test('request-driven controller has no startup job, bounds repeated/manual requests and coalesces concurrent queries',async t=>{
 let clock=now,calls=0,release;const gate=new Promise(resolve=>release=resolve),c=config();
 const base=makeController({config:c,cacheDir:temp(t),query:'existing SQL',now:()=>new Date(clock).toISOString(),execute:async()=>{calls++;await gate;return aggregate()}}),lazy=makeLazyController({controller:base,config:c,now:()=>clock});
 assert.equal(calls,0);const pending=Array.from({length:20},()=>lazy.ensureFresh());assert.equal(calls,1);release();await Promise.all(pending);assert.equal(calls,1);assert.equal(lazy.state().dashboard.a3.registered_users,0);assert.equal(lazy.state().dashboard.metadata.watermark.ga4,null);
 clock+=899999;await lazy.ensureFresh();assert.equal(calls,1);clock++;await lazy.ensureFresh();assert.equal(calls,2);
 clock+=3600000;assert.equal(lazy.state().connection.stale,true);assert.equal(calls,2); // no unattended query
});
test('failed refresh preserves stale data and retry TTL; failure text cannot leak credential details',async t=>{
 let clock=now,fail=false,calls=0;const c=config(),base=makeController({config:c,cacheDir:temp(t),query:'existing SQL',now:()=>new Date(clock).toISOString(),execute:async()=>{calls++;if(fail)throw Error('Authorization Bearer synthetic-secret');return aggregate()}}),lazy=makeLazyController({controller:base,config:c,now:()=>clock});
 const first=await lazy.ensureFresh();fail=true;clock+=1801000;const failed=await lazy.ensureFresh();assert.equal(failed.connection.state,'error');assert.equal(failed.connection.stale,true);assert.equal(failed.connection.updated_at,first.connection.updated_at);assert.equal(failed.dashboard.a3.registered_users,0);assert.ok(!JSON.stringify(failed).includes('synthetic-secret'));
 await lazy.ensureFresh();assert.equal(calls,2);
});
test('BigQuery REST uses runtime metadata credentials, same SQL/parameters, bounded aggregate result',async()=>{
 const c=config(),q=queryConfig(c,new Date(now).toISOString()),calls=[];
 const execute=createBigQueryExecutor({config:c,now:()=>now,randomId:()=> 'synthetic-job',fetchImpl:async(url,options)=>{calls.push({url,options});if(url.startsWith('http://metadata.'))return response({access_token:'synthetic-runtime-token',expires_in:3600});if(url.endsWith('/jobs')){const body=JSON.parse(options.body);assert.equal(body.configuration.query.query,'exact existing SQL');assert.equal(body.configuration.query.maximumBytesBilled,'100000000');assert.equal(body.configuration.query.useLegacySql,false);assert.deepEqual(body.configuration.query.queryParameters,namedParameters(q));return response({status:{state:'DONE'}})}return response({jobComplete:true,totalRows:'1',schema:{fields:[{name:'metrics_json',type:'STRING'}]},rows:[{f:[{v:JSON.stringify(aggregate())}]}]})}});
 assert.deepEqual(await execute('exact existing SQL',bqArgs(q)),aggregate());assert.equal(calls.length,3);assert.deepEqual(calls[0].options.headers,{'Metadata-Flavor':'Google'});assert.equal(calls[1].options.headers.Authorization,'Bearer synthetic-runtime-token');assert.equal(namedParameters(q).find(item=>item.name==='ga4_complete_through').parameterValue.value,null);assert.deepEqual(namedParameters(q).find(item=>item.name==='excluded_user_ids').parameterValue.arrayValues,[{value:'synthetic-excluded-account'}]);
 assert.ok(calls.slice(1).every(call=>call.url.startsWith('https://bigquery.googleapis.com/bigquery/v2/projects/hamster-breeding-app/')));
});
test('BigQuery query failure and excess/malformed result are redacted without private payloads',async()=>{
 for(const result of [response({jobComplete:true,totalRows:'2',schema:{fields:[{name:'metrics_json'}]},rows:[]}),{ok:false,status:403,text:async()=> 'synthetic-credential'}]){
  let n=0;const execute=createBigQueryExecutor({config:config(),now:()=>now,fetchImpl:async()=>++n===1?response({access_token:'synthetic-secret',expires_in:3600}):n===2?response({status:{state:'DONE'}}):result});
  await assert.rejects(execute('q',bqArgs(queryConfig(config(),new Date(now).toISOString()))),error=>/^BQ_/.test(error.message)&&!error.message.includes('synthetic'));
 }
});
function request(port,{url='/',method='GET',headers={}}={}){return new Promise((resolve,reject)=>{const req=http.request({host:'127.0.0.1',port,path:url,method,headers:{Host:new URL(origin).host,...headers}},res=>{let body='';res.on('data',chunk=>body+=chunk);res.on('end',()=>resolve({status:res.statusCode,body,headers:res.headers}))});req.on('error',reject);req.end(method==='POST'?'{}':undefined)})}
test('all HTML/API/error routes reject missing IAP; authorized pages reuse exact UI and deny cross-origin writes',async t=>{
 const good=signed(),verify=createIapVerifier({audience,adminEmails:['admin@example.invalid'],now:()=>now,fetchImpl:async()=>response({keys:[good.jwk]})}),c=config();let calls=0;
 const base=makeController({config:c,cacheDir:temp(t),query:'existingSQL',now:()=>new Date(now).toISOString(),execute:async()=>{calls++;return aggregate()}}),controller=makeLazyController({controller:base,config:c,now:()=>now});
 const server=makeCloudServer({controller,verify,origin,template:fs.readFileSync(path.join(__dirname,'dashboard-template.html'),'utf8'),synthetic:{...aggregate(),a3:aggregate().a3[0]}});await new Promise(resolve=>server.listen(0,'0.0.0.0',resolve));t.after(()=>new Promise(resolve=>server.close(resolve)));const port=server.address().port;
 assert.equal(server.address().address,'0.0.0.0');assert.equal(calls,0);
 for(const url of ['/','/api/dashboard','/api/refresh','/unknown']){const result=await request(port,{url,headers:{'x-goog-authenticated-user-email':'accounts.google.com:admin@example.invalid'}});assert.equal(result.status,401);assert.ok(!result.body.includes('価値体験'));}
 for(const claims of [{aud:audience+'-wrong'},{exp:now/1000-31,iat:now/1000-100},{nbf:now/1000+31}])assert.equal((await request(port,{url:'/api/dashboard',headers:{'x-goog-iap-jwt-assertion':signed(claims,{},good).token}})).status,401);
 const badsig=good.token.slice(0,-5)+'abcde';assert.equal((await request(port,{url:'/api/dashboard',headers:{'x-goog-iap-jwt-assertion':badsig}})).status,401);
 assert.equal((await request(port,{url:'/api/dashboard',headers:{'x-goog-iap-jwt-assertion':signed({email:'not-allowed@example.invalid'},{},good).token}})).status,403);
 assert.equal(calls,0);const headers={'x-goog-iap-jwt-assertion':good.token},html=await request(port,{headers});assert.equal(html.status,200);assert.ok(html.body.includes('価値体験から、利用継続へ'));assert.ok(html.body.includes('const liveConnection=true'));assert.equal(calls,0);
 assert.equal((await request(port,{headers:{...headers,'Sec-Fetch-Site':'cross-site','Sec-Fetch-Mode':'navigate'}})).status,200);
 assert.equal((await request(port,{headers:{...headers,Origin:'https://attacker.invalid','Sec-Fetch-Site':'cross-site'}})).status,403);
 assert.equal((await request(port,{url:'/api/dashboard',headers:{...headers,'Sec-Fetch-Site':'cross-site'}})).status,403);
 assert.equal((await request(port,{url:'/api/refresh',method:'POST',headers:{...headers,Origin:origin,'Content-Type':'application/json','X-HamCare-Dashboard':'local','Sec-Fetch-Site':'cross-site'}})).status,403);assert.equal(calls,0);
 const data=await request(port,{url:'/api/dashboard',headers});assert.equal(data.status,200);assert.equal(calls,1);const state=JSON.parse(data.body);assert.equal(state.connection.state,'connected');assert.equal(state.dashboard.a3.registered_users,0);assert.equal(state.dashboard.a3.ready_rate,null);assert.ok(!data.body.includes('synthetic-excluded-account'));assert.ok(!data.body.includes('admin@example.invalid'));assert.equal(data.headers['cache-control'],'no-store');assert.equal(data.headers['access-control-allow-origin'],undefined);
 assert.equal((await request(port,{url:'/api/refresh',method:'POST',headers:{...headers,Origin:'https://attacker.invalid','Content-Type':'application/json','X-HamCare-Dashboard':'local'}})).status,403);
 assert.equal((await request(port,{url:'/api/refresh',method:'POST',headers:{...headers,Origin:origin,'Content-Type':'application/json','X-HamCare-Dashboard':'local'}})).status,200);assert.equal(calls,1);
});
test('shared SQL/UI stay intact and container explicitly whitelists runtime without user credentials/cloud SDK',()=>{
 const sql=fs.readFileSync(path.join(__dirname,'../../docs/analytics/trial_journey.sql'),'utf8'),panels=fs.readFileSync(path.join(__dirname,'dashboard_queries.sql'),'utf8');assert.ok(buildQuery(sql,panels).startsWith(sql));assert.equal(buildQuery(sql,panels).match(/AS metrics_json/g).length,1);
 const docker=fs.readFileSync(path.join(__dirname,'Dockerfile'),'utf8'),ignore=fs.readFileSync(path.join(__dirname,'Dockerfile.dockerignore'),'utf8'),code=fs.readFileSync(path.join(__dirname,'cloud-run.cjs'),'utf8');assert.ok(ignore.startsWith('**\n'));assert.ok(!docker.includes('COPY .'));assert.ok(docker.includes('USER node'));assert.ok(docker.includes('node:22-bookworm-slim'));assert.ok(!/gcloud|application_default_credentials|\.config|\.env|\.secrets|secret_key/i.test(docker));assert.ok(!code.includes('setInterval'));assert.ok(code.includes("server.listen(settings.port,'0.0.0.0'"));
});
