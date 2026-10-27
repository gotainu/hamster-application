import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/viewmodels/weight_insights_view_model.dart';
import 'package:hamster_project/widgets/weight_insights_card.dart';
import 'package:intl/intl.dart';

import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';
import 'weight_insights_ui_support.dart';

class _InsightGoldenBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _InsightGoldenBinding();
  final oldLocale = Intl.defaultLocale;
  setUpAll(() async {
    if (Platform.environment['TZ'] != 'Asia/Tokyo') {
      throw StateError('Insight Goldens require TZ=Asia/Tokyo.');
    }
    Intl.defaultLocale = 'ja_JP';
    await loadPersonalityV3GoldenFonts();
  });
  tearDownAll(() => Intl.defaultLocale = oldLocale);

  for (final scenario in [
    (name: 'current_dark', dark: true, width: 393.0, scale: 1.0),
    (name: 'current_light', dark: false, width: 393.0, scale: 1.0),
    (name: 'current_narrow_large', dark: true, width: 320.0, scale: 1.5),
  ]) {
    testWidgets('weight Insights ${scenario.name}', (tester) async {
      await showHealthAnalysisUi(
          tester,
          Scaffold(
              body: Builder(
                  builder: (context) => DecoratedBox(
                        decoration: AppTheme.dataPageDecoration(context),
                        child: ListView(
                            padding: AppTheme.dataPagePadding,
                            children: [
                              Text('体重の記録から',
                                  style: AppTheme.dataTitleStyle(context)),
                              const SizedBox(height: AppTheme.dataSectionGap),
                              WeightInsightsCard(
                                  viewModel:
                                      WeightInsightsViewModel.fromCurrent(
                                          currentInsightsUiFixture())),
                            ]),
                      ))),
          dark: scenario.dark,
          size: Size(scenario.width, 852),
          textScale: scenario.scale,
          golden: true);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile('goldens/weight_insights/${scenario.name}.png'));
    });
  }

  testWidgets('frozen daily report Insight Samsung', (tester) async {
    await showPersonalityV3(tester, reportInsightsUiFixture(),
        goldenFont: true,
        width: 393,
        height: 852,
        topInset: 24,
        bottomInset: 24);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(personalityV3GoldenRoot),
        matchesGoldenFile('goldens/weight_insights/report_snapshot_dark.png'));
  });
}
