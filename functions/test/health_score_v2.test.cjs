const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildDailyHealthFeatures,
} = require('../lib/health/dailyHealthFeatures');
const {
  buildHealthAssessment,
} = require('../lib/health/healthAssessment');
const {
  evaluateWeightRecords,
} = require('../lib/health/weightAssessment');

function domainAssessment(overrides = {}) {
  return {
    state: 'good',
    score: 100,
    flags: [],
    summary: '安定しています。',
    recommendedActions: [],
    sourceUpdatedAt: null,
    ...overrides,
  };
}

function features(overrides = {}) {
  return {
    dateKey: '2026-09-14',
    environment: {
      sourceKind: 'history',
      sourceDateKey: '2026-09-14',
      avgTemp: 23,
      avgHum: 50,
      tempRatio: 1,
      humRatio: 1,
      dangerMinutes: 0,
      spikesTemp: 0,
      spikesHum: 0,
      sourceEvaluatedAt: null,
      windowDays: 7,
      windowRecordCount: 7,
      highTemperatureDays: 0,
      lowTemperatureDays: 0,
      highHumidityDays: 0,
      lowHumidityDays: 0,
      temperatureTrend: 'stable',
      humidityTrend: 'stable',
    },
    activity: {
      assessmentDateKey: '2026-09-14',
      sourceDateKey: '2026-09-13',
      hasRecord: true,
      distanceMeters: 1000,
      avg7DistanceMeters: 1000,
      deltaPct: 0,
      personalBaseline: baseline(),
      windowDays: 7,
      windowRecordCount: 7,
      recordDate: null,
    },
    body: {},
    condition: {
      recorded: true,
      condition: 'normal',
      concernTags: [],
      observationLevels: {},
      memo: '',
      recordDate: null,
    },
    nutrition: {
      recorded: false,
      concernTags: [],
      memo: '',
      recordDate: null,
    },
    dataQuality: {
      availableDomains: [
        'environment',
        'activity',
        'body',
        'condition',
      ],
      missingDomains: [],
      staleDomains: [],
      completeness: 1,
    },
    schemaVersion: 3,
    generatedAt: new Date('2026-09-14T00:00:00Z'),
    ...overrides,
  };
}

function assess(featureOverrides = {}, bodyOverrides = {}) {
  return buildHealthAssessment({
    features: features(featureOverrides),
    bodyAssessment: domainAssessment(bodyOverrides),
    evaluatedAt: new Date('2026-09-14T00:00:00Z'),
  });
}

function baseline(overrides = {}) {
  return {
    status: 'ready',
    method: 'median_mad_ewma_v1',
    recordCount: 7,
    requiredRecordCount: 7,
    spanDays: 14,
    requiredSpanDays: 14,
    firstDateKey: '2026-08-29',
    lastDateKey: '2026-09-11',
    median: 1000,
    mad: 0,
    ewma: 1000,
    ewmaAlpha: 0.3,
    deviationPct: 0,
    robustZScore: null,
    ...overrides,
  };
}

test('publishes a reference score only with complete fresh evidence', () => {
  const complete = assess();
  assert.equal(complete.overall.score, 100);
  assert.equal(complete.overall.scoreCoverage, 1);
  assert.equal(complete.overall.confidence, 'high');
  assert.deepEqual(complete.overall.primaryFactors, []);

  const partialFeatures = features();
  partialFeatures.activity = {
    ...partialFeatures.activity,
    hasRecord: false,
    distanceMeters: null,
    deltaPct: null,
  };
  const partial = buildHealthAssessment({
    features: partialFeatures,
    bodyAssessment: domainAssessment(),
    evaluatedAt: new Date('2026-09-14T00:00:00Z'),
  });

  assert.equal(partial.overall.score, null);
  assert.equal(partial.overall.observedScore, null);
  assert.equal(partial.overall.scoreCoverage, 0.75);
  assert.deepEqual(partial.overall.scoreRange, {
    minimum: 75,
    maximum: 100,
  });
  assert.equal(partial.overall.confidence, 'medium');
  assert.deepEqual(partial.dataQuality.unscoredDomains, ['activity']);
});

test('preserves a caregiver alert even when most domains are unavailable', () => {
  const sparseFeatures = features();
  sparseFeatures.environment = {
    ...sparseFeatures.environment,
    avgTemp: null,
    avgHum: null,
  };
  sparseFeatures.activity = {
    ...sparseFeatures.activity,
    hasRecord: false,
    distanceMeters: null,
    deltaPct: null,
  };
  sparseFeatures.condition = {
    ...sparseFeatures.condition,
    condition: 'veryConcerned',
    concernTags: ['appetite'],
  };

  const result = buildHealthAssessment({
    features: sparseFeatures,
    bodyAssessment: domainAssessment({
      state: 'insufficientData',
      score: null,
      summary: '体重記録がありません。',
    }),
    evaluatedAt: new Date('2026-09-14T00:00:00Z'),
  });

  assert.equal(result.overall.state, 'alert');
  assert.equal(result.overall.observedState, 'alert');
  assert.equal(result.overall.score, null);
  assert.equal(result.overall.scoreCoverage, 0.15);
  assert.match(result.overall.primaryFactors[0], /^今日の様子:/);
});

test('treats a reported breathing change as a direct alert', () => {
  const result = assess({
    condition: {
      recorded: true,
      condition: 'slightlyConcerned',
      concernTags: ['breathing'],
      observationLevels: {
        breathing: 'changed',
      },
      memo: '',
      recordDate: null,
    },
  });

  assert.equal(result.domains.condition.state, 'alert');
  assert.ok(
    result.domains.condition.flags.includes(
      'conditionBreathingChanged',
    ),
  );
  assert.match(result.domains.condition.summary, /呼吸/);
});

test('keeps a structured mild appetite change at caution', () => {
  const result = assess({
    condition: {
      recorded: true,
      condition: 'slightlyConcerned',
      concernTags: ['appetite'],
      observationLevels: {
        appetite: 'changed',
      },
      memo: '',
      recordDate: null,
    },
  });

  assert.equal(result.domains.condition.state, 'caution');
  assert.match(result.domains.condition.summary, /食欲/);
});

test('activity baseline excludes the target day and requires seven prior records over 14 days', () => {
  const source = {
    environment: {
      sourceKind: 'none',
      sourceDateKey: null,
      status: null,
      level: null,
      headline: null,
      todayAction: null,
      why: null,
      avgTemp: null,
      avgHum: null,
      tempRatio: null,
      humRatio: null,
      dangerMinutes: null,
      spikesTemp: null,
      spikesHum: null,
      sourceDocCount: null,
      version: null,
      evaluatedAt: null,
      windowDays: 7,
      windowRecordCount: 0,
      highTemperatureDays: 0,
      lowTemperatureDays: 0,
      highHumidityDays: 0,
      lowHumidityDays: 0,
      latestDailyTemp: null,
      latestDailyHum: null,
      temperatureTrend: 'unknown',
      humidityTrend: 'unknown',
    },
    activitySourceDateKey: '2026-09-13',
    distanceWindow: [
      distance('2026-08-29', 1000),
      distance('2026-09-01', 1000),
      distance('2026-09-03', 1000),
      distance('2026-09-05', 1000),
      distance('2026-09-07', 1000),
      distance('2026-09-09', 1000),
      distance('2026-09-11', 1000),
      distance('2026-09-13', 100),
    ],
    weightRecords: [],
    dailyCheckin: {
      exists: false,
      dayKey: '2026-09-14',
      condition: null,
      concernTags: [],
      observationLevels: {},
      memo: '',
      date: null,
    },
    nutrition: {
      exists: false,
      dayKey: '2026-09-14',
      foodOfferedGrams: null,
      foodRemainingGrams: null,
      foodConsumedGrams: null,
      memo: '',
      date: null,
    },
  };

  const result = buildDailyHealthFeatures({
    dateKey: '2026-09-14',
    source,
  });

  assert.equal(result.features.activity.avg7DistanceMeters, 1000);
  assert.equal(result.features.activity.deltaPct, -90);
  assert.equal(result.features.activity.windowRecordCount, 7);
  assert.equal(
    result.features.activity.personalBaseline.status,
    'ready',
  );

  source.distanceWindow = source.distanceWindow.slice(1);
  const insufficient = buildDailyHealthFeatures({
    dateKey: '2026-09-14',
    source,
  });
  assert.equal(insufficient.features.activity.avg7DistanceMeters, null);
  assert.equal(insufficient.features.activity.deltaPct, null);
  assert.equal(
    insufficient.features.activity.personalBaseline.status,
    'learning',
  );
});

test('weight uses robust personal deviation after baseline maturity', () => {
  const result = evaluateWeightRecords({
    referenceDateKey: '2026-09-14',
    records: [
      weight('2026-08-20', 99),
      weight('2026-08-24', 100),
      weight('2026-08-28', 101),
      weight('2026-09-01', 99),
      weight('2026-09-05', 100),
      weight('2026-09-09', 101),
      weight('2026-09-12', 100),
      weight('2026-09-14', 95.5),
    ],
  });

  assert.equal(result.features.personalBaseline.status, 'ready');
  assert.equal(result.features.personalBaseline.median, 100);
  assert.equal(result.features.personalBaseline.mad, 1);
  assert.equal(result.assessment.state, 'changed');
  assert.ok(
    result.assessment.flags.includes(
      'weightPersonalBaselineModerate',
    ),
  );
});

function distance(dayKey, distanceMeters) {
  return {
    dayKey,
    exists: true,
    distanceMeters,
    rotations: null,
    wheelDiameterCm: null,
    date: null,
  };
}

function weight(dayKey, weightGrams) {
  return {dayKey, weightGrams, date: null};
}
