import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

import {
  addDaysToDateKey,
  formatDateKey,
  normalizeDateKey,
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
}): Promise<{ awarded: boolean; total: number }> {
  const { db, uid, kind, sourceRef } = params;
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
    // `total` は旧形式との互換用。今後の失効では `balance` だけを
    // リセットし、`lifetimeEarned` と達成履歴は保持する。
    const previousTotal = nonNegativeInteger(
      progressData?.balance ?? progressData?.total,
    );
    const previousLifetimeEarned = nonNegativeInteger(
      progressData?.lifetimeEarned ?? progressData?.total,
    );

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

    transaction.create(awardRef, {
      missionDateKey,
      kind,
      sourcePath: sourceRef?.path ?? null,
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
    const wheel = await awardStar({
      db,
      uid,
      missionDateKey,
      kind: 'wheel',
      sourceRef: db.doc(
        `users/${uid}/distance_records/${addDaysToDateKey(missionDateKey, -1)}`,
      ),
    });
    const condition = await awardStar({
      db,
      uid,
      missionDateKey,
      kind: 'condition',
      sourceRef: db.doc(
        `users/${uid}/daily_checkins/${missionDateKey}`,
      ),
    });
    return {
      awarded: open.awarded,
      total: condition.total,
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

export const starDistanceRecordWritten = onDocumentWritten(
  {
    document: 'users/{uid}/distance_records/{sourceDateKey}',
    region: REGION,
  },
  async (event) => {
    if (!event.data?.after.exists) return;
    try {
      const sourceDateKey = normalizeDateKey(event.params.sourceDateKey);
      const missionDateKey = addDaysToDateKey(sourceDateKey, 1);
      if (!isAwardDateEligible(missionDateKey, new Date())) return;
      await awardStar({
        db: admin.firestore(),
        uid: event.params.uid,
        missionDateKey,
        kind: 'wheel',
        sourceRef: event.data.after.ref,
      });
    } catch (error) {
      logger.error('Could not award wheel star', {
        uid: event.params.uid,
        sourceDateKey: event.params.sourceDateKey,
        error,
      });
      throw error;
    }
  },
);

export const starDailyCheckinWritten = onDocumentWritten(
  {
    document: 'users/{uid}/daily_checkins/{sourceDateKey}',
    region: REGION,
  },
  async (event) => {
    if (!event.data?.after.exists) return;
    try {
      const missionDateKey = normalizeDateKey(event.params.sourceDateKey);
      if (!isAwardDateEligible(missionDateKey, new Date())) return;
      await awardStar({
        db: admin.firestore(),
        uid: event.params.uid,
        missionDateKey,
        kind: 'condition',
        sourceRef: event.data.after.ref,
      });
    } catch (error) {
      logger.error('Could not award condition star', {
        uid: event.params.uid,
        sourceDateKey: event.params.sourceDateKey,
        error,
      });
      throw error;
    }
  },
);
