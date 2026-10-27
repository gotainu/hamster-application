import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_health_features.dart';
import 'package:hamster_project/models/weight_insight.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'personality_report_fixtures.dart';
import 'current_weight_analysis_test_support.dart';
import 'weight_insight_test_support.dart';

void main() {
  DailyHealthFeatures silver({bool ready = true}) =>
      DailyHealthFeatures.fromMap(
          currentWeightFeaturesFixture(ready: ready, latest: 103),
          fallbackDateKey: '2026-10-11');
  CurrentInsightSet parse(Map<String, dynamic> raw, {bool ready = true}) =>
      CurrentInsightSet.fromMap(raw,
          features: silver(ready: ready), evaluationDateKey: '2026-10-11');
  test('current and immutable snapshot scopes are separate', () {
    final current = parse(weightInsightSetFixture());
    expect(current.insights.length, 2);
    expect(() => parse(weightInsightSetFixture(kind: 'report_snapshot')),
        throwsFormatException);
    final snapshot = ReportInsightSnapshot.fromMap(
        weightInsightSetFixture(kind: 'report_snapshot'),
        evaluationDateKey: '2026-10-11',
        generatedAt: DateTime.utc(2026, 10, 11, 2),
        cutoffDateKey: '2026-10-10');
    expect(snapshot.insights.length, 2);
    expect(
        () => ReportInsightSnapshot.fromMap(weightInsightSetFixture(),
            evaluationDateKey: '2026-10-11',
            generatedAt: DateTime.utc(2026, 10, 11, 2),
            cutoffDateKey: '2026-10-10'),
        throwsFormatException);
  });
  test('current source date and generation must exactly match live Silver', () {
    final raw = weightInsightSetFixture();
    raw['source']['silverGeneratedAt'] = '2026-10-10T02:00:00Z';
    expect(() => parse(raw), throwsFormatException);
    final old = weightInsightSetFixture(evaluationDateKey: '2026-10-10');
    expect(() => parse(old), throwsFormatException);
  });
  test('range validates adopted record bounds and exact equality, not MAD', () {
    final current =
        parse(weightInsightSetFixture(allEqual: true, period: false));
    expect(current.insights.single.evidence, isA<WeightRangeEvidence>());
    final raw = weightInsightSetFixture(allEqual: true, period: false);
    raw['insights'][0]['records'][3]['value'] = 104;
    expect(() => parse(raw), throwsFormatException);
  });
  test('period independently works during learning; range does not', () {
    expect(
        parse(weightInsightSetFixture(range: false, learning: true),
                ready: false)
            .insights
            .length,
        1);
    expect(
        () => parse(weightInsightSetFixture(period: false, learning: true),
            ready: false),
        throwsFormatException);
  });
  test('fewer than two dates, duplicate dates and future records are rejected',
      () {
    final one = weightInsightSetFixture(range: false);
    one['insights'][0]['records'] = [
      {'dateKey': '2026-10-10', 'value': 103}
    ];
    one['insights'][0]['validRecordCount'] = 1;
    expect(() => parse(one), throwsFormatException);
    final duplicate = weightInsightSetFixture(range: false);
    duplicate['insights'][0]['records'][1]['dateKey'] = '2026-09-21';
    expect(() => parse(duplicate), throwsFormatException);
    final future = weightInsightSetFixture(range: false);
    future['insights'][0]['records'][8]['dateKey'] = '2026-10-12';
    expect(() => parse(future), throwsFormatException);
  });
  test('stale, imputed, ineligible and unsupported evidence is rejected', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (x) => x['insights'][0]['dataQuality']['daysSinceMeasurement'] = 14,
      (x) => x['insights'][0]['dataQuality']['missingDaysNotImputed'] = false,
      (x) => x['insights'][0]['eligible'] = false,
      (x) => x['insights'][0]['unit'] = 'm',
      (x) => x['insights'][0]['calculationSpecVersion'] = 'unknown',
    ]) {
      final raw = weightInsightSetFixture(range: false);
      mutate(raw);
      expect(() => parse(raw), throwsFormatException);
    }
  });
  test('ascending server priority and empty set preserve the wire contract',
      () {
    expect(parse(weightInsightSetFixture()).insights.map((x) => x.priority),
        [10, 20]);
    expect(parse(weightInsightSetFixture(range: false, period: false)).insights,
        isEmpty);
    final reversed = weightInsightSetFixture();
    reversed['insights'] = (reversed['insights'] as List).reversed.toList();
    expect(() => parse(reversed), throwsFormatException);
  });
  test(
      'daily optional snapshot decodes; malformed and legacy remain compatible',
      () {
    Map<String, dynamic> report() =>
        personalityFixture(reportId: 'daily_2026-10-11')
          ..['evaluationDateKey'] = '2026-10-11'
          ..['silverDateKey'] = '2026-10-11'
          ..['generatedAt'] = DateTime.utc(2026, 10, 11, 2)
          ..['cutoffDateKey'] = '2026-10-10';
    final data = report()
      ..['insightSnapshot'] = weightInsightSetFixture(kind: 'report_snapshot');
    expect(PersonalityReport.fromMap(data).insightSnapshot!.insights.length, 2);
    data['insightSnapshot']['kind'] = 'current';
    expect(PersonalityReport.fromMap(data).insightSnapshot, isNull);
    expect(PersonalityReport.fromMap(report()).insightSnapshot, isNull);
    final legacy = personalityFixture()
      ..['insightSnapshot'] = weightInsightSetFixture(kind: 'report_snapshot');
    expect(PersonalityReport.fromMap(legacy).insightSnapshot, isNull);
  });
  test(
      'activity-only daily snapshot may explain independent measured weight difference',
      () {
    final data =
        personalityFixture(type: 'activity_only', reportId: 'daily_2026-10-11')
          ..['evaluationDateKey'] = '2026-10-11'
          ..['silverDateKey'] = '2026-10-11'
          ..['generatedAt'] = DateTime.utc(2026, 10, 11, 2)
          ..['cutoffDateKey'] = '2026-10-10'
          ..['insightSnapshot'] = weightInsightSetFixture(
              kind: 'report_snapshot', range: false, learning: true);
    final report = PersonalityReport.fromMap(data);
    expect(report.body, isNull);
    expect(report.activity, isNotNull);
    expect(report.insightSnapshot!.insights.single.kind,
        WeightInsightKind.periodDifference);
    expect(report.insightSnapshot!.insights.single.dataQuality.baselineStatus,
        'learning');
  });
  test('report cutoff and generation prevent contemporary data leakage', () {
    final raw = weightInsightSetFixture(kind: 'report_snapshot');
    expect(
        () => ReportInsightSnapshot.fromMap(raw,
            evaluationDateKey: '2026-10-11',
            generatedAt: DateTime.utc(2026, 10, 12, 2),
            cutoffDateKey: '2026-10-10'),
        throwsFormatException);
    expect(
        () => ReportInsightSnapshot.fromMap(raw,
            evaluationDateKey: '2026-10-11',
            generatedAt: DateTime.utc(2026, 10, 11, 2),
            cutoffDateKey: '2026-10-09'),
        throwsFormatException);
  });
}
