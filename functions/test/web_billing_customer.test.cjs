'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {loadStarSource} = require('./support/star_source_loader.cjs');
const {createWebBillingCustomerResolver, WebBillingCustomerError, webBillingCustomerSubject,
  webBillingCustomerIdempotencyKey, WEB_BILLING_CUSTOMER_LEASE_MS, WEB_BILLING_CUSTOMER_OPERATION_MAX_MS} = loadStarSource()('webBillingCustomer');
const UID='synthetic-customer-owner', OTHER='synthetic-other-owner';
const clone=value=>structuredClone(value);
const deferred=()=>{let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};};
async function until(fn) {for(let i=0;i<100;i++){if(fn())return;await new Promise(setImmediate);}assert.fail('synthetic operation did not start');}
const customer=(id,uid=UID,extra={})=>({id,livemode:true,metadata:{firebaseUid:uid},...extra});
function fixture() {
  let clock=Date.parse('2026-11-21T03:00:00Z'), serial=0, lease=0, tail=Promise.resolve();
  const states=new Map(), records=new Map(), keys=new Map(), billings=new Map(), calls={read:[],mutate:[],search:[],retrieve:[],create:[]};
  const f={states,records,keys,billings,calls,visible:true,createHook:null,searchHook:null};
  const store={async read(uid){calls.read.push(uid);return clone(states.get(uid)||{});},async mutate(uid,fn){
    const previous=tail;let unlock;tail=new Promise(r=>{unlock=r;});await previous;
    try {const result=fn(clone(states.get(uid)||{}));states.set(uid,clone(result.state));calls.mutate.push(uid);return result.result;}
    finally {unlock();}
  }};
  const stripe={customers:{
    async retrieve(id){calls.retrieve.push(id);if(!records.has(id))throw new Error('synthetic Stripe internal secret');return clone(records.get(id));},
    async search(input){calls.search.push(clone(input));if(f.searchHook)return f.searchHook(input);
      const prefix="metadata['firebaseUid']:'";assert.ok(input.query.startsWith(prefix));
      const uid=input.query.slice(prefix.length,-1).replace(/\\(.)/g,'$1');
      return {has_more:false,data:f.visible?[...records.values()].filter(c=>c.metadata?.firebaseUid===uid).map(clone):[]};},
    async create(input,options){calls.create.push(clone({input,options}));const number=calls.create.length;
      const createOnce=()=>{if(keys.has(options.idempotencyKey))return clone(records.get(keys.get(options.idempotencyKey)));
        const value=customer('cus_synthetic'+(++serial),input.metadata.firebaseUid);keys.set(options.idempotencyKey,value.id);records.set(value.id,value);return clone(value);};
      return f.createHook?f.createHook({input,options,number,createOnce}):createOnce();},
  }};
  f.dependencies={stripe,store,readBilling:async uid=>clone(billings.get(uid)||{kind:'missing'}),now:()=>new Date(clock),randomLeaseToken:()=> 'synthetic-lease-'+(++lease)};
  f.resolver=()=>createWebBillingCustomerResolver(f.dependencies);
  f.advance=ms=>{clock+=ms;};f.now=()=>clock;
  f.resolve=(overrides={})=>f.resolver().resolveCustomer({uid:UID,mode:'create-if-missing',email:'synthetic@example.test',...overrides});
  return f;
}
async function denied(operation) {await assert.rejects(operation,error=>{
  assert.ok(['customer_unresolved','unavailable'].includes(error.code));
  assert.doesNotMatch(error.message,/cus_|synthetic|secret|metadata|firebaseUid|@/);return true;
});}
test('new Customer uses only verified UID metadata and one stable per-UID idempotency key',async()=>{
  const f=fixture(),result=await f.resolve();
  assert.equal(result.customerId,'cus_synthetic1');assert.equal(f.calls.create.length,1);
  assert.deepEqual(f.calls.create[0],{input:{email:'synthetic@example.test',metadata:{firebaseUid:UID}},options:{idempotencyKey:webBillingCustomerIdempotencyKey(UID)}});
  assert.match(webBillingCustomerSubject(UID),/^[a-f0-9]{64}$/);
  assert.notEqual(webBillingCustomerSubject(UID),webBillingCustomerSubject(OTHER));
  assert.deepEqual(f.states.get(UID),{firebaseUid:UID,customerId:'cus_synthetic1'});
  for(const call of f.calls.search){assert.equal(call.limit,2);assert.match(call.query,/metadata\['firebaseUid'\]/);assert.doesNotMatch(call.query,/@|email/);}
});
test('existing mapped Customer is returned without search, creation or writes even with a changed email',async()=>{
  const f=fixture();f.states.set(UID,{firebaseUid:UID,customerId:'cus_syntheticExisting'});f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting'));
  const before=clone(f.states.get(UID));assert.deepEqual(await f.resolve({email:'changed@example.test'}),{customerId:'cus_syntheticExisting'});
  assert.equal(f.calls.create.length,0);assert.equal(f.calls.search.length,0);assert.equal(f.calls.mutate.length,0);assert.deepEqual(f.states.get(UID),before);
});
test('legacy 500 contract Customer remains the existing Customer without inspecting or changing its contract',async()=>{
  const f=fixture();f.billings.set(UID,{kind:'found',data:{plan:'paid',status:'active',stripeCustomerId:'cus_syntheticLegacy500'}});
  f.records.set('cus_syntheticLegacy500',customer('cus_syntheticLegacy500'));
  assert.deepEqual(await f.resolve(),{customerId:'cus_syntheticLegacy500'});assert.equal(f.calls.create.length,0);assert.equal(f.calls.search.length,0);
  assert.deepEqual(f.states.get(UID),{firebaseUid:UID,customerId:'cus_syntheticLegacy500'});
  assert.deepEqual(f.billings.get(UID).data,{plan:'paid',status:'active',stripeCustomerId:'cus_syntheticLegacy500'});
});
test('existing metadata UID match is recovered without any email search or existing-Customer update',async()=>{
  const f=fixture();f.records.set('cus_syntheticRecovered',customer('cus_syntheticRecovered'));
  assert.deepEqual(await f.resolve(),{customerId:'cus_syntheticRecovered'});assert.equal(f.calls.create.length,0);
  assert.deepEqual(f.states.get(UID),{firebaseUid:UID,customerId:'cus_syntheticRecovered'});
});
test('require-existing returns an existing Customer without any coordination or Stripe writes',async()=>{
  for(const source of ['mapping','billing','metadata']) {
    const f=fixture();f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting'));
    if(source==='mapping')f.states.set(UID,{firebaseUid:UID,customerId:'cus_syntheticExisting'});
    if(source==='billing')f.billings.set(UID,{kind:'found',data:{stripeCustomerId:'cus_syntheticExisting'}});
    assert.deepEqual(await f.resolve({mode:'require-existing',email:undefined}),{customerId:'cus_syntheticExisting'});
    assert.equal(f.calls.create.length,0);assert.equal(f.calls.mutate.length,0);
  }
});
test('require-existing missing owner fails without creating or writing state',async()=>{
  const f=fixture();await denied(f.resolve({mode:'require-existing',email:undefined}));
  assert.equal(f.calls.create.length,0);assert.equal(f.calls.mutate.length,0);assert.equal(f.states.size,0);
});
test('two resolver factories contend through the shared store and create only once',async()=>{
  const f=fixture(),gate=deferred();f.createHook=async({createOnce})=>{await gate.promise;return createOnce();};
  const a=f.resolve();await until(()=>f.calls.create.length===1);
  await denied(f.resolve());assert.equal(f.calls.create.length,1);
  gate.resolve();assert.deepEqual(await a,{customerId:'cus_synthetic1'});
  assert.deepEqual(await f.resolve(),{customerId:'cus_synthetic1'});assert.equal(f.calls.create.length,1);assert.equal(f.records.size,1);
});
test('lease takeover reuses the same operation and stale completion cannot write the mapping',async()=>{
  const f=fixture(),first=deferred(),second=deferred();
  f.createHook=async({number,createOnce})=>{await(number===1?first.promise:second.promise);return createOnce();};
  const a=f.resolve();await until(()=>f.calls.create.length===1);const startedAt=f.states.get(UID).customerOperation.startedAt;
  f.advance(WEB_BILLING_CUSTOMER_LEASE_MS);const b=f.resolve();await until(()=>f.calls.create.length===2);
  assert.equal(f.calls.create[0].options.idempotencyKey,f.calls.create[1].options.idempotencyKey);
  assert.equal(f.states.get(UID).customerOperation.startedAt,startedAt);
  first.resolve();await denied(a);assert.equal(f.states.get(UID).customerId,undefined);assert.equal(f.states.get(UID).customerLease.token,'synthetic-lease-2');
  second.resolve();assert.deepEqual(await b,{customerId:'cus_synthetic1'});assert.equal(f.records.size,1);
  assert.deepEqual(f.states.get(UID),{firebaseUid:UID,customerId:'cus_synthetic1'});
});
test('timeout after remote create preserves the operation and recovers the existing result after lock expiry',async()=>{
  const f=fixture();f.createHook=({createOnce})=>{createOnce();throw new Error('synthetic transport secret');};
  await denied(f.resolve());const pending=clone(f.states.get(UID));
  assert.equal(pending.customerOperation.state,'uncertain');assert.equal(pending.customerId,undefined);
  assert.deepEqual(await f.resolve(),{customerId:'cus_synthetic1'});assert.equal(f.calls.create.length,1);
  // An active lease remains untouched by a nonowner recovery.
  assert.deepEqual(f.states.get(UID),pending);
  f.advance(WEB_BILLING_CUSTOMER_LEASE_MS);assert.deepEqual(await f.resolve(),{customerId:'cus_synthetic1'});
  assert.deepEqual(f.states.get(UID),{firebaseUid:UID,customerId:'cus_synthetic1'});assert.equal(f.records.size,1);
});
test('unknown create with temporarily invisible result retries the original idempotency key only',async()=>{
  const f=fixture();f.visible=false;f.createHook=({number,createOnce})=>{const result=createOnce();if(number===1)throw new Error('synthetic timeout');return result;};
  await denied(f.resolve());const startedAt=f.states.get(UID).customerOperation.startedAt;
  await denied(f.resolve());assert.equal(f.calls.create.length,1);
  f.advance(WEB_BILLING_CUSTOMER_LEASE_MS);assert.deepEqual(await f.resolve(),{customerId:'cus_synthetic1'});
  assert.equal(f.calls.create.length,2);assert.equal(f.records.size,1);assert.equal(f.calls.create[0].options.idempotencyKey,f.calls.create[1].options.idempotencyKey);
  assert.equal(startedAt,f.now()-WEB_BILLING_CUSTOMER_LEASE_MS);
});
test('unknown result at 24 hours fails closed without a new operation or Customer',async()=>{
  const f=fixture();f.visible=false;f.createHook=({createOnce})=>{createOnce();throw new Error('synthetic timeout');};
  await denied(f.resolve());const pending=clone(f.states.get(UID));
  f.advance(WEB_BILLING_CUSTOMER_OPERATION_MAX_MS);await denied(f.resolve());
  assert.equal(f.calls.create.length,1);assert.equal(f.records.size,1);assert.deepEqual(f.states.get(UID),pending);
  f.visible=true;assert.deepEqual(await f.resolve(),{customerId:'cus_synthetic1'});assert.equal(f.calls.create.length,1);
});
test('billing Customer appearing after reservation is recovered before any create',async()=>{
  const f=fixture();let reads=0;f.dependencies.readBilling=async()=>{reads++;return reads===1?{kind:'missing'}:{kind:'found',data:{stripeCustomerId:'cus_syntheticExisting'}};};
  f.searchHook=()=>({has_more:false,data:[]});f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting'));
  assert.deepEqual(await f.resolve(),{customerId:'cus_syntheticExisting'});assert.equal(f.calls.create.length,0);
});
test('Stripe search grammar escapes quotes and backslashes in an otherwise valid UID',async()=>{
  const f=fixture(),uid="synthetic'\\owner";assert.deepEqual(await f.resolve({uid}),{customerId:'cus_synthetic1'});
  assert.equal(f.calls.search[0].query,"metadata['firebaseUid']:'synthetic\\'\\\\owner'");
  assert.equal(f.records.get('cus_synthetic1').metadata.firebaseUid,uid);
});
for(const [name,setup] of [
  ['wrong stored UID',f=>f.states.set(UID,{firebaseUid:OTHER,customerId:'cus_syntheticExisting'})],
  ['missing stored UID',f=>f.states.set(UID,{customerId:'cus_syntheticExisting'})],
  ['malformed stored Customer',f=>f.states.set(UID,{firebaseUid:UID,customerId:'not-a-customer'})],
  ['stored Test marker',f=>f.states.set(UID,{firebaseUid:UID,customerId:'cus_syntheticExisting',stripeLivemode:false})],
  ['different billing Customer',f=>f.billings.set(UID,{kind:'found',data:{stripeCustomerId:'cus_syntheticOther'}})],
  ['deleted Customer',f=>f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting',UID,{deleted:true}))],
  ['wrong metadata UID',f=>f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting',OTHER))],
  ['absent metadata UID',f=>f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting',UID,{metadata:{}}))],
  ['Preview metadata marker',f=>f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting',UID,{metadata:{firebaseUid:UID,previewScope:'synthetic-preview'}}))],
  ['Test Customer',f=>f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting',UID,{livemode:false}))],
  ['unknown livemode',f=>f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting',UID,{livemode:undefined}))],
]) test('known Customer rejects '+name+' without replacement creation',async()=>{
  const f=fixture();f.states.set(UID,{firebaseUid:UID,customerId:'cus_syntheticExisting'});f.records.set('cus_syntheticExisting',customer('cus_syntheticExisting'));setup(f);
  const before=clone([...f.states]);await denied(f.resolve());assert.equal(f.calls.create.length,0);assert.deepEqual([...f.states],before);
});
for(const [name,result] of [
  ['multiple UID matches',{has_more:false,data:[customer('cus_synthetic1'),customer('cus_synthetic2')]}],
  ['truncated results',{has_more:true,data:[customer('cus_synthetic1')]}],
  ['unknown pagination',{data:[]}],['malformed results',{has_more:false,data:null}],
  ['wrong UID result',{has_more:false,data:[customer('cus_syntheticOther',OTHER)]}],
  ['Test result',{has_more:false,data:[customer('cus_syntheticTest',UID,{livemode:false})]}],
]) test('UID search rejects '+name+' without create or mapping writes',async()=>{
  const f=fixture();f.searchHook=()=>result;await denied(f.resolve());assert.equal(f.calls.create.length,0);assert.equal(f.calls.mutate.length,0);
});
for(const source of [{kind:'denied'},{kind:'unavailable'},{kind:'found',data:{plan:'paid',status:'active'}},{kind:'found',data:{stripeCustomerId:'bad'}}]) test('unresolved billing fails before Stripe creation',async()=>{
  const f=fixture();f.billings.set(UID,source);await denied(f.resolve());assert.equal(f.calls.create.length,0);assert.equal(f.calls.search.length,0);
});
for(const input of [{uid:''},{uid:'synthetic/owner'},{mode:'replace'},{email:'broken'}]) test('invalid resolver input cannot create: '+Object.keys(input)[0],async()=>{
  const f=fixture();await denied(f.resolve(input));assert.equal(f.calls.create.length,0);assert.equal(f.calls.mutate.length,0);
});
test('malformed persisted operation never resets into a fresh Customer operation',async()=>{
  const f=fixture();f.states.set(UID,{firebaseUid:UID,customerOperation:{id:'different-key',startedAt:f.now(),state:'uncertain'}});
  await denied(f.resolve());assert.equal(f.calls.create.length,0);assert.equal(f.calls.mutate.length,0);
});
test('SDK and store details never escape resolver error messages',async()=>{
  const f=fixture();f.dependencies.store.read=async()=>{throw new Error('synthetic private key and SDK payload');};
  await denied(f.resolve());assert.equal(f.calls.create.length,0);
});
