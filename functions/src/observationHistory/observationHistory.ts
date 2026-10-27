import {randomUUID} from 'node:crypto';
import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {careActionMutationFingerprint, hasCareRecordAccess} from '../careActions/careActions';
import {formatDateKey, isDateKey} from '../health/dateKey';
import {OBSERVATION_CATALOG_VERSION, activeObservationItems, observationCatalog, resolveObservationId} from '../health/observationCatalog';
import {commitIdentityIntroduction, dateOf, explicitInstant, invalid, isObject, MAIN_PET_SLOT, mutationKey, onlyFields, planMainPetIdentity, revisionNumber, subjectKey} from '../petIdentity/petIdentity';

export const OBSERVATION_HISTORY_SCHEMA_VERSION = 1;
export const OBSERVATION_HISTORY_INPUT_VERSION = 'daily_checkin_history_v1';
export const OBSERVATION_HISTORY_TRANSACTION_LIMIT = 2000;
export interface ObservationTiming {
  timePrecision: 'unknown' | 'date_only' | 'instant';
  dateKey: string | null;
  observedAt: string | null;
  confirmation: 'unknown' | 'date_confirmed' | 'now_confirmed' | 'time_confirmed';
  clockSource: 'unknown' | 'user_reported';
  timeZone: 'Asia/Tokyo';
}
export interface ObservationAnswer {
  schemaVersion: 2;
  condition: 'normal' | 'slightlyConcerned' | 'veryConcerned';
  concernTags: string[];
  observationLevels: Record<string, 'normal' | 'changed' | 'concerning'>;
  memo: string;
  observationCatalogVersion: string;
  observationResponseMode: 'overall_with_selected_tags';
  answerProvenance: {overall: 'explicit_submission'; selectedTags: 'explicit_selection'; normalLevels: 'automatic_normal'};
}
export interface ObservationMutation {
  dayKey: string; date: Date; subjectId: string | null; expectedRevision: number; mutationId: string;
  operation: 'new_observation' | 'correction' | 'cancel';
  targetEventId: string | null; targetRevision: number | null;
  timing: ObservationTiming | null; answer: ObservationAnswer | null;
  inputUiVersion: typeof OBSERVATION_HISTORY_INPUT_VERSION;
}
export interface ObservationRevision {
  schemaVersion: number; ownerUid: string; petId: typeof MAIN_PET_SLOT; subjectId: string; dayKey: string;
  revision: number; previousRevision: number; eventId: string;
  operation: ObservationMutation['operation']; origin: 'explicit_observation' | 'legacy_unknown_original';
  targetRevision: number | null; acceptedAt: unknown; timing: ObservationTiming | null; answer: ObservationAnswer | null;
  mutationId: string; inputUiVersion: string; researchConsentStatus: 'not_assessed';
}
export interface ObservationSaveResult {
  saved: true; replayed: boolean; changed: boolean; subjectId: string; dayKey: string; revision: number;
  mutationId: string; eventId: string | null; recordStatus: 'active' | 'cancelled'; acceptedAt?: string;
  projection: Record<string, unknown> | null;
}
const revisionId = (revision: number) => String(revision).padStart(10, '0');
const same = (a: unknown, b: unknown) => careActionMutationFingerprint(a) === careActionMutationFingerprint(b);
function acceptanceMillis(value: unknown): number | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value.getTime() : null;
  if (isObject(value) && typeof value.toMillis === 'function') {
    const millis = (value.toMillis as () => number)(); return Number.isFinite(millis) ? millis : null;
  }
  return null;
}
function knownAt(value: unknown, cutoff: Date | undefined): boolean {
  if (!cutoff) return acceptanceMillis(value) !== null;
  if (isObject(value) && typeof value.seconds === 'number' && typeof value.nanoseconds === 'number') {
    return BigInt(value.seconds) * BigInt(1000000000) + BigInt(value.nanoseconds) <= BigInt(cutoff.getTime()) * BigInt(1000000);
  }
  const accepted = acceptanceMillis(value); return accepted != null && accepted <= cutoff.getTime();
}
function publicData(value: unknown): unknown {
  const date = dateOf(value); if (date) return date.toISOString();
  if (Array.isArray(value)) return value.map(publicData);
  return isObject(value) ? Object.fromEntries(Object.entries(value).map(([key, item]) => [key, publicData(item)])) : value;
}
function timing(value: unknown, dayKey: string, now: Date): ObservationTiming {
  if (!isObject(value)) invalid('観察した時期を確認してください。');
  onlyFields(value, ['precision', 'dateKey', 'observedAt', 'confirmation']);
  if (value.precision === 'unknown') {
    if (value.confirmation !== 'unknown' || value.dateKey != null || value.observedAt != null) invalid('時期不明の内容が不正です。');
    return {timePrecision: 'unknown', dateKey: null, observedAt: null, confirmation: 'unknown', clockSource: 'unknown', timeZone: 'Asia/Tokyo'};
  }
  if (value.precision === 'date_only') {
    if (value.confirmation !== 'date_confirmed' || value.dateKey !== dayKey || value.observedAt != null) invalid('観察日を確認してください。');
    return {timePrecision: 'date_only', dateKey: dayKey, observedAt: null, confirmation: 'date_confirmed', clockSource: 'user_reported', timeZone: 'Asia/Tokyo'};
  }
  if (value.precision !== 'instant' || !['now_confirmed', 'time_confirmed'].includes(String(value.confirmation))) invalid('観察時刻の確認方法が不正です。');
  const observed = explicitInstant(value.observedAt);
  if (!observed || observed.getTime() > now.getTime() || formatDateKey(observed) !== dayKey || (value.dateKey != null && value.dateKey !== dayKey)) invalid('観察時刻が不正です。');
  return {timePrecision: 'instant', dateKey: dayKey, observedAt: observed.toISOString(), confirmation: value.confirmation as ObservationTiming['confirmation'], clockSource: 'user_reported', timeZone: 'Asia/Tokyo'};
}
/** Automatic per-item normal is generated as before, and explicitly marked as non-answer evidence. */
export function normalizeObservationMutation(value: unknown, now: Date): ObservationMutation {
  if (!isObject(value)) invalid('保存内容が不正です。');
  onlyFields(value, ['dayKey', 'date', 'subjectId', 'expectedRevision', 'mutationId', 'operation', 'targetEventId', 'targetRevision', 'timing', 'condition', 'concernTags', 'memo', 'observationCatalogVersion', 'inputUiVersion']);
  if (typeof value.dayKey !== 'string' || !isDateKey(value.dayKey) || value.dayKey > formatDateKey(now)) invalid('対象日が不正です。');
  const date = explicitInstant(value.date);
  if (!date || formatDateKey(date) !== value.dayKey) invalid('表示用の日付が不正です。');
  const expectedRevision = revisionNumber(value.expectedRevision), mutationId = mutationKey(value.mutationId), subjectId = subjectKey(value.subjectId, true);
  if (!['new_observation', 'correction', 'cancel'].includes(String(value.operation)) || value.inputUiVersion !== OBSERVATION_HISTORY_INPUT_VERSION) invalid('保存操作が不正です。');
  const operation = value.operation as ObservationMutation['operation'];
  const targetEventId = value.targetEventId == null ? null : subjectKey(value.targetEventId);
  const targetRevision = value.targetRevision == null ? null : revisionNumber(value.targetRevision);
  if (operation === 'new_observation' && (targetEventId !== null || targetRevision !== null)) invalid('新しい観察に訂正対象は指定できません。');
  if (operation !== 'new_observation' && targetRevision === null) invalid('訂正・取消の対象revisionが必要です。');
  if (operation === 'cancel') {
    if (value.condition != null || value.concernTags != null || value.memo != null || value.timing != null) invalid('取消に新しい回答は不要です。');
    return {dayKey: value.dayKey, date, expectedRevision, subjectId, mutationId, operation, targetEventId, targetRevision, timing: null, answer: null, inputUiVersion: OBSERVATION_HISTORY_INPUT_VERSION};
  }
  if (!['normal', 'slightlyConcerned', 'veryConcerned'].includes(String(value.condition)) || !Array.isArray(value.concernTags) || value.concernTags.some(id => typeof id !== 'string' || !resolveObservationId(id))) invalid('観察回答が不正です。');
  if (value.observationCatalogVersion !== OBSERVATION_CATALOG_VERSION) invalid('観察項目が更新されています。最新版で確認してください。');
  const condition = value.condition as ObservationAnswer['condition'];
  const concernTags = [...new Set((value.concernTags as string[]).map(id => resolveObservationId(id)!))].sort((a, b) => (observationCatalog.find(item => item.id === a)!.order - observationCatalog.find(item => item.id === b)!.order));
  if (condition === 'normal' && concernTags.length) invalid('いつも通りの回答に気になる項目は指定できません。');
  const memo = value.memo ?? '';
  if (typeof memo !== 'string' || memo.length > 10000) invalid('メモが長すぎます。');
  const observationLevels: ObservationAnswer['observationLevels'] = Object.fromEntries(activeObservationItems().filter(item => item.defaultNormal).map(item => [item.id, 'normal']));
  for (const id of concernTags) observationLevels[id] = condition === 'veryConcerned' ? 'concerning' : 'changed';
  return {dayKey: value.dayKey, date, expectedRevision, subjectId, mutationId, operation, targetEventId, targetRevision, timing: timing(value.timing, value.dayKey, now),
    answer: {schemaVersion: 2, condition, concernTags, observationLevels, memo: memo.trim(), observationCatalogVersion: OBSERVATION_CATALOG_VERSION, observationResponseMode: 'overall_with_selected_tags',
      answerProvenance: {overall: 'explicit_submission', selectedTags: 'explicit_selection', normalLevels: 'automatic_normal'}}, inputUiVersion: OBSERVATION_HISTORY_INPUT_VERSION};
}
export function resolveObservationHistory(params: {
  revisions: readonly ObservationRevision[]; knowledgeCutoff?: Date; historyStartedAt?: unknown; hadLegacyProjection?: boolean;
}): {
  events: Array<{eventId: string; firstKnownRevision: number; origin: ObservationRevision['origin']; original: ObservationRevision | null; effective: ObservationRevision; cancelled: boolean}>;
  current: ObservationRevision | null; quality: {reasons: string[]; researchConsentStatus: 'not_assessed'};
} {
  const rows = params.revisions.filter(row => knownAt(row.acceptedAt, params.knowledgeCutoff)).sort((a, b) => a.revision - b.revision);
  const events = new Map<string, {eventId: string; firstKnownRevision: number; origin: ObservationRevision['origin']; original: ObservationRevision | null; effective: ObservationRevision; cancelled: boolean}>();
  for (const row of rows) {
    const previous = events.get(row.eventId);
    const original = previous?.original ?? (row.operation === 'new_observation' && row.origin === 'explicit_observation' ? row : null);
    events.set(row.eventId, {eventId: row.eventId, firstKnownRevision: previous?.firstKnownRevision ?? row.revision, origin: row.origin, original, effective: row, cancelled: row.operation === 'cancel'});
  }
  const list = [...events.values()].sort((a, b) => a.firstKnownRevision - b.firstKnownRevision);
  // The current daily view selects the last still-active logical observation, not the last correction or the worst answer.
  const active = list.filter(event => !event.cancelled && event.effective.answer != null);
  const reasons: string[] = [];
  if (params.hadLegacyProjection) reasons.push('legacy_original_unrecoverable');
  if (params.historyStartedAt && !knownAt(params.historyStartedAt, params.knowledgeCutoff)) reasons.push('before_history_introduction');
  if (!params.historyStartedAt && !rows.length) reasons.push('no_accepted_observation_history');
  if (rows.some(row => row.timing?.timePrecision === 'unknown')) reasons.push('observation_time_unknown');
  if (rows.some(row => row.timing?.timePrecision === 'date_only')) reasons.push('observation_time_date_only');
  return {events: list, current: active.length ? active[active.length - 1].effective : null, quality: {reasons, researchConsentStatus: 'not_assessed'}};
}
/** One current-day projection plus independent immutable event/revision/receipt ledger; no direct rewards or analysis writes. */
export async function saveObservationMutation(params: {db: admin.firestore.Firestore; uid: string; data: unknown; now?: Date}): Promise<ObservationSaveResult> {
  const {db, uid, data} = params; const now = params.now ?? new Date();
  if (!isObject(data) || typeof data.dayKey !== 'string' || !isDateKey(data.dayKey)) invalid('保存識別子が不正です。');
  const mutationId = mutationKey(data.mutationId), fingerprint = careActionMutationFingerprint(data);
  const ledger = db.doc(`users/${uid}/observation_days/${data.dayKey}`), projection = db.doc(`users/${uid}/daily_checkins/${data.dayKey}`);
  const receipt = ledger.collection('mutations').doc(mutationId);
  // Issued once per invocation and reused by Firestore's transaction retries.
  const issuedSubjectId = randomUUID(), issuedEventId = randomUUID();
  const result = await db.runTransaction(async tx => {
    const [ledgerSnap, currentSnap, receiptSnap] = await Promise.all([tx.get(ledger), tx.get(projection), tx.get(receipt)]);
    if (receiptSnap.exists) {
      if (receiptSnap.get('requestFingerprint') !== fingerprint) throw new HttpsError('already-exists', '同じmutation IDの内容が異なります。');
      return {...receiptSnap.get('result'), replayed: true} as ObservationSaveResult;
    }
    const mutation = normalizeObservationMutation(data, now);
    const identity = await planMainPetIdentity({db, tx, uid, expectedSubjectId: mutation.subjectId, issuedSubjectId});
    const boundSubject = ledgerSnap.get('subjectId') ?? currentSnap.get('subjectId');
    if (boundSubject != null && boundSubject !== identity.subjectId) throw new HttpsError('failed-precondition', 'この日の記録は別の個体に結び付いています。上書きできません。');
    const beforeRevision = revisionNumber(ledgerSnap.get('revision') ?? 0);
    if (mutation.expectedRevision !== beforeRevision) throw new HttpsError('aborted', '別の保存が先に完了しました。最新の記録を確認してください。');
    const history = await tx.get(ledger.collection('revisions').orderBy('revision').limit(OBSERVATION_HISTORY_TRANSACTION_LIMIT + 1));
    if (history.size > OBSERVATION_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '観察履歴が多いため保存を停止しました。');
    const rows = history.docs.map(doc => doc.data() as ObservationRevision);
    if (rows.length !== beforeRevision || rows.some((row, index) => row.revision !== index + 1 || row.ownerUid !== uid || row.subjectId !== identity.subjectId)) throw new HttpsError('failed-precondition', '履歴の整合性を確認できません。');
    if (currentSnap.get('observationHistorySchemaVersion') === OBSERVATION_HISTORY_SCHEMA_VERSION && !ledgerSnap.exists) throw new HttpsError('failed-precondition', '記録の履歴が見つかりません。');
    const hadLegacy = ledgerSnap.exists ? ledgerSnap.get('hadLegacyProjection') === true : currentSnap.exists && currentSnap.get('observationHistorySchemaVersion') !== OBSERVATION_HISTORY_SCHEMA_VERSION;
    const beforeState = resolveObservationHistory({revisions: rows});
    let target = mutation.targetEventId ? beforeState.events.find(event => event.eventId === mutation.targetEventId) : undefined;
    let eventId: string, origin: ObservationRevision['origin'], changed = true;
    if (mutation.operation === 'new_observation') {
      const latest = beforeState.current;
      const previousSame = latest != null && latest.origin === 'explicit_observation' && same(latest.answer, mutation.answer) && same(latest.timing, mutation.timing);
      changed = !previousSame;
      eventId = previousSame ? latest!.eventId : issuedEventId;
      origin = 'explicit_observation';
    } else {
      if (target) {
        if (target.effective.revision !== mutation.targetRevision) throw new HttpsError('aborted', '訂正対象が更新されています。');
        if (target.cancelled && mutation.operation === 'correction') throw new HttpsError('failed-precondition', '取消済みの観察は訂正できません。新しい観察を記録してください。');
        eventId = target.eventId; origin = target.origin;
        changed = mutation.operation === 'cancel' ? !target.cancelled : !same(target.effective.answer, mutation.answer) || !same(target.effective.timing, mutation.timing);
      } else {
        if (mutation.targetEventId !== null || mutation.targetRevision !== 0 || ledgerSnap.exists || !currentSnap.exists || !hadLegacy) throw new HttpsError('not-found', '訂正・取消対象の観察がありません。');
        // Preserve that the original is unrecoverable. This is not a reconstructed initial answer.
        eventId = issuedEventId; origin = 'legacy_unknown_original';
      }
    }
    if (mutation.operation !== 'cancel') {
      const [billing, trial] = await Promise.all([tx.get(db.doc(`users/${uid}/billing/subscription`)), tx.get(db.doc(`users/${uid}/feature_access/initial_trial_v2`))]);
      if (!hasCareRecordAccess(billing.data() ?? null, trial.data() ?? null, new Date(Math.max(now.getTime(), params.now ? now.getTime() : Date.now())))) throw new HttpsError('permission-denied', '記録には有料プランまたは有効な無料体験が必要です。');
    }
    const stamp = admin.firestore.FieldValue.serverTimestamp();
    const revision = beforeRevision + (changed ? 1 : 0);
    const saved: ObservationSaveResult = {saved: true, replayed: false, changed, subjectId: identity.subjectId, dayKey: mutation.dayKey, revision, mutationId,
      eventId, recordStatus: 'active', projection: currentSnap.data() ?? null};
    if (changed && rows.length >= OBSERVATION_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '観察履歴の上限に達しました。');
    if (changed) {
      const next: ObservationRevision = {schemaVersion: OBSERVATION_HISTORY_SCHEMA_VERSION, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId,
        dayKey: mutation.dayKey, revision, previousRevision: beforeRevision, eventId, operation: mutation.operation, origin, targetRevision: mutation.targetRevision,
        acceptedAt: stamp, timing: mutation.timing, answer: mutation.answer, mutationId, inputUiVersion: mutation.inputUiVersion, researchConsentStatus: 'not_assessed'};
      // Pending server timestamps have no value until commit. Revision order is the authoritative per-day acceptance order.
      const nextForProjection = {...next, acceptedAt: new Date(Math.max(now.getTime(), ...rows.map(row => dateOf(row.acceptedAt)?.getTime() ?? 0)) + 1)};
      const state = resolveObservationHistory({revisions: [...rows, nextForProjection]});
      const selected = state.current;
      saved.recordStatus = selected ? 'active' : 'cancelled';
      tx.create(ledger.collection('revisions').doc(revisionId(revision)), next);
      if (!target && (mutation.operation === 'new_observation' || origin === 'legacy_unknown_original')) tx.create(ledger.collection('events').doc(eventId), {
        schemaVersion: OBSERVATION_HISTORY_SCHEMA_VERSION, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId, dayKey: mutation.dayKey,
        eventId, origin, firstKnownRevision: revision, originalRevision: mutation.operation === 'new_observation' ? revision : null,
        originalAnswer: mutation.operation === 'new_observation' ? mutation.answer : null, originalTiming: mutation.operation === 'new_observation' ? mutation.timing : null,
        acceptedAt: stamp, researchConsentStatus: 'not_assessed'});
      tx.set(ledger, {schemaVersion: OBSERVATION_HISTORY_SCHEMA_VERSION, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId,
        dayKey: mutation.dayKey, revision, hadLegacyProjection: hadLegacy, historyStartedAt: ledgerSnap.get('historyStartedAt') ?? stamp,
        currentEventId: selected?.eventId ?? null, currentEventRevision: selected?.revision ?? null, acceptedAt: stamp, updatedAt: stamp,
        projectionCreatedAt: ledgerSnap.get('projectionCreatedAt') ?? currentSnap.get('createdAt') ?? stamp}, {merge: true});
      if (selected) {
        const isNext = selected.revision === revision;
        const projected = {schemaVersion: 2, ...selected.answer, dayKey: mutation.dayKey, date: admin.firestore.Timestamp.fromDate(mutation.date),
          ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId, observationHistorySchemaVersion: OBSERVATION_HISTORY_SCHEMA_VERSION,
          revision, eventId: selected.eventId, eventRevision: selected.revision, eventOrigin: selected.origin, timing: selected.timing,
          projectionMutationOperation: mutation.operation,
          eventAcceptedAt: isNext ? stamp : selected.acceptedAt, acceptedAt: stamp, updatedAt: stamp,
          createdAt: ledgerSnap.get('projectionCreatedAt') ?? currentSnap.get('createdAt') ?? stamp,
          inputUiVersion: mutation.inputUiVersion, researchConsentStatus: 'not_assessed'};
        saved.projection = projected;
        tx.set(projection, projected);
      } else {
        saved.projection = null;
        if (currentSnap.exists) tx.delete(projection);
      }
      commitIdentityIntroduction(tx, identity, uid, stamp);
      tx.set(db.doc(`users/${uid}`), {has_subcollections: true}, {merge: true});
    } else {
      saved.recordStatus = beforeState.current ? 'active' : 'cancelled';
    }
    tx.create(receipt, {schemaVersion: OBSERVATION_HISTORY_SCHEMA_VERSION, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId: identity.subjectId,
      requestFingerprint: fingerprint, acceptedAt: stamp, result: saved});
    return saved;
  });
  const committedReceipt = await receipt.get();
  const accepted = dateOf(committedReceipt.get('acceptedAt'));
  if (!accepted) throw new HttpsError('internal', '受理日時を確認できません。同じ内容を再送してください。');
  return {...result, projection: publicData(committedReceipt.get('result.projection')) as Record<string, unknown> | null, acceptedAt: accepted.toISOString()};
}
export async function readObservationHistoryAt(params: {db: admin.firestore.Firestore; uid: string; dayKey: string; knowledgeCutoff?: Date}): Promise<Record<string, unknown>> {
  const {db, uid, dayKey, knowledgeCutoff} = params;
  if (!isDateKey(dayKey)) invalid('対象日が不正です。');
  if (knowledgeCutoff && !Number.isFinite(knowledgeCutoff.getTime())) invalid('知識締切が不正です。');
  const ledger = db.doc(`users/${uid}/observation_days/${dayKey}`);
  // A transaction supplies one consistent ledger/revision view during concurrent saves.
  return db.runTransaction(async tx => {
    const [root, current] = await Promise.all([tx.get(ledger), tx.get(db.doc(`users/${uid}/daily_checkins/${dayKey}`))]);
    const rows = await tx.get(ledger.collection('revisions').orderBy('revision').limit(OBSERVATION_HISTORY_TRANSACTION_LIMIT + 1));
    if (rows.size > OBSERVATION_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '履歴読取りの上限を超えています。');
    const state = resolveObservationHistory({revisions: rows.docs.map(doc => doc.data() as ObservationRevision), knowledgeCutoff,
      historyStartedAt: root.get('historyStartedAt'), hadLegacyProjection: root.get('hadLegacyProjection') === true || (!root.exists && current.exists)});
    const knownRows = rows.docs.map(doc => doc.data() as ObservationRevision).filter(row => knownAt(row.acceptedAt, knowledgeCutoff));
    const precision = (row: ObservationRevision | null) => {
      if (!row) return null;
      const accepted = row.acceptedAt;
      return {...publicData(row) as Record<string, unknown>, acceptedAtEpochNanoseconds: accepted instanceof admin.firestore.Timestamp
        ? (BigInt(accepted.seconds) * BigInt(1000000000) + BigInt(accepted.nanoseconds)).toString()
        : dateOf(accepted) ? (BigInt(dateOf(accepted)!.getTime()) * BigInt(1000000)).toString() : null};
    };
    return {dayKey, subjectId: knownRows[0]?.subjectId ?? null, latestRevision: knownRows[knownRows.length - 1]?.revision ?? 0, historyExists: knownRows.length > 0,
      knowledgeCutoff: knowledgeCutoff?.toISOString() ?? null, ...publicData(state) as Record<string, unknown>,
      events: state.events.map(event => ({...event, original: precision(event.original), effective: precision(event.effective)})), current: precision(state.current)};
  });
}
export const saveDailyCheckin = onCall({region: 'asia-northeast1'}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  return saveObservationMutation({db: admin.firestore(), uid, data: request.data});
});
export const readDailyCheckinHistoryAt = onCall({region: 'asia-northeast1'}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  if (!isObject(request.data)) invalid('読取り内容が不正です。');
  onlyFields(request.data, ['dayKey', 'knowledgeCutoff']);
  if (typeof request.data.dayKey !== 'string') invalid('対象日が不正です。');
  const cutoff = request.data.knowledgeCutoff == null ? undefined : explicitInstant(request.data.knowledgeCutoff);
  if (cutoff === null) invalid('知識締切が不正です。');
  return readObservationHistoryAt({db: admin.firestore(), uid, dayKey: request.data.dayKey, knowledgeCutoff: cutoff});
});
