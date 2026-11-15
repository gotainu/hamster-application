'use strict';
// Pure synthetic Stripe and read-only in-memory binding. No keys or network.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createPreviewPortalEngine,isPreviewPortalSessionUrl,PREVIEW_PORTAL_PURPOSE,
  PREVIEW_PORTAL_RETURN_URL,PREVIEW_PORTAL_MANAGEABLE_STATUSES}=require('../lib/preview-functions/src/portal-engine');
const {SCOPE,hash}=require('../lib/preview-functions/src/engine');
const {PREVIEW_SYNC_EVENT_TYPES}=require('../lib/preview-functions/src/subscription-sync');
const OWNER={uid:'synthetic-portal-owner',emailVerified:true};
const SUBJECT=hash(OWNER.uid), CUSTOMER='cus_synthetic_portal_owner', PRICE='price_synthetic_550', CONFIG='bpc_synthetic_task6';
const NOW=new Date('2026-11-15T01:00:00.000Z');const SEC=NOW.getTime()/1000;
const WEBHOOK={id:'we_synthetic_task5',url:'https://preview-webhook.example.test/endpoint',events:[...PREVIEW_SYNC_EVENT_TYPES]};
const copy=value=>structuredClone(value);
const missing=()=>({kind:'missing'});
const metadata=(extra={})=>({previewScope:SCOPE,previewFirebaseUid:OWNER.uid,previewSubjectHash:SUBJECT,previewPlan:'premium_monthly',...extra});
const product=()=>({id:'prod_synthetic_preview',livemode:false,metadata:{previewScope:SCOPE},active:true});
const price=()=>({id:PRICE,livemode:false,active:true,type:'recurring',unit_amount:550,currency:'jpy',tax_behavior:'inclusive',recurring:{interval:'month',interval_count:1},product:product(),metadata:{previewScope:SCOPE}});
const subscription=(overrides={})=>({id:'sub_synthetic_managed',livemode:false,customer:CUSTOMER,status:'active',created:SEC-600,
  metadata:metadata({previewAttempt:'synthetic-attempt'}),items:{data:[{id:'si_synthetic',quantity:1,price:price()}],has_more:false},
  automatic_tax:{enabled:false},discount:null,discounts:[],default_tax_rates:[],current_period_start:SEC-600,current_period_end:SEC+86400,
  cancel_at_period_end:false,trial_end:null,...overrides});
const configuration=()=>({id:CONFIG,livemode:false,active:true,metadata:{previewScope:SCOPE,previewPurpose:PREVIEW_PORTAL_PURPOSE},
  login_page:{enabled:false,url:null},default_return_url:PREVIEW_PORTAL_RETURN_URL,
  features:{customer_update:{enabled:false,allowed_updates:['email','tax_id']},subscription_update:{enabled:false,default_allowed_updates:[]},
    payment_method_update:{enabled:true},invoice_history:{enabled:true},
    subscription_cancel:{enabled:true,mode:'at_period_end',proration_behavior:'none',cancellation_reason:{enabled:true,
      options:['too_expensive','unused','missing_features','too_complex','switched_service','other']}}}});
function fixture(dependencyOverrides={}){
  const options={state:{previewFirebaseUid:OWNER.uid,customerId:CUSTOMER},
    app:{appAccountExists:true,billing:missing(),trial:missing(),nickname:'合成検証',maskedEmail:'非公開'},
    customer:{id:CUSTOMER,livemode:false,metadata:metadata(),balance:0,discount:null,discounts:[]},
    price:price(),product:product(),config:configuration(),subscriptions:[subscription()],canonical:null,
    webhook:{data:[{id:WEBHOOK.id,url:WEBHOOK.url,status:'enabled',livemode:false,api_version:'2025-02-24.acacia',enabled_events:[...WEBHOOK.events]}],has_more:false},
    subscriptionHasMore:false,session:{},failure:null,clock:NOW};
  const calls={facts:[],store:[],customer:[],price:[],product:[],config:[],list:[],retrieve:[],webhook:[],create:[]};
  function check(name){if(options.failure===name)throw Object.assign(new Error('synthetic-private-uid cus_private https://billing.stripe.com/p/session/test_private'),{code:'raw_private_sdk_error'});}
  const stripe={
    customers:{async retrieve(id){calls.customer.push(id);check('customer');return copy(options.customer);}},
    prices:{async retrieve(id){calls.price.push(id);check('price');return copy(options.price);}},
    products:{async retrieve(id){calls.product.push(id);check('product');return copy(options.product);}},
    subscriptions:{async list(query){calls.list.push(copy(query));check('list');return {data:copy(options.subscriptions),has_more:options.subscriptionHasMore};},
      async retrieve(id){calls.retrieve.push(id);check('retrieve');return copy(options.canonical||options.subscriptions.find(s=>s.id===id));}},
    webhookEndpoints:{async list(query){calls.webhook.push(copy(query));check('webhook');return copy(options.webhook);}},
    billingPortal:{configurations:{async retrieve(id){calls.config.push(id);check('config');return copy(options.config);}},
      sessions:{async create(...args){calls.create.push(copy(args));check('create');const params=args[0];return {
        id:'bps_synthetic_'+calls.create.length,object:'billing_portal.session',livemode:false,customer:params.customer,
        configuration:params.configuration,return_url:params.return_url,locale:params.locale,flow:null,on_behalf_of:null,
        created:SEC,url:'https://billing.stripe.com/p/session/test_synthetic_'+calls.create.length,...copy(options.session)};}}},
  };
  const dependencies={stripe,store:{async read(subject){calls.store.push(subject);check('store');return copy(options.state);}},
    async readFacts(uid){calls.facts.push(uid);check('facts');return copy(options.app);},now:()=>new Date(options.clock),
    priceId:PRICE,configurationId:CONFIG,allowedWebhook:copy(WEBHOOK),...dependencyOverrides};
  const engine=createPreviewPortalEngine(dependencies);
  return {engine,options,calls,stripe,dependencies,create:(identity=OWNER)=>engine.create(identity)};
}
const rejects=async(f,code,...identities)=>{
  const identity=identities.length?identities[0]:OWNER;
  await assert.rejects(()=>f.engine.create(identity),e=>e.code===code&&e.message===code);
  assert.equal(f.calls.create.length,0);
};

test('normal Portal Session uses only bound Customer, pinned config, Japanese locale and fixed return URL',async()=>{
  const f=fixture();const response=await f.create();assert.deepEqual(Object.keys(response).sort(),['testMode','url']);
  assert.equal(response.testMode,true);assert.equal(isPreviewPortalSessionUrl(response.url),true);
  assert.deepEqual(f.calls.store,[SUBJECT]);assert.deepEqual(f.calls.facts,[OWNER.uid]);
  assert.deepEqual(f.calls.create,[[{customer:CUSTOMER,configuration:CONFIG,return_url:PREVIEW_PORTAL_RETURN_URL,locale:'ja'}]]);
  assert.deepEqual(f.calls.list,[{customer:CUSTOMER,status:'all',limit:100}]);
  assert.doesNotMatch(JSON.stringify(response),/cus_|sub_|bpc_|synthetic-portal-owner|previewFirebaseUid/);
});
test('each user action makes a fresh Portal Session without idempotency URL reuse or storage writes',async()=>{
  const f=fixture();const before=copy(f.options.state);const first=await f.create();const second=await f.create();
  assert.notEqual(first.url,second.url);assert.equal(f.calls.create.length,2);
  assert.ok(f.calls.create.every(args=>args.length===1));assert.deepEqual(f.options.state,before);
});
for(const status of PREVIEW_PORTAL_MANAGEABLE_STATUSES)test('manageable '+status+' retains Portal access without changing entitlement',async()=>{
  const f=fixture();f.options.subscriptions[0].status=status;if(status==='trialing')f.options.subscriptions[0].trial_end=SEC+86400;
  const before=copy(f.options.subscriptions);assert.equal((await f.create()).testMode,true);assert.deepEqual(f.options.subscriptions,before);
});
for(const status of ['canceled','incomplete_expired'])test('terminal '+status+' cannot create a Portal Session',async()=>{
  const f=fixture();f.options.subscriptions[0].status=status;await rejects(f,'portal_not_available');
});
test('cancel-at-period-end contract remains manageable',async()=>{const f=fixture();f.options.subscriptions[0].cancel_at_period_end=true;await f.create();});
test('stale period end does not prevent payment-method management or imply an access grant',async()=>{
  const f=fixture();f.options.subscriptions[0].current_period_start=SEC-1000;f.options.subscriptions[0].current_period_end=SEC-1;
  assert.deepEqual(Object.keys(await f.create()).sort(),['testMode','url']);
});
test('preferred paid subscription outranks newer past_due history',async()=>{
  const f=fixture();f.options.subscriptions.push(subscription({id:'sub_synthetic_new_pastdue',status:'past_due',created:SEC+1}));
  await f.create();assert.deepEqual(f.calls.retrieve,['sub_synthetic_managed']);
});
test('without a paid candidate latest manageable history is retrieved canonically',async()=>{
  const f=fixture();f.options.subscriptions=[subscription({status:'past_due'}),subscription({id:'sub_synthetic_new',status:'unpaid',created:SEC+1})];
  await f.create();assert.deepEqual(f.calls.retrieve,['sub_synthetic_new']);
});
test('canonical cancellation after listing cannot retain stale eligibility',async()=>{
  const f=fixture();f.options.canonical=subscription({status:'canceled'});await rejects(f,'portal_not_available');
});
test('empty subscription list is not a reason to create a Customer or Checkout',async()=>{const f=fixture();f.options.subscriptions=[];await rejects(f,'portal_not_available');});

for(const [name,identity,code] of [
  ['absent',undefined,'unauthenticated'],['null',null,'unauthenticated'],['empty UID',{uid:'',emailVerified:true},'unauthenticated'],
  ['missing UID',{emailVerified:true},'unauthenticated'],['numeric UID',{uid:23,emailVerified:true},'unauthenticated'],
  ['slash UID',{uid:'owner/other',emailVerified:true},'unauthenticated'],['whitespace UID',{uid:'owner other',emailVerified:true},'unauthenticated'],
  ['control UID',{uid:'owner\u0000',emailVerified:true},'unauthenticated'],['long UID',{uid:'x'.repeat(129),emailVerified:true},'unauthenticated'],
  ['unverified',{uid:OWNER.uid,emailVerified:false},'email_unverified'],['missing verification',{uid:OWNER.uid},'email_unverified'],
])test('rejects '+name+' before data or Stripe access',async()=>{
  const f=fixture();await rejects(f,code,identity);assert.equal(f.calls.facts.length,0);assert.equal(f.calls.customer.length,0);
});
test('clock failures do not mint a management Session',async()=>{const f=fixture();f.options.clock=new Date('invalid');await rejects(f,'server_clock_invalid');});
test('server-only app-account presence is required',async()=>{const f=fixture();f.options.app.appAccountExists=false;await rejects(f,'app_account_required');});
for(const kind of ['denied','unavailable'])test('unresolved production billing '+kind+' fails closed',async()=>{
  const f=fixture();f.options.app.billing={kind};await rejects(f,'billing_unresolved');
});
for(const status of ['active','trialing'])test('existing app paid '+status+' cannot be confused with Preview management',async()=>{
  const f=fixture();f.options.app.billing={kind:'found',data:{plan:'paid',status}};await rejects(f,'existing_subscription');
});
for(const data of [{},{plan:'none',status:'past_due'},{plan:'none',status:'none',cancelAtPeriodEnd:true},{plan:'none',status:'none',cancelAtPeriodEnd:'false'}])test('malformed app billing remains unresolved '+JSON.stringify(data),async()=>{
  const f=fixture();f.options.app.billing={kind:'found',data};await rejects(f,'billing_unresolved');
});
for(const status of ['none','canceled'])test('coherent app '+status+' history permits isolated Test management',async()=>{
  const f=fixture();f.options.app.billing={kind:'found',data:{plan:'none',status}};await f.create();
});
for(const [name,patch] of [['missing binding',null],['unbound UID',{}],['another UID',{previewFirebaseUid:'synthetic-other',customerId:CUSTOMER}],['missing Customer',{previewFirebaseUid:OWNER.uid}],['arbitrary reference',{previewFirebaseUid:OWNER.uid,customerId:'https://untrusted.invalid'}]])test('root '+name+' is rejected',async()=>{
  const f=fixture();f.options.state=patch;await rejects(f,name==='arbitrary reference'?'portal_unavailable':'customer_unresolved');
});
for(const [name,patch,code] of [
  ['deleted',{deleted:true},'customer_unresolved'],['live',{livemode:true},'test_mode_required'],
  ['wrong ID',{id:'cus_another'},'customer_unresolved'],['missing metadata',{metadata:{}},'customer_unresolved'],
  ['wrong UID',{metadata:metadata({previewFirebaseUid:'synthetic-other'})},'customer_unresolved'],
  ['old hash-only binding',{metadata:{previewScope:SCOPE,previewSubjectHash:SUBJECT}},'customer_unresolved'],
  ['wrong hash',{metadata:metadata({previewSubjectHash:hash('other')})},'customer_unresolved'],
  ['wrong scope',{metadata:metadata({previewScope:'production'})},'customer_unresolved'],
  ['wrong plan',{metadata:metadata({previewPlan:'annual'})},'customer_unresolved'],
  ['credit balance',{balance:-550},'price_mismatch'],['coupon',{discount:{id:'di_synthetic'}},'price_mismatch'],
  ['discount list',{discounts:['di_synthetic']},'price_mismatch'],
])test('Customer '+name+' is rejected without search or mutation',async()=>{
  const f=fixture();Object.assign(f.options.customer,patch);await rejects(f,code);
});
for(const [name,patch] of [
  ['500 yen',{unit_amount:500}],['605 yen',{unit_amount:605}],['foreign currency',{currency:'usd'}],
  ['annual',{recurring:{interval:'year',interval_count:1}}],['multi-month',{recurring:{interval:'month',interval_count:2}}],
  ['exclusive tax',{tax_behavior:'exclusive'}],['wrong ID',{id:'price_other'}],['archived',{active:false}],
  ['unscoped',{metadata:{}}],['one-time',{type:'one_time'}],
])test('Price '+name+' cannot expose Portal management',async()=>{
  const f=fixture();Object.assign(f.options.price,patch);await rejects(f,'price_mismatch');
});
test('live Price is denied',async()=>{const f=fixture();f.options.price.livemode=true;await rejects(f,'test_mode_required');});
for(const patch of [{livemode:true},{deleted:true},{metadata:{}}])test('wrong Product is rejected '+JSON.stringify(patch),async()=>{
  const f=fixture();f.options.price.product='prod_synthetic_preview';Object.assign(f.options.product,patch);
  await rejects(f,patch.livemode?'test_mode_required':'price_mismatch');
});

for(const [name,change,code] of [
  ['live',s=>{s.livemode=true;},'test_mode_required'],['foreign Customer',s=>{s.customer='cus_other';},'customer_unresolved'],
  ['foreign UID',s=>{s.metadata.previewFirebaseUid='synthetic-other';},'customer_unresolved'],
  ['wrong scope',s=>{s.metadata.previewScope='production';},'customer_unresolved'],
  ['missing plan',s=>{delete s.metadata.previewPlan;},'customer_unresolved'],
  ['missing attempt',s=>{delete s.metadata.previewAttempt;},'subscription_unresolved'],
  ['unknown status',s=>{s.status='future_status';},'subscription_unresolved'],
  ['quantity change',s=>{s.items.data[0].quantity=2;},'price_mismatch'],
  ['extra item',s=>{s.items.data.push(copy(s.items.data[0]));},'price_mismatch'],
  ['pagination',s=>{s.items.has_more=true;},'price_mismatch'],
  ['wrong Price',s=>{s.items.data[0].price.id='price_other';},'price_mismatch'],
  ['foreign currency',s=>{s.items.data[0].price.currency='usd';},'price_mismatch'],
  ['annual item',s=>{s.items.data[0].price.recurring.interval='year';},'price_mismatch'],
  ['coupon',s=>{s.discount={id:'di_synthetic'};},'price_mismatch'],
  ['discount list',s=>{s.discounts=['di_synthetic'];},'price_mismatch'],
  ['automatic tax',s=>{s.automatic_tax.enabled=true;},'price_mismatch'],
  ['tax rate',s=>{s.default_tax_rates=['txr_synthetic'];},'price_mismatch'],
  ['invalid period',s=>{s.current_period_end=s.current_period_start;},'subscription_unresolved'],
  ['invalid cancel flag',s=>{s.cancel_at_period_end='false';},'subscription_unresolved'],
])test('Subscription '+name+' is rejected',async()=>{const f=fixture();change(f.options.subscriptions[0]);await rejects(f,code);});
test('unscoped canceled history also blocks Customer-wide Portal exposure',async()=>{
  const f=fixture();const history=subscription({id:'sub_synthetic_old',status:'canceled'});history.metadata.previewScope='other';f.options.subscriptions.push(history);await rejects(f,'customer_unresolved');
});
test('ambiguous paginated subscriptions are not silently truncated',async()=>{const f=fixture();f.options.subscriptionHasMore=true;await rejects(f,'subscription_unresolved');});
test('item-level period fields supported without changing access semantics',async()=>{
  const f=fixture();const sub=f.options.subscriptions[0];sub.items.data[0].current_period_start=sub.current_period_start;sub.items.data[0].current_period_end=sub.current_period_end;delete sub.current_period_start;delete sub.current_period_end;await f.create();
});

for(const [name,change] of [
  ['another config',c=>{c.id='bpc_other';}],['inactive',c=>{c.active=false;}],
  ['scope missing',c=>{c.metadata={};}],['wrong purpose',c=>{c.metadata.previewPurpose='other';}],
  ['shared login',c=>{c.login_page.enabled=true;}],['foreign return URL',c=>{c.default_return_url='https://untrusted.invalid';}],
  ['customer updates',c=>{c.features.customer_update.enabled=true;}],
  ['subscription updates',c=>{c.features.subscription_update.enabled=true;}],
  ['payment updates off',c=>{c.features.payment_method_update.enabled=false;}],
  ['invoice history off',c=>{c.features.invoice_history.enabled=false;}],
  ['cancellation off',c=>{c.features.subscription_cancel.enabled=false;}],
  ['immediate cancellation',c=>{c.features.subscription_cancel.mode='immediately';}],
  ['proration',c=>{c.features.subscription_cancel.proration_behavior='create_prorations';}],
  ['unknown enabled feature',c=>{c.features.subscription_pause={enabled:true};}],
  ['invalid reason code',c=>{c.features.subscription_cancel.cancellation_reason.options.push('private_custom_reason');}],
  ['duplicate reasons',c=>{c.features.subscription_cancel.cancellation_reason.options.push('unused');}],
])test('Configuration '+name+' fails closed',async()=>{const f=fixture();change(f.options.config);await rejects(f,'portal_configuration_invalid');});
test('live Portal Configuration is refused',async()=>{const f=fixture();f.options.config.livemode=true;await rejects(f,'test_mode_required');});
test('optional cancellation reasons may be disabled without blocking cancellation',async()=>{const f=fixture();f.options.config.features.subscription_cancel.cancellation_reason.enabled=false;await f.create();});
for(const value of [null,'https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/'])test('fixed Session return overrides safe/null config default '+value,async()=>{
  const f=fixture();f.options.config.default_return_url=value;await f.create();assert.equal(f.calls.create[0][0].return_url,PREVIEW_PORTAL_RETURN_URL);
});
test('disabled future feature never expands Portal actions',async()=>{const f=fixture();f.options.config.features.subscription_pause={enabled:false};await f.create();});

for(const [name,change] of [
  ['none',w=>{w.data=[];}],['additional enabled',w=>{w.data.push({...copy(w.data[0]),id:'we_other'});}],
  ['live',w=>{w.data[0].livemode=true;}],['wrong target',w=>{w.data[0].url='https://untrusted.invalid';}],
  ['wrong version',w=>{w.data[0].api_version='2025-03-31.basil';}],
  ['wrong events',w=>{w.data[0].enabled_events.push('customer.updated');}],['pagination',w=>{w.has_more=true;}],
])test('unresolved Webhook '+name+' blocks Session creation',async()=>{const f=fixture();change(f.options.webhook);await rejects(f,'test_webhook_unresolved');});
test('event order and disabled unrelated Test endpoints do not change pinned Webhook equivalence',async()=>{
  const f=fixture();f.options.webhook.data[0].enabled_events.reverse();f.options.webhook.data.push({id:'we_disabled',status:'disabled',livemode:false});await f.create();
});

for(const url of ['https://billing.stripe.com/p/session/test_synthetic_token-1',
  'https://billing.stripe.com/p/session?secret=test_synthetic_token-2'])test('accepts official Test Portal URL form '+(url.includes('?')?'query':'path'),async()=>{
  const f=fixture();f.options.session.url=url;assert.equal((await f.create()).url,url);
});
for(const url of [undefined,null,'',
  'http://billing.stripe.com/p/session/test_synthetic',
  'https://billing.stripe.com.evil.invalid/p/session/test_synthetic',
  'https://untrusted.invalid/p/session/test_synthetic',
  'https://billing.stripe.com:443/p/session/test_synthetic',
  'https://billing.stripe.com:8443/p/session/test_synthetic',
  'https://user@billing.stripe.com/p/session/test_synthetic',
  'https://billing.stripe.com/p/session/live_synthetic',
  'https://billing.stripe.com/p/session/test_synthetic#fragment',
  'https://billing.stripe.com/p/session/test_synthetic#',
  'https://billing.stripe.com/p/session/test_synthetic?next=https://untrusted.invalid',
  'https://billing.stripe.com/p/session?secret=live_synthetic',
  'https://billing.stripe.com/p/session?secret=test_synthetic&secret=test_other',
  'https://billing.stripe.com/p/session?secret=test_synthetic&next=https://untrusted.invalid',
  'https://billing.stripe.com/p/session?secret=test_synthetic#fragment',
  ' https://billing.stripe.com/p/session/test_synthetic',
  'https://billing.stripe.com/p/session/test_synthetic\n'])test('refuses unsafe Portal URL '+String(url),()=>{
  assert.equal(isPreviewPortalSessionUrl(url),false);
});
for(const [name,patch,code] of [
  ['live Session',{livemode:true},'test_mode_required'],['wrong Customer',{customer:'cus_other'},'portal_unavailable'],
  ['wrong config',{configuration:'bpc_other'},'portal_unavailable'],['open redirect',{return_url:'https://untrusted.invalid'},'portal_unavailable'],
  ['wrong locale',{locale:'auto'},'portal_unavailable'],['unexpected deep link',{flow:{type:'subscription_update'}},'portal_unavailable'],
  ['connected account',{on_behalf_of:'acct_synthetic'},'portal_unavailable'],['invalid URL',{url:'https://untrusted.invalid'},'portal_unavailable'],
])test('returned '+name+' is not forwarded',async()=>{
  const f=fixture();Object.assign(f.options.session,patch);
  await assert.rejects(()=>f.create(),e=>e.code===code&&e.message===code);
});
test('body-like extra identity fields cannot choose another return URL or Customer',async()=>{
  const f=fixture();await f.create({...OWNER,return_url:'https://untrusted.invalid',customerId:'cus_other',subscriptionId:'sub_other'});
  assert.equal(f.calls.create[0][0].return_url,PREVIEW_PORTAL_RETURN_URL);assert.equal(f.calls.create[0][0].customer,CUSTOMER);
});
for(const point of ['facts','store','customer','price','product','config','list','retrieve','webhook','create'])test('SDK failure at '+point+' is sanitized',async()=>{
  const f=fixture();f.options.failure=point;if(point==='product')f.options.price.product='prod_synthetic_preview';
  await assert.rejects(()=>f.create(),e=>e.code==='portal_unavailable'&&e.message==='portal_unavailable');
});
for(const override of [{priceId:'price_other?bad'},{configurationId:'bpc_other/invalid'},{allowedWebhook:null}])test('invalid pinned server configuration is rejected '+JSON.stringify(override),()=>{
  assert.throws(()=>fixture(override),e=>e.code==='test_configuration_invalid');
});

test('canonical lookup must return the selected subscription rather than another owned ID',async()=>{
  const f=fixture();f.options.canonical=subscription({id:'sub_synthetic_unexpected'});await rejects(f,'subscription_unresolved');
});
test('trialing without a canonical trial end is unresolved rather than assumed valid',async()=>{
  const f=fixture();f.options.subscriptions[0].status='trialing';await rejects(f,'subscription_unresolved');
});

test('explicit flexible billing cannot masquerade as the approved classic period-end cancellation model',async()=>{
  const f=fixture();f.options.subscriptions[0].billing_mode={type:'flexible'};await rejects(f,'subscription_unresolved');
});

for(const status of ['canceled','incomplete_expired'])test('Task4 legacy '+status+' history without UID does not block the current strictly bound contract',async()=>{
  const f=fixture();const history=subscription({id:'sub_synthetic_legacy_'+status,status,created:SEC-2000});
  delete history.metadata.previewFirebaseUid;f.options.subscriptions.push(history);
  const before=copy(f.options.subscriptions);assert.equal((await f.create()).testMode,true);
  assert.deepEqual(f.calls.retrieve,['sub_synthetic_managed']);assert.deepEqual(f.options.subscriptions,before);
});
test('two legacy canceled Task4 records and a current active contract match the observed owner history',async()=>{
  const f=fixture();for(const suffix of ['a','b']){const legacy=subscription({id:'sub_synthetic_legacy_'+suffix,status:'canceled',created:SEC-2000});delete legacy.metadata.previewFirebaseUid;f.options.subscriptions.push(legacy);}
  await f.create();assert.equal(f.calls.create.length,1);assert.deepEqual(f.calls.retrieve,['sub_synthetic_managed']);
});
for(const status of PREVIEW_PORTAL_MANAGEABLE_STATUSES)test('missing UID on manageable '+status+' is never treated as legacy ownership',async()=>{
  const f=fixture();const sub=f.options.subscriptions[0];sub.status=status;if(status==='trialing')sub.trial_end=SEC+86400;
  delete sub.metadata.previewFirebaseUid;await rejects(f,'customer_unresolved');
});
for(const explicitUid of [null,'','synthetic-another-owner'])test('legacy terminal record with explicit UID '+String(explicitUid)+' is refused',async()=>{
  const f=fixture();const legacy=subscription({id:'sub_synthetic_wrong_uid_history',status:'canceled'});legacy.metadata.previewFirebaseUid=explicitUid;f.options.subscriptions.push(legacy);await rejects(f,'customer_unresolved');
});
for(const [name,change,code] of [
  ['foreign Customer',s=>{s.customer='cus_another';},'customer_unresolved'],
  ['live object',s=>{s.livemode=true;},'test_mode_required'],
  ['foreign scope',s=>{s.metadata.previewScope='other';},'customer_unresolved'],
  ['foreign hash',s=>{s.metadata.previewSubjectHash=hash('another');},'customer_unresolved'],
  ['wrong plan',s=>{s.metadata.previewPlan='annual';},'customer_unresolved'],
  ['missing attempt',s=>{delete s.metadata.previewAttempt;},'subscription_unresolved'],
  ['wrong Price',s=>{s.items.data[0].price.id='price_other';},'price_mismatch'],
  ['wrong amount',s=>{s.items.data[0].price.unit_amount=500;},'price_mismatch'],
  ['extra quantity',s=>{s.items.data[0].quantity=2;},'price_mismatch'],
  ['discount',s=>{s.discount={id:'di_synthetic'};},'price_mismatch'],
])test('legacy terminal allowance still rejects '+name,async()=>{
  const f=fixture();const legacy=subscription({id:'sub_synthetic_invalid_legacy',status:'canceled'});delete legacy.metadata.previewFirebaseUid;change(legacy);f.options.subscriptions.push(legacy);await rejects(f,code);
});
test('legacy terminal history alone is not a manageable contract',async()=>{
  const f=fixture();f.options.subscriptions[0].status='canceled';delete f.options.subscriptions[0].metadata.previewFirebaseUid;await rejects(f,'portal_not_available');
});
for(const [name,value] of [['retention',{type:'coupon_offer',coupon_offer:{coupon:'coupon_synthetic'}}],['retention',{}],
  ['coupon','coupon_synthetic'],['coupon_offer',{coupon:'coupon_synthetic'}],['offer',{type:'coupon'}],
  ['promotion_code','promo_synthetic'],['discount',{coupon:'coupon_synthetic'}]])test('Portal cancellation '+name+' retention/offer is forbidden '+JSON.stringify(value),async()=>{
  const f=fixture();f.options.config.features.subscription_cancel[name]=value;await rejects(f,'portal_configuration_invalid');
});
test('explicit null retention is compatible with no retention offer',async()=>{
  const f=fixture();f.options.config.features.subscription_cancel.retention=null;await f.create();
});
