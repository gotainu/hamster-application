import test from 'node:test';
import assert from 'node:assert/strict';
import { projectCheckoutReview, projectCheckoutSession, projectCheckoutStatus, projectPreviewBilling, checkoutErrorMessage } from '../public/assets/checkout-model.mjs';

const quote = () => ({
  testMode: true, planKey: 'premium_monthly', amount: 550, currency: 'jpy', interval: 'month', reviewToken: 'opaque_fixture_review_token_12345',
  account: { nickname: '  テスト  ', maskedEmail: 'te***@example.test' },
  billing: { kind: 'immediate', cardRegistrationAt: '2026-11-14T09:20:00.000Z', firstChargeAt: '2026-11-14T09:20:00.000Z', firstChargeAmount: 550, trialEndsAt: null },
});
const trial = () => ({ ...quote(), billing: { kind: 'trial', cardRegistrationAt: '2026-11-14T09:20:00.000Z', firstChargeAt: '2026-11-30T01:00:00.000Z', firstChargeAmount: 550, trialEndsAt: '2026-11-30T01:00:00.000Z' } });
const rejects = fn => assert.throws(fn, error => error.code === 'preview/invalid-response');

test('verified immediate quote displays the fixed tax-inclusive total and immediate charge', () => {
  const model = projectCheckoutReview(quote());
  assert.equal(model.nickname, 'テスト'); assert.equal(model.maskedEmail, 'te***@example.test');
  assert.equal(model.amountLabel, '月額550円（税込）／税抜500円'); assert.equal(model.firstChargeLabel, '申込時（即時）');
  assert.match(model.trialNote, /新たな21日体験が始まることはありません/);
});
test('trial quote displays the original server end date and never starts another trial', () => {
  const model = projectCheckoutReview(trial());
  assert.match(model.firstChargeLabel, /2026年11月30日/); assert.match(model.firstChargeLabel, /10:00/);
  assert.match(model.trialNote, /それまでは請求されません/); assert.match(model.trialNote, /延長・リセット/);
});
test('price mismatch 500 or 605, live mode, foreign currency and other plans fail closed', () => {
  for (const patch of [{ amount: 500 }, { amount: 605 }, { testMode: false }, { currency: 'usd' }, { planKey: 'yearly' }, { interval: 'year' }]) rejects(() => projectCheckoutReview({ ...quote(), ...patch }));
});
test('trial first charge must exactly match the original end without an excessive or past interval', () => {
  for (const patch of [{ firstChargeAt: '2026-11-29T01:00:00Z' }, { trialEndsAt: '2027-11-30T01:00:00Z', firstChargeAt: '2027-11-30T01:00:00Z' }, { trialEndsAt: '2026-11-13T01:00:00Z', firstChargeAt: '2026-11-13T01:00:00Z' }, { firstChargeAmount: 500 }, { firstChargeAt: 'invalid' }]) rejects(() => projectCheckoutReview({ ...trial(), billing: { ...trial().billing, ...patch } }));
});
test('a missing, malformed or timezone-less server billing date cannot enable checkout', () => {
  for (const value of [null, '', '2026-11-14', '2026-11-14T09:20:00', 'not-a-date']) rejects(() => projectCheckoutReview({ ...quote(), billing: { ...quote().billing, cardRegistrationAt: value } }));
  rejects(() => projectCheckoutReview({ ...quote(), billing: undefined }));
});
test('immediate billing cannot silently retain a conflicting trial end', () => {
  rejects(() => projectCheckoutReview({ ...quote(), billing: { ...quote().billing, trialEndsAt: '2026-11-30T01:00:00Z' } }));
});
test('review token must be opaque and full account emails are never accepted for display', () => {
  for (const token of ['', 'short', 'https://example.test/?uid=hidden']) rejects(() => projectCheckoutReview({ ...quote(), reviewToken: token }));
  rejects(() => projectCheckoutReview({ ...quote(), account: { nickname: 'Test', maskedEmail: 'private@example.test' } }));
});
test('projection excludes unknown identifiers and retains only safe display fields', () => {
  const raw = { ...quote(), uid: 'private_uid_fixture', customerId: 'cus_private_fixture', idToken: 'private_token_fixture' };
  const safe = JSON.stringify(projectCheckoutReview(raw));
  assert.doesNotMatch(safe, /private_uid_fixture|cus_private_fixture|private_token_fixture/);
  assert.equal(projectCheckoutReview({ ...quote(), account: { nickname: ' ', maskedEmail: 'te***@example.test' } }).nickname, '未設定');
});
test('Stripe session accepts test publishable key and test client secret only', () => {
  const session = { testMode: true, publishableKey: 'pk_test_fixtureKey0000', clientSecret: 'cs_test_fixture_secret_fakeValueOnly', sessionId: 'private_session_fixture' };
  assert.deepEqual(Object.keys(projectCheckoutSession(session)), ['publishableKey', 'clientSecret']);
  for (const patch of [{ testMode: false }, { publishableKey: 'pk_live_fixtureKey0000' }, { clientSecret: 'cs_live_fixture_secret_fakeValueOnly' }, { clientSecret: 'https://example.test/' }]) rejects(() => projectCheckoutSession({ ...session, ...patch }));
});
test('completion requires confirmed paid or trial no-payment-required without granting app access', () => {
  for (const paymentStatus of ['paid', 'no_payment_required']) {
    const result = projectCheckoutStatus({ testMode: true, state: 'complete', paymentStatus });
    assert.equal(result.state, 'complete'); assert.equal(result.terminal, true);
    assert.match(result.copy, /利用権限には反映されません/); assert.match(result.copy, /Webhook/);
  }
});
test('complete but unpaid remains processing rather than a successful payment', () => {
  const result = projectCheckoutStatus({ testMode: true, state: 'complete', paymentStatus: 'unpaid' });
  assert.equal(result.state, 'processing'); assert.equal(result.terminal, false); assert.match(result.copy, /まだ確定していません/);
});
test('open, canceled, expired, refused and authentication-failed stay distinct', () => {
  for (const state of ['open', 'canceled', 'expired', 'payment_failed', 'authentication_failed']) assert.equal(projectCheckoutStatus({ testMode: true, state }).state, state);
  rejects(() => projectCheckoutStatus({ testMode: false, state: 'complete', paymentStatus: 'paid' }));
  rejects(() => projectCheckoutStatus({ testMode: true, state: 'unknown' }));
});
test('Japanese errors never echo backend, authentication or Stripe payloads', () => {
  const payload = { code: 'preview/unexpected', message: 'private@example.test private_uid_fixture cs_test_private_fixture' };
  assert.doesNotMatch(checkoutErrorMessage(payload), /private|cs_test/);
  assert.match(checkoutErrorMessage({ code: 'preview/network-error' }), /通信に失敗/);
  assert.match(checkoutErrorMessage({ code: 'preview/trial-unavailable' }), /体験状態を確認できません/);
  assert.match(checkoutErrorMessage({ code: 'preview/review-expired' }), /有効期限/);
  assert.match(checkoutErrorMessage({ code: 'preview/already-subscribed' }), /新しい申込は行いません/);
});

test('trial quote permits sub-second rounding only at the existing 21-day boundary', () => {
  const base=trial(); const start=Date.parse(base.billing.cardRegistrationAt);
  for(const extra of [0,999]){
    const end=new Date(start+21*86400000+extra).toISOString();
    assert.match(projectCheckoutReview({...base,billing:{...base.billing,firstChargeAt:end,trialEndsAt:end}}).firstChargeLabel,/日本時間/);
  }
  const end=new Date(start+21*86400000+1000).toISOString();
  rejects(()=>projectCheckoutReview({...base,billing:{...base.billing,firstChargeAt:end,trialEndsAt:end}}));
});
test('none and processing responses never become completed payments', () => {
  const none=projectCheckoutStatus({testMode:true,state:'none'}); assert.equal(none.state,'none'); assert.equal(none.terminal,true); assert.match(none.title,/作成されていません/);
  const pending=projectCheckoutStatus({testMode:true,state:'processing'}); assert.equal(pending.state,'processing'); assert.equal(pending.terminal,false); assert.match(pending.copy,/まだ確定していません/); assert.match(pending.copy,/利用権限には反映されません/);
});
test('backend policy failures have safe and actionable Japanese messages', () => {
  const expected={existing_subscription:/新しい申込は行いません/,trial_unresolved:/体験状態を確認できません/,trial_too_short:/体験終了後/,processing:/前の申込処理/,preview_limit:/利用上限/,plan_not_allowed:/安全に確認できません/,billing_unresolved:/契約状態を確認できません/,test_webhook_unresolved:/以前のテスト決済/,price_mismatch:/表示料金/,test_configuration_invalid:/テスト用の支払い設定/};
  for(const [code,pattern] of Object.entries(expected)){
    const message=checkoutErrorMessage({code,message:'private@example.test uid_fixture cs_test_private'});
    assert.match(message,pattern);assert.doesNotMatch(message,/private|uid_fixture|cs_test/);
  }
});

test('Stripe test client secret remains opaque, including percent-encoded ASCII characters', () => {
  const publishableKey='pk_test_fixtureKey0000';
  const encoded='cs_test_fixture_secret_encoded%2Fopaque%3Dvalue%25+_safe-characters';
  assert.equal(projectCheckoutSession({testMode:true,publishableKey,clientSecret:encoded}).clientSecret,encoded);
  for(const clientSecret of [encoded+'\n',encoded+' ',encoded+'\t',encoded+'\u0000',encoded+'\u007f',encoded+'\u00a0','cs_test_fixture_secret_'+ 'a'.repeat(2048),'cs_live_fixture_secret_encoded%2Fopaque','https://example.test/opaque%2Fvalue']){
    rejects(()=>projectCheckoutSession({testMode:true,publishableKey,clientSecret}));
  }
  rejects(()=>projectCheckoutSession({testMode:true,publishableKey:'pk_live_fixtureKey0000',clientSecret:encoded}));
});

const mirrored = (status = 'active') => ({testMode:true,syncState:'synced',billing:{planKey:'premium_monthly',amount:550,currency:'jpy',interval:'month',status,currentPeriodStart:'2026-11-14T09:20:00Z',currentPeriodEnd:'2026-12-14T09:20:00Z',firstChargeAt:'2026-11-14T09:20:00Z',nextChargeAt:'2026-12-14T09:20:00Z',trialEnd:null,cancelAtPeriodEnd:false,syncedAt:'2026-11-14T09:20:02Z',entitlementMirror:status==='active'}});
test('Webhook mirror maps all subscription states to Japanese without exposing raw status', () => {
  const expected={trialing:'体験期間中・契約登録済み',active:'有料会員',past_due:'お支払いの確認が必要です',unpaid:'お支払いを確認できませんでした',paused:'契約は一時停止中です',incomplete:'お申し込みは未完了です',incomplete_expired:'お申し込みの有効期限が切れました',canceled:'解約済み'};
  for(const [status,label] of Object.entries(expected)){
    const model=projectPreviewBilling(mirrored(status));assert.equal(model.statusLabel,label);assert.equal(model.amountLabel,'月額550円（税込）／1か月ごとの自動更新');assert.match(model.syncedAtLabel,/日本時間/);
    assert.match(model.copy,/本番利用権限には反映されません/);
  }
});
test('pending, missing and unavailable mirrors are never promoted to paid membership', () => {
  for(const syncState of ['pending','none','unavailable']){
    const model=projectPreviewBilling({...mirrored(),syncState});assert.notEqual(model.outcome,'active');assert.equal(model.planLabel,'未確認');assert.equal(model.entitlementLabel,'未確認');
  }
  const unknown=projectPreviewBilling(mirrored('future-internal-status'));assert.equal(unknown.statusLabel,'契約状態を確認できません');assert.doesNotMatch(JSON.stringify(unknown),/future-internal-status/);
});
test('mirror authority stays server-provided and never becomes a browser expiry rule', () => {
  const raw=mirrored();raw.billing.currentPeriodEnd='2000-01-01T00:00:00Z';raw.billing.entitlementMirror=true;
  assert.match(projectPreviewBilling(raw).entitlementLabel,/有効として保存/);
  raw.billing.entitlementMirror=false;assert.match(projectPreviewBilling(raw).entitlementLabel,/無効として保存/);assert.equal(projectPreviewBilling(raw).outcome,'stored');
});
test('mirror rejects Live, foreign plans, wrong total and missing verified sync timestamp', () => {
  rejects(()=>projectPreviewBilling({...mirrored(),testMode:false}));
  for(const patch of [{planKey:'other'},{amount:500},{currency:'usd'},{interval:'year'},{syncedAt:null},{entitlementMirror:'true'},{cancelAtPeriodEnd:'false'}])rejects(()=>projectPreviewBilling({...mirrored(),billing:{...mirrored().billing,...patch}}));
});
test('mirror projection excludes identifiers and displays server dates without fabricating next charge', () => {
  const raw=mirrored();Object.assign(raw.billing,{uid:'private_uid_fixture',stripeCustomerId:'cus_private_fixture',subscriptionId:'sub_private_fixture',nextChargeAt:null,cancelAtPeriodEnd:true});
  const model=projectPreviewBilling(raw);assert.equal(model.cancelLabel,'期間末に解約予定');assert.equal(model.nextChargeLabel,'予定を確認できません');assert.doesNotMatch(JSON.stringify(model),/private_uid_fixture|cus_private_fixture|sub_private_fixture/);assert.match(model.managementNotice,/次の開発タスク/);
});
test('trialing sync confirms the original first-charge date and labels isolated test fixtures', () => {
  const raw=mirrored('trialing');Object.assign(raw.billing,{trialEnd:'2026-11-30T01:00:00Z',firstChargeAt:'2026-11-30T01:00:00Z',entitlementMirror:true,testDataSource:'preview_fixture'});
  const model=projectPreviewBilling(raw);assert.equal(model.outcome,'trialing');assert.match(model.title,/カード登録が完了/);assert.match(model.copy,/Preview専用のテストデータ/);assert.match(model.copy,/本番の体験状態は変更しません/);
  assert.match(projectCheckoutReview({...trial(),testDataSource:'preview_fixture'}).trialNote,/Preview専用の体験データ/);
  raw.billing.firstChargeAt='2026-11-29T01:00:00Z';rejects(()=>projectPreviewBilling(raw));
});
