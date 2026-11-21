'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {parse,run,ENDPOINT}=require('./support_account_deletion.cjs');
const id='a'.repeat(48),sa='hamcare-support-operator@hamster-breeding-app.iam.gserviceaccount.com';
const root=fs.mkdtempSync(path.join(os.tmpdir(),'hamcare-support-operator-'));
process.on('exit',()=>fs.rmSync(root,{recursive:true,force:true}));
const file=(name,data,mode=0o600)=>{const p=path.join(root,name);fs.writeFileSync(p,JSON.stringify(data),{mode});return p;};
test('operator defaults to review, never accepts UID substitution',async()=>{
  const writes=[],sent=[];
  const result=await run(['--service-account='+sa,'--request='+id,'--output=unused'],{
    token:async()=> 'synthetic-oidc',send:async(b,t)=>{sent.push(b);assert.equal(t,'synthetic-oidc');return {reviewDigest:'digest'};},write:(...v)=>writes.push(v)});
  assert.deepEqual(result,{status:'review_saved_privately',dryRun:true});
  assert.deepEqual(sent,[{action:'review',requestId:id}]);assert.equal(writes.length,1);
  assert.throws(()=>parse(['--service-account='+sa,'--request='+id,'--uid=other','--output=x']));
});
test('execute needs separate explicit acknowledgement and matching private review file',()=>{
  const p=file('review.json',{requestId:id,reviewDigest:'bound-review'});
  const args=['--service-account='+sa,'--request='+id,'--execute','--review-file='+p];
  assert.throws(()=>parse(args));
  assert.equal(parse([...args,'--ack=EXECUTE_VERIFIED_DELETION']).body.reviewDigest,'bound-review');
  assert.throws(()=>parse([...args.map(v=>v==='--request='+id?'--request='+'b'.repeat(48):v),'--ack=EXECUTE_VERIFIED_DELETION']));
});
test('create uses private input and saves opaque link privately without logging proof',async()=>{
  const input=file('intake.json',{targetUid:'synthetic-existing',intakeRef:'CASE-001'});
  const output=path.join(root,'link.json');
  const result=await run(['--service-account='+sa,'--create','--input='+input,'--output='+output],{
    token:async()=> 'oidc',send:async b=>{assert.equal(b.action,'create');return {requestId:id,proof:'c'.repeat(64),expiresAt:123};}});
  assert.deepEqual(result,{status:'link_saved_privately'});
  assert.equal(fs.statSync(output).mode&0o077,0);
  const link=JSON.parse(fs.readFileSync(output,'utf8')).verificationLink;
  assert.ok(link.includes('/confirm/#request='));assert.ok(!link.includes('synthetic-existing'));
  await assert.rejects(run(['--service-account='+sa,'--create','--input='+input,'--output='+output],{
    token:async()=> 'oidc',send:async()=>({requestId:id,proof:'c'.repeat(64)})}));
});
test('world-readable or symlink inputs are rejected before network',()=>{
  const p=file('public.json',{targetUid:'synthetic',intakeRef:'CASE-002'},0o644);
  assert.throws(()=>parse(['--service-account='+sa,'--create','--input='+p,'--output=x']));
  const link=path.join(root,'symlink');fs.symlinkSync(p,link);
  assert.throws(()=>parse(['--service-account='+sa,'--create','--input='+link,'--output=x']));
});
test('endpoint is fixed, no direct Admin or credentials in command output',()=>{
  assert.match(ENDPOINT,/\/supportAccountDeletionOperator$/);
  const source=fs.readFileSync(path.join(__dirname,'support_account_deletion.cjs'),'utf8');
  assert.doesNotMatch(source,/firebase-admin|deleteUser|\.doc\(/);
  assert.match(source,/--impersonate-service-account=/);assert.match(source,/--audiences=/);
});
