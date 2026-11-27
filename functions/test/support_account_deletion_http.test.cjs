'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {fakeFirestore,loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource();
const {createSupportDeletionHttp,SUPPORT_DELETION_ORIGIN}=load('supportAccountDeletionHttp');
const {createSupportDeletion}=load('supportAccountDeletion');
// Execute the real native declarations, including their pre-handler guards.
// Loading only the factory would miss failures before supportDeletion is called.
function nativeWrapper(name,runtime) {
  const ts=require('typescript'),vm=require('node:vm');
  const filename=path.join(__dirname,'../src/index.ts');
  const source=ts.createSourceFile(filename,fs.readFileSync(filename,'utf8'),ts.ScriptTarget.Latest,true);
  const declaration=source.statements.filter(ts.isVariableStatement)
    .flatMap(statement=>[...statement.declarationList.declarations])
    .find(node=>ts.isIdentifier(node.name)&&node.name.text===name);
  assert.ok(declaration&&ts.isCallExpression(declaration.initializer));
  assert.equal(declaration.initializer.expression.getText(source),'onRequest');
  assert.equal(declaration.initializer.arguments.length,2);
  assert.ok(ts.isArrowFunction(declaration.initializer.arguments[1]));
  const compiled=ts.transpileModule('const '+declaration.getText(source)+'; module.exports = '+name+';',
    {compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const module={exports:{}};
  vm.runInNewContext(compiled,{module,supportDeletion:runtime,SUPPORT_DELETION_ORIGIN,
    LIVE_WEB_BILLING_CONFIG:{},onRequest:(_options,handler)=>handler},{filename,timeout:1000});
  return module.exports;
}
for(const [name,route] of [['confirmSupportAccountDeletion','confirm'],['supportAccountDeletionOperator','operator']]) {
  test('native HTTP wrapper: '+name+' handles absent rawBody and keeps size/auth guards',async()=>{
    let enabled=true,entered=0;
    const forbidden=()=>assert.fail('No authentication, storage or deletion expected');
    const runtime=createSupportDeletionHttp({enabled:()=>{entered++;return enabled;},
      core:{db:{doc:forbidden},getUser:forbidden,runDeletion:forbidden,resumeDeletion:forbidden},
      auth:{verifyIdToken:forbidden,getUser:forbidden}});
    const handler=nativeWrapper(name,runtime);
    const headers={origin:SUPPORT_DELETION_ORIGIN};
    const invoke=async request=>{
      const response={code:200,headers:{},set(key,value){this.headers[key]=value;return this;},
        status(code){this.code=code;return this;},json(body){this.body=body;return this;}};
      await handler(request,response);
      assert.equal(response.headers['Cache-Control'],'no-store, max-age=0');
      return response;
    };
    for(const method of ['GET','POST']) {
      const request={method,headers,query:{}};
      assert.equal((await invoke(request)).code,400);
      enabled=false;assert.equal((await invoke(request)).code,503);enabled=true;
    }
    const before=entered;
    assert.equal((await invoke({method:'POST',headers,query:{},rawBody:Buffer.alloc(4097)})).code,400);
    assert.equal(entered,before,'Oversized input must stop before the factory');
    const body=route==='confirm'?{action:'inspect',requestId:'0'.repeat(48),proof:'0'.repeat(64)}:
      {action:'execute',requestId:'0'.repeat(48)};
    assert.equal((await invoke({method:'POST',headers,query:{},body,rawBody:Buffer.from(JSON.stringify(body))})).code,
      route==='confirm'?401:400);
  });
}
async function fixture(apple=false) {
  let now=1_795_305_600_000,calls=[];
  const {db}=fakeFirestore();const uid='synthetic-existing';
  const user={uid,disabled:false,emailVerified:false,metadata:{creationTime:new Date(now-86400000).toISOString()},
    providerData:apple?[{providerId:'apple.com',uid:'apple-subject'}]:[{providerId:'password',uid:'synthetic@example.com'}]};
  const token={uid,auth_time:now/1000,firebase:apple?{sign_in_provider:'apple.com',identities:{'apple.com':['apple-subject']}}:{sign_in_provider:'password'}};
  const core={db,now:()=>now,getUser:async()=>user,runDeletion:async()=>{calls.push('delete');return {ok:true};}};
  const ticket=await createSupportDeletion(core,{targetUid:uid,intakeRef:'CASE_TEST'});
  const auth={verifyIdToken:async(t,r)=>{calls.push(['verify',r]);assert.equal(t,'synthetic');return token;},getUser:async()=>user};
  const runtime=createSupportDeletionHttp({core,auth,enabled:()=>true});
  const body={action:'confirm',requestId:ticket.requestId,proof:ticket.proof,confirmText:'DELETE_MY_ACCOUNT',
    stopBillingConfirmed:true,appleRevocation:apple?'manual_acknowledged':'not_linked'};
  const req=(b=body)=>({method:'POST',headers:{origin:SUPPORT_DELETION_ORIGIN,authorization:'Bearer synthetic'},query:{},body:b});
  return {runtime,req,body,user,token,calls,core,auth};
}
test('disabled runtime rejects every route without auth, storage, or deletion',async()=>{
  const f=await fixture();const runtime=createSupportDeletionHttp({core:f.core,auth:{verifyIdToken:assert.fail,getUser:assert.fail},enabled:()=>false});
  assert.equal((await runtime.confirm(f.req())).status,503);
  assert.equal((await runtime.operator(f.req())).status,503);
  assert.deepEqual(f.calls,[]);
});
for(const apple of [false,true]) test('verified existing Firebase principal, no contact or profile requirement '+apple,async()=>{
  const f=await fixture(apple);
  const inspect=await f.runtime.confirm(f.req({action:'inspect',requestId:f.body.requestId,proof:f.body.proof}));
  assert.deepEqual(inspect,{status:200,body:{ok:true,appleLinked:apple}});
  assert.deepEqual(await f.runtime.confirm(f.req()),{status:200,body:{status:'verified'}});
  assert.ok(f.calls.every(v=>Array.isArray(v)&&v[0]==='verify'&&v[1]===true));
  assert.equal((await f.runtime.confirm(f.req())).status,403);
});
test('wrong origin, query, method, arbitrary UID or extra body key denied before auth',async()=>{
  const f=await fixture();
  const requests=[{...f.req(),method:'GET'},{...f.req(),query:{proof:'no'}},
    {...f.req(),headers:{...f.req().headers,origin:'https://other.invalid'}},
    f.req({...f.body,uid:'other'}),f.req({...f.body,authenticated:true})];
  for(const req of requests)assert.equal((await f.runtime.confirm(req)).status,400);
  assert.deepEqual(f.calls,[]);
});
test('authless, other UID, disabled account and mismatched Apple subject rejected without deletion',async()=>{
  const f=await fixture(true);
  assert.equal((await f.runtime.confirm({...f.req(),headers:{origin:SUPPORT_DELETION_ORIGIN}})).status,401);
  f.token.uid='other';assert.equal((await f.runtime.confirm(f.req())).status,403);f.token.uid=f.user.uid;
  f.user.disabled=true;assert.equal((await f.runtime.confirm(f.req())).status,403);f.user.disabled=false;
  f.token.firebase.identities['apple.com']=['other'];assert.equal((await f.runtime.confirm(f.req())).status,403);
  assert.ok(!f.calls.includes('delete'));
});
test('public endpoint cannot create, review, execute or supply arbitrary target',async()=>{
  const f=await fixture();
  for(const action of ['create','review','execute','resume_manual'])assert.equal((await f.runtime.confirm(f.req({action,requestId:f.body.requestId}))).status,400);
});
test('private handler defaults to review; unverified request and unacknowledged execute denied',async()=>{
  const f=await fixture();
  const base={method:'POST',headers:{},query:{}};
  assert.equal((await f.runtime.operator({...base,body:{requestId:f.body.requestId}})).status,409);
  assert.equal((await f.runtime.operator({...base,body:{action:'execute',requestId:f.body.requestId,reviewDigest:'x'}})).status,400);
  assert.ok(!f.calls.includes('delete'));
});
test('native operator transport is private IAM, no Hosting rewrite, same existing deletion dependencies',()=>{
  const source=fs.readFileSync(path.join(__dirname,'../src/index.ts'),'utf8');
  assert.match(source,/supportAccountDeletionOperator = onRequest\(\s*\{region:'asia-northeast1',invoker:'private'/);
  assert.match(source,/HAMCARE_SUPPORT_DELETION_ENABLED==='true'/);
  assert.match(source,/runDeletion:\(uid:string\)=>runAccountDeletion\(deletionDependencies,uid/);
  for(const name of ['firebase.json','firebase.account-deletion-preview.json']) {
    assert.doesNotMatch(fs.readFileSync(path.join(__dirname,'../../',name),'utf8'),/supportAccountDeletionOperator/);
  }
});
test('manual resume HTTP: only a verified private request with its separate acknowledgement can resume',async()=>{
 const {createHash}=require('node:crypto'),f=await fixture();await f.runtime.confirm(f.req());
 const key=createHash('sha256').update(f.user.uid).digest('hex');
 f.core.db.documents.set('account_deletion_requests/'+key,{version:1,uid:f.user.uid,status:'manual_review',
  attempt:12,paidConfirmed:true,billingStopped:false,lease:null,dueAt:null,requestedAt:1_795_305_590_000,updatedAt:1_795_305_599_999,reason:'retryable'});
 f.core.db.getAll=async(...refs)=>Promise.all(refs.map(ref=>ref.get()));
 f.core.resumeDeletion=async(uid,input)=>{assert.equal(uid,f.user.uid);assert.deepEqual(Object.keys(input).sort(),['fenceDigest','requestId']);f.calls.push('resume');return {ok:false,reason:'manual_review'};};
 const req=body=>({method:'POST',headers:{},query:{},body});
 const review=await f.runtime.operator(req({action:'review',requestId:f.body.requestId}));
 assert.equal(review.status,200);assert.equal(review.body.manualResumeAllowed,true);
 const body={action:'resume_manual',requestId:f.body.requestId,reviewDigest:review.body.reviewDigest,confirmText:'RESUME_VERIFIED_DELETION'};
 assert.equal((await f.runtime.confirm(f.req(body))).status,400);
 for(const bad of [{...body,confirmText:'EXECUTE_VERIFIED_DELETION'},{...body,targetUid:'other'},{...body,reviewDigest:undefined}])
  assert.notEqual((await f.runtime.operator(req(bad))).status,200);
 assert.ok(!f.calls.includes('resume'));assert.ok(!f.calls.includes('delete'));
 assert.deepEqual(await f.runtime.operator(req(body)),{status:200,body:{status:'manual_review',completionConfirmed:false}});
 assert.equal(f.calls.filter(x=>x==='resume').length,1);assert.ok(!f.calls.includes('delete'));
});
