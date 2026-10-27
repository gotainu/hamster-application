import * as admin from 'firebase-admin';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {isValidationUid} from './validationIdentity';

const REGION = 'asia-northeast1';

type RecordKind = 'weight' | 'activity' | 'daily_checkin' | 'switchbot_reading';

function hasMeasurement(kind: RecordKind, data: Record<string, unknown>): boolean {
  if (kind === 'weight') return typeof data.weightGrams === 'number' && Number.isFinite(data.weightGrams) && data.weightGrams > 0;
  if (kind === 'activity') return typeof data.distance === 'number' && Number.isFinite(data.distance) && data.distance >= 0;
  if (kind === 'daily_checkin') return ['normal', 'slightlyConcerned', 'veryConcerned'].includes(String(data.condition));
  return typeof data.temperature === 'number' || typeof data.humidity === 'number';
}

function observationAt(data: Record<string, unknown>, fallbackDateKey: string): string {
  // This is intentionally an observation time/key, not an acceptance time.
  // `serverReceivedAt` below is supplied independently by Firestore.
  if (typeof data.ts === 'string' && data.ts.length > 0) return data.ts;
  if (typeof data.dayKey === 'string' && data.dayKey.length > 0) return data.dayKey;
  return fallbackDateKey;
}

async function recordFirstAcceptedData(params: {
  uid: string;
  kind: RecordKind;
  sourceId: string;
  source: 'manual' | 'sensor';
  data: Record<string, unknown>;
  sourceAcceptedAt?: FirebaseFirestore.Timestamp;
}): Promise<void> {
  if (!hasMeasurement(params.kind, params.data)) return;
  const user = admin.firestore().collection('users').doc(params.uid);
  const event = user.collection('analysis_events').doc(`first_accepted_${params.kind}`);
  const trial = user.collection('feature_access').doc('initial_trial_v2');
  await admin.firestore().runTransaction(async (tx) => {
    const [existing, trialSnap] = await Promise.all([tx.get(event), tx.get(trial)]);
    if (existing.exists) return;
    const trialData = trialSnap.data() ?? {};
    tx.create(event, {
      eventName: 'first_accepted_data_saved',
      eventId: `first_accepted_${params.kind}`,
      trialId: trialData.trialId ?? null,
      policyVersion: trialData.policyVersion ?? null,
      trialEndsAt: trialData.endsAt ?? null,
      testOnly: isValidationUid(params.uid),
      actor: params.source === 'sensor' ? 'switchbot_poll' : 'user_client',
      source: params.source,
      recordType: params.kind,
      rawDocumentId: params.sourceId,
      observationAt: observationAt(params.data, params.sourceId),
      // Keep the accepted record time separate from this retryable trigger's write.
      occurredAt: params.data.acceptedAt ?? params.sourceAcceptedAt ?? null,
      serverReceivedAt: params.data.acceptedAt ?? params.sourceAcceptedAt ?? null,
      measurementVersion: 'accepted_data_v1',
    });
  });
}

export const analyticsWeightRecordCreated = onDocumentCreated(
  {document: 'users/{uid}/weight_records/{sourceId}', region: REGION},
  async (event) => recordFirstAcceptedData({
    uid: event.params.uid, kind: 'weight', sourceId: event.params.sourceId,
    source: 'manual', data: event.data?.data() ?? {}, sourceAcceptedAt: event.data?.createTime,
  }),
);

export const analyticsActivityRecordCreated = onDocumentCreated(
  {document: 'users/{uid}/distance_records/{sourceId}', region: REGION},
  async (event) => recordFirstAcceptedData({
    uid: event.params.uid, kind: 'activity', sourceId: event.params.sourceId,
    source: 'manual', data: event.data?.data() ?? {}, sourceAcceptedAt: event.data?.createTime,
  }),
);

export const analyticsDailyCheckinCreated = onDocumentCreated(
  {document: 'users/{uid}/daily_checkins/{sourceId}', region: REGION},
  async (event) => recordFirstAcceptedData({
    uid: event.params.uid, kind: 'daily_checkin', sourceId: event.params.sourceId,
    source: 'manual', data: event.data?.data() ?? {}, sourceAcceptedAt: event.data?.createTime,
  }),
);

export const analyticsSwitchbotReadingCreated = onDocumentCreated(
  {document: 'users/{uid}/switchbot_readings/{sourceId}', region: REGION},
  async (event) => recordFirstAcceptedData({
    uid: event.params.uid, kind: 'switchbot_reading', sourceId: event.params.sourceId,
    source: 'sensor', data: event.data?.data() ?? {}, sourceAcceptedAt: event.data?.createTime,
  }),
);
