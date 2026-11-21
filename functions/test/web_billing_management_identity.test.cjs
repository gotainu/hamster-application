'use strict';
// Synthetic already-verified token/Admin records. Signature/revocation remains
// the runtime's Admin SDK boundary; this suite performs no Auth or network I/O.
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource(),shared=load('webBillingShared');
const {createWebBillingCheckout}=load('webBillingCheckout');
const UID='synthetic-management-owner',SUBJECT='synthetic-apple-subject';
const clone=v=>structuredClone(v);
function fixture(provider='password',emailVerified=false,email){
  return {token:{uid:UID,email_verified:false,firebase:{sign_in_provider:provider,identities:{'apple.com':[SUBJECT]}}},
    user:{uid:UID,disabled:false,emailVerified,providerData:[{providerId:provider,uid:SUBJECT}],...(email===undefined?{}:{email})}};
}
const authorize=f=>shared.authorizeWebBillingManagementIdentity(f.token,f.user);
function denied(f){assert.throws(()=>authorize(f),error=>{
  assert.ok(error instanceof shared.BillingAuthenticationError);assert.equal(error.code,'unauthenticated');assert.equal(error.message,'unauthenticated');return true;
});}
for(const provider of ['password','google.com','custom','anonymous'])for(const emailVerified of [false,true]) {
  test(provider+' management retains the signed UID with actual emailVerified '+emailVerified,()=>{
    for(const email of [undefined,'synthetic@example.test','broken']) {
      const f=fixture(provider,emailVerified,email),before=clone(f),identity=authorize(f);
      assert.deepEqual(identity,{uid:UID,emailVerified,authBasis:'firebase_session'});
      assert.equal(Object.isFrozen(identity),true);assert.equal(Object.hasOwn(identity,'email'),false);assert.deepEqual(f,before);
    }
  });
}
test('UID ownership management does not depend on optional email or Firebase provider claims',()=>{
  const f=fixture();delete f.token.firebase;delete f.token.email_verified;delete f.user.providerData;
  assert.deepEqual(authorize(f),{uid:UID,emailVerified:false,authBasis:'firebase_session'});
});
test('a linked Apple provider does not change a current non-Apple Firebase session into Apple proof',()=>{
  const f=fixture('google.com',false);f.user.providerData=[{providerId:'apple.com',uid:'synthetic-different-subject'}];
  assert.equal(authorize(f).authBasis,'firebase_session');
});
for(const emailVerified of [false,true])test('firebase_session with emailVerified '+emailVerified+' cannot become Checkout or contact authorization',async()=>{
  const f=fixture('password',emailVerified,'synthetic@example.test'),identity=authorize(f);
  assert.equal(shared.isWebBillingIdentityConfirmed(identity),false);
  assert.deepEqual(shared.classifyBillingEmail(identity,f.user),{kind:'invalid'});
  assert.throws(()=>shared.assessWebCheckout({identity,appAccountExists:true,billing:{kind:'missing'},trial:{kind:'missing'},planKey:'premium_monthly',now:new Date()}),
    error=>error.code==='email_unverified');
  const touched=[],unexpected=()=>{touched.push('unexpected');throw Error('management proof reached a purchase dependency');};
  const engine=createWebBillingCheckout({
    config:{secretKey:'sk_live_'+'synthetic',publishableKey:'pk_live_'+'synthetic',priceId:'price_syntheticNew550',webhookSecret:'whsec_'+'synthetic',
      portalConfigurationId:'bpc_syntheticRestricted',origin:'https://hamster-breeding-app.web.app',returnUrl:'https://hamster-breeding-app.web.app/account/'},
    stripe:{},store:{read:unexpected,mutate:unexpected},readFacts:unexpected,readContact:unexpected,resolveCustomer:unexpected,now:()=>new Date(),
  });
  await assert.rejects(engine.review(identity,{planKey:'premium_monthly'}),error=>error.code==='unauthenticated'||error.code==='email_unverified');
  await assert.rejects(engine.create(identity,{planKey:'premium_monthly',reviewToken:'synthetic-review-token',termsAccepted:true,termsVersion:'hamcare-web-monthly-550-v1'}),
    error=>error.code==='unauthenticated'||error.code==='email_unverified');
  assert.deepEqual(touched,[]);
});
test('separate purchase authorization keeps the existing verified-email requirement',()=>{
  const f=fixture('password',false,'synthetic@example.test');
  assert.equal(authorize(f).authBasis,'firebase_session');
  assert.throws(()=>shared.authorizeWebBillingIdentity(f.token,f.user),error=>error.code==='email_unverified');
  f.token.email_verified=true;f.user.emailVerified=true;
  assert.equal(shared.authorizeWebBillingIdentity(f.token,f.user).authBasis,'verified_email');
  assert.equal(authorize(f).authBasis,'firebase_session');
});
test('an untrusted client authBasis field cannot relabel management proof as verified_email',()=>{
  const f=fixture();f.token.authBasis='verified_email';f.user.authBasis='apple_provider';
  assert.equal(authorize(f).authBasis,'firebase_session');assert.equal(f.user.emailVerified,false);
});
for(const email of [undefined,'synthetic@privaterelay.appleid.com','synthetic@private.icloud.com'])test('current Apple management preserves the original bound Apple proof: '+String(email),()=>{
  for(const emailVerified of [false,true]) {
    const f=fixture('apple.com',emailVerified,email);f.token.email_verified=emailVerified;
    const before=clone(f),management=authorize(f),purchase=shared.authorizeWebBillingIdentity(f.token,f.user);
    assert.deepEqual(management,purchase);assert.equal(management.authBasis,'apple_provider');assert.equal(management.emailVerified,emailVerified);
    assert.equal(Object.isFrozen(management),true);assert.deepEqual(f,before);
  }
});
for(const [name,mutate] of [
  ['missing identities',f=>{delete f.token.firebase.identities;}],
  ['wrong provider identity',f=>{f.token.firebase.identities={'google.com':[SUBJECT]};}],
  ['multiple signed subjects',f=>{f.token.firebase.identities['apple.com']=[SUBJECT,'synthetic-other'];}],
  ['missing Admin binding',f=>{f.user.providerData=[];}],
  ['different subject',f=>{f.user.providerData[0].uid='synthetic-other';}],
  ['duplicate Admin Apple binding',f=>{f.user.providerData.push(clone(f.user.providerData[0]));}],
  ['malformed Admin provider',f=>{f.user.providerData.push(null);}],
])test('current Apple management never falls back to UID-only proof: '+name,()=>{
  const f=fixture('apple.com',true,'synthetic@example.test');f.token.email_verified=true;mutate(f);denied(f);
});
for(const [name,mutate] of [
  ['different Admin UID',f=>{f.user.uid='synthetic-other';}],
  ['disabled user',f=>{f.user.disabled=true;}],
  ['missing disabled flag',f=>{delete f.user.disabled;}],
  ['string disabled flag',f=>{f.user.disabled='false';}],
  ['missing emailVerified flag',f=>{delete f.user.emailVerified;}],
  ['string emailVerified flag',f=>{f.user.emailVerified='false';}],
])test('management identity fails closed: '+name,()=>{const f=fixture();mutate(f);denied(f);});
for(const uid of ['',null,123,'synthetic/owner','synthetic owner','synthetic\u0000owner','x'.repeat(129)])test('management UID must satisfy the same server UID boundary: '+String(uid),()=>{
  const f=fixture();f.token.uid=uid;f.user.uid=uid;denied(f);
});
for(const value of [null,undefined,[],{},'synthetic'])test('management rejects malformed boundary objects: '+String(value),()=>denied({token:value,user:value}));
