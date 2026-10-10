import * as admin from 'firebase-admin';
import type {DailyHealthFeatures} from './healthTypes';
import {formatDateKey, normalizeDateKey} from './dateKey';
import {isValidationUid} from '../validationIdentity';
import {buildPopulationWeightContext, normalizeReferenceSpecies, parseReferenceCohort} from './referenceCohorts';

export const PERSONALITY_SPEC_VERSION = 'personality_v1';
type Data = Record<string, any>;
type Metric = 'body' | 'activity';
const METRICS: Metric[] = ['body', 'activity'];
const DIAGNOSIS_LIMIT = '観察記録に基づく特徴の説明です。肥満・健康・病気の診断ではありません。';
const TIMING_LIMIT = '日別の活動記録から、夜型や深夜に活発かどうかは判断できません。';
const TREND_LIMIT = '平滑化した値だけで、長期的な増減は断定できません。';
function numeric(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}
export function dateKey(value: unknown): string | null {
  try {
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) return normalizeDateKey(value);
    const date = value instanceof Date ? value : value && typeof (value as Data).toDate === 'function' ? (value as Data).toDate() : typeof value === 'string' ? new Date(value) : null;
    return date instanceof Date && Number.isFinite(date.getTime()) ? formatDateKey(date) : null;
  } catch (_) {return null;}
}
export function monthsAt(birthday: string | null, at: string | null): number | null {
  if (!birthday || !at || at < birthday) return null;
  const [by,bm,bd] = birthday.split('-').map(Number);
  const [y,m,d] = at.split('-').map(Number);
  return (y-by)*12+m-bm-(d<bd?1:0);
}
export function baselineSnapshot(data: Data): Data {
  return {
    status: data.status === 'ready' ? 'ready' : 'learning',
    method: typeof data.method === 'string' ? data.method : 'median_mad_ewma_v1',
    median: numeric(data.median), mad: numeric(data.mad), ewma: numeric(data.ewma),
    ewmaAlpha: numeric(data.ewmaAlpha), recordCount: numeric(data.recordCount) ?? 0,
    requiredRecordCount: numeric(data.requiredRecordCount) ?? 7,
    spanDays: numeric(data.spanDays) ?? 0, requiredSpanDays: numeric(data.requiredSpanDays) ?? 14,
    firstDateKey: dateKey(data.firstDateKey), lastDateKey: dateKey(data.lastDateKey),
    deviationPct: numeric(data.deviationPct), robustZScore: numeric(data.robustZScore),
  };
}
export function isReady(baseline: Data): boolean {
  return baseline.status === 'ready' && baseline.recordCount >= Math.max(7,baseline.requiredRecordCount) && baseline.spanDays >= Math.max(14,baseline.requiredSpanDays) && baseline.median != null && baseline.median >= 0 && baseline.firstDateKey != null && baseline.lastDateKey != null;
}
function amount(value: number, unit: string): string {
  return `${Number(value.toFixed(1))}${unit}`;
}
export function metricSnapshot(metric: Metric, feature: Data, baseline: Data): Data {
  const unit = metric === 'body' ? 'g' : 'm';
  const latest = numeric(metric === 'body' ? feature.latestWeightGrams : feature.distanceMeters);
  const interpretations: Data[] = [{
    code: metric === 'body' ? 'individual_weight' : 'individual_activity',
    text: metric === 'body'
      ? `この子の普段の体重は、観察記録では約${amount(baseline.median,unit)}です。`
      : `この子の普段の1日の走行距離は、観察記録では約${amount(baseline.median,unit)}です。`,
  }];
  const absolute = latest == null ? null : latest - baseline.median;
  if (absolute != null) interpretations.push({code: absolute === 0 ? 'latest_matches_baseline' : absolute > 0 ? 'latest_above_baseline' : 'latest_below_baseline', text: absolute === 0 ? '最近の記録は、この子の普段の基準と同じ値でした。' : `最近の記録は、普段の基準より${amount(Math.abs(absolute),unit)}${absolute>0?'多い':'少ない'}値でした。`});
  interpretations.push({code:'observation_window',text:`${baseline.firstDateKey}から${baseline.lastDateKey}まで、${baseline.spanDays}日間に記録した${baseline.recordCount}日分をもとにしています。`});
  if (metric === 'activity') interpretations.push({code:'no_activity_cohort',text:'同種の走行距離に比較できる研究統計がないため、この子自身の記録と比べています。'});
  return {unit,baseline,latestValue:latest,latestDateKey:dateKey(metric==='body'?feature.latestWeightDate:feature.sourceDateKey),difference:{absolute,percent:baseline.deviationPct},interpretations,populationComparison:null};
}

/** Read only committed current-day Silver in the transaction. Historical
 * readiness oscillations and event payloads are deliberately not used. A dry-run
 * may preview freshly rebuilt Silver without persisting it. */
export async function syncPersonalityReport(params: {
  db: FirebaseFirestore.Firestore; uid: string; evaluationDateKey: string;
  now: Date; dryRun?: boolean; previewFeatures?: DailyHealthFeatures;
}): Promise<{status: string; reportId?: string; readyMetrics?: Metric[]}> {
  if (params.previewFeatures && !params.dryRun) throw new Error('Preview features require a read-only dry-run');
  const today = formatDateKey(params.now);
  if (normalizeDateKey(params.evaluationDateKey) !== today) return {status:'historical_skipped'};
  const user = params.db.collection('users').doc(params.uid);
  const featureRef = user.collection('daily_health_features').doc(today);
  const profileRef = user.collection('pet_profiles').doc('main_pet');
  const pointerRef = user.collection('report_pointers').doc('personality');
  const trialRef = user.collection('feature_access').doc('initial_trial_v2');
  return params.db.runTransaction(async (tx) => {
    const [featureDoc, profileDoc, pointerDoc, trialDoc] = await Promise.all([tx.get(featureRef),tx.get(profileRef),tx.get(pointerRef),tx.get(trialRef)]);
    const features: Data = featureDoc.exists ? featureDoc.data() ?? {} : params.dryRun ? params.previewFeatures ?? {} : {};
    if (features.dateKey !== today || features.schemaVersion !== 5) return {status:'current_silver_unavailable'};
    const baselines = Object.fromEntries(METRICS.map(metric=>[metric,baselineSnapshot(features[metric]?.personalBaseline ?? {})])) as Record<Metric,Data>;
    const ready = METRICS.filter(metric=>isReady(baselines[metric]));
    if (!ready.length) return {status:'learning'};
    const pointer = pointerDoc.data() ?? {};
    // This v1-only pointer is independent from personality_daily publications.
    if (typeof pointer.evaluationDateKey === 'string' && pointer.evaluationDateKey > today) return {status:'stale_evaluation'};
    const previouslyPublished = (Array.isArray(pointer.publishedReadyMetrics) ? pointer.publishedReadyMetrics : Array.isArray(pointer.readyMetrics) ? pointer.readyMetrics : []).filter((m: unknown)=>METRICS.includes(m as Metric)) as Metric[];
    // Publication is monotonic: regressions, regain and daily updates cannot
    // downgrade the latest pointer or repeat an already published ready set.
    if (previouslyPublished.some(metric=>!ready.includes(metric)) || ready.every(metric=>previouslyPublished.includes(metric))) return {status:'unchanged',reportId:pointer.reportId,readyMetrics:ready};
    const reportId = `${PERSONALITY_SPEC_VERSION}_${ready.join('_')}`;
    const reportRef = user.collection('personality_reports').doc(reportId);
    const existing = await tx.get(reportRef);
    const existingReport = existing.data() ?? {};
    if (existing.exists && (existingReport.schemaVersion !== 1 || existingReport.analysisSpecVersion !== PERSONALITY_SPEC_VERSION || existingReport.reportId !== reportId || existingReport.petId !== 'main_pet' || JSON.stringify(existingReport.readyMetrics) !== JSON.stringify(ready) || !dateKey(existingReport.evaluationDateKey) || !dateKey(existingReport.silverDateKey))) return {status:'existing_report_conflict'};
    const profile = profileDoc.data() ?? {};
    const speciesRaw = typeof profile.species === 'string' ? profile.species : null;
    const species = normalizeReferenceSpecies(speciesRaw);
    let cohort = null;
    if (ready.includes('body') && species) {
      const cohortRef = params.db.collection('reference_cohorts').doc(`${species}_adult_weight`);
      const cohortPointer = (await tx.get(cohortRef)).data() ?? {};
      if (typeof cohortPointer.currentReferenceVersion === 'string' && /^[a-zA-Z0-9_-]+$/.test(cohortPointer.currentReferenceVersion)) {
        const cohortDoc = await tx.get(cohortRef.collection('versions').doc(cohortPointer.currentReferenceVersion));
        const parsed = parseReferenceCohort(cohortDoc.data(),species);
        if (parsed?.referenceVersion === cohortPointer.currentReferenceVersion) cohort = parsed;
      }
    }
    const metrics: Data = {};
    for (const metric of ready) metrics[metric] = metricSnapshot(metric,features[metric] ?? {},baselines[metric]);
    const birthday = dateKey(profile.birthday);
    if (metrics.body) metrics.body.populationComparison = buildPopulationWeightContext({species:speciesRaw,birthDateKey:birthday,assessmentDateKey:today,observationStartDateKey:baselines.body.firstDateKey,weightGrams:baselines.body.median,cohort});
    const generatedAt = admin.firestore.Timestamp.fromDate(params.now);
    const limitations = [DIAGNOSIS_LIMIT,TREND_LIMIT,TIMING_LIMIT];
    if (ready.some(metric=>baselines[metric].mad === 0)) limitations.push('MADが0でも、すべての記録が同じ値だったことを意味しません。');
    if (metrics.body) limitations.push(...metrics.body.populationComparison.limitations);
    const report = {
      schemaVersion:1, analysisSpecVersion:PERSONALITY_SPEC_VERSION, reportId,petId:'main_pet',
      reportType:ready.length===2?'both':ready[0]==='body'?'weight_only':'activity_only',
      evaluationDateKey:today,silverDateKey:today,generatedAt,readyMetrics:ready,
      silverSchemaVersion:features.schemaVersion,silverGeneratedAt:features.generatedAt ?? null,
      silverUpdatedAt:features.updatedAt ?? null,
      petSnapshot:{species:speciesRaw,speciesCode:species,birthdayDateKey:birthday,ageMonths:monthsAt(birthday,today),ageAtBaselineStartMonths:monthsAt(birthday,baselines.body.firstDateKey)},
      metrics,readinessSnapshot:baselines,limitations:[...new Set(limitations)],
      access:{mode:'read_only',requiresSubscription:false},
    };
    if (params.dryRun) return {status:existing.exists?'would_reuse':'would_create',reportId,readyMetrics:ready};
    if (!existing.exists) {
      tx.create(reportRef,report);
      const trial = trialDoc.data() ?? {};
      const eventId = `personality_report_${reportId}`;
      // A3 joins real generated report IDs. Only join metadata is sent to the
      // existing event stream; measurements/profile text remain in the report.
      tx.create(user.collection('analysis_events').doc(eventId),{
        eventName:'personality_report_generated',eventId,
        actor:'server_personality_report',source:'automatic',
        testOnly:trial.testOnly === true || isValidationUid(params.uid),
        trialId:typeof trial.trialId === 'string'?trial.trialId:null,
        policyVersion:typeof trial.policyVersion === 'string'?trial.policyVersion:null,
        trialEndsAt:trial.endsAt ?? null,
        petId:'main_pet',reportId,reportRevision:1,
        analysisSpecVersion:PERSONALITY_SPEC_VERSION,readyMetrics:ready,
        occurredAt:generatedAt,
      });
    }
    tx.set(pointerRef,{reportId,petId:'main_pet',readyMetrics:ready,publishedReadyMetrics:ready,analysisSpecVersion:PERSONALITY_SPEC_VERSION,evaluationDateKey:existing.exists?existingReport.evaluationDateKey:today,silverDateKey:existing.exists?existingReport.silverDateKey:today,updatedAt:generatedAt});
    return {status:existing.exists?'reused':'created',reportId,readyMetrics:ready};
  });
}
