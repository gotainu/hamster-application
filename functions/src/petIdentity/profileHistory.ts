import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {careActionMutationFingerprint} from '../careActions/careActions';
import {formatDateKey, isDateKey} from '../health/dateKey';

export const PROFILE_HISTORY_SCHEMA_VERSION = 1;
export const PROFILE_HISTORY_TRANSACTION_LIMIT = 2000;
export type BirthdayPrecision = 'date_only' | 'approximate_date' | 'unknown' | 'legacy_unspecified';
export interface ProfileBirthday {dateKey: string | null; precision: BirthdayPrecision; quality: 'known' | 'approximate' | 'unknown' | 'invalid' | 'precision_unspecified';}
export interface ProfileAttributes {species: string | null; birthday: ProfileBirthday;}
export interface ProfileHistoryRevision {
  schemaVersion: number; ownerUid: string; petId: 'main_pet'; subjectId: string;
  revision: number; previousRevision: number; profileRevision: number; mutationId: string;
  kind: 'initial_snapshot' | 'correction' | 'cancel'; targetHistoryRevision: number | null;
  acceptedAt: unknown; values: ProfileAttributes; patch: Partial<ProfileAttributes>;
  researchConsentStatus: 'not_assessed';
}
const object = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
function fail(message: string): never {throw new HttpsError('invalid-argument', message);}
const same = (a: unknown, b: unknown): boolean => careActionMutationFingerprint(a) === careActionMutationFingerprint(b);
const revisionId = (revision: number): string => String(revision).padStart(10, '0');
const unknownAttributes = (): ProfileAttributes => ({species: null, birthday: {dateKey: null, precision: 'unknown', quality: 'unknown'}});
export function profileHistoryReference(db: admin.firestore.Firestore, uid: string, subjectId: string): admin.firestore.DocumentReference {
  return db.doc(`users/${uid}/pet_subjects/${subjectId}/profile_history/main_profile`);
}
/** Dates are calendar attributes. No present-day fallback or inferred exact precision. */
export function normalizeProfileAttributes(value: Record<string, unknown>): ProfileAttributes {
  const species = typeof value.species === 'string' && value.species.trim().length > 0 ? value.species.trim() : null;
  let birthdayDate: Date | null = null;
  if (value.birthday instanceof Date) birthdayDate = value.birthday;
  else if (object(value.birthday) && typeof value.birthday.toDate === 'function') birthdayDate = (value.birthday.toDate as () => Date)();
  else if (typeof value.birthday === 'string') birthdayDate = new Date(value.birthday);
  const recorded = birthdayDate !== null && Number.isFinite(birthdayDate.getTime());
  const dateKey = recorded ? formatDateKey(birthdayDate!) : null;
  const precision: BirthdayPrecision = ['date_only', 'approximate_date', 'unknown', 'legacy_unspecified'].includes(String(value.birthdayPrecision))
    ? value.birthdayPrecision as BirthdayPrecision : recorded ? 'legacy_unspecified' : 'unknown';
  const quality: ProfileBirthday['quality'] = value.birthday != null && !recorded || precision !== 'unknown' && !recorded || precision === 'unknown' && recorded
    ? 'invalid' : !recorded ? 'unknown' : precision === 'approximate_date' ? 'approximate' : precision === 'legacy_unspecified' ? 'precision_unspecified' : 'known';
  return {species, birthday: {dateKey, precision, quality}};
}
/** Preserve Firestore nanoseconds instead of rounding acceptance into an earlier cutoff. */
export function profileEpochNanoseconds(value: unknown): bigint | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? BigInt(value.getTime()) * 1000000n : null;
  if (object(value) && typeof value.seconds === 'number' && Number.isSafeInteger(value.seconds) && typeof value.nanoseconds === 'number'
    && Number.isInteger(value.nanoseconds) && value.nanoseconds >= 0 && value.nanoseconds < 1000000000) return BigInt(value.seconds) * 1000000000n + BigInt(value.nanoseconds);
  return null;
}
export function profileKnowledgeCutoff(value?: unknown, epochNanoseconds?: unknown): bigint | undefined {
  if (value != null && epochNanoseconds != null) fail('知識締切は日時かnanosecondのどちらか一つを指定してください。');
  if (epochNanoseconds != null) {
    if (typeof epochNanoseconds !== 'string' || !/^(0|[1-9]\d{0,20})$/.test(epochNanoseconds)) fail('知識締切nanosecondが不正です。');
    const nanos = BigInt(epochNanoseconds);
    if (nanos > 253402300799999999999n) fail('知識締切が範囲外です。');
    return nanos;
  }
  if (value == null) return undefined;
  if (value instanceof Date) {const nanos = profileEpochNanoseconds(value); if (nanos === null) fail('知識締切が不正です。'); return nanos;}
  if (typeof value !== 'string') fail('知識締切が不正です。');
  const match = /^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (!match || !isDateKey(match[1]) || Number(match[2]) > 23 || Number(match[3]) > 59 || Number(match[4]) > 59) fail('知識締切が不正です。');
  if (match[6] !== 'Z' && (Number(match[6].slice(1, 3)) > 23 || Number(match[6].slice(4, 6)) > 59)) fail('知識締切のtimezoneが不正です。');
  const base = new Date(`${match[1]}T${match[2]}:${match[3]}:${match[4]}${match[6]}`).getTime();
  if (!Number.isFinite(base)) fail('知識締切が不正です。');
  return BigInt(base) * 1000000n + BigInt((match[5] ?? '').padEnd(9, '0') || '0');
}
function knownAt(value: unknown, cutoff: bigint | undefined): boolean {
  const accepted = profileEpochNanoseconds(value); return accepted !== null && (cutoff === undefined || accepted <= cutoff);
}
function publicAcceptance(value: unknown): {acceptedAt: string | null; acceptedAtEpochNanoseconds: string | null} {
  const nanos = profileEpochNanoseconds(value);
  return {acceptedAt: nanos === null ? null : new Date(Number(nanos / 1000000n)).toISOString(), acceptedAtEpochNanoseconds: nanos?.toString() ?? null};
}
function activeCorrections(rows: readonly ProfileHistoryRevision[]): ProfileHistoryRevision[] {
  const cancelled = new Set(rows.filter(row => row.kind === 'cancel').map(row => row.targetHistoryRevision));
  return rows.filter(row => row.kind !== 'cancel' && !cancelled.has(row.revision));
}
export function projectProfileAttributes(rows: readonly ProfileHistoryRevision[]): ProfileAttributes {
  let values = unknownAttributes();
  for (const row of activeCorrections([...rows].sort((a, b) => a.revision - b.revision))) values = {...values, ...row.patch};
  return values;
}
function ageAt(birthday: ProfileBirthday, evaluationDateKey: string): {days: number | null; months: number | null; precision: BirthdayPrecision; quality: ProfileBirthday['quality']} {
  if (!birthday.dateKey || birthday.quality === 'invalid' || evaluationDateKey < birthday.dateKey) return {days: null, months: null, precision: birthday.precision, quality: birthday.quality === 'invalid' ? 'invalid' : 'unknown'};
  const [by, bm, bd] = birthday.dateKey.split('-').map(Number), [ey, em, ed] = evaluationDateKey.split('-').map(Number);
  return {days: Math.floor((Date.UTC(ey, em - 1, ed) - Date.UTC(by, bm - 1, bd)) / 86400000), months: (ey - by) * 12 + em - bm - (ed < bd ? 1 : 0), precision: birthday.precision, quality: birthday.quality};
}
export function resolveProfileHistory(params: {
  revisions: readonly ProfileHistoryRevision[]; evaluationDateKey: string; knowledgeCutoff?: Date | string;
  knowledgeCutoffEpochNanoseconds?: string; historyStartedAt?: unknown; hadLegacyProfile?: boolean;
}) {
  if (!isDateKey(params.evaluationDateKey)) fail('年齢の評価日が不正です。');
  const cutoff = profileKnowledgeCutoff(params.knowledgeCutoff, params.knowledgeCutoffEpochNanoseconds);
  const rows = params.revisions.filter(row => knownAt(row.acceptedAt, cutoff)).sort((a, b) => a.revision - b.revision);
  const values = projectProfileAttributes(rows), reasons = new Set<string>();
  if (params.hadLegacyProfile) reasons.add('legacy_profile_before_confirmation_unrecoverable');
  if (params.historyStartedAt != null && !knownAt(params.historyStartedAt, cutoff)) reasons.add('before_initial_confirmation');
  if (!rows.length) reasons.add('no_accepted_profile_history');
  if (params.revisions.some(row => profileEpochNanoseconds(row.acceptedAt) === null)) reasons.add('invalid_acceptance_time');
  if (values.species === null) reasons.add('species_unknown');
  if (values.birthday.quality !== 'known') reasons.add(`birthday_${values.birthday.quality}`);
  if (values.birthday.dateKey && params.evaluationDateKey < values.birthday.dateKey) reasons.add('evaluation_before_birthday');
  const cancelled = new Set(rows.filter(row => row.kind === 'cancel').map(row => row.targetHistoryRevision));
  const latest = rows.length ? rows[rows.length - 1] : null;
  return {values, age: ageAt(values.birthday, params.evaluationDateKey), evaluationDateKey: params.evaluationDateKey,
    knowledgeCutoff: cutoff === undefined ? null : new Date(Number(cutoff / 1000000n)).toISOString(), knowledgeCutoffEpochNanoseconds: cutoff?.toString() ?? null,
    latestRevision: latest?.revision ?? 0, historyExists: rows.length > 0,
    current: latest ? {revision: latest.revision, values, ...publicAcceptance(latest.acceptedAt)} : null,
    evidenceRevisionIds: rows.map(row => revisionId(row.revision)),
    revisions: rows.map(row => ({...row, ...publicAcceptance(row.acceptedAt), cancelled: cancelled.has(row.revision)})),
    quality: {reasons: [...reasons].sort(), researchConsentStatus: 'not_assessed' as const}};
}
export interface ProfileHistoryPlan {
  ledger: admin.firestore.DocumentReference; rows: ProfileHistoryRevision[]; next: ProfileHistoryRevision | null;
  values: ProfileAttributes; historyRevision: number; introduced: boolean; hadLegacyProfile: boolean;
}
/** Reads only. Current profile, registry, immutable revision and receipt commit together in the caller. */
export async function planProfileHistoryMutation(params: {
  db: admin.firestore.Firestore; tx: admin.firestore.Transaction; uid: string; subjectId: string;
  before: Record<string, unknown>; after: Record<string, unknown>; profileRevision: number; mutationId: string;
  operation: 'save' | 'replace' | 'cancel_profile_correction'; targetHistoryRevision: number | null;
  hadLegacyProfile: boolean;
}): Promise<ProfileHistoryPlan> {
  const {db, tx, uid, subjectId} = params, ledger = profileHistoryReference(db, uid, subjectId);
  const [ledgerSnap, history] = await Promise.all([tx.get(ledger), tx.get(ledger.collection('revisions').orderBy('revision').limit(PROFILE_HISTORY_TRANSACTION_LIMIT + 1))]);
  if (history.size > PROFILE_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', 'プロフィール履歴が多いため保存を停止しました。');
  const rows = history.docs.map(doc => doc.data() as ProfileHistoryRevision), previousRevision = ledgerSnap.get('revision') ?? 0;
  if (!Number.isSafeInteger(previousRevision) || previousRevision < 0 || rows.length !== previousRevision
    || rows.some((row, index) => row.revision !== index + 1 || row.ownerUid !== uid || row.subjectId !== subjectId || row.schemaVersion !== PROFILE_HISTORY_SCHEMA_VERSION)
    || ledgerSnap.exists && (ledgerSnap.get('ownerUid') !== uid || ledgerSnap.get('subjectId') !== subjectId)) throw new HttpsError('failed-precondition', 'プロフィール履歴の整合性を確認できません。');
  if (!ledgerSnap.exists && rows.length || params.before.profileHistorySchemaVersion === PROFILE_HISTORY_SCHEMA_VERSION && !ledgerSnap.exists && params.operation !== 'replace') throw new HttpsError('failed-precondition', 'プロフィール履歴が見つかりません。');
  if (params.operation !== 'replace' && params.before.profileHistorySchemaVersion === PROFILE_HISTORY_SCHEMA_VERSION && params.before.profileHistoryRevision !== previousRevision) throw new HttpsError('failed-precondition', '現在のプロフィール履歴番号が一致しません。');
  const introduced = !ledgerSnap.exists, hadLegacyProfile = introduced ? params.hadLegacyProfile : ledgerSnap.get('hadLegacyProfile') === true;
  const prior = projectProfileAttributes(rows), after = normalizeProfileAttributes(params.after);
  if (!introduced && params.operation !== 'replace' && !same(prior, normalizeProfileAttributes(params.before))) throw new HttpsError('failed-precondition', '現在の属性とプロフィール履歴が一致しません。');
  let kind: ProfileHistoryRevision['kind'] = introduced ? 'initial_snapshot' : 'correction', patch: Partial<ProfileAttributes> = {}, values = after, changed = introduced;
  if (params.operation === 'cancel_profile_correction') {
    if (introduced) throw new HttpsError('not-found', '取消できるプロフィール訂正がありません。');
    const target = rows.find(row => row.revision === params.targetHistoryRevision);
    if (!target || target.kind !== 'correction') throw new HttpsError('failed-precondition', '訂正revisionだけを取り消せます。');
    kind = 'cancel'; changed = !rows.some(row => row.kind === 'cancel' && row.targetHistoryRevision === target.revision);
    values = projectProfileAttributes([...rows, {revision: previousRevision + 1, kind: 'cancel', targetHistoryRevision: target.revision} as ProfileHistoryRevision]);
  } else if (introduced) patch = after;
  else {
    if (!same(prior.species, after.species)) patch.species = after.species;
    if (!same(prior.birthday, after.birthday)) patch.birthday = after.birthday;
    changed = Object.keys(patch).length > 0;
  }
  if (changed && rows.length >= PROFILE_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', 'プロフィール履歴の上限に達しました。');
  const historyRevision = previousRevision + (changed ? 1 : 0);
  const next: ProfileHistoryRevision | null = changed ? {schemaVersion: PROFILE_HISTORY_SCHEMA_VERSION, ownerUid: uid, petId: 'main_pet', subjectId,
    revision: historyRevision, previousRevision, profileRevision: params.profileRevision, mutationId: params.mutationId, kind,
    targetHistoryRevision: kind === 'cancel' ? params.targetHistoryRevision : null, acceptedAt: admin.firestore.FieldValue.serverTimestamp(), values, patch, researchConsentStatus: 'not_assessed'} : null;
  return {ledger, rows, next, values, historyRevision, introduced, hadLegacyProfile};
}
export function commitProfileHistoryMutation(tx: admin.firestore.Transaction, plan: ProfileHistoryPlan, stamp: unknown): void {
  if (!plan.next) return;
  const next = {...plan.next, acceptedAt: stamp};
  tx.create(plan.ledger.collection('revisions').doc(revisionId(next.revision)), next);
  tx.set(plan.ledger, {schemaVersion: PROFILE_HISTORY_SCHEMA_VERSION, ownerUid: next.ownerUid, petId: 'main_pet', subjectId: next.subjectId,
    revision: next.revision, acceptedAt: stamp, updatedAt: stamp, researchConsentStatus: 'not_assessed',
    ...(plan.introduced ? {historyStartedAt: stamp, hadLegacyProfile: plan.hadLegacyProfile, priorStateReconstructable: false} : {})}, {merge: true});
}
export function profileAttributesProjection(values: ProfileAttributes): Record<string, unknown> {
  return {species: values.species ?? '', birthday: values.birthday.dateKey && values.birthday.quality !== 'invalid'
    ? admin.firestore.Timestamp.fromDate(new Date(`${values.birthday.dateKey}T00:00:00+09:00`)) : null, birthdayPrecision: values.birthday.precision};
}
export async function readProfileHistoryAt(params: {
  db: admin.firestore.Firestore; uid: string; subjectId: string; evaluationDateKey: string;
  knowledgeCutoff?: Date | string; knowledgeCutoffEpochNanoseconds?: string;
}) {
  if (!/^[a-zA-Z0-9_-]{16,128}$/.test(params.subjectId)) fail('個体識別子が不正です。');
  profileKnowledgeCutoff(params.knowledgeCutoff, params.knowledgeCutoffEpochNanoseconds);
  if (!isDateKey(params.evaluationDateKey)) fail('年齢の評価日が不正です。');
  return params.db.runTransaction(async tx => {
    const registry = await tx.get(params.db.doc(`users/${params.uid}/pet_subjects/${params.subjectId}`));
    if (!registry.exists) throw new HttpsError('not-found', '個体登録が見つかりません。');
    if (registry.get('ownerUid') !== params.uid || registry.get('subjectId') !== params.subjectId || registry.get('petId') !== 'main_pet') throw new HttpsError('permission-denied', '個体の所有者を確認できません。');
    const ledger = profileHistoryReference(params.db, params.uid, params.subjectId);
    const [root, history] = await Promise.all([tx.get(ledger), tx.get(ledger.collection('revisions').orderBy('revision').limit(PROFILE_HISTORY_TRANSACTION_LIMIT + 1))]);
    if (history.size > PROFILE_HISTORY_TRANSACTION_LIMIT) throw new HttpsError('resource-exhausted', 'プロフィール履歴が多いため読み取りを停止しました。');
    const rows = history.docs.map(doc => doc.data() as ProfileHistoryRevision);
    if (root.exists && (root.get('ownerUid') !== params.uid || root.get('subjectId') !== params.subjectId) || rows.length !== (root.get('revision') ?? 0)
      || rows.some((row, index) => row.revision !== index + 1 || row.ownerUid !== params.uid || row.subjectId !== params.subjectId)) throw new HttpsError('failed-precondition', 'プロフィール履歴の整合性を確認できません。');
    const result = resolveProfileHistory({...params, revisions: rows, historyStartedAt: root.get('historyStartedAt'), hadLegacyProfile: root.get('hadLegacyProfile') === true});
    return {...result, subjectId: result.historyExists ? params.subjectId : null};
  });
}
export const readMainPetProfileHistoryAt = onCall({region: 'asia-northeast1'}, async request => {
  const uid = request.auth?.uid; if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  if (!object(request.data) || Object.keys(request.data).some(key => !['subjectId', 'evaluationDateKey', 'knowledgeCutoff', 'knowledgeCutoffEpochNanoseconds'].includes(key))
    || typeof request.data.subjectId !== 'string' || typeof request.data.evaluationDateKey !== 'string') fail('プロフィール履歴の読み取り条件が不正です。');
  return readProfileHistoryAt({db: admin.firestore(), uid, subjectId: request.data.subjectId, evaluationDateKey: request.data.evaluationDateKey,
    knowledgeCutoff: request.data.knowledgeCutoff as string | undefined, knowledgeCutoffEpochNanoseconds: request.data.knowledgeCutoffEpochNanoseconds as string | undefined});
});
