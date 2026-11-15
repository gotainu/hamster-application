'use strict';
// Synthetic decoded-token and Admin-user objects only; no Auth or network calls.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {authorizePreviewIdentity,PreviewAuthenticationError}=require('../lib/preview-functions/src/auth-policy');
const UID='synthetic-apple-owner',SUBJECT='synthetic-apple-provider-subject';
const clone=value=>structuredClone(value);
function apple(){return {token:{uid:UID,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':[SUBJECT]}}},user:{uid:UID,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:SUBJECT}]}};}
function email(provider='password'){return {token:{uid:UID,email_verified:true,firebase:{sign_in_provider:provider}},user:{uid:UID,disabled:false,emailVerified:true,email:'synthetic@example.test',providerData:[{providerId:provider,uid:'synthetic-provider'}]}};}
function denied(value,code='unauthenticated'){assert.throws(()=>authorizePreviewIdentity(value.token,value.user),error=>{assert.ok(error instanceof PreviewAuthenticationError);assert.equal(error.code,code);assert.equal(error.message,code);assert.doesNotMatch(error.message,/synthetic|@|token|subject/);return true;});}
for(const provider of ['password','google.com'])test(provider+' retains both verified-email requirements',()=>{const f=email(provider);const before=clone(f);assert.deepEqual(authorizePreviewIdentity(f.token,f.user),{uid:UID,emailVerified:true,email:'synthetic@example.test',authBasis:'verified_email'});assert.deepEqual(f,before);});
for(const side of ['token','admin'])for(const value of [false,undefined,'true',1])test(side+' email verification rejects '+String(value),()=>{const f=email('google.com');if(side==='token')f.token.email_verified=value;else f.user.emailVerified=value;denied(f,'email_unverified');});
test('current Apple identity without email preserves false and never invents an address',()=>{const f=apple();const before=clone(f);const result=authorizePreviewIdentity(f.token,f.user);assert.deepEqual(result,{uid:UID,emailVerified:false,authBasis:'apple_provider'});assert.equal(Object.hasOwn(result,'email'),false);assert.equal(Object.isFrozen(result),true);assert.deepEqual(f,before);assert.doesNotMatch(JSON.stringify(result),new RegExp(SUBJECT));});
test('Apple verification is provider identity rather than an email-verification rewrite',()=>{const f=apple();f.user.email='existing@example.test';const result=authorizePreviewIdentity(f.token,f.user);assert.equal(Object.hasOwn(result,'email'),false);assert.equal(result.emailVerified,false);assert.equal(f.user.emailVerified,false);assert.equal(f.token.email_verified,false);});
test('other linked providers are allowed only when the current Apple binding matches',()=>{const f=apple();f.user.providerData.push({providerId:'google.com',uid:'synthetic-google'});assert.equal(authorizePreviewIdentity(f.token,f.user).authBasis,'apple_provider');});
for(const [name,mutate] of [
 ['no Firebase claims',f=>{delete f.token.firebase;}],
 ['linked Apple but current Google',f=>{f.token.firebase.sign_in_provider='google.com';}],
 ['no identities',f=>{delete f.token.firebase.identities;}],
 ['null identities',f=>{f.token.firebase.identities=null;}],
 ['wrong identity key',f=>{f.token.firebase.identities={'apple':[SUBJECT]};}],
 ['empty subjects',f=>{f.token.firebase.identities['apple.com']=[];}],
 ['multiple subjects',f=>{f.token.firebase.identities['apple.com']=[SUBJECT,'other'];}],
 ['duplicate subjects',f=>{f.token.firebase.identities['apple.com']=[SUBJECT,SUBJECT];}],
 ['string subject',f=>{f.token.firebase.identities['apple.com']=SUBJECT;}],
 ['empty subject',f=>{f.token.firebase.identities['apple.com']=[''];}],
 ['nonstring subject',f=>{f.token.firebase.identities['apple.com']=[123];}],
 ['whitespace subject',f=>{f.token.firebase.identities['apple.com']=['synthetic subject'];}],
 ['no provider data',f=>{delete f.user.providerData;}],
 ['null provider data',f=>{f.user.providerData=null;}],
 ['no Admin Apple binding',f=>{f.user.providerData=[{providerId:'google.com',uid:SUBJECT}];}],
 ['two Admin Apple bindings',f=>{f.user.providerData.push({providerId:'apple.com',uid:SUBJECT});}],
 ['malformed provider row',f=>{f.user.providerData.push(null);}],
 ['mismatching Apple subject',f=>{f.user.providerData[0].uid='another-subject';}],
 ['missing Apple subject',f=>{delete f.user.providerData[0].uid;}],
 ['missing actual email verification flag',f=>{delete f.user.emailVerified;}],
 ['string email verification flag',f=>{f.user.emailVerified='false';}],
 ['different Admin UID',f=>{f.user.uid='synthetic-other-owner';}],
 ['disabled user',f=>{f.user.disabled=true;}],
 ['disabled flag missing',f=>{delete f.user.disabled;}],
 ['disabled flag is not boolean',f=>{f.user.disabled='false';}],
 ['empty verified UID',f=>{f.token.uid='';f.user.uid='';}],
 ['path verified UID',f=>{f.token.uid='synthetic/owner';f.user.uid='synthetic/owner';}],
])test('Apple identity fails closed: '+name,()=>{const f=apple();mutate(f);denied(f);});
test('malformed current Apple cannot fall back to verified-email authorization',()=>{const f=apple();f.token.email_verified=true;f.user.emailVerified=true;f.user.email='synthetic@example.test';f.user.providerData=[];denied(f);});
test('a linked Apple account using Google still needs verified email on both sides',()=>{const f=apple();f.token.firebase.sign_in_provider='google.com';f.user.email='synthetic@example.test';denied(f,'email_unverified');f.token.authBasis='apple_provider';f.user.authBasis='apple_provider';denied(f,'email_unverified');});
test('raw identity evidence cannot be substituted with an untrusted authBasis field',()=>{const f=email();f.token.email_verified=false;f.user.emailVerified=false;f.token.authBasis='apple_provider';f.user.authBasis='apple_provider';denied(f,'email_unverified');});
for(const value of [null,undefined,[],{},'synthetic'])test('malformed boundary objects reject '+String(value),()=>denied({token:value,user:value}));

test('Apple email is forwarded only when token and Admin both confirm the existing address',()=>{for(const [tokenFlag,adminFlag] of [[true,true],[false,true],[true,false],[undefined,true]]){const f=apple();f.user.email='existing@example.test';f.token.email_verified=tokenFlag;f.user.emailVerified=adminFlag;const result=authorizePreviewIdentity(f.token,f.user);assert.equal(Object.hasOwn(result,'email'),tokenFlag===true&&adminFlag===true);assert.equal(result.emailVerified,adminFlag);if(result.email)assert.equal(result.email,f.user.email);}});
