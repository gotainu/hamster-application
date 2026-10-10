import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> personalityFixture({
  String type = 'weight_only',
  String? reportId,
  Map<String, dynamic>? population,
}) {
  final ready = type == 'both'
      ? ['body', 'activity']
      : [type == 'activity_only' ? 'activity' : 'body'];
  return {
    'schemaVersion': 1,
    'analysisSpecVersion': 'personality_v1',
    'reportId': reportId ?? 'personality_v1_${ready.join('_')}',
    'petId': 'main_pet',
    'reportType': type,
    'evaluationDateKey': '2026-10-08',
    'silverDateKey': '2026-10-08',
    'generatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 8, 3)),
    'readyMetrics': ready,
    'petSnapshot': {'species': 'シリアン', 'ageMonths': 8},
    'metrics': {
      for (final metric in ready)
        metric: {
          'unit': metric == 'body' ? 'g' : 'm',
          'baseline': {
            'status': 'ready',
            'median': metric == 'body' ? 100 : 2000,
            'mad': 0,
            'ewma': metric == 'body' ? 100 : 2000,
            'recordCount': 8,
            'requiredRecordCount': 7,
            'spanDays': 14,
            'requiredSpanDays': 14,
            'firstDateKey': '2026-09-22',
            'lastDateKey': '2026-10-05',
          },
          'latestValue': metric == 'body' ? 100 : 2000,
          'latestDateKey': '2026-10-06',
          'difference': {'absolute': 0, 'percent': 0},
          'interpretations': [
            {
              'code': metric == 'body'
                  ? 'individual_weight'
                  : 'individual_activity',
              'text': metric == 'body'
                  ? 'この子の普段の体重は、観察記録では約100gです。'
                  : 'この子の普段の1日の走行距離は、観察記録では約2000mです。',
            },
            {
              'code': 'latest_matches_baseline',
              'text': '最近の記録は、この子の普段の基準と同じ値でした。'
            },
          ],
          'populationComparison': metric == 'body'
              ? (population ??
                  {
                    'applicability': 'not_applicable',
                    'reason': 'reference_unavailable',
                    'expressionJa': '適用できる比較データがないため公開研究との比較を適用しません。',
                    'cohort': null,
                    'position': null,
                    'limitations': ['中央50%の範囲を健康・異常の判定に使うことはできません。'],
                  })
              : null,
        },
    },
    'readinessSnapshot': {
      'body': {
        'status': ready.contains('body') ? 'ready' : 'learning',
        'recordCount': 8,
        'spanDays': 14
      },
      'activity': {
        'status': ready.contains('activity') ? 'ready' : 'learning',
        'recordCount': 0,
        'spanDays': 0
      },
    },
    'limitations': [
      '観察記録に基づく特徴の説明です。肥満・健康・病気の診断ではありません。',
      'MADが0でも、すべての記録が同じ値だったことを意味しません。',
    ],
    'access': {'mode': 'read_only', 'requiresSubscription': false},
  };
}

Map<String, dynamic> applicablePopulation({bool small = false}) => {
      'applicability': 'applicable',
      'reason': null,
      'position': 'within_iqr',
      'expressionJa':
          '公開研究の中央50%の範囲内です（中央値133g、中央50%の範囲100〜160g）。健康状態や正確な順位を示すものではありません。',
      'cohort': {
        'median': 133,
        'p25': 100,
        'p75': 160,
        'referenceVersion': 'published_weight_v1',
        'sourceVersion': 'study_table1_v1',
        'sourceTitle': 'Published hamster study',
        'sourceDOI': '10.1111/jsap.13527',
        'sourceYear': 2022,
        'studyYear': 2016,
        'population': 'UK primary veterinary care, 2016',
        'sampleSizeCaution': small,
        'speciesPopulationN': small ? 52 : 12197,
        'weightSampleN': null,
      },
      'limitations': ['種別総個体数は成人体重を解析した標本数ではありません。'],
    };
