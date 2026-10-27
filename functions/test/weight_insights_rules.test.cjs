'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const {before, after, test} = require('node:test');
const sdk = process.env.HAMCARE_RULES_TEST_DEPENDENCY_PACKAGE ? createRequire(process.env.HAMCARE_RULES_TEST_DEPENDENCY_PACKAGE) : require;
const {initializeTestEnvironment, assertFails, assertSucceeds} = sdk('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc} = sdk('firebase/firestore');
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/);
const port = Number(process.env.FIRESTORE_EMULATOR_HOST.split(':')[1]);
assert.notEqual(port, 8080);
let env;
const owners = ['paid', 'trial', 'expired', 'unpaid'];
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-hamcare-weight-insight-rules', firestore:{host:'127.0.0.1', port, rules:fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    for (const uid of owners) {
      await setDoc(doc(context.firestore(), `users/${uid}/individual_insights/2026-10-11`), {kind:'current', evaluationDateKey:'2026-10-11', insights:[]});
      await setDoc(doc(context.firestore(), `users/${uid}/individual_insights/2026-10-11/private/detail`), {serverOnly:true});
    }
  });
});
after(async () => {if (env) await env.cleanup();});
const client = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
for (const uid of owners) {
  test(`${uid} can get own current Insight without granting discovery/listing`, async () => {
    await assertSucceeds(getDoc(doc(client(uid), `users/${uid}/individual_insights/2026-10-11`)));
    await assertFails(getDocs(collection(client(uid), `users/${uid}/individual_insights`)));
    await assertFails(getDoc(doc(client(uid), `users/${uid}/individual_insights/2026-10-11/private/detail`)));
  });
  for (const actor of [uid, 'other', null]) {
    test(`${actor ?? 'guest'} cannot create, update, delete ${uid}'s Insight`, async () => {
      const db = client(actor);
      await assertFails(setDoc(doc(db, `users/${uid}/individual_insights/2026-10-12`), {insights:[]}));
      await assertFails(updateDoc(doc(db, `users/${uid}/individual_insights/2026-10-11`), {insights:[]}));
      await assertFails(deleteDoc(doc(db, `users/${uid}/individual_insights/2026-10-11`)));
    });
  }
  for (const actor of ['other', null]) {
    test(`${actor ?? 'guest'} cannot read ${uid}'s current Insights`, async () => {
      await assertFails(getDoc(doc(client(actor), `users/${uid}/individual_insights/2026-10-11`)));
      await assertFails(getDocs(collection(client(actor), `users/${uid}/individual_insights`)));
    });
  }
}
