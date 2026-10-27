import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'package:hamster_project/services/switchbot_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'current_weight_analysis_test_support.dart';
import 'personality_report_v3_test_support.dart';

Stream<T> _replay<T>(T value) =>
    Stream<T>.multi((sink) => sink.add(value), isBroadcast: true);

class _CurrentAnalysisSource implements WeightAnalysisSource {
  _CurrentAnalysisSource(this.analysis);
  final CurrentWeightAnalysis? analysis;

  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() => _replay(analysis);
}

Future<void> _show(WidgetTester tester,
    {bool initialWeightAnalysis = false, bool currentAnalysis = false}) async {
  tester.view.physicalSize = const Size(393, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dates = List.generate(9, (index) => DateTime(2026, 10, 3 + index));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme.copyWith(
      textTheme: AppTheme.darkTheme.textTheme
          .apply(fontFamily: personalityV3GoldenFont),
    ),
    home: GraphFunctionScreen(
      initialWeightAnalysis: initialWeightAnalysis,
      weightAnalysisSource: _CurrentAnalysisSource(
          currentAnalysis ? currentWeightAnalysisFixture() : null),
      weightRecordsStream: _replay(dates
          .map((date) => WeightRecord(
              dayKey: fixtureDateKey(date),
              date: date,
              weightGrams: 100,
              memo: ''))
          .toList()),
      activityRecordsStream: _replay(dates
          .map((date) => HealthRecord(date: date, distance: 628.3185))
          .toList()),
      switchbotConfigStream: _replay<SwitchbotConfig?>(null),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _latest(String unit) => find.byWidgetPredicate((widget) =>
    widget is Text &&
    (widget.data?.startsWith('最新値  ') ?? false) &&
    (widget.data?.contains(unit) ?? false));

void main() {
  setUpAll(loadPersonalityV3GoldenFonts);

  testWidgets('weight latest footer uses g for each period and keeps the chart',
      (tester) async {
    await _show(tester, initialWeightAnalysis: true);
    for (final period in ['7日', '30日', '全期間']) {
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      expect(_latest('100 g'), findsOneWidget);
      expect(_latest('100 m'), findsNothing);
      expect(find.byType(SfCartesianChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('activity weight activity switches preserve each metric unit',
      (tester) async {
    await _show(tester);
    expect(find.text('最近の変化'), findsOneWidget);
    expect(_latest('628 m'), findsOneWidget);
    await tester.tap(find.text('体重').first);
    await tester.pumpAndSettle();
    expect(_latest('100 g'), findsOneWidget);
    expect(_latest('100 m'), findsNothing);
    await tester.tap(find.text('活動量').first);
    await tester.pumpAndSettle();
    expect(_latest('628 m'), findsOneWidget);
    expect(_latest('628 g'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current weight route is distinct and labels its analysis day',
      (tester) async {
    await _show(tester, initialWeightAnalysis: true, currentAnalysis: true);
    expect(find.text('現在の体重分析'), findsOneWidget);
    expect(find.text('健康評価とは別の分析です。分析日：2026-10-11'), findsOneWidget);
    expect(find.text('体重の推移'), findsOneWidget);
    expect(_latest('100 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'changing metric removes and restores the weight analysis context',
      (tester) async {
    await _show(tester, initialWeightAnalysis: true, currentAnalysis: true);
    await tester.tap(find.text('活動量').first);
    await tester.pumpAndSettle();
    expect(find.text('現在の体重分析'), findsNothing);
    expect(find.textContaining('分析日：'), findsNothing);
    expect(find.text('最近の変化'), findsOneWidget);
    expect(_latest('628 m'), findsOneWidget);
    await tester.tap(find.text('体重').first);
    await tester.pumpAndSettle();
    expect(find.text('現在の体重分析'), findsOneWidget);
    expect(find.text('健康評価とは別の分析です。分析日：2026-10-11'), findsOneWidget);
    expect(_latest('100 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current route with no analysis does not invent an analysis day',
      (tester) async {
    await _show(tester, initialWeightAnalysis: true);
    expect(find.text('現在の体重分析'), findsOneWidget);
    expect(find.text('健康評価とは別に、現在の記録を確認します。'), findsOneWidget);
    expect(find.textContaining('分析日：'), findsNothing);
    expect(_latest('100 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
