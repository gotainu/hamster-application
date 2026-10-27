import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'package:hamster_project/services/switchbot_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/viewmodels/weight_insights_view_model.dart';
import 'package:hamster_project/widgets/health_individual_analysis.dart';
import 'package:hamster_project/widgets/weight_insights_card.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'current_weight_analysis_test_support.dart';
import 'health_analysis_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';
import 'weight_insights_ui_support.dart';

Future<void> _showCard(WidgetTester tester, CurrentWeightAnalysis? current,
    {bool dark = true, double width = 393, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  await tester.pumpWidget(MaterialApp(
    theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: personalityV3GoldenFont)),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: Scaffold(
        body: SingleChildScrollView(
      padding: AppTheme.dataPagePadding,
      child: WeightInsightsCard(
          viewModel: WeightInsightsViewModel.fromCurrent(current)),
    )),
  ));
  await tester.pumpAndSettle();
}

class _InsightSource implements WeightAnalysisSource {
  _InsightSource(this.current);
  final CurrentWeightAnalysis? current;
  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() =>
      Stream.multi((sink) => sink.add(current), isBroadcast: true);
}

Stream<T> _replay<T>(T value) =>
    Stream.multi((sink) => sink.add(value), isBroadcast: true);

Future<void> _showGraph(
    WidgetTester tester, CurrentWeightAnalysis current) async {
  await showHealthAnalysisUi(
      tester,
      GraphFunctionScreen(
        initialWeightAnalysis: true,
        weightAnalysisSource: _InsightSource(current),
        weightRecordsStream: _replay(List.generate(9, (i) {
          final day = DateTime(2026, 10, 3 + i);
          return WeightRecord(
              dayKey: fixtureDateKey(day),
              date: day,
              weightGrams: 100,
              memo: '');
        })),
        activityRecordsStream: _replay<List<HealthRecord>>(const []),
        switchbotConfigStream: _replay<SwitchbotConfig?>(null),
      ),
      golden: true);
}

void main() {
  setUpAll(loadPersonalityV3GoldenFonts);

  testWidgets('all-equal real records display exact adopted count and range',
      (tester) async {
    await _showCard(
        tester, currentInsightsUiFixture(allEqual: true, period: false));
    expect(find.text('採用した8件の体重はすべて100gでした'), findsOneWidget);
    expect(find.textContaining('2026-09-21'), findsWidgets);
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MAD zero with different records does not claim all equal',
      (tester) async {
    await _showCard(tester, currentInsightsUiFixture());
    expect(find.text('採用した8件の体重は100〜104gでした'), findsOneWidget);
    expect(find.textContaining('3g増えました'), findsOneWidget);
    expect(find.textContaining('すべて100g'), findsNothing);
    expect(find.textContaining('健康'), findsNothing);
    expect(find.textContaining('継続的'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'independent endpoint Insight is available while baseline learning',
      (tester) async {
    await _showCard(
        tester,
        currentInsightsUiFixture(
            range: false, learning: true, research: false));
    expect(find.textContaining('3g増えました'), findsOneWidget);
    expect(find.textContaining('採用した8件'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing Insight Gold never fills from baseline or report',
      (tester) async {
    await _showCard(tester, currentInsightsUiFixture(includeInsights: false));
    expect(find.byKey(const ValueKey('weight-insights-card')), findsNothing);
    expect(find.textContaining('発見'), findsNothing);
  });

  testWidgets(
      'mismatched current date does not display attached prior Insights',
      (tester) async {
    final original = currentInsightsUiFixture();
    final wrongDate = CurrentWeightAnalysis(
      ownerId: original.ownerId,
      evaluationDateKey: '2026-10-12',
      features: original.features,
      profile: original.profile,
      reference: original.reference,
      insights: original.insights,
    );
    await _showCard(tester, wrongDate);
    expect(find.byKey(const ValueKey('weight-insights-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [true, false]) {
    testWidgets('compact Insight card scales without overflow dark=$dark',
        (tester) async {
      await _showCard(tester, currentInsightsUiFixture(),
          dark: dark, width: 320, scale: 1.5);
      expect(find.textContaining('3g増えました'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'graph supplements its chart; period selection does not relabel fixed Insight period',
      (tester) async {
    final current = currentInsightsUiFixture(research: false);
    await _showGraph(tester, current);
    for (final period in ['7日', '30日', '全期間']) {
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      expect(find.byType(SfCartesianChart), findsOneWidget);
      await tester
          .ensureVisible(find.byKey(const ValueKey('weight-insights-card')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3g増えました'), findsOneWidget);
      expect(find.textContaining('2026-09-21'), findsWidgets);
      expect(tester.takeException(), isNull);
      final scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      scrollable.position.jumpTo(scrollable.position.minScrollExtent);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('health only adds Insights to the same confirmed evaluation',
      (tester) async {
    final current = currentInsightsUiFixture();
    final health = healthAssessmentFixture(analysis: current, bodyScore: 87);
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
          child: HealthWeightIndividualAnalysis(
              viewModel: healthAnalysisViewModelFixture(
                  analysis: current, assessment: health)),
        )));
    expect(find.textContaining('3g増えました'), findsOneWidget);
    expect(health.domains.body.score, 87);
    expect(health.overall.score, 100);
  });

  testWidgets(
      'misaligned health omits current Insight while preserving fallback',
      (tester) async {
    final current = currentInsightsUiFixture();
    final health = healthAssessmentFixture(
        analysis: current,
        bodyScore: 87,
        dateKey: '2026-10-10',
        featureDateKey: '2026-10-10',
        evaluatedAt: DateTime.utc(2026, 10, 10, 2));
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
          child: HealthWeightIndividualAnalysis(
              viewModel: healthAnalysisViewModelFixture(
                  analysis: current, assessment: health)),
        )));
    expect(find.textContaining('3g増えました'), findsNothing);
    expect(find.byKey(const ValueKey('health-weight-analysis-fallback')),
        findsOneWidget);
    expect(health.domains.body.score, 87);
  });

  testWidgets(
      'report discovery comes from frozen snapshot and never current source',
      (tester) async {
    final data = reportInsightsUiFixture();
    await showPersonalityV3(tester, data);
    expect(find.textContaining('3g増えました'), findsOneWidget);
    expect(find.byType(WeightInsightsCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'activity-only report can explain weight endpoints without claiming a ready weight baseline',
      (tester) async {
    await showPersonalityV3(tester, reportInsightsUiFixture(bodyReady: false));
    expect(find.textContaining('3g増えました'), findsOneWidget);
    expect(find.text('体重はこれから'), findsOneWidget);
    expect(find.text('活動量'), findsOneWidget);
    expect(find.textContaining('採用した8件の体重'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cache-only health confirmation never displays committed current Insights',
      (tester) async {
    final current = currentInsightsUiFixture();
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
          child: HealthWeightIndividualAnalysis(
              viewModel: healthAnalysisViewModelFixture(
                  analysis: current, confirmed: false)),
        )));
    expect(find.byKey(const ValueKey('weight-insights-card')), findsNothing);
    expect(find.byKey(const ValueKey('health-weight-analysis-fallback')),
        findsOneWidget);
  });

  testWidgets(
      'new Insight report still marks successful rendering exactly once',
      (tester) async {
    var viewed = 0;
    await showPersonalityV3(tester, reportInsightsUiFixture(), onViewed: (_) {
      viewed++;
    });
    expect(find.textContaining('3g増えました'), findsOneWidget);
    expect(viewed, 1);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(viewed, 1);
  });

  testWidgets('legacy report without Insights keeps its existing discovery',
      (tester) async {
    await showPersonalityV3(
        tester, reportInsightsUiFixture(includeInsights: false));
    expect(find.byKey(const ValueKey('personality-overview')), findsOneWidget);
    expect(find.textContaining('3g増えました'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
