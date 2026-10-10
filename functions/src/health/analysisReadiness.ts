import { HealthPersonalBaseline } from './healthTypes';

export type AnalysisMetric = 'body' | 'activity';
export type AnalysisReadinessStatus = 'learning' | 'ready' | 'failed';

export interface AnalysisMetricReadiness {
  metric: AnalysisMetric;
  status: AnalysisReadinessStatus;
  validRecordCount: number;
  requiredRecordCount: number;
  observationSpanDays: number;
  requiredObservationSpanDays: number;
  observationStartDateKey: string | null;
  observationEndDateKey: string | null;
  missingConditions: string[];
  analysisSpecVersion: string;
}

export function readinessFromBaseline(params: {
  metric: AnalysisMetric;
  baseline: HealthPersonalBaseline;
  analysisSpecVersion: string;
}): AnalysisMetricReadiness {
  const baseline = params.baseline;
  const missingConditions: string[] = [];
  if (baseline.recordCount < baseline.requiredRecordCount) {
    missingConditions.push('valid_record_count');
  }
  if (baseline.spanDays < baseline.requiredSpanDays) {
    missingConditions.push('observation_span_days');
  }

  return {
    metric: params.metric,
    status: baseline.status === 'ready' ? 'ready' : 'learning',
    validRecordCount: baseline.recordCount,
    requiredRecordCount: baseline.requiredRecordCount,
    observationSpanDays: baseline.spanDays,
    requiredObservationSpanDays: baseline.requiredSpanDays,
    observationStartDateKey: baseline.firstDateKey,
    observationEndDateKey: baseline.lastDateKey,
    missingConditions,
    analysisSpecVersion: params.analysisSpecVersion,
  };
}
