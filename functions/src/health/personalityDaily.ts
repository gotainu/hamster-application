import * as admin from 'firebase-admin';
import {createHash} from 'node:crypto';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {addDaysToDateKey, formatDateKey, normalizeDateKey} from './dateKey';
import {fetchHealthSourceData} from './firestoreReaders';
import {buildDailyHealthFeatures} from './dailyHealthFeatures';
import {robustZScore} from './personalBaseline';
import {baselineSnapshot, isReady, metricSnapshot, dateKey, monthsAt, PERSONALITY_SPEC_VERSION} from './personalityReport';
import {buildPopulationWeightContext, normalizeReferenceSpecies, parseReferenceCohort} from './referenceCohorts';
import {isValidationUid} from '../validationIdentity';

type Data = Record<string, any>;
type Metric = 'body' | 'activity';
type Frontiers = Partial<Record<Metric, string>>;
const METRICS: Metric[] = ['body', 'activity'];
export const PERSONALITY_DAILY_QUEUE = 'personality_report_queue';
export const PERSONALITY_DAILY_BATCH_LIMIT = 100;
export const jstReportMorning = (day: string) => new Date(`${normalizeDateKey(day)}T00:00:00.000Z`);

function mergeFrontiers(...values: Frontiers[]): Frontiers {
  const result: Frontiers = {};
  for (const value of values) for (const metric of METRICS) {
    const key = dateKey(value?.[metric]);
    if (key && (!result[metric] || key > result[metric]!)) result[metric] = key;
  }
  return result;
}
function reportFrontiers(report: Data): Frontiers {
  const result: Frontiers = {...(report.latestValidDates ?? {})};
  for (const metric of METRICS) {
    const key = dateKey(report.metrics?.[metric]?.latestDateKey);
    if (key) result[metric] = key;
  }
  return mergeFrontiers(result);
}
function featureFrontiers(features: Data): Frontiers {
  const result: Frontiers = {};
  const body = features.body ?? {};
  const activity = features.activity ?? {};
  if (isReady(baselineSnapshot(body.personalBaseline ?? {})) && Number.isFinite(body.latestWeightGrams) && body.latestWeightGrams > 0) {
    const key = dateKey(body.latestWeightDate); if (key) result.body = key;
  }
  if (isReady(baselineSnapshot(activity.personalBaseline ?? {}))) {
    const currentValid = activity.hasRecord === true && Number.isFinite(activity.distanceMeters) && activity.distanceMeters >= 0;
    const key = dateKey(currentValid ? activity.sourceDateKey : activity.personalBaseline?.lastDateKey);
    if (key) result.activity = key;
  }
  return result;
}
function advanced(current: Frontiers, old: Frontiers): boolean {
  return METRICS.some(metric => current[metric] != null && (old[metric] == null || current[metric]! > old[metric]!));
}
function dueDate(now: Date, frontiers: Frontiers): string {
  const today = formatDateKey(now);
  let day = now < jstReportMorning(today) ? today : addDaysToDateKey(today, 1);
  for (const key of Object.values(frontiers)) {
    const afterObservation = addDaysToDateKey(key, 1);
    if (afterObservation > day) day = afterObservation;
  }
  return day;
}

/** The current Silver trigger queues through this entry point; today's distance
 * trigger uses the queue-only source preview below. Numeric/time-only changes
 * and historical backfill without a newer valid observation day do not enqueue
 * another report. Queue writes are server-only and contain no text. */
export async function enqueueDailyPersonalityReport(params: {
  db: FirebaseFirestore.Firestore; uid: string; sourceDateKey: string; now: Date;
}): Promise<{status: string; dueDateKey?: string}> {
  const today = formatDateKey(params.now);
  if (normalizeDateKey(params.sourceDateKey) !== today) return {status: 'historical_skipped'};
  const silver = (await params.db.collection('users').doc(params.uid).collection('daily_health_features').doc(today).get()).data() ?? {};
  if (silver.dateKey !== today || silver.schemaVersion !== 5) return {status: 'silver_unavailable'};
  return enqueueFeatures({...params, features: silver});
}

// Distance recorded for today is not consumed by the existing health pipeline
// until tomorrow. Its queue-only trigger previews tomorrow using the same
// reader/builder without creating Silver or running health/first side effects.
export async function enqueueDailyPersonalityRecord(params: {
  db: FirebaseFirestore.Firestore; uid: string; recordDateKey: string; now: Date;
}): Promise<{status: string; dueDateKey?: string}> {
  const today = formatDateKey(params.now);
  if (normalizeDateKey(params.recordDateKey) !== today) return {status: 'historical_skipped'};
  const tomorrow = addDaysToDateKey(today, 1);
  const source = await fetchHealthSourceData({db: params.db, uid: params.uid, dateKey: tomorrow});
  const features = buildDailyHealthFeatures({dateKey: tomorrow, source: {...source, weightRecords: source.weightRecords.filter(record => record.dayKey <= today)}, generatedAt: params.now}).features;
  return enqueueFeatures({db: params.db, uid: params.uid, sourceDateKey: today, now: params.now, features});
}

async function enqueueFeatures(params: {
  db: FirebaseFirestore.Firestore; uid: string; sourceDateKey: string; now: Date; features: Data;
}): Promise<{status: string; dueDateKey?: string}> {
  const today = formatDateKey(params.now);
  const user = params.db.collection('users').doc(params.uid);
  const queueRef = params.db.collection(PERSONALITY_DAILY_QUEUE).doc(params.uid);
  const pointerRef = user.collection('report_pointers').doc('personality_daily');
  const legacyPointerRef = user.collection('report_pointers').doc('personality');
  return params.db.runTransaction(async tx => {
    const [dailyPointerDoc, legacyPointerDoc, queueDoc] = await Promise.all([tx.get(pointerRef), tx.get(legacyPointerRef), tx.get(queueRef)]);
    // The first daily report inherits v1's observation watermark; later daily
    // publications use their own pointer and never change the legacy entry.
    const pointerDoc = dailyPointerDoc.exists ? dailyPointerDoc : legacyPointerDoc;
    const silver = params.features;
    const pointer = pointerDoc.data() ?? {};
    const latest = typeof pointer.reportId === 'string' ? (await tx.get(user.collection('personality_reports').doc(pointer.reportId))).data() ?? {} : {};
    const queue = queueDoc.data() ?? {};
    const current = featureFrontiers(silver);
    const known = mergeFrontiers(reportFrontiers(latest), queue.latestValidDates ?? {});
    if (!advanced(current, known)) return {status: 'unchanged'};
    const frontiers = mergeFrontiers(queue.latestValidDates ?? {}, current);
    const due = dueDate(params.now, frontiers);
    // A pending earlier morning is preserved; later data is retained by the
    // publisher and moved to the next cutoff after its first queued run.
    const queuedDay = typeof queue.dueDateKey === 'string' && queue.dueDateKey < due ? queue.dueDateKey : due;
    tx.set(queueRef, {schemaVersion: 1, uid: params.uid, dueDateKey: queuedDay,
      dueAt: admin.firestore.Timestamp.fromDate(jstReportMorning(queuedDay)),
      latestValidDates: frontiers, sourceDateKey: today,
      queuedAt: admin.firestore.Timestamp.fromDate(params.now)});
    return {status: 'queued', dueDateKey: queuedDay};
  });
}

/** Reuse the source reader and exact existing baseline builder. Gold's cutoff
 * snapshot may differ from a stale/current-day Silver, and says so explicitly.
 * Missing Silver is create-only; committed Silver is never overwritten. */
async function cutoffFeatures(params: {db: FirebaseFirestore.Firestore; uid: string; now: Date; day: string; dryRun?: boolean}) {
  const cutoff = addDaysToDateKey(params.day, -1);
  const source = await fetchHealthSourceData({db: params.db, uid: params.uid, dateKey: params.day});
  const silverRef = params.db.collection('users').doc(params.uid).collection('daily_health_features').doc(params.day);
  let silver = await silverRef.get();
  let silverStatus = silver.exists ? 'existing' : 'would_create';
  if (!silver.exists && !params.dryRun) {
    const full = buildDailyHealthFeatures({dateKey: params.day, source, generatedAt: params.now}).features;
    silverStatus = await params.db.runTransaction(async tx => {
      if ((await tx.get(silverRef)).exists) return 'existing';
      tx.create(silverRef, {...full, source: 'health_pipeline_v7', triggerReason: 'personality_daily', updatedAt: admin.firestore.FieldValue.serverTimestamp()});
      return 'created';
    });
    silver = await silverRef.get();
  }
  const filtered = {...source, weightRecords: source.weightRecords.filter(record => record.dayKey <= cutoff)};
  const features = buildDailyHealthFeatures({dateKey: params.day, source: filtered, generatedAt: params.now}).features;
  // A missing D-1 target does not erase the newest valid observation. This
  // supplements Gold's latest point only; the builder's baseline is untouched.
  if (!features.activity.hasRecord || features.activity.distanceMeters == null || features.activity.distanceMeters < 0) {
    const latest = filtered.distanceWindow.filter(record => record.dayKey <= cutoff && record.exists && Number.isFinite(record.distanceMeters) && record.distanceMeters! >= 0).slice(-1)[0];
    if (latest) {
      const baseline = features.activity.personalBaseline;
      features.activity = {...features.activity, hasRecord: true, distanceMeters: latest.distanceMeters, sourceDateKey: latest.dayKey,
        rotations: latest.rotations, wheelDiameterCm: latest.wheelDiameterCm, recordDate: latest.date,
        personalBaseline: {...baseline, deviationPct: baseline.median && baseline.median > 0 ? ((latest.distanceMeters! - baseline.median) / baseline.median) * 100 : null,
          robustZScore: robustZScore({value: latest.distanceMeters!, baseline})}};
    }
  }
  const first = addDaysToDateKey(cutoff, -90);
  const inputs = {
    body: filtered.weightRecords.filter(record => record.dayKey >= first).map(record => [record.dayKey, record.weightGrams]),
    activity: filtered.distanceWindow.filter(record => record.dayKey <= cutoff && record.exists && Number.isFinite(record.distanceMeters) && record.distanceMeters! >= 0).map(record => [record.dayKey, record.distanceMeters]),
  };
  const inputFingerprint = createHash('sha256').update(JSON.stringify(inputs)).digest('hex');
  return {features, silver: silver.data() ?? {}, silverStatus, cutoff, inputFingerprint};
}

export async function publishDailyPersonalityReport(params: {
  db: FirebaseFirestore.Firestore; uid: string; evaluationDateKey: string; now: Date; dryRun?: boolean;
}): Promise<{status: string; reportId?: string; readyMetrics?: Metric[]; silverStatus?: string}> {
  const day = formatDateKey(params.now);
  if (normalizeDateKey(params.evaluationDateKey) !== day) return {status: 'historical_skipped'};
  if (params.now < jstReportMorning(day)) return {status: 'not_due'};
  const queueRef = params.db.collection(PERSONALITY_DAILY_QUEUE).doc(params.uid);
  const initialQueue = await queueRef.get();
  if (!initialQueue.exists || initialQueue.data()?.dueDateKey > day) return {status: 'not_queued'};
  const prepared = await cutoffFeatures({...params, day});
  const user = params.db.collection('users').doc(params.uid);
  const pointerRef = user.collection('report_pointers').doc('personality_daily');
  const legacyPointerRef = user.collection('report_pointers').doc('personality');
  const reportId = `daily_${day}`;
  const reportRef = user.collection('personality_reports').doc(reportId);
  const result = await params.db.runTransaction(async tx => {
    const [queueDoc, dailyPointerDoc, legacyPointerDoc, existingDoc, profileDoc, trialDoc] = await Promise.all([
      tx.get(queueRef), tx.get(pointerRef), tx.get(legacyPointerRef), tx.get(reportRef), tx.get(user.collection('pet_profiles').doc('main_pet')),
      tx.get(user.collection('feature_access').doc('initial_trial_v2')),
    ]);
    const queue = queueDoc.data() ?? {};
    if (!queueDoc.exists || queue.dueDateKey > day) return {status: 'not_queued'};
    const pointer = (dailyPointerDoc.exists ? dailyPointerDoc : legacyPointerDoc).data() ?? {};
    const previousDoc = typeof pointer.reportId === 'string' ? await tx.get(user.collection('personality_reports').doc(pointer.reportId)) : null;
    const previous = previousDoc?.data() ?? {};
    const frontiers = featureFrontiers(prepared.features);
    const baselines = Object.fromEntries(METRICS.map(metric => [metric, baselineSnapshot(prepared.features[metric].personalBaseline)])) as Record<Metric, Data>;
    const ready = METRICS.filter(metric => isReady(baselines[metric]));
    const queueAdvancedDuringRead = !!queueDoc.updateTime && !!initialQueue.updateTime && !queueDoc.updateTime.isEqual(initialQueue.updateTime);
    const remaining = METRICS.some(metric => queue.latestValidDates?.[metric] &&
      (queue.latestValidDates[metric] > prepared.cutoff || (queueAdvancedDuringRead && (!frontiers[metric] || queue.latestValidDates[metric] > frontiers[metric]!))));
    const acknowledge = () => {
      if (params.dryRun) return;
      if (remaining) {
        const due = addDaysToDateKey(day, 1);
        tx.set(queueRef, {...queue, dueDateKey: due, dueAt: admin.firestore.Timestamp.fromDate(jstReportMorning(due))});
      } else tx.delete(queueRef);
    };
    if (typeof pointer.evaluationDateKey === 'string' && pointer.evaluationDateKey > day) {acknowledge(); return {status: 'stale_evaluation'};}
    if (existingDoc.exists) {acknowledge(); return {status: 'existing', reportId, readyMetrics: existingDoc.data()?.readyMetrics ?? []};}
    if (!ready.length) {acknowledge(); return {status: 'learning'};}
    if (!advanced(frontiers, reportFrontiers(previous))) {acknowledge(); return {status: 'no_new_data'};}
    const profile = profileDoc.data() ?? {};
    const speciesRaw = typeof profile.species === 'string' ? profile.species : null;
    const species = normalizeReferenceSpecies(speciesRaw);
    let cohort = null;
    if (ready.includes('body') && species) {
      const cohortRef = params.db.collection('reference_cohorts').doc(`${species}_adult_weight`);
      const reference = (await tx.get(cohortRef)).data() ?? {};
      if (typeof reference.currentReferenceVersion === 'string' && /^[a-zA-Z0-9_-]+$/.test(reference.currentReferenceVersion)) {
        const value = parseReferenceCohort((await tx.get(cohortRef.collection('versions').doc(reference.currentReferenceVersion))).data(), species);
        if (value?.referenceVersion === reference.currentReferenceVersion) cohort = value;
      }
    }
    const metrics: Data = {};
    for (const metric of ready) metrics[metric] = metricSnapshot(metric, prepared.features[metric], baselines[metric]);
    const birthday = dateKey(profile.birthday);
    if (metrics.body) metrics.body.populationComparison = buildPopulationWeightContext({species: speciesRaw, birthDateKey: birthday, assessmentDateKey: day, observationStartDateKey: baselines.body.firstDateKey, weightGrams: baselines.body.median, cohort});
    const generatedAt = admin.firestore.Timestamp.fromDate(params.now);
    const limitations = ['観察記録に基づく特徴の説明です。肥満・健康・病気の診断ではありません。',
      '日別の活動記録から、夜型や深夜に活発かどうかは判断できません。', '平滑化した値だけで、長期的な増減は断定できません。'];
    if (ready.some(metric => baselines[metric].mad === 0)) limitations.push('MADが0でも、すべての記録が同じ値だったことを意味しません。');
    if (metrics.body) limitations.push(...metrics.body.populationComparison.limitations);
    const report = {
      schemaVersion: 1, analysisSpecVersion: PERSONALITY_SPEC_VERSION, reportId, reportKind: 'daily', petId: 'main_pet',
      reportType: ready.length === 2 ? 'both' : ready[0] === 'body' ? 'weight_only' : 'activity_only',
      evaluationDateKey: day, cutoffDateKey: prepared.cutoff, silverDateKey: day, generatedAt, readyMetrics: ready,
      latestValidDates: frontiers, inputFingerprint: prepared.inputFingerprint,
      featureSnapshotSource: 'fresh_bronze_cutoff_rebuild',
      silverSchemaVersion: prepared.features.schemaVersion, silverGeneratedAt: prepared.silver.generatedAt ?? null, silverUpdatedAt: prepared.silver.updatedAt ?? null,
      petSnapshot: {species: speciesRaw, speciesCode: species, birthdayDateKey: birthday, ageMonths: monthsAt(birthday, day), ageAtBaselineStartMonths: monthsAt(birthday, baselines.body.firstDateKey)},
      metrics, readinessSnapshot: baselines, limitations: [...new Set(limitations)], access: {mode: 'read_only', requiresSubscription: false},
    };
    if (params.dryRun) return {status: 'would_create', reportId, readyMetrics: ready};
    tx.create(reportRef, report);
    const trial = trialDoc.data() ?? {};
    const eventId = `personality_report_${reportId}`;
    tx.create(user.collection('analysis_events').doc(eventId), {
      eventName: 'personality_report_generated', eventId, actor: 'server_personality_report', source: 'automatic',
      testOnly: trial.testOnly === true || isValidationUid(params.uid), trialId: typeof trial.trialId === 'string' ? trial.trialId : null,
      policyVersion: typeof trial.policyVersion === 'string' ? trial.policyVersion : null, trialEndsAt: trial.endsAt ?? null,
      petId: 'main_pet', reportId, reportRevision: 1, analysisSpecVersion: PERSONALITY_SPEC_VERSION, readyMetrics: ready, occurredAt: generatedAt,
    });
    tx.set(pointerRef, {reportId, reportKind: 'daily', petId: 'main_pet', readyMetrics: ready,
      publishedReadyMetrics: Array.from(new Set([...(pointer.publishedReadyMetrics ?? pointer.readyMetrics ?? []), ...ready])).filter(metric => METRICS.includes(metric)),
      analysisSpecVersion: PERSONALITY_SPEC_VERSION, evaluationDateKey: day, silverDateKey: day, updatedAt: generatedAt});
    acknowledge();
    return {status: 'created', reportId, readyMetrics: ready};
  });
  return {...result, silverStatus: prepared.silverStatus};
}

/** Bounded queue-only scan, with sequential user mutations. Failed entries stay
 * queued and Cloud Scheduler can retry the idempotent publication. */
export async function processPersonalityDailyQueue(params: {db: FirebaseFirestore.Firestore; now: Date; limit?: number}) {
  const day = formatDateKey(params.now);
  if (params.now < jstReportMorning(day)) return {processed: 0, results: []};
  const limit = Math.min(PERSONALITY_DAILY_BATCH_LIMIT, Math.max(1, Math.floor(params.limit ?? PERSONALITY_DAILY_BATCH_LIMIT)));
  const due = await params.db.collection(PERSONALITY_DAILY_QUEUE)
    .where('dueAt', '<=', admin.firestore.Timestamp.fromDate(params.now)).orderBy('dueAt').limit(limit).get();
  const results: {status: string; reportId?: string}[] = [];
  for (const doc of due.docs) {
    try {
      results.push(await publishDailyPersonalityReport({db: params.db, uid: doc.id, evaluationDateKey: day, now: params.now}));
    } catch (_) {
      // One broken user must not starve the rest of the bounded queue. Retain
      // its work, defer it behind existing due entries and store metadata only.
      await params.db.runTransaction(async tx => {
        const ref = params.db.collection(PERSONALITY_DAILY_QUEUE).doc(doc.id);
        const latest = await tx.get(ref);
        // A concurrent successful publication or new trigger may already have
        // replaced this work. An older failure must not defer that newer queue.
        if (!latest.exists || !latest.updateTime || !doc.updateTime || !latest.updateTime.isEqual(doc.updateTime)) return;
        const queued = latest.data() ?? {};
        const tomorrow = addDaysToDateKey(day, 1);
        const next = typeof queued.dueDateKey === 'string' && queued.dueDateKey > tomorrow ? queued.dueDateKey : tomorrow;
        tx.set(ref, {...queued, dueDateKey: next, dueAt: admin.firestore.Timestamp.fromDate(jstReportMorning(next)),
          attemptCount: (typeof queued.attemptCount === 'number' ? queued.attemptCount : 0) + 1,
          lastAttemptAt: admin.firestore.Timestamp.fromDate(params.now), lastAttemptStatus: 'failed'});
      });
      results.push({status: 'failed'});
    }
  }
  return {processed: results.length, failed: results.filter(result => result.status === 'failed').length, results};
}

export const personalityDailyReports = onSchedule({schedule: '0 9 * * *', timeZone: 'Asia/Tokyo', region: 'asia-northeast1',
  timeoutSeconds: 540, memory: '256MiB', retryCount: 3}, async () => {
  await processPersonalityDailyQueue({db: admin.firestore(), now: new Date()});
});
