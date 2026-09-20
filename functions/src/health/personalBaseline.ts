import {
  differenceInDateKeyDays,
  normalizeDateKey,
} from './dateKey';

export type PersonalBaselineStatus = 'learning' | 'ready';

export interface NumericBaselineObservation {
  dateKey: string;
  value: number;
}

export interface PersonalBaselineConfig {
  minRecords: number;
  minSpanDays: number;
  maxRecords: number;
  ewmaAlpha: number;
}

export interface PersonalBaseline {
  status: PersonalBaselineStatus;
  method: 'median_mad_ewma_v1';
  recordCount: number;
  requiredRecordCount: number;
  spanDays: number;
  requiredSpanDays: number;
  firstDateKey: string | null;
  lastDateKey: string | null;
  median: number | null;
  mad: number | null;
  ewma: number | null;
  ewmaAlpha: number;
}

export const DEFAULT_PERSONAL_BASELINE_CONFIG:
  PersonalBaselineConfig = {
    minRecords: 7,
    minSpanDays: 14,
    maxRecords: 14,
    ewmaAlpha: 0.3,
  };

export function buildPersonalBaseline(params: {
  observations: NumericBaselineObservation[];
  config?: Partial<PersonalBaselineConfig>;
}): PersonalBaseline {
  const config = normalizedConfig(params.config);
  const observations = normalizeObservations(params.observations)
    .slice(-config.maxRecords);
  const firstDateKey = observations[0]?.dateKey ?? null;
  const lastDateKey =
    observations[observations.length - 1]?.dateKey ?? null;
  const spanDays = firstDateKey && lastDateKey
    ? differenceInDateKeyDays(lastDateKey, firstDateKey) + 1
    : 0;
  const values = observations.map((item) => item.value);
  const center = median(values);
  const mad = center == null
    ? null
    : median(values.map((value) => Math.abs(value - center)));
  const ewma = values.length === 0
    ? null
    : values.slice(1).reduce(
        (current, value) =>
          config.ewmaAlpha * value +
          (1 - config.ewmaAlpha) * current,
        values[0],
      );

  return {
    status:
      observations.length >= config.minRecords &&
      spanDays >= config.minSpanDays
        ? 'ready'
        : 'learning',
    method: 'median_mad_ewma_v1',
    recordCount: observations.length,
    requiredRecordCount: config.minRecords,
    spanDays,
    requiredSpanDays: config.minSpanDays,
    firstDateKey,
    lastDateKey,
    median: center,
    mad,
    ewma,
    ewmaAlpha: config.ewmaAlpha,
  };
}

export function robustZScore(params: {
  value: number;
  baseline: PersonalBaseline;
}): number | null {
  if (
    params.baseline.status !== 'ready' ||
    params.baseline.median == null ||
    params.baseline.mad == null ||
    params.baseline.mad <= 0
  ) {
    return null;
  }

  return (
    0.6745 *
    (params.value - params.baseline.median) /
    params.baseline.mad
  );
}

function normalizeObservations(
  source: NumericBaselineObservation[],
): NumericBaselineObservation[] {
  const byDateKey = new Map<string, NumericBaselineObservation>();

  for (const observation of source) {
    if (!Number.isFinite(observation.value) || observation.value < 0) {
      continue;
    }

    try {
      const dateKey = normalizeDateKey(observation.dateKey);
      byDateKey.set(dateKey, {
        dateKey,
        value: observation.value,
      });
    } catch {
      continue;
    }
  }

  return [...byDateKey.values()].sort((a, b) =>
    a.dateKey.localeCompare(b.dateKey),
  );
}

function normalizedConfig(
  overrides?: Partial<PersonalBaselineConfig>,
): PersonalBaselineConfig {
  const config = {
    ...DEFAULT_PERSONAL_BASELINE_CONFIG,
    ...overrides,
  };

  return {
    minRecords: Math.max(2, Math.round(config.minRecords)),
    minSpanDays: Math.max(1, Math.round(config.minSpanDays)),
    maxRecords: Math.max(
      Math.round(config.minRecords),
      Math.round(config.maxRecords),
    ),
    ewmaAlpha: Math.max(0.05, Math.min(1, config.ewmaAlpha)),
  };
}

function median(values: number[]): number | null {
  if (values.length === 0) return null;

  const sorted = values.slice().sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);

  return sorted.length % 2 === 1
    ? sorted[middle]
    : (sorted[middle - 1] + sorted[middle]) / 2;
}
