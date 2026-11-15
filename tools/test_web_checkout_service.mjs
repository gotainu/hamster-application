import test from 'node:test';
import assert from 'node:assert/strict';
import {createPreviewCheckoutService,PREVIEW_CHECKOUT_ENDPOINT,PREVIEW_PORTAL_ENDPOINT} from '../public/assets/checkout-service.mjs';
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
const PROJECT='demo-hamcare-web-apple-task8';
function tokenResult(user,provider='password',token='synthetic-auth-header-only') { return {token,signInProvider:provider,claims:{aud:PROJECT,iss:'https://securetoken.google.com/'+PROJECT,sub:user.uid,email_verified:user.emailVerified===true,firebase:{sign_in_provider:provider,identities:{'apple.com':['synthetic-apple-subject']}}}}; }
function harness(){const calls=[];const user={uid:'synthetic-user-a',email:'synthetic@example.test',emailVerified:true,providerData:[{providerId:'password'}]};const tokenCalls=[];user.getIdTokenResult=async force=>{tokenCalls.push(force);return tokenResult(user);};const auth={app:{options:{projectId:PROJECT}},currentUser:user};const fetchRequest=async(url,options)=>{calls.push({url,options});return {ok:true,json:async()=>({testMode:true})};};return {auth,calls,fetchRequest,tokenCalls};}
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
