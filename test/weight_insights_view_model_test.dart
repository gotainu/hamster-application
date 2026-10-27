import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/daily_health_features.dart';
import 'package:hamster_project/models/weight_insight.dart';
import 'package:hamster_project/viewmodels/weight_insights_view_model.dart';
import 'current_weight_analysis_test_support.dart';
import 'weight_insight_test_support.dart';

void main() {
  WeightInsightsViewModel view(Map<String, dynamic> raw) {
    final features = DailyHealthFeatures.fromMap(
        currentWeightFeaturesFixture(latest: 103),
        fallbackDateKey: '2026-10-11');
    return WeightInsightsViewModel.fromCurrent(CurrentWeightAnalysis(
        ownerId: 'owner',
        evaluationDateKey: '2026-10-11',
        features: features,
        profile:
            const CurrentWeightProfile(rawSpecies: null, birthdayDateKey: null),
        reference: null,
        insights: CurrentInsightSet.fromMap(raw,
            features: features, evaluationDateKey: '2026-10-11')));
  }

  test(
      'server priority preserved and exact endpoint difference phrased without trend',
      () {
    final vm = view(weightInsightSetFixture());
    expect(vm.items.first.kind, WeightInsightKind.periodDifference);
    expect(vm.primaryText, '9月21日から10月10日までに3g増えました');
    expect(vm.items[1].text, '採用した8件の体重は100〜104gでした');
    expect(vm.items[1].periodLabel, '2026-09-21〜2026-10-04');
    expect(vm.items.first.text, isNot(contains('傾向')));
  });
  test('all adopted values equal gets exact equality wording', () {
    expect(
        view(weightInsightSetFixture(period: false, allEqual: true))
            .primaryText,
        '採用した8件の体重はすべて100gでした');
  });
  test('absent insights gives safe empty state and old report fallback', () {
    expect(WeightInsightsViewModel.fromCurrent(null).items, isEmpty);
    expect(WeightInsightsViewModel.fromSnapshot(null).primaryText, isNull);
    expect(
        WeightInsightsViewModel.fromCurrent(currentWeightAnalysisFixture())
            .items,
        isEmpty);
  });
  test('mismatched current date or source generation is hidden', () {
    final features = DailyHealthFeatures.fromMap(
        currentWeightFeaturesFixture(latest: 103),
        fallbackDateKey: '2026-10-11');
    final set = CurrentInsightSet.fromMap(weightInsightSetFixture(),
        features: features, evaluationDateKey: '2026-10-11');
    final wrongDay = CurrentWeightAnalysis(
        ownerId: 'owner',
        evaluationDateKey: '2026-10-12',
        features: features,
        profile:
            const CurrentWeightProfile(rawSpecies: null, birthdayDateKey: null),
        reference: null,
        insights: set);
    expect(WeightInsightsViewModel.fromCurrent(wrongDay).items, isEmpty);
    final newer = DailyHealthFeatures.fromMap(
        currentWeightFeaturesFixture(latest: 103)
          ..['generatedAt'] = DateTime.utc(2026, 10, 11, 3),
        fallbackDateKey: '2026-10-11');
    final mismatched = CurrentWeightAnalysis(
        ownerId: 'owner',
        evaluationDateKey: '2026-10-11',
        features: newer,
        profile:
            const CurrentWeightProfile(rawSpecies: null, birthdayDateKey: null),
        reference: null,
        insights: set);
    expect(WeightInsightsViewModel.fromCurrent(mismatched).items, isEmpty);
  });
  test('small nonzero endpoint difference never displays zero increase', () {
    final raw = weightInsightSetFixture(range: false);
    final item = raw['insights'][0];
    item['records'].last['value'] = 100.001;
    item['evidence']['endWeightGrams'] = 100.001;
    item['evidence']['differenceGrams'] = .001;
    item['evidence']['absoluteDifferenceGrams'] = .001;
    final features = DailyHealthFeatures.fromMap(
        currentWeightFeaturesFixture(latest: 100.001),
        fallbackDateKey: '2026-10-11');
    final set = CurrentInsightSet.fromMap(raw,
        features: features, evaluationDateKey: '2026-10-11');
    final current = CurrentWeightAnalysis(
        ownerId: 'owner',
        evaluationDateKey: '2026-10-11',
        features: features,
        profile:
            const CurrentWeightProfile(rawSpecies: null, birthdayDateKey: null),
        reference: null,
        insights: set);
    expect(WeightInsightsViewModel.fromCurrent(current).primaryText,
        contains('0.01g未満増えました'));
    expect(WeightInsightsViewModel.fromCurrent(current).primaryText,
        isNot(contains('0g増えました')));
  });
  test('distinct range endpoints never collapse into an equal display', () {
    final raw = weightInsightSetFixture(period: false, allEqual: false);
    final item = raw['insights'][0];
    for (final record in item['records']) {
      record['value'] = 100.001;
    }
    item['records'].last['value'] = 100.002;
    item['evidence']['minimumGrams'] = 100.001;
    item['evidence']['maximumGrams'] = 100.002;
    expect(view(raw).primaryText, '採用した8件の体重は100.001〜100.002gでした');
  });
  test('snapshot stays independent of a later current set', () {
    final snapshot = ReportInsightSnapshot.fromMap(
        weightInsightSetFixture(
            kind: 'report_snapshot', allEqual: true, period: false),
        evaluationDateKey: '2026-10-11',
        generatedAt: DateTime.utc(2026, 10, 11, 2),
        cutoffDateKey: '2026-10-10');
    expect(view(weightInsightSetFixture()).primaryText, contains('3g'));
    expect(WeightInsightsViewModel.fromSnapshot(snapshot).primaryText,
        contains('すべて100g'));
  });
}
