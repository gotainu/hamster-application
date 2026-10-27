const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {syncStripeSubscription, MAX_STRIPE_SYNC_ATTEMPTS} = require('../lib/stripeSubscriptionSync');

/* Expectations fixed before implementation:
 * - Only an ID is passed; webhook event payloads are not entitlement authority.
 * - Every attempt reads the Firestore version before reading current Stripe.
 * - CAS conflicts re-read both Firestore AND Stripe, not only retry a stale write.
 * - Even a same-business-state synchronization advances the CAS fence, so an
 *   older in-flight fetch cannot write after that synchronization completes.
 * - Failure never erases the state committed by another successful handler.
 * All IDs, dates, subscriptions, customers and database state below are fictitious.
 * No network, Firebase app initialization, credentials or real payments are used.
 */
const UID = 'synthetic_billing_owner';
const PERIOD_OLD = 1918425600;
const PERIOD_NEW = PERIOD_OLD + 31 * 86400;
function subscription(id = 'synthetic_sub_main', status = 'active', periodEnd = PERIOD_NEW, extra = {}) {
  return {id, status, customer: 'synthetic_customer', created: 1900000000,
    cancel_at_period_end: false, cancel_at: null, current_period_end: periodEnd,
    items: {data: [{current_period_end: periodEnd, price: {id: 'synthetic_price', product: 'synthetic_product'}}]}, ...extra};
}
function businessState(data) {
  const keys = ['provider','plan','status','stripeCustomerId','stripeSubscriptionId','stripePriceId','stripeProductId','currentPeriodEnd','cancelAtPeriodEnd','cancelAt'];
  return Object.fromEntries(keys.map(key => {
    const value = data?.[key];
    return [key, value && typeof value.toMillis === 'function' ? value.toMillis() : value ?? null];
  }));
}
function seed(status = 'active', periodEnd = PERIOD_OLD) {
  return {provider:'stripe', plan:['active','trialing'].includes(status)?'paid':'none', status,
    stripeCustomerId:'synthetic_customer', stripeSubscriptionId:'synthetic_sub_main',
    stripePriceId:'synthetic_price', stripeProductId:'synthetic_product',
    currentPeriodEnd:{toMillis:()=>periodEnd*1000}, cancelAtPeriodEnd:false, cancelAt:null};
}
function deferred() {let resolve; const promise = new Promise(r => {resolve = r;}); return {promise, resolve};}
function casError(code) {return Object.assign(new Error('synthetic CAS conflict'), {code});}
function mockStore(initial = null) {
  let data = initial ? {...initial} : null;
  let version = data ? 1 : 0;
  const metrics = {gets:0, writeAttempts:0, committedWrites:0, creates:0, updates:0};
  let forcedError = null;
  const token = n => ({version:n, isEqual:other=>other?.version===n});
  function apply(payload, creating) {
    const next = {...data};
    for (const [key,value] of Object.entries(payload)) {
      const transform = value?.constructor?.name;
      if (transform === 'DeleteTransform') {
        if (creating) throw new Error('Firestore create does not accept delete transforms');
        delete next[key];
      } else if (transform === 'ServerTimestampTransform') next[key] = {syntheticCommit:version+1};
      else next[key] = value;
    }
    data = next; version++; metrics.committedWrites++;
  }
  const ref = {
    async get() {
      metrics.gets++;
      const snapshot = data ? {...data} : null, revision = version;
      return {exists:snapshot!==null, updateTime:snapshot?token(revision):undefined,
        data:()=>snapshot?{...snapshot}:undefined, get:key=>snapshot?.[key]};
    },
    async update(payload, precondition) {
      metrics.writeAttempts++; metrics.updates++;
      assert.ok(precondition?.lastUpdateTime, 'existing writes must use the actual SDK update precondition');
      if (forcedError) throw forcedError;
      if (!data) throw casError(5);
      if (!precondition.lastUpdateTime.isEqual(token(version))) throw casError(9);
      apply(payload, false);
    },
    async create(payload) {
      metrics.writeAttempts++; metrics.creates++;
      if (forcedError) throw forcedError;
      if (data) throw casError(6);
      apply(payload, true);
    },
    async set() {throw new Error('set has no lastUpdateTime CAS precondition; use update/create');},
  };
  const collection = {doc:()=>({collection:()=>({doc:()=>ref})})};
  const db = {doc:documentPath=>{assert.equal(documentPath,`users/${UID}/billing/subscription`);return ref;},
    collection:name=>{assert.equal(name,'users');return collection;}};
  return {db, metrics, current:()=>data?{...data}:null, version:()=>version, failWrites:error=>{forcedError=error;}};
}
function mockStripe(retrieve, listed = []) {
  const calls = {retrieve:[],list:[]};
  const stripe = {subscriptions:{
    async retrieve(id) {calls.retrieve.push(id);return typeof retrieve === 'function'?retrieve(id,calls.retrieve.length):retrieve;},
    async list(params) {calls.list.push(params);const data = typeof listed === 'function'?await listed(params,calls.list.length):listed;return {data,has_more:false};},
  }};
  return {stripe,calls};
}
async function sync(store, remote, extra = {}) {
  return syncStripeSubscription({db:store.db,stripe:remote.stripe,uid:UID,subscriptionId:'synthetic_sub_main',...extra});
}
const seconds = value => value && typeof value.toMillis==='function'?value.toMillis()/1000:null;

test('late old active notification synchronizes the latest renewed Stripe period, not the old payload', async()=>{
  const store=mockStore(seed('active',PERIOD_OLD)),remote=mockStripe(subscription());
  const result=await sync(store,remote);
  assert.equal(result.id,'synthetic_sub_main');
  assert.equal(store.current().plan,'paid');
  assert.equal(seconds(store.current().currentPeriodEnd),PERIOD_NEW);
  assert.deepEqual(remote.calls.retrieve,['synthetic_sub_main']);
});
test('immediate cancellation remains canceled even though its previous paid period ends in the future',async()=>{
  const store=mockStore(seed('active',PERIOD_NEW)),remote=mockStripe(subscription('synthetic_sub_main','canceled',PERIOD_NEW));
  await sync(store,remote);
  assert.equal(store.current().plan,'none');assert.equal(store.current().status,'canceled');
  assert.equal(seconds(store.current().currentPeriodEnd),PERIOD_NEW);
});
test('ordinary cancel-at-period-end stays paid while active and carries the cancellation reservation',async()=>{
  const store=mockStore(seed()),remote=mockStripe(subscription('synthetic_sub_main','active',PERIOD_NEW,{cancel_at_period_end:true,cancel_at:PERIOD_NEW}));
  await sync(store,remote);assert.equal(store.current().plan,'paid');assert.equal(store.current().status,'active');
  assert.equal(store.current().cancelAtPeriodEnd,true);assert.equal(seconds(store.current().cancelAt),PERIOD_NEW);
});
test('subscription that has ended becomes none; payment failure cannot remain paid merely from old current data',async()=>{
  for(const status of ['canceled','past_due','unpaid']) {
    const store=mockStore(seed()),remote=mockStripe(subscription('synthetic_sub_main',status));
    await sync(store,remote);assert.equal(store.current().plan,'none');assert.equal(store.current().status,status);
  }
});
test('another active subscription takes precedence over the canceled event subscription',async()=>{
  const winner=subscription('synthetic_sub_alternative','active',PERIOD_NEW+86400);
  const store=mockStore(seed()),remote=mockStripe(subscription('synthetic_sub_main','canceled'),[subscription('synthetic_sub_unpaid','unpaid'),winner]);
  const result=await sync(store,remote);assert.equal(result.id,winner.id);
  assert.equal(store.current().stripeSubscriptionId,winner.id);assert.equal(store.current().plan,'paid');
});
test('preferred list result with the same ID is authoritative when that subscription becomes active again',async()=>{
  const active=subscription(),store=mockStore(seed('past_due')),remote=mockStripe(subscription('synthetic_sub_main','past_due'),[active]);
  const result=await sync(store,remote);assert.equal(result.status,'active');assert.equal(store.current().status,'active');
});
test('retrieve failure and list failure cause zero writes and preserve the previous business state',async()=>{
  for(const failList of [false,true]) {
    const store=mockStore(seed()),before=businessState(store.current());
    const remote=failList?mockStripe(subscription('synthetic_sub_main','canceled'),()=>{throw new Error('synthetic list unavailable');}):mockStripe(()=>{throw new Error('synthetic retrieve unavailable');});
    await assert.rejects(sync(store,remote),/synthetic .* unavailable/);
    assert.equal(store.metrics.writeAttempts,0);assert.deepEqual(businessState(store.current()),before);
  }
});
test('first synchronization creates only one billing document and uses create-compatible transforms',async()=>{
  const store=mockStore(),remote=mockStripe(subscription());await sync(store,remote);
  assert.equal(store.metrics.creates,1);assert.equal(store.metrics.committedWrites,1);assert.equal(store.current().plan,'paid');
});
test('same-content notification retries keep one identical business state while advancing the write fence',async()=>{
  const store=mockStore(),remote=mockStripe(subscription());await sync(store,remote);
  const before=businessState(store.current()),version=store.version();await sync(store,remote);await sync(store,remote);
  assert.deepEqual(businessState(store.current()),before);assert.equal(store.metrics.creates,1);
  assert.ok(store.version()>version,'same-state synchronization must fence older in-flight fetches');
});
test('checkout metadata is retained when explicitly supplied',async()=>{
  const store=mockStore(),remote=mockStripe(subscription());await sync(store,remote,{checkoutSessionId:'synthetic_checkout'});
  assert.equal(store.current().checkoutSessionId,'synthetic_checkout');
});
test('different concurrent handlers reading one Firestore version cannot let an older fetch overwrite cancellation',async()=>{
  const store=mockStore(seed()),entered=deferred(),release=deferred(),latest=subscription('synthetic_sub_main','canceled');
  const remote=mockStripe(async(_id,n)=>{if(n===1){entered.resolve();await release.promise;return subscription();}return latest;});
  const older=sync(store,remote);await entered.promise;
  await sync(store,remote);release.resolve();await older;
  assert.equal(store.current().status,'canceled');assert.equal(store.current().plan,'none');
  assert.ok(remote.calls.retrieve.length>=3,'the losing handler must re-fetch Stripe after its CAS conflict');
  assert.ok(store.metrics.writeAttempts>store.metrics.committedWrites,'the conflicting write must actually be rejected');
});
test('same-business-state synchronization fences an older in-flight fetch instead of silently returning no-op',async()=>{
  const store=mockStore(seed('active',PERIOD_NEW)),entered=deferred(),release=deferred();
  const remote=mockStripe(async(_id,n)=>{if(n===1){entered.resolve();await release.promise;return subscription('synthetic_sub_main','active',PERIOD_OLD);}return subscription();});
  const older=sync(store,remote);await entered.promise;const beforeVersion=store.version();
  await sync(store,remote);assert.ok(store.version()>beforeVersion);
  release.resolve();await older;
  assert.equal(seconds(store.current().currentPeriodEnd),PERIOD_NEW);assert.ok(remote.calls.retrieve.length>=3);
});
test('a CAS retry that cannot retrieve Stripe preserves the business state already committed by its peer',async()=>{
  const store=mockStore(seed()),entered=deferred(),release=deferred();
  const remote=mockStripe(async(_id,n)=>{if(n===1){entered.resolve();await release.promise;return subscription('synthetic_sub_main','active',PERIOD_OLD);}if(n===2)return subscription();throw new Error('synthetic retry retrieve unavailable');});
  const older=sync(store,remote);await entered.promise;await sync(store,remote);const success=businessState(store.current());
  release.resolve();await assert.rejects(older,/synthetic retry retrieve unavailable/);
  assert.deepEqual(businessState(store.current()),success);assert.equal(seconds(store.current().currentPeriodEnd),PERIOD_NEW);
});
test('concurrent first creation retries ALREADY_EXISTS with fresh Stripe state rather than duplicating the document',async()=>{
  const store=mockStore(),entered=deferred(),release=deferred();
  const remote=mockStripe(async(_id,n)=>{if(n===1){entered.resolve();await release.promise;return subscription('synthetic_sub_main','active',PERIOD_OLD);}return subscription();});
  const older=sync(store,remote);await entered.promise;await sync(store,remote);release.resolve();await older;
  assert.equal(store.current().plan,'paid');assert.equal(seconds(store.current().currentPeriodEnd),PERIOD_NEW);
  assert.ok(remote.calls.retrieve.length>=3);assert.equal(store.metrics.creates,2,'both real create attempts must run, one must lose');
});
test('persistent conflicts stop at the bounded retry limit without a partial or unguarded final write',async()=>{
  const store=mockStore(seed()),before=businessState(store.current()),remote=mockStripe(subscription());store.failWrites(casError(9));
  await assert.rejects(sync(store,remote));assert.equal(MAX_STRIPE_SYNC_ATTEMPTS,5);
  assert.equal(store.metrics.writeAttempts,MAX_STRIPE_SYNC_ATTEMPTS);assert.equal(remote.calls.retrieve.length,MAX_STRIPE_SYNC_ATTEMPTS);
  assert.equal(store.metrics.committedWrites,0);assert.deepEqual(businessState(store.current()),before);
});
test('non-conflict write errors propagate without unbounded retries or changed billing state',async()=>{
  const store=mockStore(seed()),before=businessState(store.current()),remote=mockStripe(subscription());store.failWrites(casError(7));
  await assert.rejects(sync(store,remote));assert.equal(store.metrics.writeAttempts,1);assert.equal(remote.calls.retrieve.length,1);
  assert.deepEqual(businessState(store.current()),before);
});
test('webhook and portal integration passes IDs through the shared sync helper rather than old payloads',()=>{
  const source=fs.readFileSync(path.resolve(__dirname,'../src/index.ts'),'utf8');
  assert.match(source,/syncStripeSubscription/);
  const createdStart=source.indexOf("case 'customer.subscription.created':"),deletedStart=source.indexOf("case 'customer.subscription.deleted':");
  assert.ok(createdStart>=0&&deletedStart>createdStart);
  const createdUpdated=source.slice(createdStart,deletedStart);
  assert.match(createdUpdated,/subscriptionId:\s*subscription\.id/);
  assert.doesNotMatch(createdUpdated,/subscription:\s*subscription\b/);
});
