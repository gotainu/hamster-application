'use strict';
// Real dispatch/runtime/store/Gmail modules with only synthetic Auth, database
// and HTTP dependencies. No credential, real account or network is accessed.
const {test}=require('node:test'),assert=require('node:assert/strict'),{createHash}=require('node:crypto');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource(),{dispatchLiveBillingNotifications:dispatch}=load('billingNotificationDispatch');
const {createBillingNotificationRuntime:createRuntime}=load('billingNotificationRuntime');
const {createBillingNotificationStore:createStore}=load('billingNotificationStore');
const NOW=Date.UTC(2030,0,1),UID='synthetic-limited-owner',EMAIL='owner@example.test';
const hash=v=>createHash('sha256').update(v).digest('hex'),ID=hash('limited-contract'),OTHER=hash('other-contract');
const clone=v=>structuredClone(v);
const selection=(extra={})=>({scope:'limited',notBeforeMillis:NOW,expiresAtMillis:NOW+6*3600000,
  subjectHash:hash(UID),recipientHash:hash(EMAIL),notificationId:ID,...extra});
const rawSelection=(extra={})=>({notBeforeMillis:String(NOW),expiresAtMillis:String(NOW+6*3600000),
  subjectHash:hash(UID),recipientHash:hash(EMAIL),notificationId:ID,...extra});
function fakeDb(){
  const docs=new Map(),reads=[],writes=[],queries=[];let tail=Promise.resolve(),onRead=()=>{};
  const ref=p=>({path:p,id:p.split('/').at(-1),async get(){reads.push(p);onRead(p);return snap(this);}});
  const snap=r=>({id:r.id,exists:docs.has(r.path),data:()=>clone(docs.get(r.path)),get:k=>clone(docs.get(r.path)?.[k])});
  const db={doc:ref,collection:name=>({where(field,op,value){let limit=20;return {orderBy(){return this;},limit(v){limit=v;return this;},async get(){queries.push(name);
    return {docs:[...docs].filter(([p,v])=>p.startsWith(name+'/')&&!p.slice(name.length+1).includes('/')&&v[field]<=value)
      .slice(0,limit).map(([p])=>snap(ref(p)))};}};}}),async runTransaction(fn){
    const result=tail.then(async()=>{const pending=[];const result=await fn({get:async r=>{assert.equal(pending.length,0);reads.push(r.path);onRead(r.path);return snap(r);},
      set:(r,v)=>pending.push(['set',r.path,clone(v)]),create:(r,v)=>pending.push(['create',r.path,clone(v)])});
    for(const [kind,p]of pending)if(kind==='create')assert.equal(docs.has(p),false);
    for(const [kind,p,v]of pending){docs.set(p,v);writes.push([kind,p,clone(v)]);}return result;});tail=result.catch(()=>{});return result;
  }};return {db,docs,reads,writes,queries,onRead:fn=>{onRead=fn;}};
}
function record(extra={}){return {id:ID,schemaVersion:1,environment:'live',trustedSource:'stripe_webhook',templateVersion:'billing-v1',
  type:'contract_registered',firebaseUid:UID,transitionKey:'synthetic-registered',eventHash:hash('event'),createdAtMillis:NOW,eventCreatedAtMillis:NOW,
  status:'pending',attempts:0,dispatchAtMillis:NOW,nextAttemptAtMillis:NOW,
  snapshot:{amount:550,legacyPrice:false,currency:'jpy',interval:'month',status:'active',trialEndSeconds:null,
    currentPeriodStartSeconds:NOW/1000,currentPeriodEndSeconds:NOW/1000+30*86400,nextChargeAtSeconds:NOW/1000+30*86400,
    latestInvoicePaymentStatus:'paid',latestInvoiceAmountPaid:550,latestInvoiceTotal:550,canceledAtSeconds:null,cancelAtPeriodEnd:false},...extra};}
function fixture(options={}){
  const f=fakeDb(),calls={auth:[],oauth:0,send:0,secret:0};let clock=NOW,user={uid:UID,email:EMAIL,emailVerified:true,disabled:false,providerData:[]};
  let raw={enabled:true,environment:'live',from:'gotainu@gmail.com',clientId:'synthetic.apps.googleusercontent.com',
    clientSecret:'synthetic-secret',refreshToken:'synthetic-refresh-token'};
  const path='billing_notification_outbox/'+ID;f.docs.set(path,record(options.record));
  const other=record({id:OTHER,firebaseUid:'synthetic-other-owner'});f.docs.set('billing_notification_outbox/'+OTHER,other);
  const deps={db:f.db,auth:{async getUser(uid){calls.auth.push(uid);return clone(user);}},environment:'live',
    liveDispatchScope:'limited',liveDispatchNotBeforeMillis:NOW,liveLimitedSelection:selection(),dailyLimit:1,now:()=>clock,
    rawConfig:()=>{calls.secret++;return raw;},fetchRequest:async(url)=>{
      if(String(url).includes('/token')){calls.oauth++;if(options.onOAuth)await options.onOAuth(f);
        return new Response(JSON.stringify({access_token:'synthetic-access',token_type:'Bearer',scope:'https://www.googleapis.com/auth/gmail.send'}),{status:200});}
      calls.send++;if(options.sendThrow)throw Error('Synthetic network failure');
      return new Response(JSON.stringify(options.sendStatus===503?{}:{id:'synthetic-message'}),{status:options.sendStatus??200});}};
  f.deps=deps;f.calls=calls;f.path=path;f.runtime=()=>createRuntime(deps);f.state=()=>clone(f.docs.get(path));
  f.time=()=>clock;f.advance=v=>{clock+=v;};f.user=v=>{user={...user,...v};};f.raw=v=>{raw=v;};return f;
}
const noMutation=f=>{assert.equal(f.writes.length,0);assert.equal(f.calls.send,0);assert.equal(f.calls.oauth,0);};
test('limited scope never reads or consumes the general cutoff',async()=>{
  let generalReads=0;const got=await dispatch({enabled:'true',scope:'limited',notBeforeMillis:()=>{generalReads++;throw Error();},
    limited:()=>rawSelection(),nowMillis:NOW,run:async p=>p});assert.equal(got.summary.scope,'limited');assert.equal(generalReads,0);
});
for(const scope of [undefined,'','closed'])test('missing/closed scope cannot fall back to general '+String(scope),async()=>{
  let reads=0;assert.deepEqual(await dispatch({enabled:'true',scope,notBeforeMillis:()=>{reads++;},limited:()=>{reads++;},nowMillis:NOW,run:async()=>{reads++;}}),{state:'disabled'});assert.equal(reads,0);
});
for(const patch of [{subjectHash:''},{recipientHash:hash('wrong')+'0'},{notificationId:'users/uid'},{notBeforeMillis:String(NOW-1)},
  {expiresAtMillis:String(NOW+6*3600000+1000)},{expiresAtMillis:String(NOW)},{subjectHash:[hash(UID)]}])
  test('invalid limited policy stops before runtime '+JSON.stringify(patch),async()=>{let calls=0;
    await assert.rejects(dispatch({enabled:'true',scope:'limited',notBeforeMillis:()=>{throw Error('General cutoff read');},limited:()=>rawSelection(patch),nowMillis:NOW,run:async()=>{calls++;}}));assert.equal(calls,0);});
test('expired limited scope never falls back to general',async()=>{let calls=0;
  await assert.rejects(dispatch({enabled:'true',scope:'limited',notBeforeMillis:()=>{calls++;},limited:()=>rawSelection(),nowMillis:NOW+6*3600000,run:async()=>{calls++;}}));assert.equal(calls,0);
});
test('general dispatch requires explicit general scope and a separate cutoff with limited fields removed',async()=>{
  const result=await dispatch({enabled:'true',scope:'general',notBeforeMillis:()=>String(NOW),limited:()=>({}),nowMillis:NOW,run:async p=>p});
  assert.deepEqual(result.summary,{scope:'general',notBeforeMillis:NOW});
  await assert.rejects(dispatch({enabled:'true',scope:'general',notBeforeMillis:()=>String(NOW),limited:()=>rawSelection(),nowMillis:NOW,run:async()=>{throw Error('Must not run');}}));
});
test('one exact owner contract notification sends once without querying or mutating the general queue',async()=>{
  const f=fixture(),other=clone(f.docs.get('billing_notification_outbox/'+OTHER)),result=await f.runtime().runOnce();
  assert.equal(result.counts.sent,1);assert.equal(f.calls.send,1);assert.equal(f.calls.oauth,1);assert.equal(f.state().status,'sent');
  assert.equal(f.queries.length,0);assert.ok(f.calls.auth.every(uid=>uid===UID));
  assert.ok(f.reads.filter(p=>p.startsWith('billing_notification_outbox/')).every(p=>p===f.path));
  assert.deepEqual(f.docs.get('billing_notification_outbox/'+OTHER),other);
  assert.deepEqual(await f.runtime().runOnce(),{processed:0,counts:{}});assert.equal(f.calls.send,1);
});
for(const patch of [{firebaseUid:'synthetic-other-owner'},{type:'payment_success'},{id:OTHER},{environment:'preview'},
  {trustedSource:'preview_fixture'},{createdAtMillis:NOW-1},{eventCreatedAtMillis:NOW-1000},{eventCreatedAtMillis:undefined},
  {createdAtMillis:NOW+6*3600000},{eventCreatedAtMillis:NOW+6*3600000},{eventCreatedAtMillis:NOW+1000}])
  test('out-of-scope selected document is neither claimed nor changed '+JSON.stringify(patch),async()=>{
    const f=fixture({record:patch}),before=f.state();assert.deepEqual(await f.runtime().runOnce(),{processed:0,counts:{}});
    noMutation(f);assert.equal(f.calls.auth.length,0);assert.equal(f.queries.length,0);assert.deepEqual(f.state(),before);
  });
test('direct claim cannot substitute another document or cross expiry during its read',async()=>{
  const f=fixture(),store=createStore(f.db,'live',NOW,selection(),f.time),claim=id=>store.claim({id,environment:'live',leaseToken:'owner',attemptId:'attempt',nowMillis:NOW,leaseUntilMillis:NOW+120000,maxAttempts:5});
  assert.equal((await claim(OTHER)).kind,'skipped');assert.equal(f.reads.length,0);
  f.onRead(()=>f.advance(6*3600000));assert.equal((await claim(ID)).kind,'skipped');noMutation(f);
});
for(const patch of [{liveDispatchScope:undefined},{liveDispatchScope:'closed'},{dailyLimit:50},{liveLimitedSelection:undefined},
  {liveLimitedSelection:selection({notBeforeMillis:NOW-1000})}])test('limited runtime invalid configuration rejects before Secret/queue '+Object.keys(patch),async()=>{
  const f=fixture();Object.assign(f.deps,patch);await assert.rejects(f.runtime().runOnce());noMutation(f);assert.equal(f.reads.length,0);assert.equal(f.calls.secret,0);
});
test('expired limited runtime rejects before Secret or queue access',async()=>{
  const f=fixture();f.advance(6*3600000);await assert.rejects(f.runtime().runOnce());noMutation(f);assert.equal(f.calls.secret,0);assert.equal(f.reads.length,0);
});
test('a changed verified address is rejected before the provider request',async()=>{
  const f=fixture({onOAuth:f=>f.user({email:'changed@example.test'})});await f.runtime().runOnce();
  assert.equal(f.calls.oauth,1);assert.equal(f.calls.send,0);assert.equal(f.state().status,'failed_permanent');assert.equal(f.state().lastErrorCategory,'recipient_not_allowed');
});
test('a different Auth UID cannot pass the final same-owner check',async()=>{
  const f=fixture({onOAuth:f=>f.user({uid:'synthetic-other-owner'})});await f.runtime().runOnce();assert.equal(f.calls.send,0);
});
test('expiry while OAuth is in flight stops before Gmail',async()=>{
  const f=fixture({onOAuth:f=>f.advance(6*3600000)});await f.runtime().runOnce();assert.equal(f.calls.oauth,1);assert.equal(f.calls.send,0);assert.equal(f.state().status,'failed_permanent');
});
test('changed outbox type after claim is rejected immediately before Gmail',async()=>{
  const f=fixture({onOAuth:f=>f.docs.set(f.path,{...f.state(),type:'payment_success'})});await f.runtime().runOnce();assert.equal(f.calls.send,0);
});
test('shared daily budget is preserved and refuses delivery without a reset',async()=>{
  const f=fixture();f.docs.set('billing_notification_delivery_limits/2030-01-01',{count:1});
  await f.runtime().runOnce();assert.equal(f.calls.oauth,0);assert.equal(f.calls.send,0);assert.equal(f.docs.get('billing_notification_delivery_limits/2030-01-01').count,1);
});
test('concurrent limited invocations reuse send intent and produce only one send',async()=>{
  const f=fixture();await Promise.all([f.runtime().runOnce(),f.runtime().runOnce()]);assert.equal(f.calls.send,1);assert.equal(f.state().status,'sent');
});
test('ambiguous accepted provider outcome remains uncertain and is never automatically resent',async()=>{
  const f=fixture({sendStatus:503});await f.runtime().runOnce();assert.equal(f.state().status,'uncertain');assert.equal(f.calls.send,1);
  assert.deepEqual(await f.runtime().runOnce(),{processed:0,counts:{}});assert.equal(f.calls.send,1);
});
test('contact-only limited Secret is never accepted for owner notification delivery',async()=>{
  const f=fixture();f.raw({enabled:true,environment:'live',from:'gotainu@gmail.com',clientId:'synthetic.apps.googleusercontent.com',clientSecret:'synthetic-secret',refreshToken:'synthetic-refresh-token',
    allowedSubjectHashes:[hash(UID)],allowedRecipientHashes:[hash(EMAIL)],limitedContactTest:{expiresAtMillis:NOW+1000,maxTotalSends:1}});
  await assert.rejects(f.runtime().runOnce());noMutation(f);assert.equal(f.reads.length,0);
});
