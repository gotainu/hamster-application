import * as admin from 'firebase-admin';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {addDaysToDateKey, formatDateKey, isDateKey} from '../health/dateKey';

export const CONTINUITY_POLICY_VERSION = 'continuity_v1';
export type ContinuitySourceKind = 'condition' | 'wheel' | 'weight' | 'care';
export interface ContinuityEvidence {
  sourceKind: ContinuitySourceKind; sourceDateKey: string; sourcePath: string; acceptedAt: Date;
}
export interface ContinuityState {
  schemaVersion: 1; policyVersion: string; status: 'empty' | 'active' | 'expired';
  periodId: string | null; periodStartedOn: string | null; periodEarned: number;
  lastAchievementDateKey: string | null; expiresAt: Date | null; lifetimeAchievementDays: number;
}
export interface ContinuityView {
  schemaVersion: 1; policyVersion: string; serverDateKey: string;
  phase: 'empty' | 'active' | 'grace' | 'expired'; todayAchieved: boolean;
  periodId: string | null; periodStartedOn: string | null; periodEarned: number;
  lastAchievementDateKey: string | null; expiresAt: string | null; lifetimeAchievementDays: number;
  achievementRecorded?: boolean; mirroredAwardCount?: number; confirmationPending?: boolean;
}
function count(value: unknown): number {return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : 0;}
export function trustedDate(value: unknown): Date | null {
  const date = value instanceof Date ? value : value && typeof (value as {toDate?: unknown}).toDate === 'function'
    ? (value as {toDate(): Date}).toDate() : null;
  return date && Number.isFinite(date.getTime()) ? date : null;
}
export function continuityExpiry(dayKey: string): Date {
  if (!isDateKey(dayKey)) throw new Error('Invalid achievement day');
  return new Date(`${addDaysToDateKey(dayKey, 3)}T00:00:00+09:00`);
}
export function readContinuityState(data?: admin.firestore.DocumentData): ContinuityState {
  return {schemaVersion: 1, policyVersion: CONTINUITY_POLICY_VERSION,
    status: data?.status === 'active' || data?.status === 'expired' ? data.status : 'empty',
    periodId: typeof data?.periodId === 'string' ? data.periodId : null,
    periodStartedOn: typeof data?.periodStartedOn === 'string' && isDateKey(data.periodStartedOn) ? data.periodStartedOn : null,
    periodEarned: count(data?.periodEarned),
    lastAchievementDateKey: typeof data?.lastAchievementDateKey === 'string' && isDateKey(data.lastAchievementDateKey) ? data.lastAchievementDateKey : null,
    expiresAt: trustedDate(data?.expiresAt), lifetimeAchievementDays: count(data?.lifetimeAchievementDays)};
}
/** Calendar grace, not 48 elapsed hours. This never changes permanent rewards. */
export function continuityStateAt(state: ContinuityState, now: Date): ContinuityState {
  if (state.status === 'active' && (state.expiresAt == null || now.getTime() >= state.expiresAt.getTime()))
    return {...state, status: 'expired', periodEarned: 0};
  return state;
}
export function continuityView(state: ContinuityState, now: Date): ContinuityView {
  const current = continuityStateAt(state, now); const day = formatDateKey(now);
  return {schemaVersion: 1, policyVersion: CONTINUITY_POLICY_VERSION, serverDateKey: day,
    phase: current.status === 'active' && current.lastAchievementDateKey != null && day >= addDaysToDateKey(current.lastAchievementDateKey, 2)
      ? 'grace' : current.status,
    todayAchieved: current.lastAchievementDateKey === day,
    periodId: current.periodId, periodStartedOn: current.periodStartedOn, periodEarned: current.periodEarned,
    lastAchievementDateKey: current.lastAchievementDateKey, expiresAt: current.expiresAt?.toISOString() ?? null,
    lifetimeAchievementDays: current.lifetimeAchievementDays};
}
function toData(state: ContinuityState): admin.firestore.DocumentData {
  return {...state, expiresAt: state.expiresAt ? admin.firestore.Timestamp.fromDate(state.expiresAt) : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()};
}
export function isValidManualContinuityRecord(kind: ContinuitySourceKind, data: admin.firestore.DocumentData | undefined): boolean {
  if (!data) return false;
  if (kind === 'condition' && data.source != null && !['manual', 'checkin_manual'].includes(data.source)) return false;
  if (kind === 'weight' && data.source != null && !['manual', 'weight_manual'].includes(data.source)) return false;
  if (kind === 'condition') return ['normal', 'slightlyConcerned', 'veryConcerned'].includes(data.condition);
  if (kind === 'weight') return typeof data.weightGrams === 'number' && Number.isFinite(data.weightGrams) && data.weightGrams > 0 && data.weightGrams <= 1000;
  if (kind === 'wheel') return data.source === 'wheel_manual' && typeof data.distance === 'number' && Number.isFinite(data.distance) && data.distance >= 0;
  return data.status === 'active' && data.actions && Object.values(data.actions).some((item: unknown) =>
    item != null && ['performed', 'not_performed'].includes((item as {answer?: string}).answer ?? ''));
}
/** A mirror of already-issued awards: credits are references, never a second wallet. */
export async function reconcileContinuity(params: {
  db: admin.firestore.Firestore; uid: string; now?: Date; evidence?: ContinuityEvidence;
  awardRef?: admin.firestore.DocumentReference;
}): Promise<ContinuityView> {
  const {db, uid, evidence, awardRef} = params; const now = params.now ?? new Date();
  const today = formatDateKey(now);
  if (evidence && (!isDateKey(evidence.sourceDateKey) || !Number.isFinite(evidence.acceptedAt.getTime()) ||
    evidence.acceptedAt.getTime() > now.getTime() || !evidence.sourcePath.startsWith(`users/${uid}/`)))
    throw new Error('Invalid server record evidence');
  const acceptedDay = evidence ? formatDateKey(evidence.acceptedAt) : today;
  const stateRef = db.doc(`users/${uid}/rewards/continuity`);
  const openRef = db.doc(`users/${uid}/star_awards/${acceptedDay}_open_app`);
  return db.runTransaction(async tx => {
    const beforeSnap = await tx.get(stateRef); const before = readContinuityState(beforeSnap.data());
    const outbox = await tx.get(db.collection(`users/${uid}/care_reward_receipts`).orderBy('acceptedAt').limit(101));
    // Never expire/start a period using an incomplete set of server receipts.
    // A bounded refresh drains these first; residual work stays in the outbox.
    const pendingIncomplete = outbox.size > 100;
    const proofs: ContinuityEvidence[] = [];
    const earliestPendingDay = trustedDate(outbox.docs[0]?.get('acceptedAt'));
    for (const receipt of outbox.docs.slice(0, 100)) {
      // With residual work, only recognize the earliest receipt day. This
      // cannot jump past unknown intervening achievements or close a period.
      if (pendingIncomplete && earliestPendingDay && trustedDate(receipt.get('acceptedAt')) &&
          formatDateKey(trustedDate(receipt.get('acceptedAt'))!) !== formatDateKey(earliestPendingDay)) break;
      const data = receipt.data(); const date = trustedDate(data.acceptedAt);
      if (!date || date.getTime() > now.getTime() || !isDateKey(data.dayKey) || data.dayKey > formatDateKey(date) || typeof data.revisionPath !== 'string' ||
          !data.revisionPath.startsWith(`users/${uid}/daily_care_actions/`))
        return {...continuityView(before, now), confirmationPending: true};
      const revision = await tx.get(db.doc(data.revisionPath));
      if (!revision.exists || revision.get('ownerUid') !== uid ||
          revision.get('mutationId') !== data.mutationId || !isValidManualContinuityRecord('care', revision.data()) ||
          trustedDate(revision.get('acceptedAt'))?.getTime() !== date.getTime())
        return {...continuityView(before, now), confirmationPending: true};
      proofs.push({sourceKind: 'care', sourceDateKey: data.dayKey, sourcePath: data.revisionPath, acceptedAt: date});
    }
    if (evidence && (!pendingIncomplete || proofs.some(proof => proof.sourcePath === evidence.sourcePath))) proofs.push(evidence);
    proofs.sort((a, b) => a.acceptedAt.getTime() - b.acceptedAt.getTime() || a.sourcePath.localeCompare(b.sourcePath));
    const byDay = new Map<string, ContinuityEvidence>();
    for (const proof of proofs) if (!byDay.has(formatDateKey(proof.acceptedAt))) byDay.set(formatDateKey(proof.acceptedAt), proof);
    const calendars = new Map<string, admin.firestore.DocumentSnapshot>();
    for (const day of byDay.keys()) calendars.set(day, await tx.get(db.doc(`users/${uid}/continuity_days/${day}`)));
    const previousClosure = before.status === 'expired' && before.periodId
      ? await tx.get(db.doc(`users/${uid}/continuity_periods/${before.periodId}`)) : null;
    let next = before; let changed = false; let correctedClosure = false;
    const achievements: {day: string; proof: ContinuityEvidence; periodId: string | null; late: boolean}[] = [];
    const closures: ContinuityState[] = [];
    for (const [day, proof] of byDay) {
      if (calendars.get(day)?.exists) continue;
      const late = next.lastAchievementDateKey != null && day < next.lastAchievementDateKey;
      if (!late) {
        const timely = next.periodId != null && next.expiresAt != null &&
          proof.acceptedAt.getTime() < next.expiresAt.getTime();
        if (!timely && next.status === 'active' && next.periodId) closures.push(next);
        const resumedEarned = next.status === 'expired' && timely && next.periodId === before.periodId
          ? count(previousClosure?.get('earned')) : next.periodEarned;
        if (next.status === 'expired' && timely && previousClosure?.exists) correctedClosure = true;
        next = {...next, status: 'active',
          periodId: timely ? next.periodId : `p_${day}_${proof.acceptedAt.getTime()}`,
          periodStartedOn: timely ? next.periodStartedOn : day,
          periodEarned: timely ? resumedEarned : 0,
          lastAchievementDateKey: day, expiresAt: continuityExpiry(day)};
      }
      next = {...next, lifetimeAchievementDays: next.lifetimeAchievementDays + 1}; changed = true;
      achievements.push({day, proof, periodId: late ? null : next.periodId, late});
    }
    const evaluated = pendingIncomplete ? next : continuityStateAt(next, now);
    if (evaluated !== next) {if (next.periodId) closures.push(next); next = evaluated; changed = true;}
    const candidates = [openRef, ...(awardRef && awardRef.path !== openRef.path ? [awardRef] : [])];
    const mirrors: {awardId: string; kind: string; creditRef: admin.firestore.DocumentReference; linkRef: admin.firestore.DocumentReference; awardPath: string}[] = [];
    // Partial drains may mirror a verified receipt in the established period;
    // otherwise removing that receipt would lose its already-issued award.
    const mirrorConfirmedReceipt = !pendingIncomplete || !!evidence && proofs.some(proof => proof.sourcePath === evidence.sourcePath);
    if (mirrorConfirmedReceipt && next.status === 'active' && next.periodId && next.periodStartedOn && acceptedDay >= next.periodStartedOn) {
      for (const ref of candidates) {
        const award = await tx.get(ref); if (!award.exists) continue;
        const kind = award.get('kind'); if (!['open_app', 'wheel', 'condition'].includes(kind)) continue;
        const awardedAt = trustedDate(award.get('awardedAt'));
        // New ledgers preserve the original receipt day even if issuance was
        // delayed. Processing time can never revive an award in a new period.
        const awardDay = typeof award.get('acceptedDateKey') === 'string'
          ? award.get('acceptedDateKey') : awardedAt ? formatDateKey(awardedAt) : null;
        if (!awardDay || !isDateKey(awardDay) || awardDay < next.periodStartedOn || awardDay > today) continue;
        const creditRef = db.doc(`users/${uid}/continuity_credits/${acceptedDay}_${kind}`);
        const linkRef = db.doc(`users/${uid}/continuity_award_links/${ref.id}`);
        const [credit, link] = await Promise.all([tx.get(creditRef), tx.get(linkRef)]);
        if (!credit.exists && !link.exists) mirrors.push({awardId: ref.id, kind, creditRef, linkRef, awardPath: ref.path});
      }
      if (mirrors.length) {next = {...next, periodEarned: next.periodEarned + mirrors.length}; changed = true;}
    }
    const stamp = admin.firestore.FieldValue.serverTimestamp();
    if (correctedClosure && previousClosure?.exists) tx.set(previousClosure.ref, {
      status: 'continued_after_delayed_reward', closureCorrectedAt: stamp}, {merge: true});
    for (const period of closures) tx.set(db.doc(`users/${uid}/continuity_periods/${period.periodId}`), {
      schemaVersion: 1, policyVersion: CONTINUITY_POLICY_VERSION, periodId: period.periodId,
      periodStartedOn: period.periodStartedOn, lastAchievementDateKey: period.lastAchievementDateKey,
      expiredAt: period.expiresAt ? admin.firestore.Timestamp.fromDate(period.expiresAt) : null,
      earned: period.periodEarned, status: 'expired', closedAt: stamp});
    for (const {day, proof, periodId, late} of achievements) tx.create(db.doc(`users/${uid}/continuity_days/${day}`), {
      schemaVersion: 1, policyVersion: CONTINUITY_POLICY_VERSION, dayKey: day, achieved: true, periodId,
      lateReceipt: late, sourceKind: proof.sourceKind, sourceDateKey: proof.sourceDateKey, sourcePath: proof.sourcePath,
      acceptedAt: admin.firestore.Timestamp.fromDate(proof.acceptedAt), recordedAt: stamp});
    for (const mirror of mirrors) {
      tx.create(mirror.creditRef, {schemaVersion: 1, policyVersion: CONTINUITY_POLICY_VERSION,
        acceptedDateKey: acceptedDay, kind: mirror.kind, awardId: mirror.awardId, awardPath: mirror.awardPath,
        periodId: next.periodId, amount: 1, recordedAt: stamp});
      tx.create(mirror.linkRef, {creditPath: mirror.creditRef.path, periodId: next.periodId, recordedAt: stamp});
    }
    if (changed) tx.set(stateRef, toData(next));
    return {...continuityView(next, now), achievementRecorded: achievements.some(item => item.day === acceptedDay),
      mirroredAwardCount: mirrors.length, confirmationPending: pendingIncomplete};
  });
}
export const continuityWeightRecordWritten = onDocumentWritten({region: 'asia-northeast1', document: 'users/{uid}/weight_records/{sourceDateKey}', retry: true}, async event => {
  const after = event.data?.after; if (!after?.exists || !isValidManualContinuityRecord('weight', after.data())) return;
  const acceptedAt = trustedDate(after.updateTime);
  if (!acceptedAt || !isDateKey(event.params.sourceDateKey) || event.params.sourceDateKey > formatDateKey(acceptedAt)) return;
  const result = await reconcileContinuity({db: admin.firestore(), uid: event.params.uid,
    evidence: {sourceKind: 'weight', sourceDateKey: event.params.sourceDateKey, sourcePath: after.ref.path, acceptedAt}});
  if (result.confirmationPending) throw new Error('Trusted receipt reconciliation is pending; retry record event.');
});
