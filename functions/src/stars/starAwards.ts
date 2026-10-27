import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import {reconcileContinuity, trustedDate, isValidManualContinuityRecord} from './continuity';

import {
  addDaysToDateKey,
  formatDateKey,
  normalizeDateKey,
  isDateKey,
} from '../health/dateKey';

const REGION = 'asia-northeast1';
const FIRST_MILESTONE = 50;
// 初回の星プログラムは、過去の記録を遡って加算しない。
export const STAR_PROGRAM_START_DATE = '2026-09-17';

export type StarAwardKind = 'open_app' | 'wheel' | 'condition';

export function starAwardId(
  missionDateKey: string,
  kind: StarAwardKind,
): string {
  return `${normalizeDateKey(missionDateKey)}_${kind}`;
}

export function isAwardDateEligible(
  missionDateKey: string,
  now: Date,
): boolean {
  const today = formatDateKey(now);
  const yesterday = addDaysToDateKey(today, -1);
  return missionDateKey === today || missionDateKey === yesterday;
}

export function crossedStarMilestone(
  previousTotal: number,
  nextTotal: number,
): boolean {
  return previousTotal < FIRST_MILESTONE &&
    nextTotal >= FIRST_MILESTONE;
}

export function isStarProgramDate(missionDateKey: string): boolean {
  return normalizeDateKey(missionDateKey) >= STAR_PROGRAM_START_DATE;
}

function nonNegativeInteger(value: unknown): number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0
    ? value
    : 0;
}

export async function awardStar(params: {
  db: admin.firestore.Firestore;
  uid: string;
  missionDateKey: string;
  kind: StarAwardKind;
  sourceRef?: admin.firestore.DocumentReference;
  acceptedAt?: Date;
  now?: Date;
}): Promise<{ awarded: boolean; total: number }> {
  const { db, uid, kind, sourceRef } = params;
  const now = params.now ?? new Date();
  const acceptedAt = params.acceptedAt ?? now;
  const acceptedDateKey = formatDateKey(acceptedAt);
  const conditionDayRef = db.doc(`users/${uid}/condition_award_days/${acceptedDateKey}`);
  const missionDateKey = normalizeDateKey(params.missionDateKey);
  const awardRef = db.doc(
    `users/${uid}/star_awards/${starAwardId(missionDateKey, kind)}`,
  );
  const progressRef = db.doc(`users/${uid}/rewards/stars`);
  const milestoneRef = db.doc(
    `users/${uid}/star_milestones/${FIRST_MILESTONE}`,
  );

  return db.runTransaction(async (transaction) => {
    const awardSnap = await transaction.get(awardRef);
    const progressSnap = await transaction.get(progressRef);
    const sourceSnap = sourceRef
      ? await transaction.get(sourceRef)
      : null;
    const progressData = progressSnap.data();
    // These are permanent rewards. Continuity expiry only clears its separate
    // period mirror; balance/total/lifetimeEarned and historical awards survive.
    const previousTotal = nonNegativeInteger(
      progressData?.balance ?? progressData?.total,
    );
    const previousLifetimeEarned = nonNegativeInteger(
      progressData?.lifetimeEarned ?? progressData?.total,
    );

    const conditionGuard = kind === 'condition' ? await transaction.get(conditionDayRef) : null;
    // Bounded old-ledger check prevents a current rollout from issuing another
    // condition reward for the same server receipt day; no history migration.
    const boundedLegacy = kind === 'condition' && !conditionGuard?.exists
      ? await Promise.all([acceptedDateKey, addDaysToDateKey(acceptedDateKey, -1)].map(day =>
        transaction.get(db.doc(`users/${uid}/star_awards/${starAwardId(day, 'condition')}`)))) : [];
    const legacyAccepted = boundedLegacy.find(snap => snap.exists &&
      (typeof snap.get('acceptedDateKey') === 'string'
        ? snap.get('acceptedDateKey') === acceptedDateKey
        : trustedDate(snap.get('awardedAt')) != null && formatDateKey(trustedDate(snap.get('awardedAt'))!) === acceptedDateKey));
    if (kind === 'condition' && (conditionGuard?.exists || legacyAccepted)) {
      if (!conditionGuard?.exists && legacyAccepted) transaction.create(conditionDayRef, {
        schemaVersion: 1, acceptedDateKey, awardPath: legacyAccepted.ref.path,
        policyVersion: 'condition_receipt_day_v1', recordedAt: admin.firestore.FieldValue.serverTimestamp()});
      return {awarded: false, total: previousTotal};
    }

    if (!isStarProgramDate(missionDateKey) ||
        awardSnap.exists ||
        (sourceSnap != null && !sourceSnap.exists)) {
      return { awarded: false, total: previousTotal };
    }

    const nextTotal = previousTotal + 1;
    const nextLifetimeEarned = previousLifetimeEarned + 1;
    const milestoneSnap = crossedStarMilestone(
      previousLifetimeEarned,
      nextLifetimeEarned,
    )
      ? await transaction.get(milestoneRef)
      : null;

    if (kind === 'condition') transaction.create(conditionDayRef, {
      schemaVersion: 1, acceptedDateKey, awardPath: awardRef.path,
      policyVersion: 'condition_receipt_day_v1', recordedAt: admin.firestore.FieldValue.serverTimestamp()});
    transaction.create(awardRef, {
      missionDateKey,
      kind,
      sourcePath: sourceRef?.path ?? null,
      acceptedDateKey,
      awardedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.set(progressRef, {
      // `total` は現在の表示との互換を保つため残す。
      total: nextTotal,
      balance: nextTotal,
      lifetimeEarned: nextLifetimeEarned,
      programStartedOn: STAR_PROGRAM_START_DATE,
      lastAwardDateKey: missionDateKey,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    if (milestoneSnap != null && !milestoneSnap.exists) {
      transaction.create(milestoneRef, {
        milestone: FIRST_MILESTONE,
        lifetimeEarnedAtUnlock: nextLifetimeEarned,
        unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { awarded: true, total: nextTotal };
  });
}

export const claimDailyOpenStar = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'ログインが必要です。');
    }
    const missionDateKey = formatDateKey(new Date());
    const db = admin.firestore();
    const open = await awardStar({
      db,
      uid,
      missionDateKey,
      kind: 'open_app',
    });
    const wheelRef = db.doc(`users/${uid}/distance_records/${addDaysToDateKey(missionDateKey, -1)}`);
    const conditionRef = db.doc(`users/${uid}/daily_checkins/${missionDateKey}`);
    const wheelSnap = await wheelRef.get();
    const conditionSnap = await conditionRef.get();
    const wheel = await processStarRecord({db, uid, kind: 'wheel', sourceDateKey: addDaysToDateKey(missionDateKey, -1), snapshot: wheelSnap, reconciliationOnly: true});
    const condition = await processStarRecord({db, uid, kind: 'condition', sourceDateKey: missionDateKey, snapshot: conditionSnap, reconciliationOnly: true});
    await reconcileContinuity({db, uid});
    const currentProgress = (await db.doc(`users/${uid}/rewards/stars`).get()).data();
    return {
      awarded: open.awarded,
      total: nonNegativeInteger(currentProgress?.balance ?? currentProgress?.total),
      reconciledWheel: wheel.awarded,
      reconciledCondition: condition.awarded,
    };
  },
);

export const acknowledgeFiftyStarMilestone = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'ログインが必要です。');
    }
    const milestoneRef = admin.firestore().doc(
      `users/${uid}/star_milestones/${FIRST_MILESTONE}`,
    );
    return admin.firestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(milestoneRef);
      if (!snapshot.exists) {
        throw new HttpsError('failed-precondition', '達成記録がありません。');
      }
      if (snapshot.data()?.seenAt != null) {
        return { acknowledged: false };
      }
      transaction.update(milestoneRef, {
        seenAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { acknowledged: true };
    });
  },
);

/** Shared retry path: source existence alone is never today's achievement. */
export async function processStarRecord(params: {
  db: admin.firestore.Firestore; uid: string; kind: 'wheel' | 'condition';
  sourceDateKey: string; snapshot: admin.firestore.DocumentSnapshot; now?: Date; reconciliationOnly?: boolean;
}): Promise<{awarded: boolean; total: number}> {
  const {db, uid, kind, snapshot} = params; const now = params.now ?? new Date();
  // Invalid immutable event IDs cannot succeed on retry; ignore them.
  if (!isDateKey(params.sourceDateKey)) return {awarded: false, total: 0};
  const sourceDateKey = normalizeDateKey(params.sourceDateKey);
  if (!snapshot.exists) return {awarded: false, total: 0};
  // A server-owned cancellation can restore an earlier daily projection. It is
  // still a cancellation, never a newly accepted achievement on its update day.
  const record = snapshot.data();
  if (kind === 'condition' && record?.observationHistorySchemaVersion === 1 &&
      record.projectionMutationOperation === 'cancel') return {awarded: false, total: 0};
  const missionDateKey = kind === 'wheel' ? addDaysToDateKey(sourceDateKey, 1) : sourceDateKey;
  const acceptedAt = trustedDate(snapshot.updateTime);
  const valid = isValidManualContinuityRecord(kind, snapshot.data());
  const validObservedDay = acceptedAt == null || sourceDateKey <= formatDateKey(acceptedAt);
  const eligible = validObservedDay && isAwardDateEligible(missionDateKey, kind === 'condition' && acceptedAt ? acceptedAt : now) && (kind !== 'condition' || valid);
  const result = eligible ? await awardStar({db, uid, kind, missionDateKey, sourceRef: snapshot.ref,
    ...(acceptedAt ? {acceptedAt} : {}), now}) : {awarded: false, total: 0};
  if (acceptedAt && valid && sourceDateKey <= formatDateKey(acceptedAt) &&
      (!params.reconciliationOnly || formatDateKey(acceptedAt) === formatDateKey(now))) {
    const guard = kind === 'condition' ? await db.doc(`users/${uid}/condition_award_days/${formatDateKey(acceptedAt)}`).get() : null;
    const guardPath = guard?.get('awardPath');
    const mirrorRef = typeof guardPath === 'string' && guardPath.startsWith(`users/${uid}/star_awards/`) ? db.doc(guardPath) : db.doc(`users/${uid}/star_awards/${starAwardId(missionDateKey, kind)}`);
    const continuity = await reconcileContinuity({db, uid, now, awardRef: mirrorRef,
      evidence: {sourceKind: kind, sourceDateKey, sourcePath: snapshot.ref.path, acceptedAt}});
    if (continuity.confirmationPending) throw new Error('Trusted receipt reconciliation is pending; retry record event.');
  }
  return result;
}

export const starDistanceRecordWritten = onDocumentWritten(
  {document: 'users/{uid}/distance_records/{sourceDateKey}', region: REGION, retry: true}, async event => {
    if (!event.data?.after.exists) return;
    try {await processStarRecord({db: admin.firestore(), uid: event.params.uid, kind: 'wheel',
      sourceDateKey: event.params.sourceDateKey, snapshot: event.data.after});}
    catch (error) {logger.error('Could not award wheel star', {sourceDateKey: event.params.sourceDateKey, error}); throw error;}
  });
export const starDailyCheckinWritten = onDocumentWritten(
  {document: 'users/{uid}/daily_checkins/{sourceDateKey}', region: REGION, retry: true}, async event => {
    if (!event.data?.after.exists) return;
    try {await processStarRecord({db: admin.firestore(), uid: event.params.uid, kind: 'condition',
      sourceDateKey: event.params.sourceDateKey, snapshot: event.data.after});}
    catch (error) {logger.error('Could not award condition star', {sourceDateKey: event.params.sourceDateKey, error}); throw error;}
  });
