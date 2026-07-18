import {
  DailyHealthFeatures,
  HealthAssessment,
  HealthAssessmentState,
  HealthDomainAssessment,
  HealthOverallAssessment,
} from './healthTypes';

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

  const domains = {
    environment: buildEnvironmentAssessment(params.features),
    activity: buildActivityAssessment(params.features),
    body: params.bodyAssessment,
    condition: buildConditionAssessment(params.features),
    nutrition: buildNutritionAssessment(params.features),
  };

  const overall = buildOverallAssessment(domains);
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
    evaluatorVersion: 1,
    evaluatedAt,
  };
}

function buildEnvironmentAssessment(
  features: DailyHealthFeatures,
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
      summary: 'この日の温湿度評価データがありません。',
      recommendedActions: [
        'SwitchBotの記録と連携状態を確認してください。',
      ],
      sourceUpdatedAt: environment.sourceEvaluatedAt,
    };
  }

  const flags = new Set<string>();

  if (
    environment.avgTemp != null &&
    environment.avgTemp < TEMP_MIN
  ) {
    flags.add('temperatureLow');
  }
  if (
    environment.avgTemp != null &&
    environment.avgTemp > TEMP_MAX
  ) {
    flags.add('temperatureHigh');
  }
  if (
    environment.avgHum != null &&
    environment.avgHum < HUM_MIN
  ) {
    flags.add('humidityLow');
  }
  if (
    environment.avgHum != null &&
    environment.avgHum > HUM_MAX
  ) {
    flags.add('humidityHigh');
  }
  if ((environment.dangerMinutes ?? 0) > 0) {
    flags.add('dangerMinutesDetected');
  }
  if ((environment.spikesTemp ?? 0) > 0) {
    flags.add('temperatureSpike');
  }
  if ((environment.spikesHum ?? 0) > 0) {
    flags.add('humiditySpike');
  }

  const normalizedLevel =
    environment.level?.trim() ?? '';

  let state: HealthAssessmentState;
  if (
    normalizedLevel === '危険' ||
    (environment.dangerMinutes ?? 0) >= 30
  ) {
    state = 'alert';
  } else if (
    normalizedLevel === '注意' ||
    flags.size > 0
  ) {
    state = 'caution';
  } else if (normalizedLevel === '良好') {
    state = 'good';
  } else {
    state = 'stable';
  }

  const tempRatio = clamp01(environment.tempRatio ?? 1);
  const humRatio = clamp01(environment.humRatio ?? 1);
  const score = Math.round(
    (tempRatio * 0.65 + humRatio * 0.35) * 100,
  );

  return {
    state,
    score,
    flags: [...flags],
    summary:
      environment.headline ??
      environmentSummary(environment.avgTemp, environment.avgHum),
    recommendedActions: environment.todayAction
      ? [environment.todayAction]
      : [],
    sourceUpdatedAt: environment.sourceEvaluatedAt,
  };
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
      summary: 'この日は走行距離が記録されていません。',
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
      summary: '活動量を記録しました。比較データを蓄積中です。',
      recommendedActions: [],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  if (deltaPct <= -40) {
    return {
      state: 'alert',
      score: 40,
      flags: ['activityLow', 'activityDrop'],
      summary: '活動量が直近7日平均を大きく下回っています。',
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
      summary: '活動量が直近7日平均より少なめです。',
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
      summary: '活動量が直近7日平均を大きく上回っています。',
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
      summary: '活動量が直近7日平均より多めです。',
      recommendedActions: [],
      sourceUpdatedAt: activity.recordDate,
    };
  }

  return {
    state: 'good',
    score: 100,
    flags: [],
    summary: '活動量は直近7日平均に対して概ね安定しています。',
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

function buildOverallAssessment(
  domains: {
    environment: HealthDomainAssessment;
    activity: HealthDomainAssessment;
    body: HealthDomainAssessment;
    condition: HealthDomainAssessment;
    nutrition: HealthDomainAssessment;
  },
): HealthOverallAssessment {
  const weightedDomains = [
    {domain: domains.environment, weight: 0.35},
    {domain: domains.activity, weight: 0.25},
    {domain: domains.body, weight: 0.25},
    {domain: domains.condition, weight: 0.15},
  ];

  const scored = weightedDomains.filter(
    (item) => item.domain.score != null,
  );

  const scoreWeight = scored.reduce(
    (sum, item) => sum + item.weight,
    0,
  );

  const score = scoreWeight > 0
    ? Math.round(
        scored.reduce(
          (sum, item) =>
            sum + (item.domain.score ?? 0) * item.weight,
          0,
        ) / scoreWeight,
      )
    : null;

  const considered = Object.values(domains).filter(
    (domain) =>
      domain.state !== 'unknown' &&
      domain.state !== 'insufficientData',
  );

  const state = considered.length === 0
    ? 'insufficientData'
    : considered
        .map((domain) => domain.state)
        .sort(
          (a, b) =>
            severityRank(b) - severityRank(a),
        )[0];

  const flags = [
    ...new Set(
      Object.values(domains).flatMap(
        (domain) => domain.flags,
      ),
    ),
  ];

  const topDomain = considered
    .slice()
    .sort(
      (a, b) =>
        severityRank(b.state) - severityRank(a.state),
    )[0];

  const summary = topDomain
    ? topDomain.summary
    : '評価に必要なデータが不足しています。';

  const recommendedActions = [
    ...new Set(
      Object.values(domains).flatMap(
        (domain) => domain.recommendedActions,
      ),
    ),
  ].slice(0, 5);

  return {
    state,
    score,
    flags,
    summary,
    recommendedActions,
  };
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
    params.overall.state === 'insufficientData'
      ? 'insufficient_data' as const
      : 'available' as const;

  const priority =
    params.overall.state === 'alert'
      ? 'high' as const
      : (
          params.overall.state === 'caution' ||
          params.overall.state === 'changed'
        )
        ? 'caution' as const
        : 'normal' as const;

  const lines = [
    '【統合コンディション評価】',
    `評価日: ${params.features.dateKey}`,
    `総合状態: ${params.overall.state}`,
    `総合スコア: ${params.overall.score ?? '未算出'}`,
    `要約: ${params.overall.summary}`,
    '',
    '【環境】',
    params.domains.environment.summary,
    '',
    '【活動量】',
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
    '体重・活動量・温湿度・主観記録の一つだけで病気や原因を断定しないでください。',
    '体調不良が疑われる場合は、観察、環境調整、受診検討を分けて案内してください。',
  ];

  return {
    status,
    priority,
    summary: params.overall.summary,
    promptText: lines.join('\n'),
    version: 1,
    generatedAt: params.generatedAt,
  };
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
