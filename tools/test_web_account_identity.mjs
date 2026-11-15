#!/usr/bin/env node
// Synthetic identity fixtures only. No Firebase/Apple login or network.
import test from 'node:test';
import assert from 'node:assert/strict';
import {projectAccountIdentity,isVerifiedAccountIdentity} from '../public/assets/account-identity.mjs';
const project='demo-hamcare-web-apple-task8';
const uid='synthetic-owner';
const subject='synthetic-apple-subject';
const apple=()=>({uid,email:null,emailVerified:false,providerData:[{providerId:'apple.com',uid:subject}]});
const result=(provider='apple.com')=>({signInProvider:provider,claims:{aud:project,iss:'https://securetoken.google.com/'+project,sub:uid,user_id:uid,email_verified:false,firebase:{sign_in_provider:provider,identities:{'apple.com':[subject]}}}});
test('email-less Apple projects a separate identity basis without changing email verification',()=>{
 const user=apple(),r=result();const before=JSON.stringify(user);const value=projectAccountIdentity(user,r,project);
 assert.deepEqual(value,{identityVerified:true,authenticationBasis:'apple_provider',identityCheckFailed:false});assert.equal(isVerifiedAccountIdentity(value),true);assert.equal(JSON.stringify(user),before);
 assert.doesNotMatch(JSON.stringify(value),/synthetic|apple\.com|email|claims|uid|subject|token/i);
});
test('verified email uses its own basis with both actual user and token verification',()=>{
 const user={...apple(),email:'synthetic@example.test',emailVerified:true};const r=result('password');r.claims.email_verified=true;
 assert.deepEqual(projectAccountIdentity(user,r,project),{identityVerified:true,authenticationBasis:'verified_email',identityCheckFailed:false});
});
for(const provider of ['password','google.com'])test('unverified '+provider+' remains denied even with an Apple-linked provider',()=>{
 const user=apple();user.providerData.push({providerId:provider,uid:'synthetic-other'});
 assert.deepEqual(projectAccountIdentity(user,result(provider),project),{identityVerified:false,authenticationBasis:null,identityCheckFailed:false});
});
for(const [name,change] of [
 ['wrong project audience',(_u,r)=>{r.claims.aud='other-project';}],
 ['wrong issuer',(_u,r)=>{r.claims.iss='https://securetoken.google.com/other-project';}],
 ['wrong subject UID',(_u,r)=>{r.claims.sub='other-owner';}],
 ['wrong user_id',(_u,r)=>{r.claims.user_id='other-owner';}],
 ['empty UID',u=>{u.uid='';}],
 ['path UID',u=>{u.uid='synthetic/path';}],
 ['current provider mismatch',(_u,r)=>{r.signInProvider='google.com';}],
 ['claims provider mismatch',(_u,r)=>{r.claims.firebase.sign_in_provider='google.com';}],
 ['no firebase claims',(_u,r)=>{delete r.claims.firebase;}],
 ['no Apple subject',(_u,r)=>{r.claims.firebase.identities={};}],
 ['duplicate token subjects',(_u,r)=>{r.claims.firebase.identities['apple.com']=[subject,subject];}],
 ['scalar token subject',(_u,r)=>{r.claims.firebase.identities['apple.com']=subject;}],
 ['blank token subject',(_u,r)=>{r.claims.firebase.identities['apple.com']=[''];}],
 ['no provider binding',u=>{u.providerData=[];}],
 ['duplicate provider bindings',u=>{u.providerData.push({...u.providerData[0]});}],
 ['different provider binding',u=>{u.providerData[0].uid='synthetic-different';}],
 ['control character subject',u=>{u.providerData[0].uid='synthetic\nsubject';}],
])test('Apple refuses '+name,()=>{const u=apple(),r=result();change(u,r);assert.deepEqual(projectAccountIdentity(u,r,project),{identityVerified:false,authenticationBasis:null,identityCheckFailed:true});});
test('an old auth_time is not a new arbitrary recency requirement',()=>{const r=result();r.claims.auth_time=1;assert.equal(projectAccountIdentity(apple(),r,project).authenticationBasis,'apple_provider');});
test('untrusted presentation flags alone do not authorize a projected identity',()=>{
 for(const value of [null,{emailVerified:true},{identityVerified:true},{identityVerified:true,authenticationBasis:'google.com'},{identityVerified:false,authenticationBasis:'apple_provider'}])assert.equal(isVerifiedAccountIdentity(value),false);
});

test('current Apple validates its subject even when the email is also verified',()=>{
 const user=apple(),r=result();user.email='synthetic@example.test';user.emailVerified=true;r.claims.email_verified=true;
 assert.equal(projectAccountIdentity(user,r,project).authenticationBasis,'apple_provider');r.claims.firebase.identities['apple.com']=['wrong'];assert.equal(projectAccountIdentity(user,r,project).identityVerified,false);
});
test('verified flag without an actual email cannot authorize a non-Apple session',()=>{
 const user=apple(),r=result('google.com');user.emailVerified=true;r.claims.email_verified=true;
 assert.equal(projectAccountIdentity(user,r,project).identityVerified,false);
});
