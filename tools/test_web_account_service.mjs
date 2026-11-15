#!/usr/bin/env node
// Task7 Apple service boundary tests only: synthetic SDK; no login or network.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createAccountService} from '../public/assets/account-service.mjs';
const A='synthetic-apple-owner-a',B='synthetic-apple-owner-b';
const apple=(uid=A,extra={})=>({uid,email:'hidden-owner@privaterelay.appleid.com',emailVerified:true,providerData:[{providerId:'apple.com'}],...extra});
function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});return {promise,resolve,reject};}
function harness({enabled,current=null,pet='found'}={}){
  let notify=()=>{};
  const auth={currentUser:current,authStateReady:async()=>{}};
  const calls={providers:[],popup:[],email:[],signOut:0,reads:[],petData:0};
  const options={popup:null,email:null,pet,signOutFailure:false,docs:{}};
  const sdk={
    onAuthStateChanged(_auth,callback){notify=()=>callback(auth.currentUser);return ()=>{};},
    browserSessionPersistence:Symbol('test-session'),setPersistence:async()=>{},
    OAuthProvider:class{constructor(id){this.id=id;this.scopes=[];this.parameters={};calls.providers.push(this);}addScope(value){this.scopes.push(value);}setCustomParameters(value){this.parameters=value;}},
    GoogleAuthProvider:class{constructor(){this.id='google.com';calls.providers.push(this);}setCustomParameters(value){this.parameters=value;}},
    async signInWithPopup(target,provider){assert.equal(target,auth);calls.popup.push(provider);return options.popup();},
    getAdditionalUserInfo:result=>({isNewUser:result.isNewUser===true}),
    async signInWithEmailAndPassword(target,email,password){assert.equal(target,auth);calls.email.push({email,password});return options.email();},
    async signOut(target){assert.equal(target,auth);calls.signOut++;if(options.signOutFailure)throw {code:'auth/network-request-failed'};auth.currentUser=null;notify();},
    doc:(_db,...parts)=>parts.join('/'),
    async getDoc(path){calls.reads.push(path);
      if(path.endsWith('/pet_profiles/main_pet')){
        if(options.pet==='denied')throw {code:'permission-denied',message:'private resource'};
        if(options.pet==='unavailable')throw {code:'unavailable',message:'private resource'};
        return {exists:()=>options.pet==='found',data:()=>{calls.petData++;throw Error('Pet profile contents must not be read');}};
      }
      const data=options.docs[path];
      return {exists:()=>data!==undefined,data:()=>data};
    },
    reload:async()=>{},getIdToken:async()=>{},
  };
  const service=createAccountService({auth,db:{synthetic:true},sdk,...(enabled===undefined?{}:{appleSignInEnabled:enabled})});
  const observations=[];service.onAuthChanged(value=>observations.push(value));
  const resolveApple=(user=apple(),isNewUser=false)=>{auth.currentUser=user;notify();return {user,isNewUser};};
  options.popup=async()=>resolveApple();options.email=async()=>{auth.currentUser=apple(A,{providerData:[{providerId:'password'}]});notify();};
  return {service,auth,sdk,calls,options,observations,notify:()=>notify(),resolveApple};
}
async function expectCode(operation,code){await assert.rejects(operation,error=>error.code===code);}

test('Apple capability defaults off and refuses login before provider construction or Popup',async()=>{
  const f=harness();assert.equal(f.service.appleSignInEnabled,false);
  await expectCode(()=>f.service.signInApple(),'account/apple-setup-required');
  assert.deepEqual(f.calls.providers,[]);assert.deepEqual(f.calls.popup,[]);assert.deepEqual(f.calls.reads,[]);assert.equal(f.auth.currentUser,null);
});
for(const enabled of [false,'true',1,{},null])test('Apple capability requires explicit boolean true: '+JSON.stringify(enabled),async()=>{
  const f=harness({enabled});await expectCode(()=>f.service.signInApple(),'account/apple-setup-required');assert.equal(f.calls.popup.length,0);
});
test('enabled Apple uses standard OAuth provider with Japanese name/email scopes and preserves existing UID',async()=>{
  const f=harness({enabled:true});await f.service.signInApple();
  assert.equal(f.service.appleSignInEnabled,true);assert.equal(f.auth.currentUser.uid,A);
  assert.equal(f.calls.providers[0].id,'apple.com');assert.deepEqual(f.calls.providers[0].scopes,['email','name']);
  assert.deepEqual(f.calls.providers[0].parameters,{locale:'ja'});
  assert.deepEqual(f.observations.at(-1).methods,['Apple']);assert.equal(f.observations.at(-1).isNewUser,false);
  assert.doesNotMatch(JSON.stringify(f.observations),/synthetic-apple-owner|hidden-owner|apple\.com|idToken|nonce|authorizationCode/);
});
test('later Apple login need not return a fresh name or email profile to retain the original UID',async()=>{
  const f=harness({enabled:true});f.options.popup=async()=>({...f.resolveApple(),additionalUserInfo:{profile:{}}});
  await f.service.signInApple();await f.service.signOut();await f.service.signInApple();
  assert.equal(f.auth.currentUser.uid,A);assert.equal(f.observations.at(-1).maskedEmail,'hi***@privaterelay.appleid.com');
});
test('new Apple UID without app pet profile cannot select a plan, including after page/service restart',async()=>{
  const f=harness({enabled:true,pet:'missing'});f.options.popup=async()=>f.resolveApple(apple(),true);
  await f.service.signInApple();assert.equal(f.observations.at(-1).isNewUser,true);
  const before=await f.service.readAccountSummary();assert.equal(before.appAccountExists,false);assert.equal(before.planReview.canSelectPlan,false);
  const restarted=createAccountService({auth:f.auth,db:{synthetic:true},sdk:f.sdk,appleSignInEnabled:true});
  const after=await restarted.readAccountSummary();assert.equal(after.appAccountExists,false);assert.equal(after.planReview.canSelectPlan,false);
});
test('another Apple account uses only its own UID paths and does not copy the first account',async()=>{
  const f=harness({enabled:true});await f.service.signInApple();await f.service.readAccountSummary();await f.service.signOut();f.calls.reads.length=0;
  f.options.popup=async()=>f.resolveApple(apple(B));await f.service.signInApple();await f.service.readAccountSummary();
  assert.equal(f.auth.currentUser.uid,B);assert.ok(f.calls.reads.length===4&&f.calls.reads.every(path=>path.startsWith('users/'+B+'/')));
});
test('Apple cancellation keeps no new session, raw credential, or account details',async()=>{
  const f=harness({enabled:true});f.options.popup=async()=>{throw {code:'auth/popup-closed-by-user',customData:{private:'synthetic-code'}};};
  await expectCode(()=>f.service.signInApple(),'auth/popup-closed-by-user');
  assert.equal(f.auth.currentUser,null);assert.equal(f.observations.at(-1),null);assert.equal(f.calls.reads.length,0);
});
test('Apple pending hides previous details and blocks Google, email, duplicate Apple and account reads',async()=>{
  const f=harness({enabled:true,current:apple()});const gate=deferred();f.options.popup=()=>gate.promise;
  const pending=f.service.signInApple();assert.equal(f.observations.at(-1),null);
  await expectCode(()=>f.service.signInGoogle(),'account/signin-in-progress');
  await expectCode(()=>f.service.signInEmail('owner@example.test','synthetic-password'),'account/signin-in-progress');
  await expectCode(()=>f.service.signInApple(),'account/signin-in-progress');
  await expectCode(()=>f.service.readAccountSummary(),'account/session-changed');
  assert.equal(f.calls.popup.length,1);assert.equal(f.calls.email.length,0);
  gate.resolve(f.resolveApple());await pending;assert.deepEqual(f.observations.at(-1).methods,['Apple']);
});
test('pending Google blocks Apple without changing the Google provider or starting a second Popup',async()=>{
  const f=harness({enabled:true});const gate=deferred();f.options.popup=()=>gate.promise;
  const pending=f.service.signInGoogle();await expectCode(()=>f.service.signInApple(),'account/signin-in-progress');
  assert.equal(f.calls.providers.length,1);assert.equal(f.calls.providers[0].id,'google.com');
  assert.deepEqual(f.calls.providers[0].parameters,{prompt:'select_account'});
  const user=apple(A,{providerData:[{providerId:'google.com'}]});gate.resolve(f.resolveApple(user));await pending;
});
test('pending email sign-in blocks Apple and Google until the existing operation completes',async()=>{
  const f=harness({enabled:true});const gate=deferred();f.options.email=()=>gate.promise;
  const pending=f.service.signInEmail(' owner@example.test ','synthetic-password');
  await expectCode(()=>f.service.signInApple(),'account/signin-in-progress');await expectCode(()=>f.service.signInGoogle(),'account/signin-in-progress');
  assert.equal(f.calls.popup.length,0);assert.equal(f.calls.email[0].email,'owner@example.test');gate.resolve();await pending;
});
test('logout wins over a late Apple success and a subsequent intentional sign-in can start normally',async()=>{
  const f=harness({enabled:true});const gate=deferred();f.options.popup=()=>gate.promise;const pending=f.service.signInApple();
  await f.service.signOut();const afterLogout=f.observations.length;gate.resolve(f.resolveApple());await pending;
  assert.equal(f.calls.signOut,2);assert.equal(f.auth.currentUser,null);assert.ok(f.observations.slice(afterLogout).every(value=>value===null));
  f.options.popup=async()=>f.resolveApple();await f.service.signInApple();assert.equal(f.auth.currentUser.uid,A);
});
for(const [name,user] of [['no result user',null],['empty UID',apple('')],['path UID',apple('invalid/uid')],
  ['wrong provider',apple(A,{providerData:[{providerId:'google.com'}]})],['missing provider',apple(A,{providerData:[]})],
  ['malformed provider list',apple(A,{providerData:{providerId:'apple.com'}})]])test('invalid Apple result '+name+' signs out without deletion or linkage',async()=>{
  const f=harness({enabled:true});f.options.popup=async()=>f.resolveApple(user);
  await expectCode(()=>f.service.signInApple(),'account/apple-identity-invalid');assert.equal(f.auth.currentUser,null);assert.equal(f.calls.signOut,1);assert.equal(f.observations.at(-1),null);
});
test('result UID must match the actual SDK session, not an arbitrary returned identity',async()=>{
  const f=harness({enabled:true});f.options.popup=async()=>{f.resolveApple(apple(B));return {user:apple(A)};};
  await expectCode(()=>f.service.signInApple(),'account/apple-identity-invalid');assert.equal(f.auth.currentUser,null);
});
test('the current SDK user must retain Apple provider identity too',async()=>{
  const f=harness({enabled:true});f.options.popup=async()=>{f.resolveApple(apple(A,{providerData:[{providerId:'password'}]}));return {user:apple(A)};};
  await expectCode(()=>f.service.signInApple(),'account/apple-identity-invalid');assert.equal(f.auth.currentUser,null);
});
test('failed invalid-result sign-out keeps account details hidden rather than restoring an unsafe session',async()=>{
  const f=harness({enabled:true});f.options.signOutFailure=true;f.options.popup=async()=>f.resolveApple(apple(A,{providerData:[]}));
  await expectCode(()=>f.service.signInApple(),'auth/network-request-failed');assert.equal(f.observations.at(-1),null);
  await expectCode(()=>f.service.readAccountSummary(),'account/session-changed');
});
for(const pet of ['found','missing','denied','unavailable'])test('app-account presence '+pet+' comes only from fixed main_pet exists, never profile content',async()=>{
  const f=harness({enabled:true,current:apple(),pet});const summary=await f.service.readAccountSummary();
  assert.equal(summary.appAccountExists,pet==='found'?true:pet==='missing'?false:null);
  assert.equal(summary.planReview.canSelectPlan,pet==='found');assert.equal(f.calls.petData,0);
  assert.deepEqual(f.calls.reads.sort(),['users/'+A+'/billing/subscription','users/'+A+'/feature_access/initial_trial_v2','users/'+A+'/owner_profiles/main','users/'+A+'/pet_profiles/main_pet']);
});
test('an empty restored UID exposes no safe user and cannot produce Firestore reads',async()=>{
  const f=harness({current:apple('')});assert.equal(f.observations.at(-1),null);
  await expectCode(()=>f.service.readAccountSummary(),'account/session-changed');assert.deepEqual(f.calls.reads,[]);
});
test('a delayed pet-existence response is discarded after Apple account changes',async()=>{
  const f=harness({current:apple()});const gate=deferred();const original=f.sdk.getDoc;
  f.sdk.getDoc=path=>path.endsWith('/pet_profiles/main_pet')?gate.promise:original(path);
  const reading=f.service.readAccountSummary();f.auth.currentUser=apple(B);f.notify();gate.resolve({exists:()=>true,data:()=>({})});
  await expectCode(()=>reading,'account/session-changed');
});
