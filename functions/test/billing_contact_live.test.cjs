'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {createHash}=require('node:crypto');
const {fakeFirestore}=require('./support/star_source_loader.cjs');
const {createBillingContactEngine,BILLING_CONTACT_TTL_MS}=require('../lib/billingContact');
const {createProductionBillingContactRuntime,BILLING_CONTACT_LIVE_ORIGIN}=require('../lib/billingContactRuntime');
const {createLiveBillingContactStore}=require('../lib/billingContactStore');
const {createBillingNotificationBudget}=require('../lib/billingNotificationBudget');
const {accountDeletionRef}=require('../lib/accountDeletion');
const {readVerifiedBillingContact}=require('../lib/webBillingShared');
const {resolveBillingNotificationRecipient}=require('../lib/billingNotificationRecipient');
const hash=v=>createHash('sha256').update(v).digest('hex');
const uid='synthetic-live-contact';
const config={enabled:true,environment:'live',from:'gotainu@gmail.com',clientId:'synthetic-live.apps.googleusercontent.com',
  clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token-only'};
function fixture(options={}) {
  const {db}=fakeFirestore();
  let now=1800000000000,enabled=true,raw=config,limit=20;
  const calls={auth:0,network:[],sleep:[]};
  const user={uid,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-apple-subject'}]};
  const token={uid,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['synthetic-apple-subject']}}};
  db.documents.set('users/'+uid+'/owner_profiles/main',{displayName:'Synthetic'});
  db.documents.set('users/'+uid+'/pet_profiles/main_pet',{name:'Synthetic pet'});
  const fetchRequest=async(url,init)=>{
    calls.network.push([url,init]);
    if(options.fetchRequest)return options.fetchRequest(url,init,calls);
    return new Response(JSON.stringify(url.includes('oauth2')?{access_token:'synthetic-access',token_type:'Bearer'}:{id:'synthetic-message'}),{status:200});
  };
  const auth={verifyIdToken:async(_,revoked)=>{assert.equal(revoked,true);calls.auth++;return token;},getUser:async target=>{assert.equal(target,token.uid);return user;}};
  db.documents.set('users/'+uid+'/owner_profiles/main',{displayName:'Synthetic'});db.documents.set('users/'+uid+'/pet_profiles/main_pet',{name:'Synthetic'});
  const runtime=createProductionBillingContactRuntime({db,auth,enabled:()=>enabled,rawConfig:()=>raw,dailyLimit:()=>limit,
    now:()=>now,fetchRequest,sleep:async ms=>calls.sleep.push(ms)});
  const req=(op='status',body={})=>({method:'POST',path:'/'+op,headers:{origin:BILLING_CONTACT_LIVE_ORIGIN,
    'content-type':'application/json',authorization:'Bearer synthetic-token'},query:{},rawBody:Buffer.from(JSON.stringify(body)),body});
  const run=(op,body)=>runtime.handle(req(op,body));
  const messages=()=>calls.network.filter(([url])=>url.includes('messages/send')).map(([,init])=>{
    const mime=Buffer.from(JSON.parse(init.body).raw,'base64url').toString('utf8');
    const text=Buffer.from(mime.split('Content-Transfer-Encoding: base64\r\n\r\n')[1].split('\r\n--')[0].replace(/\r\n/g,''),'base64').toString('utf8');
    const link=text.match(/https:\/\/[^\s]+\/account\/contact\/#token=[A-Za-z0-9_-]{43}/)[0];
    return {mime,text,link,token:new URL(link).hash.slice(7)};
  });
  return{db,user,token,calls,run,req,runtime,messages,now:()=>now,advance:ms=>now+=ms,
    enable:v=>enabled=v,config:v=>raw=v,limit:v=>limit=v};
}
test('disabled/missing/Preview configuration fails before Auth, DB mutation or Gmail',async()=>{
  const f=fixture();f.enable(false);assert.equal((await f.run('status')).status,503);
  f.enable(true);
  for(const value of [undefined,'invalid',{...config,environment:'preview'},{...config,enabled:false}]) {
    f.config(value);assert.equal((await f.run('request',{email:'synthetic@example.test'})).status,503);
  }
  f.config(config);f.limit(0);assert.equal((await f.run('status')).status,503);
  assert.equal(f.calls.auth,0);assert.equal(f.calls.network.length,0);assert.equal(f.db.writes.length,0);
});
for(const domain of ['example.test','privaterelay.appleid.com','private.icloud.com'])test('verified existing Auth contact needs no supplement '+domain,async()=>{
  const f=fixture();f.user.email='synthetic@'+domain;f.user.emailVerified=true;f.token.email_verified=true;
  const s=await f.run('status');assert.equal(s.status,200);assert.equal(s.body.testMode,false);assert.equal(s.body.canCheckout,true);
  assert.equal((await f.run('request',{email:'other@example.test'})).body.code,'contact_not_required');
  assert.equal(f.db.writes.length,0);assert.equal(f.calls.network.length,0);
});
test('missing Apple email → Live proof → exact shared consumer schema and notification recipient',async()=>{
  const f=fixture();assert.equal((await f.run('status')).body.canCheckout,false);
  const result=await f.run('request',{email:'receiver@privaterelay.appleid.com'});assert.equal(result.status,200);assert.equal(result.body.canCheckout,false);
  const message=f.messages()[0];assert.ok(message.link.startsWith(BILLING_CONTACT_LIVE_ORIGIN+'/account/contact/#token='));assert.doesNotMatch(message.text,/Preview/);
  const before=f.db.documents.get('billing_contacts/'+uid);assert.equal(before.firebaseUid,uid);assert.equal(before.purpose,'billing_contact_live');
  assert.equal(before.pending.tokenHash,hash('billing_contact_live\0'+uid+'\0receiver@privaterelay.appleid.com\0'+message.token));
  assert.ok(!JSON.stringify(before).includes(message.token));
  assert.equal((await f.run('confirm',{token:message.token})).body.canCheckout,true);
  const state=f.db.documents.get('billing_contacts/'+uid);
  assert.equal(state.pending,undefined);assert.equal(state.verificationStatus,'verified');
  assert.equal(readVerifiedBillingContact(state,uid,'live',f.now()),'receiver@privaterelay.appleid.com');
  assert.equal(readVerifiedBillingContact(state,uid,'preview',f.now()),null);
  assert.deepEqual(resolveBillingNotificationRecipient({uid,authUser:f.user,mode:'live',nowMillis:f.now(),supplementalContact:{uid,state}}),
    {kind:'resolved',email:'receiver@privaterelay.appleid.com',source:'user_supplied'});
  assert.equal((await f.run('confirm',{token:message.token})).body.code,'contact_used');
});
test('wrong UID and invalid current Apple provider proof cannot consume a challenge',async()=>{
  const f=fixture();await f.run('request',{email:'synthetic@example.test'});const proof=f.messages()[0].token;
  f.token.uid='other';f.user.uid='other';assert.notEqual((await f.run('confirm',{token:proof})).status,200);
  assert.equal(f.db.documents.get('billing_contacts/'+uid).verified,false);
  f.token.uid=uid;f.user.uid=uid;f.token.firebase.identities['apple.com']=['another'];
  assert.equal((await f.run('confirm',{token:proof})).status,401);
});
test('expired, replaced and reused links cannot overwrite active contact',async()=>{
  const f=fixture();await f.run('request',{email:'old@example.test'});const old=f.messages()[0].token;
  await f.run('confirm',{token:old});f.advance(60001);
  await f.run('request',{email:'next@example.test'});const next=f.messages()[1].token;
  assert.equal((await f.run('status')).body.maskedEmail,'ol***@example.test');
  assert.equal(f.db.documents.get('billing_contacts/'+uid).email,'old@example.test');
  f.advance(60001);await f.run('request',{email:'newest@example.test'});const newest=f.messages()[2].token;
  assert.equal((await f.run('confirm',{token:next})).body.code,'contact_invalid_token');
  f.advance(BILLING_CONTACT_TTL_MS);assert.equal((await f.run('confirm',{token:newest})).body.code,'contact_expired');
  assert.equal(f.db.documents.get('billing_contacts/'+uid).email,'old@example.test');
});
test('Preview documents are never read or migrated, even when already verified',async()=>{
  const f=fixture();f.db.documents.set('preview_billing_contacts/'+uid,{purpose:'billing_contact_preview',verified:true,email:'synthetic@example.test',verifiedAt:f.now(),source:'user_supplied'});
  assert.equal((await f.run('status')).body.canCheckout,false);
  assert.equal(f.db.documents.has('billing_contacts/'+uid),false);
  f.db.documents.set('billing_contacts/'+uid,{purpose:'billing_contact_preview',verified:true,email:'synthetic@example.test',verifiedAt:f.now(),source:'user_supplied'});
  assert.equal((await f.run('status')).status,503);assert.equal(f.calls.network.length,0);
});
test('corrupt Live verification and rate history fail closed consistently with shared readers',async()=>{
  const f=fixture();
  const base={firebaseUid:f.user.uid,purpose:'billing_contact_live',schemaVersion:1,verified:true,
    verificationStatus:'verified',verifiedAt:f.now(),source:'user_supplied',email:'synthetic@example.test'};
  for(const patch of [{verificationStatus:'pending'},{verifiedAt:f.now()+1},{requestedAt:'reset'},{lastRequestedAt:f.now()+1}]) {
    f.db.documents.set('billing_contacts/'+f.user.uid,{...base,...patch});
    assert.equal((await f.run('status')).status,503);
    assert.notEqual((await f.run('request',{email:'next@example.test'})).status,200);
  }
  assert.equal(f.calls.network.length,0);
});
test('deletion fence blocks reads and transaction writes, including delayed confirmation after contact cleanup',async()=>{
  const f=fixture();await f.run('request',{email:'synthetic@example.test'});const proof=f.messages()[0].token;
  f.db.documents.set(accountDeletionRef(f.db,uid).path,{version:1,status:'completed',completedAt:f.now()});f.db.documents.delete('billing_contacts/'+uid);
  assert.equal((await f.run('confirm',{token:proof})).status,503);assert.equal(f.db.documents.has('billing_contacts/'+uid),false);
  const store=createLiveBillingContactStore(f.db);
  await assert.rejects(store.mutate(uid,()=>({state:{email:'no@example.test'},result:null})),{code:'contact_account_unavailable'});
});
test('strict origin/body keys reject UID, return URL, query and missing bearer',async()=>{
  const f=fixture();
  for(const req of [{...f.req(),headers:{...f.req().headers,origin:'https://other.invalid'}},f.req('request',{email:'x@example.test',uid:'other'}),
    f.req('request',{email:'x@example.test',returnUrl:'https://other.invalid'}),{...f.req(),query:{token:'secret'}},{...f.req(),headers:{origin:BILLING_CONTACT_LIVE_ORIGIN,'content-type':'application/json'}}]) {
    assert.notEqual((await f.runtime.handle(req)).status,200);
  }
  assert.equal(f.calls.network.length,0);assert.equal(f.db.writes.length,0);
});
test('contact sends and notifications share Live global budget; per-user contact caps stay bounded',async()=>{
  const f=fixture();f.limit(1);await f.run('request',{email:'synthetic@example.test'});
  const reserve=createBillingNotificationBudget(f.db,'live',1);
  assert.equal((await reserve({uid,notificationId:'a'.repeat(64),attemptId:'notification',nowMillis:f.now()})).allowed,false);
  assert.equal(f.calls.network.filter(([url])=>url.includes('messages/send')).length,1);
  f.advance(60001);assert.equal((await f.run('request',{email:'other@example.test'})).body.code,'contact_rate_limited');
});
test('safe pre-send OAuth failure has one backoff; uncertain Gmail result never auto-retries',async()=>{
  let oauth=0;const f=fixture({fetchRequest:async url=>{
    if(url.includes('oauth2')&&++oauth===1)return new Response('{}',{status:503});
    return new Response(JSON.stringify(url.includes('oauth2')?{access_token:'synthetic-access'}:{id:'synthetic-message'}),{status:200});
  }});
  assert.equal((await f.run('request',{email:'synthetic@example.test'})).status,200);assert.deepEqual(f.calls.sleep,[1000]);
  const g=fixture({fetchRequest:async url=>new Response(JSON.stringify(url.includes('oauth2')?{access_token:'synthetic-access'}:{}),{status:url.includes('oauth2')?200:503})});
  assert.equal((await g.run('request',{email:'synthetic@example.test'})).body.code,'contact_delivery_unknown');
  assert.equal(g.calls.network.length,2);assert.equal(g.db.documents.get('billing_contacts/'+uid).pending.deliveryState,'uncertain');
  assert.equal((await g.run('request',{email:'synthetic@example.test'})).body.code,'contact_rate_limited');
});
test('Gmail quota pauses all Live senders and persists only safe operational facts',async()=>{
  const f=fixture({fetchRequest:async url=>new Response(JSON.stringify(url.includes('oauth2')?{access_token:'synthetic-access'}:{error:{message:'Daily quota exceeded',errors:[{reason:'quotaExceeded'}]}}),{status:url.includes('oauth2')?200:429})});
  assert.equal((await f.run('request',{email:'synthetic@example.test'})).body.code,'contact_rate_limited');
  const pause=f.db.documents.get('billing_notification_delivery_limits/_sender');assert.equal(pause.untilMillis,f.now()+86400000);
  assert.doesNotMatch(JSON.stringify(pause),/synthetic|access|token|@/);
  const reserve=createBillingNotificationBudget(f.db,'live',20);assert.equal((await reserve({uid,notificationId:'b'.repeat(64),attemptId:'notification',nowMillis:f.now()})).allowed,false);
});
test('pure shared Preview adapter preserves the existing challenge hash format',async()=>{
  const sent=[],states=new Map();const c={identity:{uid,emailVerified:false,authBasis:'apple_provider'},adminUser:{uid,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-subject'}]},appAccountExists:true};
  const token='A'.repeat(43),engine=createBillingContactEngine({environment:'preview',store:{read:async uid=>states.get(uid)||{},mutate:async(uid,fn)=>{const next=fn(states.get(uid)||{});states.set(uid,next.state);return next.result;}},now:()=>new Date(1800000000000),randomToken:()=>token,sendMail:async m=>sent.push(m)});
  await engine.request(c,'synthetic@example.test');assert.equal(states.get(uid).pending.tokenHash,hash(uid+'\0synthetic@example.test\0'+token));
  assert.equal((await engine.confirm(c,token)).testMode,true);
});
