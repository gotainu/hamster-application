import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/daily_health_features.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'package:hamster_project/services/switchbot_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';
import 'package:hamster_project/widgets/weight_research_comparison_card.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'current_weight_analysis_test_support.dart';
import 'personality_report_v3_test_support.dart';

class _SingleSubscriptionSource implements WeightAnalysisSource {
  _SingleSubscriptionSource(CurrentWeightAnalysis analysis) {
    controller.add(analysis);
  }
  final controller = StreamController<CurrentWeightAnalysis?>();
  int subscriptions = 0;
  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() {
    subscriptions++;
    return controller.stream;
  }
}

class _CurrentSource implements WeightAnalysisSource {
  _CurrentSource(this.current);
  CurrentWeightAnalysis? current;
  int subscriptions = 0;
  final changes =
      StreamController<CurrentWeightAnalysis?>.broadcast(sync: true);

  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() {
    subscriptions++;
    return Stream.multi((sink) {
      sink.add(current);
      final subscription =
          changes.stream.listen(sink.add, onError: sink.addError);
      sink.onCancel = subscription.cancel;
    });
  }

  void emit(CurrentWeightAnalysis? value) {
    current = value;
    changes.add(value);
  }

  Future<void> close() => changes.close();
}

CurrentWeightAnalysis _analysis({
  bool reference = true,
  bool ready = true,
  String species = 'ゴールデン',
  String? birthday = '2026-01-01',
  double median = 100,
}) {
  final base = currentWeightAnalysisFixture();
  final map = base.features.toMap();
  final body = map['body'] as Map<String, dynamic>;
  final baseline = body['personalBaseline'] as Map<String, dynamic>;
  baseline['median'] = median;
  if (!ready) baseline['status'] = 'learning';
  return CurrentWeightAnalysis(
    ownerId: base.ownerId,
    evaluationDateKey: base.evaluationDateKey,
    features: DailyHealthFeatures.fromMap(map,
        fallbackDateKey: base.evaluationDateKey),
    profile:
        CurrentWeightProfile(rawSpecies: species, birthdayDateKey: birthday),
    reference: reference ? base.reference : null,
  );
}

List<WeightRecord> _records() => [
      '2026-09-01',
      '2026-09-10',
      '2026-09-11',
      '2026-10-01',
      '2026-10-03',
      '2026-10-04',
      '2026-10-07',
      '2026-10-09',
      '2026-10-10',
      '2026-10-11',
    ]
        .asMap()
        .entries
        .map((entry) => WeightRecord(
              dayKey: entry.value,
              date: DateTime.parse(entry.value),
              weightGrams: 99 + entry.key.toDouble(),
              memo: '',
            ))
        .toList();

Future<_CurrentSource> _show(
    WidgetTester tester, CurrentWeightAnalysis? analysis,
    {bool dark = true, double width = 393, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _CurrentSource(analysis);
  addTearDown(source.close);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  theme = theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: personalityV3GoldenFont),
    primaryTextTheme:
        theme.primaryTextTheme.apply(fontFamily: personalityV3GoldenFont),
  );
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: GraphFunctionScreen(
      weightAnalysisSource: source,
      weightRecordsStream: Stream.multi((sink) => sink.add(_records())),
      switchbotConfigStream:
          Stream<SwitchbotConfig?>.multi((sink) => sink.add(null)),
      activityRecordsStream:
          Stream<List<HealthRecord>>.multi((sink) => sink.add(const [])),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('体重'));
  await tester.pumpAndSettle();
  return source;
}

SfCartesianChart _chart(WidgetTester tester) =>
    tester.widget<SfCartesianChart>(find.byType(SfCartesianChart));

void main() {
  setUpAll(loadPersonalityV3GoldenFonts);
  testWidgets(
      'current eligible Silver is supplemental to the unchanged weight chart',
      (tester) async {
    final source = await _show(tester, _analysis());
    expect(find.byType(WeightResearchComparisonCard), findsOneWidget);
    final comparison =
        tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
    expect(comparison.value, 100);
    expect(comparison.referenceValue, 133);
    expect(comparison.referenceStart, 100);
    expect(comparison.referenceEnd, 160);
    expect(find.text('体重の推移'), findsOneWidget);
    final chart = _chart(tester);
    expect(chart.series, hasLength(3));
    expect(chart.series.first, isA<LineSeries>());
    expect(chart.series[1], isA<SplineSeries>());
    expect(chart.series.last, isA<ScatterSeries>());
    expect(chart.series.first.dataSource, hasLength(5));
    final axis = chart.primaryXAxis as DateTimeAxis;
    expect(axis.minimum, DateTime(2026, 10, 5));
    expect(axis.maximum, DateTime(2026, 10, 13));
    expect(source.subscriptions, 1);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in <String, CurrentWeightAnalysis?>{
    'current analysis unavailable': null,
    'reference unavailable': _analysis(reference: false),
    'unknown species': _analysis(species: '不明な種類'),
    'unknown age': _analysis(birthday: null),
    'juvenile': _analysis(birthday: '2026-09-01'),
    'learning baseline': _analysis(ready: false),
  }.entries) {
    testWidgets('${scenario.key} omits comparison while keeping chart',
        (tester) async {
      await _show(tester, scenario.value);
      expect(find.byType(WeightResearchComparisonCard), findsNothing);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(find.text('体重の推移'), findsOneWidget);
      expect(_chart(tester).series, hasLength(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      '7/30/all switches chart data and keeps current analysis unchanged',
      (tester) async {
    final source = await _show(tester, _analysis());
    for (final period in [
      (label: '7日', count: 5),
      (label: '30日', count: 8),
      (label: '全期間', count: 10)
    ]) {
      await tester.tap(find.text(period.label));
      await tester.pumpAndSettle();
      final chart = _chart(tester);
      expect(chart.series.first.dataSource, hasLength(period.count));
      expect(chart.series[1].dataSource, hasLength(period.count));
      expect(chart.series, hasLength(3));
      final comparison =
          tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
      expect(comparison.value, 100);
      expect(comparison.referenceValue, 133);
      expect(source.subscriptions, 1);
    }
    expect(find.text('24時間'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching 24 hour activity to weight retains 30 day fallback',
      (tester) async {
    await _show(tester, _analysis());
    await tester.tap(find.text('活動量'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24時間'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('体重'));
    await tester.pumpAndSettle();
    expect(_chart(tester).series.first.dataSource, hasLength(8));
    expect(find.text('24時間'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight activity weight retains one single-subscription analysis',
      (tester) async {
    await _show(tester, _analysis());
    final source = _SingleSubscriptionSource(_analysis());
    addTearDown(source.controller.close);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme.copyWith(
            textTheme: AppTheme.darkTheme.textTheme
                .apply(fontFamily: personalityV3GoldenFont)),
        home: GraphFunctionScreen(
            weightAnalysisSource: source,
            weightRecordsStream: Stream.multi((sink) => sink.add(_records())),
            switchbotConfigStream:
                Stream<SwitchbotConfig?>.multi((sink) => sink.add(null)),
            activityRecordsStream: Stream<List<HealthRecord>>.multi(
                (sink) => sink.add(const [])))));
    await tester.pumpAndSettle();
    for (final label in ['体重', '活動量', '体重']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }
    expect(source.subscriptions, 1);
    expect(find.byType(MetricComparisonBar), findsOneWidget);
    expect(find.byType(SfCartesianChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'replacing analysis source does not keep previous owner comparison',
      (tester) async {
    final old = await _show(tester, _analysis());
    final current = _CurrentSource(_analysis(median: 145));
    addTearDown(current.close);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme.copyWith(
            textTheme: AppTheme.darkTheme.textTheme
                .apply(fontFamily: personalityV3GoldenFont)),
        home: GraphFunctionScreen(
            weightAnalysisSource: current,
            weightRecordsStream: Stream.multi((sink) => sink.add(_records())),
            switchbotConfigStream:
                Stream<SwitchbotConfig?>.multi((sink) => sink.add(null)),
            activityRecordsStream: Stream<List<HealthRecord>>.multi(
                (sink) => sink.add(const [])))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MetricComparisonBar>(find.byType(MetricComparisonBar))
            .value,
        145);
    old.emit(_analysis(median: 20));
    old.changes.addError(StateError('old cancelled source'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MetricComparisonBar>(find.byType(MetricComparisonBar))
            .value,
        145);
    expect(current.subscriptions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed/cleared current analysis removes previous comparison',
      (tester) async {
    final source = await _show(tester, _analysis());
    source.changes.addError(StateError('synthetic read failure'));
    await tester.pumpAndSettle();
    expect(find.byType(MetricComparisonBar), findsNothing);
    source.emit(_analysis());
    await tester.pumpAndSettle();
    expect(find.byType(MetricComparisonBar), findsOneWidget);
    source.emit(null);
    await tester.pumpAndSettle();
    expect(find.byType(MetricComparisonBar), findsNothing);
    expect(find.byType(SfCartesianChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final median in [20.0, 250.0]) {
    testWidgets('reference outlier $median remains a numeric comparison',
        (tester) async {
      await _show(tester, _analysis(median: median));
      final bar =
          tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
      expect(bar.value, median);
      expect(bar.referenceStart, 100);
      expect(bar.referenceEnd, 160);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'shared comparison supports narrow enlarged text without changing the graph',
      (tester) async {
    tester.view.physicalSize = const Size(320, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = AppTheme.darkTheme.copyWith(
        textTheme: AppTheme.darkTheme.textTheme
            .apply(fontFamily: personalityV3GoldenFont));
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: SingleChildScrollView(
                    child: WeightResearchComparisonCard(
                        analysis: _analysis()))))));
    await tester.pumpAndSettle();
    expect(find.byType(MetricComparisonBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
