'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource(),{billingNotificationsFromHooks}=load('billingNotificationEvents');
const {validBillingNotificationRecord}=load('billingNotificationWorker');
const {renderBillingNotification}=load('billingNotificationTemplates');
const hash=v=>createHash('sha256').update(v).digest('hex'),NOW=Date.UTC(2030,0,1),SUB='sub_syntheticNotification',UID='synthetic-notification-owner';
const base={amount:550,legacyPrice:false,currency:'jpy',interval:'month',status:'active',trialEndSeconds:null,
  currentPeriodStartSeconds:NOW/1000,currentPeriodEndSeconds:NOW/1000+30*86400,nextChargeAtSeconds:NOW/1000+30*86400,
  latestInvoicePaymentStatus:'paid',latestInvoiceAmountPaid:550,latestInvoiceTotal:550,canceledAtSeconds:null,cancelAtPeriodEnd:false};
function hook(type,extra={}){return {id:hash(type),type,firebaseUid:UID,subscriptionId:SUB,invoiceId:'in_syntheticInitial',
  transitionKey:type+':'+SUB,eventHash:hash(type),status:'pending',createdAtMillis:NOW,...extra};}
function records(hooks,billing={},environment='live'){return billingNotificationsFromHooks({billing:{...base,...billing},hooks,environment});}
test('contract and trial registration hooks collapse to one immutable, runnable notification',()=>{
  const out=records([hook('contract_started'),hook('trial_started')],{status:'trialing',trialEndSeconds:NOW/1000+7*86400,
    nextChargeAtSeconds:NOW/1000+7*86400,latestInvoicePaymentStatus:'no_payment_required',latestInvoiceAmountPaid:0,latestInvoiceTotal:0});
  assert.equal(out.length,1);assert.equal(out[0].type,'contract_registered');assert.equal(out[0].dispatchAtMillis,NOW);
  assert.equal(out[0].attempts,0);assert.equal(out[0].status,'pending');assert.equal(validBillingNotificationRecord(out[0],out[0].id,'live'),true);
  const message=renderBillingNotification({type:out[0].type,mode:'live',snapshot:out[0].snapshot});
  assert.match(message.text,/0円/);assert.match(message.text,/550円/);
});
test('different Stripe success hook classifications share an invoice semantic key',()=>{
  const first=records([hook('first_charge')])[0],renewal=records([hook('renewal',{eventHash:hash('another_event')})])[0];
  assert.equal(first.id,renewal.id);assert.equal(first.type,'payment_success');
  const next=records([hook('renewal',{invoiceId:'in_syntheticNext'})])[0];assert.notEqual(first.id,next.id);
});
test('repeated failed collection attempts for one invoice produce one notification',()=>{
  const a=records([hook('payment_failed',{transitionKey:'failed:invoice:1'})])[0];
  const b=records([hook('payment_failed',{transitionKey:'failed:invoice:2',eventHash:hash('retry')})])[0];
  assert.equal(a.id,b.id);assert.equal(a.type,'payment_failed');
});
for(const type of ['cancel_reserved','resumed','canceled'])test(type+' produces its own repeatable semantic notification',()=>{
  const a=records([hook(type)])[0],b=records([hook(type)])[0];assert.equal(a.id,b.id);assert.equal(a.type,type);
});
test('distinct real cancellation transitions can notify within the same period',()=>{
  const a=records([hook('cancel_reserved',{transitionKey:'cancel:transitionA'})])[0];
  const b=records([hook('cancel_reserved',{transitionKey:'cancel:transitionB'})])[0];assert.notEqual(a.id,b.id);
});
test('no meaningful transitions enqueue no email',()=>{assert.deepEqual(records([]),[]);});
test('environments never share notification IDs and fixture source cannot authorize a Live send',()=>{
  const live=records([hook('first_charge')])[0],preview=records([hook('first_charge')],{},'preview')[0];assert.notEqual(live.id,preview.id);
  const fixture=billingNotificationsFromHooks({billing:base,hooks:[hook('first_charge')],environment:'live',trustedSource:'preview_fixture'})[0];
  assert.equal(validBillingNotificationRecord(fixture,fixture.id,'live'),false);
});
test('snapshot and persisted records contain no recipient, message body or mail credentials',()=>{
  const b={...base,email:'synthetic@example.test',secret:'synthetic-mail-secret'};
  const out=records([hook('first_charge')],b)[0];assert.doesNotMatch(JSON.stringify(out),/synthetic@example|synthetic-mail-secret|<html|refreshToken/);
  assert.deepEqual(Object.keys(out.snapshot).sort(),Object.keys(base).sort());assert.equal(out.uidHash,hash(UID));assert.equal(out.idempotencyKey,out.id);
  b.amount=500;assert.equal(out.snapshot.amount,550);
});
test('verified legacy contract facts remain 500 instead of being rewritten to 550',()=>{
  const n=records([hook('first_charge')],{amount:500,legacyPrice:true,latestInvoiceAmountPaid:500,latestInvoiceTotal:500})[0];
  const message=renderBillingNotification({type:n.type,mode:'live',snapshot:n.snapshot});assert.match(message.text,/500円/);assert.doesNotMatch(message.text,/550円/);
});

test('canonical Stripe time is preserved separately from later enqueue time',()=>{
  const eventCreatedSeconds=NOW/1000-3600;
  const n=records([hook('first_charge')],{sourceEventCreatedSeconds:eventCreatedSeconds})[0];
  assert.equal(n.createdAtMillis,NOW);assert.equal(n.eventCreatedAtMillis,eventCreatedSeconds*1000);
  assert.equal(n.snapshot.sourceEventCreatedSeconds,undefined);assert.equal(n.snapshot.eventCreatedAtMillis,undefined);
});
test('unknown canonical event time is not replaced with enqueue time',()=>{
  const n=records([hook('first_charge')])[0];assert.equal(n.eventCreatedAtMillis,undefined);
});
