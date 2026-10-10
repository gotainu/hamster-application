import * as admin from 'firebase-admin';
import {formatDateKey, normalizeDateKey} from './dateKey';
import {fetchHealthSourceData} from './firestoreReaders';
import {buildDailyHealthFeatures} from './dailyHealthFeatures';
import {syncPersonalityReport} from './personalityReport';

/** Prepare missing current-day Silver with the exact same source reader and
 * feature builder as healthPipeline. Do not invoke its health assessment,
 * legacy first-report, incident or notification side effects. */
export async function backfillPersonalityReport(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  evaluationDateKey: string;
  now: Date;
  dryRun?: boolean;
}) {
  const today = formatDateKey(params.now);
  if (normalizeDateKey(params.evaluationDateKey) !== today) {
    return {status: 'historical_skipped', silverStatus: 'historical_skipped'};
  }
  const featureRef = params.db.collection('users').doc(params.uid)
    .collection('daily_health_features').doc(today);
  let silverStatus = 'existing';
  if (!(await featureRef.get()).exists) {
    // Never use historical Silver or readiness as a substitute for today's
    // inputs. Existing baseline/window/quality calculations remain unchanged.
    const source = await fetchHealthSourceData({db: params.db, uid: params.uid, dateKey: today});
    const {features} = buildDailyHealthFeatures({dateKey: today, source, generatedAt: params.now});
    if (params.dryRun) {
      return {
        ...await syncPersonalityReport({...params, previewFeatures: features}),
        silverStatus: 'would_create',
      };
    }
    silverStatus = await params.db.runTransaction(async tx => {
      // A concurrent pipeline or backfill wins safely. Never overwrite its
      // committed current-day Silver with a calculation made before this read.
      if ((await tx.get(featureRef)).exists) return 'existing';
      tx.create(featureRef, {
        ...features,
        source: 'health_pipeline_v7',
        triggerReason: 'personality_backfill',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return 'created';
    });
  }
  // Read the committed winner in the publisher's transaction; retries and the
  // Silver trigger use the same deterministic report and pointer contract.
  return {...await syncPersonalityReport(params), silverStatus};
}
