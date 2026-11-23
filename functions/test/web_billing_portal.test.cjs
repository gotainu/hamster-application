'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createWebBillingPortalEngine,isWebBillingPortalSessionUrl,WEB_PORTAL_MANAGEABLE_STATUSES}=require('../lib/webBillingPortal');
const {WEB_BILLING_ORIGIN,WEB_BILLING_PORTAL_RETURN_URL}=require('../lib/webBillingConfig');
const {authorizeWebBillingManagementIdentity}=require('../lib/webBillingShared');
const UID='synthetic-production-portal-owner',CUSTOMER='cus_synthetic_owner',PRICE='price_synthetic550',LEGACY='price_synthetic500',CONFIG='bpc_synthetic_pinned';
const identity={uid:UID,emailVerified:true,authBasis:'verified_email'};
const copy=v=>structuredClone(v);
const config=()=>({secretKey:'sk_live_SYNTHETIC',publishableKey:'pk_live_SYNTHETIC',priceId:PRICE,legacyPriceId:LEGACY,
  webhookSecret:'whsec_SYNTHETIC',portalConfigurationId:CONFIG,origin:WEB_BILLING_ORIGIN,returnUrl:WEB_BILLING_PORTAL_RETURN_URL});
const product=()=>({id:'prod_synthetic',livemode:true,active:true,metadata:{}});
const price=(legacy=false)=>({id:legacy?LEGACY:PRICE,livemode:true,active:true,type:'recurring',unit_amount:legacy?500:550,
  currency:'jpy',tax_behavior:legacy?'exclusive':'inclusive',recurring:{interval:'month',interval_count:1},product:product(),metadata:{}});
const sub=()=>({id:'sub_synthetic_owner',livemode:true,customer:CUSTOMER,status:'active',created:1790000000,
  metadata:{firebaseUid:UID},items:{data:[{id:'si_synthetic',quantity:1,price:price()}],has_more:false},
  current_period_start:1790000000,current_period_end:1792592000,cancel_at_period_end:false,trial_end:null});
const portal=()=>({id:CONFIG,livemode:true,active:true,metadata:{},login_page:{enabled:false},default_return_url:WEB_BILLING_PORTAL_RETURN_URL,
  features:{customer_update:{enabled:false,allowed_updates:['email','name','address','phone']},subscription_update:{enabled:false},
    payment_method_update:{enabled:true},invoice_history:{enabled:true},subscription_cancel:{enabled:true,mode:'at_period_end',
      proration_behavior:'none',cancellation_reason:{enabled:false,options:[]}}}});
function fixture(){
  const options={config:config(),source:{kind:'found',data:{stripeLivemode:true,stripeCustomerId:CUSTOMER,stripeSubscriptionId:'sub_synthetic_owner'}},
    customer:{id:CUSTOMER,livemode:true,metadata:{firebaseUid:UID}},portal:portal(),price:price(),product:product(),subscriptions:[sub()],canonical:null,
    hasMore:false,resolved:{customerId:CUSTOMER},session:{},failure:null};
  const calls={read:[],resolve:[],customer:[],portal:[],price:[],product:[],list:[],retrieve:[],session:[],forbidden:[]};
  const check=name=>{if(options.failure===name)throw Object.assign(new Error('synthetic-private-email@example.test cus_private https://billing.stripe.com/p/session/private'),{code:'private_sdk_error'});};
  const forbidden=name=>async()=>{calls.forbidden.push(name);throw new Error('forbidden mutation '+name);};
  const stripe={
    customers:{retrieve:async id=>{calls.customer.push(id);check('customer');return copy(options.customer);},create:forbidden('customer.create'),update:forbidden('customer.update'),search:forbidden('customer.search')},
    prices:{retrieve:async id=>{calls.price.push(id);check('price');return copy(options.price);}},
    products:{retrieve:async id=>{calls.product.push(id);check('product');return copy(options.product);}},
    subscriptions:{list:async q=>{calls.list.push(copy(q));check('list');return {data:copy(options.subscriptions),has_more:options.hasMore};},
      retrieve:async id=>{calls.retrieve.push(id);check('retrieve');return copy(options.canonical||options.subscriptions.find(s=>s.id===id));},
      create:forbidden('subscription.create'),update:forbidden('subscription.update'),cancel:forbidden('subscription.cancel')},
    checkout:{sessions:{create:forbidden('checkout.create')}},
    billingPortal:{configurations:{retrieve:async id=>{calls.portal.push(id);check('portal');return copy(options.portal);}},sessions:{create:async p=>{
      calls.session.push(copy(p));check('session');return {id:'bps_synthetic',livemode:true,customer:p.customer,configuration:p.configuration,
        return_url:p.return_url,locale:p.locale,flow:null,on_behalf_of:null,url:'https://billing.stripe.com/p/session/live_synthetic_'+calls.session.length,...copy(options.session)};}}},
  };
  const d={stripe,config:options.config,readBilling:async uid=>{calls.read.push(uid);check('read');return copy(options.source);},
    resolveCustomer:async p=>{calls.resolve.push(copy(p));check('resolve');return copy(options.resolved);},writeBilling:forbidden('billing.write')};
  const engine=createWebBillingPortalEngine(d);
  return {options,calls,d,create:(who=identity)=>engine.create(who)};
}
async function rejects(f,code='unavailable'){
  await assert.rejects(()=>f.create(),e=>e.code===code && e.message===code);
  assert.equal(f.calls.session.length,0);assert.deepEqual(f.calls.forbidden,[]);
}
test('existing Live contract returns only a fresh Portal URL with pinned config, UID Customer and fixed return',async()=>{
  const f=fixture();const first=await f.create();const second=await f.create();
  assert.deepEqual(Object.keys(first),['url']);assert.notEqual(first.url,second.url);
  assert.deepEqual(f.calls.read,[UID,UID]);assert.deepEqual(f.calls.resolve,[{uid:UID,mode:'require-existing'},{uid:UID,mode:'require-existing'}]);
  assert.deepEqual(f.calls.session[0],{customer:CUSTOMER,configuration:CONFIG,return_url:WEB_BILLING_PORTAL_RETURN_URL,locale:'ja'});
  assert.deepEqual(f.calls.forbidden,[]);assert.doesNotMatch(JSON.stringify(first),/cus_|sub_|bpc_|synthetic-production-portal-owner/);
});
for(const status of WEB_PORTAL_MANAGEABLE_STATUSES)test('existing '+status+' contract keeps management without granting access',async()=>{
  const f=fixture();f.options.subscriptions[0].status=status;
  if(status==='trialing')f.options.subscriptions[0].trial_end=1792592000;
  await f.create();assert.equal(f.calls.session.length,1);assert.deepEqual(f.calls.forbidden,[]);
});
test('configured old 500 JPY exclusive archived Price is managed without migration or creation',async()=>{
  const f=fixture();f.options.price=price(true);f.options.price.active=false;f.options.subscriptions[0].items.data[0].price=copy(f.options.price);
  await f.create();assert.deepEqual(f.calls.price,[LEGACY]);assert.deepEqual(f.calls.forbidden,[]);
});
test('an existing legacy coupon, Customer balance and discount stay intact during management',async()=>{
  const f=fixture();f.options.price=price(true);f.options.subscriptions[0].items.data[0].price=copy(f.options.price);
  f.options.subscriptions[0].discount={coupon:{percent_off:100,duration:'forever'}};
  f.options.subscriptions[0].discounts=['di_synthetic'];f.options.customer.balance=-500;
  f.options.customer.discount={coupon:{percent_off:100,duration:'forever'}};
  await f.create();assert.deepEqual(f.calls.forbidden,[]);
});
test('owned existing flexible old500 with a forever 100 percent coupon keeps management unchanged',async()=>{
  const f=fixture();f.options.price=price(true);f.options.subscriptions[0].items.data[0].price=copy(f.options.price);
  f.options.subscriptions[0].billing_mode={type:'flexible',flexible:{proration_discounts:'included'}};
  f.options.subscriptions[0].discount={coupon:{percent_off:100,duration:'forever'}};
  f.options.subscriptions[0].discounts=['di_synthetic'];
  const before=copy(f.options.subscriptions[0]);await f.create();
  assert.deepEqual(f.options.subscriptions[0],before);assert.deepEqual(f.calls.forbidden,[]);assert.equal(f.calls.session.length,1);
});
test('flexible mode never bypasses the existing legacy subscription anchor',async()=>{
  const f=fixture();f.options.price=price(true);f.options.subscriptions[0].items.data[0].price=copy(f.options.price);
  f.options.subscriptions[0].billing_mode={type:'flexible'};
  f.options.source.data.stripeSubscriptionId='sub_synthetic_foreign';await rejects(f);
});
test('configured legacy Price without the exact current stored subscription is refused',async()=>{
  const f=fixture();f.options.price=price(true);f.options.subscriptions[0].items.data[0].price=copy(f.options.price);
  f.options.source.data.stripeSubscriptionId='sub_synthetic_other';await rejects(f);
});
test('new 550 and old 500 subscriptions on the same UID Customer are both recognized',async()=>{
  const f=fixture();const old=sub();old.id='sub_synthetic_old';old.items.data[0].price=price(true);old.status='canceled';
  f.options.source.data.stripeSubscriptionId=old.id;
  f.options.subscriptions.push(old);
  // Return each synthetic configured Price by its exact ID.
  f.d.stripe.prices.retrieve=async id=>{f.calls.price.push(id);return price(id===LEGACY);};
  await f.create();assert.deepEqual(f.calls.price,[PRICE,LEGACY]);
});
test('cancel at period end and expired current period do not block payment management',async()=>{
  const f=fixture();f.options.subscriptions[0].cancel_at_period_end=true;await f.create();assert.deepEqual(f.calls.forbidden,[]);
});
test('verified Apple session without contact email keeps existing contract management',async()=>{
  const f=fixture();await f.create({uid:UID,emailVerified:false,authBasis:'apple_provider'});assert.equal(f.calls.session.length,1);
});
for(const email of [undefined,'synthetic-unverified@example.test'])test('verified Firebase management session keeps existing cancellation access with '+(email?'unverified':'absent')+' email',async()=>{
  const f=fixture();const proof=authorizeWebBillingManagementIdentity({uid:UID,firebase:{sign_in_provider:'password'}},
    {uid:UID,disabled:false,emailVerified:false,...(email?{email}:{})});
  await f.create(proof);assert.equal(f.calls.session.length,1);assert.equal(proof.emailVerified,false);
  assert.equal(proof.email,undefined);
  assert.deepEqual(f.calls.resolve,[{uid:UID,mode:'require-existing'}]);assert.deepEqual(f.calls.forbidden,[]);
});
test('valid management proof for another UID cannot manage the current UID Customer',async()=>{
  const f=fixture();await assert.rejects(()=>f.create({uid:'synthetic-other',emailVerified:false,authBasis:'firebase_session'}),e=>e.code==='unavailable');
  assert.equal(f.calls.session.length,0);assert.deepEqual(f.calls.forbidden,[]);
});
for(const [name,proof,code] of [
  ['absent basis',{uid:UID,emailVerified:true},'email_unverified'],
  ['empty basis',{uid:UID,emailVerified:true,authBasis:''},'email_unverified'],
  ['invented basis',{uid:UID,emailVerified:true,authBasis:'forged_management'},'email_unverified'],
  ['missing verification field',{uid:UID,authBasis:'firebase_session'},'unauthenticated'],
  ['string verification field',{uid:UID,emailVerified:'false',authBasis:'firebase_session'},'unauthenticated'],
  ['missing UID',{emailVerified:false,authBasis:'firebase_session'},'unauthenticated'],
  ['empty UID',{uid:'',emailVerified:false,authBasis:'firebase_session'},'unauthenticated'],
  ['path UID',{uid:'synthetic/other',emailVerified:false,authBasis:'firebase_session'},'unauthenticated'],
])test('malformed management proof '+name+' is refused before billing or Stripe access',async()=>{
  const f=fixture();await assert.rejects(()=>f.create(proof),e=>e.code===code);
  for(const entries of Object.values(f.calls))assert.deepEqual(entries,[]);
});
for(const status of ['canceled','incomplete_expired'])test(status+' contract cannot create a management Session',async()=>{
  const f=fixture();f.options.subscriptions[0].status=status;await rejects(f,'portal_not_available');
});
test('missing subscription does not create a Customer or purchase',async()=>{const f=fixture();f.options.subscriptions=[];await rejects(f,'portal_not_available');});
test('cancellation racing list is re-read before a Portal Session is issued',async()=>{
  const f=fixture();f.options.canonical={...sub(),status:'canceled'};await rejects(f,'portal_not_available');
});
for(const [name,change] of [
  ['unknown status',f=>{f.options.subscriptions[0].status='unknown_future';}],
  ['deleted Customer',f=>{f.options.customer={id:CUSTOMER,deleted:true};}],
  ['unmapped Customer',f=>{f.options.resolved={};}],
  ['other UID Customer',f=>{f.options.customer.metadata.firebaseUid='synthetic-other';}],
  ['other UID subscription',f=>{f.options.subscriptions[0].metadata.firebaseUid='synthetic-other';}],
  ['other Customer subscription',f=>{f.options.subscriptions[0].customer='cus_synthetic_other';}],
  ['Preview Customer',f=>{f.options.customer.metadata.previewScope='task4';}],
  ['Preview subscription',f=>{f.options.subscriptions[0].metadata.previewFirebaseUid=UID;}],
  ['unavailable billing',f=>{f.options.source={kind:'unavailable'};}],
  ['explicit Test billing',f=>{f.options.source.data.stripeLivemode=false;}],
  ['different billing UID',f=>{f.options.source.data.firebaseUid='synthetic-other';}],
  ['paginated subscriptions',f=>{f.options.hasMore=true;}],
  ['unknown historic Price',f=>{const old=sub();old.id='sub_synthetic_unknown';old.status='canceled';old.items.data[0].price.id='price_unmapped';f.options.subscriptions.push(old);}],
  ['wrong subscription quantity',f=>{f.options.subscriptions[0].items.data[0].quantity=2;}],
  ['flexible billing mode',f=>{f.options.subscriptions[0].billing_mode={type:'flexible'};}],
])test(name+' fails without any financial or billing mutation',async()=>{const f=fixture();change(f);await rejects(f);});
test('absent legacy UID metadata requires both exact Customer and exact subscription billing anchors',async()=>{
  const f=fixture();delete f.options.customer.metadata.firebaseUid;delete f.options.subscriptions[0].metadata.firebaseUid;await f.create();
  const other=fixture();delete other.options.customer.metadata.firebaseUid;other.options.source={kind:'missing'};await rejects(other);
  const missing=fixture();delete missing.options.subscriptions[0].metadata.firebaseUid;delete missing.options.source.data.stripeSubscriptionId;await rejects(missing);
});
test('UID metadata permits an existing resolvable contract when old billing document is missing',async()=>{
  const f=fixture();f.options.source={kind:'missing'};await f.create();assert.deepEqual(f.calls.forbidden,[]);
});
for(const [name,change] of [
  ['Customer',f=>{f.options.customer.livemode=false;}],['subscription',f=>{f.options.subscriptions[0].livemode=false;}],
  ['Price',f=>{f.options.price.livemode=false;}],['embedded Price',f=>{f.options.subscriptions[0].items.data[0].price.livemode=false;}],
  ['Portal Configuration',f=>{f.options.portal.livemode=false;}],
  ['Product',f=>{f.options.price.product.livemode=false;}],
])test('Test mode '+name+' fails closed',async()=>{const f=fixture();change(f);await rejects(f);});
for(const [name,change] of [
  ['customer updates',p=>{p.features.customer_update.enabled=true;}],['price or quantity updates',p=>{p.features.subscription_update.enabled=true;}],
  ['immediate cancellation',p=>{p.features.subscription_cancel.mode='immediately';}],['proration',p=>{p.features.subscription_cancel.proration_behavior='create_prorations';}],
  ['retention',p=>{p.features.subscription_cancel.retention={type:'coupon_offer'};}],['promotion',p=>{p.features.subscription_cancel.promotion_code='promo_synthetic';}],
  ['new feature',p=>{p.features.subscription_purchase={enabled:true};}],['login page',p=>{p.login_page.enabled=true;}],
  ['wrong Configuration',p=>{p.id='bpc_other';}],['inactive Configuration',p=>{p.active=false;}],
  ['Preview metadata',p=>{p.metadata.previewPurpose='task6';}],['Preview return URL',p=>{p.default_return_url='https://hamster-breeding-app--preview.web.app/account/';}],
])test('unsafe Portal Configuration '+name+' fails',async()=>{const f=fixture();change(f.options.portal);await rejects(f);});
test('disabled future Portal feature stays unavailable',async()=>{const f=fixture();f.options.portal.features.subscription_pause={enabled:false};await f.create();});
for(const [name,change] of [
  ['missing Portal Configuration',c=>{delete c.portalConfigurationId;}],['Test credentials',c=>{c.secretKey='sk_test_SYNTHETIC';}],
  ['Preview return URL',c=>{c.returnUrl='https://hamster-breeding-app--preview.web.app/account/';}],
  ['arbitrary return URL',c=>{c.returnUrl='https://untrusted.example.test/';}],['arbitrary origin',c=>{c.origin='https://untrusted.example.test';}],
])test(name+' is refused before Firestore or Stripe access',async()=>{
  const f=fixture();change(f.options.config);await rejects(f);for(const entries of Object.values(f.calls))assert.deepEqual(entries,[]);
});
test('invalid injected configuration is rejected at construction before any dependency access',()=>{
  const f=fixture();delete f.options.config.portalConfigurationId;
  assert.throws(()=>createWebBillingPortalEngine(f.d),e=>e.code==='unavailable' && !e.message.includes(CONFIG));
  for(const entries of Object.values(f.calls))assert.deepEqual(entries,[]);
});
for(const name of ['read','resolve','customer','portal','price','list','retrieve','session'])test(name+' SDK error is sanitized',async()=>{
  const f=fixture();f.options.failure=name;
  await assert.rejects(()=>f.create(),e=>e.code==='unavailable' && e.message==='unavailable' && !JSON.stringify(e).includes('private'));
  assert.deepEqual(f.calls.forbidden,[]);
});
for(const [name,patch] of [
  ['Test Session',{livemode:false}],['wrong Customer',{customer:'cus_other'}],['wrong Configuration',{configuration:'bpc_other'}],
  ['wrong return URL',{return_url:'https://untrusted.example.test/'}],['wrong locale',{locale:'auto'}],
  ['deep link',{flow:{type:'subscription_update'}}],['connected account',{on_behalf_of:'acct_other'}],
  ['Test URL',{url:'https://billing.stripe.com/p/session/test_synthetic'}],
])test('unsafe response '+name+' never reaches caller',async()=>{
  const f=fixture();f.options.session=patch;await assert.rejects(()=>f.create(),e=>e.code==='unavailable');assert.deepEqual(f.calls.forbidden,[]);
});
for(const url of ['https://billing.stripe.com/p/session/live_synthetic','https://billing.stripe.com/p/session?secret=live_synthetic'])test('accepts official Live Portal URL '+url,()=>{assert.equal(isWebBillingPortalSessionUrl(url),true);});
for(const url of ['http://billing.stripe.com/p/session/live_synthetic','https://billing.stripe.com.evil.test/p/session/live_synthetic',
  'https://billing.stripe.com/p/session/test_synthetic','https://billing.stripe.com/p/session?secret=test_synthetic',
  'https://billing.stripe.com/p/session/live_synthetic#x','https://billing.stripe.com/p/session/live_synthetic?redirect=x',
  'https://user@billing.stripe.com/p/session/live_synthetic','https://billing.stripe.com:444/p/session/live_synthetic',
  'https://billing.stripe.com/p/session?secret=live_synthetic&secret=other','https://billing.stripe.com/p/session/live_synthetic\n'])test('refuses unsafe URL '+JSON.stringify(url),()=>{assert.equal(isWebBillingPortalSessionUrl(url),false);});
