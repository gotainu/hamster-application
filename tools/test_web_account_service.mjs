#!/usr/bin/env node
// Apple service and fresh-identity boundary tests only: synthetic SDK; no login or network.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createAccountService,selectAppleSignInMethod} from '../public/assets/account-service.mjs';
const A='synthetic-apple-owner-a',B='synthetic-apple-owner-b';
const PROJECT='demo-hamcare-preview-sync';
const tokenResult = user => {
  const provider=user.providerData?.[0]?.providerId || 'password';
  const appleSubjects=(Array.isArray(user.providerData)?user.providerData:[]).filter(item=>item.providerId==='apple.com').map(item=>item.uid);
  return {signInProvider:provider,claims:{aud:PROJECT,iss:'https://securetoken.google.com/'+PROJECT,sub:user.uid,user_id:user.uid,email_verified:user.emailVerified===true,firebase:{sign_in_provider:provider,identities:{...(appleSubjects.length?{'apple.com':appleSubjects}:{})}}}};
};
const flush=()=>new Promise(resolve=>setImmediate(resolve));
const apple=(uid=A,extra={})=>({uid,email:'hidden-owner@privaterelay.appleid.com',emailVerified:true,providerData:[{providerId:'apple.com',uid:'synthetic-provider-'+uid}],...extra});
function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});return {promise,resolve,reject};}
function harness({enabled,current=null,pet='found',context}={}){
  let notify=()=>{};
  const auth={app:{options:{projectId:PROJECT}},currentUser:current,authStateReady:async()=>{}};
  const calls={providers:[],popup:[],email:[],signOut:0,reads:[],petData:0,redirectStart:[],redirectResult:0,tokens:0,reloads:0};
  const options={popup:null,email:null,pet,signOutFailure:false,docs:{},redirectStart:async()=>{},redirectResult:async()=>null,token:async user=>tokenResult(user),reload:async()=>{}};
  const sdk={
    onAuthStateChanged(_auth,callback){notify=()=>callback(auth.currentUser);return ()=>{};},
    browserSessionPersistence:Symbol('test-session'),setPersistence:async()=>{},
    OAuthProvider:class{constructor(id){this.id=id;this.scopes=[];this.parameters={};calls.providers.push(this);}addScope(value){this.scopes.push(value);}setCustomParameters(value){this.parameters=value;}},
    GoogleAuthProvider:class{constructor(){this.id='google.com';calls.providers.push(this);}setCustomParameters(value){this.parameters=value;}},
    async signInWithPopup(target,provider){assert.equal(target,auth);calls.popup.push(provider);return options.popup();},
    async signInWithRedirect(target,provider){assert.equal(target,auth);calls.redirectStart.push(provider);return options.redirectStart();},
    async getRedirectResult(target){assert.equal(target,auth);calls.redirectResult++;return options.redirectResult();},
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
    reload:async user=>{calls.reloads++;await options.reload(user);},
    getIdTokenResult:async(user,forceRefresh)=>{assert.equal(forceRefresh,true);calls.tokens++;return options.token(user);},
  };
  const service=createAccountService({auth,db:{synthetic:true},sdk,...(enabled===undefined?{}:{appleSignInEnabled:enabled}),...(context?{appleAuthContext:context}:{})});
  const observations=[];service.onAuthChanged(value=>observations.push(value));
  const resolveApple=(user=apple(),isNewUser=false)=>{auth.currentUser=user;notify();return {user,isNewUser};};
  options.popup=async()=>resolveApple();options.email=async()=>{auth.currentUser=apple(A,{providerData:[{providerId:'password'}]});notify();};
  return {service,auth,sdk,calls,options,observations,notify:()=>notify(),resolveApple};
}
async function readyHarness(options){const f=harness(options);await f.service.ready();return f;}
async function expectCode(operation,code){await assert.rejects(operation,error=>error.code===code);}

test('Apple capability defaults off and refuses login before provider construction or Popup',async()=>{
  const f=harness();assert.equal(f.service.appleSignInEnabled,false);
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/apple-setup-required');
  assert.deepEqual(f.calls.providers,[]);assert.deepEqual(f.calls.popup,[]);assert.deepEqual(f.calls.reads,[]);assert.equal(f.auth.currentUser,null);
});
for(const enabled of [false,'true',1,{},null])test('Apple capability requires explicit boolean true: '+JSON.stringify(enabled),async()=>{
  const f=harness({enabled});await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/apple-setup-required');assert.equal(f.calls.popup.length,0);
});
test('enabled Apple uses standard OAuth provider with Japanese name/email scopes and preserves existing UID',async()=>{
  const f=await readyHarness({enabled:true});await f.service.signInApple({linkingConsent:true});
  assert.equal(f.service.appleSignInEnabled,true);assert.equal(f.auth.currentUser.uid,A);
  assert.equal(f.calls.providers[0].id,'apple.com');assert.deepEqual(f.calls.providers[0].scopes,['email','name']);
  assert.deepEqual(f.calls.providers[0].parameters,{locale:'ja'});
  assert.deepEqual(f.observations.at(-1).methods,['Apple']);assert.equal(f.observations.at(-1).isNewUser,false);
  assert.doesNotMatch(JSON.stringify(f.observations),/synthetic-apple-owner|hidden-owner|apple\.com|idToken|nonce|authorizationCode/);
});
test('later Apple login need not return a fresh name or email profile to retain the original UID',async()=>{
  const f=await readyHarness({enabled:true});f.options.popup=async()=>({...f.resolveApple(),additionalUserInfo:{profile:{}}});
  await f.service.signInApple({linkingConsent:true});await f.service.signOut();await f.service.signInApple({linkingConsent:true});
  assert.equal(f.auth.currentUser.uid,A);assert.equal(f.observations.at(-1).maskedEmail,'hi***@privaterelay.appleid.com');
});
test('new Apple UID without app pet profile cannot select a plan, including after page/service restart',async()=>{
  const f=await readyHarness({enabled:true,pet:'missing'});f.options.popup=async()=>f.resolveApple(apple(),true);
  await f.service.signInApple({linkingConsent:true});assert.equal(f.observations.at(-1).isNewUser,true);
  const before=await f.service.readAccountSummary();assert.equal(before.appAccountExists,false);assert.equal(before.planReview.canSelectPlan,false);
  const restarted=createAccountService({auth:f.auth,db:{synthetic:true},sdk:f.sdk,appleSignInEnabled:true});
  await restarted.ready();const after=await restarted.readAccountSummary();assert.equal(after.appAccountExists,false);assert.equal(after.planReview.canSelectPlan,false);
});
test('another Apple account uses only its own UID paths and does not copy the first account',async()=>{
  const f=await readyHarness({enabled:true});await f.service.signInApple({linkingConsent:true});await f.service.readAccountSummary();await f.service.signOut();f.calls.reads.length=0;
  f.options.popup=async()=>f.resolveApple(apple(B));await f.service.signInApple({linkingConsent:true});await f.service.readAccountSummary();
  assert.equal(f.auth.currentUser.uid,B);assert.ok(f.calls.reads.length===4&&f.calls.reads.every(path=>path.startsWith('users/'+B+'/')));
});
test('Apple cancellation keeps no new session, raw credential, or account details',async()=>{
  const f=await readyHarness({enabled:true});f.options.popup=async()=>{throw {code:'auth/popup-closed-by-user',customData:{private:'synthetic-code'}};};
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'auth/popup-closed-by-user');
  assert.equal(f.auth.currentUser,null);assert.equal(f.observations.at(-1),null);assert.equal(f.calls.reads.length,0);
});
test('Apple pending hides previous details and blocks Google, email, duplicate Apple and account reads',async()=>{
  const f=await readyHarness({enabled:true,current:apple()});const gate=deferred();f.options.popup=()=>gate.promise;
  const pending=f.service.signInApple({linkingConsent:true});assert.equal(f.observations.at(-1),null);
  await expectCode(()=>f.service.signInGoogle(),'account/signin-in-progress');
  await expectCode(()=>f.service.signInEmail('owner@example.test','synthetic-password'),'account/signin-in-progress');
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/signin-in-progress');
  await expectCode(()=>f.service.readAccountSummary(),'account/session-changed');
  assert.equal(f.calls.popup.length,1);assert.equal(f.calls.email.length,0);
  gate.resolve(f.resolveApple());await pending;assert.deepEqual(f.observations.at(-1).methods,['Apple']);
});
test('pending Google blocks Apple without changing the Google provider or starting a second Popup',async()=>{
  const f=await readyHarness({enabled:true});const gate=deferred();f.options.popup=()=>gate.promise;
  const pending=f.service.signInGoogle();await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/signin-in-progress');
  assert.equal(f.calls.providers.length,1);assert.equal(f.calls.providers[0].id,'google.com');
  assert.deepEqual(f.calls.providers[0].parameters,{prompt:'select_account'});
  const user=apple(A,{providerData:[{providerId:'google.com'}]});gate.resolve(f.resolveApple(user));await pending;
});
test('pending email sign-in blocks Apple and Google until the existing operation completes',async()=>{
  const f=await readyHarness({enabled:true});const gate=deferred();f.options.email=()=>gate.promise;
  const pending=f.service.signInEmail(' owner@example.test ','synthetic-password');
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/signin-in-progress');await expectCode(()=>f.service.signInGoogle(),'account/signin-in-progress');
  assert.equal(f.calls.popup.length,0);assert.equal(f.calls.email[0].email,'owner@example.test');gate.resolve();await pending;
});
test('logout wins over a late Apple success and a subsequent intentional sign-in can start normally',async()=>{
  const f=await readyHarness({enabled:true});const gate=deferred();f.options.popup=()=>gate.promise;const pending=f.service.signInApple({linkingConsent:true});
  await f.service.signOut();const afterLogout=f.observations.length;gate.resolve(f.resolveApple());await pending;
  assert.equal(f.calls.signOut,2);assert.equal(f.auth.currentUser,null);assert.ok(f.observations.slice(afterLogout).every(value=>value===null));
  f.options.popup=async()=>f.resolveApple();await f.service.signInApple({linkingConsent:true});assert.equal(f.auth.currentUser.uid,A);
});
for(const [name,user] of [['no result user',null],['empty UID',apple('')],['path UID',apple('invalid/uid')],
  ['wrong provider',apple(A,{providerData:[{providerId:'google.com'}]})],['missing provider',apple(A,{providerData:[]})],
  ['malformed provider list',apple(A,{providerData:{providerId:'apple.com'}})]])test('invalid Apple result '+name+' signs out without deletion or linkage',async()=>{
  const f=await readyHarness({enabled:true});f.options.popup=async()=>f.resolveApple(user);
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/apple-identity-invalid');assert.equal(f.auth.currentUser,null);assert.equal(f.calls.signOut,1);assert.equal(f.observations.at(-1),null);
});
test('result UID must match the actual SDK session, not an arbitrary returned identity',async()=>{
  const f=await readyHarness({enabled:true});f.options.popup=async()=>{f.resolveApple(apple(B));return {user:apple(A)};};
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/apple-identity-invalid');assert.equal(f.auth.currentUser,null);
});
test('the current SDK user must retain Apple provider identity too',async()=>{
  const f=await readyHarness({enabled:true});f.options.popup=async()=>{f.resolveApple(apple(A,{providerData:[{providerId:'password'}]}));return {user:apple(A)};};
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/apple-identity-invalid');assert.equal(f.auth.currentUser,null);
});
test('failed invalid-result sign-out keeps account details hidden rather than restoring an unsafe session',async()=>{
  const f=await readyHarness({enabled:true});f.options.signOutFailure=true;f.options.popup=async()=>f.resolveApple(apple(A,{providerData:[]}));
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'auth/network-request-failed');assert.equal(f.observations.at(-1),null);
  await expectCode(()=>f.service.readAccountSummary(),'account/session-changed');
});
for(const pet of ['found','missing','denied','unavailable'])test('app-account presence '+pet+' comes only from fixed main_pet exists, never profile content',async()=>{
  const f=await readyHarness({enabled:true,current:apple(),pet});const summary=await f.service.readAccountSummary();
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
  const reading=f.service.readAccountSummary();await flush();f.auth.currentUser=apple(B);f.notify();gate.resolve({exists:()=>true,data:()=>({})});
  await expectCode(()=>reading,'account/session-changed');
});

for(const email of [undefined,null,''])test('restored Apple identity can be verified without an email: '+String(email),async()=>{
  const current=apple(A,{email,emailVerified:false});
  const f=await readyHarness({enabled:true,current});
  const visible=f.observations.at(-1);
  assert.equal(visible.emailVerified,false);
  assert.equal(visible.identityVerified,true);
  assert.equal(visible.authenticationBasis,'apple_provider');
  assert.equal(visible.identityCheckFailed,false);
  assert.equal(visible.maskedEmail,'未設定');
  assert.deepEqual(visible.methods,['Apple']);
  assert.equal(f.calls.tokens,1);
  assert.deepEqual(f.calls.reads,[]);
  const summary=await f.service.readAccountSummary();
  assert.equal(summary.identityVerified,true);
  assert.equal(summary.authenticationBasis,'apple_provider');
  assert.equal(summary.maskedEmail,'未設定');
  assert.equal(summary.appAccountExists,true);
  assert.equal(summary.planReview.canSelectPlan,true);
  assert.equal(f.auth.currentUser.emailVerified,false);
  assert.equal(f.calls.tokens,2,'each summary read obtains fresh SDK identity');
  assert.equal(f.calls.reads.length,4);
  assert.doesNotMatch(JSON.stringify([visible,summary]),/synthetic-apple-owner|synthetic-provider|apple\.com|idToken|claims/);
});
test('Apple Popup publishes its fresh verified identity without fabricating email verification',async()=>{
  const f=await readyHarness({enabled:true});
  f.options.popup=async()=>f.resolveApple(apple(A,{email:undefined,emailVerified:false}));
  await f.service.signInApple({linkingConsent:true});
  assert.equal(f.auth.currentUser.uid,A);
  assert.equal(f.auth.currentUser.emailVerified,false);
  assert.equal(f.observations.at(-1).identityVerified,true);
  assert.equal(f.observations.at(-1).authenticationBasis,'apple_provider');
  assert.equal(f.observations.at(-1).maskedEmail,'未設定');
  assert.equal(f.calls.reads.length,0);
  assert.equal((await f.service.readAccountSummary()).appAccountExists,true);
});
for(const [name,mutate] of [
  ['wrong audience',r=>r.claims.aud='another-demo-project'],
  ['wrong issuer',r=>r.claims.iss='https://securetoken.google.com/another-demo-project'],
  ['wrong token UID',r=>r.claims.sub=B],
  ['wrong user_id',r=>r.claims.user_id=B],
  ['wrong current provider',r=>{r.signInProvider='google.com';r.claims.firebase.sign_in_provider='google.com';}],
  ['inconsistent SDK provider',r=>r.signInProvider='google.com'],
  ['wrong Apple subject',r=>r.claims.firebase.identities['apple.com']=['another-synthetic-apple-subject']],
  ['missing Apple subject',r=>delete r.claims.firebase.identities['apple.com']],
  ['multiple Apple subjects',r=>r.claims.firebase.identities['apple.com'].push('another-synthetic-subject')],
])test('fresh Apple identity rejects '+name+' before document reads',async()=>{
  const current=apple(A,{email:undefined,emailVerified:false});
  const f=harness({enabled:true,current});
  f.options.token=async user=>{const r=tokenResult(user);mutate(r);return r;};
  await f.service.ready();
  assert.equal(f.observations.at(-1).identityVerified,false);
  assert.equal(f.observations.at(-1).authenticationBasis,null);
  await expectCode(()=>f.service.readAccountSummary(),'account/identity-unverified');
  assert.deepEqual(f.calls.reads,[]);
  assert.equal(f.auth.currentUser.emailVerified,false);
  assert.doesNotMatch(JSON.stringify(f.observations),/synthetic-apple-owner|synthetic-provider|another-synthetic|securetoken|claims/);
});
test('Apple email verification cannot bypass the current Apple subject binding',async()=>{
  const f=harness({enabled:true,current:apple()});
  f.options.token=async user=>{const r=tokenResult(user);r.claims.firebase.identities['apple.com']=['wrong-synthetic-subject'];return r;};
  await f.service.ready();
  assert.equal(f.observations.at(-1).emailVerified,true);
  assert.equal(f.observations.at(-1).identityVerified,false);
  assert.equal(f.observations.at(-1).identityCheckFailed,true);
  await expectCode(()=>f.service.readAccountSummary(),'account/identity-unverified');
  assert.deepEqual(f.calls.reads,[]);
});
test('verified Google flag without an actual email cannot stand in for email identity',async()=>{
  const current=apple(A,{email:undefined,providerData:[{providerId:'google.com'},{providerId:'apple.com',uid:'synthetic-provider-'+A}]});
  const f=await readyHarness({enabled:true,current});
  assert.equal(f.observations.at(-1).emailVerified,true);
  assert.equal(f.observations.at(-1).identityVerified,false);
  assert.equal(f.observations.at(-1).authenticationBasis,null);
  await expectCode(()=>f.service.readAccountSummary(),'account/identity-unverified');
  assert.deepEqual(f.calls.reads,[]);
});
test('missing Firebase project binding prevents even an otherwise verified identity from reading documents',async()=>{
  const f=harness({enabled:true,current:apple()});
  delete f.auth.app.options.projectId;
  await f.service.ready();
  assert.equal(f.observations.at(-1).identityVerified,false);
  assert.equal(f.observations.at(-1).identityCheckFailed,true);
  await expectCode(()=>f.service.readAccountSummary(),'account/identity-unverified');
  assert.deepEqual(f.calls.reads,[]);
});
for(const linkedApple of [false,true])test('unverified current Google identity stays blocked when Apple linkage is '+linkedApple,async()=>{
  const current=apple(A,{email:'unverified@example.test',emailVerified:false,providerData:[{providerId:'google.com'},...(linkedApple?[{providerId:'apple.com',uid:'synthetic-provider-'+A}]:[])]});
  const f=await readyHarness({enabled:true,current});
  assert.equal(f.observations.at(-1).emailVerified,false);
  assert.equal(f.observations.at(-1).identityVerified,false);
  assert.equal(f.observations.at(-1).identityCheckFailed,false);
  assert.equal(f.observations.at(-1).authenticationBasis,null);
  await expectCode(()=>f.service.readAccountSummary(),'account/identity-unverified');
  assert.deepEqual(f.calls.reads,[]);
});
test('reload re-evaluates Apple identity and a stale successful snapshot cannot authorize new reads',async()=>{
  const f=await readyHarness({enabled:true,current:apple(A,{email:undefined,emailVerified:false})});
  assert.equal(f.observations.at(-1).identityVerified,true);
  f.options.token=async user=>{const r=tokenResult(user);r.claims.firebase.identities['apple.com']=['wrong-synthetic-subject'];return r;};
  await f.service.reloadUser();
  assert.equal(f.calls.reloads,1);
  assert.equal(f.observations.at(-1).emailVerified,false);
  assert.equal(f.observations.at(-1).identityVerified,false);
  assert.equal(f.observations.at(-1).identityCheckFailed,true);
  await expectCode(()=>f.service.readAccountSummary(),'account/identity-unverified');
  assert.deepEqual(f.calls.reads,[]);
});
test('summary freshness rejects changed token claims even without an Auth notification or reload',async()=>{
  const f=await readyHarness({enabled:true,current:apple(A,{email:undefined,emailVerified:false})});
  assert.equal(f.observations.at(-1).identityVerified,true);
  f.options.token=async user=>{const r=tokenResult(user);r.claims.aud='another-demo-project';return r;};
  await expectCode(()=>f.service.readAccountSummary(),'account/identity-unverified');
  assert.deepEqual(f.calls.reads,[]);
});
test('logout invalidates an in-flight Apple token projection and cannot restore its safe user',async()=>{
  const f=await readyHarness({enabled:true});
  const gate=deferred();
  const current=apple(A,{email:undefined,emailVerified:false});
  f.options.token=()=>gate.promise;
  f.auth.currentUser=current;f.notify();
  assert.equal(f.observations.at(-1),null);
  await f.service.signOut();
  const afterLogout=f.observations.length;
  gate.resolve(tokenResult(current));await flush();
  assert.equal(f.auth.currentUser,null);
  assert.equal(f.observations.at(-1),null);
  assert.ok(f.observations.slice(afterLogout).every(value=>value===null));
  assert.deepEqual(f.calls.reads,[]);
});
test('late Apple token projection cannot replace another UID using verified Google sign-in',async()=>{
  const f=await readyHarness({enabled:true});
  const gate=deferred();
  const original=apple(A,{email:undefined,emailVerified:false});
  f.options.token=async user=>user.uid===A?gate.promise:tokenResult(user);
  f.auth.currentUser=original;f.notify();
  const other=apple(B,{email:'other-owner@example.test',providerData:[{providerId:'google.com'}]});
  f.auth.currentUser=other;f.notify();await flush();
  assert.deepEqual(f.observations.at(-1).methods,['Google']);
  assert.equal(f.observations.at(-1).authenticationBasis,'verified_email');
  gate.resolve(tokenResult(original));await flush();
  assert.deepEqual(f.observations.at(-1).methods,['Google']);
  assert.equal(f.observations.at(-1).maskedEmail,'ot***@example.test');
  await f.service.readAccountSummary();
  assert.equal(f.calls.reads.length,4);
  assert.ok(f.calls.reads.every(path=>path.startsWith('users/'+B+'/')));
});
test('reload started for Apple UID cannot publish over an intervening Google UID change',async()=>{
  const f=await readyHarness({enabled:true,current:apple(A,{email:undefined,emailVerified:false})});
  const gate=deferred();f.options.reload=()=>gate.promise;
  const reloading=f.service.reloadUser();
  f.auth.currentUser=apple(B,{email:'other-owner@example.test',providerData:[{providerId:'google.com'}]});f.notify();await flush();
  gate.resolve();await reloading;
  assert.deepEqual(f.observations.at(-1).methods,['Google']);
  assert.equal(f.observations.at(-1).authenticationBasis,'verified_email');
  assert.equal(f.observations.at(-1).maskedEmail,'ot***@example.test');
  assert.deepEqual(f.calls.reads,[]);
});

const APPLE_KEY='hamcare.apple-redirect-consent.v1';
const CLOCK=Date.UTC(2026,10,15,9);
const SAFARI='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Version/18.0 Mobile/15E148 Safari/604.1';
const FIXED='hamster-breeding-app.firebaseapp.com';
const PREVIEW='https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
const marker=(overrides={})=>JSON.stringify({version:'apple-linking-v1',accepted:true,method:'redirect',startedAt:CLOCK,...overrides});
function storage(initial){const values=new Map(initial===undefined?[]:[[APPLE_KEY,initial]]);return {values,writes:[],removals:[],getItem:key=>values.get(key)??null,setItem(key,value){this.writes.push({key,value});values.set(key,value);},removeItem(key){this.removals.push(key);values.delete(key);}};}
const context=(session,overrides={})=>({pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:SAFARI,platform:'iPhone',maxTouchPoints:1,storage:session,now:()=>CLOCK,...overrides});
for(const [name,input,expected] of [
  ['fixed same-origin mobile Safari',{pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:SAFARI,redirectStateAvailable:true},'redirect'],
  ['current cross-origin Preview',{pageOrigin:PREVIEW,authDomain:FIXED,userAgent:SAFARI,redirectStateAvailable:true},'popup'],
  ['desktop Safari',{pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:'Mozilla/5.0 (Macintosh) Version/18.0 Safari/605.1.15',redirectStateAvailable:true},'popup'],
  ['iOS Chrome',{pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:SAFARI+' CriOS/130.0',redirectStateAvailable:true},'popup'],
  ['Android Chrome',{pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:'Mozilla/5.0 Android Chrome/130 Safari/537',redirectStateAvailable:true},'popup'],
  ['iPad desktop UA',{pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:'Mozilla/5.0 Macintosh Version/18.0 Safari/605.1.15',platform:'MacIntel',maxTouchPoints:5,redirectStateAvailable:true},'redirect'],
  ['storage unavailable',{pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:SAFARI,redirectStateAvailable:false},'popup'],
  ['non-boolean storage availability',{pageOrigin:'https://'+FIXED,authDomain:FIXED,userAgent:SAFARI,redirectStateAvailable:'true'},'popup'],
  ['non-HTTPS page',{pageOrigin:'http://'+FIXED,authDomain:FIXED,userAgent:SAFARI,redirectStateAvailable:true},'popup'],
  ['origin contains path',{pageOrigin:'https://'+FIXED+'/account/',authDomain:FIXED,userAgent:SAFARI,redirectStateAvailable:true},'popup'],
  ['untrusted origin',{pageOrigin:'https://untrusted.invalid',authDomain:FIXED,userAgent:SAFARI,redirectStateAvailable:true},'popup'],
  ['missing context',{},'popup'],
])test('Apple flow selector: '+name,()=>assert.equal(selectAppleSignInMethod(input),expected));
for(const consent of [undefined,null,true,{},[],{linkingConsent:false},{linkingConsent:'true'},
  {linkingConsent:1},{linkingConsent:true,method:'redirect'},{linkingConsent:true,returnUrl:'https://untrusted.invalid'}])test('unconfirmed or arbitrary Apple consent cannot start OAuth: '+JSON.stringify(consent),async()=>{
  const f=await readyHarness({enabled:true});await expectCode(()=>f.service.signInApple(consent),'account/apple-consent-required');
  assert.equal(f.calls.providers.length,0);assert.equal(f.calls.popup.length,0);assert.equal(f.calls.redirectStart.length,0);assert.equal(f.calls.redirectResult,0);assert.equal(f.calls.reads.length,0);
});
test('current Preview selects Popup and keeps consent only in the current call',async()=>{
  const session=storage();const f=await readyHarness({enabled:true,context:context(session,{pageOrigin:PREVIEW})});
  assert.equal(f.service.appleSignInMethod,'popup');await f.service.signInApple({linkingConsent:true});
  assert.equal(f.calls.popup.length,1);assert.equal(f.calls.redirectStart.length,0);assert.deepEqual(session.writes,[]);
});
test('same-origin mobile Safari Redirect carries only a short-lived nonsecret consent marker',async()=>{
  const session=storage();const f=await readyHarness({enabled:true,context:context(session)});
  assert.equal(f.service.appleSignInMethod,'redirect');assert.deepEqual(await f.service.signInApple({linkingConsent:true}),{redirecting:true});
  assert.equal(f.calls.redirectStart.length,1);assert.equal(f.calls.popup.length,0);assert.equal(f.observations.at(-1),null);
  await expectCode(()=>f.service.readAccountSummary(),'account/session-changed');
  assert.equal(session.writes.length,1);assert.deepEqual(JSON.parse(session.values.get(APPLE_KEY)),JSON.parse(marker()));
  assert.doesNotMatch(session.writes[0].value,/synthetic|privaterelay|uid|email|token|nonce|authorization|https/i);
  await f.service.signOut();assert.equal(session.values.has(APPLE_KEY),false);
});
test('Redirect marker storage failure stops before either authentication SDK method',async()=>{
  const session=storage();session.setItem=()=>{throw Error('browser storage blocked');};const f=await readyHarness({enabled:true,context:context(session)});
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/apple-redirect-unavailable');
  assert.equal(f.calls.redirectStart.length,0);assert.equal(f.calls.popup.length,0);
});
test('Redirect start rejection consumes the consent marker and hides no stale account details',async()=>{
  const session=storage();const f=await readyHarness({enabled:true,context:context(session)});f.options.redirectStart=async()=>{throw {code:'auth/network-request-failed'};};
  await expectCode(()=>f.service.signInApple({linkingConsent:true}),'auth/network-request-failed');assert.equal(session.values.has(APPLE_KEY),false);assert.equal(f.observations.at(-1),null);
});
test('bootstrap hides SDK-restored Apple identity until Redirect result and prior consent are verified once',async()=>{
  const session=storage(marker()),gate=deferred();const f=harness({enabled:true,current:apple(),context:context(session)});
  f.options.redirectResult=()=>gate.promise;assert.equal(f.observations.at(-1),null);
  await expectCode(()=>f.service.readAccountSummary(),'account/session-changed');
  const starting=f.service.ready();await new Promise(resolve=>setImmediate(resolve));assert.equal(f.calls.redirectResult,1);f.notify();assert.equal(f.observations.at(-1),null);
  gate.resolve(f.resolveApple());await starting;assert.deepEqual(f.observations.at(-1).methods,['Apple']);assert.equal(session.values.has(APPLE_KEY),false);
  await f.service.ready();assert.equal(f.calls.redirectResult,1);assert.equal(f.calls.reads.length,0);
});
for(const raw of ['invalid-json',marker({accepted:false}),marker({startedAt:CLOCK-15*60000}),marker({startedAt:CLOCK+1}),
  marker({version:'other-version'}),marker({uid:'synthetic-private'})])test('invalid/expired Redirect consent is rejected before result SDK: '+raw,async()=>{
  const session=storage(raw);const f=harness({enabled:true,current:apple(),context:context(session)});
  await expectCode(()=>f.service.ready(),'account/apple-consent-required');assert.equal(f.calls.redirectResult,0);assert.equal(f.calls.popup.length,0);
  assert.equal(f.auth.currentUser,null);assert.equal(session.values.has(APPLE_KEY),false);assert.equal(f.calls.reads.length,0);
});
test('a saved Redirect marker cannot force cross-origin Redirect restoration on Preview',async()=>{
  const session=storage(marker());const f=harness({enabled:true,current:apple(),context:context(session,{pageOrigin:PREVIEW})});
  await expectCode(()=>f.service.ready(),'account/apple-redirect-unavailable');assert.equal(f.calls.redirectResult,0);assert.equal(f.auth.currentUser,null);assert.equal(session.values.has(APPLE_KEY),false);
});
test('disabled Apple performs no Redirect SDK work even if a prior public marker exists',async()=>{
  const f=harness({enabled:false,current:apple(),context:context(storage(marker()))});await f.service.ready();
  assert.equal(f.calls.redirectResult,0);assert.equal(f.calls.redirectStart.length,0);await expectCode(()=>f.service.signInApple({linkingConsent:true}),'account/apple-setup-required');
});
test('null Redirect result is cancellation, clears consent, and leaves no authenticated identity',async()=>{
  const session=storage(marker());const f=harness({enabled:true,current:apple(),context:context(session)});
  await expectCode(()=>f.service.ready(),'auth/popup-closed-by-user');assert.equal(f.calls.redirectResult,1);assert.equal(f.auth.currentUser,null);assert.equal(session.values.has(APPLE_KEY),false);
});
test('a Redirect result without Apple identity is discarded rather than exposed to billing',async()=>{
  const session=storage(marker());const f=harness({enabled:true,context:context(session)});f.options.redirectResult=async()=>f.resolveApple(apple(A,{providerData:[{providerId:'google.com'}]}));
  await expectCode(()=>f.service.ready(),'account/apple-identity-invalid');assert.equal(f.auth.currentUser,null);assert.equal(f.calls.reads.length,0);assert.equal(session.values.has(APPLE_KEY),false);
});
test('logout wins during Redirect result recovery and invalidates the pending consent marker',async()=>{
  const session=storage(marker()),gate=deferred();const f=harness({enabled:true,context:context(session)});f.options.redirectResult=()=>gate.promise;
  const starting=f.service.ready();await new Promise(resolve=>setImmediate(resolve));await f.service.signOut();const since=f.observations.length;
  gate.resolve(f.resolveApple());await starting;assert.equal(f.auth.currentUser,null);assert.equal(f.calls.signOut,2);assert.equal(session.values.has(APPLE_KEY),false);assert.ok(f.observations.slice(since).every(value=>value===null));
});
test('consent expiring while Redirect result waits cannot release an authenticated identity',async()=>{
  let time=CLOCK;const session=storage(marker()),gate=deferred();const f=harness({enabled:true,context:context(session,{now:()=>time})});f.options.redirectResult=()=>gate.promise;
  const starting=f.service.ready();await new Promise(resolve=>setImmediate(resolve));time+=15*60000;gate.resolve(f.resolveApple());
  await expectCode(()=>starting,'account/apple-consent-required');assert.equal(f.auth.currentUser,null);assert.equal(session.values.has(APPLE_KEY),false);
});
test('new Redirect Apple user remains blocked by the existing app-account guard',async()=>{
  const session=storage(marker());const f=harness({enabled:true,pet:'missing',context:context(session)});f.options.redirectResult=async()=>f.resolveApple(apple(B),true);
  await f.service.ready();assert.equal(f.observations.at(-1).isNewUser,true);const summary=await f.service.readAccountSummary();assert.equal(summary.appAccountExists,false);assert.equal(summary.planReview.canSelectPlan,false);
});

for(const [name,consent] of [['inherited consent',Object.create({linkingConsent:true})],
  ['array with own consent',Object.assign([],{linkingConsent:true})],
  ['own consent plus extra key',{linkingConsent:true,uid:'synthetic-untrusted'}]])test('Apple consent must be an own confirmed field on the approved request: '+name,async()=>{
  const f=await readyHarness({enabled:true});await expectCode(()=>f.service.signInApple(consent),'account/apple-consent-required');
  assert.equal(f.calls.providers.length,0);assert.equal(f.calls.popup.length,0);assert.equal(f.calls.redirectStart.length,0);assert.equal(f.calls.redirectResult,0);assert.equal(f.calls.reads.length,0);
});
