import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/viewmodels/analysis_progress_view_model.dart';
import 'package:hamster_project/widgets/analysis_progress_card.dart';

List<Map<String, dynamic>> progressStates({
  bool bodyReady = false,
  bool activityReady = false,
  int records = 3,
  int span = 8,
  int requiredRecords = 7,
  int requiredSpan = 14,
}) =>
    [
      for (final id in ['body', 'activity'])
        {
          'metric': id,
          'currentStatus':
              (id == 'body' ? bodyReady : activityReady) ? 'ready' : 'learning',
          'validRecordCount': (id == 'body' ? bodyReady : activityReady)
              ? requiredRecords
              : records,
          'requiredRecordCount': requiredRecords,
          'observationSpanDays':
              (id == 'body' ? bodyReady : activityReady) ? requiredSpan : span,
          'requiredObservationSpanDays': requiredSpan,
        }
    ];

Future<void> showProgress(
  WidgetTester tester,
  List<Map<String, dynamic>> states, {
  double width = 393,
  double scale = 1,
  bool dark = false,
  VoidCallback? onView,
  VoidCallback? onRecord,
  Stream<List<Map<String, dynamic>>>? stream,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AnalysisProgressCard(
          readinessStream: stream ?? Stream.value(states),
          onOpenRecord: onRecord ?? () {},
          onOpenSwitchbot: () => fail('A sensor is not a baseline requirement'),
          onViewAnalysis: onView,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  test('ViewModel formats only server counts and never determines readiness',
      () {
    final view = AnalysisProgressViewModel.fromServer(progressStates(
        records: 9, span: 21, requiredRecords: 9, requiredSpan: 21));
    expect(view.allReady, false);
    expect(view.metrics.first.recordLabel, '記録 9 / 9 件');
    expect(view.metrics.first.spanLabel, '観察期間 21 / 21 日');
    expect(view.metrics.first.recordProgress, 1);
    expect(view.metrics.first.spanProgress, 1);
    final missing = AnalysisProgressViewModel.fromServer([]).metrics.first;
    expect(missing.validRecords, null);
    expect(missing.requiredRecords, null);
    expect(missing.recordProgress, null);
  });

  testWidgets('learning uses short warm copy and independent count/span bars',
      (tester) async {
    await showProgress(tester, progressStates());
    expect(find.text('今は分析に必要な情報を集めているよ！'), findsOneWidget);
    expect(find.text('記録 3 / 7 件'), findsNWidgets(2));
    expect(find.text('観察期間 8 / 14 日'), findsNWidgets(2));
    expect(find.text('毎日連続でなくても大丈夫。'), findsOneWidget);
    expect(find.text('個体別コンディションレポート'), findsNothing);
    expect(find.text('SwitchBotを連携'), findsNothing);
    expect(find.byKey(const ValueKey('analysis-preparation-illustration')),
        findsOneWidget);
    final record = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('body-record-progress')));
    final span = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('body-span-progress')));
    expect(record.value, closeTo(3 / 7, 0.0001));
    expect(span.value, closeTo(8 / 14, 0.0001));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'body ready keeps only activity preparation and unified report CTA',
      (tester) async {
    var views = 0;
    var records = 0;
    await showProgress(tester, progressStates(bodyReady: true),
        onView: () => views++, onRecord: () => records++);
    expect(find.text('分析できるよ'), findsOneWidget);
    expect(find.text('記録 3 / 7 件'), findsOneWidget);
    expect(find.text('観察期間 8 / 14 日'), findsOneWidget);
    expect(find.byKey(const ValueKey('body-record-progress')), findsNothing);
    expect(
        find.byKey(const ValueKey('activity-record-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-preparation-illustration')),
        findsOneWidget);
    expect(find.text('今は分析に必要な情報を集めているよ！'), findsOneWidget);
    await tester.tap(find.text('今日の記録をつける'));
    expect(records, 1);
    await tester.tap(find.text('うちの子レポートを見る'));
    expect(views, 1);
  });

  testWidgets('activity ready also preserves the body preparation',
      (tester) async {
    var views = 0;
    var records = 0;
    await showProgress(tester, progressStates(activityReady: true),
        onView: () => views++, onRecord: () => records++);
    expect(find.byKey(const ValueKey('body-record-progress')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('activity-record-progress')), findsNothing);
    expect(find.text('分析できるよ'), findsOneWidget);
    expect(find.text('記録 3 / 7 件'), findsOneWidget);
    expect(find.text('観察期間 8 / 14 日'), findsOneWidget);
    expect(find.byKey(const ValueKey('analysis-preparation-illustration')),
        findsOneWidget);
    expect(find.text('今は分析に必要な情報を集めているよ！'), findsOneWidget);
    await tester.tap(find.text('今日の記録をつける'));
    expect(records, 1);
    await tester.tap(find.text('うちの子レポートを見る'));
    expect(views, 1);
  });

  testWidgets('all ready becomes compact unified report navigation',
      (tester) async {
    var views = 0;
    await showProgress(
        tester, progressStates(bodyReady: true, activityReady: true),
        onView: () => views++);
    expect(find.text('うちの子レポートを見る'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('analysis-preparation-illustration')),
        findsNothing);
    expect(find.text('今は分析に必要な情報を集めているよ！'), findsNothing);
    expect(find.text('今日の記録をつける'), findsNothing);
    expect(find.text('記録 3 / 7 件'), findsNothing);
    expect(find.text('観察期間 8 / 14 日'), findsNothing);
    await tester.tap(find.text('うちの子レポートを見る'));
    expect(views, 1);
    expect(tester.getSize(find.byType(AnalysisProgressCard)).height,
        lessThan(100));
  });

  testWidgets('existing snapshot can be opened even when current metrics learn',
      (tester) async {
    var views = 0;
    await showProgress(tester, progressStates(), onView: () => views++);
    await tester.tap(find.text('うちの子レポートを見る'));
    expect(views, 1);
  });

  testWidgets('missing readiness never invents 7 or 14 denominators',
      (tester) async {
    await showProgress(tester, [
      {'metric': 'body', 'currentStatus': 'ready'}
    ]);
    expect(find.text('活動量'), findsOneWidget);
    expect(find.text('記録数を確認中'), findsOneWidget);
    expect(find.text('観察期間を確認中'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('/ 7'), findsNothing);
  });

  testWidgets('server-defined thresholds are displayed without local defaults',
      (tester) async {
    await showProgress(
        tester,
        progressStates(
            records: 4, span: 9, requiredRecords: 9, requiredSpan: 21));
    expect(find.text('記録 4 / 9 件'), findsNWidgets(2));
    expect(find.text('観察期間 9 / 21 日'), findsNWidgets(2));
    expect(find.textContaining('/ 14'), findsNothing);
  });

  testWidgets('record CTA keeps the existing record callback', (tester) async {
    var records = 0;
    await showProgress(tester, progressStates(), onRecord: () => records++);
    await tester.tap(find.text('今日の記録をつける'));
    expect(records, 1);
  });

  testWidgets('readiness errors do not render misleading progress',
      (tester) async {
    final errors =
        Stream<List<Map<String, dynamic>>>.error(StateError('fixture'));
    await showProgress(tester, [], stream: errors);
    expect(find.text('今は分析に必要な情報を集めているよ！'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [true, false]) {
    testWidgets(
        'narrow enlarged text ${dark ? 'dark' : 'light'} has no overflow',
        (tester) async {
      await showProgress(tester, progressStates(),
          width: 280, scale: 2, dark: dark, onView: () {});
      expect(tester.takeException(), isNull);
      expect(find.text('体重'), findsOneWidget);
      expect(find.text('活動量'), findsOneWidget);
      await tester.ensureVisible(find.text('今日の記録をつける'));
      await tester.tap(find.text('今日の記録をつける'));
      expect(tester.takeException(), isNull);
    });
  }
}
