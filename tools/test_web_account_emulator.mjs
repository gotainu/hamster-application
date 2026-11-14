#!/usr/bin/env node
// Integration tests against dedicated demo emulators only. Production is refused
// before SDK initialization. Seeds are synthetic and never touch a real project.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import test, {before, after} from 'node:test';
import {summarizeAccount} from '../public/assets/account-model.mjs';

const PROJECT = 'demo-hamcare-web-auth-task2';
assert.equal(process.env.GCLOUD_PROJECT, PROJECT, 'Dedicated demo project required');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:19999', 'Dedicated loopback Auth emulator required');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:19980', 'Dedicated loopback Firestore emulator required');
if (process.env.GOOGLE_CLOUD_PROJECT) assert.equal(process.env.GOOGLE_CLOUD_PROJECT, PROJECT);
const dependencies = process.env.HAMCARE_NODE_MODULES;
assert.ok(dependencies && path.isAbsolute(dependencies), 'Point HAMCARE_NODE_MODULES at existing node_modules; do not install packages');
const require = createRequire(path.join(path.dirname(dependencies), 'package.json'));
assert.equal(require('firebase/package.json').version, '12.17.1', 'Use the existing verified SDK version');
const {initializeApp, deleteApp} = require('firebase/app');
const {initializeAuth, inMemoryPersistence, connectAuthEmulator, signInWithEmailAndPassword, signInWithCredential, GoogleAuthProvider, getAdditionalUserInfo, signOut} = require('firebase/auth');
const {getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc} = require('firebase/firestore/lite');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const full = require('firebase/firestore');
const admin = require('firebase-admin');
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PASSWORD = 'EmulatorOnly-Local-234!';
const A = 'synthetic-web-owner-a';
const B = 'synthetic-web-owner-b';
const U = 'synthetic-web-unverified';
const GOOGLE = 'synthetic-google-existing';
const paths = uid => [
  `users/${uid}/owner_profiles/main`,
  `users/${uid}/billing/subscription`,
  `users/${uid}/feature_access/initial_trial_v2`,
];
let rules, adminApp, adminAuth, first, second;
const clients = [];

function client(name) {
  const app = initializeApp({projectId: PROJECT, apiKey: 'demo-only-no-production-key', authDomain: 'localhost'}, name);
  const auth = initializeAuth(app, {persistence: inMemoryPersistence});
  connectAuthEmulator(auth, 'http://127.0.0.1:19999', {disableWarnings: true});
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 19980);
  const result = {app, auth, db};
  clients.push(result);
  return result;
}
async function signIn(target, email) {
  return signInWithEmailAndPassword(target.auth, email, PASSWORD);
}
async function rejectsCredential(promise) {
  await assert.rejects(promise, error => typeof error.code === 'string' && /^auth\//.test(error.code));
}

before(async () => {
  rules = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {host: '127.0.0.1', port: 19980, rules: readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8')},
  });
  // Reset only this explicitly guarded demo project so reruns are deterministic.
  const reset = await fetch(`http://127.0.0.1:19999/emulator/v1/projects/${PROJECT}/accounts`, {method: 'DELETE'});
  assert.ok(reset.ok, 'Dedicated demo Auth fixture reset failed');
  await rules.clearFirestore();
  adminApp = admin.initializeApp({projectId: PROJECT}, 'web-task2-emulator-admin');
  adminAuth = adminApp.auth();
  for (const [uid, email, emailVerified] of [[A, 'web-a@example.test', true], [B, 'web-b@example.test', true], [U, 'unverified@example.test', false]]) {
    await adminAuth.createUser({uid, email, password: PASSWORD, emailVerified});
  }
  const imported = await adminAuth.importUsers([{
    uid: GOOGLE, email: 'existing-google@example.test', emailVerified: true,
    providerData: [{providerId: 'google.com', uid: 'google-existing-sub', email: 'existing-google@example.test'}],
  }]);
  assert.equal(imported.successCount, 1);
  await rules.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [uid, name] of [[A, '飼い主A'], [B, '飼い主B']]) {
      const [owner, billing, trial] = paths(uid);
      await full.setDoc(full.doc(db, owner), {displayName: name});
      await full.setDoc(full.doc(db, billing), {plan: 'paid', status: 'active', customerId: `cus_${uid}`});
      await full.setDoc(full.doc(db, trial), {status: 'active', endsAt: new Date('2030-01-01T00:00:00Z')});
    }
  });
  first = client('web-task2-owner-a');
  second = client('web-task2-owner-b');
});

after(async () => {
  await Promise.all(clients.map(async item => {await signOut(item.auth); await deleteApp(item.app);}));
  await rules?.cleanup();
  await adminApp?.delete();
});

test('existing verified email/password account signs in to the original UID', async () => {
  const credential = await signIn(first, 'web-a@example.test');
  assert.equal(credential.user.uid, A);
  assert.equal(credential.user.emailVerified, true);
});

test('wrong password and nonexistent email reject through real Auth SDK', async () => {
  await rejectsCredential(signInWithEmailAndPassword(first.auth, 'web-a@example.test', 'Wrong-Local-Password!'));
  await rejectsCredential(signIn(first, 'does-not-exist@example.test'));
  assert.equal(first.auth.currentUser.uid, A);
});

test('unverified user remains unverified until emulator confirmation and reload', async () => {
  const temp = client('web-task2-unverified');
  const credential = await signIn(temp, 'unverified@example.test');
  assert.equal(credential.user.uid, U);
  assert.equal(credential.user.emailVerified, false);
  await credential.user.reload();
  assert.equal(credential.user.emailVerified, false);
  await adminAuth.updateUser(U, {emailVerified: true});
  await credential.user.reload();
  assert.equal(credential.user.emailVerified, true);
  await signOut(temp.auth);
  assert.equal(temp.auth.currentUser, null);
});

test('existing Google credential preserves its seeded UID', async () => {
  const google = client('web-task2-google-existing');
  const credential = GoogleAuthProvider.credential(JSON.stringify({sub: 'google-existing-sub', email: 'existing-google@example.test', email_verified: true}));
  const result = await signInWithCredential(google.auth, credential);
  assert.equal(result.user.uid, GOOGLE);
  assert.equal(result.user.emailVerified, true);
  assert.equal(getAdditionalUserInfo(result).isNewUser, false);
  assert.ok(result.user.providerData.some(provider => provider.providerId === 'google.com'));
});

test('new Google subject can create a new UID in the emulator', async () => {
  const google = client('web-task2-google-new');
  const result = await signInWithCredential(google.auth, GoogleAuthProvider.credential(JSON.stringify({sub: 'google-new-sub', email: 'new-google@example.test', email_verified: true})));
  assert.equal(getAdditionalUserInfo(result).isNewUser, true);
  assert.ok(result.user.uid);
  assert.ok(![A, B, U, GOOGLE].includes(result.user.uid));
});

test('same-email provider handling stays with Firebase and never picks another owner UID', async context => {
  const collision = client('web-task2-google-collision');
  try {
    const result = await signInWithCredential(collision.auth, GoogleAuthProvider.credential(JSON.stringify({sub: 'google-a-sub', email: 'web-a@example.test', email_verified: true})));
    assert.equal(result.user.uid, A);
    context.diagnostic('Emulator linked the provider to the existing synthetic owner. Production provider trust can differ.');
  } catch (error) {
    assert.equal(error.code, 'auth/account-exists-with-different-credential');
    context.diagnostic('Emulator required the existing provider. The app must show its Japanese login-method guidance.');
  }
});

for (const [index, label] of ['owner profile', 'billing subscription', 'initial trial'].entries()) {
  test(`owner can read its ${label} through real Auth and existing Rules`, async () => {
    const snap = await getDoc(doc(first.db, paths(A)[index]));
    assert.equal(snap.exists(), true);
  });
  test(`owner A cannot read owner B ${label}`, async () => {
    await assertFails(getDoc(doc(first.db, paths(B)[index])));
  });
}

test('second signed-in user sees its own nickname without mixing accounts', async () => {
  await signIn(second, 'web-b@example.test');
  const snapshots = await Promise.all(paths(B).map(p => getDoc(doc(second.db, p))));
  const summary = summarizeAccount(second.auth.currentUser, Object.fromEntries(['owner', 'billing', 'trial'].map((key, i) => [key, {kind: 'found', data: snapshots[i].data()}])));
  assert.equal(summary.nickname, '飼い主B');
  assert.ok(!JSON.stringify(summary).includes('飼い主A'));
});

test('billing and trial writes remain rejected by unchanged Rules', async () => {
  await assertFails(setDoc(doc(first.db, paths(A)[1]), {plan: 'paid', status: 'active'}));
  await assertFails(setDoc(doc(first.db, paths(A)[2]), {status: 'active', endsAt: new Date('2040-01-01T00:00:00Z')}));
});

test('logout clears Auth state and makes all owner reads fail', async () => {
  await signOut(first.auth);
  assert.equal(first.auth.currentUser, null);
  for (const p of paths(A)) await assertFails(getDoc(doc(first.db, p)));
});
