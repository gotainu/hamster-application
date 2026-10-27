import {randomUUID} from 'node:crypto';
import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {careActionMutationFingerprint, hasCareRecordAccess} from '../careActions/careActions';
import {formatDateKey, isDateKey} from '../health/dateKey';
import {commitIdentityIntroduction, dateOf, explicitInstant, invalid, isObject, MAIN_PET_SLOT, mutationKey, onlyFields, planMainPetIdentity, revisionNumber, subjectKey} from '../petIdentity/petIdentity';

export const MEASUREMENT_HISTORY_SCHEMA_VERSION = 1;
export const MEASUREMENT_HISTORY_INPUT_VERSION = 'measurement_history_v1';
export const MEASUREMENT_HISTORY_TRANSACTION_LIMIT = 2000;
export type MeasurementKind = 'weight' | 'distance';
export interface MeasurementTiming {
  timePrecision: 'unknown' | 'date_only' | 'instant'; dateKey: string | null; observedAt: string | null;
  confirmation: 'unknown' | 'date_confirmed' | 'now_confirmed' | 'time_confirmed'; clockSource: 'unknown' | 'user_reported';
  timeZone: 'Asia/Tokyo'; windowMeaning?: 'selected_day' | 'selected_night_to_next_morning' | 'unknown';
}
export interface MeasurementMutation {
  kind: MeasurementKind; dayKey: string; originalDayKey: string; date: Date; subjectId: string | null;
  expectedRevision: number; mutationId: string; operation: 'save' | 'cancel'; legacyConfirmed: boolean;
  timing: MeasurementTiming | null; values: Record<string, unknown> | null;
  diameterCorrection: boolean; wheelDiameterCm: number | null;
}
export interface MeasurementRevision {
  schemaVersion: number; ownerUid: string; petId: typeof MAIN_PET_SLOT; subjectId: string; kind: MeasurementKind;
  recordId: string; recordRevision: number; previousRecordRevision: number; dayKey: string; previousDayKey: string | null;
  dayRevisions: Record<string, number>; operation: 'create' | 'correction' | 'date_correction' | 'cancel' | 'confirmed_legacy_snapshot';
  origin: 'explicit_measurement' | 'confirmed_legacy_snapshot' | 'legacy_unknown_original';
  acceptedAt: unknown; timing: MeasurementTiming | null; values: Record<string, unknown> | null; mutationId: string;
  valueUnits: Record<string, 'g' | 'm' | 'cm' | 'count'>;
  inputRoute: 'weight_manual' | 'wheel_rotations_manual' | 'distance_manual' | 'manual_cancel';
  inputUiVersion: string; researchConsentStatus: 'not_assessed';
}
export interface MeasurementSaveResult {
  saved: true; replayed: boolean; changed: boolean; kind: MeasurementKind; subjectId: string; dayKey: string; originalDayKey: string;
  recordId: string; revision: number; recordRevision: number; mutationId: string; recordStatus: 'active' | 'cancelled';
  projection: Record<string, unknown> | null; acceptedAt?: string; acceptedAtEpochNanoseconds?: string;
}
const paths = (kind: MeasurementKind) => ({current: `${kind}_records`, history: `${kind}_record_history`, days: `${kind}_record_days`, mutations: `${kind}_record_mutations`});
const revisionId = (revision: number) => String(revision).padStart(10, '0');
const same = (a: unknown, b: unknown) => careActionMutationFingerprint(a) === careActionMutationFingerprint(b);

/** A date-only display index is never used as the measurement's observed instant. */
function normalizeTiming(value: unknown, kind: MeasurementKind, dayKey: string, now: Date): MeasurementTiming {
  if (!isObject(value)) invalid('記録した時期を確認してください。');
  onlyFields(value, ['precision', 'dateKey', 'observedAt', 'confirmation', 'windowMeaning']);
  const common = {timeZone: 'Asia/Tokyo' as const};
  let windowMeaning: MeasurementTiming['windowMeaning'];
  if (kind === 'distance') {
    windowMeaning = value.windowMeaning == null ? (value.precision === 'unknown' ? 'unknown' : 'selected_day') : value.windowMeaning as MeasurementTiming['windowMeaning'];
    if (!['selected_day', 'selected_night_to_next_morning', 'unknown'].includes(String(windowMeaning))) invalid('活動の時間帯が不正です。');
  } else if (value.windowMeaning != null) invalid('体重に活動の時間帯は指定できません。');
  const window = windowMeaning == null ? {} : {windowMeaning};
  if (value.precision === 'unknown') {
    if (value.confirmation !== 'unknown' || value.dateKey != null || value.observedAt != null) invalid('時期不明の内容が不正です。');
    return {...common, ...window, timePrecision: 'unknown', dateKey: null, observedAt: null, confirmation: 'unknown', clockSource: 'unknown'};
  }
  if (windowMeaning === 'selected_night_to_next_morning') invalid('夜から翌朝の活動は実時刻を推定せず、時刻不明として保存してください。');
  if (value.precision === 'date_only') {
    if (value.confirmation !== 'date_confirmed' || value.dateKey !== dayKey || value.observedAt != null) invalid('記録日を確認してください。');
    return {...common, ...window, timePrecision: 'date_only', dateKey: dayKey, observedAt: null, confirmation: 'date_confirmed', clockSource: 'user_reported'};
  }
  if (value.precision !== 'instant' || !['time_confirmed', 'now_confirmed'].includes(String(value.confirmation))) invalid('記録時刻の確認方法が不正です。');
  const observed = explicitInstant(value.observedAt);
  if (!observed || observed.getTime() > now.getTime() || formatDateKey(observed) !== dayKey || (value.dateKey != null && value.dateKey !== dayKey)) invalid('記録時刻が不正です。');
  return {...common, ...window, timePrecision: 'instant', dateKey: dayKey, observedAt: observed.toISOString(), confirmation: value.confirmation as MeasurementTiming['confirmation'], clockSource: 'user_reported'};
}
function diameter(value: unknown): number | null {
  const number = typeof value === 'number' ? value : typeof value === 'string' && value.trim() ? Number(value) : NaN;
  return Number.isFinite(number) && number > 0 ? number : null;
}
/** One authoritative conversion used by every server save and correction. Distance is metres, diameter centimetres. */
export function distanceFromRotations(rotations: number, wheelDiameterCm: number): number {
  if (!Number.isSafeInteger(rotations) || rotations < 0 || diameter(wheelDiameterCm) === null) invalid('回転数または直径が不正です。');
  const result = rotations * (Math.PI * wheelDiameterCm) / 100;
  if (!Number.isFinite(result)) invalid('距離が大きすぎます。');
  return result;
}
export function normalizeMeasurementMutation(kind: MeasurementKind, data: unknown, now: Date): MeasurementMutation {
  if (!isObject(data)) invalid('保存内容が不正です。');
  onlyFields(data, ['dayKey', 'originalDayKey', 'date', 'subjectId', 'expectedRevision', 'mutationId', 'operation', 'legacyConfirmed', 'timing', 'inputUiVersion', ...(kind === 'weight' ? ['weightGrams', 'memo'] : ['mode', 'rotations', 'distance', 'source', 'diameterCorrection', 'wheelDiameterCm'])]);
  const dayKey = data.dayKey, originalDayKey = data.originalDayKey ?? dayKey;
  if (typeof dayKey !== 'string' || !isDateKey(dayKey) || dayKey > formatDateKey(now) || typeof originalDayKey !== 'string' || !isDateKey(originalDayKey) || originalDayKey > formatDateKey(now)) invalid('対象日が不正です。');
  if (kind === 'distance' && originalDayKey !== dayKey) invalid('活動量の日付移動には対応していません。');
  const date = explicitInstant(data.date);
  if (!date || formatDateKey(date) !== dayKey) invalid('表示用の日付が不正です。');
  if (!['save', 'cancel'].includes(String(data.operation)) || data.inputUiVersion !== MEASUREMENT_HISTORY_INPUT_VERSION) invalid('保存操作が不正です。');
  if (data.legacyConfirmed != null && typeof data.legacyConfirmed !== 'boolean') invalid('旧記録の確認が不正です。');
  const result: MeasurementMutation = {kind, dayKey, originalDayKey, date, subjectId: subjectKey(data.subjectId, true), expectedRevision: revisionNumber(data.expectedRevision), mutationId: mutationKey(data.mutationId), operation: data.operation as 'save' | 'cancel', legacyConfirmed: data.legacyConfirmed === true, timing: null, values: null, diameterCorrection: false, wheelDiameterCm: null};
  if (data.operation === 'cancel') {
    if (dayKey !== originalDayKey || ['timing', 'weightGrams', 'memo', 'mode', 'rotations', 'distance', 'source', 'diameterCorrection', 'wheelDiameterCm'].some(key => data[key] != null)) invalid('取消に新しい値は指定できません。');
    return result;
  }
  result.timing = normalizeTiming(data.timing, kind, dayKey, now);
  if (kind === 'weight') {
    if (typeof data.weightGrams !== 'number' || !Number.isFinite(data.weightGrams) || data.weightGrams <= 0 || data.weightGrams > 1000) invalid('体重は0より大きく1000g以下で入力してください。');
    const memo = data.memo ?? '';
    if (typeof memo !== 'string' || memo.length > 10000) invalid('メモが長すぎます。');
    result.values = {weightGrams: data.weightGrams, memo: memo.trim()};
  } else {
    if (data.source != null && data.source !== 'wheel_manual') invalid('活動量の保存経路が不正です。');
    if (data.diameterCorrection != null && typeof data.diameterCorrection !== 'boolean') invalid('直径の訂正指定が不正です。');
    result.diameterCorrection = data.diameterCorrection === true;
    if (result.diameterCorrection) {
      if (typeof data.wheelDiameterCm !== 'number' || diameter(data.wheelDiameterCm) === null) invalid('訂正する直径を入力してください。');
      result.wheelDiameterCm = data.wheelDiameterCm;
    } else if (data.wheelDiameterCm != null) invalid('直径を変える場合は明示的な訂正が必要です。');
    if (data.mode === 'rotations') {
      if (typeof data.rotations !== 'number' || !Number.isSafeInteger(data.rotations) || data.rotations < 0 || data.distance != null) invalid('回転数は0以上の整数で入力してください。');
      result.values = {mode: 'rotations', rotations: data.rotations, source: 'wheel_manual'};
    } else if (data.mode === 'direct_distance') {
      if (typeof data.distance !== 'number' || !Number.isFinite(data.distance) || data.distance < 0 || data.rotations != null || result.diameterCorrection) invalid('距離は0以上で入力してください。');
      result.values = {mode: 'direct_distance', distance: data.distance, rotations: null, wheelDiameterCm: null, diameterProvenance: 'not_applicable', source: 'wheel_manual'};
    } else invalid('活動量の入力方式が不正です。');
  }
  return result;
}

export function measurementEpochNanoseconds(value: unknown): bigint | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? BigInt(value.getTime()) * 1000000n : null;
  if (isObject(value) && typeof value.seconds === 'number' && Number.isSafeInteger(value.seconds) && typeof value.nanoseconds === 'number' && Number.isInteger(value.nanoseconds) && value.nanoseconds >= 0 && value.nanoseconds < 1000000000) return BigInt(value.seconds) * 1000000000n + BigInt(value.nanoseconds);
  return null;
}
export function parseMeasurementCutoff(data: Record<string, unknown>): bigint | undefined {
  if (data.knowledgeCutoff != null && data.knowledgeCutoffEpochNanoseconds != null) invalid('知識締切は一つだけ指定してください。');
  if (data.knowledgeCutoffEpochNanoseconds != null) {
    if (typeof data.knowledgeCutoffEpochNanoseconds !== 'string' || !/^-?\d{1,30}$/.test(data.knowledgeCutoffEpochNanoseconds)) invalid('知識締切が不正です。');
    return BigInt(data.knowledgeCutoffEpochNanoseconds);
  }
  if (data.knowledgeCutoff == null) return undefined;
  if (typeof data.knowledgeCutoff !== 'string') invalid('知識締切が不正です。');
  const matched = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$/.exec(data.knowledgeCutoff);
  if (!matched || !isDateKey(matched[1].slice(0, 10)) || Number(matched[1].slice(11, 13)) > 23 || Number(matched[1].slice(14, 16)) > 59 || Number(matched[1].slice(17, 19)) > 59 || (matched[3] !== 'Z' && (Number(matched[3].slice(1, 3)) > 23 || Number(matched[3].slice(4, 6)) > 59))) invalid('知識締切が不正です。');
  const second = explicitInstant(matched[1] + matched[3]);
  if (!second) invalid('知識締切が不正です。');
  return BigInt(second.getTime()) * 1000000n + BigInt((matched[2] ?? '').padEnd(9, '0') || '0');
}
function publicData(value: unknown): unknown {
  const date = dateOf(value); if (date) return date.toISOString();
  if (Array.isArray(value)) return value.map(publicData);
  return isObject(value) ? Object.fromEntries(Object.entries(value).map(([key, item]) => [key, publicData(item)])) : value;
}
const knownAt = (value: unknown, cutoff?: bigint) => {const nanos = measurementEpochNanoseconds(value); return nanos !== null && (cutoff === undefined || nanos <= cutoff);};
/** Select the latest accepted state for this day. Cancellation never reveals an older logical record. */
export function resolveMeasurementHistory(params: {dayKey: string; revisions: readonly MeasurementRevision[]; knowledgeCutoff?: bigint; historyStartedAt?: unknown; hadLegacyProjection?: boolean}) {
  const rows = params.revisions.filter(row => row.dayRevisions[params.dayKey] !== undefined && knownAt(row.acceptedAt, params.knowledgeCutoff)).sort((a, b) => a.dayRevisions[params.dayKey] - b.dayRevisions[params.dayKey]);
  const latest = rows.length ? rows[rows.length - 1] : null;
  const moved = latest !== null && latest.dayKey !== params.dayKey;
  const cancelled = latest?.operation === 'cancel';
  const current = latest && !moved && !cancelled ? latest : null;
  const reasons: string[] = [];
  if (params.hadLegacyProjection) reasons.push('legacy_original_unrecoverable');
  if (params.historyStartedAt && !knownAt(params.historyStartedAt, params.knowledgeCutoff)) reasons.push('before_history_introduction');
  if (!rows.length) reasons.push('no_accepted_measurement_history');
  if (rows.some(row => row.timing?.timePrecision === 'unknown')) reasons.push('measurement_time_unknown');
  if (rows.some(row => row.timing?.timePrecision === 'date_only')) reasons.push('measurement_time_date_only');
  if (rows.some(row => row.timing?.windowMeaning === 'selected_night_to_next_morning')) reasons.push('activity_window_crosses_day_boundary');
  return {current, revisions: rows, latestRevision: latest?.dayRevisions[params.dayKey] ?? 0, recordStatus: moved ? 'moved' : cancelled ? 'cancelled' : current ? 'active' : 'unknown', quality: {reasons, researchConsentStatus: 'not_assessed' as const}};
}
function projectionValues(kind: MeasurementKind, data: admin.firestore.DocumentData): Record<string, unknown> | null {
  if (kind === 'weight') return typeof data.weightGrams === 'number' && Number.isFinite(data.weightGrams) && data.weightGrams > 0 ? {weightGrams: data.weightGrams, memo: typeof data.memo === 'string' ? data.memo.trim() : ''} : null;
  if (typeof data.distance !== 'number' || !Number.isFinite(data.distance) || data.distance < 0) return null;
  const rotations = typeof data.rotations === 'number' && Number.isSafeInteger(data.rotations) && data.rotations >= 0 ? data.rotations : null;
  const wheelDiameterCm = diameter(data.wheelDiameterCm);
  return {mode: rotations === null ? 'direct_distance' : 'rotations', distance: data.distance, rotations, wheelDiameterCm, diameterProvenance: wheelDiameterCm === null ? 'legacy_unknown' : 'recorded_original', source: data.source ?? 'wheel_manual'};
}

/** Current daily values, logical-record history, day bindings, identity and receipt commit together. */
export async function saveMeasurementMutation(params: {db: admin.firestore.Firestore; uid: string; kind: MeasurementKind; data: unknown; now?: Date}): Promise<MeasurementSaveResult> {
  const {db, uid, kind, data} = params; const now = params.now ?? new Date(); const names = paths(kind);
  if (!isObject(data)) invalid('保存内容が不正です。');
  const mutationId = mutationKey(data.mutationId), fingerprint = careActionMutationFingerprint(data);
  const receipt = db.doc(`users/${uid}/${names.mutations}/${mutationId}`);
  const issuedSubjectId = randomUUID(), issuedRecordId = randomUUID();
  const result = await db.runTransaction(async tx => {
    const [receiptSnap, otherKindReceipt] = await Promise.all([tx.get(receipt), tx.get(db.doc(`users/${uid}/${paths(kind === 'weight' ? 'distance' : 'weight').mutations}/${mutationId}`))]);
    if (otherKindReceipt.exists) throw new HttpsError('already-exists', '同じmutation IDが別の記録で受理されています。');
    if (receiptSnap.exists) {
      if (receiptSnap.get('ownerUid') !== uid || receiptSnap.get('requestFingerprint') !== fingerprint) throw new HttpsError('already-exists', '同じmutation IDの内容が異なります。');
      return {...receiptSnap.get('result'), replayed: true} as MeasurementSaveResult;
    }
    const mutation = normalizeMeasurementMutation(kind, data, now);
    const sourceDay = db.doc(`users/${uid}/${names.days}/${mutation.originalDayKey}`), destDay = db.doc(`users/${uid}/${names.days}/${mutation.dayKey}`);
    const sourceCurrent = db.doc(`users/${uid}/${names.current}/${mutation.originalDayKey}`), destCurrent = db.doc(`users/${uid}/${names.current}/${mutation.dayKey}`);
    const moving = mutation.originalDayKey !== mutation.dayKey;
    const [sourceRouteSnap, beforeSnap, destRouteSnap, destSnap] = await Promise.all([tx.get(sourceDay), tx.get(sourceCurrent), moving ? tx.get(destDay) : Promise.resolve(null), moving ? tx.get(destCurrent) : Promise.resolve(null)]);
    const beforeDayRevision = revisionNumber(sourceRouteSnap.get('revision') ?? 0);
    if (mutation.expectedRevision !== beforeDayRevision) throw new HttpsError('aborted', '別の保存が先に完了しました。最新の記録を確認してください。');
    const identity = await planMainPetIdentity({db, tx, uid, expectedSubjectId: mutation.subjectId, issuedSubjectId});
    for (const snap of [sourceRouteSnap, beforeSnap, destRouteSnap, destSnap]) if (snap?.exists && ((snap.get('ownerUid') != null && snap.get('ownerUid') !== uid) || (snap.get('subjectId') != null && snap.get('subjectId') !== identity.subjectId))) throw new HttpsError('permission-denied', '記録の個体または所有者を確認できません。');
    if (beforeSnap.exists && beforeSnap.get('measurementHistorySchemaVersion') === 1 && !sourceRouteSnap.exists) throw new HttpsError('failed-precondition', '記録の履歴が見つかりません。');
    const legacy = beforeSnap.exists && beforeSnap.get('measurementHistorySchemaVersion') !== 1;
    if (legacy && mutation.operation === 'cancel') throw new HttpsError('failed-precondition', '旧記録は現在のハムスターの記録であることを確認して保存した後に取り消してください。');
    if (!beforeSnap.exists && sourceRouteSnap.get('status') === 'active') throw new HttpsError('failed-precondition', '有効な現在値が見つかりません。');
    if (legacy && !mutation.legacyConfirmed) throw new HttpsError('failed-precondition', '旧記録が現在のハムスターの記録であることを確認してください。');
    if (moving && (!beforeSnap.exists || destSnap?.exists || destRouteSnap?.get('status') === 'active')) throw new HttpsError(destSnap?.exists || destRouteSnap?.get('status') === 'active' ? 'already-exists' : 'not-found', '日付の訂正先に記録があるか、訂正元が見つかりません。');
    if (mutation.operation === 'cancel' && !beforeSnap.exists && sourceRouteSnap.get('status') !== 'cancelled') throw new HttpsError('not-found', '取消する記録がありません。');
    const continuing = beforeSnap.exists && !legacy;
    const recordId = continuing || (mutation.operation === 'cancel' && sourceRouteSnap.get('status') === 'cancelled') ? subjectKey(sourceRouteSnap.get('currentRecordId'))! : issuedRecordId;
    if (continuing && beforeSnap.get('recordId') !== recordId) throw new HttpsError('failed-precondition', '記録と履歴の対応を確認できません。');
    const ledger = db.doc(`users/${uid}/${names.history}/${recordId}`);
    const ledgerSnap = await tx.get(ledger);
    if (ledgerSnap.exists && (ledgerSnap.get('ownerUid') !== uid || ledgerSnap.get('subjectId') !== identity.subjectId || ledgerSnap.get('kind') !== kind || ledgerSnap.get('recordId') !== recordId)) throw new HttpsError('permission-denied', '履歴の個体または所有者を確認できません。');
    if (!continuing && mutation.operation === 'save' && ledgerSnap.exists) throw new HttpsError('already-exists', '記録識別子の作成が競合しました。');
    const history = await tx.get(ledger.collection('revisions').orderBy('recordRevision').limit(MEASUREMENT_HISTORY_TRANSACTION_LIMIT + 1));
    const rows = history.docs.map(doc => doc.data() as MeasurementRevision);
    const beforeRecordRevision = revisionNumber(ledgerSnap.get('recordRevision') ?? 0);
    if (history.size > MEASUREMENT_HISTORY_TRANSACTION_LIMIT || rows.length !== beforeRecordRevision || rows.some((row, index) => row.recordRevision !== index + 1 || row.ownerUid !== uid || row.subjectId !== identity.subjectId || row.recordId !== recordId)) throw new HttpsError('failed-precondition', '履歴の整合性を確認できません。');
    if (continuing && (!ledgerSnap.exists || ledgerSnap.get('status') !== 'active' || ledgerSnap.get('currentDayKey') !== mutation.originalDayKey || beforeSnap.get('recordRevision') !== beforeRecordRevision)) throw new HttpsError('failed-precondition', '有効な記録履歴を確認できません。');
    let values = mutation.values;
    const previous = rows.length ? rows[rows.length - 1] : null;
    if (kind === 'distance' && values?.mode === 'rotations') {
      let wheelDiameterCm: number | null, diameterProvenance: string;
      if (mutation.diameterCorrection) {wheelDiameterCm = mutation.wheelDiameterCm; diameterProvenance = 'explicit_diameter_correction';}
      else if (beforeSnap.exists) {wheelDiameterCm = diameter(beforeSnap.get('wheelDiameterCm')); diameterProvenance = previous?.values?.diameterProvenance as string ?? 'recorded_original';}
      else {const environment = await tx.get(db.doc(`users/${uid}/breeding_environments/main_env`)); wheelDiameterCm = diameter(environment.get('wheelDiameter')); diameterProvenance = 'current_environment_at_submission';}
      if (wheelDiameterCm === null) throw new HttpsError('failed-precondition', 'この記録の回し車の直径が不明です。直径を確認して明示的に訂正してください。');
      values = {...values, wheelDiameterCm, distance: distanceFromRotations(values.rotations as number, wheelDiameterCm), diameterProvenance};
    }
    if (mutation.operation !== 'cancel') {
      const [billing, trial] = await Promise.all([tx.get(db.doc(`users/${uid}/billing/subscription`)), tx.get(db.doc(`users/${uid}/feature_access/initial_trial_v2`))]);
      if (!hasCareRecordAccess(billing.data() ?? null, trial.data() ?? null, params.now ? now : new Date())) throw new HttpsError('permission-denied', '記録には有料プランまたは有効な無料体験が必要です。');
    }
    // Free text remains in the display projection; history contains only the numeric evidence.
    const historyValues = kind === 'weight' && values ? {weightGrams: values.weightGrams} : values;
    const memoChanged = kind === 'weight' && mutation.operation === 'save' && (beforeSnap.get('memo') ?? '') !== values?.memo;
    const changed = legacy || (!beforeSnap.exists && mutation.operation === 'save') || moving || (mutation.operation === 'cancel' ? beforeSnap.exists : !same(previous?.values, historyValues) || !same(previous?.timing, mutation.timing) || memoChanged);
    const recordRevision = beforeRecordRevision + (changed ? 1 : 0);
    const sourceRevision = beforeDayRevision + (changed ? 1 : 0);
    const destRevision = moving ? revisionNumber(destRouteSnap?.get('revision') ?? 0) + 1 : sourceRevision;
    const saved: MeasurementSaveResult = {saved: true, replayed: false, changed, kind, subjectId: identity.subjectId, dayKey: mutation.dayKey, originalDayKey: mutation.originalDayKey, recordId, revision: destRevision, recordRevision, mutationId, recordStatus: mutation.operation === 'cancel' ? 'cancelled' : 'active', projection: beforeSnap.data() ?? null};
    const stamp = admin.firestore.FieldValue.serverTimestamp();
    if (changed) {
      if (rows.length >= MEASUREMENT_HISTORY_TRANSACTION_LIMIT || sourceRevision > MEASUREMENT_HISTORY_TRANSACTION_LIMIT || destRevision > MEASUREMENT_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '記録履歴の上限に達しました。');
      const sourceIds = sourceRouteSnap.get('recordIds') ?? [];
      const destIds = destRouteSnap?.get('recordIds') ?? [];
      if (!Array.isArray(sourceIds) || !Array.isArray(destIds) || sourceIds.length >= MEASUREMENT_HISTORY_TRANSACTION_LIMIT || destIds.length >= MEASUREMENT_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', 'この日の履歴の上限に達しました。');
      const legacySame = legacy && same(projectionValues(kind, beforeSnap.data()!), kind === 'weight' ? values : {...values, diameterProvenance: diameter(beforeSnap.get('wheelDiameterCm')) === null ? 'legacy_unknown' : 'recorded_original'});
      const origin = previous?.origin ?? (legacy ? legacySame ? 'confirmed_legacy_snapshot' : 'legacy_unknown_original' : 'explicit_measurement');
      const operation = mutation.operation === 'cancel' ? 'cancel' : moving ? 'date_correction' : legacySame ? 'confirmed_legacy_snapshot' : continuing || legacy ? 'correction' : 'create';
      const dayRevisions = {[mutation.originalDayKey]: sourceRevision, ...(moving ? {[mutation.dayKey]: destRevision} : {})};
      // This describes the accepted request, including a confirmed legacy snapshot, not the unknowable original entry route.
      const inputRoute: MeasurementRevision['inputRoute'] = mutation.operation === 'cancel' ? 'manual_cancel' : kind === 'weight' ? 'weight_manual' : values?.mode === 'rotations' ? 'wheel_rotations_manual' : 'distance_manual';
      const row: MeasurementRevision = {schemaVersion: 1, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId, kind, recordId, recordRevision, previousRecordRevision: beforeRecordRevision, dayKey: mutation.dayKey, previousDayKey: moving ? mutation.originalDayKey : null, dayRevisions, operation, origin, acceptedAt: stamp, timing: mutation.timing, values: historyValues, valueUnits: kind === 'weight' ? {weightGrams: 'g'} : {distance: 'm', rotations: 'count', wheelDiameterCm: 'cm'}, inputRoute, mutationId, inputUiVersion: MEASUREMENT_HISTORY_INPUT_VERSION, researchConsentStatus: 'not_assessed'};
      tx.create(ledger.collection('revisions').doc(revisionId(recordRevision)), row);
      // Daily acceptance indexes are immutable too, so a later day binding cannot hide old cutoff evidence.
      tx.create(sourceDay.collection('revisions').doc(revisionId(sourceRevision)), row);
      if (moving) tx.create(destDay.collection('revisions').doc(revisionId(destRevision)), row);
      tx.set(ledger, {schemaVersion: 1, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId, kind, recordId, recordRevision, currentDayKey: mutation.dayKey, status: saved.recordStatus, origin, hadLegacyProjection: ledgerSnap.get('hadLegacyProjection') === true || legacy, historyStartedAt: ledgerSnap.get('historyStartedAt') ?? stamp, acceptedAt: stamp, updatedAt: stamp, researchConsentStatus: 'not_assessed'}, {merge: true});
      const routeBase = {schemaVersion: 1, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId, kind, currentRecordId: recordId, acceptedAt: stamp, updatedAt: stamp, researchConsentStatus: 'not_assessed'};
      tx.set(sourceDay, {...routeBase, dayKey: mutation.originalDayKey, revision: sourceRevision, recordIds: [...new Set([...sourceIds, recordId])], status: moving ? 'moved' : saved.recordStatus, historyStartedAt: sourceRouteSnap.get('historyStartedAt') ?? stamp, hadLegacyProjection: sourceRouteSnap.get('hadLegacyProjection') === true || legacy});
      if (moving) tx.set(destDay, {...routeBase, dayKey: mutation.dayKey, revision: destRevision, recordIds: [...new Set([...destIds, recordId])], status: 'active', historyStartedAt: destRouteSnap?.get('historyStartedAt') ?? stamp, hadLegacyProjection: destRouteSnap?.get('hadLegacyProjection') === true});
      if (mutation.operation === 'cancel') {saved.projection = null; if (beforeSnap.exists) tx.delete(sourceCurrent);}
      else {
        const projected = {...values, dayKey: mutation.dayKey, date: admin.firestore.Timestamp.fromDate(mutation.date), ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId, measurementHistorySchemaVersion: 1, kind, recordId, revision: destRevision, recordRevision, timing: mutation.timing, projectionMutationOperation: operation, acceptedAt: stamp, updatedAt: stamp, createdAt: beforeSnap.get('createdAt') ?? stamp, researchConsentStatus: 'not_assessed'};
        saved.projection = projected; tx.set(destCurrent, projected); if (moving) tx.delete(sourceCurrent);
      }
      commitIdentityIntroduction(tx, identity, uid, stamp);
      tx.set(db.doc(`users/${uid}`), {has_subcollections: true}, {merge: true});
    } else if (mutation.operation === 'cancel') saved.projection = null;
    tx.create(receipt, {schemaVersion: 1, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId, kind, recordId, requestFingerprint: fingerprint, acceptedAt: stamp, result: saved, researchConsentStatus: 'not_assessed'});
    return saved;
  });
  const committed = await receipt.get(); const accepted = dateOf(committed.get('acceptedAt')), nanos = measurementEpochNanoseconds(committed.get('acceptedAt'));
  if (!accepted || nanos === null) throw new HttpsError('internal', '受理日時を確認できません。同じ内容を再送してください。');
  return {...result, projection: publicData(committed.get('result.projection')) as Record<string, unknown> | null, acceptedAt: accepted.toISOString(), acceptedAtEpochNanoseconds: nanos.toString()};
}
export async function readMeasurementHistory(params: {db: admin.firestore.Firestore; uid: string; kind: MeasurementKind; dayKey: string; knowledgeCutoff?: bigint}) {
  const {db, uid, kind, dayKey, knowledgeCutoff} = params; const names = paths(kind);
  if (!isDateKey(dayKey)) invalid('対象日が不正です。');
  return db.runTransaction(async tx => {
    const [route, current] = await Promise.all([tx.get(db.doc(`users/${uid}/${names.days}/${dayKey}`)), tx.get(db.doc(`users/${uid}/${names.current}/${dayKey}`))]);
    if (route.exists && route.get('ownerUid') !== uid) throw new HttpsError('permission-denied', '記録の所有者を確認できません。');
    const ids: unknown = route.get('recordIds') ?? [];
    if (!Array.isArray(ids) || ids.length > MEASUREMENT_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '履歴読取りの上限を超えています。');
    if (ids.some(id => typeof id !== 'string' || !/^[a-zA-Z0-9_-]{16,128}$/.test(id))) throw new HttpsError('failed-precondition', '履歴の対応を確認できません。');
    const history = await tx.get(route.ref.collection('revisions').orderBy(`dayRevisions.${dayKey}`).limit(MEASUREMENT_HISTORY_TRANSACTION_LIMIT + 1));
    if (history.size > MEASUREMENT_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '履歴読取りの上限を超えています。');
    const revisions = history.docs.map(doc => doc.data() as MeasurementRevision);
    if (revisions.length !== (route.get('revision') ?? 0) || revisions.some((row, index) => row.ownerUid !== uid || row.subjectId !== route.get('subjectId') || !ids.includes(row.recordId) || row.dayRevisions[dayKey] !== index + 1)) throw new HttpsError('failed-precondition', '履歴の整合性を確認できません。');
    const state = resolveMeasurementHistory({dayKey, revisions, knowledgeCutoff, historyStartedAt: route.get('historyStartedAt'), hadLegacyProjection: route.get('hadLegacyProjection') === true || (!route.exists && current.exists)});
    const rowData = (row: MeasurementRevision | null) => row === null ? null : {...publicData(row) as Record<string, unknown>, revision: row.dayRevisions[dayKey], acceptedAtEpochNanoseconds: measurementEpochNanoseconds(row.acceptedAt)?.toString() ?? null};
    return {kind, dayKey, recordId: state.current?.recordId ?? state.revisions[state.revisions.length - 1]?.recordId ?? null, subjectId: state.revisions[0]?.subjectId ?? null, historyExists: state.revisions.length > 0, knowledgeCutoffEpochNanoseconds: knowledgeCutoff?.toString() ?? null, ...state, current: rowData(state.current), revisions: state.revisions.map(rowData)};
  });
}
export const saveWeightRecord = onCall({region: 'asia-northeast1'}, async request => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  return saveMeasurementMutation({db: admin.firestore(), uid: request.auth.uid, kind: 'weight', data: request.data});
});
export const saveDistanceRecord = onCall({region: 'asia-northeast1'}, async request => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  return saveMeasurementMutation({db: admin.firestore(), uid: request.auth.uid, kind: 'distance', data: request.data});
});
export const readMeasurementHistoryAt = onCall({region: 'asia-northeast1'}, async request => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  if (!isObject(request.data)) invalid('読取り内容が不正です。');
  onlyFields(request.data, ['kind', 'dayKey', 'knowledgeCutoff', 'knowledgeCutoffEpochNanoseconds']);
  if ((request.data.kind !== 'weight' && request.data.kind !== 'distance') || typeof request.data.dayKey !== 'string') invalid('対象の記録が不正です。');
  return readMeasurementHistory({db: admin.firestore(), uid: request.auth.uid, kind: request.data.kind, dayKey: request.data.dayKey, knowledgeCutoff: parseMeasurementCutoff(request.data)});
});
