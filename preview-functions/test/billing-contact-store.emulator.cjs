'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {randomUUID} = require('node:crypto');

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8298') {
  throw new Error('Dedicated local billing contact Store Emulator required');
}
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {createBillingContactEngine, BILLING_CONTACT_NAMESPACE, BILLING_CONTACT_TTL_MS} = require('../lib/preview-functions/src/billing-contact');
const {createFirestoreBillingContactStore} = require('../lib/preview-functions/src/billing-contact-store');
const projectId = 'demo-hamcare-billing-contact-store';
const app = initializeApp({projectId}, 'billing-contact-store-emulator');
const db = getFirestore(app);
const store = createFirestoreBillingContactStore(db);
const tokenFrom = message => new URLSearchParams(new URL(message.verificationUrl).hash.slice(1)).get('token');
const rejects = (promise, code) => assert.rejects(promise, error => error.code === code);

function context(uid) {
  return {identity: {uid, emailVerified: false, authBasis: 'apple_provider'},
    adminUser: {uid, disabled: false, emailVerified: false,
      providerData: [{providerId: 'apple.com', uid: 'synthetic-apple-subject-' + uid}]},
    appAccountExists: true};
}
function fixture(extra = {}) {
  const uid = 'synthetic-store-' + randomUUID();
  const owner = context(uid), sent = [];
  let millis = Date.parse('2026-11-19T03:00:00Z');
  const sender = async message => {sent.push(message);};
  const dependencies = {store, now: () => new Date(millis), sendMail: sender, ...extra};
  return {uid, owner, sent, dependencies, engine: createBillingContactEngine(dependencies),
    ref: db.collection(BILLING_CONTACT_NAMESPACE).doc(uid), advance: delta => {millis += delta;}};
}

test('real store persists only the bound token hash; a fresh engine can confirm without changing business data', async () => {
  const f = fixture(), beforeIdentity = structuredClone(f.owner);
  const production = db.doc('users/' + f.uid + '/billing/subscription');
  const pet = db.doc('users/' + f.uid + '/pet_profiles/main_pet');
  await production.set({sentinel: 'synthetic-existing-billing', plan: 'none'});
  await pet.set({sentinel: 'synthetic-existing-pet'});
  const liveBefore = await production.get(), petBefore = await pet.get();
  const pending = await f.engine.request(f.owner, 'synthetic@example.test');
  assert.equal(pending.canCheckout, false);
  assert.equal(f.sent.length, 1);
  const token = tokenFrom(f.sent[0]), stored = (await f.ref.get()).data();
  assert.match(stored.pending.tokenHash, /^[a-f0-9]{64}$/);
  assert.equal(stored.pending.email, 'synthetic@example.test');
  assert.doesNotMatch(JSON.stringify(stored), new RegExp(token));
  const url = new URL(f.sent[0].verificationUrl);
  assert.equal(url.pathname, '/account/contact/'); assert.equal(url.search, '');
  assert.doesNotMatch(f.sent[0].verificationUrl, /synthetic-store|@|uid=|email=/);
  const restarted = createBillingContactEngine(f.dependencies);
  const verified = await restarted.confirm(f.owner, token);
  assert.equal(verified.canCheckout, true);
  assert.deepEqual(await restarted.requireVerified(f.owner), {email: 'synthetic@example.test', source: 'user_supplied'});
  assert.equal((await f.ref.get()).get('pending'), undefined);
  assert.deepEqual(f.owner, beforeIdentity);
  assert.deepEqual((await production.get()).data(), liveBefore.data());
  assert.equal((await production.get()).updateTime.toMillis(), liveBefore.updateTime.toMillis());
  assert.deepEqual((await pet.get()).data(), petBefore.data());
  assert.equal((await pet.get()).updateTime.toMillis(), petBefore.updateTime.toMillis());
});

test('simultaneous real Firestore requests elect exactly one mail dispatch and one rate rejection', async () => {
  const f = fixture();
  const results = await Promise.allSettled([
    f.engine.request(f.owner, 'synthetic@example.test'), f.engine.request(f.owner, 'synthetic@example.test'),
  ]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter(result => result.status === 'rejected' && result.reason.code === 'contact_rate_limited').length, 1);
  assert.equal(f.sent.length, 1);
  const stored = (await f.ref.get()).data();
  assert.equal(stored.requestedAt.length, 1);
  assert.equal(stored.pending.deliveryState, 'sent');
});

test('simultaneous real Firestore confirmations consume the own token once and reject the loser', async () => {
  const f = fixture(); await f.engine.request(f.owner, 'synthetic@example.test');
  const token = tokenFrom(f.sent[0]);
  const results = await Promise.allSettled([f.engine.confirm(f.owner, token), f.engine.confirm(f.owner, token)]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter(result => result.status === 'rejected' && result.reason.code === 'contact_token_used').length, 1);
  const snapshot = await f.ref.get();
  assert.equal(snapshot.get('verified'), true); assert.equal(snapshot.get('usedTokenHashes').length, 1);
  assert.equal(snapshot.get('pending'), undefined);
  await rejects(f.engine.confirm(f.owner, token), 'contact_token_used');
  assert.equal((await f.ref.get()).updateTime.toMillis(), snapshot.updateTime.toMillis());
});

test('a new pending address keeps the old verified contact across process restart and failed delivery', async () => {
  const f = fixture();
  await f.engine.request(f.owner, 'old@example.test'); await f.engine.confirm(f.owner, tokenFrom(f.sent[0]));
  const oldVerifiedAt = (await f.ref.get()).get('verifiedAt'); f.advance(60000);
  const next = await f.engine.request(f.owner, 'new@example.test');
  assert.equal(next.maskedEmail, 'ol***@example.test'); assert.equal(next.pendingMaskedEmail, 'ne***@example.test');
  assert.equal(next.canCheckout, true); assert.equal((await f.ref.get()).get('verifiedAt'), oldVerifiedAt);
  const restarted = createBillingContactEngine(f.dependencies);
  assert.equal((await restarted.requireVerified(f.owner)).email, 'old@example.test');
  await restarted.confirm(f.owner, tokenFrom(f.sent[1]));
  assert.equal((await restarted.requireVerified(f.owner)).email, 'new@example.test');
  f.advance(60000);
  const failedSender = createBillingContactEngine({...f.dependencies, sendMail: async () => {throw {delivery: 'not_sent'};}});
  await rejects(failedSender.request(f.owner, 'failed@example.test'), 'contact_delivery_failed');
  assert.equal((await failedSender.requireVerified(f.owner)).email, 'new@example.test');
  assert.equal((await f.ref.get()).get('pending').deliveryState, 'failed');
});

test('wrong UID and tampered token never create another owner record or mutate the pending owner', async () => {
  const f = fixture(); await f.engine.request(f.owner, 'synthetic@example.test');
  const token = tokenFrom(f.sent[0]), before = await f.ref.get();
  const otherUid = 'synthetic-other-' + randomUUID(), other = context(otherUid);
  await rejects(f.engine.confirm(other, token), 'contact_token_invalid');
  assert.equal((await db.collection(BILLING_CONTACT_NAMESPACE).doc(otherUid).get()).exists, false);
  assert.equal((await f.ref.get()).updateTime.toMillis(), before.updateTime.toMillis());
  await rejects(f.engine.confirm(f.owner, token.slice(0, 42) + (token.endsWith('A') ? 'B' : 'A')), 'contact_token_invalid');
  assert.equal((await f.ref.get()).updateTime.toMillis(), before.updateTime.toMillis());
  await f.engine.confirm(f.owner, token); assert.equal((await f.engine.status(f.owner)).verified, true);
});

test('expiry and resend work against persisted state and invalidate the previous link', async () => {
  const f = fixture(); await f.engine.request(f.owner, 'synthetic@private.icloud.com');
  const oldToken = tokenFrom(f.sent[0]); f.advance(BILLING_CONTACT_TTL_MS);
  await rejects(f.engine.confirm(f.owner, oldToken), 'contact_token_expired');
  assert.equal((await f.engine.status(f.owner)).verificationStatus, 'expired');
  await f.engine.request(f.owner, 'synthetic@private.icloud.com');
  await rejects(f.engine.confirm(f.owner, oldToken), 'contact_token_invalid');
  await f.engine.confirm(f.owner, tokenFrom(f.sent[1]));
  assert.equal((await f.engine.status(f.owner)).maskedEmail, 'sy***@private.icloud.com');
});

test('the same contact string never joins two Firestore owners or changes their UID binding', async () => {
  const a = fixture(), b = fixture();
  for (const f of [a, b]) {
    await f.engine.request(f.owner, 'shared@example.test'); await f.engine.confirm(f.owner, tokenFrom(f.sent[0]));
  }
  assert.notEqual(a.uid, b.uid);
  assert.notEqual(a.ref.path, b.ref.path);
  assert.equal((await a.engine.requireVerified(a.owner)).email, 'shared@example.test');
  assert.equal((await b.engine.requireVerified(b.owner)).email, 'shared@example.test');
  assert.equal(a.owner.identity.uid, a.uid); assert.equal(b.owner.identity.uid, b.uid);
  assert.equal(a.owner.adminUser.email, undefined); assert.equal(b.owner.adminUser.email, undefined);
  await rejects(b.engine.confirm(b.owner, tokenFrom(a.sent[0])), 'contact_token_invalid');
});

test('the real store rejects malformed UID paths before any Firestore write', async () => {
  for (const uid of ['', '../other', 'a/b', 'synthetic owner', '\ninvalid']) {
    await rejects(store.read(uid), 'unauthenticated');
    await rejects(store.mutate(uid, () => ({state: {}, result: null})), 'unauthenticated');
  }
});

test('existing application Rules keep actual stored email and hashes unreadable to all clients', async () => {
  const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
  const {doc, getDoc, setDoc, setLogLevel} = require('firebase/firestore');
  const environment = await initializeTestEnvironment({projectId,
    firestore: {host: '127.0.0.1', port: 8298,
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  setLogLevel('silent');
  try {
    const f = fixture(); await f.engine.request(f.owner, 'synthetic@example.test');
    assert.equal((await f.ref.get()).exists, true);
    for (const actor of [null, f.uid, 'synthetic-rules-other']) {
      const client = (actor ? environment.authenticatedContext(actor) : environment.unauthenticatedContext()).firestore();
      await assertFails(getDoc(doc(client, f.ref.path)));
      await assertFails(setDoc(doc(client, f.ref.path), {verified: true, email: 'client-claim@example.test'}));
    }
    assert.equal((await f.ref.get()).get('verified'), false);
    assert.equal((await f.ref.get()).get('pending').email, 'synthetic@example.test');
  } finally { await environment.cleanup(); }
});

test.after(async () => {await db.terminate(); await deleteApp(app);});
