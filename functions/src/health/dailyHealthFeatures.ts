import {
  DailyHealthFeatures,
  HealthDomainAssessment,
  HealthSourceData,
} from './healthTypes';
import { normalizeDateKey } from './dateKey';
import { evaluateWeightRecords } from './weightAssessment';

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
  };

  const targetDistance = params.source.distanceWindow.find(
    (record) => record.dayKey === dateKey,
  );

  const distanceTotal = params.source.distanceWindow.reduce(
    (sum, record) =>
      sum + Math.max(0, record.distanceMeters ?? 0),
    0,
  );

  const avg7DistanceMeters =
    params.source.distanceWindow.length > 0
      ? distanceTotal / params.source.distanceWindow.length
      : null;

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

  const activity = {
    hasRecord: targetDistance?.exists ?? false,
    distanceMeters,
    rotations: targetDistance?.rotations ?? null,
    wheelDiameterCm:
      targetDistance?.wheelDiameterCm ?? null,
    avg7DistanceMeters,
    deltaPct,
    windowDays: params.source.distanceWindow.length,
    windowRecordCount:
      params.source.distanceWindow.filter(
        (record) => record.exists,
      ).length,
    recordDate: targetDistance?.date ?? null,
  };

  const condition = {
    recorded: params.source.dailyCheckin.exists,
    condition: params.source.dailyCheckin.condition,
    concernTags: params.source.dailyCheckin.concernTags,
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
    schemaVersion: 1,
    generatedAt: params.generatedAt ?? new Date(),
  };

  return {
    features,
    bodyAssessment: bodyResult.assessment,
  };
}
