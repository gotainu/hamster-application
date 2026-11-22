'use strict';
// Synthetic identities, OAuth and Firestore only; never reads credentials or sends mail.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {loadStarSource,fakeFirestore}=require('./support/star_source_loader.cjs');
const load=loadStarSource();
const {parseBillingNotificationMailConfig:parse,createBillingNotificationGmailSender:createSender}=load('billingNotificationGmail');
const {createProductionBillingContactRuntime,BILLING_CONTACT_LIVE_ORIGIN}=load('billingContactRuntime');
const {createLimitedLiveBillingContactReservation,LIVE_BILLING_CONTACT_TEST_RESERVATION_PATH:SLOT}=load('billingContactStore');
const hash=v=>createHash('sha256').update(v).digest('hex');
const UID='synthetic-limited-contact-owner',TO='synthetic-recipient@example.test',NOW=1800000000000;
const config=()=>({enabled:true,environment:'live',from:'gotainu@gmail.com',clientId:'synthetic-live.apps.googleusercontent.com',
  clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token-only',allowedSubjectHashes:[hash(UID)],allowedRecipientHashes:[hash(TO)],
  limitedContactTest:{expiresAtMillis:NOW+6*60*60*1000,maxTotalSends:1}});
const response=(body={},status=200)=>new Response(JSON.stringify(body),{status});
function fixture(options={}) {
  const {db}=fakeFirestore();let now=NOW,raw=config(),enabled=true,dailyLimit=1;
  const calls={auth:0,reads:0,network:[],sleep:[]};const originalDoc=db.doc;
  db.doc=path=>{const ref=originalDoc(path),get=ref.get;ref.get=async()=>{calls.reads++;return get.call(ref);};return ref;};
  const user={uid:UID,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-apple-subject'}]};
  const token={uid:UID,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['synthetic-apple-subject']}}};
  db.documents.set('users/'+UID+'/owner_profiles/main',{displayName:'Synthetic'});
  db.documents.set('users/'+UID+'/pet_profiles/main_pet',{name:'Synthetic pet'});
  const fetchRequest=async(url,init)=>{calls.network.push([url,init]);if(options.fetchRequest)return options.fetchRequest(url,init,calls);
    return response(url.includes('oauth2')?{access_token:'synthetic-access',token_type:'Bearer'}:{id:'synthetic-message'});};
  const runtime=createProductionBillingContactRuntime({db,auth:{verifyIdToken:async()=>{calls.auth++;return token;},getUser:async()=>user},
    enabled:()=>enabled,rawConfig:()=>raw,dailyLimit:()=>dailyLimit,now:()=>now,fetchRequest,sleep:async ms=>calls.sleep.push(ms)});
  const run=(op='status',body={})=>runtime.handle({method:'POST',path:'/'+op,headers:{origin:BILLING_CONTACT_LIVE_ORIGIN,
    'content-type':'application/json',authorization:'Bearer synthetic-token'},query:{},rawBody:Buffer.from(JSON.stringify(body)),body});
  const sends=()=>calls.network.filter(([url])=>url.includes('messages/send'));
  const proof=()=>{const mime=Buffer.from(JSON.parse(sends()[0][1].body).raw,'base64url').toString('utf8');const text=Buffer.from(mime.split('Content-Transfer-Encoding: base64\r\n\r\n')[1].split('\r\n--')[0].replace(/\r\n/g,''),'base64').toString('utf8');return text.match(/#token=([A-Za-z0-9_-]{43})/)[1];};
  return {db,user,token,calls,run,sends,proof,advance:ms=>now+=ms,now:()=>now,setConfig:v=>raw=v,getConfig:()=>raw,
    setEnabled:v=>enabled=v,setDailyLimit:v=>dailyLimit=v};
}
test('limited Live parser requires explicit exact one UID, one recipient, total=1 and finite expiry',()=>{
  const parsed=parse(config(),'live');assert.ok(Object.isFrozen(parsed.limitedContactTest));assert.equal(parsed.allowedSubjectHashes.length,1);
  for(const patch of [{limitedContactTest:undefined},{limitedContactTest:{}},{limitedContactTest:{expiresAtMillis:NOW,maxTotalSends:2}},
    {limitedContactTest:{expiresAtMillis:NaN,maxTotalSends:1}},{limitedContactTest:{expiresAtMillis:0,maxTotalSends:1}},
    {limitedContactTest:{expiresAtMillis:NOW,maxTotalSends:1,reset:true}},
    {allowedSubjectHashes:[]},{allowedRecipientHashes:[]},{allowedSubjectHashes:[hash(UID),hash('other')]},
    {allowedRecipientHashes:[hash(TO),hash('other@example.test')]}])assert.throws(()=>parse({...config(),...patch},'live'));
  assert.throws(()=>parse({...config(),environment:'preview'},'preview'));
  const {limitedContactTest,allowedSubjectHashes,allowedRecipientHashes,...ordinary}=config();assert.equal(parse(ordinary,'live').limitedContactTest,undefined);
  assert.throws(()=>parse({...ordinary,allowedSubjectHashes:[hash(UID)]},'live'));
});
test('disabled, expired, malformed or non-one daily budget rejects before Auth or DB',async()=>{
  const f=fixture();f.setEnabled(false);assert.equal((await f.run('request',{email:TO})).status,503);f.setEnabled(true);
  f.setConfig({...config(),limitedContactTest:{expiresAtMillis:NOW,maxTotalSends:1}});assert.equal((await f.run('status')).status,503);
  f.setConfig(config());f.setDailyLimit(2);assert.equal((await f.run('request',{email:TO})).status,503);
  assert.equal(f.calls.auth,0);assert.equal(f.calls.reads,0);assert.equal(f.db.writes.length,0);assert.equal(f.calls.network.length,0);
});
test('wrong authenticated UID is blocked before any application DB read or write',async()=>{
  const f=fixture();f.token.uid=f.user.uid='synthetic-other-owner';
  for(const op of ['status','request','confirm'])assert.equal((await f.run(op,op==='request'?{email:TO}:op==='confirm'?{token:'A'.repeat(43)}:{})).status,403);
  assert.equal(f.calls.reads,0);assert.equal(f.db.writes.length,0);assert.equal(f.calls.network.length,0);
});
test('wrong recipient is blocked before pending state or any application DB access',async()=>{
  const f=fixture();assert.equal((await f.run('request',{email:'another@example.test'})).status,403);
  assert.equal(f.calls.reads,0);assert.equal(f.db.writes.length,0);assert.equal(f.calls.network.length,0);
});
for(const email of ['synthetic-normal@example.test','synthetic@privaterelay.appleid.com','synthetic@private.icloud.com'])
  test('confirmed Auth/Relay branch remains contact-complete without a supplement '+email.split('@')[1],async()=>{
    const f=fixture();f.user.email=email;f.user.emailVerified=true;f.token.email_verified=true;
    const result=await f.run('status');assert.equal(result.status,200);assert.equal(result.body.canCheckout,true);
    assert.equal(f.db.writes.length,0);assert.equal(f.calls.network.length,0);
  });
test('one scoped production contact mail can confirm; same pending proof survives repeated requests',async()=>{
  const f=fixture();const sent=await f.run('request',{email:TO});assert.equal(sent.status,200);assert.equal(f.sends().length,1);
  const first=f.db.documents.get('billing_contacts/'+UID),proof=f.proof();assert.equal(first.pending.deliveryState,'sent');
  assert.equal((await f.run('request',{email:TO})).status,429);assert.deepEqual(f.db.documents.get('billing_contacts/'+UID),first);
  f.advance(60001);assert.equal((await f.run('request',{email:TO})).status,429);assert.deepEqual(f.db.documents.get('billing_contacts/'+UID),first);
  assert.equal((await f.run('confirm',{token:proof})).body.canCheckout,true);assert.equal(f.sends().length,1);
  const slot=f.db.documents.get(SLOT);assert.equal(slot.subjectHash,hash(UID));assert.equal(slot.recipientHash,hash(TO));
  assert.doesNotMatch(JSON.stringify(slot),/synthetic|@|token=|refresh|Bearer/);assert.equal(Object.hasOwn(slot,'ttl'),false);
});
test('next day, changed expiry and a new runtime cannot reset the permanent one-send limit',async()=>{
  const f=fixture();await f.run('request',{email:TO});const pending=f.db.documents.get('billing_contacts/'+UID);
  f.advance(86400000);f.setConfig({...config(),limitedContactTest:{expiresAtMillis:f.now()+6*60*60*1000,maxTotalSends:1}});
  assert.equal((await f.run('request',{email:TO})).status,429);assert.deepEqual(f.db.documents.get('billing_contacts/'+UID),pending);assert.equal(f.sends().length,1);
  const reserveAgain=createLimitedLiveBillingContactReservation(f.db,UID);
  assert.equal(await reserveAgain({subjectHash:hash(UID),recipientHash:hash(TO),notificationIdHash:hash('new'),nowMillis:f.now(),expiresAtMillis:f.now()+1000}),false);
});
test('concurrent reservation and identical-key retry consume only one permanent slot',async()=>{
  const {db}=fakeFirestore(),reserve=createLimitedLiveBillingContactReservation(db,UID),input={subjectHash:hash(UID),recipientHash:hash(TO),notificationIdHash:hash('same'),nowMillis:NOW,expiresAtMillis:NOW+1000};
  const results=await Promise.all([reserve(input),reserve(input)]);assert.deepEqual(results,[true,false]);assert.equal(await createLimitedLiveBillingContactReservation(db,UID)(input),false);
  assert.equal(db.writes.filter(([,path])=>path===SLOT).length,1);
});
test('unknown Gmail timeout is never retried, and future requests cannot replace its challenge or send again',async()=>{
  const f=fixture({fetchRequest:async url=>{if(url.includes('oauth2'))return response({access_token:'synthetic-access'});throw Error('synthetic timeout after possible acceptance');}});
  assert.equal((await f.run('request',{email:TO})).body.code,'contact_delivery_unknown');assert.equal(f.sends().length,1);assert.deepEqual(f.calls.sleep,[]);
  const pending=f.db.documents.get('billing_contacts/'+UID);f.advance(60001);
  assert.equal((await f.run('request',{email:TO})).status,429);assert.deepEqual(f.db.documents.get('billing_contacts/'+UID),pending);assert.equal(f.sends().length,1);
});
test('known OAuth pre-send failure retains the bounded backoff and consumes the slot only at Gmail send',async()=>{
  let oauth=0;const f=fixture({fetchRequest:async url=>{if(url.includes('oauth2')&&++oauth===1)return response({},503);return response(url.includes('oauth2')?{access_token:'synthetic-access'}:{id:'synthetic-message'});}});
  assert.equal((await f.run('request',{email:TO})).status,200);assert.deepEqual(f.calls.sleep,[1000]);assert.equal(f.sends().length,1);assert.ok(f.db.documents.has(SLOT));
});
test('limited shared Gmail sender rejects missing reservation callback and foreign UID/recipient before OAuth',async()=>{
  let calls=0;const send=createSender(parse(config(),'live'),{now:()=>new Date(NOW),fetchRequest:async()=>{calls++;return response({});}});
  const message={notificationId:'synthetic',uid:UID,to:TO,subject:'Synthetic',text:'Synthetic',html:'<p>Synthetic</p>'};
  for(const patch of [{},{uid:'foreign'},{to:'foreign@example.test'}])await assert.rejects(send.send({...message,...patch}));assert.equal(calls,0);
});
test('shared Gmail sender does not re-POST even the same message when a prior request succeeded',async()=>{
  const {db}=fakeFirestore(),calls=[],reserve=createLimitedLiveBillingContactReservation(db,UID);
  const sender=()=>createSender(parse(config(),'live'),{now:()=>new Date(NOW),reserveLimitedContactTest:reserve,fetchRequest:async url=>{calls.push(url);return response(url.includes('oauth2')?{access_token:'synthetic-access'}:{id:'synthetic-message'});}});
  const msg={notificationId:'synthetic-same-message',uid:UID,to:TO,subject:'Synthetic',text:'Synthetic',html:'<p>Synthetic</p>'};
  await sender().send(msg);await assert.rejects(sender().send(msg));assert.equal(calls.filter(url=>url.includes('messages/send')).length,1);
});
test('reservation failure, exhaustion and deadline crossing all block the irreversible Gmail request',async()=>{
  const msg={notificationId:'synthetic-boundary',uid:UID,to:TO,subject:'Synthetic',text:'Synthetic',html:'<p>Synthetic</p>'};
  for(const scenario of ['db-failure','already-reserved','deadline-crossing']) {
    let now=NOW;const calls=[];
    const sender=createSender(parse(config(),'live'),{now:()=>new Date(now),reserveLimitedContactTest:async()=>{
      if(scenario==='db-failure')throw Error('synthetic transaction unavailable');
      if(scenario==='deadline-crossing')now=config().limitedContactTest.expiresAtMillis;
      return scenario!=='already-reserved';},fetchRequest:async url=>{calls.push(url);return response({access_token:'synthetic-access'});}});
    await assert.rejects(sender.send(msg));assert.equal(calls.filter(url=>url.includes('messages/send')).length,0);
  }
});
test('expired limited sender and incorrect UID cannot reserve, fetch OAuth or send',async()=>{
  let network=0,reservations=0;
  const sender=createSender(parse(config(),'live'),{now:()=>new Date(config().limitedContactTest.expiresAtMillis),
    reserveLimitedContactTest:async()=>{reservations++;return true;},fetchRequest:async()=>{network++;return response({});}});
  await assert.rejects(sender.send({notificationId:'synthetic',uid:UID,to:TO,subject:'Synthetic',text:'Synthetic',html:'<p>Synthetic</p>'}));
  assert.equal(network,0);assert.equal(reservations,0);
});
test('deletion fence and invalid subject cannot reserve the limited slot',async()=>{
  const {db}=fakeFirestore(),reserve=createLimitedLiveBillingContactReservation(db,UID);
  const input={subjectHash:hash(UID),recipientHash:hash(TO),notificationIdHash:hash('synthetic'),nowMillis:NOW,expiresAtMillis:NOW+1000};
  await assert.rejects(reserve({...input,subjectHash:hash('other')}));assert.equal(db.writes.length,0);
  const {accountDeletionRef}=load('accountDeletion');db.documents.set(accountDeletionRef(db,UID).path,{status:'requested'});
  assert.equal(await reserve(input),false);assert.equal(db.documents.has(SLOT),false);
});
test('Gmail definite refusal still consumes the one-request slot and cannot cause a second POST',async()=>{
  const f=fixture({fetchRequest:async url=>response(url.includes('oauth2')?{access_token:'synthetic-access'}:{error:{message:'synthetic recipient refused'}},url.includes('oauth2')?200:400)});
  assert.equal((await f.run('request',{email:TO})).status,400);assert.equal(f.sends().length,1);assert.ok(f.db.documents.has(SLOT));
  f.advance(60001);assert.equal((await f.run('request',{email:TO})).status,429);assert.equal(f.sends().length,1);
});
