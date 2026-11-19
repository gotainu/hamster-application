'use strict';
// Synthetic Stripe and atomic in-memory store only. No credentials or API calls.
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {createPreviewEngine, hash, SCOPE} = require('../lib/preview-functions/src/engine');

const NOW = new Date('2026-11-14T10:00:00.321Z');
const DAY = 86400000;
const PRICE = 'price_synthetic_preview';
const OWNER = {uid: 'synthetic-owner-a', emailVerified: true, email: 'owner-a@example.test'};
const OTHER = {uid: 'synthetic-owner-b', emailVerified: true, email: 'owner-b@example.test'};
const copy = value => structuredClone(value);
const deferred = () => {let resolve, reject; const promise = new Promise((yes, no) => {resolve = yes; reject = no;}); return {promise, resolve, reject};};
const missing = () => ({kind: 'missing'});
const found = data => ({kind: 'found', data});
const trial = (end = NOW.getTime() + 11 * DAY) => found({status: 'active', trialId: 'initial_trial_v2', policyVersion: 'initial_trial_v2', durationDays: 21, startedAt: new Date(NOW.getTime() - 10 * DAY), endsAt: new Date(end)});

class MemoryAtomicStore {
  constructor() {this.states = new Map(); this.tails = new Map(); this.reservations = new Set(); this.reserveCalls = []; this.writeSubjects = [];}
  async read(subject) {await (this.tails.get(subject) || Promise.resolve()); return copy(this.states.get(subject) || {});}
  async mutate(subject, updater) {
    const run = (this.tails.get(subject) || Promise.resolve()).then(() => {
      const next = updater(copy(this.states.get(subject) || {}));
      this.states.set(subject, copy(next.state)); this.writeSubjects.push(subject);
      return copy(next.result);
    });
    this.tails.set(subject, run.catch(() => {}));
    return run;
  }
  async reserveBudget(subject, day, attempt) {this.reserveCalls.push({subject,day,attempt}); this.reservations.add(`${subject}:${day}:${attempt}`);}
}

function fixture(overrides = {}) {
  let clock = new Date(NOW), sequence = 0;
  const store = new MemoryAtomicStore();
  const customers = new Map(), sessions = new Map(), subscriptions = new Map();
  const customerIdempotency = new Map(), sessionIdempotency = new Map();
  const calls = {price: [], customerCreate: [], customerRetrieve: [], customerSearch: [], subscriptionList: [], subscriptionRetrieve: [], sessionCreate: [], sessionRetrieve: [], sessionList: [], expire: [], facts: []};
  const options = {price: {}, product: {}, customer: {}, session: {}, lines: null, subscriptionHasMore: false, customerHasMore: false, sessionHasMore: false, timeoutAfterSessionCreate: false, retrieveGate: null, expireHook: null, subscriptionListHook: null, sessionListHook: null, webhookData: [], webhookHasMore: false};
  const facts = new Map();
  function factsFor(uid) {return facts.get(uid) || {appAccountExists: true, billing: missing(), trial: missing(), nickname: '合成テスト', maskedEmail: 'ow***@example.test'};}
  const price = () => ({id: PRICE, livemode: false, active: true, type: 'recurring', currency: 'jpy', unit_amount: 550, recurring: {interval: 'month', interval_count: 1}, tax_behavior: 'inclusive', metadata: {previewScope:SCOPE}, product: {id:'prod_synthetic_preview',livemode:false,active:true,metadata:{previewScope:SCOPE},...copy(options.product)}, ...copy(options.price)});
  const stripe = {
    products: {async retrieve() {return {id:'prod_synthetic_preview',livemode:false,active:true,metadata:{previewScope:SCOPE},...copy(options.product)};}},
    webhookEndpoints: {async list() {return {data: copy(options.webhookData), has_more: options.webhookHasMore};}},
    prices: {async retrieve(id) {calls.price.push(id); return price();}},
    customers: {
      async retrieve(id) {calls.customerRetrieve.push(id); if (!customers.has(id)) throw new Error('synthetic missing customer'); return copy(customers.get(id));},
      async update(id,params) {const c=customers.get(id);if(!c)throw new Error('synthetic missing customer');c.metadata=copy(params.metadata);return copy(c);},
      async search(query) {calls.customerSearch.push(copy(query)); const match = query.query.match(/previewSubjectHash'\]:'([^']+)'/); return {data: [...customers.values()].filter(c => c.metadata.previewSubjectHash === match?.[1]).map(copy), has_more: options.customerHasMore};},
      async create(params, operation) {
        calls.customerCreate.push({params:copy(params), operation:copy(operation)});
        if (customerIdempotency.has(operation.idempotencyKey)) return copy(customers.get(customerIdempotency.get(operation.idempotencyKey)));
        const value = {id: `cus_synthetic_${++sequence}`, livemode: false, email: params.email, metadata: copy(params.metadata), balance: 0, discount: null, ...copy(options.customer)};
        customers.set(value.id, value); customerIdempotency.set(operation.idempotencyKey, value.id); return copy(value);
      },
    },
    subscriptions: {
      async list(query) {calls.subscriptionList.push(copy(query)); if (options.subscriptionListHook) await options.subscriptionListHook(query); return {data: [...subscriptions.values()].filter(s => s.customer === query.customer).map(copy), has_more: options.subscriptionHasMore};},
      async retrieve(id) {calls.subscriptionRetrieve.push(id); if (!subscriptions.has(id)) throw new Error('synthetic missing subscription'); return copy(subscriptions.get(id));},
    },
    checkout: {sessions: {
      async create(params, operation) {
        calls.sessionCreate.push({params: copy(params), operation: copy(operation)});
        if (sessionIdempotency.has(operation.idempotencyKey)) return copy(sessions.get(sessionIdempotency.get(operation.idempotencyKey)));
        const value = {id: `cs_synthetic_${++sequence}`, livemode: false, client_secret: 'synthetic-client-secret', customer: params.customer, metadata: copy(params.metadata), mode: params.mode, ui_mode: params.ui_mode, currency: 'jpy', automatic_tax: {enabled:false}, total_details: {amount_discount:0,amount_tax:0}, amount_total: params.subscription_data.trial_end ? 0:550, status: 'open', expires_at: params.expires_at, payment_status: 'unpaid', subscription: null, ...copy(options.session)};
        sessions.set(value.id, value); sessionIdempotency.set(operation.idempotencyKey, value.id);
        if (options.timeoutAfterSessionCreate) {options.timeoutAfterSessionCreate = false; throw Object.assign(new Error('synthetic transport timeout'), {code:'ETIMEDOUT'});}
        return copy(value);
      },
      async retrieve(id) {calls.sessionRetrieve.push(id); const value = copy(sessions.get(id)); if (!value) throw new Error('synthetic missing session'); if(options.retrieveGate) await options.retrieveGate(id); return value;},
      async list(query) {calls.sessionList.push(copy(query)); const value = {data: [...sessions.values()].filter(s => s.customer === query.customer && (!query.status || s.status === query.status)).map(copy), has_more: options.sessionHasMore}; if(options.sessionListHook) await options.sessionListHook(query); return value;},
      async listLineItems() {return {data: options.lines || [{quantity:1, price:price()}], has_more:false};},
      async expire(id) {calls.expire.push(id); if (options.expireHook) return options.expireHook(id); const value = sessions.get(id); if (value.status !== 'open') throw new Error('synthetic session already changed'); value.status = 'expired'; return copy(value);},
    }},
  };
  const engine = createPreviewEngine({stripe, store, priceId:PRICE, publishableKey:'pk_test_synthetic_only', now:() => new Date(clock), readFacts: async uid => {calls.facts.push(uid); return factsFor(uid);},...overrides});
  const subject = identity => hash(identity.uid);
  async function review(identity = OWNER) {return engine.review(identity, 'premium_monthly');}
  async function create(quote, identity = OWNER) {return engine.create(identity,{planKey:'premium_monthly',termsAccepted:true,reviewToken:quote.reviewToken});}
  async function opened(identity = OWNER) {const quote = await review(identity); const result = await create(quote,identity); const state = await store.read(subject(identity)); return {quote,result,state,session:sessions.get(state.attempt.sessionId)};}
  function complete(session, overrides = {}) {
    const attempt = store.states.get(session.metadata.previewSubjectHash).attempt;
    const sub = {id:`sub_synthetic_${++sequence}`,livemode:false,customer:session.customer,status:attempt.trialEndSeconds ? 'trialing':'active',metadata:{previewScope:SCOPE,previewSubjectHash:session.metadata.previewSubjectHash},items:{data:[{quantity:1,price:price()}]},automatic_tax:{enabled:false},discount:null,default_tax_rates:[],trial_end:attempt.trialEndSeconds || null,...overrides};
    subscriptions.set(sub.id,sub); session.status='complete';session.payment_status=attempt.trialEndSeconds ? 'no_payment_required':'paid';session.subscription=sub.id;return sub;
  }
  return {engine,store,options,calls,customers,sessions,subscriptions,facts,subject,review,create,opened,complete,price,setClock:value=>{clock=new Date(value);}, advance:millis=>{clock=new Date(clock.getTime()+millis);}};
}
const rejectsCode = (action, code) => assert.rejects(action, e => e.code === code);

test('review and embedded Session agree on 550JPY monthly immediate charging', async () => {
  const f=fixture();const x=await f.opened();
  assert.equal(x.quote.amount,550);assert.equal(x.quote.currency,'jpy');assert.equal(x.quote.interval,'month');assert.equal(x.quote.billing.kind,'immediate');assert.equal(x.quote.billing.firstChargeAmount,550);
  const sent=f.calls.sessionCreate[0].params;
  assert.equal(sent.mode,'subscription');assert.equal(sent.ui_mode,'embedded');assert.equal(sent.locale,'ja');assert.deepEqual(sent.line_items,[{price:PRICE,quantity:1}]);assert.deepEqual(sent.payment_method_types,['card']);assert.equal(sent.payment_method_collection,'always');assert.deepEqual(sent.automatic_tax,{enabled:false});assert.equal(sent.allow_promotion_codes,false);assert.equal(sent.subscription_data.trial_end,undefined);
  assert.equal(x.result.testMode,true);assert.equal(x.result.publishableKey,'pk_test_synthetic_only');assert.equal(f.store.reservations.size,1);
});
test('active app trial uses its exact existing end and the initial Checkout total is zero', async () => {
  const f=fixture();f.facts.set(OWNER.uid,{appAccountExists:true,billing:missing(),trial:trial(),nickname:'合成',maskedEmail:'ow***@example.test'});
  const x=await f.opened();const end=Math.ceil((NOW.getTime()+11*DAY)/1000);
  assert.equal(x.quote.billing.kind,'trial');assert.equal(x.quote.billing.firstChargeAt,new Date(end*1000).toISOString());assert.equal(x.quote.billing.trialEndsAt,x.quote.billing.firstChargeAt);assert.equal(f.calls.sessionCreate[0].params.subscription_data.trial_end,end);assert.equal(x.session.amount_total,0);
  const original=f.facts.get(OWNER.uid).trial.data;assert.equal(original.aiRequestUsed,undefined);assert.equal(original.endsAt.getTime(),NOW.getTime()+11*DAY);
});
test('completed immediate Session is verified against the 550JPY Test Subscription', async () => {
  const f=fixture();const x=await f.opened();const sub=f.complete(x.session);const status=await f.engine.status(OWNER);
  assert.equal(status.state,'complete');assert.equal(status.testMode,true);assert.equal(status.paymentStatus,'paid');assert.equal(sub.items.data[0].price.unit_amount,550);assert.equal(sub.items.data[0].price.tax_behavior,'inclusive');assert.ok(!('hasAccess' in status));
});
test('completed trial Session verifies the same trial_end rather than granting application access', async () => {
  const f=fixture();f.facts.set(OWNER.uid,{appAccountExists:true,billing:missing(),trial:trial(),nickname:'合成',maskedEmail:'ow***@example.test'});const x=await f.opened();const sub=f.complete(x.session);const status=await f.engine.status(OWNER);
  assert.equal(status.state,'complete');assert.equal(sub.trial_end,f.calls.sessionCreate[0].params.subscription_data.trial_end);assert.ok(!('entitlement' in status));
});

for(const [name,override] of [['500JPY',{unit_amount:500}],['605JPY',{unit_amount:605}],['USD',{currency:'usd'}],['yearly',{recurring:{interval:'year',interval_count:1}}],['two months',{recurring:{interval:'month',interval_count:2}}],['exclusive tax',{tax_behavior:'exclusive'}],['inactive Price',{active:false}],['one-time Price',{type:'one_time'}]]) {
 test(`server rejects ${name} before Customer or Session creation`,async()=>{const f=fixture();f.options.price=override;await rejectsCode(()=>f.review(),'price_mismatch');assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);});
}
for(const [name,patch] of [['price',{price:{livemode:true}}],['customer',{customer:{livemode:true}}],['session',{session:{livemode:true}}]]) {
 test(`live ${name} object is rejected`,async()=>{const f=fixture();Object.assign(f.options,patch);await rejectsCode(async()=>{const q=await f.review();await f.create(q);},'test_mode_required');});
}
for(const override of [{balance:1},{balance:-550},{discount:{id:'synthetic-discount'}}]) {
 test(`Customer balance or discount cannot alter the advertised final total: ${JSON.stringify(override)}`,async()=>{const f=fixture();f.options.customer=override;const q=await f.review();await rejectsCode(()=>f.create(q),'price_mismatch');assert.equal(f.calls.sessionCreate.length,0);});
}
for(const override of [{amount_total:500},{amount_total:605},{automatic_tax:{enabled:true}},{total_details:{amount_discount:50,amount_tax:0}},{total_details:{amount_discount:0,amount_tax:55}}]) {
 test(`created Session with mismatched amount or tax is never returned for embedding: ${Object.keys(override)[0]}`,async()=>{const f=fixture();f.options.session=override;const q=await f.review();await rejectsCode(()=>f.create(q),'price_mismatch');});
}
for(const line of [{quantity:2,price:{id:PRICE,unit_amount:550}},{quantity:1,price:{id:'price_other',unit_amount:550}},{quantity:1,price:{id:PRICE,unit_amount:500}}]) {
 test(`Session line-item validation rejects a modified quantity or Price: ${JSON.stringify(line)}`,async()=>{const f=fixture();f.options.lines=[line];const q=await f.review();await rejectsCode(()=>f.create(q),'price_mismatch');});
}

test('same quote sequential double click reuses one open Session and one Customer',async()=>{const f=fixture();const q=await f.review();const first=await f.create(q);const second=await f.create(q);assert.deepEqual(second,first);assert.equal(f.sessions.size,1);assert.equal(f.customers.size,1);assert.equal(f.calls.sessionCreate.length,1);assert.equal(f.store.reservations.size,1);});
test('atomic lease serializes simultaneous tabs so at most one Session is created',async()=>{const f=fixture();const q=await f.review();const outcomes=await Promise.allSettled([f.create(q),f.create(q)]);assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);assert.equal(outcomes.filter(x=>x.status==='rejected'&&x.reason.code==='processing').length,1);assert.equal(f.sessions.size,1);assert.equal(f.calls.sessionCreate.length,1);});
test('timeout after Stripe accepted a create recovers the same attempt without another Session',async()=>{const f=fixture();const q=await f.review();f.options.timeoutAfterSessionCreate=true;await assert.rejects(()=>f.create(q),e=>e.code==='ETIMEDOUT');const first=await f.store.read(f.subject(OWNER));await rejectsCode(()=>f.create(q),'processing');f.advance(121000);const result=await f.create(q);const second=await f.store.read(f.subject(OWNER));assert.equal(second.attempt.id,first.attempt.id);assert.equal(f.calls.sessionCreate.length,1);assert.ok(f.calls.sessionCreate[0].operation.idempotencyKey.endsWith(first.attempt.id));assert.equal(f.sessions.size,1);assert.equal(f.customers.size,1);assert.equal(f.store.reservations.size,1);assert.equal(result.clientSecret,'synthetic-client-secret');});
test('terms and matching review token are required before Session creation',async()=>{const f=fixture();const q=await f.review();await rejectsCode(()=>f.engine.create(OWNER,{planKey:'premium_monthly',reviewToken:q.reviewToken,termsAccepted:false}),'confirmation_required');await rejectsCode(()=>f.create({reviewToken:'synthetic-wrong-token'}),'review_expired');assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);});
test('expired review quote cannot authorize a new Session',async()=>{const f=fixture();const q=await f.review();f.advance(180001);await rejectsCode(()=>f.create(q),'review_expired');assert.equal(f.calls.sessionCreate.length,0);});
test('a different tab review supersedes an older token without creating duplicate Sessions',async()=>{const f=fixture();const old=await f.review();const fresh=await f.review();await rejectsCode(()=>f.create(old),'review_expired');await f.create(fresh);assert.equal(f.calls.sessionCreate.length,1);});
test('changed trial or billing facts invalidate confirmation before creating Session',async()=>{const f=fixture();const q=await f.review();f.facts.set(OWNER.uid,{appAccountExists:true,billing:missing(),trial:trial(),nickname:'合成',maskedEmail:'ow***@example.test'});await rejectsCode(()=>f.create(q),'review_expired');assert.equal(f.calls.sessionCreate.length,0);});

test('other owner cannot reuse a quote or read the first owner Session',async()=>{const f=fixture();const x=await f.opened();const otherStatus=await f.engine.status(OTHER);assert.equal(otherStatus.state,'none');await rejectsCode(()=>f.create(x.quote,OTHER),'review_expired');assert.equal(f.calls.sessionCreate.length,1);assert.deepEqual(f.calls.sessionRetrieve,[]);});
test('a stored Customer belonging to another subject is rejected before its Session is used',async()=>{const f=fixture();const x=await f.opened();await f.store.mutate(f.subject(OTHER),()=>({state:{customerId:x.session.customer},result:null}));await rejectsCode(()=>f.review(OTHER),'customer_unresolved');assert.equal(f.calls.sessionCreate.length,1);});
test('same-email owners still receive separate Test Customers by UID hash',async()=>{const f=fixture();await f.opened();await f.opened({...OTHER,email:OWNER.email});assert.equal(f.customers.size,2);const refs=[...f.customers.values()].map(c=>c.metadata.previewSubjectHash);assert.equal(new Set(refs).size,2);assert.ok(refs.every(x=>x!==OWNER.uid&&x!==OTHER.uid));});
for(const status of ['active','trialing','past_due','unpaid','incomplete','paused']) {
 test(`Test Customer with existing ${status} subscription cannot create a new Session`,async()=>{const f=fixture();const x=await f.opened();await f.engine.cancel(OWNER);f.subscriptions.set('sub_existing',{id:'sub_existing',customer:x.session.customer,livemode:false,status});await rejectsCode(()=>f.review(),'already_subscribed');assert.equal(f.calls.sessionCreate.length,1);});
}
test('unknown subscription-list pagination blocks instead of assuming no duplicate',async()=>{const f=fixture();const q=await f.review();f.options.subscriptionHasMore=true;await rejectsCode(()=>f.create(q),'subscription_unresolved');assert.equal(f.calls.sessionCreate.length,0);});
test('an unrelated open Checkout blocks creating another one for the same Customer',async()=>{const f=fixture();const x=await f.opened();await f.engine.cancel(OWNER);f.sessions.set('cs_other_open',{id:'cs_other_open',customer:x.session.customer,status:'open',metadata:{previewAttempt:'unrelated'}});const q=await f.review();await rejectsCode(()=>f.create(q),'checkout_unresolved');assert.equal(f.calls.sessionCreate.length,1);});

test('cancel expires the unused Session, clears confirmation and never submits payment',async()=>{const f=fixture();const x=await f.opened();const cancel=await f.engine.cancel(OWNER);assert.equal(cancel.state,'canceled');assert.equal(x.session.status,'expired');const state=await f.store.read(f.subject(OWNER));assert.equal(state.quote,null);assert.equal(state.attempt.phase,'canceled');assert.equal(f.subscriptions.size,0);await rejectsCode(()=>f.create(x.quote),'review_expired');});
test('cancel during completion reports completed state and does not rewrite it as canceled',async()=>{const f=fixture();const x=await f.opened();f.options.expireHook=async()=>{f.complete(x.session);throw new Error('synthetic completion won expiry');};const result=await f.engine.cancel(OWNER);assert.equal(result.state,'complete');assert.equal((await f.store.read(f.subject(OWNER))).attempt.phase,'complete');});
test('known expired Session is never re-embedded and can use a freshly confirmed new attempt',async()=>{const f=fixture();const x=await f.opened();x.session.status='expired';assert.equal((await f.engine.status(OWNER)).state,'expired');const q=await f.review();await f.create(q);assert.equal(f.sessions.size,2);assert.notEqual((await f.store.read(f.subject(OWNER))).attempt.id,x.state.attempt.id);});
test('a server-expired open Session cannot be returned as usable merely because its status says open',async()=>{const f=fixture();const x=await f.opened();x.session.expires_at=Math.floor(NOW.getTime()/1000)-1;const q=await f.review();await rejectsCode(()=>f.create(q),'session_expired');assert.equal(f.calls.sessionCreate.length,1);});
test('status of an old completed attempt cannot change a newer attempt while retrieval is delayed',async()=>{const f=fixture();const x=await f.opened();f.complete(x.session);const gate=deferred(),entered=deferred();f.options.retrieveGate=async()=>{entered.resolve();await gate.promise;};const pending=f.engine.status(OWNER);await entered.promise;const replacement={id:'synthetic-new-attempt',phase:'creating',lease:'new-lease',leaseUntil:NOW.getTime()+120000};await f.store.mutate(f.subject(OWNER),s=>({state:{...s,attempt:replacement},result:null}));gate.resolve();await pending.catch(e=>assert.ok(['processing','checkout_unresolved'].includes(e.code)));assert.deepEqual((await f.store.read(f.subject(OWNER))).attempt,replacement);});
test('live completed Subscription cannot be described as a Test Mode success',async()=>{const f=fixture();const x=await f.opened();f.complete(x.session,{livemode:true});await rejectsCode(()=>f.engine.status(OWNER),'test_mode_required');});
test('wrong amount on the completed Subscription prevents success',async()=>{const f=fixture();const x=await f.opened();const sub=f.complete(x.session);sub.items.data[0].price.unit_amount=605;await rejectsCode(()=>f.engine.status(OWNER),'price_mismatch');});
test('trial end changed on the completed Subscription prevents success',async()=>{const f=fixture();f.facts.set(OWNER.uid,{appAccountExists:true,billing:missing(),trial:trial(),nickname:'合成',maskedEmail:'ow***@example.test'});const x=await f.opened();const sub=f.complete(x.session);sub.trial_end+=21*86400;await rejectsCode(()=>f.engine.status(OWNER),'price_mismatch');});
test('unauthorized empty app account fails before Stripe creation',async()=>{const f=fixture();f.facts.set(OWNER.uid,{appAccountExists:false,billing:missing(),trial:missing(),nickname:'',maskedEmail:'ow***@example.test'});await rejectsCode(()=>f.review(),'app_account_required');assert.equal(f.calls.price.length,0);assert.equal(f.calls.customerCreate.length,0);});
test('engine public status never returns UID, Customer or Subscription identifiers',async()=>{const f=fixture();const x=await f.opened();f.complete(x.session);const status=await f.engine.status(OWNER);const serialized=JSON.stringify(status);assert.doesNotMatch(serialized,/synthetic-owner|cus_|sub_|cs_|@example|client_secret/);assert.ok(f.store.writeSubjects.every(s=>s===f.subject(OWNER)));});

test('enabled Test webhook blocks checkout before Test events could reach an existing handler',async()=>{const f=fixture();f.options.webhookData=[{status:'enabled',livemode:false}];await rejectsCode(()=>f.review(),'test_webhook_unresolved');assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);});
test('incomplete webhook pagination is not treated as an isolated Test environment',async()=>{const f=fixture();f.options.webhookHasMore=true;await rejectsCode(()=>f.review(),'test_webhook_unresolved');assert.equal(f.calls.sessionCreate.length,0);});
test('disabled webhook endpoints do not prevent the isolated Test flow',async()=>{const f=fixture();f.options.webhookData=[{status:'disabled',livemode:false}];await f.opened();assert.equal(f.calls.sessionCreate.length,1);});

test('live Product is rejected even when the Price is a Test object',async()=>{const f=fixture();f.options.product={livemode:true};await rejectsCode(()=>f.review(),'test_mode_required');assert.equal(f.calls.sessionCreate.length,0);});
test('unscoped Test Product cannot be used by this isolated checkout',async()=>{const f=fixture();f.options.product={metadata:{previewScope:'another-scope'}};await rejectsCode(()=>f.review(),'price_mismatch');assert.equal(f.calls.sessionCreate.length,0);});

test('review quote expires at the exact three-minute boundary',async()=>{const f=fixture();const q=await f.review();f.advance(180000);await rejectsCode(()=>f.create(q),'review_expired');assert.equal(f.calls.sessionCreate.length,0);});
test('Price is revalidated at create time if it changed after confirmation',async()=>{const f=fixture();const q=await f.review();f.options.price={unit_amount:605};await rejectsCode(()=>f.create(q),'price_mismatch');assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);});
test('Customer search pagination cannot silently choose an ambiguous Test Customer',async()=>{const f=fixture();const q=await f.review();f.options.customerHasMore=true;await rejectsCode(()=>f.create(q),'customer_unresolved');assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);});
test('live publishable-key configuration is rejected before any operation',()=>{assert.throws(()=>createPreviewEngine({publishableKey:'pk_live_synthetic_only',priceId:PRICE}),e=>e.code==='test_configuration_invalid');});

test('status recovers an accepted create after a response timeout once its lease ends',async()=>{
  const f=fixture();const quote=await f.review();f.options.timeoutAfterSessionCreate=true;
  await assert.rejects(()=>f.create(quote),e=>e.code==='ETIMEDOUT');
  const pending=await f.store.read(f.subject(OWNER));assert.equal(pending.attempt.phase,'creating');assert.equal(pending.attempt.sessionId,undefined);
  f.advance(120000);
  const status=await f.engine.status(OWNER);const recovered=await f.store.read(f.subject(OWNER));
  assert.equal(status.state,'open');assert.equal(recovered.attempt.phase,'open');assert.equal(recovered.attempt.id,pending.attempt.id);
  assert.equal(recovered.attempt.sessionId,[...f.sessions.keys()][0]);assert.equal(f.sessions.size,1);assert.equal(f.customers.size,1);assert.equal(f.calls.sessionCreate.length,1);
});
test('cancel recovers an accepted create after timeout and then expires only that Session',async()=>{
  const f=fixture();const quote=await f.review();f.options.timeoutAfterSessionCreate=true;
  await assert.rejects(()=>f.create(quote),e=>e.code==='ETIMEDOUT');const pending=await f.store.read(f.subject(OWNER));
  f.advance(120000);const cancel=await f.engine.cancel(OWNER);const state=await f.store.read(f.subject(OWNER));
  assert.equal(cancel.state,'canceled');assert.equal(state.attempt.id,pending.attempt.id);assert.equal(state.attempt.phase,'canceled');assert.equal(state.quote,null);
  assert.equal(f.calls.expire.length,1);assert.equal([...f.sessions.values()][0].status,'expired');assert.equal(f.calls.sessionCreate.length,1);assert.equal(f.subscriptions.size,0);
});
test('status marks a pending attempt expired after its deadline when a complete Stripe history has no Session',async()=>{
  const f=fixture();const quote=await f.review();f.options.subscriptionListHook=async()=>{throw Object.assign(new Error('synthetic pre-create timeout'),{code:'ETIMEDOUT'});};
  await assert.rejects(()=>f.create(quote),e=>e.code==='ETIMEDOUT');const pending=await f.store.read(f.subject(OWNER));
  assert.equal(pending.attempt.phase,'creating');assert.equal(f.sessions.size,0);assert.equal(f.calls.sessionCreate.length,0);
  f.options.subscriptionListHook=null;f.advance(31*60*1000+1000);
  const status=await f.engine.status(OWNER);const expired=await f.store.read(f.subject(OWNER));
  assert.equal(status.state,'expired');assert.equal(expired.attempt.phase,'expired');assert.equal(expired.attempt.id,pending.attempt.id);assert.equal(expired.attempt.sessionId,undefined);
  assert.equal(f.calls.sessionCreate.length,0);assert.equal(f.calls.expire.length,0);assert.equal(f.customers.size,1);
});


test('delayed recovered create cannot resurrect an attempt canceled after status reconciliation',async()=>{
  const f=fixture();const quote=await f.review();f.options.timeoutAfterSessionCreate=true;
  await assert.rejects(()=>f.create(quote),e=>e.code==='ETIMEDOUT');f.advance(121000);
  const gate=deferred(),entered=deferred();let held=false;
  f.options.sessionListHook=async query=>{if(!query.status&&!held){held=true;entered.resolve();await gate.promise;}};
  const pendingCreate=f.create(quote).then(value=>({ok:true,value}),error=>({ok:false,error}));
  await entered.promise;f.options.sessionListHook=null;f.advance(120000);
  assert.equal((await f.engine.status(OWNER)).state,'open');
  assert.equal((await f.engine.cancel(OWNER)).state,'canceled');
  const canceled=await f.store.read(f.subject(OWNER));assert.equal(canceled.attempt.phase,'canceled');assert.equal(canceled.quote,null);
  gate.resolve();const outcome=await pendingCreate;
  assert.equal(outcome.ok,false,'old recovered create must not return a stale client secret');assert.equal(outcome.error.code,'processing');
  assert.deepEqual(await f.store.read(f.subject(OWNER)),canceled);
  assert.equal([...f.sessions.values()][0].status,'expired');assert.equal(f.calls.sessionCreate.length,1);assert.equal(f.subscriptions.size,0);
});
test('status reconciliation cannot steal a renewed create lease for the same attempt',async()=>{
  const f=fixture();const quote=await f.review();f.options.timeoutAfterSessionCreate=true;
  await assert.rejects(()=>f.create(quote),e=>e.code==='ETIMEDOUT');f.advance(121000);
  const statusGate=deferred(),statusEntered=deferred(),createGate=deferred(),createEntered=deferred();let calls=0;
  f.options.sessionListHook=async query=>{if(query.status)return;calls++;if(calls===1){statusEntered.resolve();await statusGate.promise;}else if(calls===2){createEntered.resolve();await createGate.promise;}};
  const pendingStatus=f.engine.status(OWNER).then(value=>({ok:true,value}),error=>({ok:false,error}));
  await statusEntered.promise;
  const pendingCreate=f.create(quote).then(value=>({ok:true,value}),error=>({ok:false,error}));
  await createEntered.promise;const renewed=await f.store.read(f.subject(OWNER));assert.equal(renewed.attempt.phase,'creating');assert.ok(renewed.attempt.leaseUntil>NOW.getTime()+121000);
  statusGate.resolve();const status=await pendingStatus;createGate.resolve();const created=await pendingCreate;
  assert.equal(status.ok,false,'a snapshot with the previous lease must not publish recovered state');assert.equal(status.error.code,'processing');
  assert.equal(created.ok,true);assert.equal(created.value.clientSecret,'synthetic-client-secret');
  const recovered=await f.store.read(f.subject(OWNER));assert.equal(recovered.attempt.id,renewed.attempt.id);assert.equal(recovered.attempt.phase,'open');assert.equal(f.calls.sessionCreate.length,1);
});

const allowedWebhook={id:'we_synthetic',url:'https://example.test/test-only',events:['checkout.session.completed','customer.subscription.created','customer.subscription.updated','customer.subscription.deleted','invoice.paid','invoice.payment_failed']};
const endpoint=()=>({id:allowedWebhook.id,url:allowedWebhook.url,enabled_events:[...allowedWebhook.events],status:'enabled',livemode:false,api_version:'2025-02-24.acacia'});
test('Task5 only its exact configured Test webhook and event set permit checkout',async()=>{const f=fixture({allowedWebhook});f.options.webhookData=[endpoint()];await f.opened();assert.equal(f.sessions.size,1);});
for(const [name,change] of [['URL',{url:'https://untrusted.invalid'}],['ID',{id:'we_another'}],['live',{livemode:true}],['events',{enabled_events:['*']}],['version',{api_version:'2020-08-27'}]])test('Task5 refuses webhook '+name+' drift',async()=>{const f=fixture({allowedWebhook});f.options.webhookData=[{...endpoint(),...change}];await rejectsCode(()=>f.review(),'test_webhook_unresolved');assert.equal(f.sessions.size,0);});
test('Task5 binds verified Firebase UID using only preview-specific metadata',async()=>{const f=fixture();const {session,state}=await f.opened();const c=[...f.customers.values()][0];assert.equal(c.metadata.previewFirebaseUid,OWNER.uid);assert.equal(session.metadata.previewFirebaseUid,OWNER.uid);assert.equal(state.previewFirebaseUid,OWNER.uid);assert.equal(session.metadata.firebaseUid,undefined);assert.equal(session.client_reference_id,undefined);});
test('Task5 safely binds a legacy hash-only Test Customer without duplicating it',async()=>{const f=fixture();await f.opened();await f.engine.cancel(OWNER);const c=[...f.customers.values()][0];delete c.metadata.previewFirebaseUid;await f.create(await f.review());assert.equal(f.customers.size,1);assert.equal(c.metadata.previewFirebaseUid,OWNER.uid);});
test('Task5 mismatched Firebase UID metadata is refused',async()=>{const f=fixture();await f.opened();await f.engine.cancel(OWNER);[...f.customers.values()][0].metadata.previewFirebaseUid=OTHER.uid;await rejectsCode(()=>f.review(),'customer_unresolved');});

test('no-email Apple UID requires a verified supplemental contact before scoped Test Checkout',async()=>{
  const f=fixture({requireBillingContact:async identity=>{assert.equal(identity.uid,OWNER.uid);return {email:'billing-verified@example.test',source:'user_supplied'};}});const identity={uid:OWNER.uid,emailVerified:false,authBasis:'apple_provider'};
  const before=copy(identity);const x=await f.opened(identity);
  assert.equal(x.quote.amount,550);assert.equal(f.calls.sessionCreate[0].params.line_items[0].quantity,1);
  const sent=f.calls.customerCreate[0].params;assert.equal(sent.email,'billing-verified@example.test');assert.equal(x.quote.account.maskedEmail,'bi***@example.test');
  assert.equal(sent.metadata.previewFirebaseUid,OWNER.uid);assert.equal(sent.metadata.previewSubjectHash,f.subject(identity));
  assert.deepEqual(identity,before);assert.equal(x.result.testMode,true);
});
test('Apple verified supplemental contact preserves exact preexisting trial end without extension or reset',async()=>{
  const f=fixture({requireBillingContact:async()=>({email:'billing-verified@example.test',source:'user_supplied'})});const identity={uid:OWNER.uid,emailVerified:false,authBasis:'apple_provider'};
  const original={appAccountExists:true,billing:missing(),trial:trial(),nickname:'合成',maskedEmail:'未設定'};
  f.facts.set(OWNER.uid,original);const before=copy(original);const x=await f.opened(identity);
  assert.equal(x.quote.billing.kind,'trial');assert.equal(f.calls.sessionCreate[0].params.subscription_data.trial_end,Math.ceil(original.trial.data.endsAt.getTime()/1000));assert.deepEqual(original,before);
});
for(const authBasis of [undefined,'verified_email','custom'])test('Checkout unverified non-Apple identity cannot create Customer: '+String(authBasis),async()=>{
  const f=fixture();await rejectsCode(()=>f.review({uid:OWNER.uid,emailVerified:false,authBasis}),'email_unverified');assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);
});


// Preview contact gate is independent of the UID-based Stripe ownership model.
test('category C without contact proof blocks review and create before Stripe or Preview quote writes',async()=>{
  const f=fixture(),identity={uid:OWNER.uid,emailVerified:false,authBasis:'apple_provider'};
  await rejectsCode(()=>f.review(identity),'contact_verification_required');
  await rejectsCode(()=>f.create({reviewToken:'synthetic-unverified-contact-review'},identity),'contact_verification_required');
  assert.equal(f.calls.facts.length,0);assert.equal(f.calls.price.length,0);assert.equal(f.calls.customerSearch.length,0);assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);assert.equal(f.store.states.size,0);assert.equal(f.store.reservations.size,0);
});
test('revoked supplemental contact after review is rechecked before creating Customer or Session',async()=>{
  let verified=true;const seen=[];
  const f=fixture({requireBillingContact:async identity=>{seen.push(identity.uid);if(!verified)throw {code:'contact_verification_required'};return {email:'verified-contact@example.test',source:'user_supplied'};}});
  const identity={uid:OWNER.uid,emailVerified:false,authBasis:'apple_provider'},before=copy(identity);
  const quote=await f.review(identity);verified=false;
  await rejectsCode(()=>f.create(quote,identity),'contact_verification_required');
  assert.deepEqual(seen,[OWNER.uid,OWNER.uid]);assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);assert.equal(f.store.reservations.size,0);assert.deepEqual(identity,before);
});
test('invalid server supplemental email cannot unlock any Stripe creation',async()=>{
  for(const email of ['',undefined,'not-an-email','synthetic@','x\r\n@example.test']) {
    const f=fixture({requireBillingContact:async()=>({email,source:'user_supplied'})});const identity={uid:OWNER.uid,emailVerified:false,authBasis:'apple_provider'};
    await rejectsCode(()=>f.review(identity),'contact_verification_required');
    assert.equal(f.calls.price.length,0);assert.equal(f.calls.customerCreate.length,0);assert.equal(f.calls.sessionCreate.length,0);assert.equal(f.store.states.size,0);
  }
});
test('verified contact changes keep the same UID-bound Customer and never search by email',async()=>{
  let email='old-contact@example.test';const f=fixture({requireBillingContact:async()=>({email,source:'user_supplied'})});
  const identity={uid:OWNER.uid,emailVerified:false,authBasis:'apple_provider'},before=copy(identity);
  const first=await f.opened(identity);const customerId=first.session.customer;
  await f.engine.cancel(identity);email='new-contact@private.icloud.com';const second=await f.opened(identity);
  assert.equal(second.quote.account.maskedEmail,'ne***@private.icloud.com');assert.equal(second.session.customer,customerId);assert.equal(f.customers.size,1);assert.equal(f.calls.customerCreate.length,1);
  const customer=f.customers.get(customerId);assert.equal(customer.metadata.previewFirebaseUid,identity.uid);assert.equal(customer.metadata.previewSubjectHash,f.subject(identity));
  assert.ok(f.calls.customerSearch.every(query=>query.query.includes("metadata['previewSubjectHash']")));
  assert.doesNotMatch(JSON.stringify(f.calls.customerSearch),/old-contact|new-contact|@|email/);
  assert.equal(second.session.metadata.previewFirebaseUid,identity.uid);assert.deepEqual(identity,before);
});
test('two verified contacts with the same address still produce distinct UID-owned Customers',async()=>{
  const email='shared-contact@privaterelay.appleid.com';const f=fixture({requireBillingContact:async()=>({email,source:'user_supplied'})});
  const first={uid:OWNER.uid,emailVerified:false,authBasis:'apple_provider'},second={uid:OTHER.uid,emailVerified:false,authBasis:'apple_provider'};
  await f.opened(first);await f.opened(second);assert.equal(f.customers.size,2);
  assert.deepEqual(new Set([...f.customers.values()].map(customer=>customer.metadata.previewFirebaseUid)),new Set([OWNER.uid,OTHER.uid]));
  assert.ok([...f.customers.values()].every(customer=>customer.email===email));assert.doesNotMatch(JSON.stringify(f.calls.customerSearch),/@|shared-contact|email/);
});
for(const providerDomain of ['privaterelay.appleid.com','private.icloud.com'])test('verified Apple '+providerDomain+' keeps the existing direct-contact checkout path',async()=>{
  const f=fixture();const identity={uid:OWNER.uid,emailVerified:true,email:'synthetic@'+providerDomain,authBasis:'apple_provider'};
  const before=copy(identity);const result=await f.opened(identity);assert.equal(result.quote.account.maskedEmail,'sy***@'+providerDomain);assert.equal(f.calls.customerCreate[0].params.email,identity.email);assert.deepEqual(identity,before);
});
