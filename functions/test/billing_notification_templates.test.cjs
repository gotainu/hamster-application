'use strict';
// Pure synthetic snapshots, no Auth client, mail transport or network calls.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const {renderBillingNotification,validateBillingNotificationSnapshot,billingNotificationLinks,
  formatBillingNotificationDate,BILLING_NOTIFICATION_TEMPLATE_VERSION}=loadStarSource()('billingNotificationTemplates');
const START=Date.UTC(2030,0,1)/1000,END=Date.UTC(2030,1,1)/1000;
const fixture=extra=>({amount:550,legacyPrice:false,currency:'jpy',interval:'month',status:'active',
  trialEndSeconds:null,currentPeriodStartSeconds:START,currentPeriodEndSeconds:END,nextChargeAtSeconds:END,
  latestInvoicePaymentStatus:'paid',latestInvoiceAmountPaid:550,latestInvoiceTotal:550,canceledAtSeconds:null,cancelAtPeriodEnd:false,...extra});
function input(type,extra={},mode='live'){return {type,mode,snapshot:fixture(extra)};}
const failed=()=>({status:'past_due',latestInvoicePaymentStatus:'unpaid',latestInvoiceAmountPaid:0});
const cases=[['contract_registered',{}],['payment_success',{}],['payment_failed',failed()],
  ['cancel_reserved',{cancelAtPeriodEnd:true}],['resumed',{}],['canceled',{status:'canceled',canceledAtSeconds:END,nextChargeAtSeconds:null}]];
for(const [type,extra]of cases)for(const mode of ['live','preview'])test(`${type} ${mode} renders Japanese plain+HTML and fixed management entrance`,()=>{
  const message=renderBillingNotification(input(type,extra,mode)),links=billingNotificationLinks(mode);
  assert.equal(message.templateVersion,'billing-v1');assert.match(message.subject,/【HamCare】/);
  assert.match(message.text,/月額550円/);assert.match(message.html,/月額550円/);
  assert.ok(message.text.includes(links.managementUrl));assert.ok(message.html.includes(links.managementUrl));
  assert.ok(message.html.includes(links.iconUrl));assert.match(message.html,/hamcare-mark-outline\.png/);
  assert.match(message.text,/gotainu@gmail\.com/);assert.match(message.html,/lang="ja"/);
  assert.doesNotMatch(message.html,/<script|<iframe|onload=|onclick=|<form|javascript:|background-image|data:/i);
  assert.doesNotMatch(message.text+message.html,/billing\.stripe\.com|checkout\.stripe\.com|sk_live_|pk_live_|_secret_|firebaseUid|cus_|sub_|税抜500円/);
  if(mode==='preview'){assert.match(message.subject,/^\[Preview\]/);assert.match(message.text,/本番の契約・請求は変更されていません/);}
  else{assert.doesNotMatch(message.subject+message.text,/Preview/);}
});
test('trial registration preserves0 today and the original first550 charge date',()=>{
  const message=renderBillingNotification(input('contract_registered',{status:'trialing',trialEndSeconds:END,
    latestInvoicePaymentStatus:'no_payment_required',latestInvoiceAmountPaid:0,latestInvoiceTotal:0}));
  assert.match(message.text,/カード登録が完了/);assert.match(message.text,/カード登録時の請求：0円/);
  assert.ok(message.text.includes('初回請求予定日：'+formatBillingNotificationDate(END)));
  assert.match(message.text,/初回請求予定額：550円/);assert.match(message.text,/1か月ごとに自動更新/);
});
test('immediate registration records paid550 and next charge',()=>{
  const message=renderBillingNotification(input('contract_registered'));
  assert.match(message.text,/550円を確認/);assert.ok(message.text.includes('次回請求予定日：'+formatBillingNotificationDate(END)));
  assert.doesNotMatch(message.text,/本日の請求：0円|21日|無料体験を開始/);
});
test('payment success reports exact period and next date without assuming another payment',()=>{
  const message=renderBillingNotification(input('payment_success'));
  assert.match(message.text,/お支払い金額：550円/);
  assert.ok(message.text.includes(formatBillingNotificationDate(START)));assert.ok(message.text.includes(formatBillingNotificationDate(END)));
});
test('cancelled renewal has no invented next invoice date',()=>{
  const message=renderBillingNotification(input('payment_success',{cancelAtPeriodEnd:true,nextChargeAtSeconds:null}));
  assert.match(message.text,/次回更新は行われません/);assert.doesNotMatch(message.text,/次回請求予定日/);
});
test('payment failure uses action guidance and never includes internal errors or asks for card data',()=>{
  const message=renderBillingNotification(input('payment_failed',failed()));
  assert.match(message.text,/お支払いを確認できませんでした/);assert.match(message.text,/返信で送らないでください/);
  assert.match(message.text,/契約管理画面/);assert.doesNotMatch(message.text,/resource_missing|card_declined|insufficient_funds/);
});
test('cancel reservation shows current usable end and next-update stop',()=>{
  const message=renderBillingNotification(input('cancel_reserved',{cancelAtPeriodEnd:true}));
  assert.ok(message.text.includes(formatBillingNotificationDate(END)));assert.match(message.text,/終了するまではHamCareプレミアムをご利用いただけます/);
  assert.match(message.text,/次回更新以降の請求は停止/);assert.match(message.text,/日割り返金は行いません/);
});
test('past_due cancellation does not falsely promise access while payment is unresolved',()=>{
  const message=renderBillingNotification(input('cancel_reserved',{...failed(),cancelAtPeriodEnd:true}));
  assert.match(message.text,/ご利用状況は、契約管理画面/);assert.doesNotMatch(message.text,/終了するまではHamCareプレミアムをご利用いただけます/);
});
test('resumed reflects monthly renewal and canceled reflects contract end',()=>{
  assert.match(renderBillingNotification(input('resumed')).text,/解約予約の取消/);
  const ended=renderBillingNotification(input('canceled',{status:'canceled',nextChargeAtSeconds:null,canceledAtSeconds:END}));
  assert.match(ended.text,/次回更新・請求はありません/);assert.doesNotMatch(ended.text,/契約終了日時/);
});
test('delayed notices describe event-time facts without treating cancellation request time as effective end',()=>{
  const ended=renderBillingNotification(input('canceled',{status:'canceled',nextChargeAtSeconds:null,canceledAtSeconds:START}));
  assert.ok(!ended.text.includes(formatBillingNotificationDate(START)));assert.match(ended.text,/変更を受け付けた時点の内容/);
  const trial=renderBillingNotification(input('contract_registered',{status:'trialing',trialEndSeconds:END,latestInvoicePaymentStatus:'no_payment_required',latestInvoiceAmountPaid:0,latestInvoiceTotal:0}));
  assert.doesNotMatch(trial.text,/本日の請求/);assert.match(trial.text,/カード登録時の請求：0円/);
});
for(const [type,extra]of cases)test(`${type} preserves explicit historical500 without announcing550`,()=>{
  const old={amount:500,legacyPrice:true,latestInvoiceAmountPaid:500,latestInvoiceTotal:500,...extra};
  const message=renderBillingNotification(input(type,old));assert.match(message.text,/月額500円/);assert.doesNotMatch(message.text,/550円/);
});
test('historical fully discounted active contract says actual0 without changing monthly price',()=>{
  const message=renderBillingNotification(input('contract_registered',{amount:500,legacyPrice:true,latestInvoiceAmountPaid:0,latestInvoiceTotal:0}));
  assert.match(message.text,/今回のお支払い：0円/);assert.match(message.text,/月額500円/);assert.doesNotMatch(message.text,/550円/);
});
const invalidSnapshots=[{amount:500},{amount:550,legacyPrice:true},{amount:551},{currency:'usd'},{interval:'year'},
  {status:'<img src=x onerror=alert(1)>'},{status:{}},{latestInvoicePaymentStatus:'other'},{latestInvoicePaymentStatus:{}},
  {latestInvoiceAmountPaid:-1},{latestInvoiceAmountPaid:551},{latestInvoiceTotal:551},{trialEndSeconds:0},{trialEndSeconds:'2030-02-01'},
  {currentPeriodEndSeconds:START},{currentPeriodStartSeconds:END+1},{nextChargeAtSeconds:NaN},{canceledAtSeconds:Infinity},
  {cancelAtPeriodEnd:'true'},{firebaseUid:'private-owner'},{stripeCustomerId:'cus_private'},{portalUrl:'https://billing.stripe.com/p/session/private'}];
for(const [i,extra]of invalidSnapshots.entries())test(`invalid snapshot${i} is rejected without exposing values`,()=>{
  assert.throws(()=>renderBillingNotification(input('payment_success',extra)),e=>e.code==='template_invalid'&&!e.message.includes('private'));
});
for(const extra of [{status:'trialing',trialEndSeconds:null,latestInvoiceAmountPaid:0,latestInvoiceTotal:0},
  {status:'trialing',trialEndSeconds:END,latestInvoiceAmountPaid:550,latestInvoiceTotal:550},{status:'active',latestInvoiceAmountPaid:0},
  {status:'active',latestInvoicePaymentStatus:'unpaid'}])test('registration inconsistent with canonical payment facts is blocked '+JSON.stringify(extra),()=>{
  assert.throws(()=>renderBillingNotification(input('contract_registered',extra)),/could not be rendered/);
});
for(const [type,extra]of [['payment_success',{latestInvoiceAmountPaid:0}],['payment_failed',{}],['cancel_reserved',{}],
  ['resumed',{cancelAtPeriodEnd:true}],['resumed',{nextChargeAtSeconds:null}],['canceled',{}]])test('semantic mismatch '+type+' rejects',()=>{
  assert.throws(()=>renderBillingNotification(input(type,extra)),/could not be rendered/);
});
test('arbitrary links, subject, free text, unknown version and environment are never accepted',()=>{
  for(const extra of [{managementUrl:'https://evil.example/'},{subject:'secret'},{message:'uid_private'},{templateVersion:'future'},{mode:'test'},{type:'unknown'}])
    assert.throws(()=>renderBillingNotification({...input('payment_success'),...extra}));
  assert.throws(()=>validateBillingNotificationSnapshot({...fixture(),extra:'private'}));
});
test('JST conversion is deterministic at midnight boundaries',()=>{
  assert.match(formatBillingNotificationDate(Date.UTC(2030,0,1,15,0)/1000),/2030年1月2日 00:00（日本時間）/);
  for(const v of [NaN,Infinity,0,-1,'2030-01-01'])assert.throws(()=>formatBillingNotificationDate(v));
});
test('rendering never mutates a source snapshot',()=>{
  const source=Object.freeze(fixture()),before=JSON.stringify(source);
  renderBillingNotification({type:'payment_success',mode:'live',snapshot:source,templateVersion:BILLING_NOTIFICATION_TEMPLATE_VERSION});
  assert.equal(JSON.stringify(source),before);
});
