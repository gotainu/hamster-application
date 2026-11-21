'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const {resolveBillingNotificationRecipient:resolve}=loadStarSource()('billingNotificationRecipient');
const UID='synthetic-mail-owner',NOW=Date.UTC(2030,0,1);
const user=extra=>({uid:UID,disabled:false,emailVerified:true,email:'owner@example.test',providerData:[],...extra});
const state=(mode='live',extra={})=>({purpose:mode==='live'?'billing_contact_live':'billing_contact_preview',schemaVersion:1,
  ...(mode==='live'?{firebaseUid:UID}:{}),verified:true,verificationStatus:'verified',source:'user_supplied',verifiedAt:NOW-1000,email:'supplement@example.test',...extra});
const context=extra=>({uid:UID,authUser:user(),mode:'live',nowMillis:NOW,...extra});
const supplemental=(mode='live',extra={})=>({uid:UID,state:state(mode,extra)});
const blocked={kind:'blocked_no_verified_contact'};
test('normal verified Auth email has priority over supplemental contact',()=>{
  assert.deepEqual(resolve(context({supplementalContact:supplemental()})),{kind:'resolved',email:'owner@example.test',source:'auth_verified'});
});
for(const domain of ['privaterelay.appleid.com','private.icloud.com'])test('verified '+domain+' with authoritative Apple provider is a valid contact',()=>{
  const email='relay@'+domain;
  assert.deepEqual(resolve(context({authUser:user({email,providerData:[{providerId:'apple.com',uid:'synthetic-apple-subject',email}]})})),{kind:'resolved',email,source:'apple_relay'});
});
test('verified Relay accepts absent provider email but never requires a personal email',()=>{
  const email='relay@privaterelay.appleid.com';
  assert.deepEqual(resolve(context({authUser:user({email,providerData:[{providerId:'apple.com',uid:'subject'}]})})),{kind:'resolved',email,source:'apple_relay'});
});
for(const providerData of [[],[{providerId:'google.com',uid:'subject'}],[{providerId:'apple.com',uid:''}],
  [{providerId:'apple.com',uid:'subject',email:'other@example.test'}],[{providerId:'apple.com',uid:'one'},{providerId:'apple.com',uid:'two'}],null])test('Relay text alone is not identity proof '+JSON.stringify(providerData),()=>{
  assert.deepEqual(resolve(context({authUser:user({email:'relay@privaterelay.appleid.com',providerData})})),blocked);
});
for(const mode of ['live','preview'])for(const authExtra of [{email:undefined,emailVerified:false},{email:'unverified@example.test',emailVerified:false},
  {email:'not-an-email',emailVerified:true}])test(mode+' verified supplemental contact is usable after unusable Auth contact '+JSON.stringify(authExtra),()=>{
  assert.deepEqual(resolve(context({mode,authUser:user(authExtra),supplementalContact:supplemental(mode)})),{kind:'resolved',email:'supplement@example.test',source:'user_supplied'});
});
test('supplemental Relay verified by challenge is valid without fabricating Firebase email',()=>{
  assert.deepEqual(resolve(context({authUser:user({email:undefined,emailVerified:false}),supplementalContact:supplemental('live',{email:'relay@private.icloud.com'})})),
    {kind:'resolved',email:'relay@private.icloud.com',source:'user_supplied'});
});
for(const extra of [{email:undefined,emailVerified:false},{email:'unverified@example.test',emailVerified:false},{email:'invalid'},{email:'   '}])test('absent or unverified contact is blocked '+JSON.stringify(extra),()=>{
  assert.deepEqual(resolve(context({authUser:user(extra)})),blocked);
});
for(const extra of [{purpose:'billing_contact_preview'},{firebaseUid:'other-owner'},{verified:false},{verificationStatus:'pending'},
  {source:'client_asserted'},{verifiedAt:NOW+1},{verifiedAt:0},{verifiedAt:'2030-01-01'},{schemaVersion:2},{email:'a\r\nBcc:private@example.test'},
  {email:'not-an-email'}])test('unsafe live supplemental state blocked '+JSON.stringify(extra),()=>{
  assert.deepEqual(resolve(context({authUser:user({email:undefined,emailVerified:false}),supplementalContact:supplemental('live',extra)})),blocked);
});
test('live contact requires explicit UID in both path binding and state',()=>{
  const missing=state();delete missing.firebaseUid;
  for(const ref of [{uid:'another',state:state()},{uid:UID,state:missing}])
    assert.deepEqual(resolve(context({authUser:user({email:undefined,emailVerified:false}),supplementalContact:ref})),blocked);
});
test('Preview cannot read a Live contact and rejects explicit mismatching state UID',()=>{
  for(const s of [state('live'),state('preview',{firebaseUid:'another'})])
    assert.deepEqual(resolve(context({mode:'preview',authUser:user({email:undefined,emailVerified:false}),supplementalContact:{uid:UID,state:s}})),blocked);
});
for(const authUser of [user({uid:'other'}),user({disabled:true}),user({disabled:undefined}),user({emailVerified:'true'}),null])test('invalid Admin account blocks even an independently verified contact '+JSON.stringify(authUser),()=>{
  assert.deepEqual(resolve(context({authUser,supplementalContact:supplemental()})),blocked);
});
for(const extra of [{uid:''},{uid:'another/path'},{mode:'test'},{nowMillis:0},{nowMillis:Infinity},{nowMillis:'now'}])test('invalid resolution context blocked '+JSON.stringify(extra),()=>{
  assert.deepEqual(resolve(context(extra)),blocked);
});
test('normalization preserves local part and lowercases domain without finding accounts by email',()=>{
  assert.deepEqual(resolve(context({authUser:user({email:' Owner@EXAMPLE.TEST '})})),{kind:'resolved',email:'Owner@example.test',source:'auth_verified'});
});
test('resolution is read-only and contains no UID or Stripe identifier in result',()=>{
  const input=context({supplementalContact:supplemental()}),before=JSON.stringify(input),result=resolve(input);
  assert.equal(JSON.stringify(input),before);assert.deepEqual(Object.keys(result).sort(),['email','kind','source']);
});
