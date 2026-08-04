import {
  DailyHealthFeatures,
  HealthAssessment,
  HealthAssessmentConfidence,
  HealthAssessmentState,
  HealthDomainAssessment,
  HealthOverallAssessment,
} from './healthTypes';
import { formatDateKey } from './dateKey';

const TEMP_MIN = 20;
const TEMP_MAX = 26;
const HUM_MIN = 40;
const HUM_MAX = 60;

export function buildHealthAssessment(params: {
  features: DailyHealthFeatures;
  bodyAssessment: HealthDomainAssessment;
  evaluatedAt?: Date;
}): HealthAssessment {
  const evaluatedAt = params.evaluatedAt ?? new Date();
  const isCurrentDate =
    params.features.dateKey === formatDateKey(evaluatedAt);

  const domains = {
    environment: buildEnvironmentAssessment(
      params.features,
      isCurrentDate,
    ),
    activity: buildActivityAssessment(params.features),
    body: params.bodyAssessment,
    condition: buildConditionAssessment(params.features),
    nutrition: buildNutritionAssessment(params.features),
  };

  const overall = buildOverallAssessment({
    domains,
    completeness: params.features.dataQuality.completeness,
    staleDomains: params.features.dataQuality.staleDomains,
  });

  const aiAdvisorContext = buildAiAdvisorContext({
    features: params.features,
    domains,
    overall,
    generatedAt: evaluatedAt,
  });

  return {
    dateKey: params.features.dateKey,
    featureDateKey: params.features.dateKey,
    domains,
    overall,
    dataQuality: {
      completeness: params.features.dataQuality.completeness,
      availableDomains:
        params.features.dataQuality.availableDomains,
      missingDomains:
        params.features.dataQuality.missingDomains,
      staleDomains:
        params.features.dataQuality.staleDomains,
    },
    aiAdvisorContext,
    evaluatorVersion: 4,
    evaluatedAt,
  };
}

function buildEnvironmentAssessment(
  features: DailyHealthFeatures,
  isCurrentDate: boolean,
): HealthDomainAssessment {
  const environment = features.environment;
  const hasData =
    environment.avgTemp != null ||
    environment.avgHum != null;

  if (!hasData) {
    return {
      state: 'insufficientData',
      score: null,
      flags: ['environmentMissing'],
      summary: isCurrentDate
        ? '今日の温湿度評価データがありません。'
        : 'この日の温湿度評価データがないため、環境評価は対象外です。',
      recommendedActions: isCurrentDate
        ? [
            '温湿度データとSwitchBotの連携状態を確認してください。',
          ]
        : [],
      sourceUpdatedAt: environment.sourceEvaluatedAt,
      components: {
        temperature: unavailableComponent(
          '温度データがありません。',
        ),
        humidity: unavailableComponent(
          '湿度データがありません。',
        ),
      },
    };
  }

  const temperature = buildEnvironmentComponent({
    metric: 'temperature',
    averageValue: environment.avgTemp,
    suitabilityRatio: environment.tempRatio,
    minimum: TEMP_MIN,
    maximum: TEMP_MAX,
    softDistance: 2,
    hardDistance: 5,
    spikeCount: environment.spikesTemp ?? 0,
    dangerMinutes: environment.dangerMinutes ?? 0,
    highDays: environment.highTemperatureDays,
    lowDays: environment.lowTemperatureDays,
    trend: environment.temperatureTrend,
  });

  const humidity = buildEnvironmentComponent({
    metric: 'humidity',
    averageValue: environment.avgHum,
    suitabilityRatio: environment.humRatio,
    minimum: HUM_MIN,
    maximum: HUM_MAX,
    softDistance: 5,
    hardDistance: 15,
    spikeCount: environment.spikesHum ?? 0,
    dangerMinutes: 0,
    highDays: environment.highHumidityDays,
    lowDays: environment.lowHumidityDays,
    trend: environment.humidityTrend,
  });

  const availableComponents = [
    temperature,
    humidity,
  ].filter((component) => component.score != null);

  if (availableComponents.length === 0) {
    return {
      state: 'insufficientData',
      score: null,
      flags: ['environmentMissing'],
      summary: '温湿度の評価に必要なデータが不足しています。',
      recommendedActions: [],
      sourceUpdatedAt: environment.sourceEvaluatedAt,
      components: {
        temperature,
        humidity,
      },
    };
  }

  const temperatureScore = temperature.score;
  const humidityScore = humidity.score;

  let weightedAverage: number;
  if (temperatureScore != null && humidityScore != null) {
    weightedAverage =
      temperatureScore * 0.55 +
      humidityScore * 0.45;
  } else {
    weightedAverage =
      temperatureScore ??
      humidityScore ??
      0;
  }

  const weakestScore = Math.min(
    ...availableComponents.map(
      (component) => component.score ?? 100,
    ),
  );

  const score = Math.round(
    weightedAverage * 0.60 +
    weakestScore * 0.40,
  );

  const flags = new Set<string>([
    ...temperature.flags,
    ...humidity.flags,
  ]);

  if ((environment.dangerMinutes ?? 0) > 0) {
    flags.add('dangerMinutesDetected');
  }
  if ((environment.spikesTemp ?? 0) > 0) {
    flags.add('temperatureSpike');
  }
  if ((environment.spikesHum ?? 0) > 0) {
    flags.add('humiditySpike');
  }

  const state = environmentState({
    score,
    temperature,
    humidity,
    dangerMinutes: environment.dangerMinutes ?? 0,
  });

  const primaryMetric: 'temperature' | 'humidity' =
    humidity.score != null &&
    (
      temperature.score == null ||
      humidity.score <= temperature.score
    )
      ? 'humidity'
      : 'temperature';
  const primaryComponent =
    primaryMetric === 'humidity'
      ? humidity
      : temperature;

  const summary = environmentDomainSummary({
    state,
    primaryMetric,
    primaryComponent,
    windowDays: environment.windowDays,
  });

  const recommendedActions = new Set<string>();
  if (environment.todayAction) {
    recommendedActions.add(environment.todayAction);
  }
  if (
    humidity.state === 'caution' ||
    humidity.state === 'alert'
  ) {
    recommendedActions.add(
      '部屋全体の湿度、ケージ周辺の通気、濡れた床材や汚れの有無を順に確認してください。',
    );
  }
  if (
    temperature.state === 'caution' ||
    temperature.state === 'alert'
  ) {
    recommendedActions.add(
      'ケージ周辺の温度と空調の風向きを確認してください。',
    );
  }

  return {
    state,
    score,
    flags: [...flags],
    summary,
    recommendedActions: [...recommendedActions].slice(0, 3),
    sourceUpdatedAt: environment.sourceEvaluatedAt,
    components: {
      temperature,
      humidity,
    },
  };
}

function buildEnvironmentComponent(params: {
  metric: 'temperature' | 'humidity';
  averageValue: number | null;
  suitabilityRatio: number | null;
  minimum: number;
  maximum: number;
  softDistance: number;
  hardDistance: number;
  spikeCount: number;
  dangerMinutes: number;
  highDays: number;
  lowDays: number;
  trend: DailyHealthFeatures['environment']['temperatureTrend'];
}): {
  score: number | null;
  state: HealthAssessmentState;
  summary: string;
  flags: string[];
} {
  const label =
    params.metric === 'temperature' ? '温度' : '湿度';
  const unit =
    params.metric === 'temperature' ? '℃' : '%';

  if (
    params.averageValue == null &&
    params.suitabilityRatio == null
  ) {
    return unavailableComponent(
      `${label}データがありません。`,
    );
  }

  const suitabilityScore =
    params.suitabilityRatio == null
      ? 100
      : clamp01(params.suitabilityRatio) * 100;

  const averageScore =
    params.averageValue == null
      ? 100
      : rangeAverageScore({
          value: params.averageValue,
          minimum: params.minimum,
          maximum: params.maximum,
          softDistance: params.softDistance,
          hardDistance: params.hardDistance,
        });

  const outOfRangeDays =
    params.highDays + params.lowDays;

  let stabilityScore = 100;
  stabilityScore -= Math.min(
    42,
    outOfRangeDays * 6,
  );
  stabilityScore -= Math.min(
    32,
    params.spikeCount * 8,
  );
  stabilityScore -= Math.min(
    55,
    params.dangerMinutes * 1.5,
  );

  if (
    params.trend === 'improving' &&
    outOfRangeDays > 0
  ) {
    stabilityScore += 6;
  } else if (params.trend === 'worsening') {
    stabilityScore -= 8;
  }

  stabilityScore = clampScore(stabilityScore);

  const score = Math.round(
    suitabilityScore * 0.55 +
    averageScore * 0.30 +
    stabilityScore * 0.15,
  );

  const flags: string[] = [];

  if (params.averageValue != null) {
    if (params.averageValue < params.minimum) {
      flags.push(
        params.metric === 'temperature'
          ? 'temperatureLow'
          : 'humidityLow',
      );
    }
    if (params.averageValue > params.maximum) {
      flags.push(
        params.metric === 'temperature'
          ? 'temperatureHigh'
          : 'humidityHigh',
      );
    }
  }

  if (params.highDays >= 2) {
    flags.push(
      params.metric === 'temperature'
        ? 'temperatureHighRecentWindow'
        : 'humidityHighRecentWindow',
    );
  }
  if (params.lowDays >= 2) {
    flags.push(
      params.metric === 'temperature'
        ? 'temperatureLowRecentWindow'
        : 'humidityLowRecentWindow',
    );
  }

  const state = componentState(score, params.dangerMinutes);

  const averageText =
    params.averageValue == null
      ? ''
      : `平均${formatMetricValue(
          params.averageValue,
          params.metric,
        )}${unit}`;

  const ratioText =
    params.suitabilityRatio == null
      ? ''
      : `適正時間${Math.round(
          clamp01(params.suitabilityRatio) * 100,
        )}%`;

  const historyText =
    outOfRangeDays > 0
      ? `直近7日で適正範囲外の日が${outOfRangeDays}日あります。`
      : '直近7日では大きな継続偏りは見られません。';

  const trendText =
    params.trend === 'improving'
      ? '現在は改善傾向です。'
      : params.trend === 'worsening'
        ? '最近は悪化傾向です。'
        : '';

  const summary = [
    [averageText, ratioText]
      .filter((value) => value.length > 0)
      .join('、'),
    historyText,
    trendText,
  ].filter((value) => value.length > 0).join(' ');

  return {
    score,
    state,
    summary,
    flags,
  };
}

function unavailableComponent(
  summary: string,
): {
  score: null;
  state: 'insufficientData';
  summary: string;
  flags: string[];
} {
  return {
    score: null,
    state: 'insufficientData',
    summary,
    flags: [],
  };
}

function rangeAverageScore(params: {
  value: number;
  minimum: number;
  maximum: number;
  softDistance: number;
  hardDistance: number;
}): number {
  const deviation =
    params.value < params.minimum
      ? params.minimum - params.value
      : params.value > params.maximum
        ? params.value - params.maximum
        : 0;

  if (deviation <= 0) return 100;

  if (deviation <= params.softDistance) {
    return clampScore(
      100 -
      (
        deviation /
        params.softDistance
      ) * 30,
    );
  }

  if (deviation <= params.hardDistance) {
    const remaining =
      params.hardDistance -
      params.softDistance;
    const progress =
      (
        deviation -
        params.softDistance
      ) / remaining;

    return clampScore(70 - progress * 50);
  }

  return clampScore(
    20 -
    (
      deviation -
      params.hardDistance
    ) * 4,
  );
}

function componentState(
  score: number,
  dangerMinutes: number,
): HealthAssessmentState {
  if (dangerMinutes >= 30 || score < 50) {
    return 'alert';
  }
  if (score < 90) {
    return 'caution';
  }
  if (score < 95) {
    return 'stable';
  }
  return 'good';
}

function environmentState(params: {
  score: number;
  temperature: {
    state: HealthAssessmentState;
  };
  humidity: {
    state: HealthAssessmentState;
  };
  dangerMinutes: number;
}): HealthAssessmentState {
  if (
    params.dangerMinutes >= 30 ||
    params.temperature.state === 'alert' ||
    params.humidity.state === 'alert'
  ) {
    return 'alert';
  }

  if (
    params.score < 90 ||
    params.temperature.state === 'caution' ||
    params.humidity.state === 'caution'
  ) {
    return 'caution';
  }

  if (
    params.temperature.state === 'good' &&
    params.humidity.state === 'good'
  ) {
    return 'good';
  }

  return 'stable';
}

function environmentDomainSummary(params: {
  state: HealthAssessmentState;
  primaryMetric: 'temperature' | 'humidity';
  primaryComponent: {
    score: number | null;
    summary: string;
    flags: string[];
  };
  windowDays: number;
}): string {
  if (
    params.state === 'good' ||
    params.state === 'stable'
  ) {
    return `過去${params.windowDays}日間の温湿度は概ね安定しています。`;
  }

  if (params.primaryMetric === 'humidity') {
    return `過去${params.windowDays}日間の湿度に注意したい状態です。${params.primaryComponent.summary}`;
  }

  return `過去${params.windowDays}日間の温度に注意したい状態です。${params.primaryComponent.summary}`;
}

function formatMetricValue(
  value: number,
  metric: 'temperature' | 'humidity',
): string {
  return metric === 'temperature'
    ? value.toFixed(1)
    : value.toFixed(1);
}

function clampScore(value: number): number {
  return Math.max(0, Math.min(100, value));
}

function buildActivityAssessment(
  features: DailyHealthFeatures,
): HealthDomainAssessment {
  const activity = features.activity;

  if (!activity.hasRecord) {
    return {
      state: 'insufficientData',
      score: null,
      flags: ['activityMissing'],
      summary: '前日分の走行距離が記録されていません。',
      recommendedActions: [],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  const deltaPct = activity.deltaPct;

  if (deltaPct == null) {
    return {
      state: 'insufficientData',
      score: null,
      flags: ['activityComparisonMissing'],
      summary: '前日分の活動量を記録しました。比較データを蓄積中です。',
      recommendedActions: [],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  if (deltaPct <= -40) {
    return {
      state: 'alert',
      score: 40,
      flags: ['activityLow', 'activityDrop'],
      summary: '前日の活動量が直近7日平均を大きく下回っています。',
      recommendedActions: [
        '食欲・排泄・動きなど、ほかの変化も確認してください。',
      ],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  if (deltaPct <= -15) {
    return {
      state: 'caution',
      score: 70,
      flags: ['activityLow', 'activityDrop'],
      summary: '前日の活動量が直近7日平均より少なめです。',
      recommendedActions: [
        '一時的な変化か、ほかの体調変化がないか確認してください。',
      ],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  if (deltaPct >= 60) {
    return {
      state: 'alert',
      score: 75,
      flags: ['activityHigh'],
      summary: '前日の活動量が直近7日平均を大きく上回っています。',
      recommendedActions: [
        '落ち着きのなさや環境変化がないか確認してください。',
      ],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  if (deltaPct >= 20) {
    return {
      state: 'caution',
      score: 88,
      flags: ['activityHigh'],
      summary: '前日の活動量が直近7日平均より多めです。',
      recommendedActions: [],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  return {
    state: 'good',
    score: 100,
    flags: [],
    summary: '前日の活動量は直近7日平均に対して概ね安定しています。',
    recommendedActions: [],
    sourceUpdatedAt: activity.recordDate,
  };
}

function buildConditionAssessment(
  features: DailyHealthFeatures,
): HealthDomainAssessment {
  const condition = features.condition;

  if (!condition.recorded) {
    return {
      state: 'insufficientData',
      score: null,
      flags: ['conditionMissing'],
      summary: 'この日の様子チェックは未入力です。',
      recommendedActions: [],
      sourceUpdatedAt: condition.recordDate,
    };
  }

  const flags = condition.concernTags.map(
    (tag) => `condition_${tag}`,
  );

  switch (condition.condition) {
    case 'veryConcerned':
      return {
        state: 'alert',
        score: 40,
        flags: ['conditionVeryConcerned', ...flags],
        summary: '飼い主が「かなり心配」と記録しています。',
        recommendedActions: [
          '症状が強い、または緊急性が疑われる場合は動物病院への相談を検討してください。',
        ],
        sourceUpdatedAt: condition.recordDate,
      };
    case 'slightlyConcerned':
      return {
        state: 'caution',
        score: 70,
        flags: ['conditionSlightlyConcerned', ...flags],
        summary: '飼い主が「少し気になる」と記録しています。',
        recommendedActions: [
          '気になる項目をほかの記録とあわせて観察してください。',
        ],
        sourceUpdatedAt: condition.recordDate,
      };
    case 'normal':
      return {
        state: 'good',
        score: 100,
        flags: [],
        summary: '今日の様子は「いつも通り」です。',
        recommendedActions: [],
        sourceUpdatedAt: condition.recordDate,
      };
    default:
      return {
        state: 'unknown',
        score: null,
        flags: ['conditionUnknown'],
        summary: '様子チェックの状態を判定できませんでした。',
        recommendedActions: [],
        sourceUpdatedAt: condition.recordDate,
      };
  }
}

function buildNutritionAssessment(
  features: DailyHealthFeatures,
): HealthDomainAssessment {
  const nutrition = features.nutrition;

  if (!nutrition.recorded) {
    return {
      state: 'insufficientData',
      score: null,
      flags: [],
      summary: '給餌量の記録はまだありません。',
      recommendedActions: [],
      sourceUpdatedAt: nutrition.recordDate,
    };
  }

  return {
    state: 'unknown',
    score: null,
    flags: [],
    summary:
      '給餌量を記録しました。傾向評価は記録の蓄積後に行います。',
    recommendedActions: [],
    sourceUpdatedAt: nutrition.recordDate,
  };
}

function buildOverallAssessment(params: {
  domains: {
    environment: HealthDomainAssessment;
    activity: HealthDomainAssessment;
    body: HealthDomainAssessment;
    condition: HealthDomainAssessment;
    nutrition: HealthDomainAssessment;
  };
  completeness: number;
  staleDomains: string[];
}): HealthOverallAssessment {
  const weightedDomains = [
    {
      key: 'environment',
      label: '環境',
      domain: params.domains.environment,
      weight: 0.35,
    },
    {
      key: 'activity',
      label: '活動量',
      domain: params.domains.activity,
      weight: 0.25,
    },
    {
      key: 'body',
      label: '体重',
      domain: params.domains.body,
      weight: 0.25,
    },
    {
      key: 'condition',
      label: '今日の様子',
      domain: params.domains.condition,
      weight: 0.15,
    },
  ];

  const scored = weightedDomains.filter(
    (item) => item.domain.score != null,
  );

  const scoreWeight = scored.reduce(
    (sum, item) => sum + item.weight,
    0,
  );

  const rawObservedScore = scoreWeight > 0
    ? Math.round(
        scored.reduce(
          (sum, item) =>
            sum + (item.domain.score ?? 0) * item.weight,
          0,
        ) / scoreWeight,
      )
    : null;

  const considered = weightedDomains.filter(
    (item) =>
      item.domain.state !== 'unknown' &&
      item.domain.state !== 'insufficientData',
  );

  const observedState: HealthAssessmentState =
    considered.length === 0
      ? 'insufficientData'
      : considered
          .map((item) => item.domain.state)
          .sort(
            (a, b) =>
              severityRank(b) - severityRank(a),
          )[0];

  const observedScore = applyStateScoreCap(
    rawObservedScore,
    observedState,
  );

  const confidence = resolveConfidence({
    completeness: params.completeness,
    hasStaleDomains: params.staleDomains.length > 0,
  });

  const isSafetyRelevantState =
    observedState === 'alert' ||
    observedState === 'caution' ||
    observedState === 'changed';

  const state: HealthAssessmentState =
    observedState === 'insufficientData'
      ? 'insufficientData'
      : confidence === 'insufficient' &&
          !isSafetyRelevantState
        ? 'insufficientData'
        : observedState;

  const score =
    confidence === 'insufficient'
      ? null
      : observedScore;

  const flags = [
    ...new Set(
      Object.values(params.domains).flatMap(
        (domain) => domain.flags,
      ),
    ),
  ];

  const topDomain = considered
    .slice()
    .sort((a, b) => {
      const severityDelta =
        severityRank(b.domain.state) -
        severityRank(a.domain.state);

      if (severityDelta != 0) return severityDelta;

      return (
        (a.domain.score ?? 101) -
        (b.domain.score ?? 101)
      );
    })[0];

  const baseSummary = topDomain
    ? topDomain.domain.summary
    : '評価に必要なデータが不足しています。';

  const primaryFactor = topDomain
    ? `${topDomain.label}: ${topDomain.domain.summary}`
    : null;

  const summary = buildOverallSummary({
    baseSummary,
    observedState,
    confidence,
  });

  const recommendedActions = [
    ...new Set(
      Object.values(params.domains).flatMap(
        (domain) => domain.recommendedActions,
      ),
    ),
  ].slice(0, 5);

  return {
    state,
    score,
    observedState,
    observedScore,
    confidence,
    isProvisional: confidence !== 'high',
    flags,
    summary,
    recommendedActions,
    primaryFactor,
  };
}

function applyStateScoreCap(
  score: number | null,
  state: HealthAssessmentState,
): number | null {
  if (score == null) return null;

  switch (state) {
    case 'alert':
      return Math.min(score, 69);
    case 'caution':
      return Math.min(score, 89);
    case 'changed':
      return Math.min(score, 94);
    default:
      return score;
  }
}

function buildOverallSummary(params: {
  baseSummary: string;
  observedState: HealthAssessmentState;
  confidence: HealthAssessmentConfidence;
}): string {
  if (params.observedState === 'insufficientData') {
    return '評価に必要なデータが不足しています。';
  }

  if (params.confidence === 'insufficient') {
    if (
      params.observedState === 'alert' ||
      params.observedState === 'caution' ||
      params.observedState === 'changed'
    ) {
      return `データは不足していますが、${params.baseSummary}`;
    }

    return `データが不足しています。取得できた範囲では、${params.baseSummary}`;
  }

  if (
    params.confidence === 'low' ||
    params.confidence === 'medium'
  ) {
    return `取得できた範囲での暫定評価です。${params.baseSummary}`;
  }

  return params.baseSummary;
}

function resolveConfidence(params: {
  completeness: number;
  hasStaleDomains: boolean;
}): HealthAssessmentConfidence {
  const completeness = clamp01(params.completeness);

  let confidence: HealthAssessmentConfidence;
  if (completeness < 0.5) {
    confidence = 'insufficient';
  } else if (completeness < 0.75) {
    confidence = 'low';
  } else if (completeness < 1) {
    confidence = 'medium';
  } else {
    confidence = 'high';
  }

  if (!params.hasStaleDomains) {
    return confidence;
  }

  switch (confidence) {
    case 'high':
      return 'medium';
    case 'medium':
      return 'low';
    case 'low':
    case 'insufficient':
      return confidence;
  }
}

function buildAiAdvisorContext(params: {
  features: DailyHealthFeatures;
  domains: {
    environment: HealthDomainAssessment;
    activity: HealthDomainAssessment;
    body: HealthDomainAssessment;
    condition: HealthDomainAssessment;
    nutrition: HealthDomainAssessment;
  };
  overall: HealthOverallAssessment;
  generatedAt: Date;
}) {
  const status =
    params.overall.confidence === 'insufficient'
      ? 'insufficient_data' as const
      : 'available' as const;

  const priority =
    params.overall.observedState === 'alert'
      ? 'high' as const
      : (
          params.overall.observedState === 'caution' ||
          params.overall.observedState === 'changed'
        )
        ? 'caution' as const
        : 'normal' as const;

  const scoreLines =
    params.overall.confidence === 'insufficient'
      ? [
          `取得できた範囲の状態: ${params.overall.observedState}`,
          `観測スコア: ${params.overall.observedScore ?? '未算出'}`,
        ]
      : [
          `総合状態: ${params.overall.state}`,
          `総合スコア: ${params.overall.score ?? '未算出'}${
            params.overall.isProvisional ? '（暫定）' : ''
          }`,
        ];

  const lines = [
    '【統合コンディション評価】',
    `評価日: ${params.features.dateKey}`,
    ...scoreLines,
    `評価信頼度: ${confidenceLabel(
      params.overall.confidence,
    )}`,
    `暫定評価: ${
      params.overall.isProvisional ? 'はい' : 'いいえ'
    }`,
    `要約: ${params.overall.summary}`,
    `主な要因: ${params.overall.primaryFactor ?? '特定なし'}`,
    '',
    '【環境】',
    params.domains.environment.summary,
    `環境スコア: ${params.domains.environment.score ?? '未算出'}`,
    `温度スコア: ${params.domains.environment.components?.temperature?.score ?? '未算出'}`,
    `湿度スコア: ${params.domains.environment.components?.humidity?.score ?? '未算出'}`,
    '',
    '【活動量】',
    `参照日: ${params.features.activity.sourceDateKey}（前日分）`,
    params.domains.activity.summary,
    '',
    '【体重】',
    params.domains.body.summary,
    '',
    '【今日の様子】',
    params.domains.condition.summary,
    '',
    '【給餌】',
    params.domains.nutrition.summary,
    '',
    '【注意フラグ】',
    params.overall.flags.length > 0
      ? params.overall.flags.join(', ')
      : '特になし',
    '',
    '【データ品質】',
    `充足率: ${Math.round(
      params.features.dataQuality.completeness * 100,
    )}%`,
    `不足: ${
      params.features.dataQuality.missingDomains.join(', ') ||
      'なし'
    }`,
    `鮮度不足: ${
      params.features.dataQuality.staleDomains.join(', ') ||
      'なし'
    }`,
    '',
    '【回答方針】',
    '質問と関係する項目だけを自然に参照してください。',
    'データ不足または暫定評価の場合は、利用可能な範囲での評価であることを明示してください。',
    '体重・活動量・温湿度・主観記録の一つだけで病気や原因を断定しないでください。',
    '体調不良が疑われる場合は、観察、環境調整、受診検討を分けて案内してください。',
  ];

  return {
    status,
    priority,
    summary: params.overall.summary,
    promptText: lines.join('\n'),
    version: 4,
    generatedAt: params.generatedAt,
  };
}

function confidenceLabel(
  confidence: HealthAssessmentConfidence,
): string {
  switch (confidence) {
    case 'insufficient':
      return 'insufficient（データ不足）';
    case 'low':
      return 'low（低）';
    case 'medium':
      return 'medium（中）';
    case 'high':
      return 'high（高）';
  }
}

function severityRank(
  state: HealthAssessmentState,
): number {
  switch (state) {
    case 'alert':
      return 6;
    case 'caution':
      return 5;
    case 'changed':
      return 4;
    case 'stable':
      return 3;
    case 'good':
      return 2;
    case 'unknown':
      return 1;
    case 'insufficientData':
      return 0;
  }
}

function clamp01(value: number): number {
  return Math.max(0, Math.min(1, value));
}

function environmentSummary(
  avgTemp: number | null,
  avgHum: number | null,
): string {
  const parts: string[] = [];

  if (avgTemp != null) {
    parts.push(`平均温度${avgTemp.toFixed(1)}℃`);
  }
  if (avgHum != null) {
    parts.push(`平均湿度${Math.round(avgHum)}%`);
  }

  return parts.length > 0
    ? `${parts.join('、')}です。`
    : '環境データを評価しました。';
}
