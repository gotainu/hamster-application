'use strict';
// Read-only migration preview. It never writes Firestore and refuses the
// production project unless a future operator explicitly opts in.
const admin = require('firebase-admin');
const { buildInitialTrialMigrationDryRun } = require('../lib/trialMigration.js');

const projectId = process.argv.find((arg) => arg.startsWith('--project='))?.split('=')[1];
if (!projectId) throw new Error('Usage: node scripts/initial_trial_migration_dry_run.cjs --project=<emulator-or-project>');
if (projectId === 'hamster-breeding-app' && process.env.ALLOW_PRODUCTION_READ_ONLY_DRY_RUN !== '1') {
  throw new Error('Production dry-run is blocked. Set ALLOW_PRODUCTION_READ_ONLY_DRY_RUN=1 only after separate approval.');
}
admin.initializeApp({projectId});
const db = admin.firestore();
const toDate = (value) => value && typeof value.toDate === 'function' ? value.toDate() : null;
(async () => {
  const users = await db.collection('users').get();
  const counts = {};
  const rows = [];
  for (const user of users.docs) {
    const [billing, legacy] = await Promise.all([
      user.ref.collection('billing').doc('subscription').get(),
      user.ref.collection('feature_access').doc('trial').get(),
    ]);
    const billingData = billing.data() || {};
    const isPaid = billingData.plan === 'paid' && ['active', 'trialing'].includes(billingData.status);
    const row = buildInitialTrialMigrationDryRun({uid: user.id, isPaid, legacyEndsAt: toDate(legacy.data()?.changesTrialEndsAt), now: new Date()});
    counts[row.disposition] = (counts[row.disposition] || 0) + 1;
    rows.push(row);
  }
  console.log(JSON.stringify({generatedAt: new Date().toISOString(), projectId, counts, rows}, null, 2));
})().catch((error) => { console.error(error); process.exitCode = 1; });
