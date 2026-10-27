import {createHash} from 'node:crypto';
import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {formatDateKey, isDateKey} from '../health/dateKey';

export const ENVIRONMENT_HISTORY_SCHEMA_VERSION = 1;
/** Bounded transaction cost; reject rather than silently truncate the timeline. */
export const ENVIRONMENT_HISTORY_TRANSACTION_LIMIT = 2000;
export const ENVIRONMENT_VALUE_FIELDS = ['cageWidth', 'cageDepth', 'cageHeight', 'beddingThickness', 'wheelDiameter', 'temperatureControl', 'accessoryTags'] as const;
const numericFields = ['cageWidth', 'cageDepth', 'cageHeight', 'beddingThickness', 'wheelDiameter'];
const auxiliaryFields = ['accessoryNote', 'accessories'];
type RawValues = Record<string, string | number | string[] | null>;
export interface EnvironmentValue {value: number | string | string[] | null; unit: 'cm' | 'cm2' | null; quality: 'known' | 'unknown' | 'invalid';}
export interface EnvironmentEffectiveTime {precision: 'unknown' | 'date_only' | 'instant'; dateKey: string | null; occurredAt: string | null;}
export interface EnvironmentRevision {
  schemaVersion: number; ownerUid?: string; petId?: string; revision: number; previousRevision: number;
  kind: 'initial_snapshot' | 'change' | 'correction' | 'cancel'; targetRevision: number | null;
  effective: EnvironmentEffectiveTime; acceptedAt: unknown; mutationId?: string; initialBatch?: boolean;
  rawValues: RawValues; beforeRawValues?: RawValues; values: Record<string, EnvironmentValue>;
  changes: Record<string, {before: EnvironmentValue; after: EnvironmentValue}>; beforeValueMeaning?: 'prior_confirmed_environment' | 'previous_day_confirmed_environment' | 'previous_recorded_input' | 'unknown'; auxiliaryFieldsChanged: string[];
}
export interface EnvironmentMutation {expectedRevision: number; mutationId: string; operation: 'change' | 'correction' | 'cancel'; values: RawValues; effective: EnvironmentEffectiveTime; targetRevision: number | null;}
export interface EnvironmentSaveResult {saved: true; replayed: boolean; revision: number; mutationId: string; changed: boolean; acceptedAt?: string;}
export interface EnvironmentResolution {
  values: Record<string, EnvironmentValue>; evidenceRevisionIds: string[]; observedAt: string; knowledgeCutoff: string | null;
  quality: {unknownFields: string[]; ambiguousFields: string[]; reasons: string[]};
}
function object(value: unknown): value is Record<string, unknown> {return typeof value === 'object' && value !== null && !Array.isArray(value);}
function fail(message: string): never {throw new HttpsError('invalid-argument', message);}
function only(value: Record<string, unknown>, keys: readonly string[]): void {if (Object.keys(value).some(key => !keys.includes(key))) fail('未対応の入力フィールドです。');}
function canonical(value: unknown): unknown {if (Array.isArray(value)) return value.map(canonical); if (object(value)) return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])); return value;}
function equal(a: unknown, b: unknown): boolean {return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));}
export function environmentMutationFingerprint(value: unknown): string {return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');}
function dateValue(value: unknown): Date | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value : null;
  if (typeof value === 'string') {const date = new Date(value); return Number.isFinite(date.getTime()) ? date : null;}
  if (object(value) && typeof value.toDate === 'function') return dateValue((value.toDate as () => unknown)());
  return null;
}
function nullValue(unit: 'cm' | 'cm2' | null = null, quality: 'unknown' | 'invalid' = 'unknown'): EnvironmentValue {return {value: null, unit, quality};}
/** Shared unit conversion. Missing, malformed and zero dimensions are never fabricated measurements. */
export function normalizeEnvironmentValues(raw: Record<string, unknown>): Record<string, EnvironmentValue> {
  const values: Record<string, EnvironmentValue> = {};
  for (const key of numericFields) {
    const input = raw[key];
    if (input == null || (typeof input === 'string' && input.trim() === '')) values[key] = nullValue('cm');
    else {
      const number = typeof input === 'number' ? input : typeof input === 'string' && /^\d+(?:\.\d+)?$/.test(input.trim()) ? Number(input.trim()) : NaN;
      values[key] = Number.isFinite(number) && number > 0 && number <= 2000 ? {value: number, unit: 'cm', quality: 'known'} : nullValue('cm', 'invalid');
    }
  }
  const temp = raw.temperatureControl;
  values.temperatureControl = temp == null || temp === '' ? nullValue() : typeof temp === 'string' && temp.trim().length > 0 && temp.length <= 80 ? {value: temp.trim(), unit: null, quality: 'known'} : nullValue(null, 'invalid');
  const tags = raw.accessoryTags;
  values.accessoryTags = tags == null ? nullValue() : Array.isArray(tags) && tags.length <= 50 && tags.every(tag => typeof tag === 'string' && tag.trim().length > 0 && tag.length <= 80)
    ? {value: [...new Set((tags as string[]).map(tag => tag.trim()))].sort(), unit: null, quality: 'known'} : nullValue(null, 'invalid');
  values.cageFloorArea = values.cageWidth.quality === 'known' && values.cageDepth.quality === 'known'
    ? {value: (values.cageWidth.value as number) * (values.cageDepth.value as number), unit: 'cm2', quality: 'known'}
    : nullValue('cm2', values.cageWidth.quality === 'invalid' || values.cageDepth.quality === 'invalid' ? 'invalid' : 'unknown');
  return values;
}
function historyRaw(raw: Record<string, unknown>): RawValues {
  // Legacy malformed containers must not smuggle arbitrary nested data into history.
  return Object.fromEntries(ENVIRONMENT_VALUE_FIELDS.filter(key => key in raw).flatMap(key => {
    const value = raw[key];
    const safe = value == null ? null : key === 'accessoryTags'
      ? (Array.isArray(value) && value.every(tag => typeof tag === 'string') ? value : null)
      : (typeof value === 'string' || typeof value === 'number' ? value : null);
    if (value != null && safe == null) return [];
    return [[key, safe as RawValues[string]]];
  }));
}
function explicitInstant(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const parts = /^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (!parts || !isDateKey(parts[1]) || Number(parts[2]) > 23 || Number(parts[3]) > 59 || Number(parts[4]) > 59) return null;
  return dateValue(value);
}
function effectiveTime(value: unknown, now: Date): EnvironmentEffectiveTime {
  if (!object(value)) fail('変更時期を確認してください。');
  only(value, ['precision', 'dateKey', 'occurredAt']);
  if (value.precision === 'unknown' && value.dateKey == null && value.occurredAt == null) return {precision: 'unknown', dateKey: null, occurredAt: null};
  if (value.precision === 'date_only' && typeof value.dateKey === 'string' && isDateKey(value.dateKey) && value.dateKey <= formatDateKey(now) && value.occurredAt == null) return {precision: 'date_only', dateKey: value.dateKey, occurredAt: null};
  if (value.precision === 'instant') {
    const time = explicitInstant(value.occurredAt);
    if (time && time.getTime() <= now.getTime() && (value.dateKey == null || value.dateKey === formatDateKey(time))) return {precision: 'instant', dateKey: formatDateKey(time), occurredAt: time.toISOString()};
  }
  return fail('変更時期が不正です。未来の変更予約は保存できません。');
}
export function normalizeEnvironmentMutation(value: unknown, now: Date, previous: Record<string, unknown>): EnvironmentMutation {
  if (!object(value)) fail('保存内容が不正です。');
  only(value, ['expectedRevision', 'mutationId', 'operation', 'values', 'effective', 'targetRevision']);
  if (!Number.isSafeInteger(value.expectedRevision) || (value.expectedRevision as number) < 0) fail('revisionが不正です。');
  if (typeof value.mutationId !== 'string' || !/^[a-zA-Z0-9_-]{16,128}$/.test(value.mutationId)) fail('mutation IDが不正です。');
  if (!['change', 'correction', 'cancel'].includes(String(value.operation))) fail('保存操作が不正です。');
  const operation = value.operation as EnvironmentMutation['operation'];
  const targetRevision = value.targetRevision == null ? null : value.targetRevision as number;
  if (operation === 'change' ? targetRevision !== null : !Number.isSafeInteger(targetRevision) || (targetRevision ?? 0) < 1) fail('訂正・取消対象が不正です。');
  const raw = value.values == null ? {} : value.values;
  if (!object(raw)) fail('環境設定が不正です。');
  only(raw, [...ENVIRONMENT_VALUE_FIELDS, ...auxiliaryFields]);
  if (operation === 'cancel' && Object.keys(raw).length > 0) fail('取消に環境値は不要です。');
  const normalized = normalizeEnvironmentValues(raw);
  const values: RawValues = {};
  for (const [key, input] of Object.entries(raw)) {
    if (auxiliaryFields.includes(key)) {
      if (input != null && (typeof input !== 'string' || input.length > 5000)) fail('環境メモが不正です。');
      values[key] = input as string | null;
    } else {
      if (normalized[key].quality === 'invalid' && !equal(input, previous[key])) fail('環境値が不正です。単位はcmです。');
      values[key] = input as RawValues[string];
    }
  }
  const effective = operation === 'cancel' ? {precision: 'unknown', dateKey: null, occurredAt: null} as EnvironmentEffectiveTime : effectiveTime(value.effective, now);
  if (operation === 'cancel' && value.effective != null && !equal(effectiveTime(value.effective, now), effective)) fail('取消の変更時期は指定できません。');
  return {expectedRevision: value.expectedRevision as number, mutationId: value.mutationId, operation, values, effective, targetRevision};
}
function revisionId(value: number): string {return String(value).padStart(10, '0');}
function acceptedMillis(event: EnvironmentRevision): number {return dateValue(event.acceptedAt)?.getTime() ?? NaN;}
/** Corrections replace only their original patch. Later changes are independently retained. */
function activeEvents(revisions: readonly EnvironmentRevision[]): EnvironmentRevision[] {
  const active = new Map<number, EnvironmentRevision>();
  for (const event of [...revisions].sort((a, b) => a.revision - b.revision)) {
    if (event.kind === 'change') active.set(event.revision, {...event, rawValues: {...event.rawValues}});
    else if (event.kind === 'cancel' && event.targetRevision != null) active.delete(event.targetRevision);
    else if (event.kind === 'correction' && event.targetRevision != null) {
      const target = active.get(event.targetRevision);
      if (target) active.set(event.targetRevision, {...target, effective: event.effective, rawValues: {...target.rawValues, ...event.rawValues}, values: normalizeEnvironmentValues({...target.rawValues, ...event.rawValues}), revision: event.revision, acceptedAt: event.effective.precision === 'unknown' || equal(event.effective, target.effective) ? target.acceptedAt : event.acceptedAt});
    }
  }
  return [...active.values()];
}
function anchorRaw(revisions: readonly EnvironmentRevision[]): RawValues {
  const initial = revisions.find(event => event.kind === 'initial_snapshot');
  const raw = {...initial?.rawValues};
  // Initial submitted confirmation is not an actual change event. Its explicitly known
  // pre-save values supply the baseline only at/after confirmation, never before it.
  for (const event of revisions.filter(event => event.kind === 'change' && event.initialBatch).sort((a, b) => a.revision - b.revision)) Object.assign(raw, event.beforeRawValues ?? {});
  return raw;
}
function currentOrder(event: EnvironmentRevision): number {
  if (event.effective.precision === 'instant') return dateValue(event.effective.occurredAt)?.getTime() ?? acceptedMillis(event);
  if (event.effective.precision === 'date_only') return Math.min(new Date(`${event.effective.dateKey}T00:00:00+09:00`).getTime() + 86400000, acceptedMillis(event));
  return acceptedMillis(event);
}
/** Operational current projection. Historical corrections cannot roll later field changes back. */
export function projectCurrentEnvironment(revisions: readonly EnvironmentRevision[]): RawValues {
  const raw = anchorRaw(revisions);
  for (const event of activeEvents(revisions).sort((a, b) => currentOrder(a) - currentOrder(b) || a.revision - b.revision)) Object.assign(raw, event.rawValues);
  return raw;
}
function interval(event: EnvironmentRevision): {start: number; end: number} {
  if (event.effective.precision === 'instant') {const time = dateValue(event.effective.occurredAt)?.getTime() ?? NaN; return {start: time, end: time};}
  if (event.effective.precision === 'date_only') {const start = new Date(`${event.effective.dateKey}T00:00:00+09:00`).getTime(); return {start, end: Math.min(start + 86400000, acceptedMillis(event))};}
  return {start: -Infinity, end: acceptedMillis(event)};
}
/** Retrospective if cutoff absent; otherwise bitemporal reconstruction without late-input leakage. */
export function resolveEnvironmentHistory(params: {revisions: readonly EnvironmentRevision[]; observedAt: Date; knowledgeCutoff?: Date}): EnvironmentResolution {
  const observed = params.observedAt.getTime(), cutoff = params.knowledgeCutoff?.getTime();
  if (!Number.isFinite(observed) || (cutoff != null && !Number.isFinite(cutoff))) fail('読み取り日時が不正です。');
  const revisions = params.revisions.filter(event => Number.isFinite(acceptedMillis(event)) && (cutoff == null || acceptedMillis(event) <= cutoff)).sort((a, b) => a.revision - b.revision);
  const initial = revisions.find(event => event.kind === 'initial_snapshot');
  const anchorAvailable = initial != null && observed >= acceptedMillis(initial);
  const anchor = anchorRaw(revisions);
  const values = normalizeEnvironmentValues(anchorAvailable ? anchor : {});
  if (anchorAvailable && initial) for (const field of ENVIRONMENT_VALUE_FIELDS) if (!(field in anchor) && initial.values[field]?.quality === 'invalid') values[field] = initial.values[field];
  const evidence = new Set<string>();
  const ambiguous = new Set<string>(); const reasons = new Set<string>();
  if (anchorAvailable && initial) evidence.add(revisionId(initial.revision));
  else reasons.add(initial ? 'before_initial_confirmation' : 'no_accepted_environment_history');
  const events = activeEvents(revisions);
  for (const field of ENVIRONMENT_VALUE_FIELDS) {
    const candidates = events.filter(event => field in event.rawValues).map(event => ({event, ...interval(event)})).filter(item => Number.isFinite(item.end) && item.start <= observed);
    const definite = candidates.filter(item => item.end <= observed).sort((a, b) => b.end - a.end || b.event.revision - a.event.revision);
    const chosen = definite[0];
    const uncertain = candidates.filter(item => item.end > observed);
    const overlaps = chosen && chosen.event.effective.precision !== 'unknown' ? definite.slice(1).filter(item => item.end > chosen.start && item.start < chosen.end) : [];
    const dangerous = uncertain.filter(item => !chosen || item.end > chosen.start);
    if (dangerous.length || overlaps.length) {
      values[field] = nullValue(numericFields.includes(field) ? 'cm' : null); ambiguous.add(field);
      for (const item of [chosen, ...dangerous, ...overlaps].filter(Boolean) as typeof candidates) {evidence.add(revisionId(item.event.revision)); reasons.add(item.event.effective.precision === 'unknown' ? 'unknown_effective_time' : 'effective_time_ambiguity');}
    } else if (chosen) {values[field] = normalizeEnvironmentValues(chosen.event.rawValues)[field]; evidence.add(revisionId(chosen.event.revision));}
  }
  // Area derives exclusively from this resolved, date-aligned pair, never the current document.
  const derived = normalizeEnvironmentValues({cageWidth: values.cageWidth.value, cageDepth: values.cageDepth.value});
  values.cageFloorArea = values.cageWidth.quality === 'invalid' || values.cageDepth.quality === 'invalid' ? nullValue('cm2', 'invalid') : derived.cageFloorArea;
  if (ambiguous.has('cageWidth') || ambiguous.has('cageDepth')) ambiguous.add('cageFloorArea');
  return {values, evidenceRevisionIds: [...evidence].sort(), observedAt: params.observedAt.toISOString(), knowledgeCutoff: params.knowledgeCutoff?.toISOString() ?? null,
    quality: {unknownFields: Object.keys(values).filter(key => values[key].quality !== 'known'), ambiguousFields: [...ambiguous].sort(), reasons: [...reasons].sort()}};
}
function changes(before: RawValues, after: RawValues, displayBefore?: Record<string, EnvironmentValue>): EnvironmentRevision['changes'] {
  const a = displayBefore ?? normalizeEnvironmentValues(before), b = normalizeEnvironmentValues(after);
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  return Object.fromEntries(ENVIRONMENT_VALUE_FIELDS.filter(key => keys.has(key) && !equal(a[key], b[key])).map(key => [key, {before: a[key], after: b[key]}]));
}
function makeEvent(params: {uid: string; revision: number; kind: EnvironmentRevision['kind']; targetRevision?: number | null; effective: EnvironmentEffectiveTime; acceptedAt: unknown; mutationId: string; before?: RawValues; after: RawValues; initialBatch?: boolean; auxiliaryFieldsChanged?: string[]; displayBefore?: Record<string, EnvironmentValue>; beforeValueMeaning?: EnvironmentRevision['beforeValueMeaning']; valuesOverride?: Record<string, EnvironmentValue>}): EnvironmentRevision {
  const before = params.before ?? {}, after = params.after;
  return {schemaVersion: ENVIRONMENT_HISTORY_SCHEMA_VERSION, ownerUid: params.uid, petId: 'main_pet', revision: params.revision, previousRevision: params.revision - 1, kind: params.kind,
    targetRevision: params.targetRevision ?? null, effective: params.effective, acceptedAt: params.acceptedAt, mutationId: params.mutationId, initialBatch: params.initialBatch ?? false,
    rawValues: after, beforeRawValues: before, values: params.valuesOverride ?? normalizeEnvironmentValues(after), changes: params.kind === 'initial_snapshot' || params.kind === 'cancel' ? {} : changes(before, after, params.displayBefore), beforeValueMeaning: params.beforeValueMeaning ?? 'unknown', auxiliaryFieldsChanged: params.auxiliaryFieldsChanged ?? []};
}
/** Current + append-only revision + receipt commit together; no health/reward/record writes. */
export async function saveEnvironmentMutation(params: {db: admin.firestore.Firestore; uid: string; data: unknown; now?: Date}): Promise<EnvironmentSaveResult> {
  const {db, uid, data} = params; const now = params.now ?? new Date();
  if (!object(data) || typeof data.mutationId !== 'string' || !/^[a-zA-Z0-9_-]{16,128}$/.test(data.mutationId)) fail('保存識別子が不正です。');
  const current = db.doc(`users/${uid}/breeding_environments/main_env`), receipt = current.collection('mutations').doc(data.mutationId);
  const fingerprint = environmentMutationFingerprint(data);
  const result = await db.runTransaction(async tx => {
    const [currentSnap, receiptSnap] = await Promise.all([tx.get(current), tx.get(receipt)]);
    if (receiptSnap.exists) {
      if (receiptSnap.get('requestFingerprint') !== fingerprint) throw new HttpsError('already-exists', '同じmutation IDで異なる内容は保存できません。');
      return {...receiptSnap.get('result'), replayed: true} as EnvironmentSaveResult;
    }
    const previous = currentSnap.data() ?? {};
    const revision = previous.revision ?? 0;
    if (!Number.isSafeInteger(revision) || revision < 0) throw new HttpsError('failed-precondition', '保存済みrevisionが不正です。');
    const mutation = normalizeEnvironmentMutation(data, now, previous);
    if (mutation.expectedRevision !== revision) throw new HttpsError('aborted', '別の保存が先に完了しました。最新の環境設定を確認してください。');
    const history = await tx.get(current.collection('revisions').orderBy('revision').limit(ENVIRONMENT_HISTORY_TRANSACTION_LIMIT + 1));
    if (history.size > ENVIRONMENT_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '履歴が多いため保存を停止しました。管理者による確認が必要です。');
    const oldRows = history.docs.map(doc => doc.data() as EnvironmentRevision);
    const initialized = previous.environmentHistorySchemaVersion === ENVIRONMENT_HISTORY_SCHEMA_VERSION;
    if (initialized !== oldRows.some(event => event.kind === 'initial_snapshot') || (initialized && revision !== oldRows[oldRows.length - 1]?.revision)) throw new HttpsError('failed-precondition', '環境履歴と現在設定の整合性を確認できません。');
    if (!initialized && mutation.operation !== 'change') throw new HttpsError('failed-precondition', '初回保存の前に訂正・取消はできません。');
    const before = historyRaw(previous);
    const after = historyRaw({...before, ...mutation.values});
    const stamp = admin.firestore.FieldValue.serverTimestamp();
    const newRows: EnvironmentRevision[] = [];
    let nextRevision = revision;
    if (!initialized) newRows.push(makeEvent({uid, revision: ++nextRevision, kind: 'initial_snapshot', effective: {precision: 'unknown', dateKey: null, occurredAt: null}, acceptedAt: stamp, mutationId: mutation.mutationId, after, valuesOverride: normalizeEnvironmentValues({...previous, ...mutation.values})}));
    const auxiliaryChanged = auxiliaryFields.filter(key => key in mutation.values && !equal(previous[key] ?? null, mutation.values[key]));
    if (mutation.operation === 'change') {
      const changed = changes(before, after);
      const alreadyRecorded = mutation.effective.precision === 'instant' && mutation.effective.dateKey != null && mutation.effective.dateKey < formatDateKey(now) && Object.keys(changed).length > 0 && auxiliaryChanged.length === 0 && Object.keys(changed).every(field => activeEvents(oldRows).some(event => field in event.rawValues && equal(event.effective, mutation.effective) && equal(normalizeEnvironmentValues(event.rawValues)[field], normalizeEnvironmentValues(after)[field])));
      if (!alreadyRecorded && (currentSnap.exists || initialized) && (Object.keys(changed).length > 0 || auxiliaryChanged.length > 0)) {
        const fields = Object.keys(changed);
        const patchBefore = Object.fromEntries(fields.map(key => [key, before[key] ?? null]));
        const patchAfter = Object.fromEntries(fields.map(key => [key, after[key] ?? null]));
        let displayBefore = normalizeEnvironmentValues({});
        let beforeValueMeaning: EnvironmentRevision['beforeValueMeaning'] = 'unknown';
        if (mutation.effective.precision !== 'unknown') {
          const boundary = mutation.effective.precision === 'instant'
            ? explicitInstant(mutation.effective.occurredAt)!.getTime()
            : new Date(`${mutation.effective.dateKey}T00:00:00+09:00`).getTime();
          displayBefore = resolveEnvironmentHistory({revisions: oldRows, observedAt: new Date(boundary - 1)}).values;
          beforeValueMeaning = mutation.effective.precision === 'instant' ? 'prior_confirmed_environment' : 'previous_day_confirmed_environment';
        }
        // Display only this patch. Other fields remain independently unknown/known.
        displayBefore = Object.fromEntries(fields.map(key => [key, displayBefore[key]]));
        const display = {...normalizeEnvironmentValues({}), ...displayBefore};
        newRows.push(makeEvent({uid, revision: ++nextRevision, kind: 'change', effective: mutation.effective, acceptedAt: stamp, mutationId: mutation.mutationId, before: patchBefore, after: patchAfter, initialBatch: !initialized, auxiliaryFieldsChanged: auxiliaryChanged, displayBefore: display, beforeValueMeaning}));
      }
    } else {
      const target = oldRows.find(event => event.revision === mutation.targetRevision && event.kind === 'change');
      const active = activeEvents(oldRows).find(event => event.revision === mutation.targetRevision || oldRows.some(original => original.kind === 'correction' && original.targetRevision === mutation.targetRevision && original.revision === event.revision));
      if (!target || !active) throw new HttpsError('failed-precondition', '有効な変更履歴を選択してください。');
      if (Object.keys(mutation.values).some(key => !(key in target.rawValues)) || auxiliaryChanged.length > 0) fail('訂正は対象履歴で変更した項目だけに指定できます。');
      const replacement = {...active.rawValues, ...historyRaw(mutation.values)};
      if (mutation.operation === 'cancel' || !equal(normalizeEnvironmentValues(replacement), normalizeEnvironmentValues(active.rawValues)) || !equal(mutation.effective, active.effective)) newRows.push(makeEvent({uid, revision: ++nextRevision, kind: mutation.operation, targetRevision: mutation.targetRevision, effective: mutation.effective, acceptedAt: stamp, mutationId: mutation.mutationId, before: target.beforeRawValues ?? {}, after: mutation.operation === 'cancel' ? {} : replacement, displayBefore: normalizeEnvironmentValues(active.rawValues), beforeValueMeaning: 'previous_recorded_input'}));
    }
    if (oldRows.length + newRows.length > ENVIRONMENT_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', '履歴が多いため保存を停止しました。管理者による確認が必要です。');
    const saved: EnvironmentSaveResult = {saved: true, replayed: false, revision: nextRevision, mutationId: mutation.mutationId, changed: newRows.length > 0};
    for (const event of newRows) tx.create(current.collection('revisions').doc(revisionId(event.revision)), event);
    tx.create(receipt, {schemaVersion: ENVIRONMENT_HISTORY_SCHEMA_VERSION, ownerUid: uid, petId: 'main_pet', requestFingerprint: fingerprint, acceptedAt: stamp, result: saved});
    if (newRows.length) {
      // A pending server timestamp must order after every previously committed receipt,
      // even if the request clock is slightly behind the Firestore commit clock.
      const projectionAcceptedAt = new Date(Math.max(now.getTime(), ...oldRows.map(acceptedMillis).filter(Number.isFinite)) + 1);
      const rows = [...oldRows, ...newRows.map(event => ({...event, acceptedAt: projectionAcceptedAt}))];
      const projection = projectCurrentEnvironment(rows);
      const auxiliary = Object.fromEntries(auxiliaryFields.filter(key => key in mutation.values).map(key => [key, mutation.values[key]]));
      tx.set(db.doc(`users/${uid}`), {has_subcollections: true}, {merge: true});
      tx.set(current, {...projection, ...auxiliary, environmentHistorySchemaVersion: ENVIRONMENT_HISTORY_SCHEMA_VERSION, ownerUid: uid, petId: 'main_pet', revision: nextRevision, acceptedAt: stamp, updatedAt: stamp, createdAt: previous.createdAt ?? stamp}, {merge: true});
    }
    return saved;
  });
  const accepted = dateValue((await receipt.get()).get('acceptedAt'));
  if (!accepted) throw new HttpsError('internal', '受理済み日時を確認できません。再送で確認してください。');
  return {...result, acceptedAt: accepted.toISOString()};
}
export async function readEnvironmentAt(params: {db: admin.firestore.Firestore; uid: string; observedAt: Date; knowledgeCutoff?: Date}): Promise<EnvironmentResolution> {
  const collection = params.db.doc(`users/${params.uid}/breeding_environments/main_env`).collection('revisions');
  const revisions: EnvironmentRevision[] = []; let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  // Page immutable documents; the metadata revision is an upper bound for a consistent read.
  const current = await collection.parent!.get(); const ceiling = current.get('revision') ?? 0;
  while (ceiling > 0) {
    let query = collection.orderBy('revision').where('revision', '<=', ceiling).limit(250);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    revisions.push(...page.docs.map(doc => doc.data() as EnvironmentRevision));
    if (revisions.length > 20000) throw new HttpsError('resource-exhausted', '履歴が多いため読み取りを停止しました。');
    if (page.size < 250) break;
    cursor = page.docs[page.docs.length - 1];
  }
  return resolveEnvironmentHistory({...params, revisions});
}
export const saveBreedingEnvironment = onCall({region: 'asia-northeast1'}, async request => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  return saveEnvironmentMutation({db: admin.firestore(), uid: request.auth.uid, data: request.data});
});
export const readBreedingEnvironmentAt = onCall({region: 'asia-northeast1'}, async request => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  if (!object(request.data)) fail('読み取り条件が不正です。'); only(request.data, ['observedAt', 'knowledgeCutoff']);
  const observedAt = explicitInstant(request.data.observedAt), knowledgeCutoff = request.data.knowledgeCutoff == null ? undefined : explicitInstant(request.data.knowledgeCutoff);
  if (!observedAt || knowledgeCutoff === null) fail('読み取り日時が不正です。');
  return readEnvironmentAt({db: admin.firestore(), uid: request.auth.uid, observedAt, knowledgeCutoff});
});
