import {
  DailyHealthFeatures,
  HealthDomainAssessment,
  HealthSourceData,
} from './healthTypes';
import { normalizeDateKey } from './dateKey';
import { evaluateWeightRecords } from './weightAssessment';
import {
  buildPersonalBaseline,
  robustZScore,
} from './personalBaseline';

export interface DailyHealthFeaturesBuildResult {
  features: DailyHealthFeatures;
  bodyAssessment: HealthDomainAssessment;
}

export function buildDailyHealthFeatures(params: {
  dateKey: string;
  source: HealthSourceData;
  generatedAt?: Date;
}): DailyHealthFeaturesBuildResult {
  const dateKey = normalizeDateKey(params.dateKey);
  const bodyResult = evaluateWeightRecords({
    records: params.source.weightRecords,
    referenceDateKey: dateKey,
  });

  const environment = {
    sourceKind: params.source.environment.sourceKind,
    sourceDateKey: params.source.environment.sourceDateKey,
    status: params.source.environment.status,
    level: params.source.environment.level,
    headline: params.source.environment.headline,
    todayAction: params.source.environment.todayAction,
    why: params.source.environment.why,
    avgTemp: params.source.environment.avgTemp,
    avgHum: params.source.environment.avgHum,
    tempRatio: params.source.environment.tempRatio,
    humRatio: params.source.environment.humRatio,
    dangerMinutes: params.source.environment.dangerMinutes,
    spikesTemp: params.source.environment.spikesTemp,
    spikesHum: params.source.environment.spikesHum,
    sourceDocCount: params.source.environment.sourceDocCount,
    assessmentVersion: params.source.environment.version,
    sourceEvaluatedAt: params.source.environment.evaluatedAt,
    windowDays: params.source.environment.windowDays,
    windowRecordCount:
      params.source.environment.windowRecordCount,
    highTemperatureDays:
      params.source.environment.highTemperatureDays,
    lowTemperatureDays:
      params.source.environment.lowTemperatureDays,
    highHumidityDays:
      params.source.environment.highHumidityDays,
    lowHumidityDays:
      params.source.environment.lowHumidityDays,
    latestDailyTemp:
      params.source.environment.latestDailyTemp,
    latestDailyHum:
      params.source.environment.latestDailyHum,
    temperatureTrend:
      params.source.environment.temperatureTrend,
    humidityTrend:
      params.source.environment.humidityTrend,
  };

  const activitySourceDateKey =
    params.source.activitySourceDateKey;
  const targetDistance = params.source.distanceWindow.find(
    (record) =>
      record.dayKey === activitySourceDateKey,
  );
  const comparisonWindow = params.source.distanceWindow.filter(
    (record) =>
      record.dayKey < activitySourceDateKey &&
      record.exists &&
      record.distanceMeters != null &&
      record.distanceMeters >= 0,
  );
  const baseline = buildPersonalBaseline({
    observations: comparisonWindow.map((record) => ({
      dateKey: record.dayKey,
      value: record.distanceMeters ?? 0,
    })),
  });
  const windowStartDateKey =
    baseline.firstDateKey ?? activitySourceDateKey;
  const windowEndDateKey =
    baseline.lastDateKey ?? activitySourceDateKey;

  // Kept as a compatibility alias for older clients. In schema v4 this is
  // the robust personal-baseline median, not a target-inclusive mean.
  const avg7DistanceMeters =
    baseline.status === 'ready' ? baseline.median : null;

  const distanceMeters =
    targetDistance?.distanceMeters ?? null;

  const deltaPct =
    targetDistance?.exists &&
    distanceMeters != null &&
    avg7DistanceMeters != null &&
    avg7DistanceMeters > 0
      ? (
          (distanceMeters - avg7DistanceMeters) /
          avg7DistanceMeters
        ) * 100
      : null;

  const activityRobustZScore =
    targetDistance?.exists && distanceMeters != null
      ? robustZScore({value: distanceMeters, baseline})
      : null;

  const activity = {
    assessmentDateKey: dateKey,
    sourceDateKey: activitySourceDateKey,
    lagDays: 1,
    windowStartDateKey,
    windowEndDateKey,
    hasRecord: targetDistance?.exists ?? false,
    distanceMeters,
    rotations: targetDistance?.rotations ?? null,
    wheelDiameterCm:
      targetDistance?.wheelDiameterCm ?? null,
    avg7DistanceMeters,
    deltaPct,
    personalBaseline: {
      ...baseline,
      deviationPct: deltaPct,
      robustZScore: activityRobustZScore,
    },
    windowDays: 90,
    windowRecordCount: baseline.recordCount,
    recordDate: targetDistance?.date ?? null,
  };

  const condition = {
    recorded: params.source.dailyCheckin.exists,
    condition: params.source.dailyCheckin.condition,
    concernTags: params.source.dailyCheckin.concernTags,
    observationLevels:
      params.source.dailyCheckin.observationLevels,
    memo: params.source.dailyCheckin.memo,
    recordDate: params.source.dailyCheckin.date,
  };

  const nutrition = {
    recorded: params.source.nutrition.exists,
    foodOfferedGrams:
      params.source.nutrition.foodOfferedGrams,
    foodRemainingGrams:
      params.source.nutrition.foodRemainingGrams,
    foodConsumedGrams:
      params.source.nutrition.foodConsumedGrams,
    memo: params.source.nutrition.memo,
    recordDate: params.source.nutrition.date,
  };

  const activeDomains = [
    'environment',
    'activity',
    'body',
    'condition',
  ];

  const availability = new Map<string, boolean>([
    [
      'environment',
      environment.avgTemp != null ||
      environment.avgHum != null,
    ],
    ['activity', activity.hasRecord],
    ['body', bodyResult.features.latestWeightGrams != null],
    ['condition', condition.recorded],
  ]);

  const availableDomains = activeDomains.filter(
    (domain) => availability.get(domain) === true,
  );
  const missingDomains = activeDomains.filter(
    (domain) => availability.get(domain) !== true,
  );
  const staleDomains: string[] = [];

  if (
    bodyResult.features.daysSinceMeasurement != null &&
    bodyResult.features.daysSinceMeasurement >= 14
  ) {
    staleDomains.push('body');
  }

  const completeness =
    activeDomains.length === 0
      ? 0
      : availableDomains.length / activeDomains.length;

  const features: DailyHealthFeatures = {
    dateKey,
    environment,
    activity,
    body: bodyResult.features,
    condition,
    nutrition,
    dataQuality: {
      availableDomains,
      missingDomains,
      staleDomains,
      completeness,
    },
    schemaVersion: 5,
    generatedAt: params.generatedAt ?? new Date(),
  };

  return {
    features,
    bodyAssessment: bodyResult.assessment,
  };
}
