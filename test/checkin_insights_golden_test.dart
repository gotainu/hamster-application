import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/viewmodels/checkin_insights_view_model.dart';
import 'package:hamster_project/widgets/insights_card.dart';
import 'checkin_insight_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _Binding();
  setUpAll(() async {
    if (Platform.environment['TZ'] != 'Asia/Tokyo') {
      throw StateError('Golden TZ required');
    }
    await loadPersonalityV3GoldenFonts();
  });
  for (final scenario in [
    (name: 'dark', dark: true, width: 393.0, scale: 1.0),
    (name: 'light', dark: false, width: 393.0, scale: 1.0),
    (name: 'narrow_large', dark: true, width: 320.0, scale: 1.5)
  ]) {
    testWidgets('observation evidence ${scenario.name}', (tester) async {
      await showHealthAnalysisUi(
          tester,
          Scaffold(
              body: Builder(
                  builder: (context) => DecoratedBox(
                      decoration: AppTheme.dataPageDecoration(context),
                      child: ListView(
                          padding: AppTheme.dataPagePadding,
                          children: [
                            InsightsCard(
                                title: '今日の様子の記録から',
                                evaluationDateKey: '2026-10-11',
                                items: CheckinInsightsViewModel.fromCurrent(
                                        checkinCurrentFixture())
                                    .items),
                          ])))),
          dark: scenario.dark,
          size: Size(scenario.width, 852),
          textScale: scenario.scale,
          golden: true);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile('goldens/checkin_insights/${scenario.name}.png'));
    });
  }
}
