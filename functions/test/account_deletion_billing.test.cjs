'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {stopAccountBilling} = require('../lib/accountDeletionBilling');
const uid = 'synthetic-apple';
const plain = () => ({billing:{},customer:{},checkout:{}});
const source = () => ({billing:{firebaseUid:uid,stripeCustomerId:'cus_owned',stripeSubscriptionId:'sub_owned',
  stripeLivemode:false},customer:{firebaseUid:uid,customerId:'cus_owned'},checkout:{}});
const scope = 'hamcare-web-live-v1';
function fixture(status = 'active') {
  const calls = [];
  const customer = {id:'cus_owned',livemode:false,metadata:{firebaseUid:uid}};
  const sub = {id:'sub_owned',livemode:false,customer:customer.id,status,metadata:{firebaseUid:uid,webBillingScope:scope},
    items:{has_more:false,data:[{price:{id:'price_550'}}]}};
  const subscriptions = [sub];
  const sessions = [];
  const invoices = [];
  const list = data => ({has_more:false,data});
  const stripe = {
    customers:{retrieve:async id=>{calls.push(['customer',id]);return customer;}},
    invoiceItems:{list:async()=>list([])},
    subscriptionSchedules:{list:async()=>list([])},
    subscriptions:{
      list:async arg=>{assert.deepEqual(arg,{customer:customer.id,status:'all',limit:100});return list(subscriptions);},
      retrieve:async id=>{calls.push(['verify',id]);return subscriptions.find(s=>s.id===id);},
      cancel:async (id,params)=>{calls.push(['cancel',id,params]);sub.status='canceled';return sub;},
    },
    checkout:{sessions:{list:async()=>list(sessions.filter(s=>s.status==='open')),
      expire:async id=>{calls.push(['expire',id]);sessions.find(s=>s.id===id).status='expired';},
      retrieve:async id=>sessions.find(s=>s.id===id)}},
    invoices:{list:async arg=>list(invoices.filter(i=>i.status===arg.status))},
  };
  const run = (billingSource=source(), consent=true) => stopAccountBilling(uid,billingSource,consent,
    ()=>({stripe,livemode:false,priceId:'price_550'}),1_000_000,false);
  return {run,sub,customer,subscriptions,sessions,invoices,stripe,calls};
}

for (const state of [{}, {plan:'none',status:'none'}]) {
  test('no Stripe call for free including separate 21-day trial: '+JSON.stringify(state), async()=>{
    await stopAccountBilling(uid,{...plain(),billing:state},false,()=>assert.fail(),1_000_000,false);
  });
}
for (const state of ['active','trialing','past_due','unpaid','incomplete','paused','reserved','canceled','incomplete_expired']) {
  test('confirm exact immediate cancellation '+state,async()=>{
    const f=fixture(state==='reserved'?'active':state);
    f.sub.cancel_at_period_end=state==='reserved';
    await f.run();
    if (['canceled','incomplete_expired'].includes(state)) {
      assert.equal(f.calls.filter(c=>c[0]==='cancel').length,0);
    } else {
      assert.deepEqual(f.calls.filter(c=>c[0]==='cancel'),[['cancel','sub_owned',{invoice_now:false,prorate:false}]]);
    }
    assert.ok(f.calls.some(c=>c[0]==='verify'));
  });
}
test('a subscription or open session requires affirmative paid consent before mutation',async()=>{
  const f=fixture();
  await assert.rejects(f.run(source(),false),{reason:'paid_confirmation_required'});
  assert.deepEqual(f.calls,[['customer','cus_owned']]);
});
test('confirmation of Stripe cancellation is required even after a successful cancel response',async()=>{
  const f=fixture();
  f.stripe.subscriptions.cancel=async()=>({...f.sub,status:'canceled'});
  await assert.rejects(f.run(),{reason:'retryable'});
});
test('retry after cancellation timeout retrieves actual status and does not cancel twice',async()=>{
  const f=fixture();let n=0;
  f.stripe.subscriptions.cancel=async()=>{n++;f.sub.status='canceled';throw new Error('timeout');};
  await assert.rejects(f.run(),/timeout/);
  await f.run();
  assert.equal(n,1);
});
for (const type of ['different-customer','different-subject','different-price','different-mode','extra-contract','truncated','missing-subscription']) {
  test('fails closed before mutation: '+type,async()=>{
    const f=fixture();
    if(type==='different-customer') f.sub.customer='cus_other';
    if(type==='different-subject') f.customer.metadata.firebaseUid='other';
    if(type==='different-price') f.sub.items.data[0].price.id='price_other';
    if(type==='different-mode') f.sub.livemode=true;
    if(type==='extra-contract') f.subscriptions.push({...f.sub,id:'sub_other',metadata:{firebaseUid:'other'}});
    if(type==='truncated') f.stripe.subscriptions.list=async()=>({has_more:true,data:[f.sub]});
    if(type==='missing-subscription') f.subscriptions.pop();
    await assert.rejects(f.run(),{reason:'billing_unresolved'});
    assert.ok(!f.calls.some(c=>c[0]==='cancel'));
  });
}
test('an open subscription Checkout is expired and confirmed before cancellation',async()=>{
  const f=fixture();f.sessions.push({id:'cs_owned',status:'open',mode:'subscription',livemode:false,
    customer:'cus_owned',client_reference_id:uid,metadata:{firebaseUid:uid,webBillingScope:scope}});
  await f.run();
  assert.ok(f.calls.findIndex(c=>c[0]==='expire') < f.calls.findIndex(c=>c[0]==='cancel'));
});
test('unknown in-flight Checkout result waits for expiry',async()=>{
  const f=fixture(),s=source();
  s.checkout={firebaseUid:uid,operation:{customerId:'cus_owned',expiresAt:1_500_000}};
  await assert.rejects(f.run(s),{reason:'checkout_pending'});
  assert.ok(!f.calls.some(c=>c[0]==='cancel'));
});
test('cannot delete on unknown billing without a canonical customer',async()=>{
  await assert.rejects(stopAccountBilling(uid,{...plain(),billing:{status:'unexpected'}},true,()=>assert.fail(),1,false),
    {reason:'billing_unresolved'});
});
for (const variation of ['safe','automatic','payment_processing','foreign_invoice','next_attempt']) {
  test('preserve accounting invoice, check future collection: '+variation,async()=>{
    const f=fixture('past_due'),invoice={id:'in_owned',status:'open',livemode:false,customer:'cus_owned',
      subscription:'sub_owned',auto_advance:false,payment_intent:null,next_payment_attempt:null};
    if(variation==='automatic')invoice.auto_advance=true;
    if(variation==='payment_processing')invoice.payment_intent={status:'processing'};
    if(variation==='foreign_invoice')invoice.subscription='sub_other';
    if(variation==='next_attempt')invoice.next_payment_attempt=12345;
    f.invoices.push(invoice);
    const snapshot=structuredClone(invoice);
    if(variation==='safe')await f.run();else await assert.rejects(f.run(),{reason:'invoice_review'});
    assert.deepEqual(invoice,snapshot);
  });
}

test('future schedule or attached schedule needs review before mutation',async()=>{
  for (const attached of [false,true]) {
    const f=fixture();
    if (attached) f.sub.schedule='sub_sched_owned';
    else f.stripe.subscriptionSchedules.list=async()=>({has_more:false,data:[{
      livemode:false,customer:'cus_owned',status:'not_started'}]});
    await assert.rejects(f.run(),{reason:'billing_unresolved'});
    assert.ok(!f.calls.some(c=>c[0]==='cancel'));
  }
});

test('pending invoice items are preserved for review after stopping renewal',async()=>{
  const f=fixture();
  f.stripe.invoiceItems.list=async args=>{
    assert.deepEqual(args,{customer:'cus_owned',pending:true,limit:1});
    return {has_more:false,data:[{id:'ii_unbilled'}]};
  };
  await assert.rejects(f.run(),{reason:'invoice_review'});
  assert.equal(f.sub.status,'canceled');
});
