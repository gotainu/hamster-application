'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {createHash}=require('node:crypto');
const fs=require('node:fs'),path=require('node:path');
const {loadStarSource,fakeFirestore}=require('./support/star_source_loader.cjs');
const load=loadStarSource();
const {createProductionBillingContactRuntime,BILLING_CONTACT_LIVE_ORIGIN}=load('billingContactRuntime');
const {accountDeletionRef}=load('accountDeletion');
const hash=v=>createHash('sha256').update(v).digest('hex');
const uid='synthetic-readonly-contact',time=1800000000000;
const mailConfig={enabled:true,environment:'live',from:'gotainu@gmail.com',
  clientId:'synthetic-live.apps.googleusercontent.com',clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token-only'};
const limitedConfig=(expiresAtMillis=time+60000)=>({...mailConfig,allowedSubjectHashes:[hash('previous-synthetic-owner')],
  allowedRecipientHashes:[hash('previous@example.test')],limitedContactTest:{expiresAtMillis,maxTotalSends:2}});
function fixture(options={}) {
  const {enabled=false,config=mailConfig}=options;
  const statusEnabled=Object.hasOwn(options,'statusEnabled')?options.statusEnabled:true;
  const {db}=fakeFirestore(),reads=[];
  const originalDoc=db.doc;
  db.doc=p=>{const ref=originalDoc(p),get=ref.get;ref.get=async()=>{reads.push(p);return get();};return ref;};
  const calls={config:0,budget:0,verify:0,user:0,network:0,sleep:0};
  const user={uid,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:'synthetic-apple-subject'}]};
  const token={uid,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['synthetic-apple-subject']}}};
  let authFailure=false;
  db.documents.set('users/'+uid+'/owner_profiles/main',{displayName:'Synthetic'});
  db.documents.set('users/'+uid+'/pet_profiles/main_pet',{name:'Synthetic'});
  const runtime=createProductionBillingContactRuntime({db,enabled:()=>enabled,statusEnabled:()=>statusEnabled,
    rawConfig:()=>{calls.config++;return config;},dailyLimit:()=>{calls.budget++;return 1;},now:()=>time,
    auth:{verifyIdToken:async(_bearer,revoked)=>{calls.verify++;assert.equal(revoked,true);if(authFailure)throw Error('synthetic revoked');return token;},
      getUser:async target=>{calls.user++;assert.equal(target,token.uid);return user;}},
    fetchRequest:async()=>{calls.network++;throw Error('unexpected mail send');},sleep:async()=>{calls.sleep++;}});
  const req=(op='status',body={})=>({method:'POST',path:'/'+op,headers:{origin:BILLING_CONTACT_LIVE_ORIGIN,
    'content-type':'application/json',authorization:'Bearer synthetic-token'},query:{},rawBody:Buffer.from(JSON.stringify(body)),body});
  return {db,reads,calls,user,token,runtime,req,run:(op,body)=>runtime.handle(req(op,body)),revoke:()=>authFailure=true};
}
function assertReadOnly(f) {
  assert.equal(f.calls.config,0);assert.equal(f.calls.budget,0);assert.equal(f.calls.network,0);assert.equal(f.calls.sleep,0);
  assert.equal(f.db.writes.length,0);assert.ok(f.reads.every(p=>p.startsWith('users/'+uid+'/') || p==='billing_contacts/'+uid || p===accountDeletionRef(f.db,uid).path));
}
function assertUntouched(f) {
  assertReadOnly(f);assert.equal(f.calls.verify,0);assert.equal(f.calls.user,0);assert.equal(f.reads.length,0);
}
function verifiedContact(patch={}) {return {firebaseUid:uid,purpose:'billing_contact_live',schemaVersion:1,verified:true,
  verificationStatus:'verified',verifiedAt:time-1,source:'user_supplied',email:'receiver@example.test',...patch};}
for(const [provider,email,category] of [['password','normal@example.test','normal'],['google.com','normal@example.test','normal'],
  ['apple.com','relay@privaterelay.appleid.com','apple_relay'],['apple.com','relay@private.icloud.com','apple_relay']]) {
  test('read-only status uses current verified '+provider+' '+category+' contact without mail configuration',async()=>{
    const f=fixture();f.user.email=email;f.user.emailVerified=true;f.token.email_verified=true;
    if(provider!=='apple.com'){f.user.providerData=[{providerId:provider,uid:'synthetic-provider'}];f.token.firebase={sign_in_provider:provider};}
    const r=await f.run('status');assert.equal(r.status,200);assert.equal(r.body.testMode,false);assert.equal(r.body.category,category);assert.equal(r.body.canCheckout,true);
    assert.ok(!f.reads.some(p=>p.startsWith('billing_contacts/')));assertReadOnly(f);
  });
}
test('read-only missing Apple email remains missing until a same-UID Live proof exists',async()=>{
  const f=fixture();const first=await f.run('status');assert.equal(first.status,200);assert.equal(first.body.category,'missing');assert.equal(first.body.canCheckout,false);
  f.db.documents.set('billing_contacts/'+uid,verifiedContact());const second=await f.run('status');
  assert.equal(second.status,200);assert.equal(second.body.canCheckout,true);assert.equal(second.body.source,'user_supplied');assert.equal(second.body.maskedEmail,'re***@example.test');assertReadOnly(f);
});
test('expired owner-only mail config does not restrict independently enabled read-only status',async()=>{
  const f=fixture({config:limitedConfig(time-1)});f.db.documents.set('billing_contacts/'+uid,verifiedContact());
  assert.equal((await f.run('status')).body.canCheckout,true);assertReadOnly(f);
});
for(const statusEnabled of [undefined,false,'true',1,null]) test('disabled or inexact status flag fails closed: '+String(statusEnabled),async()=>{
  const f=fixture({statusEnabled});
  assert.equal((await f.run('status')).status,503);
  assertUntouched(f);
});
for(const [op,body] of [['request',{email:'receiver@example.test'}],['confirm',{token:'A'.repeat(43)}],['request',{uid:'other'}]]) {
  test('read-only flag never enables '+op+' or its dependencies '+Object.keys(body).join(','),async()=>{
    const f=fixture();assert.equal((await f.run(op,body)).status,503);assertUntouched(f);
  });
}
test('read-only status keeps strict Origin, method, JSON and body/query boundaries',async()=>{
  const f=fixture(),base=f.req();
  for(const req of [{...base,headers:{...base.headers,origin:'https://hamster-breeding-app--synthetic.web.app'}},
    {...base,method:'GET'},{...base,headers:{...base.headers,'content-type':'text/plain'}},f.req('status',{uid:'other'}),
    f.req('status',{email:'other@example.test'}),f.req('status',{returnUrl:'https://other.invalid'}),{...base,query:{uid:'other'}},
    {...base,rawBody:Buffer.alloc(2049)},{...base,body:[]}]) assert.notEqual((await f.runtime.handle(req)).status,200);
  assertUntouched(f);
});
test('read-only status rejects missing bearer and revoked sessions before database reads',async()=>{
  const f=fixture(),req=f.req();delete req.headers.authorization;
  assert.equal((await f.runtime.handle(req)).status,401);assert.equal(f.calls.verify,0);f.revoke();
  assert.equal((await f.run('status')).status,401);assert.equal(f.calls.user,0);assert.equal(f.reads.length,0);assertReadOnly(f);
});
for(const variant of ['different-admin-uid','disabled-user','different-apple-subject','empty-uid']) test('read-only status rejects '+variant,async()=>{
  const f=fixture();if(variant==='different-admin-uid')f.user.uid='other';if(variant==='disabled-user')f.user.disabled=true;
  if(variant==='different-apple-subject')f.token.firebase.identities['apple.com']=['other'];if(variant==='empty-uid')f.token.uid='';
  assert.equal((await f.run('status')).status,401);assert.equal(f.reads.length,0);assertReadOnly(f);
});
for(const missing of ['owner_profiles/main','pet_profiles/main_pet']) test('read-only status still requires own '+missing,async()=>{
  const f=fixture();f.db.documents.delete('users/'+uid+'/'+missing);assert.equal((await f.run('status')).body.code,'app_account_required');assertReadOnly(f);
});
test('read-only status cannot pass a deletion fence or recreate a contact',async()=>{
  const f=fixture();f.db.documents.set(accountDeletionRef(f.db,uid).path,{status:'completed'});
  assert.equal((await f.run('status')).status,503);assert.equal(f.db.documents.has('billing_contacts/'+uid),false);assertReadOnly(f);
});
test('read-only status never reads or migrates Preview contact proof',async()=>{
  const f=fixture();f.db.documents.set('preview_billing_contacts/'+uid,verifiedContact({purpose:'billing_contact_preview'}));
  assert.equal((await f.run('status')).body.canCheckout,false);assert.equal(f.db.documents.has('billing_contacts/'+uid),false);
  f.db.documents.set('billing_contacts/'+uid,verifiedContact({purpose:'billing_contact_preview'}));assert.equal((await f.run('status')).status,503);assertReadOnly(f);
});
for(const patch of [{firebaseUid:'other'},{verifiedAt:time+1},{verificationStatus:'pending'},{source:'auth_verified'}]) {
  test('read-only status refuses invalid same-collection proof '+Object.keys(patch)[0],async()=>{
    const f=fixture();f.db.documents.set('billing_contacts/'+uid,verifiedContact(patch));assert.equal((await f.run('status')).status,503);assertReadOnly(f);
  });
}
test('read-only status preserves expired pending data and delivery history without cleanup writes',async()=>{
  const f=fixture(),state={firebaseUid:uid,purpose:'billing_contact_live',schemaVersion:1,verified:false,requestedAt:[time-100000],lastRequestedAt:time-100000,
    pending:{email:'receiver@example.test',tokenHash:'a'.repeat(64),createdAt:time-100000,expiresAt:time-1,deliveryState:'uncertain'}};
  f.db.documents.set('billing_contacts/'+uid,state);const r=await f.run('status');assert.equal(r.status,200);assert.equal(r.body.canCheckout,false);assert.equal(r.body.state,'missing');
  assert.deepEqual(f.db.documents.get('billing_contacts/'+uid),state);assertReadOnly(f);
});
test('send-enabled status retains existing Live config and limited-owner checks even when status flag is true',async()=>{
  const normal=fixture({enabled:true,statusEnabled:false});assert.equal((await normal.run('status')).status,200);assert.equal(normal.calls.config,1);assert.equal(normal.calls.budget,1);
  for(const config of [limitedConfig(time-1),{...mailConfig,environment:'preview'}]) {
    const f=fixture({enabled:true,statusEnabled:true,config});assert.equal((await f.run('status')).status,503);assert.equal(f.calls.verify,0);assert.equal(f.reads.length,0);assert.equal(f.calls.network,0);assert.equal(f.db.writes.length,0);
  }
  const limited=fixture({enabled:true,statusEnabled:true,config:limitedConfig()});assert.equal((await limited.run('status')).body.code,'contact_test_not_allowed');
  assert.equal(limited.reads.length,0);assert.equal(limited.calls.network,0);assert.equal(limited.db.writes.length,0);
});
test('production entry point requires the exact true literal for the independent status flag',()=>{
  const source=fs.readFileSync(path.resolve(__dirname,'../src/index.ts'),'utf8');
  assert.match(source,/statusEnabled:\(\)=>process\.env\.HAMCARE_BILLING_CONTACT_STATUS_ENABLED==='true'/);
});
