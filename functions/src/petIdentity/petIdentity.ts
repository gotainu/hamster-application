import {randomUUID} from 'node:crypto';
import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {careActionMutationFingerprint} from '../careActions/careActions';
import {commitProfileHistoryMutation, normalizeProfileAttributes, planProfileHistoryMutation, PROFILE_HISTORY_SCHEMA_VERSION, profileAttributesProjection, profileEpochNanoseconds, profileKnowledgeCutoff} from './profileHistory';
export {readMainPetProfileHistoryAt} from './profileHistory';

export const PET_IDENTITY_SCHEMA_VERSION = 1;
export const MAIN_PET_SLOT = 'main_pet';
export const isObject = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
export function invalid(message: string): never {throw new HttpsError('invalid-argument', message);}
export function onlyFields(value: Record<string, unknown>, fields: readonly string[]): void {
  if (Object.keys(value).some(key => !fields.includes(key))) invalid('未対応の入力フィールドです。');
}
export function revisionNumber(value: unknown): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) invalid('revisionが不正です。');
  return value;
}
export function subjectKey(value: unknown, nullable = false): string | null {
  if (nullable && value === null) return null;
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{16,128}$/.test(value)) invalid('個体識別子が不正です。');
  return value;
}
export function mutationKey(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{16,128}$/.test(value)) invalid('mutation IDが不正です。');
  return value;
}
export function explicitInstant(value: unknown): Date | null {
  if (typeof value !== 'string' || !/(Z|[+-]\d\d:\d\d)$/.test(value)) return null;
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed : null;
}
export function dateOf(value: unknown): Date | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value : null;
  if (isObject(value) && typeof value.toDate === 'function') {
    const date = (value.toDate as () => unknown)();
    return date instanceof Date && Number.isFinite(date.getTime()) ? date : null;
  }
  return null;
}
function same(a: unknown, b: unknown): boolean {
  const stampA = dateOf(a), stampB = dateOf(b);
  return stampA || stampB ? stampA?.getTime() === stampB?.getTime() : careActionMutationFingerprint(a ?? null) === careActionMutationFingerprint(b ?? null);
}
export interface PetIdentityPlan {
  subjectId: string;
  profile: admin.firestore.DocumentReference;
  profileData: admin.firestore.DocumentData;
  registry: admin.firestore.DocumentReference;
  introduced: boolean;
}
/** Reads only; the caller applies this plan with its own immutable save in the same transaction. */
export async function planMainPetIdentity(params: {
  db: admin.firestore.Firestore; tx: admin.firestore.Transaction; uid: string;
  expectedSubjectId: string | null; issuedSubjectId: string;
}): Promise<PetIdentityPlan> {
  const {db, tx, uid, expectedSubjectId, issuedSubjectId} = params;
  const profile = db.doc(`users/${uid}/pet_profiles/${MAIN_PET_SLOT}`);
  const snap = await tx.get(profile);
  if (!snap.exists) throw new HttpsError('failed-precondition', '先にうちの子のプロフィールを登録してください。');
  const data = snap.data()!;
  if (data.ownerUid != null && data.ownerUid !== uid) throw new HttpsError('permission-denied', '個体の所有者を確認できません。');
  const current = data.subjectId == null ? null : subjectKey(data.subjectId);
  if (current !== expectedSubjectId) throw new HttpsError('aborted', '対象の個体が更新されています。画面を開き直してください。');
  const subjectId = current ?? issuedSubjectId;
  const registry = db.doc(`users/${uid}/pet_subjects/${subjectId}`);
  const registered = await tx.get(registry);
  if (current && (!registered.exists || registered.get('ownerUid') !== uid || registered.get('active') !== true || registered.get('petId') !== MAIN_PET_SLOT))
    throw new HttpsError('failed-precondition', '有効な個体登録を確認できません。');
  if (!current && registered.exists) throw new HttpsError('already-exists', '個体識別子の作成が競合しました。');
  return {subjectId, profile, profileData: data, registry, introduced: current === null};
}
export function commitIdentityIntroduction(tx: admin.firestore.Transaction, plan: PetIdentityPlan, uid: string, stamp: unknown): void {
  if (!plan.introduced) return;
  tx.create(plan.registry, {schemaVersion: PET_IDENTITY_SCHEMA_VERSION, ownerUid: uid, petId: MAIN_PET_SLOT,
    subjectId: plan.subjectId, active: true, registeredAt: stamp, identityOrigin: 'explicit_current_registration',
    priorRecordsAssigned: false, researchConsentStatus: 'not_assessed'});
  tx.set(plan.profile, {subjectId: plan.subjectId, ownerUid: uid, petId: MAIN_PET_SLOT, identitySchemaVersion: PET_IDENTITY_SCHEMA_VERSION,
    revision: revisionNumber(plan.profileData.revision ?? 0) + 1, acceptedAt: stamp, updatedAt: stamp}, {merge: true});
}
export interface ProfileSaveResult {
  saved: true; mutationId: string; subjectId: string; revision: number; historyRevision: number; changed: boolean; replayed: boolean; acceptedAt?: string; acceptedAtEpochNanoseconds?: string;
}
function profileValues(value: unknown): Record<string, unknown> {
  if (!isObject(value)) invalid('プロフィールが不正です。');
  onlyFields(value, ['name', 'birthday', 'birthdayPrecision', 'species', 'color', 'imageUrl']);
  const result: Record<string, unknown> = {};
  for (const key of ['name', 'species', 'color', 'imageUrl']) {
    if (!(key in value)) continue;
    const raw = value[key];
    if (raw === null && ['color', 'imageUrl'].includes(key)) {result[key] = null; continue;}
    if (typeof raw !== 'string' || raw.length > (key === 'imageUrl' ? 4096 : 200)) invalid('プロフィールの値が不正です。');
    result[key] = raw.trim();
  }
  if ('birthday' in value) {
    if (value.birthday === null) result.birthday = null;
    else {const nanos = profileKnowledgeCutoff(value.birthday); if (nanos === undefined) invalid('誕生日が不正です。'); const date = new Date(Number(nanos / 1000000n)); if (!Number.isFinite(date.getTime()) || date.getTime() > Date.now()) invalid('誕生日が不正です。'); result.birthday = admin.firestore.Timestamp.fromDate(date);}
  }
  if ('birthdayPrecision' in value) {
    if (!['date_only', 'approximate_date', 'unknown', 'legacy_unspecified'].includes(String(value.birthdayPrecision))) invalid('誕生日の精度が不正です。');
    result.birthdayPrecision = value.birthdayPrecision;
  }
  return result;
}
/** Profile edits keep identity; only an explicitly named replacement creates a new subject. */
export async function saveProfileMutation(params: {db: admin.firestore.Firestore; uid: string; data: unknown}): Promise<ProfileSaveResult> {
  const {db, uid, data} = params;
  if (!isObject(data)) invalid('保存内容が不正です。');
  onlyFields(data, ['mutationId', 'expectedRevision', 'expectedSubjectId', 'operation', 'values', 'targetHistoryRevision']);
  const mutationId = mutationKey(data.mutationId);
  const expectedRevision = revisionNumber(data.expectedRevision);
  const expectedSubjectId = subjectKey(data.expectedSubjectId, true);
  if (data.operation !== 'save' && data.operation !== 'replace' && data.operation !== 'cancel_profile_correction') invalid('プロフィール操作が不正です。');
  const operation = data.operation;
  const targetHistoryRevision = data.targetHistoryRevision == null ? null : revisionNumber(data.targetHistoryRevision);
  if (data.operation === 'cancel_profile_correction' ? targetHistoryRevision === null || targetHistoryRevision === 0 : targetHistoryRevision !== null) invalid('プロフィール訂正の取消対象が不正です。');
  const inputValues = profileValues(data.values ?? (data.operation === 'cancel_profile_correction' ? {} : null));
  if (data.operation === 'cancel_profile_correction' && Object.keys(inputValues).length) invalid('取消に新しいプロフィール値は不要です。');
  const fingerprint = careActionMutationFingerprint(data);
  const profile = db.doc(`users/${uid}/pet_profiles/${MAIN_PET_SLOT}`), receipt = profile.collection('mutations').doc(mutationId);
  const issuedSubjectId = randomUUID();
  const result = await db.runTransaction(async tx => {
    const [beforeSnap, receiptSnap] = await Promise.all([tx.get(profile), tx.get(receipt)]);
    if (receiptSnap.exists) {
      if (receiptSnap.get('requestFingerprint') !== fingerprint) throw new HttpsError('already-exists', '同じmutation IDの内容が異なります。');
      return {...receiptSnap.get('result'), replayed: true} as ProfileSaveResult;
    }
    const before = beforeSnap.data() ?? {};
    const values = {...inputValues};
    const replacing = data.operation === 'replace';
    if ('birthday' in values && !('birthdayPrecision' in values)) {
      values.birthdayPrecision = values.birthday === null ? 'unknown' : same(before.birthday, values.birthday) && !replacing ? before.birthdayPrecision ?? 'legacy_unspecified' : 'legacy_unspecified';
    }
    const afterAttributes = normalizeProfileAttributes({...(!replacing ? before : {}), ...values});
    if (('birthday' in values || 'birthdayPrecision' in values) && afterAttributes.birthday.quality === 'invalid') invalid('誕生日と精度の組み合わせが不正です。');
    if (before.ownerUid != null && before.ownerUid !== uid) throw new HttpsError('permission-denied', '所有者を確認できません。');
    const currentRevision = revisionNumber(before.revision ?? 0);
    const currentSubject = before.subjectId == null ? null : subjectKey(before.subjectId);
    if (currentRevision !== expectedRevision || currentSubject !== expectedSubjectId)
      throw new HttpsError('aborted', '別の保存が先に完了しました。プロフィールを開き直してください。');
    if (data.operation === 'replace' && (!currentSubject || typeof values.name !== 'string' || typeof values.species !== 'string'))
      throw new HttpsError('failed-precondition', '入れ替え対象と新しい個体のプロフィールを確認してください。');
    if (data.operation === 'replace') {
      // Current analyses are still user-scoped. A new subject must not inherit another animal's Bronze/Silver/Gold.
      // Full multi-subject analysis is deliberately outside this change.
      const existing = await Promise.all(['weight_records', 'distance_records', 'weight_record_history', 'distance_record_history', 'daily_checkins', 'daily_care_actions',
        'breeding_environments', 'switchbot_readings', 'daily_health_features', 'health_assessments', 'analysis_readiness',
        'individual_insights', 'personalized_reports', 'personality_reports', 'observation_days']
        .map(name => tx.get(db.collection(`users/${uid}/${name}`).limit(1))));
      if (existing.some(rows => !rows.empty)) throw new HttpsError('failed-precondition', '既存の記録や分析があるため、個体を入れ替えできません。個体別の分離に対応するまでは現在の個体を編集してください。');
    }
    if (!beforeSnap.exists && (typeof values.name !== 'string' || typeof values.species !== 'string'))
      throw new HttpsError('failed-precondition', 'うちの子の名前と種類を登録してください。');
    const subjectId = data.operation === 'replace' ? issuedSubjectId : currentSubject ?? issuedSubjectId;
    const registry = db.doc(`users/${uid}/pet_subjects/${subjectId}`);
    const registrySnap = await tx.get(registry);
    let oldRegistry: admin.firestore.DocumentReference | null = null;
    if (currentSubject && data.operation === 'replace') {
      oldRegistry = db.doc(`users/${uid}/pet_subjects/${currentSubject}`);
      const old = await tx.get(oldRegistry);
      if (!old.exists || old.get('ownerUid') !== uid || old.get('active') !== true) throw new HttpsError('failed-precondition', '以前の個体登録を確認できません。');
    } else if (currentSubject && (!registrySnap.exists || registrySnap.get('ownerUid') !== uid || registrySnap.get('active') !== true)) {
      throw new HttpsError('failed-precondition', '個体登録を確認できません。');
    }
    if (subjectId !== currentSubject && registrySnap.exists) throw new HttpsError('already-exists', '個体識別子の作成が競合しました。');
    const historyPlan = await planProfileHistoryMutation({db, tx, uid, subjectId, before: data.operation === 'replace' ? {} : before,
      after: data.operation === 'replace' ? {species: '', birthday: null, ...values} : {...before, ...values},
      profileRevision: currentRevision + 1, mutationId, operation, targetHistoryRevision, hadLegacyProfile: beforeSnap.exists && data.operation !== 'replace'});
    if (data.operation === 'cancel_profile_correction' && historyPlan.next) Object.assign(values, profileAttributesProjection(historyPlan.values));
    const changed = !currentSubject || data.operation === 'replace' || historyPlan.next !== null || Object.keys(values).some(key => !same(before[key], values[key]));
    const revision = currentRevision + (changed ? 1 : 0);
    const saved: ProfileSaveResult = {saved: true, mutationId, subjectId, revision, historyRevision: historyPlan.historyRevision, changed, replayed: false};
    const stamp = admin.firestore.FieldValue.serverTimestamp();
    if (subjectId !== currentSubject) tx.create(registry, {schemaVersion: PET_IDENTITY_SCHEMA_VERSION, ownerUid: uid, petId: MAIN_PET_SLOT, subjectId,
      active: true, registeredAt: stamp, identityOrigin: data.operation === 'replace' ? 'explicit_replacement' : 'explicit_current_registration',
      priorRecordsAssigned: false, researchConsentStatus: 'not_assessed'});
    if (oldRegistry) tx.update(oldRegistry, {active: false, retiredAt: stamp, replacedBySubjectId: subjectId});
    commitProfileHistoryMutation(tx, historyPlan, stamp);
    if (changed) {
      const patch = {...values, subjectId, ownerUid: uid, petId: MAIN_PET_SLOT, identitySchemaVersion: PET_IDENTITY_SCHEMA_VERSION,
        revision, profileHistoryRevision: historyPlan.historyRevision, profileHistorySchemaVersion: PROFILE_HISTORY_SCHEMA_VERSION, acceptedAt: stamp, updatedAt: stamp};
      if (data.operation === 'replace') tx.set(profile, {name: '', birthday: null, species: '', color: null, imageUrl: null, ...patch, createdAt: stamp});
      else tx.set(profile, {...patch, ...(!beforeSnap.exists ? {createdAt: stamp} : {})}, {merge: true});
      tx.set(db.doc(`users/${uid}`), {has_subcollections: true}, {merge: true});
    }
    tx.create(receipt, {schemaVersion: PET_IDENTITY_SCHEMA_VERSION, ownerUid: uid, subjectId, requestFingerprint: fingerprint, acceptedAt: stamp, result: saved});
    return saved;
  });
  const receiptTimestamp = (await receipt.get()).get('acceptedAt');
  const accepted = dateOf(receiptTimestamp), nanos = profileEpochNanoseconds(receiptTimestamp);
  if (!accepted || nanos === null) throw new HttpsError('internal', '受理日時を確認できません。同じ内容を再送してください。');
  return {...result, acceptedAt: accepted.toISOString(), acceptedAtEpochNanoseconds: nanos.toString()};
}
export const saveMainPetProfile = onCall({region: 'asia-northeast1'}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  return saveProfileMutation({db: admin.firestore(), uid, data: request.data});
});
