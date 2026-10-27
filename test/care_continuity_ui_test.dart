import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/care_continuity.dart';
import 'package:hamster_project/models/daily_star_progress.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/screens/daily_stars.dart';
import 'package:hamster_project/models/star_rewards_progress.dart';
import 'package:hamster_project/viewmodels/care_continuity_view_model.dart';
import 'package:hamster_project/widgets/care_continuity_panel.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';
import 'care_continuity_test_support.dart';
import 'care_action_test_support.dart';
import 'health_individual_analysis_ui_support.dart';

const _progress = DailyStarProgress([
  DailyStarSlot(kind: DailyStarSlotKind.openApp, label: 'アプリを開く', filled: true),
  DailyStarSlot(
      kind: DailyStarSlotKind.wheel, label: '昨日の走った記録', filled: false),
  DailyStarSlot(kind: DailyStarSlotKind.condition, label: '今日の様子', filled: true)
]);
void main() {
  test('server phase is displayed without client-clock expiry decisions', () {
    final vm = CareContinuityViewModel(
        continuityFixture(phase: CareContinuityPhase.grace, achieved: false));
    expect(vm.achievementLabel, '今日の記録はこれから');
    expect(vm.graceDeadline, '10月14日 23:59まで（日本時間）');
    expect(vm.guidance, '今日の記録でキープ');
    expect(
        CareContinuityViewModel(continuityFixture(
                phase: CareContinuityPhase.expired, earned: 0, achieved: false))
            .guidance,
        'たくわえが空になりました');
  });
  test('calendar counts server accepted day, not backdated source day or grace',
      () {
    final vm = CareContinuityViewModel(
        continuityFixture(phase: CareContinuityPhase.grace, achieved: false));
    final cells = vm.cells([
      const CareContinuityDay(
          dayKey: '2026-10-12', achieved: true, sourceDateKey: '2026-10-01')
    ]);
    expect(cells.where((c) => c.achieved).map((c) => c.dayKey), ['2026-10-12']);
    expect(
        cells.singleWhere((c) => c.dayKey == '2026-10-13').achieved, isFalse);
    expect(cells.last.isToday, isTrue);
  });
  for (final phase in CareContinuityPhase.values) {
    testWidgets('continuity ${phase.name} uses existing 3 slots',
        (tester) async {
      final source = ContinuityTestSource(continuityFixture(
          phase: phase,
          achieved: phase == CareContinuityPhase.active,
          earned: phase == CareContinuityPhase.expired ? 0 : 8));
      addTearDown(source.close);
      await showHealthAnalysisUi(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: CareContinuityPanel(
                      source: source, progress: _progress))));
      expect(find.text('たくわえ'), findsOneWidget);
      expect(find.byType(DailyStarsStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (phase == CareContinuityPhase.expired) {
        expect(find.text('たくわえが空になりました'), findsOneWidget);
      }
      if (phase == CareContinuityPhase.grace) {
        expect(find.text('今日の記録でキープ'), findsOneWidget);
      }
    });
  }
  testWidgets(
      'grace fixture has only open-app slot filled and no achieved today cell',
      (tester) async {
    final source = ContinuityTestSource(
        continuityFixture(phase: CareContinuityPhase.grace, achieved: false));
    addTearDown(source.close);
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: CareContinuityPanel(
                    source: source,
                    progress: continuityGraceProgressFixture,
                    showCalendar: true))));
    expect(
        find.descendant(
            of: find.byType(DailyStarsStrip),
            matching: find.byIcon(Icons.star_rounded)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(DailyStarsStrip),
            matching: find.byIcon(Icons.star_border_rounded)),
        findsNWidgets(2));
    final cells =
        CareContinuityViewModel(source.state).cells(await source.calendar());
    expect(cells.last.achieved, isFalse);
    expect(cells.last.isToday, isTrue);
    expect(
        continuityGraceProgressFixture.slots
            .singleWhere((s) => s.kind == DailyStarSlotKind.condition)
            .filled,
        isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('record and details callbacks stay in existing navigation',
      (tester) async {
    final source = ContinuityTestSource(continuityFixture(achieved: false));
    addTearDown(source.close);
    var records = 0, details = 0;
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: CareContinuityPanel(
                source: source,
                progress: _progress,
                onRecord: () => records++,
                onOpenDetails: () => details++)));
    await tester.tap(find.text('今日の記録を残す'));
    await tester.tap(find.text('カレンダー'));
    expect(records, 1);
    expect(details, 1);
  });
  testWidgets('calendar semantics distinguish real recorded and rest days',
      (tester) async {
    final source = ContinuityTestSource(continuityFixture());
    addTearDown(source.close);
    final semantics = tester.ensureSemantics();

    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: CareContinuityPanel(
                    source: source, progress: _progress, showCalendar: true))));
    expect(find.bySemanticsLabel('2026-10-12、記録保存で達成'), findsOneWidget);
    expect(find.bySemanticsLabel('2026-10-13、お休み'), findsOneWidget);
    await tester.ensureVisible(find.text('これまで記録した日'));
    expect(find.text('12日'), findsOneWidget);
    expect(find.textContaining('恒久残高'), findsNothing);
    expect(find.textContaining('サーバーで保存'), findsNothing);
    semantics.dispose();
  });
  testWidgets('pending server reconciliation never confirms expiry or balance',
      (tester) async {
    final source = ContinuityTestSource(continuityFixture(
        phase: CareContinuityPhase.expired,
        achieved: false,
        earned: 0,
        confirmationPending: true));
    addTearDown(source.close);
    await showHealthAnalysisUi(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: CareContinuityPanel(
                    source: source,
                    progress: _progress,
                    showCalendar: true,
                    onRecord: () {}))));
    expect(find.text('報酬は再確認待ちです。記録は保存されています。'), findsOneWidget);
    expect(find.text('たくわえが空になりました'), findsNothing);
    expect(find.textContaining('今日の記録：'), findsNothing);
    expect(find.text('0 スター'), findsNothing);
    expect(find.text('今日の記録を残す'), findsNothing);
    await tester.tap(find.text('状態を再確認'));
    await tester.pumpAndSettle();
    expect(source.refreshes, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reward-only retry never saves care or health again',
      (tester) async {
    final health = CareHealthTestStore(),
        care = CareTestStore()..rewardStatus = 'failed';
    final source = ContinuityTestSource(continuityFixture());
    addTearDown(source.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: DailyConditionInputCard(
                    repo: health, careRepo: care, continuitySource: source)))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('care-cageCleaning-none')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('この内容で記録'));
    await tester.tap(find.text('この内容で記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('報酬だけ再確認する'));
    await tester.pumpAndSettle();
    expect(source.retries, 1);
    expect(care.saved.length, 1);
    expect(health.saves, 0);
    expect(find.text('保存済みのケア記録の報酬を確認しました。'), findsOneWidget);
  });
  testWidgets(
      'reward-only retry remains provisional while outbox reconciliation is pending',
      (tester) async {
    final health = CareHealthTestStore(),
        care = CareTestStore()..rewardStatus = 'failed';
    final source = ContinuityTestSource(continuityFixture())
      ..rewardPending = true;
    addTearDown(source.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: DailyConditionInputCard(
                    repo: health, careRepo: care, continuitySource: source)))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('care-cageCleaning-none')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('この内容で記録'));
    await tester.tap(find.text('この内容で記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('報酬だけ再確認する'));
    await tester.pumpAndSettle();
    expect(find.text('ケア記録は保存済みです。報酬は再確認待ちです。'), findsOneWidget);
    expect(find.text('報酬だけ再確認する'), findsOneWidget);
    expect(care.saved.length, 1);
    expect(health.saves, 0);
  });
  testWidgets('new achievement feedback is brief and never forces navigation',
      (tester) async {
    final health = CareHealthTestStore(),
        care = CareTestStore()
          ..rewardStatus = 'processed'
          ..achievementRecorded = true;
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('care-cageCleaning-none')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('この内容で記録'));
    await tester.tap(find.text('この内容で記録'));
    await tester.pumpAndSettle();
    expect(find.text('ケア記録を保存しました。今日の継続達成を記録しました。'), findsOneWidget);
    expect(find.byType(DailyConditionInputCard), findsOneWidget);
    expect(health.saves, 0);
  });
  testWidgets(
      'daily detail screen reuses continuity without adding another slot',
      (tester) async {
    final source = ContinuityTestSource(continuityFixture());
    addTearDown(source.close);
    final completion = ValueNotifier<DailyRecordCompletion?>(
        DailyRecordCompletion(
            conditionCompleted: true,
            wheelCompleted: false,
            latestWeight: null,
            weightReminderDays: 7,
            referenceDate: DateTime(2026, 10, 14)));
    addTearDown(completion.dispose);
    await showHealthAnalysisUi(
        tester,
        DailyStarsScreen(
            completionListenable: completion,
            continuitySource: source,
            rewardsProgressStream: Stream.value(
                const StarRewardsProgress(total: 11, lifetimeEarned: 20))),
        size: const Size(320, 852),
        textScale: 1.5);
    expect(tester.takeException(), isNull);
    expect(find.byType(CareContinuityPanel), findsOneWidget);
    expect(find.byType(DailyStarsStrip), findsOneWidget);
  });
  testWidgets('reduced-motion setting suppresses existing star animation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: DailyStarsStrip(progress: _progress)))));
    final animations = tester.widgetList<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>));
    expect(animations.length, 3);
    expect(animations.every((a) => a.duration == Duration.zero), isTrue);
  });
}
