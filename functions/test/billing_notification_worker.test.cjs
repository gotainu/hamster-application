'use strict';
// Synthetic Auth/billing facts, in-memory transactions and captured delivery
// only. No Gmail, Stripe, Firebase app, credentials or remote service is used.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource();
const {createBillingNotificationWorker,validateBillingNotificationWorkerConfig}=load('billingNotificationWorker');
const {createBillingNotificationStore,BILLING_NOTIFICATION_OUTBOX,PREVIEW_BILLING_NOTIFICATION_OUTBOX}=load('billingNotificationStore');
const HASH=v=>createHash('sha256').update(v).digest('hex');
const NOW=Date.UTC(2030,0,1),UID='synthetic_notification_owner',ID=HASH('synthetic-notification');
const clone=v=>structuredClone(v);
const deferred=()=>{let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};};
async function until(fn){for(let i=0;i<100;i++){if(fn())return;await new Promise(setImmediate);}assert.fail('synthetic operation did not start');}
function fakeDb(){
  const docs=new Map(),writes=[];let tail=Promise.resolve();
  const ref=p=>({path:p,id:p.split('/').at(-1)});
  const snap=r=>({exists:docs.has(r.path),id:r.id,data:()=>clone(docs.get(r.path))});
  const db={doc:ref,collection:name=>({where(field,op,value){assert.equal(field,'dispatchAtMillis');assert.equal(op,'<=');let cap=20;return {
    orderBy(field2,direction){assert.equal(field2,field);assert.equal(direction,'asc');return this;},limit(n){cap=n;return this;},async get(){
      const selected=[...docs].filter(([p,v])=>p.startsWith(name+'/')&&!p.slice(name.length+1).includes('/')&&typeof v[field]==='number'&&v[field]<=value)
        .sort((a,b)=>a[1][field]-b[1][field]||a[0].localeCompare(b[0])).slice(0,cap);
      return {docs:selected.map(([p])=>snap(ref(p)))};
    }};}}),async runTransaction(fn){
      const run=tail.then(async()=>{const pending=[];const result=await fn({get:async r=>{assert.equal(pending.length,0);return snap(r);},set:(r,value)=>pending.push([r.path,clone(value)])});
        for(const [p,v]of pending){docs.set(p,v);writes.push([p,clone(v)]);}return result;});tail=run.catch(()=>{});return run;
    }};
  return {db,docs,writes};
}
function record(extra={}){return {id:ID,schemaVersion:1,environment:'preview',trustedSource:'preview_fixture',templateVersion:'billing-v1',
  type:'contract_registered',firebaseUid:UID,transitionKey:'synthetic-transition',eventHash:HASH('synthetic-event'),snapshot:{amount:550},
  status:'pending',createdAtMillis:NOW,attempts:0,nextAttemptAtMillis:NOW,dispatchAtMillis:NOW,...extra};}
function fixture(options={}){
  const f=fakeDb();let clock=NOW,serial=0;
  const environment=options.environment??'preview',collection=environment==='live'?BILLING_NOTIFICATION_OUTBOX:PREVIEW_BILLING_NOTIFICATION_OUTBOX;
  const path=collection+'/'+ID;
  f.docs.set(path,record({environment,trustedSource:environment==='live'?'stripe_webhook':'preview_fixture',...options.record}));
  const store=createBillingNotificationStore(f.db,environment),calls={recipient:[],render:[],send:[],budget:[],allow:[]};
  const dependencies={config:{environment,maxAttempts:5,baseDelayMillis:60000,maxDelayMillis:3600000,leaseMillis:120000,batchSize:5,...options.config},
    store,resolveRecipient:async uid=>{calls.recipient.push(uid);return {email:'synthetic@example.test',source:'auth_verified'};},
    render:n=>{calls.render.push(clone(n));return {subject:'【HamCare】合成通知',text:'月額550円',html:'<p>月額550円</p>',templateVersion:'billing-v1'};},
    send:async input=>{calls.send.push(input);return {messageIdHash:HASH('synthetic-provider-message')};},
    reserveDelivery:async input=>{calls.budget.push(input);return {allowed:true};},
    allowedRecipient:(uid,email)=>{calls.allow.push([uid,email]);return true;},now:()=>clock,randomToken:()=> 'synthetic-lease-'+(++serial)};
  f.path=path;f.collection=collection;f.store=store;f.calls=calls;f.dependencies=dependencies;
  f.worker=()=>createBillingNotificationWorker(dependencies);f.state=()=>clone(f.docs.get(path));f.advance=n=>{clock+=n;};f.time=()=>clock;
  return f;
}
test('success records only reference/source and provider hash, then a repeated invocation does not send',async()=>{
  const f=fixture();const result=await f.worker().runOnce();assert.equal(result.counts.sent,1);assert.equal(f.calls.send.length,1);
  const state=f.state();assert.equal(state.status,'sent');assert.equal(state.attempts,1);assert.equal(state.recipientSource,'auth_verified');
  assert.match(state.recipientReference,/^[a-f0-9]{64}$/);assert.equal(state.sentAtMillis,NOW);assert.equal(state.dispatchAtMillis,undefined);
  assert.equal(state.leaseToken,undefined);assert.equal(state.nextAttemptAtMillis,undefined);
  assert.doesNotMatch(JSON.stringify(f.writes),/synthetic@example\.test|月額550円|合成通知/);
  assert.deepEqual(await f.worker().runOnce(),{processed:0,counts:{}});assert.equal(f.calls.send.length,1);
  assert.ok(f.writes.every(([p])=>p.startsWith(PREVIEW_BILLING_NOTIFICATION_OUTBOX+'/')));
});
for(const type of ['contract_registered','payment_success','payment_failed','cancel_reserved','resumed','canceled'])test('semantic notification '+type+' reaches renderer once',async()=>{
  const f=fixture({record:{type}});await f.worker().runOnce();assert.equal(f.calls.render[0].type,type);assert.equal(f.calls.send.length,1);
});
test('separate simultaneous workers use one durable send intent',async()=>{
  const f=fixture();await Promise.all([f.worker().runOnce(),f.worker().runOnce()]);assert.equal(f.calls.send.length,1);assert.equal(f.state().status,'sent');
});
test('expired sending lease is quarantined, late matching positive receipt may finish without resend',async()=>{
  const f=fixture(),wait=deferred();f.dependencies.send=async input=>{f.calls.send.push(input);await wait.promise;return {messageIdHash:HASH('late-message')};};
  const first=f.worker().runOnce();await until(()=>f.calls.send.length===1);assert.equal(f.state().status,'sending');
  f.advance(120000);const second=await f.worker().runOnce();assert.equal(second.counts.uncertain,1);assert.equal(f.state().status,'uncertain');
  assert.equal(f.calls.send.length,1);assert.equal(f.state().dispatchAtMillis,undefined);wait.resolve();await first;
  assert.equal(f.state().status,'sent');assert.equal(f.calls.send.length,1);
});
test('expired pre-send claim can be recovered and stale owner cannot send',async()=>{
  const f=fixture(),wait=deferred();let count=0;f.dependencies.resolveRecipient=async uid=>{f.calls.recipient.push(uid);if(++count===1)await wait.promise;return {email:'synthetic@example.test',source:'auth_verified'};};
  const first=f.worker().runOnce();await until(()=>f.calls.recipient.length===1);f.advance(120000);
  await f.worker().runOnce();assert.equal(f.calls.send.length,1);wait.resolve();await first;
  assert.equal(f.calls.send.length,1);assert.equal(f.state().attempts,2);assert.equal(f.state().status,'sent');
});
for(const recipient of [null,{email:'not-email',source:'auth_verified'},{email:'synthetic@example.test',source:'unverified'}])test('missing or invalid verified recipient blocks without retry '+JSON.stringify(recipient),async()=>{
  const f=fixture();f.dependencies.resolveRecipient=async()=>recipient;await f.worker().runOnce();assert.equal(f.state().status,'blocked_no_verified_contact');
  assert.equal(f.calls.send.length,0);assert.equal(f.calls.budget.length,0);assert.equal(f.state().dispatchAtMillis,undefined);
  f.advance(86400000);await f.worker().runOnce();assert.equal(f.state().attempts,1);
});
for(const source of ['auth_verified','apple_relay','user_supplied'])test('server-resolved recipient source '+source+' is retained as a reference',async()=>{
  const f=fixture();f.dependencies.resolveRecipient=async()=>({email:'synthetic@private.icloud.com',source});await f.worker().runOnce();assert.equal(f.state().recipientSource,source);assert.equal(f.calls.send.length,1);
});
test('Preview allowlist denies another recipient before budget or send',async()=>{
  const f=fixture();f.dependencies.allowedRecipient=()=>false;await f.worker().runOnce();assert.equal(f.state().status,'blocked_recipient_not_allowed');assert.equal(f.calls.send.length,0);assert.equal(f.calls.budget.length,0);
});
test('unexpected truthy allowlist values cannot authorize delivery',async()=>{
  const f=fixture();f.dependencies.allowedRecipient=()=>Promise.resolve(true);await f.worker().runOnce();
  assert.equal(f.state().status,'blocked_recipient_not_allowed');assert.equal(f.calls.send.length,0);
});
for(const patch of [{schemaVersion:2},{environment:'live'},{trustedSource:'untrusted_client'},{templateVersion:'unknown'},{firebaseUid:'bad/uid'},
  {id:HASH('another')},{eventHash:'not-hash'},{type:'metadata_changed'},{snapshot:null},{attempts:-1},{status:'unknown'}])test('invalid outbox cannot send '+JSON.stringify(patch),async()=>{
  const f=fixture({record:patch});await f.worker().runOnce();assert.equal(f.state().status,'blocked_invalid_notification');assert.equal(f.calls.send.length,0);
});
test('Live refuses Preview fixtures even in the Live collection',async()=>{
  const f=fixture({environment:'live',record:{trustedSource:'preview_fixture'}});await f.worker().runOnce();assert.equal(f.state().status,'blocked_invalid_notification');assert.equal(f.calls.send.length,0);
});
test('Live store accesses only the production outbox',async()=>{
  const f=fixture({environment:'live'});f.docs.set(PREVIEW_BILLING_NOTIFICATION_OUTBOX+'/'+HASH('other'),record({id:HASH('other')}));
  await f.worker().runOnce();assert.equal(f.calls.send.length,1);assert.ok(f.writes.every(([p])=>p.startsWith(BILLING_NOTIFICATION_OUTBOX+'/')));
});
test('no default retry settings or Preview allowlist is silently inferred',()=>{
  const f=fixture();for(const field of ['maxAttempts','baseDelayMillis','maxDelayMillis','leaseMillis','batchSize']){
    const c={...f.dependencies.config};delete c[field];assert.throws(()=>validateBillingNotificationWorkerConfig(c));
  }
  assert.throws(()=>validateBillingNotificationWorkerConfig({...f.dependencies.config,maxAttempts:0}));
  assert.throws(()=>validateBillingNotificationWorkerConfig({...f.dependencies.config,batchSize:21}));
});
test('Preview without an allowlist or global budget fails before queue reads',()=>{
  const f=fixture();delete f.dependencies.allowedRecipient;assert.throws(()=>f.worker(),/unavailable/);
  f.dependencies.allowedRecipient=()=>true;delete f.dependencies.reserveDelivery;assert.throws(()=>f.worker(),/unavailable/);assert.equal(f.writes.length,0);
});
test('explicit 429 refusal retries exponentially and does not poll while deferred',async()=>{
  const f=fixture();f.dependencies.send=async input=>{f.calls.send.push(input);throw {category:'rate_limited',delivery:'not_sent',retryable:true};};
  await f.worker().runOnce();assert.equal(f.state().status,'failed_retryable');assert.equal(f.state().nextAttemptAtMillis,NOW+60000);
  await f.worker().runOnce();assert.equal(f.calls.send.length,1);f.advance(60000);await f.worker().runOnce();assert.equal(f.state().nextAttemptAtMillis,f.time()+120000);
  f.advance(120000);f.dependencies.send=async input=>{f.calls.send.push(input);return {messageIdHash:HASH('retry-success')};};
  await f.worker().runOnce();assert.equal(f.state().status,'sent');assert.equal(f.state().attempts,3);
});
for(const category of ['quota_exceeded','sending_limit'])test(category+' waits at least a rolling day',async()=>{
  const f=fixture();f.dependencies.send=async()=>{throw {category,delivery:'not_sent',retryable:true,retryAfterMillis:1000};};await f.worker().runOnce();
  assert.equal(f.state().nextAttemptAtMillis,NOW+86400000);assert.equal(f.state().status,'failed_retryable');
});
test('provider Retry-After may extend beyond a day without a burst loop',async()=>{
  const f=fixture();f.dependencies.send=async()=>{throw {category:'quota_exceeded',delivery:'not_sent',retryable:true,retryAfterMillis:2*86400000};};
  await f.worker().runOnce();assert.equal(f.state().nextAttemptAtMillis,NOW+2*86400000);
});
test('unrepresentable provider retry schedule becomes an operational failure',async()=>{
  const f=fixture();f.dependencies.send=async()=>{throw {category:'rate_limited',delivery:'not_sent',retryable:true,retryAfterMillis:Number.MAX_SAFE_INTEGER};};
  await f.worker().runOnce();assert.equal(f.state().status,'failed_permanent');assert.equal(f.state().lastErrorCategory,'retry_schedule_invalid');
});
test('attempt cap terminates safe retries',async()=>{
  const f=fixture({config:{maxAttempts:3}});f.dependencies.send=async input=>{f.calls.send.push(input);throw {category:'oauth_temporary',delivery:'not_sent',retryable:true};};
  for(const advance of [0,60000,120000]){f.advance(advance);await f.worker().runOnce();}
  assert.equal(f.state().status,'failed_permanent');assert.equal(f.state().lastErrorCategory,'attempt_limit');assert.equal(f.calls.send.length,3);
  f.advance(86400000);await f.worker().runOnce();assert.equal(f.calls.send.length,3);
});
for(const category of ['authorization_revoked','authorization_failed','invalid_recipient','request_invalid','gmail_permanent','configuration_invalid'])test('permanent '+category+' does not retry',async()=>{
  const f=fixture();f.dependencies.send=async()=>{throw {category,delivery:'not_sent',retryable:false};};await f.worker().runOnce();assert.equal(f.state().status,'failed_permanent');assert.equal(f.state().lastErrorCategory,category);
});
for(const failure of [{category:'gmail_temporary',delivery:'uncertain',retryable:false},{category:'delivery_uncertain',delivery:'uncertain',retryable:false},new Error('synthetic@example.test secret-provider-body')])test('ambiguous delivery is never automatically resent '+String(failure.category),async()=>{
  const f=fixture();f.dependencies.send=async input=>{f.calls.send.push(input);throw failure;};await f.worker().runOnce();assert.equal(f.state().status,'uncertain');
  assert.equal(f.state().dispatchAtMillis,undefined);f.advance(86400000);await f.worker().runOnce();assert.equal(f.calls.send.length,1);
  assert.doesNotMatch(JSON.stringify(f.writes),/secret-provider-body|synthetic@example\.test/);
});
test('malformed success receipt is uncertain, not a retry',async()=>{
  const f=fixture();f.dependencies.send=async()=>({messageIdHash:'raw-provider-id'});await f.worker().runOnce();assert.equal(f.state().status,'uncertain');
});
test('failure before send intent safely retries without mailing',async()=>{
  const f=fixture();f.dependencies.resolveRecipient=async()=>{throw new Error('private-contact-error');};await f.worker().runOnce();assert.equal(f.state().status,'failed_retryable');assert.equal(f.calls.send.length,0);assert.doesNotMatch(JSON.stringify(f.writes),/private-contact-error/);
});
test('recipient backend outages also reach the finite attempt cap',async()=>{
  const f=fixture({config:{maxAttempts:1}});f.dependencies.resolveRecipient=async()=>{throw new Error();};
  const result=await f.worker().runOnce();assert.equal(f.state().status,'failed_permanent');assert.equal(result.counts.failed_permanent,1);assert.equal(f.calls.send.length,0);
});
test('budget denial defers without Gmail or a sending intent',async()=>{
  const f=fixture();f.dependencies.reserveDelivery=async()=>({allowed:false,nextAttemptAtMillis:NOW+86400000});await f.worker().runOnce();
  assert.equal(f.state().status,'failed_retryable');assert.equal(f.state().nextAttemptAtMillis,NOW+86400000);assert.equal(f.calls.send.length,0);
  assert.equal(f.writes.some(([,v])=>v.status==='sending'),false);
});
test('budget backend failure does not send and does not expose its error',async()=>{
  const f=fixture();f.dependencies.reserveDelivery=async()=>{throw new Error('private-budget-error');};await f.worker().runOnce();assert.equal(f.state().status,'failed_retryable');assert.equal(f.calls.send.length,0);assert.doesNotMatch(JSON.stringify(f.writes),/private-budget-error/);
});
test('renderer failure is a blocked invalid notification with no provider call',async()=>{
  const f=fixture();f.dependencies.render=()=>{throw new Error('private-render-error');};await f.worker().runOnce();assert.equal(f.state().status,'blocked_invalid_notification');assert.equal(f.calls.send.length,0);
});
test('crash recording a positive send result leaves an uncertain non-resendable record',async()=>{
  const f=fixture(),original=f.store.finish;let fail=true;f.dependencies.store={...f.store,finish:async input=>{
    if(input.outcome.status==='sent'&&fail){fail=false;throw new Error('synthetic-write-failure');}return original(input);
  }};
  await f.worker().runOnce();assert.equal(f.state().status,'uncertain');assert.equal(f.calls.send.length,1);f.advance(86400000);await f.worker().runOnce();assert.equal(f.calls.send.length,1);
});
test('lost response after sent commit cannot overwrite the confirmed terminal state',async()=>{
  const f=fixture(),original=f.store.finish;f.dependencies.store={...f.store,finish:async input=>{const result=await original(input);if(input.outcome.status==='sent')throw new Error('commit-response-lost');return result;}};
  await f.worker().runOnce();assert.equal(f.state().status,'sent');assert.equal(f.calls.send.length,1);await f.worker().runOnce();assert.equal(f.calls.send.length,1);
});
test('malformed queue results stop before processing arbitrary document IDs',async()=>{
  const f=fixture();f.dependencies.store={...f.store,listDue:async()=>['not-a-document-hash']};await assert.rejects(f.worker().runOnce(),/unavailable/);assert.equal(f.calls.send.length,0);
});
test('batch bound prevents unbounded list fanout',async()=>{
  const f=fixture({config:{batchSize:2}});f.docs.set(f.collection+'/'+HASH('second'),record({id:HASH('second')}));f.docs.set(f.collection+'/'+HASH('third'),record({id:HASH('third')}));
  const result=await f.worker().runOnce();assert.equal(result.processed,2);assert.equal(f.calls.send.length,2);
});
test('terminal sent cannot be overwritten by a stale owner or converted into a retry',async()=>{
  const f=fixture();await f.worker().runOnce();const before=f.state();const result=await f.store.finish({id:ID,leaseToken:'stale-owner',attemptId:'stale-attempt',outcome:{status:'failed_retryable',atMillis:NOW,nextAttemptAtMillis:NOW+60000,lastErrorCategory:'rate_limited'}});
  assert.equal(result,false);assert.deepEqual(f.state(),before);
});
test('stale terminal dispatch metadata is removed rather than starving the scan',async()=>{
  const f=fixture({record:{status:'sent'}});await f.worker().runOnce();assert.equal(f.state().status,'sent');assert.equal(f.state().dispatchAtMillis,undefined);assert.equal(f.calls.send.length,0);
});
test('fractional due schedule is blocked as corrupt instead of repeatedly scanned',async()=>{
  const f=fixture({record:{dispatchAtMillis:NOW-0.5}});await f.worker().runOnce();assert.equal(f.state().status,'blocked_invalid_notification');assert.equal(f.state().lastErrorCategory,'schedule_invalid');assert.equal(f.calls.send.length,0);
});
test('cross-environment claim and invalid paths are rejected without writes',async()=>{
  const f=fixture();await assert.rejects(f.store.claim({id:ID,environment:'live',leaseToken:'owner',attemptId:'attempt',nowMillis:NOW,leaseUntilMillis:NOW+120000,maxAttempts:5}));
  await assert.rejects(f.store.claim({id:'users/synthetic/billing/subscription',environment:'preview',leaseToken:'owner',attemptId:'attempt',nowMillis:NOW,leaseUntilMillis:NOW+120000,maxAttempts:5}));assert.equal(f.writes.length,0);
});
