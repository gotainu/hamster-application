import test from 'node:test';
import assert from 'node:assert/strict';
import {createPreviewCheckoutService,PREVIEW_CHECKOUT_ENDPOINT,PREVIEW_PORTAL_ENDPOINT} from '../public/assets/checkout-service.mjs';
import {projectCheckoutReview} from '../public/assets/checkout-model.mjs';
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
const PROJECT='demo-hamcare-web-apple-task8';
function tokenResult(user,provider='password',token='synthetic-auth-header-only') { return {token,signInProvider:provider,claims:{aud:PROJECT,iss:'https://securetoken.google.com/'+PROJECT,sub:user.uid,email_verified:user.emailVerified===true,firebase:{sign_in_provider:provider,identities:{'apple.com':['synthetic-apple-subject']}}}}; }
function harness(){const calls=[];const user={uid:'synthetic-user-a',email:'synthetic@example.test',emailVerified:true,providerData:[{providerId:'password'}]};const tokenCalls=[];user.getIdTokenResult=async force=>{tokenCalls.push(force);return tokenResult(user);};const auth={app:{options:{projectId:PROJECT}},currentUser:user};const fetchRequest=async(url,options)=>{calls.push({url,options});return {ok:true,json:async()=>({testMode:true})};};return {auth,calls,fetchRequest,tokenCalls};}
const reviewQuote = maskedEmail => ({testMode:true,planKey:'premium_monthly',amount:550,currency:'jpy',interval:'month',reviewToken:'synthetic_review_proof_12345',account:{nickname:'テスト',maskedEmail},billing:{kind:'immediate',cardRegistrationAt:'2026-11-15T01:00:00Z',firstChargeAt:'2026-11-15T01:00:00Z',firstChargeAmount:550,trialEndsAt:null}});
function appleReviewHarness() {
 const h=harness(),user=h.auth.currentUser;user.email=null;user.emailVerified=false;user.providerData=[{providerId:'apple.com',uid:'synthetic-apple-subject'}];
 user.getIdTokenResult=async force=>{h.tokenCalls.push(force);return tokenResult(user,'apple.com');};
 h.profileReads=[];h.readOwnProfiles=async uid=>{h.profileReads.push(uid);return {ownerExists:true,petExists:true};};
 h.fetchRequest=async(url,options)=>{h.calls.push({url,options});return {ok:true,status:200,json:async()=>reviewQuote('未設定')};};return h;
}
test('all operations use exact endpoint, POST Authorization and only allowlisted business key',async()=>{const h=harness();const service=createPreviewCheckoutService(h);await service.reviewPreviewCheckout();await service.createPreviewCheckout({reviewToken:'synthetic-review-proof',termsAccepted:true,uid:'untrusted',priceId:'untrusted',trial_end:1});await service.getPreviewCheckoutStatus();await service.cancelPreviewCheckout();await service.getPreviewBilling();assert.equal(h.calls.length,5);for(const {url,options} of h.calls){assert.ok(url.startsWith(PREVIEW_CHECKOUT_ENDPOINT+'/'));assert.ok(!url.includes('synthetic-auth'));assert.equal(options.method,'POST');assert.equal(options.credentials,'omit');assert.equal(options.cache,'no-store');assert.equal(options.headers.Authorization,'Bearer synthetic-auth-header-only');assert.equal(JSON.parse(options.body).planKey,'premium_monthly');assert.doesNotMatch(options.body,/synthetic-user|untrusted|priceId|trial_end|amount/);}assert.deepEqual(Object.keys(JSON.parse(h.calls[1].options.body)).sort(),['planKey','reviewToken','termsAccepted']);});
test('unverified and empty sessions never send a request',async()=>{for(const currentUser of [null,{uid:'synthetic',emailVerified:false}]){const h=harness();h.auth.currentUser=currentUser;await assert.rejects(createPreviewCheckoutService(h).reviewPreviewCheckout(),e=>e.code==='unauthenticated');assert.equal(h.calls.length,0);}});
test('switching identities while token refresh is pending prevents submission',async()=>{const h=harness(),wait=deferred();h.auth.currentUser.getIdTokenResult=()=>wait.promise;const pending=createPreviewCheckoutService(h).reviewPreviewCheckout();h.auth.currentUser={uid:'synthetic-user-b',emailVerified:true};wait.resolve('synthetic-token');await assert.rejects(pending,e=>e.code==='session_changed');assert.equal(h.calls.length,0);});
test('switching identities during response discards private result',async()=>{const h=harness(),wait=deferred();h.fetchRequest=()=>wait.promise;const pending=createPreviewCheckoutService(h).reviewPreviewCheckout();await Promise.resolve();h.auth.currentUser={uid:'synthetic-user-b',emailVerified:true};wait.resolve({ok:true,json:async()=>({private:'not-returned'})});await assert.rejects(pending,e=>e.code==='session_changed');});
test('clear aborts pending fetch and invalidates later responses',async()=>{const h=harness(),wait=deferred();let signal;h.fetchRequest=async(_,o)=>{signal=o.signal;return wait.promise;};const s=createPreviewCheckoutService(h);const pending=s.reviewPreviewCheckout();await Promise.resolve();s.clear();assert.equal(signal.aborted,true);wait.resolve({ok:true,json:async()=>({})});await assert.rejects(pending,e=>e.code==='session_changed');});
test('unknown error details never leave service and endpoint overrides are forbidden',async()=>{const h=harness();h.fetchRequest=async()=>({ok:false,json:async()=>({code:'trial_unresolved',message:'private',uid:'private'})});await assert.rejects(createPreviewCheckoutService(h).reviewPreviewCheckout(),e=>Object.keys(e).length===1&&e.code==='trial_unresolved');assert.throws(()=>createPreviewCheckoutService({...h,endpoint:'https://untrusted.invalid'}));});

test('billing mirror read posts only the plan key with current Firebase authentication',async()=>{const h=harness();await createPreviewCheckoutService(h).getPreviewBilling();assert.equal(h.calls.length,1);assert.equal(h.calls[0].url,PREVIEW_CHECKOUT_ENDPOINT+'/billing');assert.deepEqual(JSON.parse(h.calls[0].options.body),{planKey:'premium_monthly'});assert.equal(h.calls[0].options.headers.Authorization,'Bearer synthetic-auth-header-only');});
test('billing mirror response is discarded when identity changes during the read',async()=>{const h=harness(),wait=deferred();h.fetchRequest=()=>wait.promise;const pending=createPreviewCheckoutService(h).getPreviewBilling();await Promise.resolve();h.auth.currentUser={uid:'synthetic-user-b',emailVerified:true};wait.resolve({ok:true,json:async()=>({testMode:true,syncState:'synced',billing:{private:'other-user'}})});await assert.rejects(pending,e=>e.code==='session_changed');});


test('Portal creation uses dedicated exact endpoint, ID token header and an empty body',async()=>{
 const h=harness();const service=createPreviewCheckoutService(h);await service.createPreviewPortalSession({uid:'untrusted',customerId:'untrusted',subscriptionId:'untrusted',returnUrl:'https://evil.invalid'});
 assert.equal(h.calls.length,1);const {url,options}=h.calls[0];assert.equal(url,PREVIEW_PORTAL_ENDPOINT);assert.equal(options.method,'POST');assert.equal(options.credentials,'omit');assert.equal(options.cache,'no-store');assert.equal(options.referrerPolicy,'no-referrer');assert.equal(options.headers.Authorization,'Bearer synthetic-auth-header-only');assert.deepEqual(JSON.parse(options.body),{});assert.doesNotMatch(url+options.body,/untrusted|synthetic-user|synthetic-auth|returnUrl|customerId|subscriptionId/);
});
test('Portal creation rejects unauthenticated and unverified sessions without a network call',async()=>{
 for(const currentUser of [null,{uid:'',emailVerified:true},{uid:'synthetic',emailVerified:false}]){const h=harness();h.auth.currentUser=currentUser;await assert.rejects(createPreviewCheckoutService(h).createPreviewPortalSession(),e=>e.code==='unauthenticated');assert.equal(h.calls.length,0);}
});
test('Portal destination is rejected after UID switch, email verification change or logout',async()=>{
 for(const change of ['uid','verification','logout']){const h=harness(),wait=deferred();h.fetchRequest=()=>wait.promise;const service=createPreviewCheckoutService(h);const pending=service.createPreviewPortalSession();await Promise.resolve();if(change==='uid')h.auth.currentUser={uid:'synthetic-user-b',emailVerified:true};if(change==='verification')h.auth.currentUser.emailVerified=false;if(change==='logout'){h.auth.currentUser=null;service.clear();}wait.resolve({ok:true,json:async()=>({testMode:true,url:'https://billing.stripe.com/p/session/test_neverUsed'})});await assert.rejects(pending,e=>e.code==='session_changed');}
});
test('Portal errors expose only safe codes and clear aborts pending creation',async()=>{
 const h=harness();h.fetchRequest=async()=>({ok:false,json:async()=>({code:'portal_not_available',url:'private',customerId:'private'})});await assert.rejects(createPreviewCheckoutService(h).createPreviewPortalSession(),e=>Object.keys(e).length===1&&e.code==='portal_not_available');
 const wait=deferred();let signal;h.fetchRequest=async(_,o)=>{signal=o.signal;return wait.promise;};const service=createPreviewCheckoutService(h);const pending=service.createPreviewPortalSession();await Promise.resolve();service.clear();assert.equal(signal.aborted,true);wait.resolve({ok:true,json:async()=>({})});await assert.rejects(pending,e=>e.code==='session_changed');
});


test('every operation accepts current email-less Apple only through a fresh project- and subject-bound SDK result',async()=>{
 const h=harness(),user=h.auth.currentUser;user.emailVerified=false;user.email=null;user.providerData=[{providerId:'apple.com',uid:'synthetic-apple-subject'}];user.getIdTokenResult=async force=>{h.tokenCalls.push(force);return tokenResult(user,'apple.com');};
 const service=createPreviewCheckoutService(h);await service.reviewPreviewCheckout();await service.getPreviewBilling();await service.createPreviewPortalSession();assert.equal(user.emailVerified,false);assert.deepEqual(h.tokenCalls,[true,true,true]);
 for(const call of h.calls)assert.doesNotMatch(call.options.body,/authBasis|identityVerified|emailVerified|subject|synthetic-user/);
});
test('an unverified Google session linked with Apple is not an Apple login',async()=>{
 const h=harness(),user=h.auth.currentUser;user.emailVerified=false;user.providerData=[{providerId:'google.com',uid:'synthetic-google'},{providerId:'apple.com',uid:'synthetic-apple-subject'}];user.getIdTokenResult=async()=>tokenResult(user,'google.com');
 await assert.rejects(createPreviewCheckoutService(h).getPreviewBilling(),e=>e.code==='unauthenticated');assert.equal(h.calls.length,0);
});
for(const [name,alter] of [
 ['audience',r=>{r.claims.aud='other-project';}],
 ['issuer',r=>{r.claims.iss='https://securetoken.google.com/other-project';}],
 ['UID',r=>{r.claims.sub='other-owner';}],
 ['Apple subject',r=>{r.claims.firebase.identities['apple.com']=['other-apple'];}],
])test('transport refuses fresh Apple token with wrong '+name,async()=>{
 const h=harness(),user=h.auth.currentUser;user.emailVerified=false;user.providerData=[{providerId:'apple.com',uid:'synthetic-apple-subject'}];user.getIdTokenResult=async()=>{const r=tokenResult(user,'apple.com');alter(r);return r;};await assert.rejects(createPreviewCheckoutService(h).getPreviewBilling(),e=>e.code==='unauthenticated');assert.equal(h.calls.length,0);
});
test('401 retries once with refreshed identity but preserves exact empty Portal body',async()=>{
 const h=harness(),user=h.auth.currentUser;let tokens=0;user.getIdTokenResult=async force=>{assert.equal(force,true);return tokenResult(user,'password','synthetic-token-'+(++tokens));};h.fetchRequest=async(url,options)=>{h.calls.push({url,options});return h.calls.length===1?{ok:false,status:401,json:async()=>{throw Error('401 payload must not be rendered');}}:{ok:true,status:200,json:async()=>({testMode:true})};};await createPreviewCheckoutService(h).createPreviewPortalSession();assert.equal(tokens,2);assert.equal(h.calls.length,2);assert.deepEqual(h.calls.map(c=>JSON.parse(c.options.body)),[{},{}]);assert.deepEqual(h.calls.map(c=>c.options.headers.Authorization),['Bearer synthetic-token-1','Bearer synthetic-token-2']);
});
test('second 401 stops rather than repeatedly retrying',async()=>{
 const h=harness();h.fetchRequest=async(url,options)=>{h.calls.push({url,options});return {ok:false,status:401,json:async()=>({code:'unauthenticated',message:'private'})};};await assert.rejects(createPreviewCheckoutService(h).getPreviewBilling(),e=>e.code==='unauthenticated');assert.equal(h.calls.length,2);
});
test('401 refreshed Google token cannot reuse a previous unverified Apple identity',async()=>{
 const h=harness(),user=h.auth.currentUser;user.emailVerified=false;user.providerData=[{providerId:'apple.com',uid:'synthetic-apple-subject'}];let n=0;user.getIdTokenResult=async()=>tokenResult(user,++n===1?'apple.com':'google.com');h.fetchRequest=async(url,options)=>{h.calls.push({url,options});return {ok:false,status:401};};await assert.rejects(createPreviewCheckoutService(h).getPreviewBilling(),e=>e.code==='unauthenticated');assert.equal(h.calls.length,1);
});
test('unknown mutation or business failure is never retried',async()=>{
 for(const failure of ['network','business']){const h=harness();h.fetchRequest=async(url,options)=>{h.calls.push({url,options});if(failure==='network')throw TypeError('private network data');return {ok:false,status:409,json:async()=>({code:'existing_subscription'})};};await assert.rejects(createPreviewCheckoutService(h).createPreviewCheckout({reviewToken:'synthetic',termsAccepted:true}),e=>e.code===(failure==='network'?'network_error':'existing_subscription'));assert.equal(h.calls.length,1);}
});
test('same-UID replacement SDK user also invalidates the in-flight response',async()=>{
 const h=harness(),wait=deferred();h.fetchRequest=()=>wait.promise;const pending=createPreviewCheckoutService(h).getPreviewBilling();await Promise.resolve();h.auth.currentUser={...h.auth.currentUser};wait.resolve({ok:true,json:async()=>({private:'not-returned'})});await assert.rejects(pending,e=>e.code==='session_changed');
});

test('server-declared unavailable Apple email is accepted only with current own owner and pet reads',async()=>{
 const h=appleReviewHarness(),service=createPreviewCheckoutService(h),raw=await service.reviewPreviewCheckout();
 assert.deepEqual(h.profileReads,['synthetic-user-a']);assert.equal(service.isVerifiedMissingEmailReview(raw),true);
 const model=projectCheckoutReview(raw,service.isVerifiedMissingEmailReview);assert.equal(model.maskedEmail,'未設定');
 assert.doesNotMatch(JSON.stringify(model),/synthetic-user|synthetic-apple|synthetic-auth|apple-e2e@/);
 assert.equal(h.calls.length,1);assert.equal(h.calls[0].url,PREVIEW_CHECKOUT_ENDPOINT+'/review');
 assert.deepEqual(JSON.parse(h.calls[0].options.body),{planKey:'premium_monthly'});assert.equal(h.auth.currentUser.email,null);
});
test('unavailable server email also covers an Apple email omitted because it is unverified',async()=>{
 const h=appleReviewHarness();h.auth.currentUser.email='synthetic-unverified@example.test';
 const service=createPreviewCheckoutService(h),raw=await service.reviewPreviewCheckout();
 assert.equal(projectCheckoutReview(raw,service.isVerifiedMissingEmailReview).maskedEmail,'未設定');
 assert.equal(h.auth.currentUser.email,'synthetic-unverified@example.test');assert.equal(h.auth.currentUser.emailVerified,false);
});
test('a locally invented missing-email response cannot borrow another response or service proof',async()=>{
 const h=appleReviewHarness(),service=createPreviewCheckoutService(h),raw=await service.reviewPreviewCheckout();
 for(const other of [{...raw},JSON.parse(JSON.stringify(raw)),reviewQuote('未設定')]){
  assert.equal(service.isVerifiedMissingEmailReview(other),false);assert.throws(()=>projectCheckoutReview(other,service.isVerifiedMissingEmailReview));
 }
 const otherService=createPreviewCheckoutService(h);assert.equal(otherService.isVerifiedMissingEmailReview(raw),false);
 service.clear();assert.equal(service.isVerifiedMissingEmailReview(raw),false);assert.throws(()=>projectCheckoutReview(raw,service.isVerifiedMissingEmailReview));
});
for(const [label,profiles] of [['missing owner',{ownerExists:false,petExists:true}],['missing pet',{ownerExists:true,petExists:false}],['new empty UID',{ownerExists:false,petExists:false}],['unresolved read',null]]){
 test('missing email cannot pass review for '+label,async()=>{
  const h=appleReviewHarness();h.readOwnProfiles=async()=>profiles;
  await assert.rejects(createPreviewCheckoutService(h).reviewPreviewCheckout(),e=>e.code==='app_account_required');
  assert.ok(h.calls.every(c=>!c.url.endsWith('/session')));
 });
}
test('missing profile reader and denied reads fail closed',async()=>{
 for(const reader of [undefined,async()=>{throw {code:'permission-denied',message:'private'};}]){
  const h=appleReviewHarness();h.readOwnProfiles=reader;
  await assert.rejects(createPreviewCheckoutService(h).reviewPreviewCheckout(),e=>['invalid_response','app_account_required'].includes(e.code));
 }
});
for(const change of ['logout','different UID','same UID replacement','same object UID','Apple subject','clear']){
 test('pending own-profile read rejects '+change,async()=>{
  const h=appleReviewHarness(),wait=deferred();let entered;const reading=new Promise(r=>{entered=r;});
  h.readOwnProfiles=async()=>{entered();return wait.promise;};const service=createPreviewCheckoutService(h),pending=service.reviewPreviewCheckout();await reading;
  if(change==='logout')h.auth.currentUser=null;
  if(change==='different UID')h.auth.currentUser={...h.auth.currentUser,uid:'synthetic-user-b'};
  if(change==='same UID replacement')h.auth.currentUser={...h.auth.currentUser};
  if(change==='same object UID')h.auth.currentUser.uid='synthetic-user-b';
  if(change==='Apple subject')h.auth.currentUser.providerData=[{providerId:'apple.com',uid:'different-subject'}];
  if(change==='clear')service.clear();
  wait.resolve({ownerExists:true,petExists:true});await assert.rejects(pending,e=>e.code==='session_changed');
 });
}
test('proof is rejected after replacement or in-place UID change even after review returned',async()=>{
 for(const replace of [false,true]){const h=appleReviewHarness(),service=createPreviewCheckoutService(h),raw=await service.reviewPreviewCheckout();
  if(replace)h.auth.currentUser={...h.auth.currentUser};else h.auth.currentUser.uid='synthetic-user-b';
  assert.equal(service.isVerifiedMissingEmailReview(raw),false);
 }
});
test('returned response proof also rejects a changed or removed Apple binding',async()=>{
 for(const providers of [undefined,null,[],[{providerId:'google.com',uid:'synthetic-google'}],[{providerId:'apple.com',uid:'different-subject'}],[null],[Object.assign([],{providerId:'apple.com',uid:'synthetic-apple-subject'})],[{providerId:'apple.com',uid:'synthetic-apple-subject'},{providerId:'apple.com',uid:'synthetic-apple-subject'}]]){
  const h=appleReviewHarness(),service=createPreviewCheckoutService(h),raw=await service.reviewPreviewCheckout();h.auth.currentUser.providerData=providers;
  assert.equal(service.isVerifiedMissingEmailReview(raw),false);assert.throws(()=>projectCheckoutReview(raw,service.isVerifiedMissingEmailReview));
 }
});
test('unavailable email cannot become an exception for verified password or Google sessions',async()=>{
 for(const provider of ['password','google.com']){const h=harness();h.auth.currentUser.providerData=[{providerId:provider}];h.auth.currentUser.getIdTokenResult=async()=>tokenResult(h.auth.currentUser,provider);let reads=0;
  h.readOwnProfiles=async()=>{reads++;return {ownerExists:true,petExists:true};};h.fetchRequest=async()=>({ok:true,json:async()=>reviewQuote('未設定')});
  await assert.rejects(createPreviewCheckoutService(h).reviewPreviewCheckout(),e=>e.code==='invalid_response');assert.equal(reads,0);
 }
});
test('existing password, Google and Apple masked-email reviews need no missing-email exception',async()=>{
 for(const provider of ['password','google.com','apple.com']){
  const h=provider==='apple.com'?appleReviewHarness():harness();h.auth.currentUser.getIdTokenResult=async()=>tokenResult(h.auth.currentUser,provider);
  h.fetchRequest=async()=>({ok:true,json:async()=>reviewQuote('go***@example.com')});let reads=0;h.readOwnProfiles=async()=>{reads++;throw Error('must not read');};
  const service=createPreviewCheckoutService(h),raw=await service.reviewPreviewCheckout();assert.equal(projectCheckoutReview(raw,service.isVerifiedMissingEmailReview).maskedEmail,'go***@example.com');assert.equal(reads,0);
 }
});
