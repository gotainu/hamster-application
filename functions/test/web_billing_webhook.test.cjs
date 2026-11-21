'use strict';
// All account IDs, keys and Stripe objects are synthetic. These tests execute
// only dependency-injected reads and an in-memory transactional database.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {loadStarSource} = require('./support/star_source_loader.cjs');
const load = loadStarSource();
const {createWebBillingWebhook, WebBillingWebhookError, verifyWebBillingEvent} = load('webBillingWebhook');
const {createWebBillingWebhookStore} = load('webBillingWebhookStore');
const hash = value => createHash('sha256').update(value).digest('hex');
const UID = 'synthetic_owner', NOW = Date.UTC(2030,0,1), START = NOW/1000-86400, END = NOW/1000+30*86400;
const CUSTOMER = 'cus_syntheticOwner', SUB = 'sub_syntheticMonthly', PRICE = 'price_syntheticNew550', OLD = 'price_syntheticOld500';
const INVOICE = 'in_syntheticInitial', PRODUCT = 'prod_syntheticPremium';
const billingPath = `users/${UID}/billing/subscription`, mappingPath = `billing_customers/${hash(UID)}`;
const metadata = (extra={}) => ({firebaseUid:UID,webBillingScope:'hamcare-web-live-v1',webBillingAttempt:'syntheticAttempt',...extra});
const config = extra => ({secretKey:'sk_live_synthetic',publishableKey:'pk_live_synthetic',priceId:PRICE,legacyPriceId:OLD,
  webhookSecret:'whsec_synthetic',portalConfigurationId:'bpc_syntheticRestricted',origin:'https://hamster-breeding-app.web.app',
  returnUrl:'https://hamster-breeding-app.web.app/account/',...extra});
function subscription(extra={}) {
  return {id:SUB,object:'subscription',livemode:true,customer:CUSTOMER,metadata:metadata(),status:'active',
    created:START,start_date:START,current_period_start:START,current_period_end:END,
    cancel_at_period_end:false,cancel_at:null,canceled_at:null,trial_start:null,trial_end:null,
    automatic_tax:{enabled:false},latest_invoice:INVOICE,items:{data:[{id:'si_synthetic',quantity:1,price:{id:PRICE}}]},...extra};
}
function invoice(extra={}) {
  return {id:INVOICE,object:'invoice',livemode:true,customer:CUSTOMER,subscription:SUB,status:'paid',currency:'jpy',
    total:550,amount_due:550,amount_paid:550,billing_reason:'subscription_create',attempt_count:1,
    status_transitions:{paid_at:START},total_discount_amounts:[],default_tax_rates:[],...extra};
}
function fakeDb() {
  const docs = new Map(), versions = new Map(), writes = []; let version = 0, tail = Promise.resolve();
  const clone = value => value?.toMillis ? value : value instanceof Date ? new Date(value) : Array.isArray(value) ? value.map(clone) : value && typeof value==='object' ? Object.fromEntries(Object.entries(value).map(([key,v])=>[key,clone(v)])) : value;
  const ref = path => ({path});
  function snapshot(r) {
    const value = docs.has(r.path) ? clone(docs.get(r.path)) : undefined, v = versions.get(r.path);
    return {exists:value!==undefined,ref:r,data:()=>value,get:key=>value?.[key],updateTime:v?{seconds:v,nanoseconds:0}:undefined};
  }
  function seed(path,value) {docs.set(path,clone(value));versions.set(path,++version);}
  const db = {doc:ref,getAll:async(...refs)=>refs.map(snapshot),async runTransaction(fn) {
    const run = tail.then(async()=>{
      const pending=[];
      const tx={get:async r=>{assert.equal(pending.length,0,'all transaction reads precede writes');return snapshot(r);},
        set:(r,v,o)=>pending.push(['set',r.path,v,o]),update:(r,v)=>pending.push(['update',r.path,v]),create:(r,v)=>pending.push(['create',r.path,v])};
      const result=await fn(tx);
      for(const [kind,path] of pending) {if(kind==='create'&&docs.has(path))throw Error('duplicate create');if(kind==='update'&&!docs.has(path))throw Error('missing update');}
      for(const [kind,path,value,opt]of pending) {seed(path,(kind==='update'||opt?.merge)?{...docs.get(path),...value}:value);writes.push([kind,path]);}
      return result;
    });tail=run.catch(()=>{});return run;
  }};
  return {db,docs,writes,seed};
}
function setup(options={}) {
  const memory=fakeDb(); let currentTime=NOW;
  if(options.mapping!==false)memory.seed(mappingPath,{firebaseUid:UID,customerId:CUSTOMER,...options.mapping});
  if(options.billing)memory.seed(billingPath,options.billing);
  const remote={sub:subscription(options.sub),invoice:invoice(options.invoice),customer:{id:CUSTOMER,livemode:true,metadata:{firebaseUid:UID}},
    price:{id:PRICE,livemode:true,type:'recurring',unit_amount:550,currency:'jpy',tax_behavior:'inclusive',recurring:{interval:'month',interval_count:1},product:PRODUCT},
    product:{id:PRODUCT,livemode:true},session:{id:'cs_syntheticCompleted',livemode:true,mode:'subscription',ui_mode:'embedded',status:'complete',
      customer:CUSTOMER,subscription:SUB,client_reference_id:UID,metadata:metadata()}};
  const calls=[];const read=async(name,id,value)=>{calls.push([name,id]);if(options.onRead)await options.onRead(name,id,remote);return typeof value==='function'?value():value;};
  const stripe={customers:{retrieve:id=>read('customer',id,()=>remote.customer)},
    subscriptions:{retrieve:id=>read('subscription',id,()=>id===remote.sub.id?remote.sub:remote.other),
      list:params=>read('list',params,()=>({data:remote.list??[remote.sub],has_more:remote.hasMore??false}))},
    prices:{retrieve:id=>read('price',id,()=>remote.price)},products:{retrieve:id=>read('product',id,()=>remote.product)},
    invoices:{retrieve:id=>read('invoice',id,()=>remote.invoice)},checkout:{sessions:{retrieve:id=>read('session',id,()=>remote.session)}}};
  const store=createWebBillingWebhookStore(memory.db,()=>currentTime);
  const facts=options.facts===undefined?{appAccountExists:true}:options.facts;
  const engine=createWebBillingWebhook({stripe,store,config:config(options.config),now:()=>new Date(currentTime),readFacts:async()=>facts});
  const event=(type='customer.subscription.updated',id='evt_syntheticMain',extra={})=>({id,type,livemode:true,created:START,
    data:{object:{id:type.startsWith('invoice.')?remote.invoice.id:type.startsWith('checkout.')?remote.session.id:SUB}},...extra});
  return {memory,remote,calls,stripe,store,engine,event,billing:()=>memory.docs.get(billingPath),
    hooks:()=>[...memory.docs.entries()].filter(([path])=>path.startsWith('billing_notification_outbox/')).map(([,v])=>v),
    now:()=>currentTime,setTime:value=>{currentTime=value;}};
}
async function rejected(s,event=s.event(),code) {
  await assert.rejects(s.engine.process(event),error=>{
    assert.ok(error instanceof WebBillingWebhookError);
    if(code)assert.equal(error.code,code);
    assert.doesNotMatch(error.message,/synthetic|sk_|pk_|whsec_|cus_|sub_|uid|stripe/i);
    return true;
  });
  assert.equal(s.billing(),undefined);
  assert.equal(s.hooks().length,0);
}
for(const type of ['checkout.session.completed','customer.subscription.created','customer.subscription.updated','customer.subscription.deleted','invoice.paid','invoice.payment_failed']) {
  test('required event synchronizes fetched Live state: '+type,async()=>{
    const s=setup();if(type==='invoice.payment_failed'){s.remote.sub.status='past_due';Object.assign(s.remote.invoice,{status:'open',amount_paid:0});}
    if(type==='customer.subscription.deleted'){s.remote.sub.status='canceled';s.remote.sub.canceled_at=START;}
    assert.deepEqual(await s.engine.process(s.event(type)),{result:'synced'});
    assert.equal(s.billing().stripeLivemode,true);assert.equal(s.billing().provider,'stripe');assert.equal(s.billing().amount,550);
    assert.equal(s.billing().currentPeriodEnd.toMillis(),END*1000);
    assert.equal(s.billing().plan,type==='invoice.payment_failed'||type==='customer.subscription.deleted'?'none':'paid');
    assert.ok(s.calls.filter(([name])=>name==='customer').length>=2);
    assert.equal(s.memory.docs.get('billing_webhook_events/'+hash('evt_syntheticMain')).result,'processed');
    assert.ok(s.memory.writes.every(([,path])=>!path.includes('preview')));
  });
}
test('DI configuration is revalidated before any operation',()=>{
  const s=setup();assert.throws(()=>createWebBillingWebhook({stripe:s.stripe,store:s.store,config:config({secretKey:'sk_test_synthetic'}),now:()=>new Date(NOW)}));
  assert.throws(()=>createWebBillingWebhook({stripe:s.stripe,store:s.store,config:config({priceId:undefined}),now:()=>new Date(NOW)}));
  assert.equal(s.calls.length,0);
});
test('Test Mode event is rejected before claiming event or UID',async()=>{
  const s=setup();await rejected(s,s.event(undefined,undefined,{livemode:false}),'live_mode_required');assert.equal(s.memory.writes.length,0);
});
test('unsubscribed signed Live event is acknowledged without any state or Stripe call',async()=>{
  const s=setup();assert.deepEqual(await s.engine.process(s.event('customer.updated')),{result:'ignored'});assert.equal(s.memory.writes.length,0);assert.equal(s.calls.length,0);
});
for(const name of ['session','customer','sub','price','product','invoice']) {
  test('a fetched Test object cannot cross the production boundary: '+name,async()=>{
    const s=setup();s.remote[name].livemode=false;await rejected(s,s.event(name==='session'?'checkout.session.completed':undefined),'live_mode_required');
  });
}
test('a Test subscription in customer listing also rejects synchronization',async()=>{
  const s=setup();s.remote.list=[subscription({livemode:false})];await rejected(s,undefined,'live_mode_required');
});
test('forged UID in event payload never controls the target billing path',async()=>{
  const s=setup();await s.engine.process(s.event(undefined,undefined,{data:{object:{id:SUB,metadata:{firebaseUid:'synthetic_forged'}}}}));
  assert.equal(s.billing().firebaseUid,UID);assert.equal(s.memory.docs.has('users/synthetic_forged/billing/subscription'),false);
});
for(const [name,change,code] of [
  ['Customer UID missing',s=>{s.remote.customer.metadata={};},'uid_binding_invalid'],
  ['Subscription UID differs',s=>{s.remote.sub.metadata.firebaseUid='synthetic_other';},'uid_binding_mismatch'],
  ['Subscription scope differs',s=>{s.remote.sub.metadata.webBillingScope='preview';},'web_binding_invalid'],
  ['Subscription attempt absent',s=>{delete s.remote.sub.metadata.webBillingAttempt;},'web_binding_invalid'],
  ['stored UID differs',s=>s.memory.seed(mappingPath,{firebaseUid:'synthetic_other',customerId:CUSTOMER}),'stored_binding_mismatch'],
  ['stored Customer differs',s=>s.memory.seed(mappingPath,{firebaseUid:UID,customerId:'cus_syntheticOther'}),'stored_binding_mismatch'],
  ['stored Test billing',s=>s.memory.seed(billingPath,{stripeCustomerId:CUSTOMER,stripeLivemode:false}),'stored_binding_mismatch'],
]) {
  test('same-owner binding rejects '+name,async()=>{
    const s=setup();change(s);
    if(name==='stored Test billing'){const before=s.billing();await assert.rejects(s.engine.process(s.event()),e=>e.code===code);assert.deepEqual(s.billing(),before);}
    else await rejected(s,undefined,code);
  });
}
test('new Customer without stored UID mapping cannot create billing from metadata alone',async()=>{
  const s=setup({mapping:false});await rejected(s,undefined,'stored_binding_missing');
});
test('Session metadata and source Subscription attempts must agree',async()=>{
  const s=setup();s.remote.session.metadata.webBillingAttempt='anotherAttempt';await rejected(s,s.event('checkout.session.completed'),'session_binding_mismatch');
});
test('current app account must still exist before entitlement sync',async()=>{
  const s=setup({facts:{appAccountExists:false}});await rejected(s,undefined,'account_missing');
});
for(const [label,mutate,code] of [
  ['unconfigured Price',s=>{s.remote.sub.items.data[0].price.id='price_syntheticOther';},'subscription_price_invalid'],
  ['500 on configured new Price',s=>{s.remote.price.unit_amount=500;},'price_invalid'],
  ['exclusive new tax',s=>{s.remote.price.tax_behavior='exclusive';},'price_invalid'],
  ['yearly interval',s=>{s.remote.price.recurring.interval='year';},'price_invalid'],
  ['quantity two',s=>{s.remote.sub.items.data[0].quantity=2;},'subscription_price_invalid'],
  ['two subscription items',s=>{s.remote.sub.items.data.push({...s.remote.sub.items.data[0]});},'subscription_price_invalid'],
  ['automatic tax',s=>{s.remote.sub.automatic_tax.enabled=true;},'subscription_price_invalid'],
  ['coupon',s=>{s.remote.sub.discount={id:'di_synthetic'};},'subscription_price_invalid'],
  ['invoice tax overage',s=>{s.remote.invoice.total=605;},'invoice_price_invalid'],
  ['invoice discount',s=>{s.remote.invoice.total_discount_amounts=[{amount:50}];},'invoice_price_invalid'],
  ['invoice Customer mismatch',s=>{s.remote.invoice.customer='cus_syntheticOther';},'invoice_binding_mismatch'],
  ['invoice subscription mismatch',s=>{s.remote.invoice.subscription='sub_syntheticOther';},'invoice_binding_mismatch'],
])test('fixed 550 monthly boundary rejects '+label,async()=>{const s=setup();mutate(s);await rejected(s,undefined,code);});
test('Stripe original trial uses exact original end and zero invoice gives no charge hook',async()=>{
  const trialEnd=END-10*86400;
  const s=setup({sub:{status:'trialing',trial_start:START,trial_end:trialEnd},invoice:{total:0,amount_due:0,amount_paid:0},
    facts:{appAccountExists:true,trial:{kind:'found',data:{endsAt:new Date(trialEnd*1000-500)}}}});
  await s.engine.process(s.event('checkout.session.completed'));
  assert.equal(s.billing().nextChargeAtSeconds,trialEnd);assert.equal(s.billing().latestInvoicePaymentStatus,'no_payment_required');
  assert.deepEqual(s.hooks().map(h=>h.type).sort(),['contract_registered']);
});
test('a new Stripe trial cannot extend the original app trial',async()=>{
  const s=setup({sub:{status:'trialing',trial_end:END},facts:{appAccountExists:true,trial:{kind:'found',data:{endsAt:new Date((END-1)*1000)}}}});
  await rejected(s,undefined,'trial_binding_mismatch');
});
test('legacy old500 stays on its owned original Price, including 100% coupon invoice',async()=>{
  const oldBilling={provider:'stripe',stripeCustomerId:CUSTOMER,stripeSubscriptionId:SUB,stripePriceId:OLD,plan:'paid',status:'active'};
  const s=setup({mapping:false,billing:oldBilling,sub:{metadata:{},items:{data:[{quantity:1,price:{id:OLD}}]},discount:{id:'di_syntheticLegacy'}},
    invoice:{total:0,amount_due:0,amount_paid:0}});
  Object.assign(s.remote.price,{id:OLD,unit_amount:500,tax_behavior:'exclusive'});
  await s.engine.process(s.event('invoice.payment_succeeded'));
  assert.equal(s.billing().amount,500);assert.equal(s.billing().stripePriceId,OLD);assert.equal(s.billing().legacyPrice,true);
  assert.equal(s.billing().plan,'paid');assert.equal(s.billing().latestInvoicePaymentStatus,'no_payment_required');
});
test('legacy Price never creates a newly unanchored subscription',async()=>{
  const s=setup({sub:{items:{data:[{quantity:1,price:{id:OLD}}]}}});Object.assign(s.remote.price,{id:OLD,unit_amount:500,tax_behavior:'exclusive'});
  await rejected(s,undefined,'subscription_price_invalid');
});
test('new550 success alias and invoice.paid share canonical billing and one invoice hook',async()=>{
  const s=setup();
  assert.deepEqual(await s.engine.process(s.event('invoice.payment_succeeded','evt_syntheticSuccessAlias')),{result:'synced'});
  const period=s.billing().currentPeriodEndSeconds,charge=s.billing().firstChargeAtSeconds,hooks=s.hooks().length;
  assert.deepEqual(await s.engine.process(s.event('invoice.paid','evt_syntheticPaidAfterAlias')),{result:'synced'});
  assert.equal(s.billing().plan,'paid');assert.equal(s.billing().amount,550);assert.equal(s.billing().stripePriceId,PRICE);
  assert.equal(s.billing().currentPeriodEndSeconds,period);assert.equal(s.billing().firstChargeAtSeconds,charge);
  assert.equal(s.hooks().length,hooks);assert.equal(s.hooks().filter(h=>h.type==='payment_success').length,1);
  assert.equal([...s.memory.docs.keys()].filter(p=>p.startsWith('users/')&&p.endsWith('/billing/subscription')).length,1);
  assert.equal(s.memory.docs.get('billing_webhook_events/'+hash('evt_syntheticSuccessAlias')).result,'processed');
  assert.equal(s.memory.docs.get('billing_webhook_events/'+hash('evt_syntheticPaidAfterAlias')).result,'processed');
});
test('duplicate event receipt skips Stripe and hooks; distinct duplicate invoice events keep one first-charge hook',async()=>{
  const s=setup();await s.engine.process(s.event('invoice.paid'));
  const calls=s.calls.length,hooks=s.hooks().length;
  assert.deepEqual(await s.engine.process(s.event('invoice.paid')),{result:'duplicate'});assert.equal(s.calls.length,calls);
  await s.engine.process(s.event('invoice.paid','evt_syntheticDuplicateInvoice'));
  assert.equal(s.hooks().length,hooks);assert.equal(s.hooks().filter(h=>h.type==='payment_success').length,1);assert.equal(s.billing().billingSyncFence,2);
});
test('canonical Stripe is re-fetched under the UID lease instead of using the routing response',async()=>{
  const s=setup();const original=s.store.claimSubject;
  s.store.claimSubject=async(...args)=>{const claimed=await original(...args);s.remote.sub=subscription({status:'canceled',canceled_at:START});return claimed;};
  await s.engine.process(s.event());assert.equal(s.billing().status,'canceled');assert.equal(s.billing().plan,'none');
});
test('late old deletion cannot replace a current paid replacement subscription',async()=>{
  const s=setup();s.remote.sub=subscription({status:'canceled'});s.remote.other=subscription({id:'sub_syntheticReplacement',created:START+1,current_period_end:END+86400});
  s.remote.list=[s.remote.sub,s.remote.other];s.remote.invoice.subscription=s.remote.other.id;
  await s.engine.process(s.event('customer.subscription.deleted'));
  assert.equal(s.billing().stripeSubscriptionId,s.remote.other.id);assert.equal(s.billing().plan,'paid');
});
test('late old invoice payload resolves current renewed invoice and keeps the current period',async()=>{
  const s=setup();s.remote.sub.latest_invoice='in_syntheticRenewal';s.remote.invoice.id='in_syntheticRenewal';s.remote.invoice.billing_reason='subscription_cycle';
  s.remote.sub.current_period_end=END+30*86400;
  await s.engine.process(s.event('invoice.paid',undefined,{created:START-86400,data:{object:{id:INVOICE}}}));
  assert.equal(s.billing().latestInvoiceId,'in_syntheticRenewal');assert.equal(s.billing().currentPeriodEndSeconds,END+30*86400);
  assert.equal(s.hooks().filter(h=>h.type==='payment_success').length,0);
});
test('internal metadata synchronization does not notify an existing old500 payment first observed by the new model',async()=>{
  const s=setup({billing:{provider:'stripe',stripeCustomerId:CUSTOMER,stripeSubscriptionId:SUB,stripePriceId:OLD,plan:'paid',status:'active'},
    sub:{metadata:{},items:{data:[{quantity:1,price:{id:OLD}}]}},invoice:{total:500,amount_due:500,amount_paid:500}});
  Object.assign(s.remote.price,{id:OLD,unit_amount:500,tax_behavior:'exclusive'});
  await s.engine.process(s.event('customer.subscription.updated','evt_syntheticLegacyMetadata'));
  await s.engine.process(s.event('customer.subscription.updated','evt_syntheticLegacyInternalSync'));
  assert.equal(s.billing().latestInvoiceId,INVOICE);assert.equal(s.billing().amount,500);assert.equal(s.billing().stripePriceId,OLD);
  assert.deepEqual(s.hooks(),[]);
});
test('a real paid event after subscription synchronization still creates exactly one payment notification',async()=>{
  const s=setup();await s.engine.process(s.event('customer.subscription.created','evt_syntheticSubscribedFirst'));
  assert.equal(s.billing().latestInvoiceId,INVOICE);assert.equal(s.billing().latestInvoicePaymentStatus,'paid');
  assert.equal(s.hooks().filter(h=>h.type==='contract_registered').length,1);
  assert.equal(s.hooks().filter(h=>h.type==='payment_success').length,0);
  await s.engine.process(s.event('invoice.paid','evt_syntheticActualPaidAfterSubscription'));
  await s.engine.process(s.event('invoice.payment_succeeded','evt_syntheticAliasAfterSubscription'));
  await s.engine.process(s.event('invoice.paid','evt_syntheticPaidRetryAfterSubscription'));
  const paid=s.hooks().filter(h=>h.type==='payment_success');assert.equal(paid.length,1);
  assert.equal(paid[0].snapshot.amount,550);assert.equal(paid[0].invoiceId,INVOICE);assert.equal(paid[0].snapshot.legacyPrice,false);
});
test('old500 actual payment after internal sync keeps the actual old amount in the notification',async()=>{
  const s=setup({billing:{provider:'stripe',stripeCustomerId:CUSTOMER,stripeSubscriptionId:SUB,stripePriceId:OLD,plan:'paid',status:'active'},
    sub:{metadata:{},items:{data:[{quantity:1,price:{id:OLD}}]}},invoice:{total:500,amount_due:500,amount_paid:500}});
  Object.assign(s.remote.price,{id:OLD,unit_amount:500,tax_behavior:'exclusive'});
  await s.engine.process(s.event('customer.subscription.updated','evt_syntheticLegacySyncBeforePaid'));
  assert.equal(s.hooks().length,0);
  await s.engine.process(s.event('invoice.payment_succeeded','evt_syntheticLegacyActualPaid'));
  await s.engine.process(s.event('invoice.paid','evt_syntheticLegacyActualPaidAlias'));
  const paid=s.hooks().filter(h=>h.type==='payment_success');assert.equal(paid.length,1);assert.equal(paid[0].snapshot.amount,500);
  assert.equal(paid[0].snapshot.legacyPrice,true);assert.equal(paid[0].snapshot.latestInvoiceAmountPaid,500);
  const {renderBillingNotification}=load('billingNotificationTemplates');
  const message=renderBillingNotification({type:paid[0].type,mode:'live',snapshot:paid[0].snapshot});
  assert.match(message.text,/500円/);assert.doesNotMatch(message.text,/550円/);assert.doesNotMatch(message.html,/550円/);
});
test('billing emits cancellation, resume, failure and end hooks only on their canonical transitions',async()=>{
  const s=setup();await s.engine.process(s.event());
  await s.engine.process(s.event('invoice.paid','evt_syntheticActualInitialPayment'));
  s.remote.sub.cancel_at_period_end=true;s.remote.sub.cancel_at=END;
  await s.engine.process(s.event(undefined,'evt_syntheticCancelReserve'));assert.equal(s.billing().plan,'paid');
  await s.engine.process(s.event(undefined,'evt_syntheticCancelDuplicate'));
  s.remote.sub.cancel_at_period_end=false;s.remote.sub.cancel_at=null;
  await s.engine.process(s.event(undefined,'evt_syntheticResume'));
  Object.assign(s.remote.sub,{status:'past_due'});Object.assign(s.remote.invoice,{status:'open',amount_paid:0});
  await s.engine.process(s.event('invoice.payment_failed','evt_syntheticFailure'));
  await s.engine.process(s.event('invoice.payment_failed','evt_syntheticFailureDuplicate'));
  Object.assign(s.remote.sub,{status:'canceled',canceled_at:START+10});
  await s.engine.process(s.event('customer.subscription.deleted','evt_syntheticEnd'));
  for(const type of ['contract_registered','payment_success','cancel_reserved','resumed','payment_failed','canceled'])assert.equal(s.hooks().filter(h=>h.type===type).length,1,type);
  assert.equal(s.billing().plan,'none');assert.equal(s.billing().nextChargeAtSeconds,null);
});
test('a stale payment-failed event cannot queue failure for a newer paid invoice',async()=>{
  const s=setup();s.remote.invoice.id='in_syntheticCurrentPaid';s.remote.sub.latest_invoice=s.remote.invoice.id;
  await s.engine.process(s.event('invoice.payment_failed',undefined,{data:{object:{id:INVOICE}}}));assert.equal(s.hooks().some(h=>h.type==='payment_failed'),false);
});
test('busy UID lease is retryable and leaves the other owner lease intact',async()=>{
  const s=setup();await s.store.claimSubject(UID,'synthetic-other-lease',NOW,NOW+120000);
  await rejected(s,undefined,'subject_busy');assert.equal(s.memory.docs.get('billing_webhook_subjects/'+hash(UID)).lease,'synthetic-other-lease');
});
test('fetch failure exposes a generic retryable error and leaves no paid or hook write',async()=>{
  const s=setup({onRead:async name=>{if(name==='price')throw Error('synthetic raw response sk_live_doNotExpose');}});
  await rejected(s,undefined,'sync_unavailable');const event=s.memory.docs.get('billing_webhook_events/'+hash('evt_syntheticMain'));
  assert.equal(event.result,'retryable');assert.equal(event.errorCode,'sync_unavailable');
});
test('raw-byte signature verification passes exact Buffer to SDK and enforces Live mode',()=>{
  const raw=Buffer.from('{"synthetic":true}');let args;
  const stripe={webhooks:{constructEvent:(...values)=>{args=values;return {livemode:true,type:'invoice.paid'};}}};
  assert.equal(verifyWebBillingEvent(stripe,raw,'t='+String(NOW/1000)+',v1=synthetic','whsec_synthetic',()=>new Date(NOW)).livemode,true);
  assert.equal(args[0],raw);assert.equal(args[3],300);
  for(const value of [{},raw.toString(),Buffer.alloc(0),Buffer.alloc(262145)])assert.throws(()=>verifyWebBillingEvent(stripe,value,'sig','whsec_synthetic'));
  assert.throws(()=>verifyWebBillingEvent({webhooks:{constructEvent:()=>({livemode:false})}},raw,'t='+String(NOW/1000)+',v1=synthetic','whsec_synthetic',()=>new Date(NOW)),e=>e.code==='live_mode_required');
  assert.throws(()=>verifyWebBillingEvent({webhooks:{constructEvent:()=>{throw Error('raw secret');}}},raw,'t='+String(NOW/1000)+',v1=synthetic','whsec_synthetic',()=>new Date(NOW)),e=>e.code==='signature_invalid'&&!e.message.includes('secret'));
});
function deferred() {let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};}
test('a handler whose UID lease expired cannot overwrite its newer cancellation successor',async()=>{
  const entered=deferred(),resume=deferred();let first=true;
  const s=setup({onRead:async name=>{if(name==='price'&&first){first=false;entered.resolve();await resume.promise;}}});
  const old=s.engine.process(s.event(undefined,'evt_syntheticSlow'));await entered.promise;
  s.setTime(NOW+120001);s.remote.sub=subscription({status:'canceled',canceled_at:START+10});
  await s.engine.process(s.event('customer.subscription.deleted','evt_syntheticSuccessor'));
  const canonical=s.billing(),fence=canonical.billingSyncFence;
  resume.resolve();await assert.rejects(old,error=>error.code==='sync_conflict'&&error.retryable===true);
  assert.deepEqual(s.billing(),canonical);assert.equal(s.billing().billingSyncFence,fence);assert.equal(s.billing().plan,'none');
  assert.equal(s.memory.docs.get('billing_webhook_events/'+hash('evt_syntheticSuccessor')).result,'processed');
});
test('CAS rejects a billing document changed after canonical Stripe reads and retries fetch fresh',async()=>{
  let injected=false;let s;
  s=setup({onRead:async name=>{if(name==='price'&&!injected){injected=true;s.memory.seed(billingPath,{provider:'stripe',stripeLivemode:true,
    stripeCustomerId:CUSTOMER,stripeSubscriptionId:SUB,stripePriceId:PRICE,status:'canceled',plan:'none',billingSyncFence:9});}}});
  await assert.rejects(s.engine.process(s.event()),e=>e.code==='sync_conflict'&&e.retryable===true);
  assert.equal(s.billing().billingSyncFence,9);assert.equal(s.billing().status,'canceled');assert.equal(s.hooks().length,0);
  const reads=s.calls.length;s.remote.sub.status='canceled';s.remote.sub.canceled_at=START;
  await s.engine.process(s.event());assert.ok(s.calls.length>reads);assert.equal(s.billing().status,'canceled');assert.equal(s.billing().billingSyncFence,10);
});
test('CAS also fences a same-owner Customer mapping update made during a fetch',async()=>{
  let injected=false;let s;
  s=setup({onRead:async name=>{if(name==='price'&&!injected){injected=true;s.memory.seed(mappingPath,{firebaseUid:UID,customerId:CUSTOMER,syntheticVersion:2});}}});
  await rejected(s,undefined,'sync_conflict');assert.equal(s.memory.docs.get(mappingPath).syntheticVersion,2);
});
test('actual adapter clock detects lease expiry before commit even without another claimant',async()=>{
  let s;s=setup({onRead:async name=>{if(name==='price')s.setTime(NOW+120000);}});
  await rejected(s,undefined,'sync_conflict');
});
test('an in-flight identical event is retryable and cannot steal either active lease',async()=>{
  const entered=deferred(),resume=deferred();let first=true;
  const s=setup({onRead:async name=>{if(name==='price'&&first){first=false;entered.resolve();await resume.promise;}}});
  const initial=s.engine.process(s.event());await entered.promise;
  await assert.rejects(s.engine.process(s.event()),e=>e.code==='event_busy'&&e.retryable);
  resume.resolve();assert.deepEqual(await initial,{result:'synced'});assert.equal(s.billing().billingSyncFence,1);
});
test('release by an expired owner never clears the replacement event or subject lease',async()=>{
  const s=setup();const hash=hashValue('evt_syntheticReclaim');
  const meta={eventType:'invoice.paid',createdSeconds:START,version:1};
  await s.store.claimEvent(hash,'synthetic-lease-a',NOW,NOW+1,meta);await s.store.claimSubject(UID,'synthetic-lease-a',NOW,NOW+1);
  await s.store.claimEvent(hash,'synthetic-lease-b',NOW+2,NOW+100,meta);await s.store.claimSubject(UID,'synthetic-lease-b',NOW+2,NOW+100);
  await s.store.release({uid:UID,eventHash:hash,lease:'synthetic-lease-a',errorCode:'sync_conflict'});
  assert.equal(s.memory.docs.get('billing_webhook_events/'+hash).lease,'synthetic-lease-b');
  assert.equal(s.memory.docs.get('billing_webhook_subjects/'+hashValue(UID)).lease,'synthetic-lease-b');
});
function hashValue(value) {return require('node:crypto').createHash('sha256').update(value).digest('hex');}
test('adapter refuses UID path injection and non-hash event paths before any write',async()=>{
  const s=setup();await assert.rejects(s.store.readSubject('../synthetic'),e=>e.code==='uid_binding_invalid');
  await assert.rejects(s.store.claimEvent('evt_raw','synthetic-lease',NOW,NOW+100,{version:1,createdSeconds:START,eventType:'invoice.paid'}),e=>e.code==='reference_invalid');
  assert.equal(s.memory.writes.length,0);
});
test('adapter independently refuses a mode-false billing object',async()=>{
  const s=setup();let captured;const commit=s.store.commit;
  s.store.commit=async input=>{captured=input;return commit({...input,billing:{...input.billing,stripeLivemode:false}});};
  await rejected(s,undefined,'billing_invalid');assert.equal(captured.billing.stripeLivemode,true);
});
test('adapter independently rejects a notification target different from the billing UID',async()=>{
  const s=setup();const commit=s.store.commit;
  s.store.commit=input=>commit({...input,hooks:input.hooks.map(h=>({...h,firebaseUid:'synthetic_other'}))});
  await rejected(s,undefined,'hook_invalid');
});
test('notification delivery failure cannot rerun billing or duplicate its pending hooks',async()=>{
  const s=setup();await s.engine.process(s.event());const billing=s.billing();
  const [path,hook]=[...s.memory.docs.entries()].find(([path])=>path.startsWith('billing_notification_outbox/'));
  s.memory.seed(path,{...hook,status:'failed',lastError:'synthetic_delivery_unavailable'});
  const count=s.memory.writes.length;
  assert.deepEqual(await s.engine.process(s.event()),{result:'duplicate'});assert.deepEqual(s.billing(),billing);assert.equal(s.memory.writes.length,count);
  assert.equal(s.memory.docs.get(path).status,'failed');
});
test('no retention TTL is invented for processed receipts or notification records',async()=>{
  const s=setup();await s.engine.process(s.event());
  for(const [path,data]of s.memory.docs)if(path.startsWith('billing_webhook_events/')||path.startsWith('billing_notification_outbox/'))
    assert.equal(Object.keys(data).some(k=>/^(?:ttl|expiresAt|expireAt|deleteAt|retention)/i.test(k)),false,path);
});
test('modern invoice parent subscription reference is supported without trusting event metadata',async()=>{
  const s=setup();delete s.remote.invoice.subscription;s.remote.invoice.parent={subscription_details:{subscription:SUB}};
  await s.engine.process(s.event('invoice.paid'));assert.equal(s.billing().stripeSubscriptionId,SUB);
});
test('incomplete Stripe list is retryable rather than choosing a partial winner',async()=>{
  const s=setup();s.remote.hasMore=true;await rejected(s,undefined,'subscription_unresolved');
});
test('newest canceled history wins over an older deleted event when no paid contract remains',async()=>{
  const s=setup();s.remote.sub=subscription({status:'canceled',canceled_at:START});
  s.remote.other=subscription({id:'sub_syntheticNewerEnded',status:'canceled',created:START+5,canceled_at:START+10});
  s.remote.list=[s.remote.sub,s.remote.other];s.remote.invoice.subscription=s.remote.other.id;
  await s.engine.process(s.event('customer.subscription.deleted'));assert.equal(s.billing().stripeSubscriptionId,s.remote.other.id);assert.equal(s.billing().plan,'none');
});
test('first paid subscription_cycle after a zero-charge trial emits first_charge, then renewal',async()=>{
  const trialEnd=END-10*86400;
  const s=setup({sub:{status:'trialing',trial_start:START,trial_end:trialEnd},invoice:{total:0,amount_due:0,amount_paid:0},
    facts:{appAccountExists:true,trial:{kind:'found',data:{endsAt:new Date(trialEnd*1000)}}}});
  await s.engine.process(s.event('checkout.session.completed'));
  s.remote.sub.status='active';s.remote.sub.latest_invoice='in_syntheticFirstAfterTrial';
  Object.assign(s.remote.invoice,{id:'in_syntheticFirstAfterTrial',total:550,amount_due:550,amount_paid:550,billing_reason:'subscription_cycle',status_transitions:{paid_at:trialEnd}});
  await s.engine.process(s.event('invoice.paid','evt_syntheticFirstAfterTrial'));
  assert.equal(s.hooks().filter(h=>h.type==='payment_success').length,1);assert.equal(s.hooks().filter(h=>h.type==='payment_success').length,1);
  s.remote.sub.latest_invoice='in_syntheticSecondAfterTrial';s.remote.invoice.id='in_syntheticSecondAfterTrial';
  s.remote.invoice.status_transitions.paid_at=trialEnd+30*86400;
  await s.engine.process(s.event('invoice.paid','evt_syntheticSecondAfterTrial'));
  assert.equal(s.hooks().filter(h=>h.type==='payment_success').length,2);assert.equal(s.hooks().filter(h=>h.type==='payment_success' && h.invoiceId===s.remote.invoice.id).length,1);
});
test('real SDK verifies signatures offline, refusing tampering, expired or future signatures',()=>{
  const Stripe=require('stripe');const stripe=new Stripe('sk_live_synthetic');
  const raw=Buffer.from(JSON.stringify({id:'evt_syntheticSignature',livemode:true,type:'invoice.paid'}));
  const header=timestamp=>stripe.webhooks.generateTestHeaderString({payload:raw.toString(),secret:'whsec_synthetic',timestamp});
  assert.equal(verifyWebBillingEvent(stripe,raw,header(NOW/1000),'whsec_synthetic',()=>new Date(NOW)).id,'evt_syntheticSignature');
  for(const value of [header(NOW/1000-301),header(NOW/1000+301),[header(NOW/1000)],'v1=invalid'])
    assert.throws(()=>verifyWebBillingEvent(stripe,raw,value,'whsec_synthetic',()=>new Date(NOW)),e=>e.code==='signature_invalid');
  assert.throws(()=>verifyWebBillingEvent(stripe,Buffer.from(raw.toString()+' '),header(NOW/1000),'whsec_synthetic',()=>new Date(NOW)),e=>e.code==='signature_invalid');
});
test('a new Stripe trial requires original trial evidence even when the optional facts reader is omitted',async()=>{
  const s=setup({sub:{status:'trialing',trial_end:END},invoice:{total:0,amount_due:0,amount_paid:0}});
  const engine=createWebBillingWebhook({stripe:s.stripe,store:s.store,config:config(),now:()=>new Date(NOW)});
  await assert.rejects(engine.process(s.event()),e=>e.code==='trial_binding_mismatch');assert.equal(s.billing(),undefined);
});
test('missing app profiles do not block an existing owned 550 cancellation update',async()=>{
  const s=setup({facts:{appAccountExists:false},billing:{stripeLivemode:true,stripeCustomerId:CUSTOMER,stripeSubscriptionId:SUB,stripePriceId:PRICE},
    sub:{status:'canceled',canceled_at:START}});
  await s.engine.process(s.event('customer.subscription.deleted'));assert.equal(s.billing().plan,'none');assert.equal(s.billing().status,'canceled');
});
test('missing app profiles do not block a protected legacy500 payment failure update',async()=>{
  const s=setup({mapping:false,facts:{appAccountExists:false},billing:{stripeCustomerId:CUSTOMER,stripeSubscriptionId:SUB,stripePriceId:OLD},
    sub:{status:'past_due',metadata:{},items:{data:[{quantity:1,price:{id:OLD}}]}},invoice:{status:'open',total:500,amount_due:500,amount_paid:0}});
  Object.assign(s.remote.price,{id:OLD,unit_amount:500,tax_behavior:'exclusive'});
  await s.engine.process(s.event('invoice.payment_failed'));assert.equal(s.billing().plan,'none');assert.equal(s.billing().stripePriceId,OLD);
});
test('existing verified trial end permits cancellation after original profile and trial documents are removed',async()=>{
  const s=setup({facts:{appAccountExists:false,trial:{kind:'missing'}},billing:{billingSyncVersion:1,stripeLivemode:true,
    stripeCustomerId:CUSTOMER,stripeSubscriptionId:SUB,stripePriceId:PRICE,trialEndSeconds:END},
    sub:{status:'canceled',canceled_at:START,trial_end:END}});
  await s.engine.process(s.event('customer.subscription.deleted'));assert.equal(s.billing().plan,'none');assert.equal(s.billing().trialEndSeconds,END);
});

const deletionPath=uid=>load('accountDeletion').accountDeletionRef({doc:path=>({path})},uid).path;
test('late signed webhook after deletion is acknowledged without restoring billing or sending mail',async()=>{
  const s=setup({mapping:false,facts:{appAccountExists:false}});
  s.memory.seed(deletionPath(UID),{status:'completed'});
  const event=s.event('invoice.paid');
  assert.deepEqual(await s.engine.process(event),{result:'ignored'});
  assert.deepEqual(await s.engine.process(event),{result:'duplicate'});
  assert.equal(s.billing(),undefined);
  assert.deepEqual(s.hooks(),[]);
  assert.equal(s.memory.writes.some(([,p])=>p.startsWith('users/')),false);
});
test('deletion between webhook read and commit suppresses billing and outbox atomically',async()=>{
  const s=setup({onRead(name){
    if(name==='price')s.memory.seed(deletionPath(UID),{status:'running',billingStopped:true});
  }});
  const event=s.event('invoice.paid');
  assert.deepEqual(await s.engine.process(event),{result:'ignored'});
  const receipt=s.memory.docs.get('billing_webhook_events/'+hash(event.id));
  assert.equal(receipt.result,'processed');
  assert.equal(receipt.reason,'account_deletion');
  assert.equal(s.billing(),undefined);
  assert.deepEqual(s.hooks(),[]);
  assert.deepEqual(await s.engine.process(event),{result:'duplicate'});
});
test('deletion for a different UID does not suppress this UID billing or outbox',async()=>{
  const s=setup();
  s.memory.seed(deletionPath('otherUser'),{status:'completed'});
  assert.deepEqual(await s.engine.process(s.event()),{result:'synced'});
  assert.equal(s.billing().firebaseUid,UID);
  assert.ok(s.hooks().length>0);
});

test('an abandoned free deletion cannot permanently acknowledge a paid webhook',async()=>{
  const s=setup();
  const event=s.event('invoice.paid');
  s.memory.seed(deletionPath(UID),{status:'running',billingStopped:false});
  // The owner can decline cancellation after discovering a purchase that had
  // not reached the app. Its invoice still grants access and creates mail.
  assert.deepEqual(await s.engine.process(event),{result:'synced'});
  s.memory.docs.delete(deletionPath(UID));
  assert.deepEqual(await s.engine.process(event),{result:'duplicate'});
  assert.equal(s.billing().firebaseUid,UID);
  assert.ok(s.hooks().length>0);
});
