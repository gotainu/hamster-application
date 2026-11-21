import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {consumeSupportDeletionLink, canUseSupportDeletion, createSupportDeletionService} from '../public/assets/support-deletion-service.mjs';
import {mountSupportDeletionPage, supportDeletionError} from '../public/assets/support-deletion.mjs';

const link = Object.freeze({requestId: 'a'.repeat(48), proof: 'b'.repeat(64)});
const html = await readFile(new URL('../public/account-deletion/confirm/index.html', import.meta.url), 'utf8');
const serviceSource = await readFile(new URL('../public/assets/support-deletion-service.mjs', import.meta.url), 'utf8');
const pageSource = await readFile(new URL('../public/assets/support-deletion.mjs', import.meta.url), 'utf8');
const css = await readFile(new URL('../public/assets/support-deletion.css', import.meta.url), 'utf8');

function harness({apple = false, newUser = false, revokeFailure = false, inspectDenied = false, appleTimeoutMs} = {}) {
  const user = {uid: 'existing-test-subject', email: null, providerData: apple ? [{providerId: 'apple.com', uid: 'fixed-apple-subject'}] : [{providerId: 'password'}]};
  const auth = {currentUser: null, authStateReady: async () => {}};
  const events = [], calls = [];
  class OAuthProvider {
    constructor(providerId) {this.providerId = providerId;}
    addScope() {}
    setCustomParameters() {}
    static credentialFromResult(result) {return result.credential ?? null;}
  }
  const result = provider => ({user, credential: provider === 'apple.com' ? {providerId: 'apple.com', accessToken: 'ephemeral-oauth-token'} : null});
  const sdk = {
    OAuthProvider,
    GoogleAuthProvider: class {setCustomParameters() {}},
    EmailAuthProvider: {credential: () => ({providerId: 'password'})},
    browserSessionPersistence: 'session', setPersistence: async () => {},
    getAdditionalUserInfo: () => ({isNewUser: newUser}),
    signInWithEmailAndPassword: async () => {events.push('login'); auth.currentUser = user; return result('password');},
    reauthenticateWithCredential: async () => {events.push('reauth-email'); return result('password');},
    signInWithPopup: async (_auth, provider) => {events.push('login-popup'); auth.currentUser = user; return result(provider.providerId);},
    reauthenticateWithPopup: async (_user, provider) => {events.push('reauth-popup'); return result(provider.providerId);},
    getIdToken: async () => 'firebase-test-token',
    signOut: async () => {events.push('signout'); auth.currentUser = null;},
    revokeAccessToken: async (_auth, token) => {events.push('apple-revoke'); assert.equal(token, 'ephemeral-oauth-token'); if (revokeFailure) throw new Error('safe simulated failure');},
  };
  const fetcher = async (_url, init) => {
    const body = JSON.parse(init.body); events.push(body.action); calls.push({body, init});
    if (body.action === 'inspect') return {ok: !inspectDenied, json: async () => inspectDenied ? {} : {ok: true, appleLinked: apple}};
    return {ok: true, json: async () => ({status: 'verified'})};
  };
  return {auth, sdk, user, events, calls, service: createSupportDeletionService({auth, sdk, fetcher, appleTimeoutMs})};
}

test('one-use fragment is removed before validation and contains no identity', () => {
  const replaced = [];
  const location = {pathname: '/account-deletion/confirm/', hash: `#request=${link.requestId}&proof=${link.proof}`};
  assert.deepEqual(consumeSupportDeletionLink(location, {replaceState: (...args) => replaced.push(args)}), link);
  assert.deepEqual(replaced, [[null, '', '/account-deletion/confirm/']]);
  for (const hash of ['', '#request=123', `${location.hash}&uid=forged`, `${location.hash}&request=${link.requestId}`, '#'.repeat(257)]) {
    assert.equal(consumeSupportDeletionLink({...location, hash}, {replaceState() {}}), null);
  }
});

test('release flag and canonical origin both required; Preview always disabled', () => {
  assert.equal(canUseSupportDeletion('https://hamster-breeding-app.web.app'), false);
  assert.equal(canUseSupportDeletion('https://hamster-breeding-app--web-first-task1-lco08m60.web.app', true), false);
  assert.equal(canUseSupportDeletion('https://hamster-breeding-app.web.app', true), true);
  assert.match(pageSource, /if \(!canUseSupportDeletion[\s\S]*?else \{[\s\S]*?import\('https:\/\/www.gstatic.com/);
});

test('existing profileless email account binds intent without profile/email/Firestore reads', async () => {
  const h = harness(); await h.service.ready();
  await h.service.signInEmail('user@example.test', 'not-a-real-password');
  assert.deepEqual(await h.service.inspect(link), {appleLinked: false});
  assert.deepEqual(await h.service.confirm(link, {intent: true}), {ok: true, status: 'verified'});
  assert.deepEqual(h.events, ['login', 'inspect', 'inspect', 'confirm', 'signout']);
  const {body, init} = h.calls.at(-1);
  assert.deepEqual(body, {action: 'confirm', ...link, confirmText: 'DELETE_MY_ACCOUNT', stopBillingConfirmed: true, appleRevocation: 'not_linked'});
  assert.equal(init.headers.Authorization, 'Bearer firebase-test-token');
  assert.equal(init.credentials, 'omit'); assert.equal(init.referrerPolicy, 'no-referrer');
  assert.doesNotMatch(serviceSource, /getFirestore|getDoc\(|readAccountSummary|owner_profiles|pet_profiles|console\.|localStorage|sessionStorage|deleteUser\(|linkWith/);
});

test('persisted login is not enough; no token or endpoint before fresh login', async () => {
  const h = harness(); h.auth.currentUser = h.user; await h.service.ready();
  await assert.rejects(h.service.inspect(link), {code: 'session_changed'});
  assert.equal(h.calls.length, 0);
  await h.service.signInEmail('user@example.test', 'not-a-real-password');
  assert.deepEqual(h.events, ['reauth-email']);
});

test('new social Firebase account is signed out and cannot confirm', async () => {
  const h = harness({newUser: true}); await h.service.ready();
  await assert.rejects(h.service.signInSocial('google'), {code: 'existing_account_required'});
  assert.equal(h.auth.currentUser, null); assert.equal(h.calls.length, 0);
});

test('session UID change after fresh login blocks all transport', async () => {
  const h = harness(); await h.service.signInEmail('user@example.test', 'test');
  h.auth.currentUser = {...h.user, uid: 'other-subject'};
  await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'session_changed'});
  assert.equal(h.calls.length, 0);
});

test('intent required before read/revoke/write; Apple login consent is explicit', async () => {
  const h = harness({apple: true});
  await assert.rejects(h.service.signInSocial('apple', false), {code: 'consent_required'});
  await h.service.signInSocial('apple', true);
  await assert.rejects(h.service.confirm(link, {intent: false}), {code: 'intent_required'});
  assert.equal(h.calls.length, 0); assert.ok(!h.events.includes('apple-revoke'));
});

test('Apple without email inspects exact target before revocation, then records client report', async () => {
  const h = harness({apple: true}); await h.service.signInSocial('apple', true);
  await h.service.confirm(link, {intent: true});
  assert.deepEqual(h.events, ['login-popup', 'inspect', 'apple-revoke', 'confirm', 'signout']);
  assert.equal(h.calls.at(-1).body.appleRevocation, 'revoked_client_reported');
  assert.ok(h.calls.every(call => !JSON.stringify(call.body).includes('oauth-token')));
});

test('manual acknowledgement cannot bypass an available Apple revocation attempt', async () => {
  const h = harness({apple: true}); await h.service.signInSocial('apple', true);
  await assert.rejects(h.service.confirm(link, {intent: true, manualAppleAcknowledged: true}), {code: 'manual_apple_unavailable'});
  assert.deepEqual(h.events, ['login-popup', 'inspect']);
  await h.service.confirm(link, {intent: true});
  assert.equal(h.calls.at(-1).body.appleRevocation, 'revoked_client_reported');
});

test('server rejection prevents Apple revoke and intent write', async () => {
  const h = harness({apple: true, inspectDenied: true}); await h.service.signInSocial('apple', true);
  await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'request_unavailable'});
  assert.deepEqual(h.events, ['login-popup', 'inspect']);
});

test('Google session with linked Apple reauthenticates original user and rechecks ticket', async () => {
  const h = harness({apple: true}); await h.service.signInSocial('google');
  await h.service.confirm(link, {intent: true});
  assert.deepEqual(h.events, ['login-popup', 'inspect', 'reauth-popup', 'inspect', 'apple-revoke', 'confirm', 'signout']);
});

test('Apple subject mismatch is fatal and never turns into manual fallback success', async () => {
  const h = harness({apple: true}); await h.service.signInSocial('google');
  h.sdk.reauthenticateWithPopup = async () => ({user: {...h.user, providerData: [{providerId: 'apple.com', uid: 'foreign-subject'}]}});
  await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'session_changed'});
  await assert.rejects(h.service.confirm(link, {intent: true, manualAppleAcknowledged: true}), {code: 'session_changed'});
  assert.deepEqual(h.events, ['login-popup', 'inspect']);
});

for (const code of ['auth/user-mismatch', 'auth/invalid-user-token', 'auth/user-token-expired', 'auth/account-exists-with-different-credential']) {
  test(`${code} invalidates fresh ownership and cannot be bypassed with manual Apple acknowledgement`, async () => {
    const h = harness({apple: true}); await h.service.signInSocial('google');
    h.sdk.reauthenticateWithPopup = async () => {throw Object.assign(new Error('SDK refused wrong identity'), {code});};
    await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'session_changed'});
    await assert.rejects(h.service.confirm(link, {intent: true, manualAppleAcknowledged: true}), {code: 'session_changed'});
    assert.deepEqual(h.events, ['login-popup', 'inspect']);
  });
}

test('Apple popup cancellation allows only a separately acknowledged manual continuation', async () => {
  const h = harness({apple: true}); await h.service.signInSocial('google');
  h.sdk.reauthenticateWithPopup = async () => {throw {code: 'auth/popup-closed-by-user'};};
  await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'manual_apple_required'});
  await h.service.confirm(link, {intent: true, manualAppleAcknowledged: true});
  assert.equal(h.calls.at(-1).body.appleRevocation, 'manual_acknowledged');
  assert.ok(!h.events.includes('apple-revoke'));
});

test('revocation failure requires separate manual acknowledgement and same request retry', async () => {
  const h = harness({apple: true, revokeFailure: true}); await h.service.signInSocial('apple', true);
  await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'manual_apple_required'});
  assert.equal(h.calls.some(call => call.body.action === 'confirm'), false);
  await h.service.confirm(link, {intent: true, manualAppleAcknowledged: true});
  assert.equal(h.calls.at(-1).body.appleRevocation, 'manual_acknowledged');
  assert.ok(h.calls.every(call => call.body.requestId === link.requestId));
  assert.equal(h.events.filter(item => item === 'apple-revoke').length, 1);
});

test('missing Apple access token is not reported as revocation success', async () => {
  const h = harness({apple: true}); await h.service.signInSocial('google');
  h.sdk.reauthenticateWithPopup = async () => ({user: h.user});
  await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'manual_apple_required'});
  assert.ok(!h.events.includes('apple-revoke')); assert.ok(!h.events.includes('confirm'));
});

test('unconfirmed Apple revocation timeout remains recoverable through explicit manual acknowledgement', async () => {
  const h = harness({apple: true, appleTimeoutMs: 1}); await h.service.signInSocial('apple', true);
  h.sdk.revokeAccessToken = async () => new Promise(() => {});
  await assert.rejects(h.service.confirm(link, {intent: true}), {code: 'manual_apple_required'});
  assert.ok(!h.events.includes('confirm'));
  await h.service.confirm(link, {intent: true, manualAppleAcknowledged: true});
  assert.equal(h.calls.at(-1).body.appleRevocation, 'manual_acknowledged');
});

test('confirmation never displays raw backend/SDK error details', () => {
  for (const error of [{message: 'private test token uid@example.test'}, {code: 'unknown', email: 'hidden@example.test'}]) {
    assert.doesNotMatch(supportDeletionError(error), /private test|uid@|hidden@/);
  }
});

function fakeDocument() {
  const items = new Map();
  return {items, getElementById(id) {
    if (!items.has(id)) items.set(id, {hidden: true, disabled: true, checked: false, value: '', textContent: '', listeners: {}, addEventListener(type, listener) {this.listeners[type] = listener;}});
    return items.get(id);
  }};
}
const settle = () => new Promise(resolve => setImmediate(resolve));

test('UI separates ownership and intent from operator deletion completion, blocks double click', async () => {
  const doc = fakeDocument(), calls = [];
  let release;
  const service = {ready: async () => {}, signInSocial: async () => {}, inspect: async () => ({appleLinked: true}), confirm: async (_link, options) => {calls.push(options); await new Promise(resolve => release = resolve);}, signOut: async () => {}};
  await mountSupportDeletionPage({doc, link, service});
  doc.getElementById('support-apple-consent').checked = true;
  doc.getElementById('support-apple').listeners.click(); await settle();
  assert.equal(doc.getElementById('deletion-intent-panel').hidden, false);
  assert.equal(doc.getElementById('support-apple-manual').hidden, false);
  assert.equal(doc.getElementById('support-manual-choice').hidden, true);
  assert.equal(doc.getElementById('support-manual-ack').disabled, true);
  assert.doesNotMatch(doc.getElementById('verified-account').textContent, /existing-test-subject/);
  doc.getElementById('support-intent').checked = true;
  doc.getElementById('support-confirm').listeners.click();
  doc.getElementById('support-confirm').listeners.click();
  assert.equal(calls.length, 1); release(); await settle();
  assert.equal(doc.getElementById('support-verified').hidden, false);
  assert.match(doc.getElementById('request-status').textContent, /削除の完了は、運営から別途/);
});

test('manual Apple choice appears only after service reports an attempted but unconfirmed revocation', async () => {
  const doc = fakeDocument();
  const service = {ready: async () => {}, signInSocial: async () => {}, inspect: async () => ({appleLinked: true}), confirm: async () => {throw {code: 'manual_apple_required'};}};
  await mountSupportDeletionPage({doc, link, service});
  doc.getElementById('support-apple-consent').checked = true;
  doc.getElementById('support-apple').listeners.click(); await settle();
  assert.equal(doc.getElementById('support-manual-choice').hidden, true);
  doc.getElementById('support-intent').checked = true;
  doc.getElementById('support-confirm').listeners.click(); await settle();
  assert.equal(doc.getElementById('support-manual-choice').hidden, false);
  assert.equal(doc.getElementById('support-manual-ack').disabled, false);
  assert.equal(doc.getElementById('support-manual-ack').checked, false);
});

test('invalid link never initializes authentication controls', async () => {
  const doc = fakeDocument(); let ready = 0;
  await mountSupportDeletionPage({doc, link: null, service: {ready: () => ready++}});
  assert.equal(ready, 0); assert.equal(doc.getElementById('verification-controls').hidden, true);
});

test('confirmation uses approved icon/theme and narrow-screen, keyboard-friendly controls', () => {
  assert.match(html, /hamcare-mark-outline\.png/);
  assert.match(html, /account-deletion\.css/); assert.match(html, /support-deletion\.css/);
  assert.match(css, /font-size: 16px/); assert.match(css, /min-height: 48px/);
  assert.match(css, /min-width: 0/); assert.match(css, /overflow-wrap: anywhere/);
  assert.match(html, /for="support-email"/); assert.match(html, /for="support-password"/);
  assert.match(html, /role="status" aria-live="polite"/);
  assert.match(html, /アプリの再インストールや購入は必要ありません/);
  assert.doesNotMatch(html, /href="\/account\/|billing\.stripe|checkout\.stripe|\b550円/);
});
