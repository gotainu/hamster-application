'use strict';
// Budget transactions run only against an in-memory serializable database.
// No Firebase app, credentials, Gmail request or Stripe client is constructed.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const {createBillingNotificationBudget:createBudget,deferBillingNotificationSender:deferSender}=loadStarSource()('billingNotificationBudget');
const hash=v=>createHash('sha256').update(v).digest('hex');
const NOW=Date.UTC(2030,0,1,12),DAY='2030-01-01',UID='synthetic-budget-owner';
function fakeDb(){
  const documents=new Map(),writes=[],reads=[];let tail=Promise.resolve();
  const clone=v=>structuredClone(v),ref=path=>({path});
  const snapshot=r=>({exists:documents.has(r.path),data:()=>clone(documents.get(r.path)),get:key=>clone(documents.get(r.path)?.[key])});
  const db={doc:ref,async runTransaction(fn){const run=tail.then(async()=>{
    const pending=[];
    const value=await fn({get:async r=>{assert.equal(pending.length,0,'transaction reads must precede writes');reads.push(r.path);return snapshot(r);},
      set:(r,v)=>pending.push(['set',r.path,clone(v)]),create:(r,v)=>pending.push(['create',r.path,clone(v)])});
    for(const [op,path]of pending)if(op==='create')assert.equal(documents.has(path),false,'reservation create is unique');
    for(const [op,path,v]of pending){documents.set(path,v);writes.push([op,path,clone(v)]);}return value;
  });tail=run.catch(()=>{});return run;}};
  return {db,documents,writes,reads};
}
const input=(extra={})=>({uid:UID,notificationId:hash('synthetic-notification'),attemptId:'synthetic-attempt',nowMillis:NOW,...extra});
test('one reservation atomically writes a global slot, per-owner slot and private hash-only receipt',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);
  assert.deepEqual(await reserve(input()),{allowed:true});assert.equal(f.writes.length,3);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,1);
  assert.equal(f.documents.get('preview_billing_notification_delivery_limits/'+DAY+'_'+hash(UID)).count,1);
  assert.doesNotMatch(JSON.stringify(f.writes),new RegExp(UID+'|synthetic-notification|synthetic-attempt|@'));
  assert.ok(f.writes.every(([,path])=>path.startsWith('preview_billing_')));
});
test('same reservation is idempotent and consumes one daily slot',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);
  await Promise.all(Array.from({length:25},()=>reserve(input())));
  assert.equal(f.writes.length,3);assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,1);
});
test('an intact existing reservation stays usable at full quotas without charging twice',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);await reserve(input());
  f.documents.set('preview_billing_contact_delivery_limits/'+DAY,{count:10});
  f.documents.set('preview_billing_notification_delivery_limits/'+DAY+'_'+hash(UID),{count:5});
  const count=f.writes.length;assert.equal((await reserve(input({nowMillis:NOW+1000}))).allowed,true);assert.equal(f.writes.length,count);
});
for(const receipt of [{},{environment:'live',reservedAtMillis:NOW},{environment:'preview'},
  {environment:'preview',reservedAtMillis:NaN},{environment:'preview',reservedAtMillis:NOW+1},
  {environment:'preview',reservedAtMillis:Date.UTC(2029,11,31,23,59,59)},
  {environment:'preview',reservedAtMillis:NOW,unknown:'unexpected'}])
  test('malformed existing reservation '+JSON.stringify(receipt)+' cannot bypass quota checks',async()=>{
    const f=fakeDb(),reserve=createBudget(f.db,'preview',10);await reserve(input());
    const key='preview_billing_notification_delivery_limits/'+DAY+'_'+hash(input().notificationId+':'+input().attemptId);
    f.documents.set(key,receipt);const before=cloneDocuments(f.documents),count=f.writes.length;
    await assert.rejects(reserve(input()));assert.equal(f.writes.length,count);assert.deepEqual(cloneDocuments(f.documents),before);
  });
function cloneDocuments(documents){return structuredClone([...documents]);}
for(const target of ['global','owner'])for(const bad of [undefined,-1,'1',NaN])
  test('existing receipt does not skip a malformed '+target+' counter '+String(bad),async()=>{
    const f=fakeDb(),reserve=createBudget(f.db,'preview',10);await reserve(input());
    const path=target==='global'?'preview_billing_contact_delivery_limits/'+DAY:'preview_billing_notification_delivery_limits/'+DAY+'_'+hash(UID);
    f.documents.set(path,{count:bad});const count=f.writes.length;
    await assert.rejects(reserve(input()));assert.equal(f.writes.length,count);assert.deepEqual(f.documents.get(path),{count:bad});
  });
for(const target of ['global','owner'])test('existing receipt with missing '+target+' accounting blocks without resetting state',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);await reserve(input());
  const path=target==='global'?'preview_billing_contact_delivery_limits/'+DAY:'preview_billing_notification_delivery_limits/'+DAY+'_'+hash(UID);
  f.documents.delete(path);const count=f.writes.length;
  await assert.rejects(reserve(input()));assert.equal(f.writes.length,count);assert.equal(f.documents.has(path),false);
});
test('a distinct retry attempt consumes its own conservative reservation',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);
  await reserve(input());await reserve(input({attemptId:'synthetic-retry-attempt'}));
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,2);
});
test('concurrent Preview reservations never exceed the five-message per-owner cap',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);
  const results=await Promise.all(Array.from({length:20},(_,i)=>reserve(input({notificationId:hash('synthetic-'+i)}))));
  assert.equal(results.filter(r=>r.allowed).length,5);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,5);
  assert.equal(f.documents.get('preview_billing_notification_delivery_limits/'+DAY+'_'+hash(UID)).count,5);
  for(const result of results.filter(r=>!r.allowed))assert.equal(result.nextAttemptAtMillis,Date.UTC(2030,0,2));
});
test('different Preview owners share one atomic ten-message global allowance',async()=>{
  const f=fakeDb(),a=createBudget(f.db,'preview',10),b=createBudget(f.db,'preview',10);
  const results=await Promise.all(Array.from({length:30},(_,i)=>(i%2?a:b)(input({uid:'synthetic-owner-'+i,notificationId:hash('notification-'+i)}))));
  assert.equal(results.filter(r=>r.allowed).length,10);assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,10);
  assert.equal(f.writes.length,30);
});
test('established contact-mail global counter is shared without resetting its purpose or count',async()=>{
  const f=fakeDb();f.documents.set('preview_billing_contact_delivery_limits/'+DAY,{purpose:'billing_contact_preview',count:9,updatedAt:NOW-1000});
  const reserve=createBudget(f.db,'preview',10);
  assert.deepEqual(await reserve(input()),{allowed:true});
  const before=f.writes.length;assert.equal((await reserve(input({notificationId:hash('another-notification')}))).allowed,false);
  assert.equal(f.writes.length,before);assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,10);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).purpose,'billing_contact_preview');
});
test('full contact-mail quota blocks notification delivery before any budget write',async()=>{
  const f=fakeDb();f.documents.set('preview_billing_contact_delivery_limits/'+DAY,{count:10});
  assert.equal((await createBudget(f.db,'preview',10)(input())).allowed,false);assert.equal(f.writes.length,0);
});
for(const target of ['global','owner'])for(const count of [undefined,null,-1,1.2,'1',NaN,Infinity])
  test('malformed '+target+' counter '+String(count)+' fails closed',async()=>{
    const f=fakeDb(),path=target==='global'?'preview_billing_contact_delivery_limits/'+DAY:'preview_billing_notification_delivery_limits/'+DAY+'_'+hash(UID);
    f.documents.set(path,{count});await assert.rejects(createBudget(f.db,'preview',10)(input()));assert.equal(f.writes.length,0);
  });
test('UTC daily rollover uses new local reservation documents and preserves old counters',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);
  f.documents.set('preview_billing_contact_delivery_limits/'+DAY,{count:10});
  assert.equal((await reserve(input())).allowed,false);
  const tomorrow=Date.UTC(2030,0,2,0,0,1);assert.equal((await reserve(input({nowMillis:tomorrow}))).allowed,true);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,10);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/2030-01-02').count,1);
});
test('Live uses only explicitly budgeted production counters, isolated from Preview counts',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'live',2);
  f.documents.set('preview_billing_contact_delivery_limits/'+DAY,{count:10});
  const results=await Promise.all(Array.from({length:4},(_,i)=>reserve(input({uid:'synthetic-live-'+i,notificationId:hash('live-'+i)}))));
  assert.equal(results.filter(r=>r.allowed).length,2);assert.equal(f.documents.get('billing_notification_delivery_limits/'+DAY).count,2);
  assert.ok(f.writes.every(([,path])=>path.startsWith('billing_notification_delivery_limits/')));
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,10);
});
test('shared sender cooldown blocks every owner without reserving or resetting quota',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);
  await deferSender(f.db,'preview',{nowMillis:NOW,category:'sending_limit',delayMillis:86400000});
  const count=f.writes.length;
  const values=await Promise.all(Array.from({length:10},(_,i)=>reserve(input({uid:'synthetic-owner-'+i,notificationId:hash('cooldown-'+i)}))));
  assert.ok(values.every(v=>v.allowed===false && v.nextAttemptAtMillis===NOW+86400000));assert.equal(f.writes.length,count);
  assert.equal(f.documents.has('preview_billing_contact_delivery_limits/'+DAY),false);
  assert.deepEqual(f.documents.get('preview_billing_notification_delivery_limits/_sender'),{untilMillis:NOW+86400000,category:'sending_limit'});
});
test('sender cooldown also blocks reuse of a previously reserved delivery slot',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);await reserve(input());
  await deferSender(f.db,'preview',{nowMillis:NOW,category:'rate_limited',delayMillis:60000});
  const count=f.writes.length;assert.deepEqual(await reserve(input()),{allowed:false,nextAttemptAtMillis:NOW+60000});assert.equal(f.writes.length,count);
  assert.equal(f.documents.get('preview_billing_contact_delivery_limits/'+DAY).count,1);
});
test('concurrent cooldown updates retain the maximum deadline and never shorten an account pause',async()=>{
  const f=fakeDb();
  await Promise.all([deferSender(f.db,'preview',{nowMillis:NOW,category:'rate_limited',delayMillis:60000}),
    deferSender(f.db,'preview',{nowMillis:NOW,category:'quota_exceeded',delayMillis:86400000}),
    deferSender(f.db,'preview',{nowMillis:NOW,category:'rate_limited',delayMillis:120000})]);
  assert.deepEqual(f.documents.get('preview_billing_notification_delivery_limits/_sender'),{untilMillis:NOW+86400000,category:'quota_exceeded'});
  const count=f.writes.length;await deferSender(f.db,'preview',{nowMillis:NOW+1000,category:'rate_limited',delayMillis:60000});assert.equal(f.writes.length,count);
});
test('expired sender cooldown permits a new reservation without deleting historical pause metadata',async()=>{
  const f=fakeDb(),reserve=createBudget(f.db,'preview',10);await deferSender(f.db,'preview',{nowMillis:NOW,category:'rate_limited',delayMillis:60000});
  assert.equal((await reserve(input({nowMillis:NOW+59999}))).allowed,false);
  assert.equal((await reserve(input({nowMillis:NOW+60000}))).allowed,true);
  assert.equal(f.documents.get('preview_billing_notification_delivery_limits/_sender').untilMillis,NOW+60000);
});
test('cooldowns are mode-specific and contain only safe category/deadline fields',async()=>{
  const f=fakeDb();await deferSender(f.db,'preview',{nowMillis:NOW,category:'sending_limit',delayMillis:86400000});
  assert.equal((await createBudget(f.db,'live',10)(input())).allowed,true);
  await deferSender(f.db,'live',{nowMillis:NOW,category:'quota_exceeded',delayMillis:172800000});
  assert.equal(f.documents.get('preview_billing_notification_delivery_limits/_sender').untilMillis,NOW+86400000);
  assert.equal(f.documents.get('billing_notification_delivery_limits/_sender').untilMillis,NOW+172800000);
  assert.doesNotMatch(JSON.stringify([...f.documents]),/@|clientSecret|refreshToken|gotainu/);
});
for(const state of [{},{untilMillis:0,category:'rate_limited'},{untilMillis:NaN,category:'quota_exceeded'},
  {untilMillis:NOW+1000,category:'authorization_revoked'},{untilMillis:NOW+1000,category:'rate_limited',email:'forbidden@example.test'}])
  test('malformed shared sender cooldown fails closed without quota mutation '+JSON.stringify(state),async()=>{
    const f=fakeDb();f.documents.set('preview_billing_notification_delivery_limits/_sender',state);
    await assert.rejects(createBudget(f.db,'preview',10)(input()));assert.equal(f.writes.length,0);
    await assert.rejects(deferSender(f.db,'preview',{nowMillis:NOW,category:'rate_limited',delayMillis:60000}));assert.equal(f.writes.length,0);
  });
for(const extra of [{nowMillis:0},{nowMillis:1.5},{category:'authorization_revoked'},{delayMillis:0},{delayMillis:-1},{delayMillis:NaN},{delayMillis:Number.MAX_SAFE_INTEGER}])
  test('invalid cooldown request '+JSON.stringify(extra)+' cannot access storage',async()=>{
    const f=fakeDb();await assert.rejects(deferSender(f.db,'preview',{nowMillis:NOW,category:'rate_limited',delayMillis:60000,...extra}));
    assert.equal(f.reads.length,0);assert.equal(f.writes.length,0);
  });
test('unknown cooldown environment cannot address another namespace',async()=>{
  const f=fakeDb();await assert.rejects(deferSender(f.db,'unknown',{nowMillis:NOW,category:'rate_limited',delayMillis:60000}));assert.equal(f.reads.length,0);assert.equal(f.writes.length,0);
});
for(const [mode,limit]of [['preview',undefined],['preview',5],['preview',11],['live',undefined],['live',0],['live',101],['live',1.5],['unknown',10]])
  test('missing or unsafe explicit budget '+mode+'/'+String(limit)+' rejects before database activity',()=>{
    const f=fakeDb();assert.throws(()=>createBudget(f.db,mode,limit));assert.equal(f.writes.length,0);assert.equal(f.reads.length,0);
  });
for(const extra of [{uid:''},{uid:'bad/path'},{notificationId:'not-hash'},{attemptId:''},{attemptId:'bad\nattempt'},
  {nowMillis:0},{nowMillis:NaN},{nowMillis:1.5}])test('invalid reservation input '+Object.keys(extra).join(',')+' rejects without access',async()=>{
  const f=fakeDb();await assert.rejects(createBudget(f.db,'preview',10)(input(extra)));assert.equal(f.reads.length,0);assert.equal(f.writes.length,0);
});
