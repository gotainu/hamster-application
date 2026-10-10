import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  calculateInitialTrialEndsAt,
  initialTrialPolicy,
  isInitialTrialActive,
} from './trialPolicy';
import {isValidationUid} from './validationIdentity';

const region = 'asia-northeast1';
export const aiTrialLimit = 3;
export const changesTrialDays = 5;

function accessRef(uid: string) {
  return admin.firestore()
    .collection('users')
    .doc(uid)
    .collection('feature_access')
    .doc('trial');
}

function initialAccessRef(uid: string) {
  return admin.firestore().collection('users').doc(uid).collection('feature_access').doc('initial_trial_v2');
}

function billingRef(uid: string) {
  return admin.firestore().collection('users').doc(uid).collection('billing').doc('subscription');
}

function toDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function isPaid(data: FirebaseFirestore.DocumentData | undefined, now: Date): boolean {
  if (!data || data.plan !== 'paid' || !['active', 'trialing'].includes(data.status)) return false;
  const end = toDate(data.currentPeriodEnd);
  return end == null || now.getTime() < end.getTime();
}

export type FeatureAccessSource = 'paid' | 'initial_trial' | 'none';
export async function getFeatureAccess(uid: string, now = new Date()): Promise<{allowed: boolean; source: FeatureAccessSource}> {
  const [billing, trial] = await Promise.all([billingRef(uid).get(), initialAccessRef(uid).get()]);
  if (isPaid(billing.data(), now)) return {allowed: true, source: 'paid'};
  const data = trial.data() ?? {};
  const active = isInitialTrialActive({status: data.status, endsAt: toDate(data.endsAt), now});
  return {allowed: active, source: active ? 'initial_trial' : 'none'};
}

export const activateFeatureTrial = onCall({region}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const ref = accessRef(uid);
  await admin.firestore().runTransaction(async (transaction) => {
    const current = await transaction.get(ref);
    if (current.exists) return;
    const now = admin.firestore.Timestamp.now();
    transaction.set(ref, {
      version: 1,
      activatedAt: now,
      changesTrialEndsAt: admin.firestore.Timestamp.fromMillis(
        now.toMillis() + changesTrialDays * 24 * 60 * 60 * 1000,
      ),
      aiTrialLimit,
      aiTrialUsed: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  const snap = await ref.get();
  return snap.data();
});

// RAG APIをプロキシ化するまでの移行用のサーバー権限。クライアントは応答成功後に
// この呼び出しで確定するため、料金判定を端末ローカルに置かない。
export const consumeAiTrial = onCall({region}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const ref = accessRef(uid);
  const result = await admin.firestore().runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) throw new HttpsError('failed-precondition', '無料体験を開始してください。');
    const data = snap.data() ?? {};
    const used = typeof data.aiTrialUsed === 'number' ? data.aiTrialUsed : 0;
    const limit = typeof data.aiTrialLimit === 'number' ? data.aiTrialLimit : aiTrialLimit;
    if (used >= limit) throw new HttpsError('resource-exhausted', 'AI無料体験は3回までです。');
    const nextUsed = used + 1;
    transaction.update(ref, {
      aiTrialUsed: nextUsed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {aiTrialUsed: nextUsed, aiTrialLimit: limit};
  });
  return result;
});

/** Starts one immutable, policy-versioned 21-day trial. Paid status never rewrites trial history. */
export const startInitialTrial = onCall({region}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const validationUids = (process.env.TRIAL_TEST_UIDS ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (validationUids.length > 0 && !validationUids.includes(uid)) {
    throw new HttpsError('permission-denied', '現在は許可されたテストアカウントのみ無料体験を開始できます。');
  }
  const ref = initialAccessRef(uid);
  const testOnly = isValidationUid(uid);
  return admin.firestore().runTransaction(async (transaction) => {
    const [existing, billing] = await Promise.all([transaction.get(ref), transaction.get(billingRef(uid))]);
    const now = new Date();
    if (isPaid(billing.data(), now)) return {accessSource: 'paid', started: false};
    if (existing.exists) {
      const data = existing.data() ?? {};
      return {
        accessSource: isInitialTrialActive({status: data.status, endsAt: toDate(data.endsAt), now}) ? 'initial_trial' : 'none',
        started: false,
        ...data,
      };
    }
    // A trial that cannot make even one AI request is not a valid user-facing
    // trial. Do not start its 21-day clock until finite limits are approved.
    if (
      initialTrialPolicy.aiRequestLimit <= 0 ||
      initialTrialPolicy.aiCostMicrosLimit <= 0
    ) {
      throw new HttpsError(
        'failed-precondition',
        '無料体験は利用上限の設定完了後に開始できます。',
      );
    }
    const startedAt = admin.firestore.Timestamp.fromDate(now);
    const endsAt = admin.firestore.Timestamp.fromDate(calculateInitialTrialEndsAt({startedAt: now}));
    transaction.create(ref, {
      trialId: 'initial_trial_v2',
      policyVersion: initialTrialPolicy.policyVersion,
      status: 'active',
      startedAt,
      endsAt,
      durationDays: initialTrialPolicy.durationDays,
      aiRequestLimit: initialTrialPolicy.aiRequestLimit,
      aiRequestUsed: 0,
      aiReservationCostMicros: initialTrialPolicy.aiReservationCostMicros,
      aiCostMicrosLimit: initialTrialPolicy.aiCostMicrosLimit,
      aiCostMicrosUsed: 0,
      testOnly,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.create(
      admin.firestore().collection('users').doc(uid).collection('journey_events').doc('initial_trial_started'),
      {
        eventName: 'initial_trial_started',
        eventId: 'initial_trial_started',
        trialId: 'initial_trial_v2',
        actor: 'server',
        policyVersion: initialTrialPolicy.policyVersion,
        testOnly,
        startedAt,
        endsAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    );
    return {accessSource: 'initial_trial', started: true, policyVersion: initialTrialPolicy.policyVersion, startedAt, endsAt, aiRequestLimit: initialTrialPolicy.aiRequestLimit, aiReservationCostMicros: initialTrialPolicy.aiReservationCostMicros, testOnly};
  });
});

/** A deterministic requestId makes a retry consume at most one AI unit. */
export const consumeInitialTrialAi = onCall({region}, async (req) => {
  const uid = req.auth?.uid;
  const requestId = typeof req.data?.requestId === 'string' ? req.data.requestId : '';
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  if (!/^[A-Za-z0-9_-]{12,128}$/.test(requestId)) throw new HttpsError('invalid-argument', 'requestId が不正です。');
  const trialRef = initialAccessRef(uid);
  const usageRef = trialRef.collection('ai_usage').doc(requestId);
  return admin.firestore().runTransaction(async (transaction) => {
    const [billing, trial, usage] = await Promise.all([transaction.get(billingRef(uid)), transaction.get(trialRef), transaction.get(usageRef)]);
    if (isPaid(billing.data(), new Date())) return {authorized: true, source: 'paid', consumed: false};
    if (usage.exists) return {authorized: true, source: 'initial_trial', consumed: true, idempotent: true};
    const data = trial.data() ?? {};
    if (!isInitialTrialActive({status: data.status, endsAt: toDate(data.endsAt), now: new Date()})) throw new HttpsError('permission-denied', '無料体験の利用期間が終了しています。');
    const limit = typeof data.aiRequestLimit === 'number' ? data.aiRequestLimit : 0;
    const used = typeof data.aiRequestUsed === 'number' ? data.aiRequestUsed : 0;
    // 0 is the intentional safe pre-approval configuration, never unlimited access.
    if (limit <= 0) throw new HttpsError('failed-precondition', 'AI無料利用上限は設定中です。');
    if (used >= limit) throw new HttpsError('resource-exhausted', 'AI無料利用の上限に達しました。');
    transaction.create(usageRef, {requestId, actor: 'user', status: 'consumed', testOnly: isValidationUid(uid), consumedAt: admin.firestore.FieldValue.serverTimestamp()});
    transaction.update(trialRef, {aiRequestUsed: used + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    return {authorized: true, source: 'initial_trial', consumed: true, aiRequestUsed: used + 1, aiRequestLimit: limit};
  });
});
