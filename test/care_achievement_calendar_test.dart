import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/care_continuity.dart';
import 'package:hamster_project/models/daily_star_progress.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/viewmodels/care_continuity_view_model.dart';
import 'package:hamster_project/widgets/care_continuity_panel.dart';
import 'care_continuity_test_support.dart';
import 'health_individual_analysis_ui_support.dart';

List<CareContinuityDay> recorded(List<int> days,
        {String period = 'p', String month = '2026-10'}) =>
    days
        .map((day) => CareContinuityDay(
            dayKey: '$month-${day.toString().padLeft(2, '0')}',
            achieved: true,
            periodId: period))
        .toList();
const progress = DailyStarProgress([
  DailyStarSlot(kind: DailyStarSlotKind.openApp, label: 'アプリを開く', filled: true),
  DailyStarSlot(
      kind: DailyStarSlotKind.wheel, label: '昨日の走った記録', filled: false),
  DailyStarSlot(kind: DailyStarSlotKind.condition, label: '今日の様子', filled: true)
]);
void main() {
  test('one day has two rounded ends, no derived streak/grace achievement', () {
    final vm = CareContinuityViewModel(
        continuityFixture(phase: CareContinuityPhase.grace, achieved: false));
    final cells = vm.monthCells(recorded([12]));
    final achieved = cells.where((cell) => cell.achieved).single;
    expect(achieved.day, 12);
    expect(achieved.connectedBefore, false);
    expect(achieved.connectedAfter, false);
    expect(cells.singleWhere((cell) => cell.isToday).achieved, false);
    expect(cells.singleWhere((cell) => cell.isToday).semanticLabel,
        contains('未達成、今日'));
  });
  test(
      'multi-week bands only round row edges, Monday header and month edges correct',
      () {
    final cells = CareContinuityViewModel(continuityFixture())
        .monthCells(recorded(List.generate(14, (i) => i + 1)));
    expect(cells.length, 35);
    expect(cells.first.dayKey, '2026-09-28');
    expect(cells.first.outsideMonth, true);
    final byDate = {for (final cell in cells) cell.dayKey: cell};
    expect(byDate['2026-10-01']!.connectedBefore, false);
    expect(byDate['2026-10-02']!.connectedBefore, true);
    expect(byDate['2026-10-02']!.connectedAfter, true);
    expect(byDate['2026-10-04']!.connectedAfter, false);
    expect(byDate['2026-10-05']!.connectedBefore, false);
    expect(byDate['2026-10-14']!.connectedAfter, false);
  });
  test('rest/gap is never joined; grace return retains real days only', () {
    final cells = CareContinuityViewModel(continuityFixture())
        .monthCells(recorded([11, 12, 14]));
    final byDate = {for (final cell in cells) cell.dayKey: cell};
    expect(byDate['2026-10-12']!.connectedAfter, false);
    expect(byDate['2026-10-13']!.achieved, false);
    expect(byDate['2026-10-14']!.connectedBefore, false);
    expect(cells.where((cell) => cell.achieved).length, 3);
  });
  test('different period and month/week edge cannot visually join', () {
    final vm = CareContinuityViewModel(continuityFixture());
    final cells = vm.monthCells([
      ...recorded([12], period: 'old'),
      ...recorded([13, 14], period: 'new')
    ]);
    expect(
        cells.singleWhere((cell) => cell.dayKey == '2026-10-12').connectedAfter,
        false);
    final week =
        CareContinuityViewModel(continuityFixture(serverDateKey: '2026-10-03'))
            .weekCells([
      ...recorded([30], month: '2026-09'),
      ...recorded([1, 2, 3])
    ]);
    expect(
        week.singleWhere((cell) => cell.dayKey == '2026-09-30').connectedAfter,
        false);
    expect(
        week.singleWhere((cell) => cell.dayKey == '2026-10-01').connectedBefore,
        false);
  });
  test('future and adjacent-month data cannot become an actual achieved day',
      () {
    final cells = CareContinuityViewModel(continuityFixture()).monthCells([
      ...recorded([14, 15]),
      ...recorded([30], month: '2026-09')
    ]);
    expect(cells.where((cell) => cell.achieved).map((cell) => cell.dayKey),
        ['2026-10-14']);
    expect(cells.singleWhere((cell) => cell.dayKey == '2026-10-15').isFuture,
        true);
  });
  testWidgets(
      'Home uses exact seven day read; monthly navigation reads only displayed month',
      (tester) async {
    final source = ContinuityTestSource(continuityFixture());
    addTearDown(source.close);
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child:
                    CareContinuityPanel(source: source, progress: progress))));
    expect(source.calendarRequests.last, ('2026-10-08', '2026-10-14'));
    expect(find.text('直近7日'), findsOneWidget);
    expect(find.byType(CareAchievementCalendar), findsOneWidget);
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: CareContinuityPanel(
                    key: const ValueKey('month'),
                    source: source,
                    progress: progress,
                    showCalendar: true))));
    expect(source.calendarRequests.last, ('2026-10-01', '2026-10-31'));
    await tester.tap(find.byTooltip('前の月'));
    await tester.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget);
    expect(source.calendarRequests.last, ('2026-09-01', '2026-09-30'));
    await tester.tap(find.byTooltip('次の月'));
    await tester.pumpAndSettle();
    expect(find.text('2026年10月'), findsOneWidget);
  });
  testWidgets(
      'shape and semantics distinguish a band, rest and unachieved today',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final source = ContinuityTestSource(continuityFixture(achieved: false))
      ..recordedDays = recorded([9, 10]);
    addTearDown(source.close);
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: CareContinuityPanel(
                    source: source, progress: progress, showCalendar: true))));
    expect(find.bySemanticsLabel('2026-10-10、記録保存で達成'), findsOneWidget);
    expect(find.bySemanticsLabel('2026-10-13、お休み'), findsOneWidget);
    expect(find.bySemanticsLabel('2026-10-14、未達成、今日'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('care-calendar-today-ring')), findsOneWidget);
    expect(find.byKey(const ValueKey('care-achievement-band-2026-10-14')),
        findsNothing);
    final band = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('care-achievement-band-2026-10-10')));
    final radius =
        (band.decoration as BoxDecoration).borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 0);
    expect(radius.topRight.x, AppTheme.careCalendarBandRadius);
    semantics.dispose();
  });
  for (final dark in [true, false]) {
    testWidgets(
        'large actual balance keeps complete semantics at narrow expanded text (${dark ? 'dark' : 'light'})',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final source = ContinuityTestSource(continuityFixture(earned: 12345678));
      addTearDown(source.close);
      await showHealthAnalysisUi(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: CareContinuityPanel(
                      source: source, progress: progress, showCalendar: true))),
          dark: dark,
          size: const Size(280, 852),
          textScale: 2);
      expect(find.bySemanticsLabel('現在のたくわえ 12345678${dark ? '個' : '粒'}'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
