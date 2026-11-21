'use strict';
// Real runner + Worker/Store/normalizer/templates; only cloud and mail I/O are
// substituted. Repeating the same smoke run cannot create another end event.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {createHash}=require('node:crypto'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {loadStarSource}=require('./support/star_source_loader.cjs'),load=loadStarSource();
const hash=v=>createHash('sha256').update(v).digest('hex');
const UID='synthetic_preview_owner',FROM='gotainu@gmail.com',RUN='hamcare-billing-mail-preview-20261121-v1';
const source=fs.readFileSync(path.resolve(__dirname,'../scripts/billing_notification_preview.cjs'),'utf8');
function fixture(){
  let clock=Date.UTC(2030,0,1),tail=Promise.resolve();const docs=new Map(),mail=[],writes=[];
  docs.set('preview_checkout_task4/'+hash(UID),{previewFirebaseUid:UID});docs.set('users/'+UID+'/owner_profiles/main',{});docs.set('users/'+UID+'/pet_profiles/main_pet',{});
  const ref=p=>({path:p,id:p.split('/').at(-1),get:async()=>snap(ref(p))});
  const snap=r=>({ref:r,id:r.id,exists:docs.has(r.path),data:()=>structuredClone(docs.get(r.path)),get:key=>docs.get(r.path)?.[key]});
  const db={doc:ref,collection:name=>({
    where(field,op,value){
      assert.equal(op,'==');let cap=20;
      return {limit(n){cap=n;return this;},async get(){
        const selected=[...docs].filter(([p,v])=>p.startsWith(name+'/')&&v[field]===value).slice(0,cap);
        return {size:selected.length,docs:selected.map(([p])=>snap(ref(p)))};
      }};
    },
  }),
    async runTransaction(fn){const run=tail.then(async()=>{const pending=[];const result=await fn({get:async r=>{assert.equal(pending.length,0);return snap(r);},set:(r,v)=>pending.push(['set',r.path,v]),create:(r,v)=>{if(docs.has(r.path))throw Error();pending.push(['create',r.path,v]);},delete:r=>pending.push(['delete',r.path])});for(const [kind,p,v]of pending){if(kind==='delete')docs.delete(p);else docs.set(p,structuredClone(v));writes.push([kind,p]);}return result;});tail=run.catch(()=>{});return run;}};
  const config={enabled:true,environment:'preview',from:FROM,clientId:'synthetic.apps.googleusercontent.com',clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token',allowedSubjectHashes:[hash(UID)],allowedRecipientHashes:[hash(FROM)]};
  const user={uid:UID,email:FROM,emailVerified:true,disabled:false,providerData:[]};
  async function run(flag='--send-owner-preview'){
    const output=[],errors=[],processStub={argv:['node','runner',flag],stdout:{write:s=>output.push(s)},stderr:{write:s=>errors.push(s)},exitCode:0};
    const RealDate=Date;class ClockDate extends RealDate{constructor(...args){super(...(args.length?args:[clock]));}static now(){return clock;}}
    const mod={exports:{}};
    const req=name=>{
      if(name==='node:child_process')return {spawnSync:()=>({status:0,stdout:JSON.stringify(config)})};
      if(name==='firebase-admin/app')return {initializeApp(){}};
      if(name==='firebase-admin/firestore')return {getFirestore:()=>db};
      if(name==='firebase-admin/auth')return {getAuth:()=>({getUser:async uid=>{assert.equal(uid,UID);return user;}})};
      if(name.startsWith('../lib/')){
        const nameOnly=name.slice('../lib/'.length),real=load(nameOnly);
        return nameOnly==='billingNotificationGmail'?{...real,createBillingNotificationGmailSender:()=>({send:async m=>{mail.push(m);return {messageIdHash:hash(m.notificationId)};}})}:real;
      }
      return require(name);
    };
    vm.runInNewContext('(function(require,module,process,Date){'+source+'\n})',{Buffer})(req,mod,processStub,ClockDate);
    await mod.exports.completion;
    return {exit:processStub.exitCode,result:output.length?JSON.parse(output.join('')):null,errors};
  }
  return {docs,mail,writes,run,advance:ms=>{clock+=ms;},notifications:()=>[...docs].filter(([p])=>p.startsWith('preview_billing_notification_outbox/'))};
}
test('same smoke run at a later wall clock retains five sent records and sends zero again',async()=>{
  const f=fixture(),first=await f.run();assert.equal(first.exit,0);assert.equal(first.result.providerSendCalls,5);assert.equal(f.mail.length,5);
  const originals=f.notifications().map(([p,v])=>[p,structuredClone(v)]);f.advance(3600000);
  const repeat=await f.run();assert.equal(repeat.exit,0);assert.equal(repeat.result.providerSendCalls,0);assert.equal(repeat.result.discardedUnsentFixtures,0);
  assert.equal(f.mail.length,5);assert.deepEqual(f.notifications(),originals);
});
test('only this owner run never-dispatched surplus fixture may be cleaned without another send',async()=>{
  const f=fixture();await f.run();const [,ended]=f.notifications().find(([,v])=>v.type==='canceled');const id=hash('synthetic-surplus');
  f.docs.set('preview_billing_notification_outbox/'+id,{...structuredClone(ended),id,status:'failed_retryable',lastErrorCategory:'local_sending_limit',dispatchAtMillis:Date.UTC(2030,0,2),messageIdHash:undefined,sentAtMillis:undefined,sendStartedAtMillis:undefined});
  f.advance(3600000);const repeat=await f.run();assert.equal(repeat.exit,0);assert.equal(repeat.result.discardedUnsentFixtures,1);assert.equal(repeat.result.providerSendCalls,0);assert.equal(f.mail.length,5);assert.equal(f.notifications().length,5);
});
for(const status of ['sent','sending','uncertain'])test('surplus '+status+' record is never removed or reset',async()=>{
  const f=fixture();await f.run();const [,ended]=f.notifications().find(([,v])=>v.type==='canceled'),id=hash('surplus-'+status),p='preview_billing_notification_outbox/'+id;
  const extra={...structuredClone(ended),id,status};f.docs.set(p,extra);const repeat=await f.run();assert.equal(repeat.exit,1);assert.deepEqual(f.docs.get(p),extra);assert.equal(f.mail.length,5);
});
test('unknown flags and another owner existing fixture cannot authorize sending',async()=>{
  const f=fixture();const invalid=await f.run('--arbitrary-recipient');assert.equal(invalid.exit,1);assert.equal(f.mail.length,0);
  f.docs.set('preview_billing_notification_outbox/'+hash('other'),{firebaseUid:'synthetic_other',environment:'preview',trustedSource:'preview_fixture',fixtureRunId:RUN});
  assert.equal((await f.run()).exit,1);assert.equal(f.mail.length,0);
});
