import {createHash} from 'node:crypto';
import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {formatDateKey, isDateKey} from '../health/dateKey';
import {awardStar, isAwardDateEligible, starAwardId} from '../stars/starAwards';
import {reconcileContinuity, trustedDate, isValidManualContinuityRecord, ContinuityView} from '../stars/continuity';
import {CARE_ACTION_CATALOG_VERSION, CareActionCatalogItem, activeCareActionItems, careActionCatalog, careActionDetailDefinitions, resolveCareActionId} from './careActionCatalog';

export const CARE_ACTION_SCHEMA_VERSION = 1;
export const CARE_ACTION_INPUT_VERSION = 'care_actions_input_v2';
export const CARE_ACTION_LEGACY_INPUT_VERSION = 'care_actions_input_v1';
export const CARE_ACTION_GAME_POLICY_VERSION = 'continuity_v1';
export type CareActionAnswer = 'performed' | 'not_performed' | 'unanswered';
export type CareActionAnswerProvenance = 'item_selection' | 'batch_confirmation' | 'unanswered' | 'legacy_unspecified';
export interface CareActionEvidence {
  answer: CareActionAnswer; answerProvenance: CareActionAnswerProvenance; details: Record<string, string | number>;
  detailUnits: Record<string, string | null>; detailMeanings: Record<string, string | null>;
  occurredAt: null; occurredDateKey: string | null; timePrecision: 'date_only' | 'unknown';
  nonPerformanceScope: 'up_to_acceptance' | null;
}
export interface CareActionMutation {
  dayKey: string; expectedRevision: number; mutationId: string; operation: 'save' | 'cancel';
  actions: Record<string, CareActionEvidence>; inputUiVersion: string; inputRoute: 'daily_checkin';
  eligibleForAchievement: boolean;
}
export interface CareActionSaveResult {
  saved: true; replayed: boolean; dayKey: string; revision: number; mutationId: string;
  recordStatus: 'active' | 'cancelled'; eligibleForAchievement: boolean; reward: {status: 'not_processed' | 'processed' | 'failed' | 'not_eligible'};
}
function object(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
function fail(message: string): never {throw new HttpsError('invalid-argument', message);}
function only(value: Record<string, unknown>, fields: readonly string[]): void {
  if (Object.keys(value).some(key => !fields.includes(key))) fail('未対応の入力フィールドです。');
}
function emptyEvidence(): CareActionEvidence {
  return {answer: 'unanswered', answerProvenance: 'unanswered', details: {}, detailUnits: {}, detailMeanings: {}, occurredAt: null, occurredDateKey: null, timePrecision: 'unknown', nonPerformanceScope: null};
}
/** A legacy unknown answer may only be carried from the matching current revision. */
function answerProvenance(raw: Record<string, unknown>, answer: CareActionAnswer, details: Record<string, string | number>, inputVersion: string, previous: unknown): CareActionAnswerProvenance {
  if (inputVersion === CARE_ACTION_LEGACY_INPUT_VERSION) {
    if (raw.answerProvenance != null && raw.answerProvenance !== 'legacy_unspecified') fail('旧入力方式の回答出所が不正です。');
    return 'legacy_unspecified';
  }
  if (raw.answerProvenance === 'legacy_unspecified' || (raw.answerProvenance == null && answer !== 'unanswered')) {
    if (!object(previous) || previous.answer !== answer ||
        (previous.answerProvenance != null && previous.answerProvenance !== 'legacy_unspecified') ||
        JSON.stringify(canonical(object(previous.details) ? previous.details : {})) !== JSON.stringify(canonical(details)))
      fail('未確認の回答は保存できません。内容を確認してください。');
    return 'legacy_unspecified';
  }
  if (answer === 'unanswered') {
    if (raw.answerProvenance != null && raw.answerProvenance !== 'unanswered') fail('未回答の出所が不正です。');
    return 'unanswered';
  }
  if (raw.answerProvenance !== 'item_selection' && raw.answerProvenance !== 'batch_confirmation') fail('回答の確認方法が不正です。');
  return raw.answerProvenance;
}
/** Only confirmed state is trusted. Optional detail is erased on non-performance/unanswered. */
export function normalizeCareActionMutation(
  value: unknown, now: Date, catalog: readonly CareActionCatalogItem[] = careActionCatalog,
  previousActions: Record<string, unknown> = {},
): CareActionMutation {
  if (!object(value)) fail('保存内容が不正です。');
  only(value, ['dayKey', 'expectedRevision', 'mutationId', 'operation', 'actions', 'inputUiVersion', 'inputRoute']);
  if (typeof value.dayKey !== 'string' || !isDateKey(value.dayKey) || value.dayKey > formatDateKey(now)) fail('対象日が不正です。');
  if (typeof value.expectedRevision !== 'number' || !Number.isSafeInteger(value.expectedRevision) || value.expectedRevision < 0) fail('revisionが不正です。');
  if (typeof value.mutationId !== 'string' || !/^[a-zA-Z0-9_-]{16,128}$/.test(value.mutationId)) fail('mutation IDが不正です。');
  if (value.operation !== 'save' && value.operation !== 'cancel') fail('保存操作が不正です。');
  if (![CARE_ACTION_INPUT_VERSION, CARE_ACTION_LEGACY_INPUT_VERSION].includes(String(value.inputUiVersion)) || value.inputRoute !== 'daily_checkin') fail('入力方式が不正です。');
  if (!object(value.actions)) fail('行動回答が不正です。');
  if (value.operation === 'cancel' && Object.keys(value.actions).length !== 0) fail('取消に行動回答は不要です。');
  const inputUiVersion = value.inputUiVersion as string;
  const actions: Record<string, CareActionEvidence> = {};
  if (value.operation === 'save') {
    for (const item of activeCareActionItems(catalog)) actions[item.id] = emptyEvidence();
    for (const [key, raw] of Object.entries(value.actions)) {
      const id = resolveCareActionId(key, catalog);
      const item = catalog.find(candidate => candidate.id === id);
      if (!item || !item.active || id !== key || !object(raw)) fail('行動項目が不正です。');
      only(raw, ['answer', 'details', 'answerProvenance']);
      if (!['performed', 'not_performed', 'unanswered'].includes(String(raw.answer))) fail('行動回答が不正です。');
      const answer = raw.answer as CareActionAnswer;
      const details: Record<string, string | number> = {};
      const detailUnits: Record<string, string | null> = {};
      const detailMeanings: Record<string, string | null> = {};
      if (answer === 'performed' && raw.details != null) {
        if (!object(raw.details)) fail('任意詳細が不正です。');
        const definitions = careActionDetailDefinitions(item);
        only(raw.details, definitions.map(detail => detail.key));
        for (const detail of definitions) {
          const detailValue = raw.details[detail.key];
          if (detailValue == null) continue;
          if (detail.type === 'enum' && (typeof detailValue !== 'string' || !detail.values?.some(x => x.id === detailValue))) fail('任意詳細の選択が不正です。');
          if (detail.type === 'integer' && (typeof detailValue !== 'number' || !Number.isSafeInteger(detailValue) || detailValue < (detail.min ?? 0) || detailValue > (detail.max ?? Number.MAX_SAFE_INTEGER))) fail('任意詳細の数値が不正です。');
          details[detail.key] = detailValue as string | number;
          detailUnits[detail.key] = detail.unit ?? null;
          detailMeanings[detail.key] = detail.meaning ?? null;
        }
        if (definitions.some(detail => detail.legacy && detail.key in details) && definitions.some(detail => !detail.legacy && detail.key in details)) fail('旧区分と新しい区分は同時に保存できません。');
        for (const detail of definitions) if (detail.key in details && detail.onlyWhen && !detail.onlyWhen.values.includes(String(details[detail.onlyWhen.key]))) fail('選択した内容にはこの詳細を保存できません。');
      }
      actions[item.id] = {answer, answerProvenance: answerProvenance(raw, answer, details, inputUiVersion, previousActions[item.id]), details, detailUnits, detailMeanings, occurredAt: null, occurredDateKey: answer === 'performed' ? value.dayKey : null,
        timePrecision: answer === 'performed' ? 'date_only' : 'unknown', nonPerformanceScope: answer === 'not_performed' ? 'up_to_acceptance' : null};
    }
  }
  return {dayKey: value.dayKey, expectedRevision: value.expectedRevision, mutationId: value.mutationId,
    operation: value.operation, actions, inputUiVersion, inputRoute: value.inputRoute,
    eligibleForAchievement: value.operation === 'save' && Object.values(actions).some(action => action.answer !== 'unanswered')};
}
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (object(value)) return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  return value;
}
export function careActionMutationFingerprint(mutation: unknown): string {
  return createHash('sha256').update(JSON.stringify(canonical(mutation))).digest('hex');
}
function millis(value: unknown): number | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value.getTime() : null;
  if (object(value) && typeof value.toMillis === 'function') {
    const time = (value.toMillis as () => number)(); return Number.isFinite(time) ? time : null;
  }
  return null;
}
/** Mirrors canCreateRecord in Rules; malformed expiry never grants access. */
export function hasCareRecordAccess(billing: Record<string, unknown> | null, trial: Record<string, unknown> | null, now: Date): boolean {
  const end = billing?.currentPeriodEnd;
  const paid = billing?.plan === 'paid' && ['active', 'trialing'].includes(String(billing.status)) &&
    (end == null || (millis(end) != null && now.getTime() < millis(end)!));
  const trialEnd = millis(trial?.endsAt);
  return paid || (trial?.status === 'active' && trialEnd != null && now.getTime() < trialEnd);
}
/** One atomic immutable revision + idempotency receipt + current projection. No health/reward writes. */
export async function saveCareActionMutation(params: {
  db: admin.firestore.Firestore; uid: string; data: unknown; now?: Date;
}): Promise<CareActionSaveResult> {
  const {db, uid} = params;
  const now = params.now ?? new Date();
  const data = params.data;
  // A receipt retains the exact request identity across later catalog additions/retirements.
  // Path-safe envelope is checked before looking up the receipt; new requests are fully
  // normalized only after receipt lookup. An old accepted replay cannot rewrite current.
  if (!object(data) || typeof data.dayKey !== 'string' || !isDateKey(data.dayKey) ||
      typeof data.mutationId !== 'string' || !/^[a-zA-Z0-9_-]{16,128}$/.test(data.mutationId)) fail('保存識別子が不正です。');
  const fingerprint = careActionMutationFingerprint(data);
  const current = db.doc(`users/${uid}/daily_care_actions/${data.dayKey}`);
  const receipt = current.collection('mutations').doc(data.mutationId);
  return db.runTransaction(async tx => {
    const [currentSnap, receiptSnap] = await Promise.all([tx.get(current), tx.get(receipt)]);
    if (receiptSnap.exists) {
      if (receiptSnap.get('requestFingerprint') !== fingerprint) throw new HttpsError('already-exists', '同じmutation IDで異なる内容は保存できません。');
      return {...receiptSnap.get('result'), replayed: true} as CareActionSaveResult;
    }
    const revision = currentSnap.exists ? currentSnap.get('revision') : 0;
    if (!Number.isSafeInteger(revision) || revision < 0) throw new HttpsError('failed-precondition', '保存済みrevisionが不正です。');
    if (typeof data.expectedRevision !== 'number' || !Number.isSafeInteger(data.expectedRevision) || data.expectedRevision < 0) fail('revisionが不正です。');
    if (revision !== data.expectedRevision) throw new HttpsError('aborted', '別の保存が先に完了しました。最新記録を確認してください。');
    const previousActions = currentSnap.get('actions');
    const mutation = normalizeCareActionMutation(data, now, careActionCatalog, object(previousActions) ? previousActions : {});
    if (mutation.operation === 'cancel') {
      if (!currentSnap.exists) throw new HttpsError('not-found', '取消対象の記録がありません。');
    } else {
      const [billing, trial] = await Promise.all([tx.get(db.doc(`users/${uid}/billing/subscription`)), tx.get(db.doc(`users/${uid}/feature_access/initial_trial_v2`))]);
      if (!hasCareRecordAccess(billing.data() ?? null, trial.data() ?? null, new Date(Math.max(now.getTime(), params.now ? now.getTime() : Date.now())))) throw new HttpsError('permission-denied', '記録には有料プランまたは有効な無料体験が必要です。');
    }
    const nextRevision = revision + 1;
    const result: CareActionSaveResult = {saved: true, replayed: false, dayKey: mutation.dayKey, revision: nextRevision,
      mutationId: mutation.mutationId, recordStatus: mutation.operation === 'cancel' ? 'cancelled' : 'active',
      eligibleForAchievement: mutation.eligibleForAchievement, reward: {status: 'not_processed'}};
    const stamp = admin.firestore.FieldValue.serverTimestamp();
    const record = {schemaVersion: CARE_ACTION_SCHEMA_VERSION, catalogVersion: CARE_ACTION_CATALOG_VERSION,
      ownerUid: uid, petId: 'main_pet', dayKey: mutation.dayKey, status: result.recordStatus,
      revision: nextRevision, mutationId: mutation.mutationId, previousRevision: revision,
      actions: mutation.actions, acceptedAt: stamp, updatedAt: stamp,
      createdAt: currentSnap.get('createdAt') ?? stamp, inputUiVersion: mutation.inputUiVersion,
      inputRoute: mutation.inputRoute, gamePolicyVersion: CARE_ACTION_GAME_POLICY_VERSION};
    tx.create(current.collection('revisions').doc(String(nextRevision).padStart(10, '0')), record);
    tx.create(receipt, {schemaVersion: 1, requestFingerprint: fingerprint, acceptedAt: stamp, result});
    if (mutation.eligibleForAchievement) tx.create(db.doc(`users/${uid}/care_reward_receipts/${mutation.dayKey}_${mutation.mutationId}`), {
      schemaVersion: 1, dayKey: mutation.dayKey, mutationId: mutation.mutationId, acceptedAt: stamp,
      revision: nextRevision, revisionPath: current.collection('revisions').doc(String(nextRevision).padStart(10, '0')).path});
    tx.set(current, record);
    return result;
  });
}
export const saveDailyCareActions = onCall({region: 'asia-northeast1'}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const db = admin.firestore();
  const result = await saveCareActionMutation({db, uid, data: request.data});
  // The immutable Bronze save is already committed. A reward outage never
  // changes the successful save into an input failure or asks for re-entry.
  try {
    const reward = await processCareActionReward({db, uid, dayKey: result.dayKey, mutationId: result.mutationId});
    return {...result, ...reward};
  } catch (_) {return {...result, reward: {status: 'failed'}};}
});

/** Retry from the accepted immutable revision, never from a new client timestamp. */
export async function processCareActionReward(params: {
  db: admin.firestore.Firestore; uid: string; dayKey: string; mutationId: string; now?: Date;
}): Promise<{reward: {status: 'processed' | 'not_eligible'}; continuity?: ContinuityView}> {
  const {db, uid, dayKey, mutationId} = params;
  if (!isDateKey(dayKey) || !/^[a-zA-Z0-9_-]{16,128}$/.test(mutationId)) fail('保存識別子が不正です。');
  const root = db.doc(`users/${uid}/daily_care_actions/${dayKey}`);
  const receipt = await root.collection('mutations').doc(mutationId).get();
  const revision = receipt.get('result.revision');
  if (!receipt.exists || !Number.isSafeInteger(revision) || revision < 1) throw new HttpsError('not-found', '保存済み記録がありません。');
  const accepted = await root.collection('revisions').doc(String(revision).padStart(10, '0')).get();
  if (!accepted.exists || accepted.get('ownerUid') !== uid || accepted.get('mutationId') !== mutationId)
    throw new HttpsError('failed-precondition', '保存履歴を確認できません。');
  if (!isValidManualContinuityRecord('care', accepted.data())) return {reward: {status: 'not_eligible'}};
  const acceptedAt = trustedDate(accepted.get('acceptedAt'));
  if (!acceptedAt) throw new HttpsError('failed-precondition', '受理日時を確認できません。');
  const now = params.now ?? new Date(); const acceptedDay = formatDateKey(acceptedAt);
  let awardRef: admin.firestore.DocumentReference | undefined;
  // Existing same-day condition category only. A historical care entry has no
  // new permanent reward; its actual receipt day can still achieve continuity.
  if (dayKey === acceptedDay && isAwardDateEligible(dayKey, acceptedAt)) {
    await awardStar({db, uid, missionDateKey: dayKey, kind: 'condition', sourceRef: accepted.ref, acceptedAt, now});
    const guard = await db.doc(`users/${uid}/condition_award_days/${acceptedDay}`).get();
    const path = guard.get('awardPath');
    awardRef = typeof path === 'string' && path.startsWith(`users/${uid}/star_awards/`)
      ? db.doc(path) : db.doc(`users/${uid}/star_awards/${starAwardId(dayKey, 'condition')}`);
  }
  const continuity = await reconcileContinuity({db, uid, now, awardRef,
    evidence: {sourceKind: 'care', sourceDateKey: dayKey, sourcePath: accepted.ref.path, acceptedAt}});
  if (continuity.confirmationPending && !(await db.doc(`users/${uid}/continuity_days/${acceptedDay}`).get()).exists)
    throw new Error('Accepted care receipt has not been reconciled yet.');
  await db.doc(`users/${uid}/care_reward_receipts/${dayKey}_${mutationId}`).delete();
  return {reward: {status: 'processed'}, continuity};
}
export const retryDailyCareActionReward = onCall({region: 'asia-northeast1'}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const data = request.data;
  if (!object(data) || typeof data.dayKey !== 'string' || typeof data.mutationId !== 'string' ||
      Object.keys(data).some(key => !['dayKey', 'mutationId'].includes(key))) fail('再試行の識別子が不正です。');
  try {return await processCareActionReward({db: admin.firestore(), uid, dayKey: data.dayKey, mutationId: data.mutationId});}
  catch (error) {
    if (error instanceof HttpsError) throw error;
    return {reward: {status: 'failed'}};
  }
});
