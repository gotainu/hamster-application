'use strict';
// Real Stripe HMAC verification with synthetic credentials/events only.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const Stripe=require('stripe');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const {createWebBillingWebhookRouter}=loadStarSource()('webBillingWebhookRouter');
const NOW=Date.UTC(2030,0,1),OLD='whsec_syntheticOldEndpoint',NEW='whsec_syntheticNewEndpoint';
function fixture(extra={}) {
  const client=new Stripe('sk_live_synthetic',{apiVersion:'2025-02-24.acacia',telemetry:false});
  const calls={legacy:0,current:0,currentConfig:0};
  const router=createWebBillingWebhookRouter({
    legacySource:()=>({stripe:client,secret:OLD}),legacyEnabled:()=>true,
    processLegacy:async()=>{calls.legacy++;return {result:'legacy_synced'};},
    source:()=>{calls.currentConfig++;return {stripe:client,secret:NEW};},mode:()=> 'verify_only',enabled:()=>false,
    process:async()=>{calls.current++;return {result:'synced'};},now:()=>new Date(NOW),...extra});
  const signed=(secret=NEW,patch={})=>{
    const raw=Buffer.from(JSON.stringify({id:'evt_syntheticRouter',object:'event',livemode:true,
      api_version:'2025-02-24.acacia',created:NOW/1000,type:'customer.subscription.updated',
      data:{object:{id:'sub_syntheticRouter'}},...patch}));
    return [raw,client.webhooks.generateTestHeaderString({payload:raw.toString(),secret,timestamp:NOW/1000})];
  };
  return {calls,router,signed,client};
}
test('old signed endpoint keeps processing while new endpoint is verification-only',async()=>{
  const f=fixture();assert.deepEqual(await f.router.handle(...f.signed(OLD)),{result:'legacy_synced'});
  assert.deepEqual(f.calls,{legacy:1,current:0,currentConfig:0});
});
test('new verify-only event stays retryable without entering either processing callback',async()=>{
  const f=fixture();await assert.rejects(f.router.handle(...f.signed()),e=>e.code==='verification_only'&&e.retryable===true);
  assert.deepEqual(f.calls,{legacy:0,current:0,currentConfig:1});
});
test('new endpoint cannot process from an enabled flag alone or mode alone',async()=>{
  for(const options of [{enabled:()=>true},{mode:()=> 'process'}, {mode:()=> 'invented',enabled:()=>true}]) {
    const f=fixture(options);await assert.rejects(f.router.handle(...f.signed()),e=>e.retryable===true);
    assert.equal(f.calls.legacy,0);assert.equal(f.calls.current,0);
  }
});
test('explicit processing mode plus enable delegates only the verified new event',async()=>{
  const f=fixture({mode:()=> 'process',enabled:()=>true});
  assert.deepEqual(await f.router.handle(...f.signed()),{result:'synced'});
  assert.equal(f.calls.current,1);assert.equal(f.calls.legacy,0);
});
test('resending an old-version event to the new endpoint routes by HMAC rather than event API version',async()=>{
  const f=fixture({mode:()=> 'process',enabled:()=>true});
  assert.deepEqual(await f.router.handle(...f.signed(NEW,{api_version:'2026-05-27.dahlia'})),{result:'synced'});
  assert.equal(f.calls.current,1);assert.equal(f.calls.legacy,0);
});
test('disabling legacy never falls through to new processing',async()=>{
  const f=fixture({legacyEnabled:()=>false,mode:()=> 'process',enabled:()=>true});
  await assert.rejects(f.router.handle(...f.signed(OLD)),e=>e.code==='processing_paused'&&e.retryable===true);
  assert.equal(f.calls.currentConfig,0);assert.equal(f.calls.current,0);assert.equal(f.calls.legacy,0);
});
test('new config failure does not interrupt a valid old signature',async()=>{
  const f=fixture({source:()=>{throw Error('synthetic unavailable new config');}});
  assert.deepEqual(await f.router.handle(...f.signed(OLD)),{result:'legacy_synced'});
});
test('forged, Test or tampered events cannot enter either processing callback',async()=>{
  for(const which of ['forged','old-test','new-test','tampered']) {
    const f=fixture({mode:()=> 'process',enabled:()=>true});
    const [raw,signature]=f.signed(which==='old-test'?OLD:which==='forged'?'whsec_foreign':NEW,
      which.endsWith('test')?{livemode:false}:{});
    await assert.rejects(f.router.handle(which==='tampered'?Buffer.concat([raw,Buffer.from(' ')]):raw,signature));
    assert.equal(f.calls.legacy,0);assert.equal(f.calls.current,0);
  }
});
test('the two endpoint credentials must be distinct for the new route',async()=>{
  const f=fixture({source:()=>({stripe:new Stripe('sk_live_synthetic'),secret:OLD})});
  await assert.rejects(f.router.handle(...f.signed()),e=>e.code==='configuration_invalid');
  assert.equal(f.calls.legacy,0);assert.equal(f.calls.current,0);
});
test('no legacy configuration preserves the single-new-endpoint route',async()=>{
  const f=fixture({legacySource:undefined,mode:()=> 'process',enabled:()=>true});
  assert.deepEqual(await f.router.handle(...f.signed()),{result:'synced'});
  assert.equal(f.calls.current,1);assert.equal(f.calls.legacy,0);
});
