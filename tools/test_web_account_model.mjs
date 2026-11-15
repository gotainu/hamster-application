#!/usr/bin/env node
// Task7-only display projections; no SDK, login, identifiers, or account writes.
import test from 'node:test';
import assert from 'node:assert/strict';
import {loginMethods,safeAuthError,summarizeAccount} from '../public/assets/account-model.mjs';
const user={uid:'synthetic-private-apple-uid',email:'synthetic-private@privaterelay.appleid.com',providerData:[{providerId:'apple.com',uid:'synthetic-private-apple-sub'}]};
const docs=pet=>({owner:{kind:'missing'},billing:{kind:'missing'},trial:{kind:'missing'},pet});
test('Apple provider label identifies the actual method without claiming a capability or exposing subject',()=>{
  assert.deepEqual(loginMethods(user.providerData),['Apple']);
  assert.doesNotMatch(loginMethods(user.providerData).join(' '),/準備中|apple\.com|synthetic-private/);
});
test('mixed provider list remains deduplicated and does not imply application linking',()=>{
  assert.deepEqual(loginMethods([{providerId:'apple.com'},{providerId:'google.com'},{providerId:'apple.com'},{providerId:'password'}]),['Apple','Google','メールアドレス／パスワード']);
});
for(const malformed of [null,{},'apple.com'])test('malformed provider display list is safe '+JSON.stringify(malformed),()=>{
  assert.deepEqual(loginMethods(malformed),['確認できません']);
});
for(const code of ['auth/popup-closed-by-user','auth/cancelled-popup-request'])test('cancellation is provider-neutral for '+code,()=>{
  const message=safeAuthError({code});assert.match(message,/中止/);assert.doesNotMatch(message,/Google|Apple|auth\//);
});
for(const [code,expected] of [['account/apple-setup-required',/設定確認中/],['account/apple-identity-invalid',/確認できません/],
  ['account/signin-in-progress',/処理中/],['account/app-account-required',/アカウントとペット情報/],['account/app-account-unavailable',/登録状態を確認できません/]])test('safe Task7 error '+code,()=>{
  const message=safeAuthError({code,message:'synthetic-private token',customData:{email:user.email,uid:user.uid}});
  assert.match(message,expected);assert.doesNotMatch(message,/synthetic-private|token|privaterelay|account\//);
});
for(const code of ['auth/account-exists-with-different-credential','auth/credential-already-in-use'])test('provider collision '+code+' directs the original app method rather than merging',()=>{
  assert.match(safeAuthError({code}),/アプリ.*ログイン方法/);assert.match(safeAuthError({code}),/独自のアカウント統合は行いません/);
});
for(const [name,pet,expected] of [['found',{kind:'found'},true],['missing',{kind:'missing'},false],['denied',{kind:'denied'},null],
  ['unavailable',{kind:'unavailable'},null],['absent',undefined,null],['malformed',{kind:'other'},null]])test('app existence '+name+' controls plan-selection hint without granting entitlement',()=>{
  const summary=summarizeAccount(user,docs(pet));assert.equal(summary.appAccountExists,expected);assert.equal(summary.planReview.canSelectPlan,expected===true);
  assert.deepEqual(summary.methods,['Apple']);assert.equal(summary.unavailableFields.length,0);
  assert.doesNotMatch(JSON.stringify(summary),/synthetic-private|apple-sub|apple-uid/);
  for(const key of ['uid','providerUid','isPaid','hasAccess','entitlement'])assert.equal(key in summary,false);
});
test('existing paid app billing still uses management route even when app profile exists',()=>{
  const data=docs({kind:'found'});data.billing={kind:'found',data:{plan:'paid',status:'active'}};
  const summary=summarizeAccount(user,data);assert.equal(summary.planReview.route,'manage');assert.equal(summary.planReview.canSelectPlan,false);
});

for(const [code,pattern] of [['account/apple-consent-required',/関連付け.*同意/],['account/apple-redirect-unavailable',/安全に戻れません/],
  ['auth/operation-not-allowed',/ログイン設定/],['auth/invalid-oauth-client-id',/ログイン設定/],
  ['auth/unauthorized-domain',/ログイン設定/],['auth/missing-or-invalid-nonce',/ログイン情報/],['auth/invalid-auth-event',/ログイン情報/]])test('Apple setup/consent/return failure remains safe Japanese '+code,()=>{
  const message=safeAuthError({code,message:'private-token synthetic-subject',customData:{email:user.email,uid:user.uid}});
  assert.match(message,pattern);assert.doesNotMatch(message,/private-token|synthetic|appleid|auth\/|account\//);
});
