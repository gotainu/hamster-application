'use strict';

const admin = require('firebase-admin');
const {
  buildDailyHealthFeatures,
} = require('../lib/health/dailyHealthFeatures');
const {
  fetchHealthSourceData,
} = require('../lib/health/firestoreReaders');
const {
  buildHealthAssessment,
} = require('../lib/health/healthAssessment');
const {
  buildHealthScoreDryRunReport,
} = require('../lib/health/healthScoreDryRun');
const {
  normalizeDateKey,
} = require('../lib/health/dateKey');

function valueAfter(args, flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : null;
}

async function mapWithConcurrency(items, concurrency, worker) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function runWorker() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await worker(items[index], index);
    }
  }

  await Promise.all(
    Array.from(
      {length: Math.min(concurrency, items.length)},
      () => runWorker(),
    ),
  );
  return results;
}

async function main() {
  const args = process.argv.slice(2);
  const uid = valueAfter(args, '--uid');
  const email = valueAfter(args, '--email');
  const projectId = valueAfter(args, '--project');
  const from = valueAfter(args, '--from');
  const to = valueAfter(args, '--to');
  const limitValue = valueAfter(args, '--limit');
  const limit = limitValue ? Number(limitValue) : null;

  if (!uid && !email) {
    throw new Error(
      'Usage: node scripts/health_score_dry_run.cjs --uid FIREBASE_UID [--project PROJECT_ID]\n' +
      '   or: node scripts/health_score_dry_run.cjs --email USER_EMAIL [--project PROJECT_ID]\n' +
      'Optional: --from YYYY-MM-DD --to YYYY-MM-DD --limit COUNT',
    );
  }
  if (limit != null && (!Number.isInteger(limit) || limit <= 0)) {
    throw new Error('--limit must be a positive integer.');
  }

  if (admin.apps.length === 0) {
    admin.initializeApp(projectId ? {projectId} : undefined);
  }

  const resolvedUid = uid || (await admin.auth().getUserByEmail(email)).uid;
  const db = admin.firestore();
  const snapshot = await db
    .collection('users')
    .doc(resolvedUid)
    .collection('health_assessments_history')
    .orderBy('dateKey', 'asc')
    .get();

  let history = snapshot.docs
    .map((document) => ({
      id: document.id,
      data: document.data(),
    }))
    .filter(({id, data}) => {
      const dateKey = normalizeDateKey(
        typeof data.dateKey === 'string' ? data.dateKey : id,
      );
      return (!from || dateKey >= from) && (!to || dateKey <= to);
    });

  if (limit != null) {
    history = history.slice(-limit);
  }
  if (history.length === 0) {
    throw new Error('No historical assessments matched the requested range.');
  }

  const rows = await mapWithConcurrency(
    history,
    4,
    async ({id, data}) => {
      const dateKey = normalizeDateKey(
        typeof data.dateKey === 'string' ? data.dateKey : id,
      );
      const evaluatedAt = new Date(`${dateKey}T03:00:00.000Z`);
      const source = await fetchHealthSourceData({
        db,
        uid: resolvedUid,
        dateKey,
      });
      const featureResult = buildDailyHealthFeatures({
        dateKey,
        source,
        generatedAt: evaluatedAt,
      });
      const candidateAssessment = buildHealthAssessment({
        features: featureResult.features,
        bodyAssessment: featureResult.bodyAssessment,
        evaluatedAt,
      });

      return {
        dateKey,
        previousAssessment: data,
        candidateAssessment,
      };
    },
  );

  const report = buildHealthScoreDryRunReport(rows);
  process.stdout.write(`${JSON.stringify({
    projectId: projectId ?? null,
    generatedAt: new Date().toISOString(),
    dateRange: {
      from: rows[0].dateKey,
      to: rows[rows.length - 1].dateKey,
    },
    readOnly: true,
    report,
  }, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
