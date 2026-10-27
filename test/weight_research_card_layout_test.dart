import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';
import 'package:hamster_project/widgets/weight_research_comparison_card.dart';

import 'current_weight_analysis_test_support.dart';
import 'personality_report_v3_test_support.dart';

Future<void> _show(WidgetTester tester, CurrentWeightAnalysis analysis,
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
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: WeightResearchComparisonCard(analysis: analysis),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _number(String text) => find.descendant(
    of: find.byType(MetricComparisonBar), matching: find.text(text));

void main() {
  setUpAll(loadPersonalityV3GoldenFonts);

  for (final dark in [true, false]) {
    testWidgets('shared compact card aligns true cohort labels, dark=$dark',
        (tester) async {
      await _show(tester, currentWeightAnalysisFixture(), dark: dark);
      expect(find.byKey(const ValueKey('comparison-positioned-captions')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('comparison-wrapped-captions')),
          findsNothing);
      final left = tester.getTopLeft(_number('100g'));
      final median = tester.getTopLeft(_number('133g'));
      final right = tester.getTopLeft(_number('160g'));
      expect(left.dy, closeTo(median.dy, .01));
      expect(right.dy, closeTo(median.dy, .01));
      expect(left.dx, lessThan(median.dx));
      expect(median.dx, lessThan(right.dx));
      expect(
          tester.getCenter(_number('133g')).dx,
          closeTo(
              tester
                  .getCenter(
                      find.byKey(const ValueKey('comparison-reference-marker')))
                  .dx,
              .01));
      expect(find.text('中央50%の下限'), findsOneWidget);
      expect(find.text('参考中央値'), findsOneWidget);
      expect(find.text('中央50%の上限'), findsOneWidget);
      expect(find.textContaining('健康上の正常範囲ではありません'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final value in [80.0, 133.0, 160.0, 250.0]) {
    testWidgets('card retains real values and safe wrapping for $value',
        (tester) async {
      await _show(tester, currentWeightAnalysisFixture(median: value),
          width: 320, scale: 1.5);
      expect(_number('${value.toInt()}g'), findsWidgets);
      expect(_number('100g'), findsWidgets);
      expect(_number('133g'), findsWidgets);
      expect(_number('160g'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing research and learning never expose compact comparison',
      (tester) async {
    for (final analysis in [
      currentWeightAnalysisFixture(referenceAvailable: false),
      currentWeightAnalysisFixture(ready: false),
    ]) {
      await _show(tester, analysis);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
