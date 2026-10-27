import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/health_assessment.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/services/switchbot_repo.dart';
import 'package:hamster_project/screens/daily_status_detail.dart';
import 'package:hamster_project/widgets/health_score_gauge.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';
import 'package:hamster_project/widgets/weight_research_comparison_card.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'health_analysis_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';

Future<ValueNotifier<CurrentWeightAnalysis?>> _showWeight(
  WidgetTester tester, {
  CurrentWeightAnalysis? analysis,
  HealthAssessment? assessment,
  bool confirmed = true,
  bool absent = false,
  bool dark = true,
  bool goldenFont = false,
  String? ownerId = 'synthetic-owner',
  WidgetBuilder? currentWeightAnalysisBuilder,
  double textScale = 1,
  Size size = const Size(393, 852),
}) async {
  final current = analysis ?? healthAnalysisFixture();
  final notifier =
      ValueNotifier<CurrentWeightAnalysis?>(absent ? null : current);
  addTearDown(notifier.dispose);
  await showHealthAnalysisUi(
      tester,
      HealthWeightDetailScreen(
        assessment: assessment ?? healthAssessmentFixture(analysis: current),
        analysisListenable: notifier,
        ownerId: ownerId,
        assessmentServerConfirmed: confirmed,
        currentWeightAnalysisBuilder: currentWeightAnalysisBuilder,
        backgroundBuilder: healthTestBackground,
      ),
      dark: dark,
      golden: goldenFont,
      size: size,
      textScale: textScale);
  return notifier;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja_JP');
    await loadPersonalityV3GoldenFonts();
  });

  testWidgets(
      'weight health score and current personal/reference values remain distinct',
      (tester) async {
    final analysis = healthAnalysisFixture(latestWeight: 102);
    final assessment =
        healthAssessmentFixture(analysis: analysis, bodyScore: 87);
    final before = assessment.toMap();
    await _showWeight(tester, analysis: analysis, assessment: assessment);
    expect(find.text('体重の健康評価'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.text('普段の体重：100g'), findsOneWidget);
    expect(find.text('直近の体重：102g'), findsOneWidget);
    expect(find.text('普段より2g重め'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byType(WeightResearchComparisonCard), 180);
    final bar =
        tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
    expect(bar.value, 100);
    expect(bar.referenceValue, 133);
    expect(bar.referenceStart, 100);
    expect(bar.referenceEnd, 160);
    expect(assessment.toMap(), before);
    expect(tester.takeException(), isNull);
  });

  for (final reason in [
    'reference unavailable',
    'unknown species',
    'age ineligible'
  ]) {
    testWidgets('personal baseline and health retained when $reason',
        (tester) async {
      final analysis = healthAnalysisFixture(
        referenceAvailable: reason != 'reference unavailable',
        species: reason == 'unknown species' ? '未登録の種類' : 'ゴールデン',
        birthdayDateKey:
            reason == 'age ineligible' ? '2026-09-01' : '2026-01-01',
      );
      final assessment =
          healthAssessmentFixture(analysis: analysis, bodyScore: 87);
      await _showWeight(tester, analysis: analysis, assessment: assessment);
      expect(find.text('87'), findsOneWidget);
      expect(find.byKey(const ValueKey('health-weight-individual-analysis')),
          findsOneWidget);
      expect(find.text('普段の体重：100g'), findsOneWidget);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'waiting weight health preserves existing evaluation and omits analysis',
      (tester) async {
    final analysis = healthAnalysisFixture();
    final assessment =
        healthAssessmentFixture(analysis: analysis, bodyScore: null);
    await _showWeight(tester, analysis: analysis, assessment: assessment);
    expect(find.text('記録待ち'), findsWidgets);
    expect(find.text('体重の健康評価は記録待ちです。'), findsOneWidget);
    expect(find.byType(MetricComparisonBar), findsNothing);
    expect(find.byKey(const ValueKey('health-weight-individual-analysis')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning baseline keeps health score and safe explanation',
      (tester) async {
    final analysis = healthAnalysisFixture(bodyReady: false);
    await _showWeight(tester, analysis: analysis);
    expect(find.text('100'), findsOneWidget);
    expect(find.textContaining('普段の体重を学習中'), findsOneWidget);
    expect(find.byType(MetricComparisonBar), findsNothing);
  });

  for (final fallback in [
    'Silver absent',
    'cache only',
    'date mismatch',
    'feature date mismatch',
    'generation mismatch'
  ]) {
    testWidgets(
        '$fallback hides current comparison without changing health result',
        (tester) async {
      final analysis = healthAnalysisFixture();
      final assessment = healthAssessmentFixture(
        analysis: analysis,
        bodyScore: 87,
        dateKey: fallback == 'date mismatch' ? '2026-10-10' : null,
        featureDateKey:
            fallback == 'feature date mismatch' ? '2026-10-10' : null,
        evaluatedAt: fallback == 'generation mismatch'
            ? analysis.features.generatedAt!.add(const Duration(seconds: 1))
            : null,
      );
      await _showWeight(tester,
          analysis: analysis,
          assessment: assessment,
          absent: fallback == 'Silver absent',
          confirmed: fallback != 'cache only');
      expect(find.text('87'), findsOneWidget);
      expect(find.byKey(const ValueKey('health-weight-analysis-fallback')),
          findsOneWidget);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'mismatched saved health opens an explicitly separate current weight route',
      (tester) async {
    final old = healthAnalysisFixture(evaluationDateKey: '2026-10-10');
    final current = healthAnalysisFixture();
    final assessment = healthAssessmentFixture(analysis: old, bodyScore: 87);
    final before = assessment.toMap();
    final source = HealthScreenAnalysisSource(current);
    addTearDown(source.close);
    await _showWeight(tester,
        analysis: current,
        assessment: assessment,
        goldenFont: true,
        currentWeightAnalysisBuilder: (_) => GraphFunctionScreen(
              initialWeightAnalysis: true,
              weightAnalysisSource: source,
              weightRecordsStream:
                  Stream<List<WeightRecord>>.multi((sink) => sink.add([
                        WeightRecord(
                            dayKey: '2026-10-10',
                            date: DateTime(2026, 10, 10),
                            weightGrams: 100,
                            memo: ''),
                      ])),
              switchbotConfigStream:
                  Stream<SwitchbotConfig?>.multi((sink) => sink.add(null)),
              activityRecordsStream:
                  Stream<List<HealthRecord>>.multi((sink) => sink.add([])),
            ));
    expect(find.text('評価日：2026-10-10'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.byType(MetricComparisonBar), findsNothing);
    expect(find.text('健康評価の日時：2026-10-10 11:00 JST'), findsOneWidget);
    expect(find.text('分析日時：2026-10-11 11:00 JST'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-current-weight-analysis-link')), 180);
    await tester
        .tap(find.byKey(const ValueKey('health-current-weight-analysis-link')));
    await tester.pumpAndSettle();
    final screen =
        tester.widget<GraphFunctionScreen>(find.byType(GraphFunctionScreen));
    expect(screen.initialWeightAnalysis, isTrue);
    expect(find.text('現在の体重分析'), findsOneWidget);
    expect(find.text('健康評価とは別の分析です。分析日：2026-10-11'), findsOneWidget);
    expect(find.text('体重の推移'), findsOneWidget);
    expect(find.text('87'), findsNothing);
    await tester.scrollUntilVisible(
        find.byType(WeightResearchComparisonCard), 160);
    final bar =
        tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
    expect(bar.value, 100);
    expect(bar.referenceValue, 133);
    expect(source.reads, 1);
    expect(assessment.toMap(), before);
    Navigator.of(tester.element(find.byType(GraphFunctionScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(HealthWeightDetailScreen), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.byType(MetricComparisonBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-day later generation is labeled separately from health',
      (tester) async {
    final current = healthAnalysisFixture();
    await _showWeight(tester,
        analysis: current,
        assessment: healthAssessmentFixture(
            analysis: current,
            bodyScore: 87,
            evaluatedAt: current.features.generatedAt!
                .subtract(const Duration(minutes: 1))));
    expect(find.text('健康評価の日時：2026-10-11 10:59 JST'), findsOneWidget);
    expect(find.text('分析日時：2026-10-11 11:00 JST'), findsOneWidget);
    expect(find.byKey(const ValueKey('health-current-weight-analysis-link')),
        findsOneWidget);
    expect(find.byType(MetricComparisonBar), findsNothing);
    expect(find.text('87'), findsOneWidget);
  });

  testWidgets('latest CTA clears when its source disappears or owner changes',
      (tester) async {
    final current = healthAnalysisFixture();
    final old = healthAnalysisFixture(evaluationDateKey: '2026-10-10');
    final notifier = await _showWeight(tester,
        analysis: current, assessment: healthAssessmentFixture(analysis: old));
    expect(find.byKey(const ValueKey('health-current-weight-analysis-link')),
        findsOneWidget);
    notifier.value = null;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('health-current-weight-analysis-link')),
        findsNothing);
    notifier.value = current;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('health-current-weight-analysis-link')),
        findsOneWidget);
    notifier.value = healthAnalysisFixture(ownerId: 'another-owner');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('health-current-weight-analysis-link')),
        findsNothing);
    expect(find.byType(MetricComparisonBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final unavailable in [
    'missing Silver',
    'cached health',
    'wrong owner'
  ]) {
    testWidgets('current analysis CTA is withheld for $unavailable',
        (tester) async {
      final current = healthAnalysisFixture();
      final old = healthAnalysisFixture(evaluationDateKey: '2026-10-10');
      await _showWeight(tester,
          analysis: current,
          assessment: healthAssessmentFixture(analysis: old, bodyScore: 87),
          absent: unavailable == 'missing Silver',
          confirmed: unavailable != 'cached health',
          ownerId: unavailable == 'wrong owner'
              ? 'another-owner'
              : 'synthetic-owner');
      expect(find.text('87'), findsOneWidget);
      expect(find.byKey(const ValueKey('health-weight-analysis-fallback')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('health-current-weight-analysis-link')),
          findsNothing);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [true, false]) {
    testWidgets('dated fallback route readable at narrow enlarged $dark theme',
        (tester) async {
      final current = healthAnalysisFixture();
      final old = healthAnalysisFixture(evaluationDateKey: '2026-10-10');
      await _showWeight(tester,
          analysis: current,
          assessment: healthAssessmentFixture(analysis: old, bodyScore: 87),
          dark: dark,
          size: const Size(320, 852),
          textScale: 1.5);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('health-current-weight-analysis-link')),
          160);
      expect(find.text('現在の体重分析を見る'), findsOneWidget);
      expect(find.text('分析日時：2026-10-11 11:00 JST'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('range-outside research value uses real shared bar inputs',
      (tester) async {
    final analysis = healthAnalysisFixture(weight: 220, latestWeight: 220);
    await _showWeight(tester, analysis: analysis);
    await tester.scrollUntilVisible(
        find.byType(WeightResearchComparisonCard), 180);
    final bar =
        tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
    expect(bar.value, 220);
    expect(bar.referenceEnd, 160);
    expect(find.textContaining('正常範囲'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'activity baseline ready never supplies missing evaluation-day record',
      (tester) async {
    final analysis = healthAnalysisFixture(hasActivityRecord: false);
    final notifier = ValueNotifier<CurrentWeightAnalysis?>(analysis);
    addTearDown(notifier.dispose);
    final assessment =
        healthAssessmentFixture(analysis: analysis, activityScore: null);
    await showHealthAnalysisUi(
        tester,
        HealthAssessmentBreakdownScreen(
          assessment: assessment,
          analysisListenable: notifier,
          ownerId: 'synthetic-owner',
          assessmentServerConfirmed: true,
          backgroundBuilder: healthTestBackground,
        ));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-activity-analysis-status')), 240);
    expect(find.text('個体別の基準：準備完了'), findsOneWidget);
    expect(find.text('評価対象日の記録（2026-10-10）：記録待ち'), findsOneWidget);
    expect(find.text('健康評価：記録待ち'), findsOneWidget);
    expect(assessment.domains.activity.score, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'activity learning is separate from existing target-day record and score',
      (tester) async {
    final analysis = healthAnalysisFixture(activityReady: false);
    final notifier = ValueNotifier<CurrentWeightAnalysis?>(analysis);
    addTearDown(notifier.dispose);
    await showHealthAnalysisUi(
        tester,
        HealthAssessmentBreakdownScreen(
          assessment:
              healthAssessmentFixture(analysis: analysis, activityScore: null),
          analysisListenable: notifier,
          ownerId: 'synthetic-owner',
          assessmentServerConfirmed: true,
          backgroundBuilder: healthTestBackground,
        ));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-activity-analysis-status')), 240);
    expect(find.textContaining('個体別の基準：学習中'), findsOneWidget);
    expect(find.text('評価対象日の記録（2026-10-10）：記録あり（628.3m）'), findsOneWidget);
    expect(find.text('健康評価：準備中'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fallback in [
    'Silver absent',
    'cache only',
    'generation mismatch',
    'target date mismatch'
  ]) {
    testWidgets(
        'activity $fallback keeps Gold evaluation with a safe context fallback',
        (tester) async {
      var analysis = healthAnalysisFixture();
      final assessment =
          healthAssessmentFixture(analysis: analysis, activityScore: 87);
      if (fallback == 'target date mismatch') {
        final data = analysis.features.toMap();
        (data['activity'] as Map<String, dynamic>)['sourceDateKey'] =
            '2026-10-09';
        analysis = healthAnalysisWithFeatures(analysis, data);
      }
      final notifier = ValueNotifier<CurrentWeightAnalysis?>(
          fallback == 'Silver absent' ? null : analysis);
      addTearDown(notifier.dispose);
      await showHealthAnalysisUi(
          tester,
          HealthAssessmentBreakdownScreen(
            assessment: fallback == 'generation mismatch'
                ? healthAssessmentFixture(
                    analysis: analysis,
                    activityScore: 87,
                    evaluatedAt: analysis.features.generatedAt!
                        .add(const Duration(seconds: 1)),
                  )
                : assessment,
            analysisListenable: notifier,
            ownerId: 'synthetic-owner',
            assessmentServerConfirmed: fallback != 'cache only',
            backgroundBuilder: healthTestBackground,
          ));
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('health-activity-analysis-fallback')), 160);
      await tester.pumpAndSettle();
      expect(find.textContaining('健康評価は引き続き表示します'), findsOneWidget);
      expect(find.text('87'), findsOneWidget);
      expect(find.text('健康評価：確認できません'), findsNothing);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(assessment.domains.activity.score, 87);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'summary uses compact entry; existing summary to breakdown to weight route remains',
      (tester) async {
    final analysis = healthAnalysisFixture();
    final source = HealthScreenAnalysisSource(analysis);
    addTearDown(source.close);
    final data = healthScreenDataFixture(analysis: analysis);
    await showHealthAnalysisUi(
        tester,
        DailyStatusDetailScreen(
          dataLoader: () async => data,
          weightAnalysisSource: source,
          backgroundBuilder: healthTestBackground,
        ));
    expect(
        tester
            .widget<HealthScoreGauge>(find.byType(HealthScoreGauge).first)
            .score,
        100);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-weight-analysis-entry')), 200);
    expect(find.text('普段の体重：100g'), findsOneWidget);
    expect(find.text('同種の研究参考中央値：133g'), findsOneWidget);
    expect(find.byType(WeightResearchComparisonCard), findsNothing);
    await tester.scrollUntilVisible(find.text('統合評価の内訳'), 160);
    await tester.tap(find.text('統合評価の内訳'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthAssessmentBreakdownScreen), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-weight-detail-link')), 180);
    await tester.tap(find.byKey(const ValueKey('health-weight-detail-link')));
    await tester.pumpAndSettle();
    expect(find.byType(HealthWeightDetailScreen), findsOneWidget);
    expect(find.text('体重の健康評価'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byType(WeightResearchComparisonCard), 180);
    expect(find.byType(MetricComparisonBar), findsOneWidget);
    expect(source.reads, 1);
    expect(data.healthAssessment!.overall.score, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'summary entry opens detail directly and owner/error clear reaches pushed screen',
      (tester) async {
    final analysis = healthAnalysisFixture();
    final source = HealthScreenAnalysisSource(analysis);
    addTearDown(source.close);
    await showHealthAnalysisUi(
        tester,
        DailyStatusDetailScreen(
          dataLoader: () async => healthScreenDataFixture(analysis: analysis),
          weightAnalysisSource: source,
          backgroundBuilder: healthTestBackground,
        ));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-weight-analysis-entry')), 200);
    await tester
        .tap(find.byKey(const ValueKey('health-weight-analysis-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(HealthWeightDetailScreen), findsOneWidget);
    source.emit(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('health-weight-analysis-fallback')),
        findsOneWidget);
    expect(find.byType(MetricComparisonBar), findsNothing);
    source.emit(analysis);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('health-weight-individual-analysis')),
        findsOneWidget);
    source.emitError();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('health-weight-analysis-fallback')),
        findsOneWidget);
    expect(source.reads, 1);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [true, false]) {
    testWidgets(
        'weight detail ${dark ? 'dark' : 'light'} narrow enlarged text stays readable',
        (tester) async {
      await _showWeight(tester,
          dark: dark, size: const Size(320, 852), textScale: 1.5);
      await tester.scrollUntilVisible(
          find.byType(WeightResearchComparisonCard), 160);
      await tester.scrollUntilVisible(find.text('記録の基準・研究の出典'), 160);
      await tester.pumpAndSettle();
      await tester.tap(find.text('記録の基準・研究の出典'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DOI:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
