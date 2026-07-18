import {
  BodyHealthFeatures,
  HealthDomainAssessment,
  WeightRecordSource,
} from './healthTypes';
import {
  assertDateKey,
  differenceInDateKeyDays,
  isDateKeyWithinWindow,
} from './dateKey';

export interface WeightAssessmentConfig {
  changedRateThreshold: number;
  cautionRateThreshold: number;
  staleAfterDays: number;
  windowDays: number;
}

export interface WeightAssessmentResult {
  features: BodyHealthFeatures;
  assessment: HealthDomainAssessment;
}

export const DEFAULT_WEIGHT_ASSESSMENT_CONFIG:
  WeightAssessmentConfig = {
    changedRateThreshold: 0.05,
    cautionRateThreshold: 0.10,
    staleAfterDays: 14,
    windowDays: 30,
  };

export function evaluateWeightRecords(params: {
  records: WeightRecordSource[];
  referenceDateKey: string;
  config?: Partial<WeightAssessmentConfig>;
}): WeightAssessmentResult {
  const referenceDateKey = assertDateKey(
    params.referenceDateKey,
  );
  const config: WeightAssessmentConfig = {
    ...DEFAULT_WEIGHT_ASSESSMENT_CONFIG,
    ...params.config,
  };

  const records = normalizeWeightRecords(params.records)
    .filter((record) => record.dayKey <= referenceDateKey);

  if (records.length === 0) {
    return {
      features: emptyBodyFeatures(config.windowDays),
      assessment: {
        state: 'insufficientData',
        score: null,
        flags: ['weightMissing'],
        summary: '体重を記録すると変化を確認できます',
        recommendedActions: [
          '毎日の必須記録ではありません。週1回程度を目安に記録してください。',
        ],
        sourceUpdatedAt: null,
      },
    };
  }

  const latest = records[records.length - 1];
  const previous =
    records.length >= 2 ? records[records.length - 2] : null;

  const daysSinceMeasurement = Math.max(
    0,
    differenceInDateKeyDays(
      referenceDateKey,
      latest.dayKey,
    ),
  );

  const previousDifferenceGrams = previous
    ? latest.weightGrams - previous.weightGrams
    : null;

  const previousChangeRate =
    previous && previous.weightGrams > 0
      ? previousDifferenceGrams! / previous.weightGrams
      : null;

  const windowRecords = records.filter((record) =>
    isDateKeyWithinWindow({
      targetDateKey: record.dayKey,
      referenceDateKey,
      windowDays: config.windowDays,
    }),
  );

  const windowFirst =
    windowRecords.length >= 2 ? windowRecords[0] : null;

  const windowChangeRate =
    windowFirst && windowFirst.weightGrams > 0
      ? (latest.weightGrams - windowFirst.weightGrams) /
        windowFirst.weightGrams
      : null;

  const features: BodyHealthFeatures = {
    latestWeightGrams: latest.weightGrams,
    latestWeightDate:
      latest.date ?? dateKeyAsDate(latest.dayKey),
    daysSinceMeasurement,
    previousWeightGrams: previous?.weightGrams ?? null,
    previousDifferenceGrams,
    previousChangeRate,
    windowDays: config.windowDays,
    windowChangeRate,
    windowRecordCount: windowRecords.length,
    totalRecordCount: records.length,
  };

  if (!previous) {
    return {
      features,
      assessment: {
        state: 'insufficientData',
        score: null,
        flags: ['weightComparisonMissing'],
        summary: '最初の体重を記録しました',
        recommendedActions: [
          '次回以降の記録と比較して、個体自身の変化を確認します。',
        ],
        sourceUpdatedAt: features.latestWeightDate,
      },
    };
  }

  if (daysSinceMeasurement >= config.staleAfterDays) {
    return {
      features,
      assessment: {
        state: 'insufficientData',
        score: null,
        flags: ['weightStale'],
        summary: '最新の体重記録から日数が空いています',
        recommendedActions: [
          '現在の傾向を判断するため、次回の測定をおすすめします。',
        ],
        sourceUpdatedAt: features.latestWeightDate,
      },
    };
  }

  const absolutePreviousRate =
    Math.abs(previousChangeRate ?? 0);
  const absoluteWindowRate =
    Math.abs(windowChangeRate ?? 0);
  const maximumRate = Math.max(
    absolutePreviousRate,
    absoluteWindowRate,
  );

  if (maximumRate >= config.cautionRateThreshold) {
    return {
      features,
      assessment: {
        state: 'caution',
        score: 55,
        flags: buildWeightChangeFlags({
          previousChangeRate,
          windowChangeRate,
          level: 'large',
        }),
        summary: '体重に大きめの変化があります',
        recommendedActions: [
          '測定条件をそろえて再確認してください。',
          '食欲・排泄・活動量など、ほかの変化とあわせて確認してください。',
        ],
        sourceUpdatedAt: features.latestWeightDate,
      },
    };
  }

  if (maximumRate >= config.changedRateThreshold) {
    return {
      features,
      assessment: {
        state: 'changed',
        score: 80,
        flags: buildWeightChangeFlags({
          previousChangeRate,
          windowChangeRate,
          level: 'moderate',
        }),
        summary: '体重に変化があります',
        recommendedActions: [
          'すぐに異常と判断せず、同じ条件で次回の記録と比較してください。',
        ],
        sourceUpdatedAt: features.latestWeightDate,
      },
    };
  }

  return {
    features,
    assessment: {
      state: 'stable',
      score: 100,
      flags: [],
      summary: '最近の体重は概ね安定しています',
      recommendedActions: [
        '現在の記録ペースを継続してください。',
      ],
      sourceUpdatedAt: features.latestWeightDate,
    },
  };
}

function normalizeWeightRecords(
  source: WeightRecordSource[],
): WeightRecordSource[] {
  const byDateKey = new Map<string, WeightRecordSource>();

  for (const record of source) {
    if (
      !record ||
      typeof record.dayKey !== 'string' ||
      !Number.isFinite(record.weightGrams) ||
      record.weightGrams <= 0 ||
      record.weightGrams > 1000
    ) {
      continue;
    }

    try {
      const dayKey = assertDateKey(record.dayKey);

      byDateKey.set(dayKey, {
        dayKey,
        weightGrams: record.weightGrams,
        date: record.date ?? null,
      });
    } catch {
      continue;
    }
  }

  return [...byDateKey.values()].sort((a, b) =>
    a.dayKey.localeCompare(b.dayKey),
  );
}

function emptyBodyFeatures(
  windowDays: number,
): BodyHealthFeatures {
  return {
    latestWeightGrams: null,
    latestWeightDate: null,
    daysSinceMeasurement: null,
    previousWeightGrams: null,
    previousDifferenceGrams: null,
    previousChangeRate: null,
    windowDays,
    windowChangeRate: null,
    windowRecordCount: 0,
    totalRecordCount: 0,
  };
}

function dateKeyAsDate(dateKey: string): Date {
  const [year, month, day] = dateKey
    .split('-')
    .map((part) => Number(part));

  return new Date(Date.UTC(year, month - 1, day));
}

function buildWeightChangeFlags(params: {
  previousChangeRate: number | null;
  windowChangeRate: number | null;
  level: 'moderate' | 'large';
}): string[] {
  const flags = new Set<string>();
  const suffix =
    params.level === 'large' ? 'Large' : 'Moderate';

  for (const rate of [
    params.previousChangeRate,
    params.windowChangeRate,
  ]) {
    if (rate == null || rate === 0) continue;

    flags.add(
      rate < 0
        ? `weightDecrease${suffix}`
        : `weightIncrease${suffix}`,
    );
  }

  return [...flags];
}
