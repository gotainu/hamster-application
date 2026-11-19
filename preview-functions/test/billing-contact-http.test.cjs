'use strict';
// Direct Functions handler with synthetic Auth/facts/store only. No outbound I/O.
const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const {EventEmitter}=require('node:events');
const {createHash}=require('node:crypto');
process.env.GCLOUD_PROJECT='demo-hamcare-contact-http';
process.env.FIREBASE_CONFIG=JSON.stringify({projectId:process.env.GCLOUD_PROJECT});
process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:1';
const handler=require('../lib/preview-functions/src/index').previewBillingContactEmail;
const auth=require('firebase-admin/auth').getAuth();
const runtime=require('../lib/preview-functions/src/preview-runtime');
const stores=require('../lib/preview-functions/src/billing-contact-store');
const {CONTACT_MAIL_SECRET}=require('../lib/preview-functions/src/billing-contact-mail');
const ORIGIN='https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
const UID='synthetic-contact-http-owner',SUBJECT='synthetic-contact-http-apple';
const hash=v=>createHash('sha256').update(v).digest('hex');
let calls, user, decoded, states;
const originalFetch=globalThis.fetch;
globalThis.fetch=async()=>{if(calls)calls.network.push('unexpected-outbound-attempt');throw new Error('Synthetic test forbids network');};
after(()=>{globalThis.fetch=originalFetch;});
function reset() {
  calls={verify:[],getUser:[],facts:[],read:[],write:[],network:[]};states=new Map();
  user={uid:UID,disabled:false,emailVerified:false,providerData:[{providerId:'apple.com',uid:SUBJECT}]};
  decoded={uid:UID,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':[SUBJECT]}}};
  auth.verifyIdToken=async(value,revoked)=>{calls.verify.push({value,revoked});return decoded;};
  auth.getUser=async uid=>{calls.getUser.push(uid);return user;};
  runtime.readPreviewFacts=async uid=>{calls.facts.push(uid);return {appAccountExists:true};};
  stores.createFirestoreBillingContactStore=()=>({
    async read(uid){calls.read.push(uid);return structuredClone(states.get(uid)||{});},
    async mutate(uid,fn){const next=fn(structuredClone(states.get(uid)||{}));calls.write.push(uid);states.set(uid,structuredClone(next.state));return next.result;},
  });
  process.env[CONTACT_MAIL_SECRET]='synthetic-invalid-json-secret-that-status-must-not-read';
}
class Response extends EventEmitter {
  constructor(){super();this.statusCode=200;this.headers={};}
  set(key,value){this.headers[key]=value;return this;}
  status(value){this.statusCode=value;return this;}
  json(value){this.value=value;return this;}
  send(value){this.value=value;return this;}
}
function request(extra={}) {
  const headers={Origin:ORIGIN,Authorization:'Bearer synthetic-current-token'};
  return Object.assign(new EventEmitter(),{method:'POST',path:'/status',url:'/status',originalUrl:'/status',query:{},body:{},rawBody:Buffer.from('{}'),get:key=>headers[key],is:type=>type==='application/json'},extra);
}
async function run(req){const res=new Response();await handler(req,res);return res;}
const noMutation=()=>{assert.deepEqual(calls.write,[]);assert.deepEqual(calls.network,[]);};
const noAuthentication=()=>{assert.deepEqual(calls.verify,[]);assert.deepEqual(calls.getUser,[]);assert.deepEqual(calls.facts,[]);assert.deepEqual(calls.read,[]);noMutation();};
function enabledConfig(subject=UID){return JSON.stringify({enabled:true,environment:'preview',from:'gotainu@gmail.com',allowedSubjectHashes:[hash(subject)],allowedRecipientHashes:[hash('synthetic-recipient@example.test')],clientId:'synthetic-preview.apps.googleusercontent.com',clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token-only'});}

test('contact HTTP rejects untrusted or missing Origin before authentication and mail configuration',async()=>{
  for(const origin of ['https://untrusted.example.test',undefined,'null']){reset();const res=await run(request({get:key=>key==='Origin'?origin:'Bearer synthetic'}));assert.equal(res.statusCode,403);assert.deepEqual(res.value,{code:'origin_not_allowed'});assert.equal(res.headers['Access-Control-Allow-Origin'],undefined);noAuthentication();}
});
test('contact preflight permits only exact Origin POST and explicit headers without cookies',async()=>{
  reset();const res=await run(request({method:'OPTIONS'}));assert.equal(res.statusCode,204);assert.equal(res.headers['Access-Control-Allow-Origin'],ORIGIN);assert.equal(res.headers['Access-Control-Allow-Methods'],'POST');assert.equal(res.headers['Access-Control-Allow-Headers'],'Authorization, Content-Type');assert.equal(res.headers['Access-Control-Allow-Credentials'],undefined);noAuthentication();
});
test('contact HTTP rejects wrong method, content type, path, query, body and oversize before Auth',async()=>{
  for(const extra of [{method:'GET'},{is:()=>false},{path:'/other'},{path:'//status'},{query:{token:'synthetic'}},{query:{uid:UID}},{body:null},{body:[]},{body:{email:'synthetic@example.test'}},{rawBody:'{}'},{rawBody:Buffer.alloc(2049)},{path:'/request',body:{}},{path:'/confirm',body:{}}]){
    reset();const res=await run(request(extra));assert.equal(res.statusCode,400);assert.deepEqual(res.value,{code:'request_invalid'});noAuthentication();
  }
});
test('client identity, verified flags and routing fields never reach Auth or the store',async()=>{
  for(const op of ['status','request','confirm'])for(const field of ['uid','emailVerified','verified','authBasis','provider','purpose','from','returnUrl','csrfBypass']){
    reset();const body=op==='status'?{}:op==='request'?{email:'synthetic-recipient@example.test'}:{token:'a'.repeat(43)};
    body[field]='synthetic';const res=await run(request({path:'/'+op,body}));assert.equal(res.statusCode,400);noAuthentication();
  }
});
test('missing, malformed and oversized Bearer are rejected without mail or contact reads',async()=>{
  for(const bearer of [undefined,'Basic synthetic','Bearer '+'a'.repeat(8193)]){reset();const res=await run(request({get:key=>key==='Origin'?ORIGIN:bearer}));assert.equal(res.statusCode,401);assert.deepEqual(res.value,{code:'unauthenticated'});assert.deepEqual(calls.verify,[]);noMutation();}
});
test('expired or revoked tokens expose only unauthenticated and perform no reads or writes',async()=>{
  for(const code of ['auth/argument-error','auth/id-token-expired','auth/id-token-revoked','auth/invalid-id-token','auth/user-disabled','auth/user-not-found']){
    reset();auth.verifyIdToken=async()=>{calls.verify.push(code);throw {code,message:'synthetic-private-payload@example.test'};};
    const res=await run(request());assert.equal(res.statusCode,401);assert.deepEqual(res.value,{code:'unauthenticated'});assert.deepEqual(calls.getUser,[]);assert.deepEqual(calls.read,[]);noMutation();
  }
});
test('status works without usable mail Secret and stays read-only for missing-email Apple owner',async()=>{
  reset();const before=structuredClone(user);const res=await run(request());assert.equal(res.statusCode,200);assert.equal(res.value.testMode,true);assert.equal(res.value.category,'missing');assert.equal(res.value.state,'missing');assert.equal(res.value.canCheckout,false);assert.equal(res.value.maskedEmail,null);assert.deepEqual(calls.verify,[{value:'synthetic-current-token',revoked:true}]);assert.deepEqual(calls.getUser,[UID]);assert.deepEqual(calls.facts,[UID]);assert.deepEqual(calls.read,[UID]);assert.deepEqual(user,before);noMutation();
  assert.doesNotMatch(JSON.stringify(res.value),/synthetic|token|uid|provider|@/);
});
test('status works with explicitly disabled sender configuration',async()=>{
  reset();process.env[CONTACT_MAIL_SECRET]=JSON.stringify({enabled:false,environment:'preview',from:'gotainu@gmail.com',allowedSubjectHashes:[],allowedRecipientHashes:[]});const res=await run(request());assert.equal(res.statusCode,200);assert.equal(res.value.state,'missing');noMutation();
});
test('verified normal Auth mail status bypasses additional email requests and contact storage',async()=>{
  reset();user.email='synthetic-normal@example.test';user.emailVerified=true;user.providerData=[{providerId:'password',uid:'synthetic-email-provider'}];decoded={uid:UID,email_verified:true,firebase:{sign_in_provider:'password'}};
  const res=await run(request());assert.equal(res.statusCode,200);assert.equal(res.value.category,'normal');assert.equal(res.value.state,'verified');assert.equal(res.value.maskedEmail,'sy***@example.test');assert.equal(res.value.canCheckout,true);assert.deepEqual(calls.read,[]);noMutation();assert.doesNotMatch(JSON.stringify(res.value),/synthetic-normal@/);
});
for(const domain of ['privaterelay.appleid.com','private.icloud.com'])test('verified current Apple '+domain+' status requires no supplemental email',async()=>{
  reset();user.email='synthetic-relay@'+domain;user.emailVerified=true;decoded.email_verified=true;const res=await run(request());assert.equal(res.statusCode,200);assert.equal(res.value.category,'apple_relay');assert.equal(res.value.state,'verified');assert.equal(res.value.maskedEmail,'sy***@'+domain);assert.equal(res.value.canCheckout,true);assert.deepEqual(calls.read,[]);noMutation();
});
test('unverified existing Apple email is not mislabeled as absent and cannot create checkout',async()=>{
  reset();user.email='synthetic-unverified@example.test';const res=await run(request());assert.equal(res.statusCode,200);assert.equal(res.value.category,'unverified');assert.equal(res.value.state,'unverified');assert.equal(res.value.canCheckout,false);assert.deepEqual(calls.read,[]);noMutation();
});
test('wrong Admin UID, disabled owner and mismatching Apple identity fail before reading contacts',async()=>{
  for(const alter of [()=>{user.uid='synthetic-other';},()=>{user.disabled=true;},()=>{user.providerData[0].uid='synthetic-other-provider';}]){
    reset();alter();const res=await run(request());assert.equal(res.statusCode,401);assert.deepEqual(res.value,{code:'unauthenticated'});assert.deepEqual(calls.read,[]);noMutation();
  }
});
test('missing app profile cannot read or mutate the contact namespace',async()=>{
  reset();runtime.readPreviewFacts=async uid=>{calls.facts.push(uid);return {appAccountExists:false};};const res=await run(request());assert.equal(res.statusCode,400);assert.deepEqual(res.value,{code:'app_account_required'});assert.deepEqual(calls.read,[]);noMutation();
});
test('disabled sender prevents request and confirm without contact writes or network',async()=>{
  for(const [op,body] of [['request',{email:'synthetic-recipient@example.test'}],['confirm',{token:'a'.repeat(43)}]]){
    reset();process.env[CONTACT_MAIL_SECRET]=JSON.stringify({enabled:false,environment:'preview',from:'gotainu@gmail.com',allowedSubjectHashes:[hash(UID)],allowedRecipientHashes:[hash('synthetic-recipient@example.test')]});
    const res=await run(request({path:'/'+op,body}));assert.equal(res.statusCode,400);assert.deepEqual(res.value,{code:'contact_mail_unavailable'});assert.deepEqual(calls.read,[]);noMutation();
  }
});
test('enabled sender still rejects a UID outside the explicit operator allowlist before writes',async()=>{
  for(const [op,body] of [['request',{email:'synthetic-recipient@example.test'}],['confirm',{token:'a'.repeat(43)}]]){
    reset();process.env[CONTACT_MAIL_SECRET]=enabledConfig('synthetic-other-owner');const res=await run(request({path:'/'+op,body}));assert.equal(res.statusCode,400);assert.deepEqual(res.value,{code:'contact_mail_unavailable'});assert.deepEqual(calls.read,[]);noMutation();
  }
});
test('malformed requested email is rejected before contact storage or mail dispatch',async()=>{
  reset();process.env[CONTACT_MAIL_SECRET]=enabledConfig();const res=await run(request({path:'/request',body:{email:'x\r\nBcc:synthetic-other@example.test'}}));assert.equal(res.statusCode,400);assert.deepEqual(res.value,{code:'contact_invalid_email'});assert.deepEqual(calls.read,[]);noMutation();
});
test('known verified own supplemental contact is returned masked and never for another UID',async()=>{
  reset();states.set(UID,{purpose:'billing_contact_preview',schemaVersion:1,email:'synthetic-verified@example.test',verified:true,source:'user_supplied',verifiedAt:Date.parse('2026-11-19T02:00:00Z')});
  const before=structuredClone(states.get(UID));const res=await run(request());assert.equal(res.statusCode,200);assert.equal(res.value.state,'verified');assert.equal(res.value.canCheckout,true);assert.equal(res.value.maskedEmail,'sy***@example.test');assert.deepEqual(calls.read,[UID]);assert.deepEqual(states.get(UID),before);noMutation();
  user.uid='synthetic-other';decoded.uid='synthetic-other';const other=await run(request());assert.equal(other.statusCode,200);assert.equal(other.value.state,'missing');assert.equal(other.value.canCheckout,false);assert.deepEqual(calls.read,[UID,'synthetic-other']);noMutation();
});
for(const deliveryState of ['failed','uncertain'])test('verified active contact preserves replacement '+deliveryState+' delivery status',async()=>{
  reset();const now=Date.now();states.set(UID,{purpose:'billing_contact_preview',schemaVersion:1,email:'synthetic-active@example.test',verified:true,source:'user_supplied',verifiedAt:now-60000,lastRequestedAt:now,
    pending:{email:'replacement@example.test',tokenHash:hash('synthetic-replacement-token'),createdAt:now,expiresAt:now+900000,sentAt:null,deliveryState}});
  const before=structuredClone(states.get(UID));const res=await run(request());assert.equal(res.statusCode,200);assert.equal(res.value.state,'verified');assert.equal(res.value.canCheckout,true);
  assert.equal(res.value.maskedEmail,'sy***@example.test');assert.equal(res.value.pendingMaskedEmail,'re***@example.test');assert.equal(res.value.source,'user_supplied');assert.equal(res.value.deliveryState,deliveryState);
  assert.equal(res.value.pendingDeliveryState,undefined);assert.doesNotMatch(JSON.stringify(res.value),/tokenHash|synthetic-active@|replacement@|synthetic-contact-http-owner/);assert.deepEqual(states.get(UID),before);noMutation();
});
test('all contact responses retain no-store no-referrer and nosniff',async()=>{
  reset();const res=await run(request());assert.match(res.headers['Cache-Control'],/no-store/);assert.equal(res.headers.Pragma,'no-cache');assert.equal(res.headers['Referrer-Policy'],'no-referrer');assert.equal(res.headers['X-Content-Type-Options'],'nosniff');assert.equal(res.headers['Access-Control-Allow-Credentials'],undefined);
});
