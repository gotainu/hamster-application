import {createHash} from 'node:crypto';
import {normalizeDateKey} from './dateKey';
import {selectWeightAnalysisObservations} from './weightAssessment';
import type {BodyHealthFeatures, WeightRecordSource} from './healthTypes';
import type {NumericBaselineObservation} from './personalBaseline';
import {buildCheckinInsights, type CheckinInsightEvidence, type CheckinInsights} from './checkinInsights';

export const WEIGHT_INSIGHT_SPEC_VERSION = 'weight_insights_v1';

/** Measurement-only Silver evidence, selected by the existing health baseline
 * selector. No memo, profile text, inferred missing values or scores. */
export interface WeightInsightEvidence {
  schemaVersion: 1;
  calculationSpecVersion: typeof WEIGHT_INSIGHT_SPEC_VERSION;
  evaluationDateKey: string;
  periodWindowDays: number;
  baselineObservations: NumericBaselineObservation[];
  periodObservations: NumericBaselineObservation[];
}

export interface WeightInsight {
  id: string;
  kind: 'weight_observed_range' | 'weight_period_difference';
  metric: 'body';
  evaluationDateKey: string;
  observationStartDateKey: string;
  observationEndDateKey: string;
  records: NumericBaselineObservation[];
  validRecordCount: number;
  unit: 'g';
  evidence: {
    minimumGrams?: number;
    maximumGrams?: number;
    allEqual?: boolean;
    startWeightGrams?: number;
    endWeightGrams?: number;
    differenceGrams?: number;
    absoluteDifferenceGrams?: number;
    startDateKey?: string;
    endDateKey?: string;
    windowDays?: number;
  };
  dataQuality: {
    baselineStatus: 'learning' | 'ready';
    latestDateKey: string;
    daysSinceMeasurement: number;
    missingDaysNotImputed: true;
  };
  interpretationCode: 'weight_all_equal' | 'weight_observed_range' |
    'weight_increased' | 'weight_decreased' | 'weight_unchanged';
  eligible: true;
  priority: number;
  calculationSpecVersion: typeof WEIGHT_INSIGHT_SPEC_VERSION;
  sourceGeneratedAt: Date;
  limitations: string[];
}

interface InsightSetData {
  schemaVersion: 1;
  calculationSpecVersion: typeof WEIGHT_INSIGHT_SPEC_VERSION;
  evaluationDateKey: string;
  generatedAt: Date;
  source: {
    silverDateKey: string;
    silverSchemaVersion: number;
    silverGeneratedAt: Date;
    evidenceHash: string;
  };
  contentHash: string;
  insights: WeightInsight[];
  checkinInsights?: CheckinInsights;
}
export interface CurrentInsightSet extends InsightSetData {kind: 'current';}
export interface ReportInsightSnapshot extends InsightSetData {kind: 'report_snapshot';}
type FeatureSource = {
  dateKey: string;
  schemaVersion: number;
  generatedAt: Date;
  body: BodyHealthFeatures;
  weightInsightEvidence?: WeightInsightEvidence;
  checkinInsightEvidence?: CheckinInsightEvidence;
};

export function buildWeightInsightEvidence(params: {
  records: WeightRecordSource[];
  referenceDateKey: string;
  windowDays?: number;
}): WeightInsightEvidence {
  const selected = selectWeightAnalysisObservations(params);
  return {
    schemaVersion: 1,
    calculationSpecVersion: WEIGHT_INSIGHT_SPEC_VERSION,
    evaluationDateKey: normalizeDateKey(params.referenceDateKey),
    periodWindowDays: params.windowDays ?? 30,
    baselineObservations: selected.baselineObservations,
    periodObservations: selected.periodObservations,
  };
}

function buildWeightCurrentInsightSet(params: {
  features: FeatureSource;
  generatedAt: Date;
}): CurrentInsightSet | null {
  const features = params.features;
  const evidence = features.weightInsightEvidence;
  if (!evidence || evidence.schemaVersion !== 1 ||
      evidence.calculationSpecVersion !== WEIGHT_INSIGHT_SPEC_VERSION ||
      evidence.evaluationDateKey !== features.dateKey || features.schemaVersion !== 5 ||
      !Number.isFinite(features.generatedAt?.getTime()) || !Number.isFinite(params.generatedAt.getTime()) ||
      features.generatedAt.getTime() !== params.generatedAt.getTime()) return null;
  const body = features.body;
  const baseline = body.personalBaseline;
  const last = evidence.periodObservations[evidence.periodObservations.length - 1];
  const fresh = body.daysSinceMeasurement != null && body.daysSinceMeasurement >= 0 && body.daysSinceMeasurement < 14;
  const recordsValid = (observations: NumericBaselineObservation[]) => observations.every((item, i) => {
    try {return normalizeDateKey(item.dateKey) === item.dateKey && item.dateKey <= features.dateKey &&
      Number.isFinite(item.value) && item.value > 0 && item.value <= 1000 &&
      (i === 0 || item.dateKey > observations[i - 1].dateKey);} catch {return false;}
  });
  if (!recordsValid(evidence.baselineObservations) || !recordsValid(evidence.periodObservations)) return null;
  const insights: WeightInsight[] = [];
  const quality = {
    baselineStatus: baseline.status,
    latestDateKey: last?.dateKey ?? evidence.baselineObservations[evidence.baselineObservations.length - 1]?.dateKey ?? features.dateKey,
    daysSinceMeasurement: body.daysSinceMeasurement ?? 0,
    missingDaysNotImputed: true as const,
  };
  const base = (kind: WeightInsight['kind'], records: NumericBaselineObservation[]): Omit<WeightInsight, 'evidence' | 'interpretationCode' | 'priority' | 'limitations'> => ({
    id: kind, kind, metric: 'body' as const, evaluationDateKey: features.dateKey,
    observationStartDateKey: records[0].dateKey,
    observationEndDateKey: records[records.length - 1].dateKey,
    records: records.map(record => ({...record})), validRecordCount: records.length,
    unit: 'g' as const, dataQuality: quality, eligible: true as const,
    calculationSpecVersion: WEIGHT_INSIGHT_SPEC_VERSION,
    sourceGeneratedAt: features.generatedAt,
  });
  const selected = evidence.baselineObservations;
  const matchesBaseline = selected.length === baseline.recordCount &&
    selected[0]?.dateKey === baseline.firstDateKey && selected[selected.length - 1]?.dateKey === baseline.lastDateKey;
  let allEqual = false;
  if (fresh && baseline.status === 'ready' && matchesBaseline && selected.length >= baseline.requiredRecordCount && baseline.spanDays >= baseline.requiredSpanDays) {
    const values = selected.map(item => item.value);
    const minimumGrams = Math.min(...values);
    const maximumGrams = Math.max(...values);
    allEqual = minimumGrams === maximumGrams;
    insights.push({...base('weight_observed_range', selected), evidence: {minimumGrams, maximumGrams, allEqual},
      interpretationCode: allEqual ? 'weight_all_equal' : 'weight_observed_range', priority: 20,
      limitations: ['採用した実測記録の範囲です。健康上の正常範囲ではありません。']});
  }
  const period = evidence.periodObservations;
  if (fresh && period.length >= 2) {
    const first = period[0];
    const last = period[period.length - 1];
    const differenceGrams = last.value - first.value;
    // A flat endpoint comparison adds no discovery to an all-equal range.
    if (!(allEqual && differenceGrams === 0)) insights.push({...base('weight_period_difference', period),
      evidence: {startWeightGrams: first.value, endWeightGrams: last.value, differenceGrams, absoluteDifferenceGrams: Math.abs(differenceGrams),
        startDateKey: first.dateKey, endDateKey: last.dateKey, windowDays: evidence.periodWindowDays},
      interpretationCode: differenceGrams > 0 ? 'weight_increased' : differenceGrams < 0 ? 'weight_decreased' : 'weight_unchanged',
      priority: differenceGrams === 0 ? 30 : 10,
      limitations: ['期間内の最初と最後の実測値の差です。継続的な増減や健康状態は判断できません。']});
  }
  insights.sort((a, b) => a.priority - b.priority || a.id.localeCompare(b.id));
  const source = {silverDateKey: features.dateKey, silverSchemaVersion: features.schemaVersion,
    silverGeneratedAt: features.generatedAt, evidenceHash: hashInsightEvidence(evidence)};
  const contentHash = contentFingerprint({evaluationDateKey: features.dateKey, source, insights});
  return {schemaVersion: 1, kind: 'current', calculationSpecVersion: WEIGHT_INSIGHT_SPEC_VERSION,
    evaluationDateKey: features.dateKey, generatedAt: params.generatedAt, source, contentHash, insights};
}

/** Compatibility envelope: old clients keep the exact weight array/version;
 * condition evidence is typed/versioned separately, never mixed into that array. */
export function buildCurrentInsightSet(params: {
  features: FeatureSource; generatedAt: Date;
}): CurrentInsightSet | null {
  const weighted = buildWeightCurrentInsightSet(params);
  const features = params.features;
  if (features.schemaVersion !== 5 || !Number.isFinite(features.generatedAt?.getTime()) ||
      features.generatedAt.getTime() !== params.generatedAt.getTime()) return weighted;
  const evidence = features.checkinInsightEvidence;
  const checkinInsights = evidence?.evaluationDateKey === features.dateKey ? buildCheckinInsights({evidence, generatedAt: params.generatedAt}) : null;
  if (!checkinInsights) return weighted;
  const source = weighted?.source ?? {silverDateKey:features.dateKey,silverSchemaVersion:features.schemaVersion,
    silverGeneratedAt:features.generatedAt,evidenceHash:checkinInsights.evidenceHash};
  const current: CurrentInsightSet = weighted ?? {schemaVersion:1,kind:'current',calculationSpecVersion:WEIGHT_INSIGHT_SPEC_VERSION,
    evaluationDateKey:features.dateKey,generatedAt:params.generatedAt,source,contentHash:'',insights:[]};
  return {...current,checkinInsights,contentHash:contentFingerprint({evaluationDateKey:features.dateKey,source,insights:current.insights,checkinInsights})};
}

/** Called only while creating a new daily report. Never reads current Gold and
 * never enriches or rewrites an already-issued report. */
export function buildReportInsightSnapshot(params: {
  features: FeatureSource;
  generatedAt: Date;
}): ReportInsightSnapshot | null {
  const current = buildCurrentInsightSet(params);
  return current ? {...current, kind: 'report_snapshot'} : null;
}

export function hashInsightEvidence(evidence: WeightInsightEvidence): string {
  return contentFingerprint(evidence);
}
function contentFingerprint(value: unknown): string {
  const canonical = (item: any): any => item instanceof Date ? item.toISOString() : Array.isArray(item) ? item.map(canonical)
    : item && typeof item === 'object' ? Object.fromEntries(Object.keys(item).sort().map(key => [key, canonical(item[key])])) : item;
  return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
}

/** Read Gold before any writes in the surrounding Silver/health transaction.
 * Same-source-generation retries do not modify the fixed dated document; a late older
 * calculation cannot replace a newer current result. */
export async function persistCurrentInsightSet(params: {
  transaction: FirebaseFirestore.Transaction;
  reference: FirebaseFirestore.DocumentReference;
  snapshot: FirebaseFirestore.DocumentSnapshot;
  current: CurrentInsightSet | null;
}): Promise<'written' | 'unchanged' | 'stale' | 'unavailable'> {
  const current = params.current;
  if (!current) return 'unavailable';
  const previous = params.snapshot.data() ?? {};
  const timestamp = previous.generatedAt;
  const previousAt = timestamp instanceof Date ? timestamp : typeof timestamp?.toDate === 'function' ? timestamp.toDate() : null;
  if (previousAt && previousAt.getTime() > current.generatedAt.getTime()) return 'stale';
  if (previous.contentHash === current.contentHash) return 'unchanged';
  params.transaction.set(params.reference, current);
  return 'written';
}
