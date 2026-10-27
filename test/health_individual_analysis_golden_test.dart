import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/screens/daily_status_detail.dart';
import 'package:hamster_project/widgets/weight_research_comparison_card.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'health_analysis_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';

class _HealthGoldenBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _HealthGoldenBinding();
  final previousLocale = Intl.defaultLocale;
  setUpAll(() async {
    if (Platform.environment['TZ'] != 'Asia/Tokyo') {
      throw StateError('Run health analysis goldens with TZ=Asia/Tokyo.');
    }
    await initializeDateFormatting('ja_JP');
    Intl.defaultLocale = 'ja_JP';
    await loadPersonalityV3GoldenFonts();
  });
  tearDownAll(() {
    Intl.defaultLocale = previousLocale;
  });

  for (final dark in [true, false]) {
    testWidgets('health weight detail ${dark ? 'dark' : 'light'} Samsung',
        (tester) async {
      final analysis = healthAnalysisFixture(latestWeight: 102);
      final notifier = ValueNotifier<CurrentWeightAnalysis?>(analysis);
      addTearDown(notifier.dispose);
      await showHealthAnalysisUi(
          tester,
          HealthWeightDetailScreen(
            assessment:
                healthAssessmentFixture(analysis: analysis, bodyScore: 87),
            analysisListenable: notifier,
            ownerId: 'synthetic-owner',
            assessmentServerConfirmed: true,
            backgroundBuilder: healthTestBackground,
          ),
          dark: dark,
          golden: true);
      final name = dark ? 'dark' : 'light';
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile(
              'goldens/health_analysis/${name}_weight_initial.png'));
      await tester.scrollUntilVisible(
          find.byType(WeightResearchComparisonCard), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile(
              'goldens/health_analysis/${name}_weight_comparison.png'));
    });
  }

  for (final dark in [true, false]) {
    testWidgets('saved health fallback and separate current analysis $dark',
        (tester) async {
      final current = healthAnalysisFixture();
      final notifier = ValueNotifier<CurrentWeightAnalysis?>(current);
      addTearDown(notifier.dispose);
      await showHealthAnalysisUi(
          tester,
          HealthWeightDetailScreen(
            assessment: healthAssessmentFixture(
              analysis: current,
              bodyScore: 87,
              dateKey: '2026-10-10',
              evaluatedAt: DateTime.utc(2026, 10, 10, 2),
            ),
            analysisListenable: notifier,
            ownerId: 'synthetic-owner',
            assessmentServerConfirmed: true,
            backgroundBuilder: healthTestBackground,
          ),
          dark: dark,
          golden: true);
      expect(find.byKey(const ValueKey('health-current-weight-analysis-link')),
          findsOneWidget);
      expect(find.byType(WeightResearchComparisonCard), findsNothing);
      expect(tester.takeException(), isNull);
      final name = dark ? 'dark' : 'light';
      await expectLater(
          find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile(
              'goldens/health_analysis/${name}_dated_fallback.png'));
    });
  }

  testWidgets('summary preserves health hierarchy with compact weight entrance',
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
        ),
        golden: true);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-weight-analysis-entry')), 160);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(healthAnalysisGoldenRoot),
        matchesGoldenFile('goldens/health_analysis/dark_summary_entry.png'));
  });

  testWidgets('breakdown baseline ready and missing evaluated record',
      (tester) async {
    final analysis = healthAnalysisFixture(hasActivityRecord: false);
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
        ),
        golden: true);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-activity-analysis-status')), 160);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
        find.byKey(healthAnalysisGoldenRoot),
        matchesGoldenFile(
            'goldens/health_analysis/dark_activity_record_waiting.png'));
  });
}
