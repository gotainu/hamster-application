import {createHash} from 'node:crypto';
import * as admin from 'firebase-admin';
import {SENSOR_CAPTURE_BLOCK_FIELD, SensorCaptureUnavailable} from './acquisition';

export const SENSOR_QUALITY_SPEC_VERSION = 'sensor_acquisition_quality_v2';
export const SENSOR_QUALITY_READ_SPEC_VERSION = 'sensor_quality_window_read_v2';
const NANOSECOND = 1000000000n;
type Json = Record<string, unknown>;
export interface SensorEvidenceDocument {id: string; data: Json; updatedAt?: unknown;}
export interface SensorQualityCompleteness {
  attempts: 'complete' | 'partial'; readings: 'complete' | 'partial'; states: 'complete' | 'partial'; reasons: string[];
}
/** Internal evidence only. Current groc/configuration transitions do not satisfy
 * this contract; no client API accepts assertions of verified target intervals. */
export interface VerifiedSensorScheduleInterval {
  id: string; from: unknown; to: unknown; acceptedAt: unknown; active: boolean;
  deviceId: string | null; policyVersion: string; jobName: string;
  anchor: unknown; intervalMinutes: number; verification: 'verified';
  evidenceLoggingVerified?: boolean;
}
export interface AggregateSensorQualityInput {
  uid?: string; windowStart: unknown; windowEnd: unknown; timeZone: 'Asia/Tokyo' | 'UTC'; knowledgeCutoff: unknown;
  attempts: SensorEvidenceDocument[]; readings: SensorEvidenceDocument[]; states: SensorEvidenceDocument[];
  deviceId?: string; completeness?: SensorQualityCompleteness; verifiedIntervals?: VerifiedSensorScheduleInterval[];
  evidenceRetainedFrom?: unknown;
}
function obj(value: unknown): Json {return value && typeof value === 'object' && !Array.isArray(value) ? value as Json : {};}
function text(value: unknown): string | null {return typeof value === 'string' && value.length > 0 ? value : null;}
/** Firestore receipt comparisons never truncate the sub-millisecond component. */
export function sensorTimestampNanoseconds(value: unknown): bigint | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? BigInt(value.getTime()) * 1000000n : null;
  const stamp = obj(value), seconds = stamp.seconds ?? stamp._seconds, nanos = stamp.nanoseconds ?? stamp._nanoseconds;
  if (Number.isSafeInteger(seconds) && Number.isInteger(nanos) && Number(nanos) >= 0 && Number(nanos) < 1e9) return BigInt(Number(seconds)) * NANOSECOND + BigInt(Number(nanos));
  if (typeof value !== 'string') return null;
  const match = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (!match) return null;
  const base = Date.parse(match[1] + match[3]);
  if (!Number.isFinite(base)) return null;
  const offset = match[3] === 'Z' ? 0 : (match[3][0] === '+' ? 1 : -1) * (Number(match[3].slice(1, 3)) * 60 + Number(match[3].slice(4, 6))) * 60000;
  if (new Date(base + offset).toISOString().slice(0, 19) !== match[1]) return null;
  return BigInt(base) * 1000000n + BigInt((match[2] ?? '').padEnd(9, '0'));
}
function instant(value: bigint): string {
  let seconds = value / NANOSECOND, nanos = value % NANOSECOND;
  if (nanos < 0n) {seconds--; nanos += NANOSECOND;}
  return new Date(Number(seconds * 1000n)).toISOString().replace(/\.\d{3}Z$/, `.${nanos.toString().padStart(9, '0')}Z`);
}
function requiredInstant(value: unknown, label: string): bigint {const parsed = sensorTimestampNanoseconds(value); if (parsed == null) throw new Error(`Invalid ${label}.`); return parsed;}
function canonical(value: unknown): unknown {
  if (typeof value === 'bigint') return value.toString();
  if (value instanceof Date || value && typeof value === 'object' && ('seconds' in value || '_seconds' in value)) {const parsed = sensorTimestampNanoseconds(value); if (parsed != null) return instant(parsed);}
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(obj(value)[key])]));
  return typeof value === 'number' && !Number.isFinite(value) ? String(value) : value;
}
function digest(value: unknown): string {return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');}
function inWindow(value: bigint | null, start: bigint, end: bigint, cutoff: bigint): value is bigint {return value != null && value >= start && value < end && value <= cutoff;}
function fields(data: Json, keys: string[]): Json {return Object.fromEntries(keys.filter(key => data[key] !== undefined).map(key => [key, data[key]]));}
function finite(value: unknown): boolean {return typeof value === 'number' && Number.isFinite(value);}
const metrics = ['temperature', 'humidity'] as const;
type Metric = typeof metrics[number];
function distribution(times: bigint[], start: bigint, right: bigint) {
  const values = times.filter(t => t >= start && t <= right).sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
  const seconds = (v: bigint) => Number(v) / 1e9, duration = seconds(right - start);
  if (!values.length) return {count: 0, firstAt: null, lastAt: null, adjacentMaxGapSeconds: null, startGapSeconds: duration, endGapSeconds: duration, maxGapSeconds: duration};
  const startGapSeconds = seconds(values[0] - start), endGapSeconds = seconds(right - values[values.length - 1]);
  const adjacent = values.slice(1).map((v, i) => seconds(v - values[i]));
  const adjacentMaxGapSeconds = adjacent.length ? Math.max(...adjacent) : null;
  return {count: values.length, firstAt: instant(values[0]), lastAt: instant(values[values.length - 1]), adjacentMaxGapSeconds, startGapSeconds, endGapSeconds, maxGapSeconds: Math.max(startGapSeconds, endGapSeconds, adjacentMaxGapSeconds ?? 0)};
}
function uniqueDocuments(rows: SensorEvidenceDocument[], kind: string, reasons: Set<string>): SensorEvidenceDocument[] {
  const grouped = new Map<string, SensorEvidenceDocument[]>();
  for (const row of rows) {const list = grouped.get(row.id) ?? []; list.push(row); grouped.set(row.id, list);}
  return [...grouped].sort(([a], [b]) => a.localeCompare(b)).flatMap(([, values]) => {
    if (new Set(values.map(v => digest(v.data))).size > 1) {reasons.add(`conflicting_${kind}_identity`); return [];}
    return [values[0]];
  });
}
function expectedOpportunities(input: AggregateSensorQualityInput, start: bigint, end: bigint, cutoff: bigint, reasons: Set<string>) {
  const intervals = (input.verifiedIntervals ?? []).filter(item => {
    const accepted = sensorTimestampNanoseconds(item.acceptedAt);
    return item.verification === 'verified' && accepted != null && accepted <= cutoff;
  }).map(item => ({...item, left: sensorTimestampNanoseconds(item.from), right: sensorTimestampNanoseconds(item.to)}))
    .filter(item => item.left != null && item.right != null && item.left < item.right && item.right > start && item.left < end)
    .sort((a, b) => a.left! < b.left! ? -1 : 1);
  const through = cutoff < end ? cutoff : end;
  if (through < start) return {count: 0, keys: new Set<string>(), times: [] as bigint[], reasons: [] as string[], loggingVerified: false};
  for (let index = 1; index < intervals.length; index++) {
    if (intervals[index].left! < intervals[index - 1].right! && intervals[index].left! < through) {reasons.add('target_interval_history_conflicting'); return {count: null, keys: null, times: [] as bigint[], reasons: ['target_interval_history_conflicting'], loggingVerified: false};}
  }
  let cursor = start;
  for (const interval of intervals) {
    if (interval.left! > cursor || interval.left! < cursor && cursor !== start) {reasons.add('target_interval_history_incomplete'); return {count: null, keys: null, times: [] as bigint[], reasons: ['target_interval_history_incomplete'], loggingVerified: false};}
    if (interval.right! > cursor) cursor = interval.right!;
    if (cursor >= through) break;
  }
  if (!intervals.length || cursor < through) {reasons.add('expected_schedule_unknown'); return {count: null, keys: null, times: [] as bigint[], reasons: ['expected_schedule_unknown'], loggingVerified: false};}
  const keys = new Set<string>(), times: bigint[] = [];
  for (const interval of intervals) {
    if (!interval.active || input.deviceId && interval.deviceId !== input.deviceId) continue;
    const anchor = sensorTimestampNanoseconds(interval.anchor);
    if (!interval.deviceId || !interval.jobName || !interval.policyVersion || anchor == null || interval.intervalMinutes !== 60) {reasons.add('schedule_anchor_unknown'); return {count: null, keys: null, times: [], reasons: ['schedule_anchor_unknown'], loggingVerified: false};}
    const step = BigInt(interval.intervalMinutes) * 60n * NANOSECOND;
    const left = interval.left! > start ? interval.left! : start;
    let first = anchor + ((left - anchor) / step) * step;
    while (first < left) first += step;
    while (first - step >= left) first -= step;
    for (let slot = first; slot < interval.right! && slot < end && slot <= cutoff; slot += step) {
      if (keys.size >= 10000) {reasons.add('expected_slot_limit_reached'); return {count: null, keys: null, times: [], reasons: ['expected_slot_limit_reached'], loggingVerified: false};}
      const scheduledFor = new Date(Number(slot / 1000000n)).toISOString();
      const logical = digest({jobName: interval.jobName, scheduledFor, policyVersion: interval.policyVersion});
      const key = `${interval.deviceId}|${logical}`;
      if (!keys.has(key)) {keys.add(key); times.push(slot);}
    }
  }
  const loggingVerified = intervals.every(interval => interval.evidenceLoggingVerified === true);
  if (!loggingVerified) reasons.add('logging_continuity_unknown');
  return {count: keys.size, keys, times, reasons: [] as string[], loggingVerified};
}

/** Descriptive acquisition evidence, never sensor uptime/measurement coverage. */
export function aggregateSensorQuality(input: AggregateSensorQualityInput) {
  const start = requiredInstant(input.windowStart, 'window start'), end = requiredInstant(input.windowEnd, 'window end'), cutoff = requiredInstant(input.knowledgeCutoff, 'knowledge cutoff');
  if (end <= start || !['Asia/Tokyo', 'UTC'].includes(input.timeZone)) throw new Error('Invalid quality window.');
  const right = cutoff < start ? start : cutoff < end ? cutoff : end;
  const completeness = input.completeness ?? {attempts: 'complete', readings: 'complete', states: 'complete', reasons: []};
  const reasons = new Set(completeness.reasons), manifest: Record<string, unknown[]> = {attempts: [], readings: [], states: [], intervals: []};
  const attemptDevices = new Map<string, string>();
  const visibleAttempts = new Map<string, Json>(), terminals = new Map<string, Json>(), policyVersions = new Set<string>(), subjectIds = new Set<string>();
  let unknownWindowMembership = false, timestampedEvidenceComplete = true;
  const retainedFrom = sensorTimestampNanoseconds(input.evidenceRetainedFrom);
  if (retainedFrom != null && start < retainedFrom) {reasons.add('evidence_expired'); timestampedEvidenceComplete = false;}
  for (const row of uniqueDocuments(input.attempts, 'attempt', reasons)) {
    const accepted = sensorTimestampNanoseconds(row.data.preparedAt);
    if (accepted == null) {reasons.add('attempt_receipt_unknown'); timestampedEvidenceComplete = false; continue;}
    if (accepted > cutoff) continue;
    const registeredDevice = text(row.data.deviceId); if (registeredDevice) attemptDevices.set(row.id, registeredDevice);
    if (input.deviceId && row.data.deviceId !== input.deviceId) continue;
    const safe = fields(row.data, ['attemptId', 'invocationId', 'ownerUid', 'route', 'deviceId', 'policyVersion', 'binding', 'scheduler', 'preparedAt']);
    const terminal = obj(row.data.terminal), completed = sensorTimestampNanoseconds(terminal.acceptedAt);
    if (completed != null && completed <= cutoff) {safe.terminal = terminal; terminals.set(row.id, terminal);}
    else if (row.data.terminal && completed == null) {reasons.add('terminal_receipt_unknown');}
    manifest.attempts.push({id: row.id, data: safe}); visibleAttempts.set(row.id, safe);
    const policy = text(safe.policyVersion); if (policy) policyVersions.add(policy);
  }
  const visibleReadings = new Map<string, Json>(), collectionTimes: bigint[] = [], receiptTimes: bigint[] = [], legacyTimes: bigint[] = [];
  let count = 0, unverifiedCount = 0, legacyCount = 0, knowledgeReceiptUnknownCount = 0, manualReadingCount = 0, unmatchedAcquisitionCount = 0;
  const validValueCount: Record<Metric, number> = {temperature: 0, humidity: 0}, invalidValueCount: Record<Metric, number> = {temperature: 0, humidity: 0};
  for (const row of uniqueDocuments(input.readings, 'reading', reasons)) {
    const ts = sensorTimestampNanoseconds(row.data.ts), created = sensorTimestampNanoseconds(row.data.createdAt), updated = sensorTimestampNanoseconds(row.updatedAt);
    const acquisitionId = text(row.data.acquisitionId), source = acquisitionId ? visibleAttempts.get(acquisitionId) : null;
    if (created != null && created > cutoff) continue;
    if (input.deviceId && acquisitionId && attemptDevices.has(acquisitionId) && attemptDevices.get(acquisitionId) !== input.deviceId) continue;
    if (input.deviceId && (!source || source.deviceId !== input.deviceId)) {
      if (!source && (ts == null || inWindow(ts, start, end, cutoff))) {reasons.add('device_membership_unknown'); timestampedEvidenceComplete = false;}
      continue;
    }
    if (ts == null) {unknownWindowMembership = true; timestampedEvidenceComplete = false; reasons.add('reading_window_membership_unknown'); continue;}
    const inRange = inWindow(ts, start, end, cutoff);
    // Old merge writers do not provide an immutable first receipt. A current
    // version updateTime proves this projection existed, but cannot restore an
    // earlier overwritten value. Neither ts nor doc ID is a receipt fallback.
    const receipt = acquisitionId ? created : updated;
    if (receipt == null || receipt > cutoff) {
      if (inRange) {knowledgeReceiptUnknownCount++; reasons.add('reading_knowledge_receipt_unknown'); if (!acquisitionId) legacyTimes.push(ts);}
      continue;
    }
    if (ts > receipt) reasons.add('clock_order_inconsistent');
    const safe = fields(row.data, ['ts', 'createdAt', 'temperature', 'humidity', 'battery', 'source', 'acquisitionId', 'acquisitionSchemaVersion', 'acquisitionVerification']);
    manifest.readings.push({id: row.id, data: safe, versionAcceptedAt: acquisitionId ? undefined : instant(receipt)});
    visibleReadings.set(row.id, safe);
    if (!inRange) continue;
    count++; collectionTimes.push(ts); if (inWindow(receipt, start, end, cutoff)) receiptTimes.push(receipt);
    if (!acquisitionId) {legacyCount++; legacyTimes.push(ts);} else if (row.data.acquisitionVerification !== 'verified') unverifiedCount++;
    if (acquisitionId && !source) unmatchedAcquisitionCount++;
    if (source?.route === 'manual_owner' || source?.route === 'manual_operator_all') manualReadingCount++;
    for (const metric of metrics) {if (finite(safe[metric])) validValueCount[metric]++; else invalidValueCount[metric]++;}
  }
  for (const row of uniqueDocuments(input.states, 'state', reasons)) {
    const accepted = sensorTimestampNanoseconds(row.data.acceptedAt);
    if (accepted == null) {reasons.add('state_receipt_unknown'); timestampedEvidenceComplete = false; continue;}
    if (accepted > cutoff) continue;
    manifest.states.push({id: row.id, data: fields(row.data, ['sourcePath', 'sourceVersion', 'sourceUpdatedAt', 'acceptedAt', 'config', 'previousConfig', 'deleted', 'policy', 'eligibility', 'continuity', 'subjectAssociation'])});
    const version = text(obj(row.data.policy).version); if (version) policyVersions.add(version);
  }
  for (const interval of input.verifiedIntervals ?? []) {const accepted = sensorTimestampNanoseconds(interval.acceptedAt); if (accepted != null && accepted <= cutoff) manifest.intervals.push(interval);}
  const expected = expectedOpportunities(input, start, end, cutoff, reasons);
  const attemptedSlots = new Set<string>(), validSlots: Record<Metric | 'both', Set<string>> = {temperature: new Set(), humidity: new Set(), both: new Set()};
  const slotTimes: bigint[] = [], responseTimes: bigint[] = [];
  let confirmedAttemptCount = 0, preparedUnknownCount = 0, confirmedFailureCount = 0, readingSaveUnknownCount = 0, unverifiedScheduledAttemptCount = 0, manualAttemptCount = 0, unknownRouteAttemptCount = 0;
  for (const [id, attempt] of visibleAttempts) {
    const terminal = terminals.get(id), scheduler = obj(attempt.scheduler);
    const scheduled = sensorTimestampNanoseconds(scheduler.scheduledFor), request = sensorTimestampNanoseconds(terminal?.requestStartedAt), prepared = sensorTimestampNanoseconds(attempt.preparedAt);
    const verifiedSlot = attempt.route === 'scheduled' && scheduler.slotIdentityStatus === 'verified' && text(scheduler.logicalSlotId) && inWindow(scheduled, start, end, cutoff);
    const membership = verifiedSlot ? scheduled : request ?? prepared;
    if (!inWindow(membership, start, end, cutoff)) continue;
    const subject = text(obj(attempt.binding).subjectId); if (subject) subjectIds.add(subject);
    if (!terminal) {preparedUnknownCount++; continue;}
    if (terminal.requestAttempted !== true) {preparedUnknownCount++; continue;}
    confirmedAttemptCount++;
    if (attempt.route === 'manual_owner' || attempt.route === 'manual_operator_all') manualAttemptCount++;
    else if (attempt.route !== 'scheduled') unknownRouteAttemptCount++;
    if (terminal.status === 'request_failed') confirmedFailureCount++;
    if (attempt.route === 'scheduled' && !verifiedSlot) unverifiedScheduledAttemptCount++;
    const response = sensorTimestampNanoseconds(terminal.responseReceivedAt); if (inWindow(response, start, end, cutoff)) responseTimes.push(response);
    const terminalAccepted = sensorTimestampNanoseconds(terminal.acceptedAt);
    if (request != null && terminalAccepted != null && request > terminalAccepted || response != null && (request != null && response < request || terminalAccepted != null && response > terminalAccepted) || prepared != null && terminalAccepted != null && prepared > terminalAccepted) reasons.add('clock_order_inconsistent');
    const slotKey = verifiedSlot ? `${attempt.deviceId}|${scheduler.logicalSlotId}` : null;
    const matchedSlot = slotKey && (!expected.keys || expected.keys.has(slotKey));
    if (slotKey && !matchedSlot) reasons.add('verified_slot_outside_expected_set');
    if (matchedSlot) {if (!attemptedSlots.has(slotKey!)) slotTimes.push(scheduled!); attemptedSlots.add(slotKey!);}
    if (terminal.status !== 'reading_saved') continue;
    const path = text(terminal.readingPath), rawId = path?.split('/').pop(), raw = rawId ? visibleReadings.get(rawId) : null;
    const pathMatches = !!path && path === `users/${input.uid ?? path.split('/')[1]}/switchbot_readings/${rawId}`;
    if (!raw || raw.acquisitionId !== id || raw.acquisitionVerification !== 'verified' || !pathMatches || raw.ts !== terminal.readingTs || sensorTimestampNanoseconds(raw.createdAt) !== sensorTimestampNanoseconds(terminal.acceptedAt)) {readingSaveUnknownCount++; reasons.add('confirmed_reading_missing'); continue;}
    const validity = obj(terminal.validity), valid = (metric: Metric) => validity.api === 'valid' && validity[metric] === 'valid' && finite(raw[metric]);
    if (matchedSlot) {for (const metric of metrics) if (valid(metric)) validSlots[metric].add(slotKey!); if (valid('temperature') && valid('humidity')) validSlots.both.add(slotKey!);}
  }
  if (knowledgeReceiptUnknownCount > 0) timestampedEvidenceComplete = false;
  const allComplete = completeness.attempts === 'complete' && completeness.readings === 'complete' && completeness.states === 'complete' && timestampedEvidenceComplete && !unknownWindowMembership;
  const countUnknown = preparedUnknownCount > 0 || readingSaveUnknownCount > 0 || unverifiedScheduledAttemptCount > 0 || unknownRouteAttemptCount > 0 || unverifiedCount > 0 || legacyCount > 0 || unmatchedAcquisitionCount > 0 || [...reasons].some(reason => reason.startsWith('conflicting_') || reason === 'terminal_receipt_unknown' || reason === 'verified_slot_outside_expected_set' || reason === 'clock_order_inconsistent');
  function ratio(numerator: number, denominator: number | null) {
    const status = !allComplete || countUnknown || !expected.loggingVerified || denominator == null ? 'unknown' : denominator === 0 ? 'not_applicable' : 'available';
    return {status, numerator, denominator, value: status === 'available' ? numerator / denominator! : null};
  }
  const sortedManifest = Object.fromEntries(Object.entries(manifest).map(([key, values]) => [key, values.sort((a, b) => JSON.stringify(canonical(a)).localeCompare(JSON.stringify(canonical(b))))]));
  const identifiers = Object.fromEntries(Object.entries(manifest).map(([key, values]) => [key, {count: values.length, ids: values.slice(0, 100).map(value => text(obj(value).id)).filter(Boolean), idsTruncated: values.length > 100}]));
  const readingCountsKnown = completeness.readings === 'complete' && !unknownWindowMembership && timestampedEvidenceComplete &&
    ![...reasons].some(reason => reason === 'device_membership_unknown' || reason.startsWith('conflicting_reading_')) &&
    (!input.deviceId || completeness.attempts === 'complete');
  const attemptCountsKnown = completeness.attempts === 'complete' && ![...reasons].some(reason => reason === 'attempt_receipt_unknown' || reason.startsWith('conflicting_attempt_'));
  const observedReadings = {count, validValueCount, invalidValueCount, unverifiedCount, legacyCount, knowledgeReceiptUnknownCount, unmatchedAcquisitionCount};
  const observedAcquisitions = {confirmedAttemptCount, preparedUnknownCount, confirmedFailureCount, readingSaveUnknownCount, manualAttemptCount, manualReadingCount, unknownRouteAttemptCount};
  const metricTotals = (value: Record<Metric, number>) => ({temperature: readingCountsKnown ? value.temperature : null, humidity: readingCountsKnown ? value.humidity : null});
  const timeDistribution = (times: bigint[], known: boolean) => {
    const observed = distribution(times, start, right);
    return known ? {status: 'available', ...observed, observed} : {status: 'unknown', count: null, firstAt: null, lastAt: null,
      adjacentMaxGapSeconds: null, startGapSeconds: null, endGapSeconds: null, maxGapSeconds: null, observed};
  };
  const result = {
    schemaVersion: 1, qualitySpecVersion: SENSOR_QUALITY_SPEC_VERSION,
    window: {start: instant(start), end: instant(end), timeZone: input.timeZone}, informationAsOf: instant(cutoff), evaluatedThrough: instant(right), deviceId: input.deviceId ?? null,
    policyVersions: [...policyVersions].sort(),
    opportunities: {expectedCount: expected.count, attemptedCount: attemptedSlots.size, validCount: {temperature: validSlots.temperature.size, humidity: validSlots.humidity.size, both: validSlots.both.size}, unverifiedScheduledAttemptCount, expectedUnknownReasons: expected.reasons},
    acquisitions: {confirmedAttemptCount: attemptCountsKnown ? confirmedAttemptCount : null,
      preparedUnknownCount: attemptCountsKnown ? preparedUnknownCount : null, confirmedFailureCount: attemptCountsKnown ? confirmedFailureCount : null,
      readingSaveUnknownCount: attemptCountsKnown ? readingSaveUnknownCount : null, manualAttemptCount: attemptCountsKnown ? manualAttemptCount : null,
      manualReadingCount: readingCountsKnown ? manualReadingCount : null, unknownRouteAttemptCount: attemptCountsKnown ? unknownRouteAttemptCount : null,
      countStatus: attemptCountsKnown ? 'available' : 'unknown', observed: observedAcquisitions},
    readings: {count: readingCountsKnown ? count : null, validValueCount: metricTotals(validValueCount), invalidValueCount: metricTotals(invalidValueCount),
      unverifiedCount, legacyCount, knowledgeReceiptUnknownCount, unmatchedAcquisitionCount,
      countStatus: readingCountsKnown ? 'available' : 'unknown', diagnosticCountsAreLowerBounds: !readingCountsKnown, observed: observedReadings},
    distribution: {collectionClock: timeDistribution(collectionTimes, readingCountsKnown), responseClock: timeDistribution(responseTimes, attemptCountsKnown),
      serverReceipt: timeDistribution(receiptTimes, readingCountsKnown), verifiedSlots: timeDistribution(slotTimes, attemptCountsKnown && readingCountsKnown)},
    legacyTimestampDistribution: {...timeDistribution(legacyTimes, readingCountsKnown && knowledgeReceiptUnknownCount === 0), basis: 'collection_process_clock_without_receipt_proof'},
    ratios: {attempted: ratio(attemptedSlots.size, expected.count), temperature: ratio(validSlots.temperature.size, expected.count), humidity: ratio(validSlots.humidity.size, expected.count), both: ratio(validSlots.both.size, expected.count), successAmongAttempted: ratio(validSlots.both.size, expected.count == null ? null : attemptedSlots.size)},
    completeness: {...completeness, timestampedEvidenceComplete, unknownWindowMembership, loggingContinuityVerified: expected.loggingVerified, reasons: [...reasons].sort(), countsAreLowerBounds: !allComplete || !expected.loggingVerified || countUnknown},
    binding: {subjectIds: [...subjectIds].sort(), status: subjectIds.size ? 'registered_config' : 'unknown', physicalPlacement: 'unknown'},
    freshness: {status: 'unknown', measuredAt: null, providerUpdatedAt: null, measurementCoverage: null, sensorUptime: null},
    sourceManifest: {digest: digest(sortedManifest), identifiers},
    researchUse: 'not_assessed', retention: {evidenceAvailability: 'not_guaranteed_after_retention', retainedFrom: retainedFrom == null ? null : instant(retainedFrom), automaticDeletionConfigured: false},
  };
  return result;
}

export function jstSensorQualityWindow(dateKey: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) throw new Error('Invalid JST date key.');
  const midnight = new Date(`${dateKey}T00:00:00+09:00`);
  if (!Number.isFinite(midnight.getTime()) || new Date(midnight.getTime() + 9 * 3600000).toISOString().slice(0, 10) !== dateKey) throw new Error('Invalid JST date key.');
  return {windowStart: midnight.toISOString(), windowEnd: new Date(midnight.getTime() + 86400000).toISOString(), timeZone: 'Asia/Tokyo' as const};
}

export interface SensorQualityReadDiagnostics {
  readSpecVersion: string;
  selection: 'window' | 'legacy_bounded_scan';
  scannedDocuments: Record<'attempts' | 'readings' | 'states', number>;
  matchedDocuments: Record<'attempts' | 'readings' | 'states', number>;
  queryScope: {utcString: 'complete' | 'partial'; timestamp: 'complete' | 'partial'};
  legacyAudit: {status: 'complete' | 'unknown'; scannedDocuments: number; limit: number};
}
type SensorReadParams = {db: FirebaseFirestore.Firestore; uid: string; pageSize?: number; maxDocuments?: number;
  windowStart?: unknown; windowEnd?: unknown; knowledgeCutoff?: unknown; deviceId?: string;};
/** Query-supported timestamps are selected before the budget is applied. Missing/
 * offset/invalid timestamps cannot be proved absent by orderBy(ts): a small,
 * bounded compatibility inventory either proves the population or declares it
 * unknown. No unbounded legacy fallback is performed. */
export async function readSensorQualityEvidence(params: SensorReadParams) {
  if (!params.uid || params.uid.includes('/')) throw new Error('Invalid owner.');
  const pageSize = Math.min(500, Math.max(1, params.pageSize ?? 100)), cap = Math.min(5000, Math.max(1, params.maxDocuments ?? 3000));
  const hasWindow = params.windowStart !== undefined || params.windowEnd !== undefined || params.knowledgeCutoff !== undefined;
  const start = hasWindow ? requiredInstant(params.windowStart, 'window start') : null;
  const end = hasWindow ? requiredInstant(params.windowEnd, 'window end') : null;
  const cutoff = hasWindow ? requiredInstant(params.knowledgeCutoff, 'knowledge cutoff') : null;
  if (hasWindow && end! <= start!) throw new Error('Invalid quality window.');
  const names = {attempts: 'sensor_acquisition_attempts', readings: 'switchbot_readings', states: 'sensor_polling_state'} as const;
  type Kind = keyof typeof names;
  const result: {attempts: SensorEvidenceDocument[]; readings: SensorEvidenceDocument[]; states: SensorEvidenceDocument[];
    completeness: SensorQualityCompleteness; readLimits: {pageSize: number; maxDocumentsPerCollection: number; maxDocumentsTotal: number};
    cursors: Record<string, string | null>; readDiagnostics: SensorQualityReadDiagnostics} = {
    attempts: [], readings: [], states: [], completeness: {attempts: 'complete', readings: 'complete', states: 'complete', reasons: []},
    readLimits: {pageSize, maxDocumentsPerCollection: cap, maxDocumentsTotal: cap * 3}, cursors: {},
    readDiagnostics: {readSpecVersion: SENSOR_QUALITY_READ_SPEC_VERSION, selection: hasWindow ? 'window' : 'legacy_bounded_scan',
      scannedDocuments: {attempts: 0, readings: 0, states: 0}, matchedDocuments: {attempts: 0, readings: 0, states: 0},
      queryScope: {utcString: 'complete', timestamp: 'complete'}, legacyAudit: {status: 'complete', scannedDocuments: 0, limit: Math.min(64, cap)}},
  };
  const partial = (kind: Kind, reason: string) => {result.completeness[kind] = 'partial'; if (!result.completeness.reasons.includes(reason)) result.completeness.reasons.push(reason);};
  try {
    await params.db.runTransaction(async transaction => {
      result.attempts = []; result.readings = []; result.states = []; result.completeness = {attempts: 'complete', readings: 'complete', states: 'complete', reasons: []}; result.cursors = {};
      result.readDiagnostics.scannedDocuments = {attempts: 0, readings: 0, states: 0};
      result.readDiagnostics.queryScope = {utcString: 'complete', timestamp: 'complete'};
      result.readDiagnostics.legacyAudit = {status: 'complete', scannedDocuments: 0, limit: Math.min(64, cap)};
      const documents: Record<Kind, Map<string, SensorEvidenceDocument>> = {attempts: new Map(), readings: new Map(), states: new Map()};
      const add = (kind: Kind, doc: FirebaseFirestore.DocumentSnapshot) => {if (doc.exists) documents[kind].set(doc.id, {id: doc.id, data: doc.data()!, updatedAt: doc.updateTime});};
      const remaining = (kind: Kind) => cap - result.readDiagnostics.scannedDocuments[kind];
      const scan = async (kind: Kind, initial: FirebaseFirestore.Query, key: string, accept?: (doc: FirebaseFirestore.QueryDocumentSnapshot) => boolean) => {
        let cursor: FirebaseFirestore.QueryDocumentSnapshot | null = null;
        try {
          while (remaining(kind) > 0) {
            const size = Math.min(pageSize, remaining(kind));
            let query = initial.limit(size); if (cursor) query = query.startAfter(cursor);
            const snapshot = await transaction.get(query);
            result.readDiagnostics.scannedDocuments[kind] += snapshot.size;
            for (const doc of snapshot.docs) if (!accept || accept(doc)) add(kind, doc);
            cursor = snapshot.docs[snapshot.docs.length - 1] ?? cursor;
            if (snapshot.size < size) {result.cursors[key] = null; return true;}
          }
          partial(kind, `${kind}_limit_reached`);
        } catch {partial(kind, `${kind}_page_read_failed`);}
        result.cursors[key] = cursor?.id ?? null; return false;
      };
      // Preparation may precede a period-internal request; state can precede the
      // whole period. Preserve these bounded readers instead of dropping context.
      const contextScans = async () => {for (const kind of ['attempts', 'states'] as const) await scan(kind, params.db.collection(`users/${params.uid}/${names[kind]}`).orderBy(admin.firestore.FieldPath.documentId()), kind);};
      const collection = params.db.collection(`users/${params.uid}/${names.readings}`);
      if (!hasWindow) {
        await contextScans();
        await scan('readings', collection.orderBy(admin.firestore.FieldPath.documentId()), 'readings');
      } else {
        const within = (doc: FirebaseFirestore.QueryDocumentSnapshot) => inWindow(sensorTimestampNanoseconds(doc.get('ts')), start!, end!, cutoff!);
        const asStamp = (v: bigint) => {let seconds = v / NANOSECOND, nanos = v % NANOSECOND; if (nanos < 0n) {seconds--; nanos += NANOSECOND;} return new admin.firestore.Timestamp(Number(seconds), Number(nanos));};
        if (cutoff! >= start!) {
          // Second-wide lexical bounds also include UTC strings without millis
          // and with nanoseconds. Exact instant/receipt checks remain in memory.
          const upper = end! < cutoff! + 1n ? end! : cutoff! + 1n;
          const lowerPrefix = new Date(Number((start! / NANOSECOND) * 1000n)).toISOString().slice(0, 19);
          const upperPrefix = new Date(Number(((upper + NANOSECOND - 1n) / NANOSECOND) * 1000n)).toISOString().slice(0, 19);
          const ordered = (query: FirebaseFirestore.Query) => query.orderBy('ts').orderBy(admin.firestore.FieldPath.documentId());
          const stringComplete = await scan('readings', ordered(collection.where('ts', '>=', lowerPrefix).where('ts', '<', upperPrefix)), 'readings_utc_string', within);
          result.readDiagnostics.queryScope.utcString = stringComplete ? 'complete' : 'partial';
          const timestampComplete = await scan('readings', ordered(collection.where('ts', '>=', asStamp(start!)).where('ts', '<', asStamp(end!)).where('ts', '<=', asStamp(cutoff!))), 'readings_timestamp', within);
          result.readDiagnostics.queryScope.timestamp = timestampComplete ? 'complete' : 'partial';
        }
        // A query cannot find a missing ts. Inspect at most64 metadata rows,
        // charged to the same reading budget, and never claim the rest is valid.
        const inventoryLimit = Math.min(64, remaining('readings'));
        try {
          const inventory = inventoryLimit ? await transaction.get(collection.orderBy(admin.firestore.FieldPath.documentId()).select('ts', 'createdAt', 'temperature', 'humidity', 'battery', 'source', 'acquisitionId', 'acquisitionSchemaVersion', 'acquisitionVerification').limit(inventoryLimit)) : null;
          if (inventory) {
            result.readDiagnostics.scannedDocuments.readings += inventory.size;
            result.readDiagnostics.legacyAudit.scannedDocuments = inventory.size;
            for (const doc of inventory.docs) {
              const value = doc.get('ts'), parsed = sensorTimestampNanoseconds(value);
              const knownReceipt = sensorTimestampNanoseconds(doc.get('acquisitionId') ? doc.get('createdAt') : doc.updateTime);
              if (knownReceipt != null && knownReceipt > cutoff!) continue;
              if (parsed == null || inWindow(parsed, start!, end!, cutoff!)) add('readings', doc);
              if (parsed == null) partial('readings', 'reading_timestamp_unqueryable');
            }
          }
          if (!inventory || inventory.size === inventoryLimit) {
            result.readDiagnostics.legacyAudit.status = 'unknown'; partial('readings', 'legacy_timestamp_population_unverified');
          }
        } catch {result.readDiagnostics.legacyAudit.status = 'unknown'; partial('readings', 'legacy_timestamp_audit_failed');}
        // Prioritize the attempt references of period-selected readings. Old
        // global attempt history must not consume their entire lookup budget.
        for (const row of documents.readings.values()) {
          const id = text(row.data.acquisitionId), receipt = sensorTimestampNanoseconds(row.data.createdAt);
          if (!id || id.includes('/') || documents.attempts.has(id) || receipt != null && receipt > cutoff!) continue;
          if (remaining('attempts') <= 0) {partial('attempts', 'attempts_limit_reached'); break;}
          try {result.readDiagnostics.scannedDocuments.attempts++; add('attempts', await transaction.get(params.db.doc(`users/${params.uid}/sensor_acquisition_attempts/${id}`)));}
          catch {partial('attempts', 'referenced_attempt_read_failed');}
        }
        await contextScans();
        // Referenced rows may legitimately fall beyond the day (delayed reply).
        // They support slot verification but are not extra period measurements.
        for (const attempt of documents.attempts.values()) {
          const a = attempt.data, t = obj(a.terminal), scheduler = obj(a.scheduler);
          const prepared = sensorTimestampNanoseconds(a.preparedAt), accepted = sensorTimestampNanoseconds(t.acceptedAt);
          if (prepared == null || prepared > cutoff! || accepted == null || accepted > cutoff! || t.status !== 'reading_saved') continue;
          if (params.deviceId && a.deviceId !== params.deviceId) continue;
          const slot = sensorTimestampNanoseconds(scheduler.scheduledFor);
          const member = a.route === 'scheduled' && scheduler.slotIdentityStatus === 'verified' && inWindow(slot, start!, end!, cutoff!) ? slot : sensorTimestampNanoseconds(t.requestStartedAt) ?? prepared;
          if (!inWindow(member, start!, end!, cutoff!)) continue;
          const path = text(t.readingPath), id = path?.split('/').pop();
          if (!path || !id || path !== `users/${params.uid}/switchbot_readings/${id}` || documents.readings.has(id)) continue;
          if (remaining('readings') <= 0) {partial('readings', 'readings_limit_reached'); break;}
          try {result.readDiagnostics.scannedDocuments.readings++; add('readings', await transaction.get(params.db.doc(path)));}
          catch {partial('readings', 'referenced_reading_read_failed');}
        }
      }
      for (const kind of Object.keys(names) as Kind[]) {result[kind] = [...documents[kind].values()]; result.readDiagnostics.matchedDocuments[kind] = result[kind].length;}
      result.cursors.readings = result.cursors.readings_utc_string ?? result.cursors.readings_timestamp ?? result.cursors.readings ?? null;
    }, {readOnly: true});
  } catch {for (const kind of Object.keys(names) as Kind[]) partial(kind, 'consistent_read_unavailable');}
  return result;
}

/** Immutable sidecar; writes cannot invoke the existing health/report triggers. */
export async function buildAndSaveSensorQuality(params: {
  db: FirebaseFirestore.Firestore; uid: string; windowStart: unknown; windowEnd: unknown; timeZone: 'Asia/Tokyo' | 'UTC'; knowledgeCutoff: unknown;
  deviceId?: string; pageSize?: number; maxDocuments?: number; verifiedIntervals?: VerifiedSensorScheduleInterval[]; evidenceRetainedFrom?: unknown;
  supersedesSnapshotId?: string;
}) {
  const evidence = await readSensorQualityEvidence(params);
  const quality = aggregateSensorQuality({...params, ...evidence});
  if (params.supersedesSnapshotId !== undefined && !/^[a-f0-9]{64}$/.test(params.supersedesSnapshotId)) throw new Error('Invalid previous snapshot identifier.');
  const resultHash = digest({quality, supersedesSnapshotId: params.supersedesSnapshotId ?? null}), snapshotId = resultHash;
  const ref = params.db.doc(`users/${params.uid}/sensor_quality_snapshots/${snapshotId}`);
  const stored = JSON.parse(JSON.stringify(quality)) as Json;
  const persisted = await params.db.runTransaction(async transaction => {
    // Reading the same barrier document as account deletion makes a concurrent
    // deletion conflict with this transaction; late work cannot recreate data.
    const capture = await transaction.get(params.db.doc(`users/${params.uid}/integrations/switchbot`));
    if (!capture.exists || capture.get(SENSOR_CAPTURE_BLOCK_FIELD) === true) throw new SensorCaptureUnavailable();
    if (params.supersedesSnapshotId) {
      const previous = await transaction.get(params.db.doc(`users/${params.uid}/sensor_quality_snapshots/${params.supersedesSnapshotId}`));
      if (!previous.exists) throw new Error('Previous snapshot does not exist.');
    }
    const existing = await transaction.get(ref);
    if (existing.exists) {if (existing.get('resultHash') !== resultHash) throw new Error('Sensor quality snapshot identity conflict.'); return false;}
    transaction.create(ref, {schemaVersion: 2, resultHash, supersedesSnapshotId: params.supersedesSnapshotId ?? null, quality: stored, readDiagnostics: evidence.readDiagnostics, readLimits: evidence.readLimits, cursors: evidence.cursors, generatedAt: admin.firestore.FieldValue.serverTimestamp()});
    return true;
  });
  return {snapshotId, path: ref.path, created: persisted, quality, readDiagnostics: evidence.readDiagnostics, readLimits: evidence.readLimits};
}
