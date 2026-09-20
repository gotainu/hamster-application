import {
  HealthAssessment,
  HealthAssessmentState,
} from './healthTypes';

type Json = Record<string, unknown>;

export interface HealthScoreDryRunRow {
  dateKey: string;
  previousAssessment: unknown;
  candidateAssessment: HealthAssessment;
}

export interface HealthScoreDryRunDay {
  dateKey: string;
  previousState: string;
  candidateState: HealthAssessmentState;
  previousScore: number | null;
  candidateScore: number | null;
  scoreCoverage: number;
  previousActivityState: string;
  candidateActivityState: HealthAssessmentState;
  unscoredDomains: string[];
  stateChanged: boolean;
  activityDecisionChanged: boolean;
}

export interface HealthScoreDryRunReport {
  inputDays: number;
  referenceScore: {
    previousPublishedDays: number;
    candidatePublishedDays: number;
    candidateHiddenDays: number;
    candidatePublishedRate: number;
  };
  coverage: {
    average: number;
    completeDays: number;
    substantialDays: number;
    partialDays: number;
    sparseDays: number;
  };
  safety: {
    previousAlertDays: number;
    candidateAlertDays: number;
    previousAlertsPreserved: number;
    previousAlertsDowngraded: number;
    previousSafetyRelevantDays: number;
    candidateSafetyRelevantDays: number;
    previousSafetySignalsRetained: number;
    previousSafetySignalsLost: number;
    newCandidateSafetySignals: number;
  };
  activity: {
    comparableDays: number;
    changedDecisions: number;
    becameInsufficientDays: number;
  };
  previousStateCounts: Record<string, number>;
  candidateStateCounts: Record<string, number>;
  stateTransitions: Record<string, number>;
  unscoredDomainCounts: Record<string, number>;
  changedDays: HealthScoreDryRunDay[];
}

export function buildHealthScoreDryRunReport(
  rows: HealthScoreDryRunRow[],
): HealthScoreDryRunReport {
  const days = rows
    .map(toDryRunDay)
    .sort((a, b) => a.dateKey.localeCompare(b.dateKey));

  const previousPublishedDays = days.filter(
    (day) => day.previousScore != null,
  ).length;
  const candidatePublishedDays = days.filter(
    (day) => day.candidateScore != null,
  ).length;
  const previousAlertDays = days.filter(
    (day) => day.previousState === 'alert',
  );
  const previousSafetyDays = days.filter(
    (day) => isSafetyRelevant(day.previousState),
  );
  const candidateSafetyDays = days.filter(
    (day) => isSafetyRelevant(day.candidateState),
  );

  const comparableActivityDays = days.filter(
    (day) =>
      day.previousActivityState !== 'unknown' &&
      day.previousActivityState !== 'insufficientData',
  );

  return {
    inputDays: days.length,
    referenceScore: {
      previousPublishedDays,
      candidatePublishedDays,
      candidateHiddenDays: days.length - candidatePublishedDays,
      candidatePublishedRate: ratio(
        candidatePublishedDays,
        days.length,
      ),
    },
    coverage: {
      average: round(
        days.reduce(
          (sum, day) => sum + day.scoreCoverage,
          0,
        ) / Math.max(1, days.length),
      ),
      completeDays: days.filter(
        (day) => day.scoreCoverage >= 0.999,
      ).length,
      substantialDays: days.filter(
        (day) =>
          day.scoreCoverage >= 0.75 &&
          day.scoreCoverage < 0.999,
      ).length,
      partialDays: days.filter(
        (day) =>
          day.scoreCoverage >= 0.5 &&
          day.scoreCoverage < 0.75,
      ).length,
      sparseDays: days.filter(
        (day) => day.scoreCoverage < 0.5,
      ).length,
    },
    safety: {
      previousAlertDays: previousAlertDays.length,
      candidateAlertDays: days.filter(
        (day) => day.candidateState === 'alert',
      ).length,
      previousAlertsPreserved: previousAlertDays.filter(
        (day) => day.candidateState === 'alert',
      ).length,
      previousAlertsDowngraded: previousAlertDays.filter(
        (day) => day.candidateState !== 'alert',
      ).length,
      previousSafetyRelevantDays: previousSafetyDays.length,
      candidateSafetyRelevantDays: candidateSafetyDays.length,
      previousSafetySignalsRetained: previousSafetyDays.filter(
        (day) => isSafetyRelevant(day.candidateState),
      ).length,
      previousSafetySignalsLost: previousSafetyDays.filter(
        (day) => !isSafetyRelevant(day.candidateState),
      ).length,
      newCandidateSafetySignals: candidateSafetyDays.filter(
        (day) => !isSafetyRelevant(day.previousState),
      ).length,
    },
    activity: {
      comparableDays: comparableActivityDays.length,
      changedDecisions: comparableActivityDays.filter(
        (day) => day.activityDecisionChanged,
      ).length,
      becameInsufficientDays: comparableActivityDays.filter(
        (day) =>
          day.candidateActivityState === 'insufficientData',
      ).length,
    },
    previousStateCounts: countBy(
      days.map((day) => day.previousState),
    ),
    candidateStateCounts: countBy(
      days.map((day) => day.candidateState),
    ),
    stateTransitions: countBy(
      days.map(
        (day) =>
          `${day.previousState}->${day.candidateState}`,
      ),
    ),
    unscoredDomainCounts: countBy(
      days.flatMap((day) => day.unscoredDomains),
    ),
    changedDays: days.filter(
      (day) =>
        day.stateChanged ||
        day.activityDecisionChanged ||
        (day.previousScore != null) !==
          (day.candidateScore != null),
    ),
  };
}

function toDryRunDay(
  row: HealthScoreDryRunRow,
): HealthScoreDryRunDay {
  const previous = asJson(row.previousAssessment);
  const previousOverall = nestedJson(previous, 'overall');
  const previousDomains = nestedJson(previous, 'domains');
  const previousActivity = nestedJson(
    previousDomains,
    'activity',
  );
  const candidate = row.candidateAssessment;

  const previousState =
    asString(previousOverall.observedState) ??
    asString(previousOverall.state) ??
    'unknown';
  const previousScore =
    asNumber(previousOverall.observedScore) ??
    asNumber(previousOverall.score);
  const previousActivityState =
    asString(previousActivity.state) ?? 'unknown';
  const candidateState = candidate.overall.observedState;
  const candidateActivityState =
    candidate.domains.activity.state;

  return {
    dateKey: row.dateKey,
    previousState,
    candidateState,
    previousScore,
    candidateScore: candidate.overall.score,
    scoreCoverage: candidate.overall.scoreCoverage,
    previousActivityState,
    candidateActivityState,
    unscoredDomains: candidate.dataQuality.unscoredDomains,
    stateChanged: previousState !== candidateState,
    activityDecisionChanged:
      previousActivityState !== candidateActivityState,
  };
}

function asJson(value: unknown): Json {
  return value != null &&
      typeof value === 'object' &&
      !Array.isArray(value)
    ? value as Json
    : {};
}

function nestedJson(value: Json, key: string): Json {
  return asJson(value[key]);
}

function asString(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0
    ? value
    : null;
}

function asNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value)
    ? value
    : null;
}

function isSafetyRelevant(state: string): boolean {
  return (
    state === 'changed' ||
    state === 'caution' ||
    state === 'alert'
  );
}

function countBy(values: string[]): Record<string, number> {
  return values.reduce<Record<string, number>>(
    (counts, value) => {
      counts[value] = (counts[value] ?? 0) + 1;
      return counts;
    },
    {},
  );
}

function ratio(numerator: number, denominator: number): number {
  return denominator === 0 ? 0 : round(numerator / denominator);
}

function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}
