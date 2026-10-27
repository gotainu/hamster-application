import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/checkin_insight.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/services/current_checkin_insights_repo.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/services/switchbot_repo.dart';
import 'package:hamster_project/viewmodels/checkin_insights_view_model.dart';
import 'package:hamster_project/widgets/insights_card.dart';
import 'checkin_insight_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';

class _CheckinSource implements CheckinInsightsSource {
  final CurrentCheckinAnalysis? value;
  _CheckinSource(this.value);
  @override
  Stream<CurrentCheckinAnalysis?> watchCurrent() => _stream(value);
}

class _WeightSource implements WeightAnalysisSource {
  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() => _stream(null);
}

Stream<T> _stream<T>(T value) =>
    Stream.multi((sink) => sink.add(value), isBroadcast: true);
void main() {
  setUpAll(loadPersonalityV3GoldenFonts);
  for (final kind in [
    'checkin_item_repetition',
    'checkin_concern_frequency',
    'checkin_record_continuity'
  ]) {
    testWidgets('server evidence $kind compact card', (tester) async {
      final vm = CheckinInsightsViewModel.fromCurrent(
          checkinCurrentFixture(kind: kind));
      await showHealthAnalysisUi(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: InsightsCard(title: '今日の様子の記録から', items: vm.items))),
          size: const Size(320, 852),
          textScale: 1.5,
          golden: true);
      expect(find.text(vm.items.single.text), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.textContaining('病気'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'daily report uses own frozen evidence, old report remains unchanged',
      (tester) async {
    await showPersonalityV3(tester, checkinReportFixture(), goldenFont: true);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('checkin-insights-card')), 250,
        maxScrolls: 30);
    expect(find.textContaining('食欲が3日'), findsOneWidget);
    expect(find.textContaining('2026-09-27〜2026-10-10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await showPersonalityV3(tester, personalityV3Fixture(), goldenFont: true);
    expect(find.byKey(const ValueKey('checkin-insights-card')), findsNothing);
  });
  testWidgets(
      'changes shows observation evidence without weight records or research',
      (tester) async {
    final current = checkinCurrentFixture();
    final vm = CheckinInsightsViewModel.fromCurrent(current);
    await showHealthAnalysisUi(
        tester,
        GraphFunctionScreen(
            weightAnalysisSource: _WeightSource(),
            checkinInsightsSource: _CheckinSource(current),
            weightRecordsStream: _stream<List<WeightRecord>>([]),
            activityRecordsStream: _stream<List<HealthRecord>>([]),
            switchbotConfigStream: _stream<SwitchbotConfig?>(null)),
        golden: true);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('checkin-insights-card')), 250,
        maxScrolls: 30);
    expect(find.text(vm.items.single.text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
