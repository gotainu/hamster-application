import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_health_features.dart';

void main() {
  test('reads personal baseline metadata for activity and body', () {
    final features = DailyHealthFeatures.fromMap(
      {
        'dateKey': '2026-09-14',
        'activity': {
          'hasRecord': true,
          'distanceMeters': 900,
          'avg7DistanceMeters': 1000,
          'deltaPct': -10,
          'personalBaseline': baselineMap(
            median: 1000,
            deviationPct: -10,
          ),
        },
        'body': {
          'latestWeightGrams': 120,
          'personalBaseline': baselineMap(
            median: 118,
            deviationPct: 1.7,
          ),
        },
      },
      fallbackDateKey: '2026-09-14',
    );

    expect(features.activity.personalBaseline.isReady, isTrue);
    expect(features.activity.personalBaseline.median, 1000);
    expect(features.body.personalBaseline.median, 118);
    expect(features.body.personalBaseline.deviationPct, 1.7);
  });

  test('legacy feature documents default to a learning baseline', () {
    final features = DailyHealthFeatures.fromMap(
      const {},
      fallbackDateKey: '2026-09-14',
    );

    expect(features.activity.personalBaseline.isReady, isFalse);
    expect(features.activity.personalBaseline.recordCount, 0);
    expect(features.body.personalBaseline.isReady, isFalse);
  });
}

Map<String, Object?> baselineMap({
  required double median,
  required double deviationPct,
}) {
  return {
    'status': 'ready',
    'method': 'median_mad_ewma_v1',
    'recordCount': 7,
    'requiredRecordCount': 7,
    'spanDays': 21,
    'requiredSpanDays': 14,
    'firstDateKey': '2026-08-20',
    'lastDateKey': '2026-09-10',
    'median': median,
    'mad': 1,
    'ewma': median,
    'ewmaAlpha': 0.3,
    'deviationPct': deviationPct,
    'robustZScore': 0,
  };
}
