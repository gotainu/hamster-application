#!/usr/bin/env node
// Synthetic Apple provider identities against dedicated loopback demo emulators.
// This is NOT real Apple OAuth, state/nonce verification, Safari, or an iOS↔Web
// production UID measurement. Popup is an explicit stub; credential exchange,
// Auth identities, Firestore reads, and the repository Rules are real emulators.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import test, {before, after} from 'node:test';
import {createAccountService} from '../public/assets/account-service.mjs';

const PROJECT = 'demo-hamcare-web-apple-task7';
assert.equal(process.env.GCLOUD_PROJECT, PROJECT, 'Dedicated demo project required');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:19999', 'Dedicated loopback Auth emulator required');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:19980', 'Dedicated loopback Firestore emulator required');
if (process.env.GOOGLE_CLOUD_PROJECT) assert.equal(process.env.GOOGLE_CLOUD_PROJECT, PROJECT);
const dependencies = process.env.HAMCARE_NODE_MODULES;
assert.ok(dependencies && path.isAbsolute(dependencies), 'Use an existing absolute node_modules path; do not install dependencies');
const require = createRequire(path.join(path.dirname(dependencies), 'package.json'));
assert.equal(require('firebase/package.json').version, '12.17.1', 'Use the existing pinned Firebase SDK');
const {initializeApp, deleteApp} = require('firebase/app');
const authSdk = require('firebase/auth');
const {initializeAuth, inMemoryPersistence, connectAuthEmulator, OAuthProvider,
  signInWithCredential, getAdditionalUserInfo, signOut} = authSdk;
const {getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc} = require('firebase/firestore/lite');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const full = require('firebase/firestore');
const admin = require('firebase-admin');
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REAL = {uid: 'synthetic-apple-existing-public', sub: 'synthetic-apple-public-sub', email: 'apple-public@example.test'};
const RELAY = {uid: 'synthetic-apple-existing-relay', sub: 'synthetic-apple-relay-sub', email: 'synthetic-relay@privaterelay.example.test'};
const PASSWORD_OWNER = {uid: 'synthetic-apple-collision-password', email: 'same-email-observation@example.test'};
const APPLE_PUBLIC_FIXTURE = {sub: REAL.sub, email: REAL.email, email_verified: true, is_private_email: false};
const APPLE_RELAY_FIXTURE = {sub: RELAY.sub, email: RELAY.email, email_verified: true, is_private_email: true};
const clients = [];
let rules, adminApp, publicClient, relayClient;
const paths = uid => ({
  owner: `users/${uid}/owner_profiles/main`,
  pet: `users/${uid}/pet_profiles/main_pet`,
  billing: `users/${uid}/billing/subscription`,
  trial: `users/${uid}/feature_access/initial_trial_v2`,
});

function client(name) {
  const app = initializeApp({projectId: PROJECT, apiKey: 'demo-only-no-production-key', authDomain: 'localhost'}, name);
  const auth = initializeAuth(app, {persistence: inMemoryPersistence});
  connectAuthEmulator(auth, 'http://127.0.0.1:19999', {disableWarnings: true});
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 19980);
  const target = {app, auth, db};
  clients.push(target);
  return target;
}
function credential(claims) {
  // Emulator-only unsigned identity JSON. Never a real Apple token or secret.
  return new OAuthProvider('apple.com').credential({idToken: JSON.stringify(claims)});
}
async function apple(target, claims) {
  return signInWithCredential(target.auth, credential(claims));
}
function popupAdapter(claimsOrError) {
  return {
    ...authSdk, doc, getDoc,
    // Node has no browser session store. This substitution is local to this
    // fixture adapter and does not change production browser persistence.
    browserSessionPersistence: inMemoryPersistence,
    async signInWithPopup(auth, provider) {
      assert.equal(provider.providerId, 'apple.com');
      if (claimsOrError?.code) throw claimsOrError;
      return signInWithCredential(auth, credential(claimsOrError));
    },
  };
}
function service(target, claimsOrError) {
  return createAccountService({auth: target.auth, db: target.db, sdk: popupAdapter(claimsOrError), appleSignInEnabled: true});
}

before(async () => {
  rules = await initializeTestEnvironment({projectId: PROJECT, firestore: {
    host: '127.0.0.1', port: 19980, rules: readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8'),
  }});
  // Reset only the explicitly guarded synthetic project. No live project is used.
  const reset = await fetch(`http://127.0.0.1:19999/emulator/v1/projects/${PROJECT}/accounts`, {method: 'DELETE'});
  assert.ok(reset.ok, 'Dedicated demo Auth fixture reset failed');
  await rules.clearFirestore();
  adminApp = admin.initializeApp({projectId: PROJECT}, 'apple-task7-emulator-admin');
  const imported = await adminApp.auth().importUsers([REAL, RELAY].map(identity => ({
    uid: identity.uid, email: identity.email, emailVerified: true,
    providerData: [{providerId: 'apple.com', uid: identity.sub, email: identity.email}],
  })));
  assert.equal(imported.successCount, 2, 'Synthetic Apple provider fixture import failed');
  await adminApp.auth().createUser({...PASSWORD_OWNER, password: 'Only-Emulator-Local-234!', emailVerified: true});
  await rules.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [identity, name] of [[REAL, '合成Apple公開メール'], [RELAY, '合成Apple非公開メール']]) {
      const p = paths(identity.uid);
      await full.setDoc(full.doc(db, p.owner), {displayName: name});
      await full.setDoc(full.doc(db, p.pet), {name: '合成のペット', species: 'ロボロフスキー', color: 'パイド'});
      await full.setDoc(full.doc(db, p.billing), {plan: 'none', status: 'none'});
      await full.setDoc(full.doc(db, p.trial), {status: 'active', endsAt: new Date('2030-01-01T00:00:00Z')});
    }
  });
  publicClient = client('apple-task7-public');
  relayClient = client('apple-task7-relay');
});

after(async () => {
  await Promise.all(clients.map(async target => {await signOut(target.auth); await deleteApp(target.app);}));
  await rules?.cleanup();
  await adminApp?.delete();
});

test('synthetic existing public-email Apple provider identity preserves seeded UID', async () => {
  const result = await apple(publicClient, APPLE_PUBLIC_FIXTURE);
  assert.equal(result.user.uid, REAL.uid);
  assert.equal(result.user.emailVerified, true);
  assert.equal(getAdditionalUserInfo(result).isNewUser, false);
  assert.ok(result.user.providerData.some(provider => provider.providerId === 'apple.com' && provider.uid === REAL.sub));
});

test('synthetic private-relay Apple provider identity preserves its separate seeded UID', async () => {
  const result = await apple(relayClient, APPLE_RELAY_FIXTURE);
  assert.equal(result.user.uid, RELAY.uid);
  assert.notEqual(result.user.uid, REAL.uid);
  assert.equal(result.user.emailVerified, true);
  assert.equal(getAdditionalUserInfo(result).isNewUser, false);
});

test('second synthetic Apple login without profile name or email uses provider subject, not a new account', async () => {
  await signOut(relayClient.auth);
  const result = await apple(relayClient, {sub: RELAY.sub});
  assert.equal(result.user.uid, RELAY.uid);
  assert.equal(getAdditionalUserInfo(result).isNewUser, false);
  assert.ok(result.user.providerData.some(provider => provider.providerId === 'apple.com' && provider.uid === RELAY.sub));
  assert.equal((await getDoc(doc(relayClient.db, paths(RELAY.uid).owner))).get('displayName'), '合成Apple非公開メール');
});

test('different synthetic Apple subjects with distinct emails obtain distinct Firebase UIDs', async () => {
  const first = client('apple-task7-new-a');
  const second = client('apple-task7-new-b');
  const a = await apple(first, {sub: 'synthetic-apple-new-a', email: 'new-apple-a@example.test', email_verified: true});
  const b = await apple(second, {sub: 'synthetic-apple-new-b', email: 'new-apple-b@example.test', email_verified: true});
  assert.equal(getAdditionalUserInfo(a).isNewUser, true);
  assert.equal(getAdditionalUserInfo(b).isNewUser, true);
  assert.notEqual(a.user.uid, b.user.uid);
  assert.ok(![REAL.uid, RELAY.uid].includes(a.user.uid));
  assert.ok(![REAL.uid, RELAY.uid].includes(b.user.uid));
});

test('real Emulator credential exchange through explicitly stubbed Popup preserves Apple account projection', async () => {
  const target = client('apple-task7-service-existing');
  const api = service(target, APPLE_PUBLIC_FIXTURE);
  await api.ready();
  await api.signInApple();
  assert.equal(target.auth.currentUser.uid, REAL.uid);
  const summary = await api.readAccountSummary();
  assert.equal(summary.appAccountExists, true);
  assert.equal(summary.nickname, '合成Apple公開メール');
  assert.deepEqual(summary.methods, ['Apple']);
  assert.equal(summary.planReview.canSelectPlan, true);
  assert.doesNotMatch(JSON.stringify(summary), /synthetic-apple-public-sub|synthetic-apple-existing-public|apple-public@example\.test/);
  await api.signOut();
});

test('new synthetic Apple UID without main_pet cannot proceed to plan or contract through account service', async () => {
  const target = client('apple-task7-service-empty');
  const api = service(target, {sub: 'synthetic-apple-empty-sub', email: 'empty-apple@example.test', email_verified: true});
  const states = [];
  const unwatch = api.onAuthChanged(value => states.push(value));
  await api.ready();
  await api.signInApple();
  assert.ok(target.auth.currentUser.uid);
  assert.ok(states.some(value => value?.isNewUser === true));
  const summary = await api.readAccountSummary();
  assert.equal(summary.appAccountExists, false);
  assert.equal(summary.planReview.canSelectPlan, false);
  assert.equal((await getDoc(doc(target.db, paths(target.auth.currentUser.uid).pet))).exists(), false);
  unwatch();
  await api.signOut();
});

test('synthetic Popup cancellation leaves a signed-out Emulator client without a session', async () => {
  const target = client('apple-task7-service-cancel');
  const api = service(target, {code: 'auth/popup-closed-by-user'});
  await api.ready();
  await assert.rejects(api.signInApple(), error => error.code === 'auth/popup-closed-by-user');
  assert.equal(target.auth.currentUser, null);
  assert.equal(api.safeError({code: 'auth/popup-closed-by-user'}), 'ログインを中止しました。必要な場合にもう一度お試しください。');
});

test('synthetic Popup failure remains private and cannot create a signed-in session', async () => {
  const target = client('apple-task7-service-failure');
  const api = service(target, {code: 'auth/network-request-failed', privateDetails: 'synthetic-hidden-authorization-code'});
  await api.ready();
  await assert.rejects(api.signInApple(), error => error.code === 'auth/network-request-failed');
  assert.equal(target.auth.currentUser, null);
  assert.doesNotMatch(api.safeError({code: 'auth/network-request-failed'}), /synthetic|code|token|@/);
});

for (const [label, key] of [['owner profile', 'owner'], ['pet profile', 'pet'], ['billing', 'billing'], ['initial trial', 'trial']]) {
  test(`Apple-authenticated owner can read its own ${label} under production Rules`, async () => {
    assert.equal((await getDoc(doc(publicClient.db, paths(REAL.uid)[key]))).exists(), true);
  });
  test(`Apple-authenticated owner cannot read another UID's ${label} under production Rules`, async () => {
    await assertFails(getDoc(doc(publicClient.db, paths(RELAY.uid)[key])));
  });
}

test('Apple-authenticated client cannot create paid billing, extend a trial, or rewrite the pet identity', async () => {
  await assertFails(setDoc(doc(publicClient.db, paths(REAL.uid).billing), {plan: 'paid', status: 'active'}));
  await assertFails(setDoc(doc(publicClient.db, paths(REAL.uid).trial), {status: 'active', endsAt: new Date('2040-01-01T00:00:00Z')}));
  await assertFails(setDoc(doc(publicClient.db, paths(REAL.uid).pet), {name: 'not allowed'}));
  assert.equal((await getDoc(doc(publicClient.db, paths(REAL.uid).billing))).get('plan'), 'none');
});

test('same-email trusted-provider behavior is an observation, never proof of no automatic linking', async context => {
  const target = client('apple-task7-same-email-observation');
  try {
    const result = await apple(target, {sub: 'synthetic-apple-same-email-sub', email: PASSWORD_OWNER.email, email_verified: true});
    const linkedToExisting = result.user.uid === PASSWORD_OWNER.uid;
    context.diagnostic(`OBSERVATION ONLY: Auth Emulator accepted Apple credential; linked-to-existing-password-UID=${linkedToExisting}. This does not establish production anti-linking, Apple OAuth or iOS UID compatibility.`);
  } catch (error) {
    assert.equal(error.code, 'auth/account-exists-with-different-credential');
    context.diagnostic('OBSERVATION ONLY: Auth Emulator requested the existing provider. Production trusted-provider linking can differ; anti-linking is not established.');
  }
  // No HamCare business data is copied, merged or written by this observation.
  await rules.withSecurityRulesDisabled(async context => {
    for (const p of Object.values(paths(PASSWORD_OWNER.uid))) assert.equal((await full.getDoc(full.doc(context.firestore(), p))).exists(), false);
  });
});

test('logout removes Apple session and rejects every owner document read', async () => {
  await signOut(publicClient.auth);
  assert.equal(publicClient.auth.currentUser, null);
  for (const p of Object.values(paths(REAL.uid))) await assertFails(getDoc(doc(publicClient.db, p)));
});
