import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/models/weight_research_comparison.dart';
import 'package:hamster_project/viewmodels/personality_report_view_model.dart';
import 'package:hamster_project/viewmodels/weight_research_comparison_view_model.dart';

import 'personality_report_v2_ui_fixtures.dart';

WeightResearchComparisonViewModel _vm(double weight) =>
    WeightResearchComparisonViewModel(WeightResearchComparison(
      individualWeightGrams: weight,
      referenceMedianGrams: 133,
      referenceP25Grams: 100,
      referenceP75Grams: 160,
    ));

void main() {
  test('one shared comparison preserves reference arithmetic outside IQR', () {
    expect(_vm(100).summary, '同種の参考中央値より33g軽め');
    expect(_vm(70).summary, '同種の参考中央値より63g軽め');
    expect(_vm(180).summary, '同種の参考中央値より47g重め');
    expect(_vm(133).summary, '同種の参考中央値と同じ水準');
    expect(_vm(133).deltaValue, '0g');
    expect(_vm(132.99).deltaValue, '0.1g未満');
    expect(_vm(132.99).deltaCaption, '軽め');
  });

  test('saved v1 and daily reports use the same wording without input mutation',
      () {
    for (final reportId in [
      'personality_v1_body_activity',
      'daily_2026-10-09'
    ]) {
      final data = personalityV2UiFixture(reportId: reportId);
      final report = PersonalityReport.fromMap(data);
      final snapshot = report.body!;
      final shared = WeightResearchComparisonViewModel.fromSnapshot(snapshot)!;
      final reportVm = PersonalityReportViewModel(report).body!;
      expect(reportVm.summary, shared.summary);
      expect(reportVm.comparisonDeltaValue, shared.deltaValue);
      expect(reportVm.comparisonDeltaCaption, shared.deltaCaption);
      expect(reportVm.comparisonDeltaContext, shared.deltaContext);
      expect(reportVm.discovery, shared.discovery);
      expect(snapshot.median, 100);
      expect(snapshot.population!.median, 133);
      expect(report.reportId, reportId);
    }
  });

  test('saved inapplicable comparison is never made applicable by UI', () {
    final data = personalityV2UiFixture(population: {
      'applicability': 'not_applicable',
      'reason': 'age_unknown',
    });
    final report = PersonalityReport.fromMap(data);
    expect(
        WeightResearchComparisonViewModel.fromSnapshot(report.body!), isNull);
    expect(
        PersonalityReportViewModel(report).body!.populationApplicable, isFalse);
  });

  test('invalid numbers and inverted research bounds are rejected', () {
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
          WeightResearchComparison(
                  individualWeightGrams: value,
                  referenceMedianGrams: 133,
                  referenceP25Grams: 100,
                  referenceP75Grams: 160)
              .isValid,
          isFalse);
    }
    expect(
        const WeightResearchComparison(
                individualWeightGrams: 100,
                referenceMedianGrams: 133,
                referenceP25Grams: 140,
                referenceP75Grams: 160)
            .isValid,
        isFalse);
    expect(_vm(70).comparison.isValid, isTrue);
    expect(_vm(180).comparison.isValid, isTrue);
  });
}
