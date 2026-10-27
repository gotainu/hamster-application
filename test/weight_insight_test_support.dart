Map<String, dynamic> weightInsightSetFixture({
  String kind = 'current',
  String evaluationDateKey = '2026-10-11',
  String generatedAt = '2026-10-11T02:00:00Z',
  bool range = true,
  bool period = true,
  bool allEqual = false,
  bool learning = false,
}) {
  final dates = [
    '2026-09-21',
    '2026-09-23',
    '2026-09-25',
    '2026-09-27',
    '2026-09-29',
    '2026-10-01',
    '2026-10-03',
    '2026-10-04'
  ];
  Map<String, dynamic> insight(String type, int priority) => {
        'id': type,
        'kind': type,
        'metric': 'body',
        'evaluationDateKey': evaluationDateKey,
        'observationStartDateKey': dates.first,
        'observationEndDateKey':
            type == 'weight_period_difference' ? '2026-10-10' : dates.last,
        'records': [
          for (var i = 0; i < dates.length; i++)
            {
              'dateKey': dates[i],
              'value': allEqual ? 100 : (i == 7 ? 104 : 100)
            },
          if (type == 'weight_period_difference')
            {'dateKey': '2026-10-10', 'value': allEqual ? 100 : 103}
        ],
        'validRecordCount': type == 'weight_period_difference' ? 9 : 8,
        'unit': 'g',
        'evidence': type == 'weight_observed_range'
            ? {
                'minimumGrams': 100,
                'maximumGrams': allEqual ? 100 : 104,
                'allEqual': allEqual,
              }
            : {
                'startWeightGrams': 100,
                'endWeightGrams': allEqual ? 100 : 103,
                'differenceGrams': allEqual ? 0 : 3,
                'absoluteDifferenceGrams': allEqual ? 0 : 3,
                'startDateKey': dates.first,
                'endDateKey': '2026-10-10',
                'windowDays': 30,
              },
        'dataQuality': {
          'baselineStatus': learning ? 'learning' : 'ready',
          'latestDateKey': '2026-10-10',
          'daysSinceMeasurement': 1,
          'missingDaysNotImputed': true
        },
        'interpretationCode': type == 'weight_observed_range'
            ? (allEqual ? 'weight_all_equal' : 'weight_observed_range')
            : (allEqual ? 'weight_unchanged' : 'weight_increased'),
        'eligible': true,
        'priority': priority,
        'calculationSpecVersion': 'weight_insights_v1',
        'sourceGeneratedAt': generatedAt,
        'limitations': ['健康状態や継続的な傾向の判定ではありません。'],
      };
  return {
    'schemaVersion': 1,
    'kind': kind,
    'calculationSpecVersion': 'weight_insights_v1',
    'evaluationDateKey': evaluationDateKey,
    'generatedAt': generatedAt,
    'source': {
      'silverDateKey': evaluationDateKey,
      'silverSchemaVersion': 5,
      'silverGeneratedAt': generatedAt
    },
    'contentHash': 'fixture-content',
    'insights': [
      if (period) insight('weight_period_difference', 10),
      if (range) insight('weight_observed_range', 20)
    ],
  };
}
