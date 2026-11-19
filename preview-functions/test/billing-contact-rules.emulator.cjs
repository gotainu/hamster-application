const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {randomUUID} = require('node:crypto');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, setLogLevel} = require('firebase/firestore');

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8298') {
  throw new Error('Dedicated local billing contact Rules Emulator required');
}
const projectId = 'demo-hamcare-billing-contact-rules';
const syntheticStatus = () => ({
  testMode: true, state: 'pending', category: 'missing',
  maskedEmail: null, pendingMaskedEmail: 'sy***@example.test',
  canCheckout: false, source: null, deliveryState: 'sent',
  resendAfter: '2026-11-19T00:01:00.000Z', expiresAt: '2026-11-19T00:15:00.000Z',
});

test('Preview contact Rules allow only an owner to get the sanitized projection', async () => {
  const environment = await initializeTestEnvironment({projectId,
    firestore: {host: '127.0.0.1', port: 8298,
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.contact-preview.rules'), 'utf8')}});
  setLogLevel('silent');
  try {
    const owner = 'synthetic-owner-' + randomUUID();
    const other = 'synthetic-other-' + randomUUID();
    const root = 'preview_billing_contacts/' + owner;
    const status = root + '/status/current';
    const raw = {email: 'synthetic@example.test', pending: {tokenHash: 'synthetic-hash'}, verified: false};
    await environment.withSecurityRulesDisabled(async context => {
      const admin = context.firestore();
      await setDoc(doc(admin, root), raw);
      await setDoc(doc(admin, status), syntheticStatus());
      await setDoc(doc(admin, root + '/tokens/synthetic-token'), {tokenHash: 'synthetic-hash'});
    });
    const ownDb = environment.authenticatedContext(owner).firestore();
    const ownStatus = await assertSucceeds(getDoc(doc(ownDb, status)));
    assert.deepEqual(ownStatus.data(), syntheticStatus());
    assert.doesNotMatch(JSON.stringify(ownStatus.data()), /tokenHash|synthetic-hash|synthetic-owner|synthetic@example/);
    for (const actor of [null, owner, other]) {
      const client = (actor ? environment.authenticatedContext(actor) : environment.unauthenticatedContext()).firestore();
      // An owner cannot read raw contact/email/token state or list any namespace.
      for (const rawPath of [root, root + '/tokens/synthetic-token']) {
        await assertFails(getDoc(doc(client, rawPath)));
      }
      if (actor !== owner) await assertFails(getDoc(doc(client, status)));
      for (const listPath of ['preview_billing_contacts', root + '/status', root + '/tokens']) {
        await assertFails(getDocs(collection(client, listPath)));
      }
      for (const target of [root, status, root + '/tokens/synthetic-token']) {
        await assertFails(setDoc(doc(client, target), syntheticStatus()));
        await assertFails(updateDoc(doc(client, target), {verified: true}));
        await assertFails(deleteDoc(doc(client, target)));
      }
      await assertFails(setDoc(doc(client, root + '/status/new'), syntheticStatus()));
    }
  } finally { await environment.cleanup(); }
});

test('a mistaken server projection cannot expose full emails, secrets or extra fields', async () => {
  const environment = await initializeTestEnvironment({projectId,
    firestore: {host: '127.0.0.1', port: 8298,
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.contact-preview.rules'), 'utf8')}});
  setLogLevel('silent');
  try {
    const owner = 'synthetic-owner-' + randomUUID();
    const target = 'preview_billing_contacts/' + owner + '/status/current';
    const client = environment.authenticatedContext(owner).firestore();
    const mutations = [
      {email: 'synthetic@example.test'}, {tokenHash: 'synthetic-hash'}, {uid: owner},
      {appleSubject: 'synthetic-provider-subject'}, {maskedEmail: 'synthetic@example.test'},
      {pendingMaskedEmail: 'synthetic@private.icloud.com'}, {state: 'synthetic-secret'},
      {source: 'synthetic-secret'}, {deliveryState: 'synthetic-secret'}, {canCheckout: 'true'}, {testMode: false},
    ];
    for (const mutation of mutations) {
      await environment.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), target), {...syntheticStatus(), ...mutation}));
      await assertFails(getDoc(doc(client, target)));
    }
    // Both relay domains remain valid display values, not evidence of identity.
    for (const domain of ['privaterelay.appleid.com', 'private.icloud.com']) {
      await environment.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), target), {
        ...syntheticStatus(), pendingMaskedEmail: 'sy***@' + domain,
      }));
      await assertSucceeds(getDoc(doc(client, target)));
    }
  } finally { await environment.cleanup(); }
});

test('currently deployed application Rules remain fail closed for all contact namespace reads and writes', async () => {
  const environment = await initializeTestEnvironment({projectId,
    firestore: {host: '127.0.0.1', port: 8298,
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  setLogLevel('silent');
  try {
    const owner = 'synthetic-existing-rules-' + randomUUID();
    const root = 'preview_billing_contacts/' + owner;
    const status = root + '/status/current';
    await environment.withSecurityRulesDisabled(async context => {
      await setDoc(doc(context.firestore(), root), {email: 'synthetic@example.test', tokenHash: 'synthetic-hash'});
      await setDoc(doc(context.firestore(), status), syntheticStatus());
    });
    for (const actor of [null, owner, 'synthetic-other']) {
      const client = (actor ? environment.authenticatedContext(actor) : environment.unauthenticatedContext()).firestore();
      for (const target of [root, status]) {
        await assertFails(getDoc(doc(client, target)));
        await assertFails(setDoc(doc(client, target), {verified: true}));
      }
    }
  } finally { await environment.cleanup(); }
});
