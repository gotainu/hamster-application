'use strict';
// This suite connects the actual runtime, store, recipient, templates, budgets
// and Gmail transport. Only Auth, Firestore storage and HTTP are synthetic.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource(),{createBillingNotificationRuntime:createRuntime}=load('billingNotificationRuntime');
const hash=v=>createHash('sha256').update(v).digest('hex');
const NOW=Date.UTC(2030,0,1),UID='synthetic-runtime-mail-owner',EMAIL='synthetic@example.test',ID=hash('runtime-mail-notification');
const clone=v=>structuredClone(v);
function fakeDb({cooldownWriteFail=false}={}){
  const documents=new Map(),writes=[],reads=[],queries=[];let tail=Promise.resolve();
  const ref=path=>({path,id:path.split('/').at(-1),async get(){reads.push(path);return snapshot(this);}});
  const snapshot=r=>({exists:documents.has(r.path),id:r.id,data:()=>clone(documents.get(r.path)),get:key=>clone(documents.get(r.path)?.[key])});
  const db={doc:ref,collection:name=>({where(field,op,value){let limit=20;return {orderBy(){return this;},limit(n){limit=n;return this;},async get(){
    queries.push(name);assert.equal(field,'dispatchAtMillis');assert.equal(op,'<=');
    return {docs:[...documents].filter(([path,v])=>path.startsWith(name+'/') && !path.slice(name.length+1).includes('/') &&
      typeof v[field]==='number' && v[field]<=value).sort((a,b)=>a[1][field]-b[1][field]).slice(0,limit).map(([path])=>snapshot(ref(path)))};
  }};}}),async runTransaction(fn){const run=tail.then(async()=>{
    const pending=[];const value=await fn({get:async r=>{assert.equal(pending.length,0);reads.push(r.path);return snapshot(r);},
      set:(r,v)=>{if(cooldownWriteFail && r.path.endsWith('/_sender'))throw Error('Synthetic sender cooldown write failed');pending.push(['set',r.path,clone(v)]);},create:(r,v)=>pending.push(['create',r.path,clone(v)])});
    for(const [op,path]of pending)if(op==='create')assert.equal(documents.has(path),false);
    for(const [op,path,v]of pending){documents.set(path,v);writes.push([op,path,clone(v)]);}return value;
  });tail=run.catch(()=>{});return run;}};
  return {db,documents,writes,reads,queries};
}
function snapshot(extra={}){return {amount:550,legacyPrice:false,currency:'jpy',interval:'month',status:'active',trialEndSeconds:null,
  currentPeriodStartSeconds:NOW/1000,currentPeriodEndSeconds:NOW/1000+30*86400,nextChargeAtSeconds:NOW/1000+30*86400,
  latestInvoicePaymentStatus:'paid',latestInvoiceAmountPaid:550,latestInvoiceTotal:550,canceledAtSeconds:null,cancelAtPeriodEnd:false,...extra};}
function record(extra={}){return {id:ID,schemaVersion:1,environment:'preview',trustedSource:'preview_fixture',templateVersion:'billing-v1',
  type:'contract_registered',firebaseUid:UID,transitionKey:'synthetic-contract-registered',eventHash:hash('runtime-mail-event'),snapshot:snapshot(),
  status:'pending',createdAtMillis:NOW,attempts:0,nextAttemptAtMillis:NOW,dispatchAtMillis:NOW,...extra};}
const config=(extra={})=>({enabled:true,environment:'preview',from:'gotainu@gmail.com',clientId:'synthetic-client.apps.googleusercontent.com',
  clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token-long',allowedSubjectHashes:[hash(UID)],allowedRecipientHashes:[hash(EMAIL)],...extra});
function fixture(options={}){
  const f=fakeDb(options),calls={auth:[],fetch:[]};let clock=NOW;
  const mode=options.environment??'preview',collection=mode==='live'?'billing_notification_outbox':'preview_billing_notification_outbox';
  const user={uid:UID,disabled:false,email:EMAIL,emailVerified:true,providerData:[],...options.user};
  let raw=options.rawConfig===undefined?config():options.rawConfig;
  f.documents.set(collection+'/'+ID,record({environment:mode,trustedSource:mode==='live'?'stripe_webhook':'preview_fixture',...options.record}));
  const dependencies={db:f.db,auth:{async getUser(uid){calls.auth.push(uid);if(options.authError)throw options.authError;return clone(user);}},
    environment:mode,rawConfig:()=>raw,dailyLimit:options.dailyLimit===undefined?10:options.dailyLimit,now:()=>clock,
    fetchRequest:async(url,request)=>{calls.fetch.push({url,request});
      if(String(url).includes('/token'))return new Response(JSON.stringify({access_token:'synthetic-access',token_type:'Bearer',scope:'https://www.googleapis.com/auth/gmail.send'}),{status:200});
      if(options.sendThrow)throw Error('Synthetic network failure');
      return new Response(JSON.stringify(options.sendBody??{id:'syntheticMessage'}),{status:options.sendStatus??200,headers:options.sendHeaders});}};
  f.dependencies=dependencies;f.runtime=()=>createRuntime(dependencies);f.calls=calls;f.user=user;
  f.state=()=>clone(f.documents.get(collection+'/'+ID));f.raw=v=>{raw=v;};f.advance=n=>{clock+=n;};f.collection=collection;
  f.sentMime=()=>calls.fetch.filter(c=>!String(c.url).includes('/token')).map(c=>Buffer.from(JSON.parse(c.request.body).raw,'base64url').toString('utf8'));
  return f;
}
function noAccess(f){assert.equal(f.calls.auth.length,0);assert.equal(f.calls.fetch.length,0);assert.equal(f.reads.length,0);assert.equal(f.queries.length,0);assert.equal(f.writes.length,0);}
test('runtime construction is inert before explicit runOnce',()=>{const f=fixture();f.runtime();noAccess(f);});
for(const raw of [null,'','{bad',{},config({enabled:false}),config({clientSecret:undefined}),config({refreshToken:undefined}),config({environment:'live'})])
  test('missing/mixed configuration fails before Auth/Firestore/Gmail',async()=>{const f=fixture({rawConfig:raw});await assert.rejects(f.runtime().runOnce());noAccess(f);});
test('missing environment fails closed before external activity',async()=>{const f=fixture();f.dependencies.environment=undefined;await assert.rejects(f.runtime().runOnce());noAccess(f);});
for(const limit of [undefined,0,101,1.5])test('Live daily operator budget '+String(limit)+' is mandatory before reads',async()=>{
  const {allowedSubjectHashes,allowedRecipientHashes,...live}=config({environment:'live'});
  const f=fixture({environment:'live',rawConfig:live});f.dependencies.dailyLimit=limit;
  await assert.rejects(f.runtime().runOnce());noAccess(f);
});
test('verified Auth email reaches fixed Gmail sender and writes only private Preview mail state/budget',async()=>{
  const f=fixture(),result=await f.runtime().runOnce();assert.equal(result.counts.sent,1);assert.equal(f.state().status,'sent');
  assert.equal(f.state().recipientSource,'auth_verified');assert.deepEqual(f.calls.auth,[UID]);assert.equal(f.calls.fetch.length,2);
  assert.deepEqual(f.queries,['preview_billing_notification_outbox']);
  assert.ok(f.writes.every(([,path])=>path.startsWith('preview_billing_')));
  assert.doesNotMatch(JSON.stringify(f.writes),/@|synthetic-client-secret|synthetic-refresh|月額550円|Bearer /);
  const mime=f.sentMime()[0];assert.match(mime,/From: HamCare <gotainu@gmail\.com>/);assert.match(mime,/To: <synthetic@example\.test>/);
  assert.deepEqual(await f.runtime().runOnce(),{processed:0,counts:{}});assert.equal(f.sentMime().length,1);
});
for(const domain of ['privaterelay.appleid.com','private.icloud.com'])test('verified same-UID Apple '+domain+' is accepted only through allowlist',async()=>{
  const email='synthetic-relay@'+domain,f=fixture({user:{email,providerData:[{providerId:'apple.com',uid:'synthetic-apple-subject',email}]},rawConfig:config({allowedRecipientHashes:[hash(email)]})});
  await f.runtime().runOnce();assert.equal(f.state().status,'sent');assert.equal(f.state().recipientSource,'apple_relay');assert.match(f.sentMime()[0],new RegExp('To: <synthetic-relay@'+domain.replaceAll('.','\\.')+'>'));
});
test('confirmed supplemental contact is resolved by UID from Preview only',async()=>{
  const f=fixture({user:{email:undefined,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-sub'}]}});
  f.documents.set('preview_billing_contacts/'+UID,{purpose:'billing_contact_preview',schemaVersion:1,verified:true,verificationStatus:'verified',source:'user_supplied',email:EMAIL,verifiedAt:NOW-1000});
  f.documents.set('billing_contacts/'+UID,{firebaseUid:UID,purpose:'billing_contact_live',schemaVersion:1,verified:true,verificationStatus:'verified',source:'user_supplied',email:'not-allowed@example.test',verifiedAt:NOW-1000});
  await f.runtime().runOnce();assert.equal(f.state().status,'sent');assert.equal(f.state().recipientSource,'user_supplied');
  assert.ok(f.reads.includes('preview_billing_contacts/'+UID));assert.ok(!f.reads.includes('billing_contacts/'+UID));
});
test('unconfirmed Auth and no supplemental contact block without repeated delivery attempts',async()=>{
  const f=fixture({user:{emailVerified:false}});await f.runtime().runOnce();assert.equal(f.state().status,'blocked_no_verified_contact');
  assert.equal(f.calls.fetch.length,0);assert.equal(f.state().dispatchAtMillis,undefined);
  await f.runtime().runOnce();assert.equal(f.calls.auth.length,1);assert.equal(f.calls.fetch.length,0);
});
test('Relay syntax without authoritative Apple provider identity cannot send',async()=>{
  const email='fake@privaterelay.appleid.com',f=fixture({user:{email,providerData:[]},rawConfig:config({allowedRecipientHashes:[hash(email)]})});
  await f.runtime().runOnce();assert.equal(f.state().status,'blocked_no_verified_contact');assert.equal(f.calls.fetch.length,0);
});
test('expired/mismatched unverified supplemental state cannot use a Live contact as Preview fallback',async()=>{
  const f=fixture({user:{email:undefined,emailVerified:false}});
  f.documents.set('preview_billing_contacts/'+UID,{purpose:'billing_contact_live',schemaVersion:1,verified:true,verificationStatus:'verified',source:'user_supplied',email:EMAIL,verifiedAt:NOW-1000});
  f.documents.set('billing_contacts/'+UID,{firebaseUid:UID,purpose:'billing_contact_live',schemaVersion:1,verified:true,verificationStatus:'verified',source:'user_supplied',email:EMAIL,verifiedAt:NOW-1000});
  await f.runtime().runOnce();assert.equal(f.state().status,'blocked_no_verified_contact');assert.equal(f.calls.fetch.length,0);
});
for(const extra of [{user:{uid:'another-uid'}},{user:{disabled:true}},{authError:{code:'auth/user-not-found'}}])
  test('wrong-UID/disabled/deleted Auth account never dispatches mail '+Object.keys(extra).join(','),async()=>{
    const f=fixture(extra);await f.runtime().runOnce();assert.equal(f.state().status,'blocked_no_verified_contact');assert.equal(f.calls.fetch.length,0);
  });
test('Auth outage retries outbox without leaking Auth errors or affecting billing',async()=>{
  const f=fixture({authError:{code:'auth/internal-error',message:'sensitive@example.test'}});
  const untouched={plan:'paid',status:'active',stripeCustomerId:'cus_synthetic'};f.documents.set('users/'+UID+'/billing/subscription',untouched);
  await f.runtime().runOnce();assert.equal(f.state().status,'failed_retryable');assert.equal(f.state().lastErrorCategory,'recipient_unavailable');
  assert.deepEqual(f.documents.get('users/'+UID+'/billing/subscription'),untouched);assert.equal(f.calls.fetch.length,0);
  assert.doesNotMatch(JSON.stringify(f.writes),/sensitive@example/);
});
test('Preview approved recipient is still rejected when the UID is outside the subject allowlist',async()=>{
  const f=fixture({rawConfig:config({allowedSubjectHashes:[hash('another-owner')]})});
  await f.runtime().runOnce();assert.equal(f.state().status,'blocked_recipient_not_allowed');assert.equal(f.calls.fetch.length,0);
});
test('Preview approved UID cannot send to an unlisted verified email',async()=>{
  const f=fixture({user:{email:'other@example.test'}});await f.runtime().runOnce();
  assert.equal(f.state().status,'blocked_recipient_not_allowed');assert.equal(f.calls.fetch.length,0);
});
test('Preview does not read or mutate production outbox/billing while sending a valid test',async()=>{
  const f=fixture(),live=record({environment:'live',trustedSource:'stripe_webhook'});
  f.documents.set('billing_notification_outbox/'+ID,live);f.documents.set('users/'+UID+'/billing/subscription',{plan:'paid',status:'active'});
  await f.runtime().runOnce();assert.deepEqual(f.documents.get('billing_notification_outbox/'+ID),live);
  assert.deepEqual(f.documents.get('users/'+UID+'/billing/subscription'),{plan:'paid',status:'active'});
  assert.ok(!f.reads.some(path=>path.startsWith('users/')||path.startsWith('billing_notification_outbox/')));
});
test('Live does not read Preview outbox/contact/budget namespaces',async()=>{
  const {allowedSubjectHashes,allowedRecipientHashes,...live}=config({environment:'live'}),f=fixture({environment:'live',rawConfig:live,dailyLimit:2});
  const preview=record();f.documents.set('preview_billing_notification_outbox/'+ID,preview);
  await f.runtime().runOnce();assert.equal(f.state().status,'sent');assert.deepEqual(f.documents.get('preview_billing_notification_outbox/'+ID),preview);
  assert.ok(f.queries.every(path=>path==='billing_notification_outbox'));assert.ok(f.writes.every(([,path])=>!path.startsWith('preview_')));
});
test('Live rejects a Preview-fixture producer even inside its own collection',async()=>{
  const {allowedSubjectHashes,allowedRecipientHashes,...live}=config({environment:'live'}),f=fixture({environment:'live',rawConfig:live,record:{trustedSource:'preview_fixture'},dailyLimit:2});
  await f.runtime().runOnce();assert.equal(f.state().status,'blocked_invalid_notification');assert.equal(f.calls.auth.length,0);assert.equal(f.calls.fetch.length,0);
});
test('concurrent runtime instances dispatch one actual synthetic Gmail request',async()=>{
  const f=fixture();await Promise.all([f.runtime().runOnce(),f.runtime().runOnce()]);assert.equal(f.state().status,'sent');assert.equal(f.sentMime().length,1);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/2030-01-01').count,1);
});
test('shared Preview contact-mail cap blocks Gmail before OAuth and defers notification',async()=>{
  const f=fixture();f.documents.set('preview_billing_contact_delivery_limits/2030-01-01',{count:10,purpose:'billing_contact_preview'});
  await f.runtime().runOnce();assert.equal(f.state().status,'failed_retryable');assert.equal(f.state().lastErrorCategory,'local_sending_limit');
  assert.equal(f.calls.fetch.length,0);assert.equal(f.documents.get('preview_billing_contact_delivery_limits/2030-01-01').count,10);
});
test('Gmail daily quota refusal never affects billing and uses rolling24h retry',async()=>{
  const f=fixture({sendStatus:429,sendBody:{error:{message:'User-rate limit exceeded (Mail sending)'}}});
  f.documents.set('users/'+UID+'/billing/subscription',{plan:'paid',status:'active'});
  await f.runtime().runOnce();assert.equal(f.state().status,'failed_retryable');assert.equal(f.state().lastErrorCategory,'sending_limit');
  assert.ok(f.state().nextAttemptAtMillis>=NOW+86400000);assert.deepEqual(f.documents.get('users/'+UID+'/billing/subscription'),{plan:'paid',status:'active'});
});
test('one Gmail sending-limit response pauses the whole remaining queued batch',async()=>{
  const f=fixture({sendStatus:429,sendBody:{error:{message:'User-rate limit exceeded (Mail sending)'}}}),second=hash('second-runtime-notification');
  f.documents.set('preview_billing_notification_outbox/'+second,record({id:second,transitionKey:'synthetic-second-contract'}));
  f.documents.set('users/'+UID+'/billing/subscription',{plan:'paid',status:'active'});
  const result=await f.runtime().runOnce();assert.equal(result.counts.failed_retryable,2);assert.equal(f.sentMime().length,1);assert.equal(f.calls.fetch.length,2);
  assert.equal(f.state().lastErrorCategory,'sending_limit');const other=f.documents.get('preview_billing_notification_outbox/'+second);
  assert.equal(other.lastErrorCategory,'local_sending_limit');assert.ok(other.nextAttemptAtMillis>=NOW+86400000);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/2030-01-01').count,1);
  assert.deepEqual(f.documents.get('preview_billing_notification_delivery_limits/_sender'),{untilMillis:NOW+86400000,category:'sending_limit'});
  assert.deepEqual(f.documents.get('users/'+UID+'/billing/subscription'),{plan:'paid',status:'active'});
});
test('rate-limit shared pause honors provider Retry-After instead of calling Gmail for the next job',async()=>{
  const f=fixture({sendStatus:429,sendBody:{error:{message:'User-rate limit exceeded'}},sendHeaders:{'Retry-After':'180'}}),second=hash('rate-limit-second-notification');
  f.documents.set('preview_billing_notification_outbox/'+second,record({id:second}));
  await f.runtime().runOnce();assert.equal(f.sentMime().length,1);
  assert.equal(f.documents.get('preview_billing_notification_delivery_limits/_sender').untilMillis,NOW+180000);
  assert.ok(f.documents.get('preview_billing_notification_outbox/'+second).nextAttemptAtMillis>=NOW+180000);
});
test('quota pause retains a provider deadline longer than the 24-hour minimum',async()=>{
  const f=fixture({sendStatus:429,sendBody:{error:{message:'Quota exceeded'}},sendHeaders:{'Retry-After':'172800'}});
  await f.runtime().runOnce();assert.equal(f.state().lastErrorCategory,'quota_exceeded');
  assert.equal(f.documents.get('preview_billing_notification_delivery_limits/_sender').untilMillis,NOW+172800000);
  assert.ok(f.state().nextAttemptAtMillis>=NOW+172800000);
});
test('cooldown storage failure preserves the original certain Gmail quota result',async()=>{
  const f=fixture({cooldownWriteFail:true,sendStatus:429,sendBody:{error:{message:'User-rate limit exceeded (Mail sending)'}}});
  await f.runtime().runOnce();assert.equal(f.state().status,'failed_retryable');assert.equal(f.state().lastErrorCategory,'sending_limit');
  assert.ok(f.state().nextAttemptAtMillis>=NOW+86400000);assert.equal(f.documents.has('preview_billing_notification_delivery_limits/_sender'),false);
});
test('a persisted sender cooldown blocks a later runtime invocation before OAuth',async()=>{
  const f=fixture();f.documents.set('preview_billing_notification_delivery_limits/_sender',{untilMillis:NOW+86400000,category:'sending_limit'});
  await f.runtime().runOnce();assert.equal(f.calls.fetch.length,0);assert.equal(f.state().status,'failed_retryable');assert.ok(f.state().nextAttemptAtMillis>=NOW+86400000);
  assert.equal(f.documents.has('preview_billing_contact_delivery_limits/2030-01-01'),false);
});
for(const extra of [{sendStatus:503},{sendThrow:true}])test('ambiguous provider result is quarantined without blind runtime retry '+Object.keys(extra),async()=>{
  const f=fixture(extra);await f.runtime().runOnce();assert.equal(f.state().status,'uncertain');assert.equal(f.sentMime().length,1);
  f.advance(86400000);assert.deepEqual(await f.runtime().runOnce(),{processed:0,counts:{}});assert.equal(f.sentMime().length,1);
});
test('loading actual notification runtime needs no Stripe or Admin SDK capability',()=>{
  const Module=require('node:module'),original=Module._load,attempted=[];
  try {
    Module._load=function(name,...args){if(name==='stripe'||name==='firebase-admin'||name.startsWith('firebase-admin/')){attempted.push(name);throw Error('Forbidden billing/mail capability import');}return original.call(this,name,...args);};
    const isolated=loadStarSource();assert.equal(typeof isolated('billingNotificationRuntime').createBillingNotificationRuntime,'function');assert.deepEqual(attempted,[]);
  } finally {Module._load=original;}
});
