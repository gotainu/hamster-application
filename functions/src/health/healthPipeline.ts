import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

import { buildDailyHealthFeatures } from './dailyHealthFeatures';
import { fetchHealthSourceData } from './firestoreReaders';
import { buildHealthAssessment } from './healthAssessment';
import { formatDateKey, normalizeDateKey } from './dateKey';
import { executeGoldHealthNotificationPipeline } from './goldHealthNotification';

export interface HealthPipelineResult {
  uid: string;
  dateKey: string;
  overallState: string;
  overallScore: number | null;
  observedState: string;
  observedScore: number | null;
  confidence: string;
  isProvisional: boolean;
  featureCompleteness: number;
  primaryFactor: string | null;
  updatedLatest: boolean;
}

export async function rebuildHealthForDate(params: {
  uid: string;
  dateKey: string;
  reason: string;
  db?: FirebaseFirestore.Firestore;
}): Promise<HealthPipelineResult> {
  const dateKey = normalizeDateKey(params.dateKey);
  const db = params.db ?? admin.firestore();
  const generatedAt = new Date();

  const source = await fetchHealthSourceData({
    db,
    uid: params.uid,
    dateKey,
  });

  const featureResult = buildDailyHealthFeatures({
    dateKey,
    source,
    generatedAt,
  });

  const assessment = buildHealthAssessment({
    features: featureResult.features,
    bodyAssessment: featureResult.bodyAssessment,
    evaluatedAt: generatedAt,
  });

  const userRef = db.collection('users').doc(params.uid);
  const featureRef = userRef
    .collection('daily_health_features')
    .doc(dateKey);
  const historyRef = userRef
    .collection('health_assessments_history')
    .doc(dateKey);
  const latestRef = userRef
    .collection('health_assessments')
    .doc('latest');

  let updatedLatest = false;

  await db.runTransaction(async (transaction) => {
    const latestSnapshot = await transaction.get(latestRef);
    const latestData = latestSnapshot.data() ?? {};
    const latestDateKey =
      typeof latestData.dateKey === 'string'
        ? latestData.dateKey
        : null;

    transaction.set(
      featureRef,
      {
        ...featureResult.features,
        source: 'health_pipeline_v4',
        triggerReason: params.reason,
        updatedAt:
          admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    transaction.set(
      historyRef,
      {
        ...assessment,
        source: 'health_pipeline_v4',
        triggerReason: params.reason,
        updatedAt:
          admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    if (!latestDateKey || dateKey >= latestDateKey) {
      transaction.set(
        latestRef,
        {
          ...assessment,
          source: 'health_pipeline_v4',
          triggerReason: params.reason,
          updatedAt:
            admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      updatedLatest = true;
    }
  });

  if (updatedLatest && dateKey === formatDateKey(generatedAt)) {
    try {
      const notificationResult =
        await executeGoldHealthNotificationPipeline({
          db,
          messaging: admin.messaging(),
          uid: params.uid,
          assessment,
          triggerReason: params.reason,
          now: generatedAt,
        });

      logger.info('Gold health notification pipeline completed', {
        uid: params.uid,
        dateKey,
        triggerReason: params.reason,
        reason: notificationResult.reason,
        notificationKey: notificationResult.notificationKey,
        tokenCount: notificationResult.tokenCount,
        sentCount: notificationResult.sentCount,
        failedCount: notificationResult.failedCount,
        noTokens: notificationResult.noTokens,
      });
    } catch (error: unknown) {
      logger.error('Gold health notification pipeline failed', {
        uid: params.uid,
        dateKey,
        triggerReason: params.reason,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      });
    }
  }

  logger.info('Health architecture rebuilt', {
    uid: params.uid,
    dateKey,
    reason: params.reason,
    overallState: assessment.overall.state,
    overallScore: assessment.overall.score,
    observedState: assessment.overall.observedState,
    observedScore: assessment.overall.observedScore,
    confidence: assessment.overall.confidence,
    isProvisional: assessment.overall.isProvisional,
    primaryFactor: assessment.overall.primaryFactor,
    completeness:
      featureResult.features.dataQuality.completeness,
    updatedLatest,
  });

  return {
    uid: params.uid,
    dateKey,
    overallState: assessment.overall.state,
    overallScore: assessment.overall.score,
    observedState: assessment.overall.observedState,
    observedScore: assessment.overall.observedScore,
    confidence: assessment.overall.confidence,
    isProvisional: assessment.overall.isProvisional,
    featureCompleteness:
      featureResult.features.dataQuality.completeness,
    primaryFactor: assessment.overall.primaryFactor,
    updatedLatest,
  };
}
