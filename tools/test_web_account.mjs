#!/usr/bin/env node
// Pure presentation tests. No network, Firebase initialization, or production data.
import assert from 'node:assert/strict';
import test from 'node:test';
import {maskEmail, loginMethods, safeAuthError, summarizeAccount} from '../public/assets/account-model.mjs';
import {createAccountService} from '../public/assets/account-service.mjs';

const PROJECT='demo-hamcare-preview-sync';
const sdkTokenResult = user => {
  const provider=user.providerData?.[0]?.providerId || 'password';
  return {signInProvider:provider,claims:{aud:PROJECT,iss:'https://securetoken.google.com/'+PROJECT,sub:user.uid,user_id:user.uid,email_verified:user.emailVerified===true,firebase:{sign_in_provider:provider,identities:{}}}};
};

const missing = () => ({kind: 'missing'});
const found = data => ({kind: 'found', data});
const docs = overrides => ({owner: missing(), billing: missing(), trial: missing(), ...overrides});
const person = {
  uid: 'synthetic-subject-a',
  email: 'go@example.test',
  displayName: 'Auth name must not replace owner profile',
  providerData: [{providerId: 'password'}],
};
const flatten = value => Array.isArray(value) ? value.join(' ') : String(value);
const noPrivateFields = summary => {
  const serialized = JSON.stringify(summary);
  for (const privateValue of ['synthetic-subject-a', 'cus_private_fixture', 'sub_private_fixture', 'synthetic_token', 'go@example.test']) {
    assert.ok(!serialized.includes(privateValue), `must not expose ${privateValue.split('_')[0]} field`);
  }
};

test('email masking never returns a complete address', () => {
  assert.equal(maskEmail('go@example.com'), 'go***@example.com');
  assert.equal(maskEmail('g@example.com'), 'g***@example.com');
  for (const address of ['long.name@example.test', 'ハムスター@example.test']) {
    const masked = maskEmail(address);
    assert.notEqual(masked, address);
    assert.match(masked, /\*+/);
    assert.match(masked, /@example\.test$/);
  }
});

test('missing or malformed email gets a safe display label', () => {
  for (const value of [undefined, null, '', 'not-an-email', '<script>', '@example.test']) {
    assert.match(maskEmail(value), /未設定|確認できません/);
  }
});

test('provider labels are an allowlisted presentation without provider identifiers', () => {
  const labels = loginMethods([{providerId: 'password'}, {providerId: 'google.com'}, {providerId: 'password'}]);
  assert.ok(Array.isArray(labels));
  assert.match(flatten(labels), /メール|パスワード/);
  assert.match(flatten(labels), /Google/);
  assert.equal(labels.length, new Set(labels).size);
  assert.doesNotMatch(flatten(labels), /google\.com|providerId/);
  assert.doesNotMatch(flatten(loginMethods([{providerId: '<script>private-provider</script>'}])), /<script>|private-provider/);
});

test('invalid credential, wrong password, and nonexistent user do not reveal account existence', () => {
  const messages = ['auth/invalid-credential', 'auth/wrong-password', 'auth/user-not-found'].map(code => safeAuthError({code}));
  assert.equal(new Set(messages).size, 1);
  assert.match(messages[0], /メール|パスワード/);
});

test('provider conflict guides the user to the app login method', () => {
  assert.match(safeAuthError({code: 'auth/account-exists-with-different-credential'}), /アプリ.*ログイン方法|ログイン方法.*アプリ/);
});

test('popup cancellation, blocked popup, network failure, and throttling are Japanese', () => {
  for (const code of ['auth/popup-closed-by-user', 'auth/popup-blocked', 'auth/cancelled-popup-request', 'auth/network-request-failed', 'auth/too-many-requests']) {
    const message = safeAuthError({code});
    assert.match(message, /[ぁ-んァ-ヶ一-龠]/);
    assert.doesNotMatch(message, /auth\/|Firebase|Error:/);
  }
  assert.match(safeAuthError({code: 'auth/network-request-failed'}), /通信/);
});

test('internal errors and arbitrary error payloads never appear in user messages', () => {
  const message = safeAuthError({code: 'arbitrary-internal-error', message: 'go@example.test synthetic_token', customData: {uid: person.uid}});
  assert.match(message, /[ぁ-んァ-ヶ一-龠]/);
  assert.doesNotMatch(message, /go@example|synthetic|arbitrary|uid|customData/);
  assert.equal(typeof safeAuthError(null), 'string');
});

test('nickname authority is owner profile, not Firebase Auth displayName', () => {
  const absent = summarizeAccount(person, docs());
  assert.equal(absent.nickname, '未設定');
  const present = summarizeAccount(person, docs({owner: found({displayName: '  うちの飼い主  '})}));
  assert.equal(present.nickname, 'うちの飼い主');
  assert.equal(present.maskedEmail, 'go***@example.test');
  noPrivateFields(present);
});

test('empty nickname remains unset and raw markup remains text for the DOM renderer', () => {
  assert.equal(summarizeAccount(person, docs({owner: found({displayName: '   '})})).nickname, '未設定');
  const nickname = '<img src=x onerror=alert(1)>';
  // The view must insert this with textContent, never innerHTML. The model does
  // not transform a legitimate user's display name into executable markup.
  assert.equal(summarizeAccount(person, docs({owner: found({displayName: nickname})})).nickname, nickname);
});

test('missing documents are distinct from unreadable documents', () => {
  const absent = summarizeAccount(person, docs());
  assert.ok(Array.isArray(absent.unavailableFields));
  assert.equal(absent.unavailableFields.length, 0);
  const denied = summarizeAccount(person, docs({
    owner: {kind: 'denied'}, billing: {kind: 'denied'}, trial: {kind: 'unavailable'},
  }));
  assert.equal(denied.unavailableFields.length, 3);
  assert.match(denied.billingLabel, /確認|取得/);
  assert.match(denied.trialLabel, /確認|取得/);
  assert.notEqual(denied.billingLabel, absent.billingLabel);
  assert.notEqual(denied.trialLabel, absent.trialLabel);
  noPrivateFields(denied);
});

test('summary excludes raw UID, customer, subscription, token, and full email', () => {
  const summary = summarizeAccount(person, docs({
    owner: found({displayName: 'テスト飼い主', uid: person.uid, email: person.email}),
    billing: found({status: 'active', plan: 'paid', customerId: 'cus_private_fixture', subscriptionId: 'sub_private_fixture', idToken: 'synthetic_token'}),
    trial: found({status: 'active', endsAt: new Date('2030-01-01T00:00:00Z')}),
  }));
  noPrivateFields(summary);
  for (const forbiddenKey of ['uid', 'customerId', 'subscriptionId', 'idToken', 'isPaid', 'isActive', 'canPurchase', 'hasAccess']) {
    assert.ok(!(forbiddenKey in summary), `no entitlement or private ${forbiddenKey}`);
  }
});

test('saved billing statuses display safely without opening or granting a plan', () => {
  for (const status of ['active', 'trialing', 'past_due', 'canceled', 'unpaid', 'incomplete', 'unknown-future-status']) {
    const summary = summarizeAccount(person, docs({billing: found({plan: 'paid', status})}));
    assert.equal(typeof summary.billingLabel, 'string');
    assert.ok(summary.billingLabel.length > 0);
    assert.doesNotMatch(summary.billingLabel, /unknown-future-status|undefined|null/);
    noPrivateFields(summary);
  }
});

test('AI counters do not become a second Web entitlement evaluator', () => {
  const base = {status: 'active', endsAt: new Date('2030-01-01T00:00:00Z')};
  const unused = summarizeAccount(person, docs({trial: found({...base, aiRequestUsed: 0, aiRequestLimit: 20})}));
  const used = summarizeAccount(person, docs({trial: found({...base, aiRequestUsed: 20, aiRequestLimit: 20})}));
  assert.equal(unused.trialLabel.split('／AI相談')[0], used.trialLabel.split('／AI相談')[0]);
  assert.match(unused.trialLabel, /0回/);
  assert.match(used.trialLabel, /20回/);
  assert.ok(!('hasAccess' in used));
});

test('malformed and missing timestamps never crash or fabricate an access verdict', () => {
  for (const value of [null, undefined, 'not-a-date', {}, {seconds: NaN}, new Date(NaN)]) {
    const summary = summarizeAccount(person, docs({billing: found({status: 'active', currentPeriodEnd: value}), trial: found({status: 'active', endsAt: value})}));
    assert.doesNotMatch(summary.billingLabel + summary.trialLabel, /Invalid Date|NaN|undefined/);
    assert.ok(!('isActive' in summary));
  }
});


test('past and future end dates remain stored facts, never a new Web access decision', () => {
  const past = new Date('2000-01-01T00:00:00Z');
  const future = new Date('2100-01-01T00:00:00Z');
  const withEnd = end => summarizeAccount(person, docs({billing: found({plan: 'paid', status: 'active', currentPeriodEnd: end}), trial: found({status: 'active', endsAt: end})}));
  const a = withEnd(past), b = withEnd(future);
  assert.equal(a.billingLabel.split('／契約期間末')[0], b.billingLabel.split('／契約期間末')[0]);
  assert.equal(a.trialLabel.split('／体験終了日時')[0], b.trialLabel.split('／体験終了日時')[0]);
  assert.notEqual(a.billingLabel, b.billingLabel);
  assert.notEqual(a.trialLabel, b.trialLabel);
  assert.match(a.billingLabel + a.trialLabel, /保存/);
});


function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return {promise, resolve, reject};
}
function fakeService(overrides = {}) {
  let notify = () => {};
  const calls = [];
  const user = {uid: 'synthetic-subject-a', email: 'go@example.test', emailVerified: true, providerData: [{providerId: 'password'}]};
  const auth = {app:{options:{projectId:PROJECT}},currentUser: user, authStateReady: async () => { calls.push('auth-ready'); }};
  const sdk = {
    browserSessionPersistence: Symbol('Firebase session persistence'),
    onAuthStateChanged: (_auth, callback) => { notify = callback; return () => {}; },
    setPersistence: async (target, persistence) => { assert.equal(target, auth); assert.equal(persistence, sdk.browserSessionPersistence); calls.push('session-persistence'); },
    getIdTokenResult: async (target,forceRefresh) => { assert.equal(forceRefresh,true);return sdkTokenResult(target); },
    doc: (_db, ...parts) => parts.join('/'),
    getDoc: async resource => { calls.push(resource); return {exists: () => true, data: () => resource.includes('owner_profiles') ? {displayName: 'Owner A'} : {status: 'active'}}; },
    signOut: async () => { auth.currentUser = null; notify(null); },
    GoogleAuthProvider: class { setCustomParameters(value) { assert.deepEqual(value, {prompt: 'select_account'}); } },
    getAdditionalUserInfo: result => ({isNewUser: result.isNewUser}),
    ...overrides,
  };
  const service = createAccountService({auth, db: Object.freeze({kind: 'opaque-db'}), sdk});
  return {service, auth, sdk, calls, notify: () => notify(auth.currentUser)};
}

test('service chooses Firebase session persistence once before Auth readiness', async () => {
  const {service, calls} = fakeService();
  const first = service.ready();
  await Promise.all([first, service.ready()]);
  assert.deepEqual(calls, ['session-persistence', 'auth-ready']);
});

test('service reads only the four fixed documents belonging to the signed-in UID', async () => {
  const {service, calls} = fakeService();
  const summary = await service.readAccountSummary();
  assert.deepEqual(calls.sort(), [
    'users/synthetic-subject-a/billing/subscription',
    'users/synthetic-subject-a/feature_access/initial_trial_v2',
    'users/synthetic-subject-a/owner_profiles/main',
    'users/synthetic-subject-a/pet_profiles/main_pet',
  ]);
  assert.equal(summary.nickname, 'Owner A');
  noPrivateFields(summary);
});

test('service refuses account reads for an unverified or signed-out identity', async () => {
  const {service, auth, calls} = fakeService();
  auth.currentUser.emailVerified = false;
  await assert.rejects(service.readAccountSummary(), error => error.code === 'account/identity-unverified');
  auth.currentUser = null;
  await assert.rejects(service.readAccountSummary(), error => error.code === 'account/session-changed');
  assert.deepEqual(calls, []);
});

test('delayed owner A results are refused after identity switch or logout', async () => {
  for (const action of ['switch', 'logout']) {
    const gate = deferred();
    const {service, auth, notify} = fakeService({getDoc: () => gate.promise});
    const visible = [];
    service.onAuthChanged(value => visible.push(value));
    const pending = service.readAccountSummary();
    await new Promise(resolve => setImmediate(resolve)); // Keep the delayed-document regression beyond the fresh-token boundary.
    if (action === 'switch') { auth.currentUser = {...auth.currentUser, uid: 'synthetic-subject-b'}; notify(); }
    else { await service.signOut(); assert.equal(visible.at(-1), null); }
    gate.resolve({exists: () => true, data: () => ({displayName: 'Stale Owner A'})});
    await assert.rejects(pending, error => error.code === 'account/session-changed');
    assert.ok(!JSON.stringify(visible).includes('Stale Owner A'));
  }
});

test('Google pending hides the previous account and rejects stale reads until the new-user result is known', async () => {
  const popup = deferred(), read = deferred();
  const {service, auth, notify} = fakeService({signInWithPopup: () => popup.promise, getDoc: () => read.promise});
  const visible = [];
  service.onAuthChanged(value => visible.push(value));
  const oldRead = service.readAccountSummary();
  await new Promise(resolve => setImmediate(resolve));
  const signingIn = service.signInGoogle();
  assert.equal(visible.at(-1), null, 'hide account details immediately while Google choice is pending');
  await assert.rejects(service.readAccountSummary(), error => error.code === 'account/session-changed');
  read.resolve({exists: () => true, data: () => ({displayName: 'Stale Owner A'})});
  await assert.rejects(oldRead, error => error.code === 'account/session-changed');
  auth.currentUser = {...auth.currentUser, uid: 'synthetic-subject-b', email: 'new-owner@example.test', providerData: [{providerId: 'google.com'}]};
  notify();
  assert.equal(visible.at(-1), null);
  popup.resolve({user: auth.currentUser, isNewUser: true});
  await signingIn;
  assert.equal(visible.at(-1).isNewUser, true);
  assert.equal(visible.at(-1).maskedEmail, 'ne***@example.test');
  assert.ok(!JSON.stringify(visible).includes('synthetic-subject'));
});

test('read failures remain unavailable and never reveal SDK error or resource details', async () => {
  const {service} = fakeService({getDoc: async resource => {
    throw {code: resource.includes('owner_profiles') ? 'permission-denied' : 'unavailable', message: 'synthetic-subject-a secret@example.test'};
  }});
  const summary = await service.readAccountSummary();
  assert.equal(summary.unavailableFields.length, 3);
  assert.doesNotMatch(JSON.stringify(summary), /synthetic-subject|secret@example|permission-denied/);
});

test('logout wins over a Google popup that succeeds later', async () => {
  const popup = deferred();
  const {service, auth, sdk, notify, calls} = fakeService({signInWithPopup: () => popup.promise});
  const visible = [];
  service.onAuthChanged(value => visible.push(value));
  let sdkSignOuts = 0;
  const realFakeSignOut = sdk.signOut;
  sdk.signOut = async target => { sdkSignOuts++; await realFakeSignOut(target); };
  const signingIn = service.signInGoogle();
  await service.signOut();
  assert.equal(auth.currentUser, null);
  const afterLogout = visible.length;
  // Firebase may update currentUser before the pending popup promise resolves.
  // The logout generation must still hide and discard that late sign-in.
  auth.currentUser = {
    uid: 'synthetic-late-google-owner', email: 'late-owner@example.test',
    emailVerified: true, providerData: [{providerId: 'google.com'}],
  };
  notify();
  popup.resolve({user: auth.currentUser, isNewUser: true});
  await signingIn;
  assert.equal(sdkSignOuts, 2, 'late popup identity is signed out again');
  assert.equal(auth.currentUser, null);
  assert.ok(visible.slice(afterLogout).every(value => value === null));
  await assert.rejects(service.readAccountSummary(), error => error.code === 'account/session-changed');
  assert.deepEqual(calls, []);
});
