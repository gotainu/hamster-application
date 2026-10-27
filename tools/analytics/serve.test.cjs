'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http'),vm=require('node:vm');
const {validateConfig,queryConfig,buildQuery,bqArgs,parseBqResult,makeController,makeServer,assertAggregate}=require('./serve.cjs');
const config=()=>validateConfig({excluded_user_ids:['synthetic-excluded-account']});
const aggregate=()=>({funnel:[{stage_order:1,stage:'registration',label:'登録',users:0,eligible_users:0,rate:null}],retention:[{day:1,eligible_users:0,retained_users:0,rate:null}],conversion_cohorts:[],landmark_segments:[],a3:[{registered_users:0,trial_starts:0,viewed:0,ready:0,generated:0,checkout:0,cancel_scheduled:0,ended:0,ready_rate:null,generated_rate:null,viewed_rate:null}]});
const template=fs.readFileSync(path.join(__dirname,'dashboard-template.html'),'utf8');
function temp(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'hamcare-aggregate-connect-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));return dir}
test('connection requires explicit exclusion list and bounded read/refresh limits',()=>{
 assert.throws(()=>validateConfig({}),/Explicit/);assert.throws(()=>validateConfig({excluded_user_ids:[],project_id:'another-project'}),/approved/);
 for(const v of [{max_bytes_billed:1},{cohort_days:180},{refresh_seconds:1},{stale_after_seconds:30}])assert.throws(()=>validateConfig({excluded_user_ids:[],...v}),/limits/);
 assert.deepEqual(validateConfig({excluded_user_ids:['fixture-a','fixture-a']}).excluded_user_ids,['fixture-a']);
});
test('JST cohort dates and knowledge cutoff are explicit; no completeness is invented',()=>{
 const q=queryConfig(config(),'2026-10-17T23:05:00Z');assert.equal(q.as_of,'2026-10-17T23:05:00.000Z');assert.equal(q.cohort_end,'2026-10-18');assert.equal(q.ga4_complete_through,null);assert.equal(q.server_complete_through,null);
 assert.throws(()=>queryConfig({...config(),server_complete_through:'2026-10-19T00:00:00Z'},q.as_of),/exceeds/);
});
test('one BigQuery job reuses existing normalization and exact shared panel SQL; IDs excluded before roster',()=>{
 const normalization=fs.readFileSync(path.join(__dirname,'../../docs/analytics/trial_journey.sql'),'utf8'),panels=fs.readFileSync(path.join(__dirname,'dashboard_queries.sql'),'utf8'),q=buildQuery(normalization,panels);
 assert.ok(q.startsWith(normalization));assert.equal(q.match(/CREATE TEMP TABLE journey_users/g).length,1);assert.equal(q.match(/AS metrics_json/g).length,1);
 assert.ok(q.indexOf('user_id NOT IN UNNEST(@excluded_user_ids)')<q.indexOf('registrations AS'));
 assert.ok(!/CREATE (?:OR REPLACE )?(?:TABLE|VIEW)|INSERT INTO|DELETE FROM|UPDATE `/i.test(q));
 const args=bqArgs(queryConfig(config(),'2026-10-18T00:00:00Z'));assert.ok(args.includes('--maximum_bytes_billed=100000000'));assert.ok(args.includes('--max_rows=1'));assert.ok(args.includes('--parameter=ga4_complete_through:TIMESTAMP:NULL'));assert.ok(args.includes('--parameter=server_complete_through:TIMESTAMP:NULL'));assert.ok(!args.some(v=>/--parameter=(?:server|ga4)_complete_through:TIMESTAMP:$/.test(v)));assert.ok(args.some(v=>v.startsWith('--parameter=excluded_user_ids:ARRAY<STRING>:')));
});
test('initial query failure is unconnected, never fabricated zero; private errors are redacted',async t=>{
 const c=makeController({config:config(),cacheDir:temp(t),query:'SELECT aggregate',now:()=> '2026-10-18T00:00:00Z',execute:async()=>{throw Error('secret credential fixture-private-uid')}});
 assert.equal(c.state().connection.state,'unconnected');assert.equal(c.state().dashboard,null);
 const s=await c.refresh();assert.equal(s.connection.state,'error');assert.equal(s.dashboard,null);assert.equal(s.connection.failure.code,'AGGREGATE_REFRESH_FAILED');assert.ok(!JSON.stringify(s).includes('fixture-private-uid'));
});
test('connected zero is distinct from unconnected; nullable rates and unknown watermarks survive',async t=>{
 const dir=temp(t),c=makeController({config:config(),cacheDir:dir,query:'SELECT aggregate',now:()=> '2026-10-18T00:00:00Z',execute:async()=>aggregate()});
 const s=await c.refresh();assert.equal(s.connection.state,'connected');assert.equal(s.dashboard.a3.registered_users,0);assert.equal(s.dashboard.a3.ready_rate,null);assert.equal(s.dashboard.metadata.as_of,'2026-10-18T00:00:00.000Z');assert.equal(s.dashboard.metadata.watermark.server,null);assert.equal(s.dashboard.diagnostics.source_completeness_confirmed,false);assert.equal(s.connection.stale,false);
 assert.ok(!JSON.stringify(s).includes('synthetic-excluded-account'));assert.equal(fs.statSync(dir).mode&0o777,0o700);assert.equal(fs.statSync(path.join(dir,'last-success.json')).mode&0o777,0o600);
});
test('refresh failure preserves exact last successful aggregates and visibly records failure',async t=>{
 let failure=false,time='2026-10-18T00:00:00Z';const dir=temp(t),c=makeController({config:config(),cacheDir:dir,query:'SELECT aggregate',now:()=>time,execute:async()=>{if(failure)throw Error('BQ_QUERY_FAILED');return aggregate()}});
 const first=await c.refresh(),saved=fs.readFileSync(path.join(dir,'last-success.json'),'utf8');time='2026-10-18T01:00:00Z';failure=true;const s=await c.refresh();
 assert.equal(s.connection.state,'error');assert.equal(s.connection.stale,true);assert.equal(s.connection.updated_at,first.connection.updated_at);assert.deepEqual(s.dashboard,first.dashboard);assert.equal(fs.readFileSync(path.join(dir,'last-success.json'),'utf8'),saved);
});
test('cached data is marked old and only reused under the same exclusion/connection config',async t=>{
 const dir=temp(t),first=makeController({config:config(),cacheDir:dir,query:'q',now:()=> '2026-10-18T00:00:00Z',execute:async()=>aggregate()});await first.refresh();
 const second=makeController({config:config(),cacheDir:dir,query:'q',now:()=> '2026-10-18T01:00:00Z'});assert.equal(second.state().connection.stale,true);assert.equal(second.state().connection.state,'connected');
 const changed=makeController({config:{...config(),excluded_user_ids:[]},cacheDir:dir,query:'q',now:()=> '2026-10-18T01:00:00Z'});assert.equal(changed.state().dashboard,null);assert.equal(changed.state().connection.state,'unconnected');
});
test('parallel manual refreshes reuse one pending read job',async t=>{
 let calls=0,release;const ready=new Promise(resolve=>{release=resolve});const c=makeController({config:config(),cacheDir:temp(t),query:'q',now:()=> '2026-10-18T00:00:00Z',execute:async()=>{calls++;await ready;return aggregate()}});
 const first=c.refresh(),second=c.refresh();assert.equal(calls,1);assert.equal(c.state().connection.refreshing,true);release();await Promise.all([first,second]);assert.equal(calls,1);
});
test('identifier fields never enter successful output/cache',async t=>{
 const raw=aggregate();raw.a3[0].uid='fixture-private-id';assert.throws(()=>assertAggregate({...raw,a3:raw.a3[0]}),/PRIVATE_FIELD/);
 const c=makeController({config:config(),cacheDir:temp(t),query:'q',now:()=> '2026-10-18T00:00:00Z',execute:async()=>raw});const s=await c.refresh();assert.equal(s.dashboard,null);assert.equal(s.connection.failure.code,'BQ_AGGREGATE_PRIVATE_FIELD');
});
function request(port,{method='GET',url='/',headers={}}={}){return new Promise((resolve,reject)=>{const r=http.request({host:'127.0.0.1',port,method,path:url,headers:{Host:`127.0.0.1:${port}`,...headers}},res=>{let body='';res.on('data',c=>body+=c);res.on('end',()=>resolve({status:res.statusCode,body,headers:res.headers}))});r.on('error',reject);r.end(method==='POST'?'{}':undefined)})}
test('HTTP connection serves existing HTML + aggregate API on loopback; rejects cross-origin refresh and DNS rebinding',async t=>{
 const c=makeController({config:config(),cacheDir:temp(t),query:'q',now:()=> '2026-10-18T00:00:00Z',execute:async()=>aggregate()});
 // Test bind uses an ephemeral loopback port, then locks Host to the assigned value.
 const blocker=http.createServer();await new Promise(resolve=>blocker.listen(0,'127.0.0.1',resolve));const port=blocker.address().port;await new Promise(resolve=>blocker.close(resolve));
 const s=makeServer({controller:c,config:config(),port,template,synthetic:{...aggregate(),a3:aggregate().a3[0]}});await new Promise(resolve=>s.listen(port,'127.0.0.1',resolve));t.after(()=>new Promise(resolve=>s.close(resolve)));
 assert.equal(s.address().address,'127.0.0.1');const html=await request(port);assert.equal(html.status,200);assert.ok(html.body.includes('const liveConnection=true'));assert.ok(html.body.includes('id="data-updated"'));assert.ok(!html.body.includes('synthetic-excluded-account'));
 assert.equal((await request(port,{headers:{Host:'attacker.invalid'}})).status,403);assert.equal((await request(port,{method:'POST',url:'/api/refresh',headers:{Origin:'https://attacker.invalid'}})).status,403);
 assert.equal((await request(port,{method:'POST',url:'/api/refresh',headers:{Origin:`http://127.0.0.1:${port}`,'Content-Type':'application/json','X-HamCare-Dashboard':'local'}})).status,200);
 const data=await request(port,{url:'/api/dashboard'});assert.equal(JSON.parse(data.body).connection.state,'connected');assert.equal(data.headers['cache-control'],'no-store');assert.equal(data.headers['access-control-allow-origin'],undefined);
});
test('existing renderer defaults offline; connection UI labels source/cutoff/failure and stale states',()=>{
 assert.ok(template.includes('const liveConnection=/*LIVE_CONNECTION*/false'));assert.ok(template.includes('BigQueryに接続済みです。対象期間の分類済み一般ユーザーは0人です。'));assert.ok(template.includes('人数は未確認'));assert.ok(template.includes('更新が古くなっています。前回の結果です。'));assert.ok(template.includes('最終失敗: ${connection.failure.at}'));assert.ok(template.includes('syncLive(refresh=false)'));assert.ok(template.includes('[hidden]{display:none!important}'));assert.ok(!template.includes('架空データの基準: ${m.as_of')||template.includes("selected==='general'?"));
 // Compile the actual inline script so live edits cannot silently break the existing dashboard.
 const script=template.match(/<script>([\s\S]*?)<\/script>/)[1].replace('/*AGGREGATE_DATA*/null','{}');new vm.Script(script);
});

// bq scripts can return per-statement status strings and nested final result arrays.
test('BigQuery nested script results accept one aggregate record and known assertion/temp-DDL statuses only',()=>{
 const row={metrics_json:JSON.stringify(aggregate())};
 assert.deepEqual(parseBqResult(JSON.stringify([row])),aggregate());
 assert.deepEqual(parseBqResult(JSON.stringify(['Assertion successful','Assertion successful','Created temp table journey_users.',[[row]]])),aggregate());
 assert.deepEqual(parseBqResult(JSON.stringify(['Assertion successful','Created hamster-breeding-app._script012345abcdef.journey_users\n',[row]])),aggregate());
 for(const bad of [[row,row],['unrecognized statement output',row],['Created hamster-breeding-app._script0123.private_user_rows',row],[{user_id:'fixture-private-id'},row],[{metrics_json:row.metrics_json,extra:true}],['Assertion successful'],[null,row]])assert.throws(()=>parseBqResult(JSON.stringify(bad)));
 assert.throws(()=>parseBqResult('not JSON'));
});
