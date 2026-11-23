'use strict';
// Sanitized structural review fixture. No live IDs, addresses or credentials.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const UID='synthetic-review-owner',CUSTOMER='cus_syntheticReview',SUB='sub_syntheticReview',PRICE='price_syntheticOld500';
const NOW=Date.UTC(2030,0,1),START=NOW/1000-86400,END=NOW/1000+30*86400;
const PATH='users/'+UID+'/billing/subscription',DELETE=Symbol('delete');
class Stamp {
  constructor(ms){this.ms=ms;this.seconds=Math.floor(ms/1000);this.nanoseconds=(ms%1000)*1e6;}
  toMillis(){return this.ms;}toDate(){return new Date(this.ms);}
}
function fixture(options={}) {
  const docs=new Map(),versions=new Map(),writes=[],calls=[];let seq=0,tail=Promise.resolve();
  const copy=v=>v instanceof Stamp?new Stamp(v.ms):Array.isArray(v)?v.map(copy):v&&typeof v==='object'?Object.fromEntries(Object.entries(v).map(([k,x])=>[k,copy(x)])):v;
  const seed=(p,v)=>{docs.set(p,copy(v));versions.set(p,++seq);};
  const ref=p=>({path:p,get:async()=>snap(p)});
  const snap=p=>({exists:docs.has(p),data:()=>copy(docs.get(p)),get:k=>copy(docs.get(p)?.[k]),
    updateTime:docs.has(p)?{seconds:versions.get(p),nanoseconds:0}:undefined});
  const db={doc:ref,collectionGroup(){throw Error('synthetic metadata-first lookup should not query');},async runTransaction(fn){
    const run=tail.then(async()=>{
      const pending=[];const result=await fn({get:r=>Promise.resolve(snap(r.path)),
        update:(r,v)=>pending.push(['update',r.path,v]),create:(r,v)=>pending.push(['create',r.path,v])});
      for(const [kind,p,value]of pending){if(kind==='create'&&docs.has(p))throw Object.assign(Error('synthetic duplicate'),{code:6});
        const next={...(kind==='update'?docs.get(p):{})};for(const [key,v]of Object.entries(value)){if(v===DELETE)delete next[key];else next[key]=v;}
        seed(p,next);writes.push([kind,p]);}
      return result;
    });tail=run.catch(()=>{});return run;
  }};
  const firestore=()=>db;firestore.Timestamp={fromMillis:ms=>new Stamp(ms)};
  firestore.FieldValue={serverTimestamp:()=>new Stamp(NOW),delete:()=>DELETE};
  const load=loadStarSource({admin:{firestore}}),{createLegacyWebBillingWebhook}=load('legacyWebBillingWebhook');
  const deletionPath=who=>load('accountDeletion').accountDeletionRef(db,who).path;
  seed(PATH,{provider:'stripe',stripeLivemode:true,plan:'paid',status:'active',stripeCustomerId:CUSTOMER,
    stripeSubscriptionId:SUB,stripePriceId:PRICE,currentPeriodEnd:new Stamp(END*1000-1000)});
  const remote={subscription:{id:SUB,livemode:true,customer:CUSTOMER,status:'active',metadata:{firebaseUid:UID},created:START,
    billing_mode:{type:'flexible',flexible:{proration_discounts:'included'}},
    current_period_start:START,current_period_end:END,cancel_at_period_end:false,cancel_at:null,canceled_at:null,
    trial_start:null,trial_end:null,discount:{coupon:{percent_off:100,duration:'forever'}},discounts:['di_syntheticReview'],
    items:{data:[{quantity:1,price:{id:PRICE,unit_amount:500,tax_behavior:'exclusive',currency:'jpy',product:'prod_syntheticReview'}}]}},
    invoice:{id:'in_syntheticReview',livemode:true,status:'paid',customer:CUSTOMER,subscription:SUB,total:0,amount_due:0,amount_paid:0}};
  let retrieves=0;
  const stripe={subscriptions:{retrieve:async id=>{calls.push(['subscription',id]);retrieves++;if(options.onRetrieve)options.onRetrieve(retrieves,{seed,remote,deletionPath,docs});return copy(remote.subscription);},
    list:async()=>{calls.push(['list']);return {data:[copy(remote.subscription)],has_more:false};}},
    invoices:{retrieve:async id=>{calls.push(['invoice',id]);return copy(remote.invoice);}},
    checkout:{sessions:{retrieve:async id=>{calls.push(['session',id]);return {id,livemode:true,mode:'subscription',subscription:SUB};}}}};
  const engine=createLegacyWebBillingWebhook({db,stripe});
  const event=(type='invoice.payment_succeeded',extra={})=>({id:'evt_syntheticReview',livemode:true,type,
    data:{object:{id:type.startsWith('invoice.')?remote.invoice.id:type.startsWith('checkout.')?'cs_syntheticReview':SUB}},...extra});
  return {engine,event,remote,docs,writes,calls,seed,deletionPath,billing:()=>docs.get(PATH)};
}
test('old signature continuity reuses canonical paid mapping for an existing flexible 100 percent review subscription',async()=>{
  const f=fixture(),before=structuredClone(f.remote);
  assert.deepEqual(await f.engine.process(f.event()),{result:'synced'});
  assert.equal(f.billing().plan,'paid');assert.equal(f.billing().status,'active');assert.equal(f.billing().stripePriceId,PRICE);
  assert.equal(f.billing().currentPeriodEnd.toMillis(),END*1000);assert.deepEqual(f.remote,before);
  assert.deepEqual(f.writes,[['update',PATH]]);assert.equal(f.calls.filter(([name])=>name==='subscription').length,2);
});
test('old subscription update and deletion payloads both re-fetch current canonical entitlement',async()=>{
  for(const type of ['customer.subscription.updated','customer.subscription.deleted']){
    const f=fixture();await f.engine.process(f.event(type));assert.equal(f.billing().plan,'paid');
    assert.equal(f.billing().stripeSubscriptionId,SUB);assert.equal(f.billing().currentPeriodEnd.toMillis(),END*1000);
  }
});
test('old invoice failure reads the canonical subscription instead of manufacturing a failed entitlement',async()=>{
  const f=fixture();await f.engine.process(f.event('invoice.payment_failed'));assert.equal(f.billing().status,'active');
  assert.equal(f.billing().plan,'paid');assert.equal(f.writes.length,1);
});
test('old route handles a modern invoice parent without an inline subscription reference',async()=>{
  const f=fixture();delete f.remote.invoice.subscription;f.remote.invoice.parent={subscription_details:{subscription:SUB}};
  await f.engine.process(f.event());assert.equal(f.billing().plan,'paid');
});
test('a different UID in event metadata never chooses the billing path',async()=>{
  const f=fixture();const e=f.event('customer.subscription.updated');e.data.object.metadata={firebaseUid:'synthetic-foreign'};
  await f.engine.process(e);assert.ok(f.writes.every(([,path])=>path===PATH));
});
test('confirmed deletion before processing suppresses old-path billing restoration',async()=>{
  const f=fixture();f.seed(f.deletionPath(UID),{status:'completed'});
  assert.deepEqual(await f.engine.process(f.event()),{result:'ignored'});assert.deepEqual(f.writes,[]);
});
test('deletion confirmed during canonical refresh is fenced atomically before the billing write',async()=>{
  const f=fixture({onRetrieve(n,{seed,deletionPath}){if(n===2)seed(deletionPath(UID),{status:'running',billingStopped:true});}});
  assert.deepEqual(await f.engine.process(f.event()),{result:'ignored'});assert.deepEqual(f.writes,[]);
});
test('an unconfirmed deletion or another UID fence does not discard normal renewal synchronization',async()=>{
  for(const which of ['pending','other']){
    const f=fixture();f.seed(f.deletionPath(which==='other'?'synthetic-other':UID),which==='other'?{status:'completed'}:{status:'running',billingStopped:false});
    assert.deepEqual(await f.engine.process(f.event()),{result:'synced'});assert.equal(f.writes.length,1);
  }
});
test('a changed billing snapshot forces canonical re-fetch instead of overwriting a concurrent successor',async()=>{
  const f=fixture({onRetrieve(n,{seed,docs}){if(n===2)seed(PATH,{...docs.get(PATH),unchangedMarker:true});}});
  await f.engine.process(f.event());assert.equal(f.calls.filter(([name])=>name==='subscription').length,3);
  assert.equal(f.billing().unchangedMarker,true);assert.equal(f.billing().currentPeriodEnd.toMillis(),END*1000);
});
test('cross-owner customer binding is rejected without mutation',async()=>{
  const f=fixture();f.seed(PATH,{...f.billing(),stripeCustomerId:'cus_syntheticForeign'});
  await assert.rejects(f.engine.process(f.event()),e=>e.code==='uid_binding_mismatch');assert.deepEqual(f.writes,[]);
});
test('unsupported and Test events never create receipts, outbox or billing changes',async()=>{
  const f=fixture();assert.deepEqual(await f.engine.process(f.event('invoice.paid')),{result:'ignored'});
  await assert.rejects(f.engine.process(f.event(undefined,{livemode:false})),e=>e.code==='live_mode_required');
  assert.deepEqual(f.writes,[]);assert.deepEqual(f.calls,[]);
});
