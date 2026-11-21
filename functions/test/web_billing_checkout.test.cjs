'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const {createWebBillingCheckout,WEB_BILLING_SCOPE,WEB_BILLING_TERMS,WEB_BILLING_QUOTES_MS}=loadStarSource()('webBillingCheckout');
const UID='synthetic-checkout-owner',CID='cus_syntheticOwner';
const clone=v=>structuredClone(v);
const deferred=()=>{let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};};
async function until(fn){for(let n=0;n<100;n++){if(fn())return;await new Promise(setImmediate);}assert.fail('synthetic operation did not start');}
const identity={uid:UID,emailVerified:true,authBasis:'verified_email',email:'synthetic@example.test'};
const config={secretKey:'sk_live_'+'synthetic',publishableKey:'pk_live_'+'synthetic',webhookSecret:'whsec_'+'synthetic',
  priceId:'price_syntheticNew550',legacyPriceId:'price_syntheticLegacy500',portalConfigurationId:'bpc_syntheticRestricted',
  origin:'https://hamster-breeding-app.web.app',returnUrl:'https://hamster-breeding-app.web.app/account/'};
function fixture(){
  let clock=Date.parse('2026-11-21T03:00:00.321Z'),n=0,tail=Promise.resolve(),sid=0;
  const states=new Map(),sessions=new Map(),keys=new Map(),invoices=new Map();
  const calls={facts:[],contact:[],price:[],customer:[],subscriptions:[],resolve:[],sessionCreate:[],sessionList:[],sessionRetrieve:[],expire:[],writes:[]};
  const p={id:config.priceId,livemode:true,active:true,unit_amount:550,currency:'jpy',type:'recurring',tax_behavior:'inclusive',
    recurring:{interval:'month',interval_count:1,usage_type:'licensed'},product:{id:'prod_synthetic',livemode:true,active:true}};
  const f={calls,states,sessions,invoices,price:p,customer:{id:CID,livemode:true,balance:0,discount:null,metadata:{firebaseUid:UID}},
    subscriptions:[],contact:'synthetic@example.test',facts:{appAccountExists:true,billing:{kind:'missing'},trial:{kind:'missing'},nickname:'Synthetic'},
    createHook:null,listHook:null,factsHook:null,resolveHook:null};
  const store={async read(uid){return clone(states.get(uid)||{});},async mutate(uid,fn){
    const previous=tail;let unlock;tail=new Promise(r=>{unlock=r;});await previous;
    try{const result=fn(clone(states.get(uid)||{}));states.set(uid,clone(result.state));calls.writes.push(uid);return result.result;}finally{unlock();}
  }};
  const stripe={
    prices:{async retrieve(id){calls.price.push(id);return clone(f.price);}},
    customers:{async retrieve(id){calls.customer.push(id);return clone(f.customer);}},
    subscriptions:{async list(input){calls.subscriptions.push(clone(input));return {has_more:false,data:clone(f.subscriptions)};}},
    invoices:{async retrieve(id){if(!invoices.has(id))throw Error('synthetic invoice absent');return clone(invoices.get(id));}},
    checkout:{sessions:{
      async list(input){calls.sessionList.push(clone(input));if(f.listHook)return f.listHook(input);return {has_more:false,data:[...sessions.values()].filter(s=>s.customer===input.customer).map(clone)};},
      async retrieve(id){calls.sessionRetrieve.push(id);if(!sessions.has(id))throw Error('synthetic Session absent');return clone(sessions.get(id));},
      async create(input,options){calls.sessionCreate.push(clone({input,options}));const number=calls.sessionCreate.length;
        const createOnce=()=>{if(keys.has(options.idempotencyKey))return clone(sessions.get(keys.get(options.idempotencyKey)));
          const id='cs_synthetic'+(++sid),value={id,livemode:true,status:'open',mode:input.mode,ui_mode:input.ui_mode,
            return_url:input.return_url,customer:input.customer,client_reference_id:input.client_reference_id,metadata:clone(input.metadata),
            currency:'jpy',amount_total:input.subscription_data.trial_end?0:550,automatic_tax:{enabled:false},allow_promotion_codes:false,
            total_details:{amount_discount:0,amount_tax:0},line_items:{has_more:false,data:[{quantity:1,price:clone(p)}]},
            subscription:null,client_secret:id+'_secret_synthetic',expires_at:input.expires_at};
          sessions.set(id,value);keys.set(options.idempotencyKey,id);return clone(value);};
        return f.createHook?f.createHook({number,input,options,createOnce}):createOnce();},
      async expire(id){calls.expire.push(id);const s=sessions.get(id);s.status='expired';s.client_secret=null;return clone(s);},
    }},
  };
  f.dependencies={config:clone(config),stripe,store,readFacts:async uid=>{calls.facts.push(uid);return f.factsHook?f.factsHook():clone(f.facts);},
    readContact:async i=>{calls.contact.push(i.uid);return f.contact;},resolveCustomer:async input=>{calls.resolve.push(clone(input));return f.resolveHook?f.resolveHook():{customerId:CID};},
    now:()=>new Date(clock),randomToken:()=> 'synthetic-token-'+String(++n).padStart(6,'0')};
  f.engine=()=>createWebBillingCheckout(f.dependencies);f.advance=ms=>{clock+=ms;};f.now=()=>clock;
  f.review=()=>f.engine().review(identity,{planKey:'premium_monthly'});
  f.body=review=>({planKey:'premium_monthly',reviewToken:review.reviewToken,termsAccepted:true,termsVersion:WEB_BILLING_TERMS});
  f.create=review=>f.engine().create(identity,f.body(review));
  f.complete=({trialEnd=null,total=550}={})=>{const s=[...sessions.values()][0],attempt=s.metadata.webBillingAttempt;
    const sub={id:'sub_synthetic',livemode:true,customer:CID,metadata:{firebaseUid:UID,webBillingScope:WEB_BILLING_SCOPE,webBillingAttempt:attempt},
      trial_end:trialEnd,automatic_tax:{enabled:false},discount:null,discounts:[],default_tax_rates:[],
      items:{has_more:false,data:[{quantity:1,price:clone(p)}]},latest_invoice:'in_synthetic'};
    const invoice={id:'in_synthetic',livemode:true,customer:CID,subscription:sub.id,currency:'jpy',status:'paid',
      total,amount_due:total,amount_paid:total,billing_reason:'subscription_create',total_discount_amounts:[],default_tax_rates:[],total_tax_amounts:[],automatic_tax:{enabled:false}};
    s.status='complete';s.subscription=sub;s.client_secret=null;invoices.set(invoice.id,invoice);return {session:s,sub,invoice};};
  return f;
}
async function denied(p,code){await assert.rejects(p,e=>{if(code)assert.equal(e.code,code);assert.ok(e.code);assert.doesNotMatch(e.message,/cs_|cus_|sub_|synthetic|secret|@/);return true;});}
test('missing configuration fails before any facts, contact, Stripe or store operation',()=>{
  const f=fixture();f.dependencies.config={};assert.throws(()=>f.engine(),e=>e.code==='unavailable'&&e.message==='現在お申し込みを受け付けていません。');
  for(const rows of Object.values(f.calls))assert.equal(rows.length,0);
});
test('review returns one fixed 550JPY plan and masked contact without Customer or Session creation',async()=>{
  const f=fixture(),review=await f.review();assert.equal(review.unitAmount,550);assert.equal(review.currency,'jpy');assert.equal(review.interval,'month');
  assert.equal(review.chargeTiming,'immediate');assert.equal(review.maskedEmail,'sy***@example.test');assert.equal(review.termsVersion,WEB_BILLING_TERMS);
  assert.equal(f.calls.resolve.length,0);assert.equal(f.calls.sessionCreate.length,0);assert.doesNotMatch(JSON.stringify(review),/cus_|cs_|firebaseUid|synthetic@example/);
});
test('immediate Checkout rechecks authorities then creates fixed embedded Live 550JPY with UID binding',async()=>{
  const f=fixture(),review=await f.review(),result=await f.create(review),create=f.calls.sessionCreate[0];
  assert.deepEqual(Object.keys(result).sort(),['clientSecret','publishableKey']);assert.equal(result.publishableKey,config.publishableKey);
  assert.equal(create.input.ui_mode,'embedded');assert.equal(create.input.mode,'subscription');assert.equal(create.input.client_reference_id,UID);
  assert.deepEqual(create.input.line_items,[{price:config.priceId,quantity:1}]);assert.deepEqual(create.input.automatic_tax,{enabled:false});
  assert.equal(create.input.allow_promotion_codes,false);assert.equal(create.input.return_url,config.origin+'/billing/success/');
  assert.equal(create.input.metadata.firebaseUid,UID);assert.deepEqual(create.input.subscription_data.metadata,create.input.metadata);
  assert.equal(Object.hasOwn(create.input.subscription_data,'trial_end'),false);assert.equal(f.calls.facts.length,3);assert.equal(f.calls.contact.length,3);
  assert.equal(f.calls.subscriptions.length,2);assert.equal(f.states.get(UID).lease,undefined);assert.equal(f.states.get(UID).operation.sessionId,'cs_synthetic1');
});
test('active trial is exactly the existing rounded end with today0 and future550, never reset or extended',async()=>{
  const f=fixture(),end=new Date(f.now()+11*86400000);f.facts.trial={kind:'found',data:{status:'active',startedAt:new Date(f.now()-10*86400000),endsAt:end}};
  const before=clone(f.facts),review=await f.review();assert.equal(review.chargeTiming,'trial_end');assert.equal(review.firstChargeAtSeconds,Math.ceil(end.getTime()/1000));
  await f.create(review);assert.equal(f.calls.sessionCreate[0].input.subscription_data.trial_end,Math.ceil(end.getTime()/1000));assert.equal([...f.sessions.values()][0].amount_total,0);
  assert.deepEqual(f.facts,before);
});
for(const [name,mutate] of [
  ['500 price',f=>{f.price.unit_amount=500;}],['exclusive tax',f=>{f.price.tax_behavior='exclusive';}],['Test Price',f=>{f.price.livemode=false;}],
  ['Test Product',f=>{f.price.product.livemode=false;}],['deleted Product',f=>{f.price.product.deleted=true;}],['yearly',f=>{f.price.recurring.interval='year';}],
  ['missing contact',f=>{f.contact=null;}],['existing active app billing',f=>{f.facts.billing={kind:'found',data:{plan:'paid',status:'active'}};}],
])test('review rejects '+name+' before Customer or Session creation',async()=>{const f=fixture();mutate(f);await denied(f.review());assert.equal(f.calls.resolve.length,0);assert.equal(f.calls.sessionCreate.length,0);assert.equal(f.states.size,0);});
for(const [name,extra] of [['client UID',{uid:'synthetic-other'}],['client Price',{priceId:'price_syntheticOther'}],['client amount',{amount:1}],['client email',{email:'other@example.test'}],['false terms',{termsAccepted:false}],['wrong terms',{termsVersion:'synthetic-old'}]])
  test('create rejects '+name+' without financial mutation',async()=>{const f=fixture(),review=await f.review();await denied(f.engine().create(identity,{...f.body(review),...extra}));assert.equal(f.calls.resolve.length,0);assert.equal(f.calls.sessionCreate.length,0);});
for(const expiresAt of [undefined,null,'synthetic',NaN])test('malformed quote expiration fails closed: '+String(expiresAt),async()=>{
  const f=fixture(),review=await f.review();f.states.get(UID).quote.expiresAt=expiresAt;await denied(f.create(review),'review_expired');assert.equal(f.calls.resolve.length,0);
});
test('expired review cannot create a Customer or Session',async()=>{const f=fixture(),review=await f.review();f.advance(WEB_BILLING_QUOTES_MS);await denied(f.create(review),'review_expired');assert.equal(f.calls.resolve.length,0);assert.equal(f.calls.sessionCreate.length,0);});
test('contact changed during Customer resolution invalidates the existing operation before Session create',async()=>{
  const f=fixture(),review=await f.review();f.resolveHook=async()=>{f.contact='changed@example.test';return {customerId:CID};};
  await denied(f.create(review),'review_expired');assert.equal(f.calls.sessionCreate.length,0);assert.ok(f.states.get(UID).operation);assert.equal(f.states.get(UID).lease,undefined);
});
test('new app contract appearing after Customer resolution blocks a Session without resetting the attempt',async()=>{
  const f=fixture(),review=await f.review();f.resolveHook=async()=>{f.facts.billing={kind:'found',data:{plan:'paid',status:'active'}};return {customerId:CID};};
  await denied(f.create(review),'existing_subscription');assert.equal(f.calls.sessionCreate.length,0);assert.ok(f.states.get(UID).operation);
});
test('existing trial crossing the minimum during recovery blocks creation and preserves its original end',async()=>{
  const f=fixture(),end=new Date(f.now()+(48*3600+61)*1000);f.facts.trial={kind:'found',data:{status:'active',startedAt:new Date(f.now()-86400000),endsAt:end}};
  const review=await f.review();f.resolveHook=async()=>{f.advance(1001);return {customerId:CID};};
  await denied(f.create(review),'trial_too_short');assert.equal(f.calls.sessionCreate.length,0);assert.equal(f.facts.trial.data.endsAt.getTime(),end.getTime());
});
test('subscription appearing on the final Stripe check prevents duplicate Checkout',async()=>{
  const f=fixture(),review=await f.review(),list=f.dependencies.stripe.subscriptions.list;let n=0;
  f.dependencies.stripe.subscriptions.list=async input=>{if(++n===2)f.subscriptions=[{id:'sub_syntheticExisting',livemode:true,customer:CID,status:'active',metadata:{firebaseUid:UID}}];return list(input);};
  await denied(f.create(review),'existing_subscription');assert.equal(f.calls.sessionCreate.length,0);
});
test('a lost operation lease cannot issue a Session create or overwrite the new owner',async()=>{
  const f=fixture(),review=await f.review(),list=f.dependencies.stripe.subscriptions.list;let n=0;
  f.dependencies.stripe.subscriptions.list=async input=>{const value=await list(input);if(++n===2)f.states.get(UID).lease={token:'synthetic-takeover-token',until:f.now()+120000};return value;};
  await denied(f.create(review),'checkout_unresolved');assert.equal(f.calls.sessionCreate.length,0);assert.equal(f.states.get(UID).lease.token,'synthetic-takeover-token');
});
test('separate factories sharing one UID create one Session and reuse its client secret',async()=>{
  const f=fixture(),review=await f.review(),gate=deferred();f.createHook=async({createOnce})=>{await gate.promise;return createOnce();};
  const first=f.create(review);await until(()=>f.calls.sessionCreate.length===1);await denied(f.create(review),'checkout_busy');gate.resolve();
  const a=await first,b=await f.create(review);assert.deepEqual(a,b);assert.equal(f.calls.sessionCreate.length,1);assert.equal(f.sessions.size,1);
});
test('unknown remote creation result recovers the same Session without a new operation or idempotency key',async()=>{
  const f=fixture(),review=await f.review();f.createHook=({number,createOnce})=>{const s=createOnce();if(number===1)throw Error('synthetic Stripe timeout');return s;};
  await assert.rejects(f.create(review));const attempt=f.states.get(UID).operation.id;
  assert.equal(f.states.get(UID).operation.sessionId,undefined);assert.equal(f.states.get(UID).lease,undefined);
  assert.ok((await f.create(review)).clientSecret);assert.equal(f.calls.sessionCreate.length,1);assert.equal(f.states.get(UID).operation.id,attempt);
});
test('an unresolved expired operation is never reset into another Session',async()=>{
  const f=fixture(),review=await f.review();f.createHook=()=>{throw Error('synthetic unknown result');};await assert.rejects(f.create(review));
  const original=clone(f.states.get(UID).operation);f.advance(32*60000);const fresh=await f.review();await denied(f.create(fresh),'session_unresolved');
  assert.equal(f.calls.sessionCreate.length,1);assert.deepEqual(f.states.get(UID).operation,original);
});
test('completed Checkout is pending until matching production webhook billing has been reflected',async()=>{
  const f=fixture(),review=await f.review();await f.create(review);f.complete();const writesBeforeStatus=f.calls.writes.length;
  assert.deepEqual(await f.engine().status(identity),{checkoutStatus:'complete',billingState:'pending'});
  f.facts.billing={kind:'found',data:{stripeLivemode:true,firebaseUid:UID,stripeCustomerId:CID,stripeSubscriptionId:'sub_synthetic',status:'active'}};
  assert.deepEqual(await f.engine().status(identity),{checkoutStatus:'complete',billingState:'confirmed'});
  assert.equal(f.calls.writes.length,writesBeforeStatus);
});
for(const [name,mutate] of [
  ['foreign UID',s=>{s.metadata.firebaseUid='synthetic-other';}],['Test mode',s=>{s.livemode=false;}],['hosted UI',s=>{s.ui_mode='hosted';}],
  ['foreign return',s=>{s.return_url='https://example.test/';}],['500 total',s=>{s.amount_total=500;}],['605 total',s=>{s.amount_total=605;}],
  ['wrong Customer',s=>{s.customer='cus_syntheticOther';}],['Test line price',s=>{s.line_items.data[0].price.livemode=false;}],
  ['exclusive line tax',s=>{s.line_items.data[0].price.tax_behavior='exclusive';}],['discount',s=>{s.total_details.amount_discount=50;}],
])test('canonical status rejects '+name+' without billing writes',async()=>{
  const f=fixture(),review=await f.review();await f.create(review);mutate([...f.sessions.values()][0]);const before=f.calls.writes.length;
  await denied(f.engine().status(identity));assert.equal(f.calls.writes.length,before);
});
for(const [name,mutate] of [
  ['unexpected trial',({sub})=>{sub.trial_end=123;}],['550+tax invoice',({invoice})=>{invoice.total=605;invoice.amount_due=605;invoice.amount_paid=605;}],
  ['legacy500 invoice',({invoice})=>{invoice.total=500;invoice.amount_due=500;invoice.amount_paid=500;}],['credit offset',({invoice})=>{invoice.amount_due=0;invoice.amount_paid=0;}],
  ['discounted subscription',({sub})=>{sub.discounts=['synthetic'];}],['wrong Subscription Customer',({sub})=>{sub.customer='cus_syntheticOther';}],
  ['Test invoice',({invoice})=>{invoice.livemode=false;}],['foreign invoice Subscription',({invoice})=>{invoice.subscription='sub_syntheticOther';}],
])test('completed canonical validation rejects '+name,async()=>{
  const f=fixture(),review=await f.review();await f.create(review);const data=f.complete();mutate(data);await denied(f.engine().status(identity));
});
test('trial Checkout completion accepts its original zero-charge invoice',async()=>{
  const f=fixture(),end=new Date(f.now()+5*86400000);f.facts.trial={kind:'found',data:{status:'active',startedAt:new Date(f.now()-86400000),endsAt:end}};
  const review=await f.review();await f.create(review);f.complete({trialEnd:Math.ceil(end.getTime()/1000),total:0});
  assert.deepEqual(await f.engine().status(identity),{checkoutStatus:'complete',billingState:'pending'});
});
test('cancel expires only the UID-bound pending Session and removes coordination after canonical expiration',async()=>{
  const f=fixture(),review=await f.review();await f.create(review);assert.deepEqual(await f.engine().cancel(identity),{checkoutStatus:'expired'});
  assert.deepEqual(f.calls.expire,['cs_synthetic1']);assert.equal(f.states.get(UID).operation,undefined);assert.equal(f.states.get(UID).quote,undefined);
});
test('status and cancel reject an unconfirmed regular-email identity before reads or Stripe',async()=>{
  const f=fixture(),invalid={...identity,emailVerified:false};await denied(f.engine().status(invalid),'email_unverified');await denied(f.engine().cancel(invalid),'email_unverified');
  assert.equal(f.calls.sessionRetrieve.length,0);assert.equal(f.calls.writes.length,0);
});
