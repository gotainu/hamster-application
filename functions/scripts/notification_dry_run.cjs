'use strict';

const fs = require('fs');
const admin = require('firebase-admin');
const {
  healthNotificationDryRunPolicyFromSettings,
  replayHealthNotificationHistory,
} = require('../lib/health/healthNotificationDryRun');

function valueAfter(args, flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : null;
}

async function loadFromFirestore({uid, email, projectId}) {
  if (admin.apps.length === 0) {
    admin.initializeApp(projectId ? {projectId} : undefined);
  }
  const resolvedUid = uid || (await admin.auth().getUserByEmail(email)).uid;
  const db = admin.firestore();
  const userRef = db.collection('users').doc(resolvedUid);
  const [history, settings] = await Promise.all([
    userRef.collection('health_assessments_history')
      .orderBy('dateKey', 'asc')
      .get(),
    userRef.collection('settings').doc('notifications').get(),
  ]);
  return {
    assessments: history.docs.map((doc) => doc.data()),
    settings: settings.data() ?? {},
  };
}

async function main() {
  const args = process.argv.slice(2);
  const inputPath = valueAfter(args, '--input');
  const uid = valueAfter(args, '--uid');
  const email = valueAfter(args, '--email');
  const projectId = valueAfter(args, '--project');

  let source;
  if (inputPath) {
    const parsed = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
    source = Array.isArray(parsed)
      ? {assessments: parsed, settings: {}}
      : parsed;
  } else if (uid || email) {
    source = await loadFromFirestore({uid, email, projectId});
  } else {
    throw new Error(
      'Usage: node scripts/notification_dry_run.cjs --input history.json\n' +
      '   or: node scripts/notification_dry_run.cjs --uid FIREBASE_UID [--project PROJECT_ID]\n' +
      '   or: node scripts/notification_dry_run.cjs --email USER_EMAIL [--project PROJECT_ID]',
    );
  }

  if (!Array.isArray(source.assessments)) {
    throw new Error('The input must contain an assessments array.');
  }
  const policy = healthNotificationDryRunPolicyFromSettings(source.settings);
  const report = replayHealthNotificationHistory(source.assessments, policy);
  process.stdout.write(`${JSON.stringify({policy, report}, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
