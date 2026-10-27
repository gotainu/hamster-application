import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

import { buildDailyHealthFeatures } from './dailyHealthFeatures';
import { fetchHealthSourceData } from './firestoreReaders';
import { buildHealthAssessment } from './healthAssessment';
import { formatDateKey, normalizeDateKey } from './dateKey';
import {
  executeGoldHealthNotificationPipeline,
  executePendingResolvedHealthNotifications,
} from './goldHealthNotification';
import { syncHealthIncidentLifecycle } from './healthIncidentLifecycle';
import { syncPersonalizedAnalysis } from './firstPersonalizedReport';
import {buildCurrentInsightSet, persistCurrentInsightSet} from './weightInsights';
import {checkinFingerprint} from './checkinInsights';

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
  scoreCoverage: number;
  primaryFactor: string | null;
  primaryFactors: string[];
  updatedLatest: boolean;
}

class HealthSourceVersionConflict extends Error {
  constructor() {super('Health source version changed during calculation; retry the rebuild');}
}
type HealthRebuildParameters = {uid: string; dateKey: string; reason: string; db?: FirebaseFirestore.Firestore};

/** A transaction retry alone reuses stale Bronze. Restart the source read when
 * the paired Silver destination changed, with a bounded retry budget. */
export async function rebuildHealthForDate(params: HealthRebuildParameters): Promise<HealthPipelineResult> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {return await rebuildHealthForDateAttempt(params, attempt);}
    catch (error) {if (!(error instanceof HealthSourceVersionConflict) || attempt === 2) throw error;}
  }
  throw new HealthSourceVersionConflict();
}
async function rebuildHealthForDateAttempt(params: HealthRebuildParameters, attempt: number): Promise<HealthPipelineResult> {
  const dateKey = normalizeDateKey(params.dateKey);
  const db = params.db ?? admin.firestore();
  const generatedAt = new Date();
  // Capture the destination version before Bronze reads. Millisecond timestamps
  // alone cannot order two concurrent jobs that started in the same instant.
  const featureVersionBeforeRead = await db.collection('users').doc(params.uid)
    .collection('daily_health_features').doc(dateKey).get();

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

  const insightRef = userRef.collection('individual_insights').doc(dateKey);
  const currentInsights = buildCurrentInsightSet({features: featureResult.features, generatedAt});
  let updatedLatest = false;
  let staleCalculation = false;

  await db.runTransaction(async (transaction) => {
    const [latestSnapshot, insightSnapshot, featureSnapshot] = await Promise.all([
      transaction.get(latestRef), transaction.get(insightRef), transaction.get(featureRef),
    ]);
    // generatedAt is captured before reading Bronze. A delayed older job may
    // not overwrite either Silver or its atomically paired current Insight.
    const generationMillis = (value: any): number | null => {
      const date = typeof value?.toDate === 'function' ? value.toDate() : value;
      const millis = typeof date?.getTime === 'function' ? date.getTime() : null;
      return Number.isFinite(millis) ? millis : null;
    };
    const priorMillis = generationMillis(featureSnapshot.data()?.generatedAt);
    const priorInsightMillis = generationMillis(insightSnapshot.data()?.generatedAt);
    const featureVersionChanged = featureSnapshot.exists !== featureVersionBeforeRead.exists ||
      (!!featureSnapshot.updateTime && !!featureVersionBeforeRead.updateTime &&
        !featureSnapshot.updateTime.isEqual(featureVersionBeforeRead.updateTime));
    if ((priorMillis != null && priorMillis > generatedAt.getTime()) ||
        (priorInsightMillis != null && priorInsightMillis > generatedAt.getTime())) {staleCalculation = true; return;}
    if (featureVersionChanged || attempt > 0) {
      // Exclude generation/write metadata but compare every existing feature,
      // including non-Insight health inputs. Identical fresh data needs no write.
      const inputFields = Object.keys(featureResult.features).filter(key => key !== 'generatedAt');
      const stableFeatureValue = (value: any): any => {
        if (typeof value?.toDate === 'function') return value.toDate().toISOString();
        if (typeof value?.getTime === 'function' && typeof value?.toISOString === 'function') return value.toISOString();
        if (Array.isArray(value)) return value.map(stableFeatureValue);
        if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).map(key => [key, stableFeatureValue(value[key])]));
        return value;
      };
      const featureInputs = (data: Record<string, unknown>) => stableFeatureValue(Object.fromEntries(inputFields.map(key => [key, data[key]])));
      const sameInputs = featureSnapshot.exists && checkinFingerprint(featureInputs(featureSnapshot.data() ?? {})) ===
        checkinFingerprint(featureInputs(featureResult.features as unknown as Record<string, unknown>));
      if (sameInputs) {staleCalculation = true; return;}
      if (featureVersionChanged) throw new HealthSourceVersionConflict();
    }
    await persistCurrentInsightSet({transaction, reference: insightRef, snapshot: insightSnapshot, current: currentInsights});
    const latestData = latestSnapshot.data() ?? {};
    const latestDateKey =
      typeof latestData.dateKey === 'string'
        ? latestData.dateKey
        : null;

    transaction.set(
      featureRef,
      {
        ...featureResult.features,
        source: 'health_pipeline_v7',
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
        source: 'health_pipeline_v7',
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
          source: 'health_pipeline_v7',
          triggerReason: params.reason,
          updatedAt:
            admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      updatedLatest = true;
    }
  });

  try {
    if (!staleCalculation) await syncPersonalizedAnalysis({
      db,
      uid: params.uid,
      dateKey,
      features: featureResult.features,
      now: generatedAt,
    });
  } catch (error: unknown) {
    // Readiness/report persistence is retried by the next idempotent pipeline run.
    logger.error('Personalized analysis state sync failed', {uid: params.uid, dateKey, error: error instanceof Error ? error.message : String(error)});
  }

  if (updatedLatest && dateKey === formatDateKey(generatedAt)) {
    try {
      if (params.reason !== 'manual_rebuild') {
        await syncHealthIncidentLifecycle({
          db,
          uid: params.uid,
          assessment,
          now: generatedAt,
        });
      }

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

      if (
        params.reason !== 'manual_rebuild' &&
        notificationResult.sentCount === 0
      ) {
        const resolvedResult =
          await executePendingResolvedHealthNotifications({
            db,
            messaging: admin.messaging(),
            uid: params.uid,
            triggerReason: params.reason,
            now: generatedAt,
          });
        logger.info('Resolved health notifications processed', {
          uid: params.uid,
          dateKey,
          pendingCount: resolvedResult.pendingCount,
          sentCount: resolvedResult.sentCount,
          failedCount: resolvedResult.failedCount,
          skippedCount: resolvedResult.skippedCount,
        });
      }
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
    primaryFactors: assessment.overall.primaryFactors,
    scoreCoverage: assessment.overall.scoreCoverage,
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
    scoreCoverage: assessment.overall.scoreCoverage,
    primaryFactor: assessment.overall.primaryFactor,
    primaryFactors: assessment.overall.primaryFactors,
    updatedLatest,
  };
}
