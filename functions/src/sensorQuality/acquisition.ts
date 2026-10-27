import {createHash, randomUUID} from 'node:crypto';
import * as admin from 'firebase-admin';

/** Acquisition evidence is separate from the unchanged environment/health calculation. */
export const SENSOR_ACQUISITION_SCHEMA_VERSION = 1;
export const SENSOR_CAPTURE_BLOCK_FIELD = 'sensorCaptureBlockedForDeletion';
export class SensorCaptureUnavailable extends Error {
  readonly code = 'sensor_capture_unavailable';
  constructor() {super('Sensor capture is unavailable.'); this.name = 'SensorCaptureUnavailable';}
}
export const SENSOR_POLLING_POLICY_VERSION = 'switchbot_status_60m_utc_v1';
export type SensorAcquisitionRoute = 'scheduled' | 'manual_owner' | 'manual_operator_all' | 'unknown';
export interface SensorStatus {temperature: number | null; humidity: number | null; battery: number | null;}
export interface SensorApiMetadata {httpStatus: number | null; providerStatusCode: number | null; responseShape: 'valid' | 'invalid' | 'unknown';}
export interface SensorApiResult {reading: SensorStatus; api: SensorApiMetadata;}
export interface SensorSchedulerContext {
  jobName: string | null; scheduleTimeCandidate: string | null;
  logicalSlotId: string | null; scheduledFor: string | null;
  slotIdentityStatus: 'verified' | 'unverified' | 'not_applicable'; reason: string | null;
}
export interface SensorBindingSnapshot {
  subjectId: string | null; environmentPath: string; environmentRevision: number | null;
  status: 'registered_config' | 'unknown'; reasons: string[];
}
export type SensorMetricValidity = 'valid' | 'missing' | 'invalid';
export interface SensorValidity {
  api: 'valid' | 'invalid' | 'unknown'; temperature: SensorMetricValidity;
  humidity: SensorMetricValidity; battery: SensorMetricValidity;
}
export interface SensorAttemptStart {
  schemaVersion: number; attemptId: string; invocationId: string; ownerUid: string;
  deviceId: string; route: SensorAcquisitionRoute; policyVersion: string;
  binding: SensorBindingSnapshot; scheduler: SensorSchedulerContext;
}
export interface SensorAttemptTerminal {
  status: 'reading_saved' | 'request_failed'; requestAttempted: boolean | null;
  requestStartedAt: string; responseReceivedAt: string | null;
  clockSource: 'functions_process_clock'; api: SensorApiMetadata;
  validity: SensorValidity; errorCode: string | null; readingPath: string | null;
  readingTs: string | null; measuredAt: null; providerUpdatedAt: null; freshness: 'unknown';
  acceptedAt?: unknown;
}
export interface SensorStoredAttempt extends SensorAttemptStart {preparedAt?: unknown; terminal?: SensorAttemptTerminal; fingerprint?: string;}
export interface SensorRawWrite {path: string; data: Record<string, unknown>;}
export interface SensorPreparation {created: boolean; attempt: SensorStoredAttempt; priorReading?: {path: string; reading: SensorStatus; ts: string | null; verified: boolean};}
export interface SensorAcquisitionPersistence {
  prepare(start: SensorAttemptStart): Promise<SensorPreparation>;
  complete(attemptId: string, terminal: SensorAttemptTerminal, raw?: SensorRawWrite): Promise<SensorAttemptTerminal>;
  saveUnverified(raw: SensorRawWrite): Promise<{path: string; verified: boolean}>;
  getReading?(path: string): Promise<SensorStatus | null>;
}
export interface RunSensorAcquisitionOptions {
  db?: admin.firestore.Firestore; store?: SensorAcquisitionPersistence;
  uid: string; deviceId: string; route: SensorAcquisitionRoute;
  request: () => Promise<SensorApiResult>; assess: () => Promise<void>;
  binding?: SensorBindingSnapshot; scheduler?: SensorSchedulerContext;
  attemptId?: string; invocationId?: string; clock?: () => Date;
  warn?: (code: string) => void;
}
export interface SensorAcquisitionResult {
  attemptId: string; readingPath: string | null; reading: SensorStatus | null;
  evidenceStatus: 'verified' | 'unverified' | 'pending'; replayed: boolean;
}
export class SensorRequestError extends Error {
  readonly code: 'network_error' | 'http_error' | 'parse_error' | 'unknown_error';
  readonly httpStatus: number | null;
  constructor(code: SensorRequestError['code'], httpStatus?: number) {
    super(`SwitchBot acquisition failed (${code}).`); this.name = 'SensorRequestError';
    this.code = code; this.httpStatus = Number.isInteger(httpStatus) ? httpStatus! : null;
  }
}
export class SensorPersistenceError extends Error {
  readonly code = 'reading_persistence_unknown';
  constructor() {super('SwitchBot reading persistence could not be confirmed.'); this.name = 'SensorPersistenceError';}
}
class SensorIdentityConflict extends Error {
  readonly code = 'sensor_acquisition_identity_conflict';
  constructor() {super('Acquisition identity already belongs to different content.'); this.name = 'SensorIdentityConflict';}
}
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical((value as Record<string, unknown>)[key])]));
  if (typeof value === 'number' && !Number.isFinite(value)) return String(value);
  return value;
}
function digest(value: unknown): string {return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');}
function safeString(value: unknown, max = 512): string | null {return typeof value === 'string' && value.length > 0 && value.length <= max ? value : null;}
function validInstant(value: unknown): string | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return null;
  const date = new Date(value); return Number.isFinite(date.getTime()) ? date.toISOString() : null;
}
function identifier(value: string): string {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new Error('Invalid acquisition identifier.');
  return value;
}
/** The deployed groc schedule is deliberately unverified until its delivery metadata is proven. */
export function deriveSchedulerContext(
  event: {jobName?: unknown; scheduleTime?: unknown} | null | undefined,
  proof: {scheduleTimeVerified?: boolean; expectedJobName?: string} = {},
): SensorSchedulerContext {
  const jobName = safeString(event?.jobName);
  const candidate = validInstant(event?.scheduleTime);
  const verified = proof.scheduleTimeVerified === true && !!jobName && !!candidate && (!proof.expectedJobName || proof.expectedJobName === jobName);
  return {
    jobName, scheduleTimeCandidate: candidate,
    logicalSlotId: verified ? digest({jobName, scheduledFor: candidate, policyVersion: SENSOR_POLLING_POLICY_VERSION}) : null,
    scheduledFor: verified ? candidate : null,
    slotIdentityStatus: verified ? 'verified' : jobName ? 'unverified' : 'not_applicable',
    reason: verified ? null : jobName ? 'groc_scheduled_time_not_verified' : 'scheduler_origin_not_confirmed',
  };
}
function safeApi(metadata: SensorApiMetadata): SensorApiMetadata {
  return {httpStatus: Number.isInteger(metadata.httpStatus) ? metadata.httpStatus : null,
    providerStatusCode: Number.isInteger(metadata.providerStatusCode) ? metadata.providerStatusCode : null,
    responseShape: ['valid', 'invalid', 'unknown'].includes(metadata.responseShape) ? metadata.responseShape : 'unknown'};
}
/** Quality validation never changes the legacy values passed to environment assessment. */
export function validateSensorResult(result: SensorApiResult): SensorValidity {
  const api = safeApi(result.api);
  const metric = (value: unknown): SensorMetricValidity => value == null ? 'missing' : typeof value === 'number' && Number.isFinite(value) ? 'valid' : 'invalid';
  return {api: api.httpStatus != null && (api.httpStatus < 200 || api.httpStatus >= 300) || api.providerStatusCode != null && api.providerStatusCode !== 100 || api.responseShape === 'invalid' ? 'invalid'
    : api.httpStatus != null && api.providerStatusCode === 100 && api.responseShape === 'valid' ? 'valid' : 'unknown',
  temperature: metric(result.reading.temperature), humidity: metric(result.reading.humidity), battery: metric(result.reading.battery)};
}
/** Current registration only: not proof of physical placement or historical individual identity. */
export async function snapshotSensorBinding(db: admin.firestore.Firestore, uid: string): Promise<SensorBindingSnapshot> {
  const environmentPath = `users/${uid}/breeding_environments/main_env`;
  try {
    const [pet, environment] = await Promise.all([db.doc(`users/${uid}/pet_profiles/main_pet`).get(), db.doc(environmentPath).get()]);
    const subjectId = safeString(pet.get('subjectId'), 128);
    const revision = environment.get('revision');
    return {subjectId, environmentPath, environmentRevision: Number.isSafeInteger(revision) && revision >= 1 ? revision : null,
      status: subjectId ? 'registered_config' : 'unknown', reasons: subjectId ? ['physical_placement_not_verified'] : ['subject_registration_unknown', 'physical_placement_not_verified']};
  } catch {
    return {subjectId: null, environmentPath, environmentRevision: null, status: 'unknown', reasons: ['binding_read_failed', 'physical_placement_not_verified']};
  }
}
/** Server-only evidence. No request to the external API occurs inside these transactions. */
export class FirestoreAcquisitionStore implements SensorAcquisitionPersistence {
  constructor(private readonly db: admin.firestore.Firestore, private readonly uid: string) {}
  private async assertCaptureAvailable(transaction: admin.firestore.Transaction): Promise<void> {
    const config = await transaction.get(this.db.doc(`users/${this.uid}/integrations/switchbot`));
    if (!config.exists || config.get(SENSOR_CAPTURE_BLOCK_FIELD) === true) throw new SensorCaptureUnavailable();
  }
  private attempt(id: string): admin.firestore.DocumentReference {return this.db.doc(`users/${this.uid}/sensor_acquisition_attempts/${identifier(id)}`);}
  async prepare(start: SensorAttemptStart): Promise<SensorPreparation> {
    const ref = this.attempt(start.attemptId); const fingerprint = digest(start);
    const rawRef = this.db.doc(`users/${this.uid}/switchbot_readings/acq_${start.attemptId}`);
    return this.db.runTransaction(async transaction => {
      await this.assertCaptureAvailable(transaction);
      const [snapshot, raw] = await Promise.all([transaction.get(ref), transaction.get(rawRef)]);
      const previous = snapshot.exists ? snapshot.data() as SensorStoredAttempt : null;
      if (previous && previous.fingerprint !== fingerprint) throw new SensorIdentityConflict();
      if (raw.exists) {
        if (raw.get('acquisitionId') !== start.attemptId || raw.get('acquisitionFingerprint') !== fingerprint) throw new SensorIdentityConflict();
        const terminal = previous?.terminal;
        const verified = raw.get('acquisitionVerification') === 'verified' && terminal?.status === 'reading_saved' && terminal.readingPath === rawRef.path && terminal.readingTs === raw.get('ts');
        // A previously persisted fail-open raw is already a receipt of this request.
        // Do not poll again merely to repair missing evidence or create an earlier receipt.
        return {created: false, attempt: previous ?? start, priorReading: {path: rawRef.path,
          reading: {temperature: raw.get('temperature') ?? null, humidity: raw.get('humidity') ?? null, battery: raw.get('battery') ?? null},
          ts: typeof raw.get('ts') === 'string' ? raw.get('ts') : null, verified}};
      }
      if (previous) return {created: false, attempt: previous};
      transaction.create(ref, {...start, fingerprint, preparedAt: admin.firestore.FieldValue.serverTimestamp()});
      return {created: true, attempt: start};
    });
  }
  async complete(attemptId: string, terminal: SensorAttemptTerminal, raw?: SensorRawWrite): Promise<SensorAttemptTerminal> {
    const ref = this.attempt(attemptId);
    return this.db.runTransaction(async transaction => {
      await this.assertCaptureAvailable(transaction);
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new SensorPersistenceError();
      const previous = snapshot.data() as SensorStoredAttempt;
      // Immutable confirmation: delayed failures cannot replace a successful reading.
      if (previous.terminal) return previous.terminal;
      const rawRef = raw ? this.db.doc(raw.path) : null;
      const rawSnapshot = rawRef ? await transaction.get(rawRef) : null;
      if (rawSnapshot?.exists && rawSnapshot.get('acquisitionId') !== attemptId) throw new SensorIdentityConflict();
      if (rawRef && !rawSnapshot?.exists) transaction.create(rawRef, {...raw!.data, createdAt: admin.firestore.FieldValue.serverTimestamp(), acquisitionVerification: 'verified'});
      if (rawRef && rawSnapshot?.exists) {
        // Unverified fallback cannot be retroactively promoted with an earlier acceptance time.
        if (rawSnapshot.get('acquisitionVerification') !== 'verified') throw new SensorPersistenceError();
      }
      transaction.update(ref, {terminal: {...terminal, acceptedAt: admin.firestore.FieldValue.serverTimestamp()}});
      return terminal;
    });
  }
  async saveUnverified(raw: SensorRawWrite): Promise<{path: string; verified: boolean}> {
    const ref = this.db.doc(raw.path);
    return this.db.runTransaction(async transaction => {
      await this.assertCaptureAvailable(transaction);
      const snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        if (snapshot.get('acquisitionId') !== raw.data.acquisitionId || snapshot.get('acquisitionFingerprint') !== raw.data.acquisitionFingerprint) throw new SensorIdentityConflict();
        return {path: raw.path, verified: snapshot.get('acquisitionVerification') === 'verified'};
      }
      transaction.create(ref, {...raw.data, acquisitionVerification: 'unverified', createdAt: admin.firestore.FieldValue.serverTimestamp()});
      return {path: raw.path, verified: false};
    });
  }
  async getReading(path: string): Promise<SensorStatus | null> {
    const snapshot = await this.db.doc(path).get();
    if (!snapshot.exists) return null;
    return {temperature: snapshot.get('temperature') ?? null, humidity: snapshot.get('humidity') ?? null, battery: snapshot.get('battery') ?? null};
  }
}
function sanitizedError(error: unknown): SensorRequestError {return error instanceof SensorRequestError ? error : new SensorRequestError('unknown_error');}
function emptyApi(): SensorApiMetadata {return {httpStatus: null, providerStatusCode: null, responseShape: 'unknown'};}
/** One genuine API request, one stable reading identity; evidence outages do not trigger repair polling. */
export async function runSensorAcquisition(options: RunSensorAcquisitionOptions): Promise<SensorAcquisitionResult> {
  const clock = options.clock ?? (() => new Date());
  const attemptId = identifier(options.attemptId ?? randomUUID());
  const invocationId = identifier(options.invocationId ?? attemptId);
  const store = options.store ?? (options.db ? new FirestoreAcquisitionStore(options.db, options.uid) : null);
  if (!store) throw new Error('An acquisition store is required.');
  const binding = options.binding ?? (options.db ? await snapshotSensorBinding(options.db, options.uid) : {subjectId: null, environmentPath: `users/${options.uid}/breeding_environments/main_env`, environmentRevision: null, status: 'unknown' as const, reasons: ['binding_unknown']});
  const start: SensorAttemptStart = {schemaVersion: SENSOR_ACQUISITION_SCHEMA_VERSION, attemptId, invocationId, ownerUid: options.uid,
    deviceId: options.deviceId, route: options.route, policyVersion: SENSOR_POLLING_POLICY_VERSION, binding,
    scheduler: options.scheduler ?? deriveSchedulerContext(null)};
  let evidencePrepared = false;
  let preparation: SensorPreparation | null = null;
  try {preparation = await store.prepare(start); evidencePrepared = true;}
  catch (error) {
    if (error instanceof SensorIdentityConflict || error instanceof SensorCaptureUnavailable) throw error;
    options.warn?.('sensor_evidence_prepare_unavailable');
  }
  if (preparation && !preparation.created) {
    if (preparation.priorReading) {
      await options.assess();
      return {attemptId, readingPath: preparation.priorReading.path, reading: preparation.priorReading.reading,
        evidenceStatus: preparation.priorReading.verified ? 'verified' : 'unverified', replayed: true};
    }
    const terminal = preparation.attempt.terminal;
    if (terminal?.status === 'request_failed') throw new SensorRequestError((terminal.errorCode as SensorRequestError['code']) ?? 'unknown_error', terminal.api.httpStatus ?? undefined);
    let reading: SensorStatus | null = null;
    if (terminal?.readingPath && store.getReading) {
      try {reading = await store.getReading(terminal.readingPath);} catch {options.warn?.('sensor_replay_read_unavailable');}
    }
    // A prior downstream evaluation failure may be retried without a new request or raw.
    if (terminal?.status === 'reading_saved' && reading) await options.assess();
    // Once an existing attempt is known, read failure must never trigger another API call.
    return {attemptId, readingPath: terminal?.readingPath ?? null, reading,
      evidenceStatus: terminal ? 'verified' : 'pending', replayed: true};
  }
  const requestStartedAt = clock().toISOString();
  let result: SensorApiResult;
  let responseReceivedAt: string;
  try {result = await options.request(); responseReceivedAt = clock().toISOString();}
  catch (error) {
    const safe = sanitizedError(error);
    if (evidencePrepared) {
      const api = {...emptyApi(), httpStatus: safe.httpStatus};
      const terminal: SensorAttemptTerminal = {status: 'request_failed', requestAttempted: safe.code === 'unknown_error' ? null : true, requestStartedAt,
        responseReceivedAt: safe.code === 'http_error' || safe.code === 'parse_error' ? clock().toISOString() : null,
        clockSource: 'functions_process_clock', api, validity: {api: safe.code === 'http_error' || safe.code === 'parse_error' ? 'invalid' : 'unknown', temperature: 'missing', humidity: 'missing', battery: 'missing'},
        errorCode: safe.code, readingPath: null, readingTs: null, measuredAt: null, providerUpdatedAt: null, freshness: 'unknown'};
      try {await store.complete(attemptId, terminal);} catch (error) {if (error instanceof SensorCaptureUnavailable) throw error; options.warn?.('sensor_evidence_terminal_unavailable');}
    }
    throw safe;
  }
  // This remains the process clock after response parsing, not a measurement timestamp.
  const ts = clock().toISOString();
  const readingPath = `users/${options.uid}/switchbot_readings/acq_${attemptId}`;
  const raw: SensorRawWrite = {path: readingPath, data: {ts, ...result.reading, source: 'status',
    acquisitionId: attemptId, acquisitionFingerprint: digest(start), acquisitionSchemaVersion: SENSOR_ACQUISITION_SCHEMA_VERSION}};
  const terminal: SensorAttemptTerminal = {status: 'reading_saved', requestAttempted: true, requestStartedAt, responseReceivedAt,
    clockSource: 'functions_process_clock', api: safeApi(result.api), validity: validateSensorResult(result), errorCode: null,
    readingPath, readingTs: ts, measuredAt: null, providerUpdatedAt: null, freshness: 'unknown'};
  let evidenceStatus: SensorAcquisitionResult['evidenceStatus'] = 'unverified';
  if (evidencePrepared) {
    try {
      const confirmed = await store.complete(attemptId, terminal, raw);
      if (confirmed.status === 'reading_saved' && confirmed.readingPath === raw.path && confirmed.readingTs === ts) evidenceStatus = 'verified';
      else options.warn?.('sensor_terminal_confirmation_mismatch');
    }
    catch (error) {if (error instanceof SensorIdentityConflict || error instanceof SensorCaptureUnavailable) throw error; options.warn?.('sensor_evidence_commit_unavailable');}
  }
  if (evidenceStatus !== 'verified') {
    try {const saved = await store.saveUnverified(raw); if (saved.verified) evidenceStatus = 'verified';}
    catch (error) {if (error instanceof SensorCaptureUnavailable) throw error; throw new SensorPersistenceError();}
  }
  await options.assess();
  return {attemptId, readingPath, reading: result.reading, evidenceStatus, replayed: false};
}
