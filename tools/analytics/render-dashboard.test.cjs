'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const {renderDashboard}=require('./render-dashboard.cjs');
const template=fs.readFileSync(path.join(__dirname,'dashboard-template.html'),'utf8');
const fixture=()=>({funnel:[],retention:[],a3:{registered_users:0,trial_starts:0},conversion_cohorts:[],landmark_segments:[],metadata:{synthetic_only:true}});
test('same aggregate produces the same standalone report; zero and null remain distinct',()=>{
 const data={general:fixture(),synthetic:fixture()};data.general.a3.ready_rate=null;
 const html=renderDashboard(data,template);assert.equal(html,renderDashboard(data,template));
 assert.ok(html.includes('"registered_users":0'));assert.ok(html.includes('"ready_rate":null'));
 assert.ok(!html.includes('/*AGGREGATE_DATA*/null'));
});
test('embedded aggregate cannot terminate its JSON script; data is not interpreted as markup',()=>{
 const d=fixture();d.metadata.note='</script><script>alert(1)</script>';
 const html=renderDashboard({synthetic:d},template);
 assert.ok(!html.includes('</script><script>alert(1)'));
 assert.ok(html.includes('\\u003c/script>'));
});
test('direct identifiers and private record text are rejected from reports',()=>{
 for(const key of ['user_id','uid','email','question','answer','memo','customer_id','subscription_id']){
  const d=fixture();d.metadata[key]='not-for-dashboard';
  assert.throws(()=>renderDashboard({general:d},template),/aggregates only/);
 }
});
test('malformed aggregate is rejected',()=>assert.throws(()=>renderDashboard({general:{a3:{}}},template),/schema/));
test('runner creates a report but refuses to overwrite an existing output',()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'journey-report-'));
 try{
  const input=path.join(folder,'aggregate.json'),output=path.join(folder,'report.html');fs.writeFileSync(input,JSON.stringify(fixture()));
  const args=[path.join(__dirname,'render-dashboard.cjs'),input,input,output];
  const first=spawnSync(process.execPath,args,{encoding:'utf8'});assert.equal(first.status,0,first.stderr);
  const saved=fs.readFileSync(output,'utf8'),second=spawnSync(process.execPath,args,{encoding:'utf8'});
  assert.notEqual(second.status,0);assert.match(second.stderr,/EEXIST/);assert.equal(fs.readFileSync(output,'utf8'),saved);
 }finally{fs.rmSync(folder,{recursive:true,force:true})}
});
