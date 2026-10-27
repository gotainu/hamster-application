import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/daily_health_features.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/models/weight_insight.dart';
import 'package:hamster_project/viewmodels/weight_insights_view_model.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/weight_insight_backend_${name}_fixture.json')
        .readAsStringSync()) as Map<String, dynamic>;
void main() {
  test(
      'actual TypeScript builder current Gold is consumed without reordering or recalculating',
      () {
    final features = DailyHealthFeatures.fromMap(_fixture('silver'),
        fallbackDateKey: '2026-10-11');
    final set = CurrentInsightSet.fromMap(_fixture('current'),
        features: features, evaluationDateKey: '2026-10-11');
    expect(set.insights.map((i) => i.priority), [10, 20]);
    final current = CurrentWeightAnalysis(
        ownerId: 'synthetic-owner',
        evaluationDateKey: '2026-10-11',
        features: features,
        profile:
            const CurrentWeightProfile(rawSpecies: null, birthdayDateKey: null),
        reference: null,
        insights: set);
    final vm = WeightInsightsViewModel.fromCurrent(current);
    expect(vm.primaryText, '9月22日から10月10日までに3g増えました');
    expect(vm.items.last.text, '採用した8件の体重は100〜104gでした');
    expect(features.body.personalBaseline.mad, 0);
    expect(vm.items.last.text, isNot(contains('すべて')));
  });
  test(
      'actual daily report carries own cutoff snapshot, never live current Gold',
      () {
    final raw = _fixture('report');
    final report = PersonalityReport.fromMap(raw);
    expect(report.insightSnapshot, isNotNull);
    expect(report.insightSnapshot!.insights.length, 2);
    expect(
        WeightInsightsViewModel.fromSnapshot(report.insightSnapshot)
            .primaryText,
        '9月22日から10月10日までに3g増えました');
    final snapshot = ReportInsightSnapshot.fromMap(_fixture('snapshot'),
        evaluationDateKey: report.evaluationDateKey,
        generatedAt: report.generatedAt,
        cutoffDateKey: report.cutoffDateKey!);
    expect(snapshot.generatedAt, report.generatedAt);
    expect(
        () => CurrentInsightSet.fromMap(_fixture('snapshot'),
            features: DailyHealthFeatures.fromMap(_fixture('silver'),
                fallbackDateKey: '2026-10-11'),
            evaluationDateKey: '2026-10-11'),
        throwsFormatException);
  });
}
