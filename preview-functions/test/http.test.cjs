const test=require('node:test');
const assert=require('node:assert/strict');
const {EventEmitter}=require('node:events');
process.env.GCLOUD_PROJECT='demo-hamcare-checkout-task4';
process.env.FIREBASE_CONFIG=JSON.stringify({projectId:'demo-hamcare-checkout-task4'});
process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:1';
const handler=require('../lib/preview-functions/src/index.js').createPreviewStripeCheckoutSession;
const auth=require('firebase-admin/auth').getAuth();
const origin='https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
let verifyCalls=0;
auth.verifyIdToken=async()=>{verifyCalls++;throw {code:'auth/argument-error'};};
class Response extends EventEmitter{constructor(){super();this.statusCode=200;this.headers={};}set(k,v){this.headers[k]=v;return this;}status(n){this.statusCode=n;return this;}json(v){this.value=v;return this;}send(v){this.value=v;return this;}}
function request(extra={}){const headers={Origin:origin,'Authorization':'Bearer synthetic-invalid-token'};return Object.assign(new EventEmitter(),{method:'POST',path:'/review',url:'/review',originalUrl:'/review',query:{},body:{planKey:'premium_monthly'},rawBody:Buffer.from('{}'),headers,get:k=>headers[k],is:x=>x==='application/json'},extra);}
async function run(req){const res=new Response();await handler(req,res);return res;}
test('untrusted origins never reach authentication',async()=>{verifyCalls=0;const req=request();req.get=k=>k==='Origin'?'https://untrusted.invalid':undefined;const r=await run(req);assert.equal(r.statusCode,403);assert.equal(verifyCalls,0);assert.equal(r.headers['Access-Control-Allow-Origin'],undefined);});
test('CORS preflight permits only POST and explicit auth/content headers',async()=>{const r=await run(request({method:'OPTIONS'}));assert.equal(r.statusCode,204);assert.equal(r.headers['Access-Control-Allow-Origin'],origin);assert.equal(r.headers['Access-Control-Allow-Methods'],'POST');assert.equal(r.headers['Access-Control-Allow-Headers'],'Authorization, Content-Type');assert.equal(r.headers['Access-Control-Allow-Credentials'],undefined);});
test('missing Authorization is rejected without Secret or Stripe access',async()=>{const r=await run(request({get:k=>k==='Origin'?origin:undefined}));assert.equal(r.statusCode,401);assert.equal(r.value.code,'unauthenticated');assert.match(r.headers['Cache-Control'],/no-store/);});
test('invalid, expired and revoked ID tokens never disclose their contents',async()=>{for(const code of ['auth/argument-error','auth/id-token-expired','auth/id-token-revoked','auth/invalid-id-token','auth/user-disabled','auth/user-not-found']){auth.verifyIdToken=async()=>{throw {code,message:'synthetic-private-details'};};const r=await run(request());assert.equal(r.statusCode,401);assert.deepEqual(r.value,{code:'unauthenticated'});}});
test('unknown input fields, client identifiers, prices and dates are rejected',async()=>{for(const field of ['uid','email','priceId','amount','trial_end','trialEndsAt','customerId','return_url']){verifyCalls=0;const r=await run(request({body:{planKey:'premium_monthly',[field]:'synthetic'}}));assert.equal(r.statusCode,400);assert.equal(verifyCalls,0);}});
test('annual and arbitrary plan keys are rejected',async()=>{for(const planKey of ['annual','price_synthetic',null,'']){const r=await run(request({body:{planKey}}));assert.equal(r.value.code,'plan_not_allowed');}});
test('GET, wrong content type, query credentials and oversized body are rejected',async()=>{for(const extra of [{method:'GET'},{is:()=>false},{query:{idToken:'synthetic'}},{rawBody:Buffer.alloc(2049)}]){verifyCalls=0;const r=await run(request(extra));assert.equal(r.value.code,'request_invalid');assert.equal(verifyCalls,0);}});
test('unverified emails and disabled users are rejected before backend initialization',async()=>{for(const disabled of [false,true]){auth.verifyIdToken=async()=>({uid:'synthetic-a',email_verified:false});auth.getUser=async()=>({uid:'synthetic-a',email:'synthetic@example.test',emailVerified:false,disabled});const r=await run(request());assert.equal(r.value.code,disabled?'unauthenticated':'email_unverified');}});
test('all data responses retain no-store and no-referrer',async()=>{const r=await run(request({get:k=>k==='Origin'?origin:undefined}));assert.equal(r.headers['X-Content-Type-Options'],'nosniff');assert.equal(r.headers['Referrer-Policy'],'no-referrer');assert.match(r.headers['Cache-Control'],/no-store/);});
