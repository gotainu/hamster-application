import * as admin from 'firebase-admin';
import { AnalysisMetricReadiness, readinessFromBaseline } from './analysisReadiness';
import { DailyHealthFeatures } from './healthTypes';
import {isValidationUid} from '../validationIdentity';

export const PERSONALIZED_ANALYSIS_SPEC_VERSION = 'personal_baseline_v1';

function readiness(features: DailyHealthFeatures): AnalysisMetricReadiness[] {
  return [
    readinessFromBaseline({metric: 'body', baseline: features.body.personalBaseline, analysisSpecVersion: PERSONALIZED_ANALYSIS_SPEC_VERSION}),
    readinessFromBaseline({metric: 'activity', baseline: features.activity.personalBaseline, analysisSpecVersion: PERSONALIZED_ANALYSIS_SPEC_VERSION}),
  ];
}

/**
 * Persists current server readiness independently of the first report. Once
 * generated, the first report remains the snapshot of its initial ready metrics.
 */
export async function syncPersonalizedAnalysis(params: {db: FirebaseFirestore.Firestore; uid: string; dateKey: string; features: DailyHealthFeatures; now: Date}): Promise<void> {
  const user = params.db.collection('users').doc(params.uid);
  const states = readiness(params.features);
  const reportRef = user.collection('personalized_reports').doc('first');
  const trialRef = user.collection('feature_access').doc('initial_trial_v2');
  await params.db.runTransaction(async (tx) => {
    const readinessRefs = states.map((state) =>
      user.collection('analysis_readiness').doc(state.metric),
    );
    const [reportSnap, trialSnap, ...oldReadiness] = await Promise.all([
      tx.get(reportRef),
      tx.get(trialRef),
      ...readinessRefs.map((ref) => tx.get(ref)),
    ]);
    const trialData = trialSnap.data() ?? {};
    const trialFields = {
      trialId: trialData.trialId ?? null,
      policyVersion: trialData.policyVersion ?? null,
      trialEndsAt: trialData.endsAt ?? null,
    };
    for (const [index, state] of states.entries()) {
      const ref = readinessRefs[index];
      const old = oldReadiness[index];
      const oldData = old.data() ?? {};
      const oldStatus = oldData.currentStatus;
      const transition = old.exists && oldStatus !== state.status;
      const firstReady = state.status === 'ready' && !oldData.firstReadyAt;
      const nextSequence = typeof oldData.transitionSequence === 'number' ? oldData.transitionSequence + (transition ? 1 : 0) : 1;
      tx.set(ref, {
        ...state,
        testOnly: isValidationUid(params.uid),
        currentStatus: state.status,
        sourceDateKey: params.dateKey,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(firstReady ? {firstReadyAt: admin.firestore.Timestamp.fromDate(params.now)} : {}),
        ...(transition ? {lastTransitionAt: admin.firestore.Timestamp.fromDate(params.now), transitionSequence: nextSequence} : {transitionSequence: nextSequence}),
      }, {merge: true});
      if (transition || firstReady) {
        const eventId = firstReady
          ? `readiness_${state.metric}_first_ready`
          : `readiness_${state.metric}_transition_${nextSequence}`;
        tx.set(user.collection('analysis_events').doc(eventId), {
          eventName: 'analysis_readiness_changed', eventId,
          testOnly: isValidationUid(params.uid),
          ...trialFields,
          actor: 'server_health_pipeline', source: 'automatic', metric: state.metric,
          previousStatus: oldStatus, currentStatus: state.status, analysisSpecVersion: PERSONALIZED_ANALYSIS_SPEC_VERSION,
          ...(firstReady ? {firstReadyAt: admin.firestore.Timestamp.fromDate(params.now)} : {}),
          occurredAt: admin.firestore.Timestamp.fromDate(params.now),
        });
      }
    }
    // Readiness updates above must continue even when the first report is frozen.
    if (reportSnap.data()?.generation?.status === 'generated') return;
    const ready = states.filter((item) => item.status === 'ready').map((item) => item.metric).sort();
    if (ready.length === 0) return;
    const old = reportSnap.data() ?? {};
    const oldMetrics = Array.isArray(old.readyMetrics) ? old.readyMetrics.slice().sort() : [];
    const metricSetChanged = JSON.stringify(oldMetrics) !== JSON.stringify(ready);
    const specChanged = old.analysisSpecVersion !== PERSONALIZED_ANALYSIS_SPEC_VERSION;
    const revision = typeof old.analysisRevision === 'number' ? old.analysisRevision + (metricSetChanged || specChanged ? 1 : 0) : 1;
    tx.set(reportRef, {
      logicalId: 'first',
      reportKind: 'initial_personalized',
      userId: params.uid,
      testOnly: isValidationUid(params.uid),
      ...trialFields,
      petId: 'main_pet',
      reportId: 'first',
      generation: {status: 'generated', generatedAt: admin.firestore.Timestamp.fromDate(params.now), sourceDateKey: params.dateKey, analysisRevision: revision},
      access: {mode: 'read_only', requiresSubscription: false},
      analysisSpecVersion: PERSONALIZED_ANALYSIS_SPEC_VERSION,
      readyMetrics: ready,
      metricStates: states,
      analysisRevision: revision,
      reportJoinKey: `${params.uid}:main_pet:first:${revision}`,
      ...(old.firstGeneratedAt ? {} : {firstGeneratedAt: admin.firestore.Timestamp.fromDate(params.now)}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    if (!reportSnap.exists || metricSetChanged || specChanged) {
      tx.set(user.collection('analysis_events').doc(`first_report_${revision}`), {
        eventName: 'first_personalized_report_generated', eventId: `first_report_${revision}`,
        testOnly: isValidationUid(params.uid),
        ...trialFields,
        actor: 'server_health_pipeline', source: 'automatic', petId: 'main_pet', reportId: 'first', reportRevision: revision, readyMetrics: ready,
        analysisSpecVersion: PERSONALIZED_ANALYSIS_SPEC_VERSION, occurredAt: admin.firestore.Timestamp.fromDate(params.now),
      });
    }
  });
}
