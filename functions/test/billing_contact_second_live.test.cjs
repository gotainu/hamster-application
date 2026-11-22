'use strict';
// Synthetic max-two extension only. No credentials, network delivery or cloud access.
const {test}=require('node:test'),assert=require('node:assert/strict'),{createHash}=require('node:crypto');
const {loadStarSource,fakeFirestore}=require('./support/star_source_loader.cjs');
const load=loadStarSource(),{parseBillingNotificationMailConfig:parse,createBillingNotificationGmailSender:createSender}=load('billingNotificationGmail');
const {createProductionBillingContactRuntime,BILLING_CONTACT_LIVE_ORIGIN}=load('billingContactRuntime');
const {createLimitedLiveBillingContactReservation:reserveFactory,canRequestLimitedLiveBillingContact:canRequest,
  LIVE_BILLING_CONTACT_TEST_RESERVATION_PATH:SLOT1,LIVE_BILLING_CONTACT_TEST_SECOND_RESERVATION_PATH:SLOT2}=load('billingContactStore');
const {accountDeletionRef}=load('accountDeletion');
const hash=v=>createHash('sha256').update(v).digest('hex'),UID='synthetic-second-contact-owner',TO='synthetic-first@example.test',NEXT='synthetic-second@example.test',NOW=1800000000000;
const config=(max=1,recipient=TO)=>({enabled:true,environment:'live',from:'gotainu@gmail.com',clientId:'synthetic-live.apps.googleusercontent.com',
  clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token-only',allowedSubjectHashes:[hash(UID)],allowedRecipientHashes:[hash(recipient)],
  limitedContactTest:{expiresAtMillis:NOW+6*3600000,maxTotalSends:max}});
const first=()=>({purpose:'billing_contact_live_limited_test',schemaVersion:1,subjectHash:hash(UID),recipientHash:hash(TO),
  notificationIdHash:hash('synthetic-first'),reservedAtMillis:NOW-1000,expiresAtMillis:NOW-1});
const reservation=(notificationId='synthetic-second')=>({subjectHash:hash(UID),recipientHash:hash(NEXT),notificationIdHash:hash(notificationId),nowMillis:NOW,expiresAtMillis:NOW+1000});
const response=(body,status=200)=>new Response(JSON.stringify(body),{status});
function fixture(options={}) {
  const {db}=fakeFirestore();let now=NOW,raw=config(),limit=1,enabled=true;const calls={auth:0,reads:0,network:[]};
  const original=db.doc;db.doc=path=>{const r=original(path),get=r.get;r.get=async()=>{calls.reads++;return get.call(r);};return r;};
  const user={uid:UID,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-apple-subject'}]},
    token={uid:UID,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['synthetic-apple-subject']}}};
  db.documents.set('users/'+UID+'/owner_profiles/main',{displayName:'Synthetic'});db.documents.set('users/'+UID+'/pet_profiles/main_pet',{name:'Synthetic pet'});
  const runtime=createProductionBillingContactRuntime({db,auth:{verifyIdToken:async()=>{calls.auth++;return token;},getUser:async()=>user},
    enabled:()=>enabled,rawConfig:()=>raw,dailyLimit:()=>limit,now:()=>now,sleep:async()=>{},fetchRequest:async(url,init)=>{calls.network.push([url,init]);
      if(options.fetchRequest)return options.fetchRequest(url,init,calls);
      return response(url.includes('oauth2')?{access_token:'synthetic-access'}:{id:'synthetic-message'});}});
  const run=(op='status',body={})=>runtime.handle({method:'POST',path:'/'+op,headers:{origin:BILLING_CONTACT_LIVE_ORIGIN,'content-type':'application/json',authorization:'Bearer synthetic-token'},query:{},rawBody:Buffer.from(JSON.stringify(body)),body});
  const sends=()=>calls.network.filter(([url])=>url.includes('messages/send'));
  const proof=()=>{const mime=Buffer.from(JSON.parse(sends().at(-1)[1].body).raw,'base64url').toString('utf8');const text=Buffer.from(mime.split('Content-Transfer-Encoding: base64\r\n\r\n')[1].split('\r\n--')[0].replace(/\r\n/g,''),'base64').toString('utf8');return text.match(/#token=([A-Za-z0-9_-]{43})/)[1];};
  return {db,user,token,calls,run,sends,proof,now:()=>now,advance:ms=>now+=ms,setConfig:v=>raw=v,setLimit:v=>limit=v,setEnabled:v=>enabled=v};
}
test('explicit Live max2 is parsed immutably; max3, strings and Preview max2 are rejected',()=>{
  assert.equal(parse(config(2),'live').limitedContactTest.maxTotalSends,2);assert.ok(Object.isFrozen(parse(config(2),'live').limitedContactTest));
  for(const max of [0,3,100,'2',null,NaN])assert.throws(()=>parse(config(max),'live'));
  assert.throws(()=>parse({...config(2),environment:'preview'},'preview'));
  for(const key of ['allowedSubjectHashes','allowedRecipientHashes'])assert.throws(()=>parse({...config(2),[key]:[hash('one'),hash('two')]},'live'));
});
test('max2 with no first receipt or only a second slot cannot request or mutate pending state',async()=>{
  for(const secondOnly of [false,true]){const f=fixture();f.setConfig(config(2));f.setLimit(2);if(secondOnly)f.db.documents.set(SLOT2,{});
    assert.equal((await f.run('request',{email:TO})).status,429);assert.equal(f.db.writes.length,0);assert.equal(f.calls.network.length,0);assert.equal(f.db.documents.has('billing_contacts/'+UID),false);}
});
test('max1 cannot reallocate slot1 even when only slot2 remains',async()=>{
  const {db}=fakeFirestore();db.documents.set(SLOT2,{});assert.equal(await canRequest(db,UID,1,NOW),false);assert.equal(await reserveFactory(db,UID,1)(reservation()),false);assert.equal(db.writes.length,0);
});
for(const [label,patch] of Object.entries({wrongOwner:{subjectHash:hash('other')},wrongPurpose:{purpose:'other'},wrongSchema:{schemaVersion:2},invalidRecipient:{recipientHash:'bad'},invalidMessage:{notificationIdHash:'bad'},futureReserved:{reservedAtMillis:NOW+1},sameInstant:{reservedAtMillis:NOW},zeroReserved:{reservedAtMillis:0},invalidExpiry:{expiresAtMillis:NOW-1001},unsafeExpiry:{expiresAtMillis:8640000000000001},extraKey:{reset:true}}))
  test('max2 fails closed for first receipt '+label,async()=>{const {db}=fakeFirestore();db.documents.set(SLOT1,{...first(),...patch});assert.equal(await canRequest(db,UID,2,NOW),false);assert.equal(await reserveFactory(db,UID,2)(reservation()),false);assert.equal(db.writes.length,0);});
test('max2 validates original expired receipt, permits designated new recipient, and preserves slot1 exactly',async()=>{
  const {db}=fakeFirestore(),old=first();db.documents.set(SLOT1,old);assert.equal(await canRequest(db,UID,2,NOW),true);
  assert.equal(await reserveFactory(db,UID,2)(reservation()),true);assert.deepEqual(db.documents.get(SLOT1),old);
  const second=db.documents.get(SLOT2);assert.equal(second.recipientHash,hash(NEXT));assert.equal(second.subjectHash,old.subjectHash);assert.equal(second.previousNotificationIdHash,old.notificationIdHash);assert.equal(second.reservationOrdinal,2);
  assert.doesNotMatch(JSON.stringify(second),/synthetic|@|token=|Bearer/);assert.equal(db.writes.filter(([,p])=>p===SLOT1).length,0);
});
test('same old notification is refused without consuming slot2; trusted max cannot be raised through callback input',async()=>{
  const {db}=fakeFirestore();db.documents.set(SLOT1,first());assert.equal(await reserveFactory(db,UID,2)(reservation('synthetic-first')),false);assert.equal(db.documents.has(SLOT2),false);
  assert.equal(await reserveFactory(db,UID,1)({...reservation(),maxTotalSends:2}),false);assert.equal(db.documents.has(SLOT2),false);
  assert.throws(()=>reserveFactory(db,UID,3));
});
test('concurrent second reservations allocate exactly one slot2 and preserve existing first receipt',async()=>{
  const {db}=fakeFirestore(),old=first();db.documents.set(SLOT1,old);const results=await Promise.all([reserveFactory(db,UID,2)(reservation('synthetic-second-a')),reserveFactory(db,UID,2)(reservation('synthetic-second-b'))]);
  assert.deepEqual(results,[true,false]);assert.deepEqual(db.documents.get(SLOT1),old);assert.equal(db.writes.filter(([,p])=>p===SLOT2).length,1);
});
test('second slot remains spent across expiry/config/date changes and lowering then raising cap',async()=>{
  const {db}=fakeFirestore();db.documents.set(SLOT1,first());assert.equal(await reserveFactory(db,UID,2)(reservation()),true);
  for(const max of [1,2])assert.equal(await reserveFactory(db,UID,max)({...reservation('synthetic-third'),nowMillis:NOW+86400000,expiresAtMillis:NOW+86401000}),false);
  assert.equal(await canRequest(db,UID,2,NOW+86400000),false);assert.equal(db.writes.length,1);
});
test('deletion fence blocks second reservation',async()=>{const {db}=fakeFirestore();db.documents.set(SLOT1,first());db.documents.set(accountDeletionRef(db,UID).path,{status:'requested'});assert.equal(await reserveFactory(db,UID,2)(reservation()),false);assert.equal(db.documents.has(SLOT2),false);});
test('same-day second mail increments existing daily counters from1 to2 without resetting any history',async()=>{
  const f=fixture();assert.equal((await f.run('request',{email:TO})).status,200);const old=structuredClone(f.db.documents.get(SLOT1));f.advance(60001);f.setConfig(config(2));f.setLimit(2);
  assert.equal((await f.run('request',{email:TO})).status,200);assert.equal(f.sends().length,2);assert.deepEqual(f.db.documents.get(SLOT1),old);
  const day=new Date(NOW).toISOString().slice(0,10),owner='billing_notification_delivery_limits/'+day+'_'+hash(UID);
  assert.equal(f.db.documents.get('billing_notification_delivery_limits/'+day).count,2);assert.equal(f.db.documents.get(owner).count,2);
  assert.equal(f.db.documents.get('billing_contacts/'+UID).requestedAt.length,2);assert.equal((await f.run('confirm',{token:f.proof()})).body.canCheckout,true);
  f.advance(60001);const history=structuredClone(f.db.documents.get('billing_contacts/'+UID));assert.equal((await f.run('request',{email:TO})).status,429);assert.deepEqual(f.db.documents.get('billing_contacts/'+UID),history);assert.equal(f.sends().length,2);
  const reads=f.calls.reads,auth=f.calls.auth;f.setEnabled(false);assert.equal((await f.run('status')).status,503);assert.equal(f.calls.reads,reads);assert.equal(f.calls.auth,auth);
});
test('explicit new designated recipient is enforced before DB; original receipt keeps old recipient',async()=>{
  const f=fixture();await f.run('request',{email:TO});const old=structuredClone(f.db.documents.get(SLOT1));f.advance(60001);f.setConfig(config(2,NEXT));f.setLimit(2);
  const reads=f.calls.reads,writes=f.db.writes.length;assert.equal((await f.run('request',{email:TO})).status,403);assert.equal(f.calls.reads,reads);assert.equal(f.db.writes.length,writes);
  assert.equal((await f.run('request',{email:NEXT})).status,200);assert.equal(f.sends().length,2);assert.deepEqual(f.db.documents.get(SLOT1),old);assert.equal(f.db.documents.get(SLOT2).recipientHash,hash(NEXT));
});
test('max2 daily1 stays conservative; daily3 rejects before Auth/DB and request cannot inject a cap',async()=>{
  const f=fixture();f.db.documents.set(SLOT1,first());f.setConfig(config(2));assert.equal((await f.run('status')).status,200);
  const auth=f.calls.auth,reads=f.calls.reads;f.setLimit(3);assert.equal((await f.run('request',{email:TO})).status,503);assert.equal(f.calls.auth,auth);assert.equal(f.calls.reads,reads);
  f.setLimit(2);assert.equal((await f.run('request',{email:TO,maxTotalSends:3})).status,400);assert.equal(f.calls.auth,auth);assert.equal(f.calls.reads,reads);
});
test('second irreversible send timeout never permits another Gmail POST',async()=>{
  let sends=0;const f=fixture({fetchRequest:async url=>{if(url.includes('oauth2'))return response({access_token:'synthetic-access'});if(++sends===2)throw Error('synthetic unknown result');return response({id:'synthetic-first'});}});
  await f.run('request',{email:TO});f.advance(60001);f.setConfig(config(2));f.setLimit(2);assert.equal((await f.run('request',{email:TO})).body.code,'contact_delivery_unknown');assert.equal(f.sends().length,2);
  const pending=structuredClone(f.db.documents.get('billing_contacts/'+UID));f.advance(60001);assert.equal((await f.run('request',{email:TO})).status,429);assert.deepEqual(f.db.documents.get('billing_contacts/'+UID),pending);assert.equal(f.sends().length,2);
});
test('shared Gmail sender refuses original notification key before second POST and never reuses slot2',async()=>{
  const {db}=fakeFirestore();db.documents.set(SLOT1,first());const calls=[];const sender=createSender(parse(config(2,NEXT),'live'),{now:()=>new Date(NOW),reserveLimitedContactTest:reserveFactory(db,UID,2),fetchRequest:async url=>{calls.push(url);return response(url.includes('oauth2')?{access_token:'synthetic-access'}:{id:'synthetic-second'});}});
  const msg={notificationId:'synthetic-first',uid:UID,to:NEXT,subject:'Synthetic',text:'Synthetic',html:'<p>Synthetic</p>'};
  await assert.rejects(sender.send(msg));assert.equal(db.documents.has(SLOT2),false);assert.equal(calls.filter(url=>url.includes('messages/send')).length,0);
  await sender.send({...msg,notificationId:'synthetic-second'});await assert.rejects(sender.send({...msg,notificationId:'synthetic-second'}));assert.equal(calls.filter(url=>url.includes('messages/send')).length,1);
});
