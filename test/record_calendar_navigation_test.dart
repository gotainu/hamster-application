// FlutterFire adapters are reused from the existing real-Tabs widget harness.
// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart'
    as fu;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/models/star_rewards_progress.dart';
import 'package:hamster_project/screens/daily_stars.dart';
import 'package:hamster_project/screens/star_collection.dart';
import 'package:hamster_project/screens/tabs.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/care_continuity_panel.dart';
import 'package:hamster_project/widgets/collectible_glyph.dart';
import 'package:hamster_project/widgets/floating_bottom_navigation.dart';
import 'package:hamster_project/widgets/main_drawer.dart';
import 'package:hamster_project/widgets/quick_record_sheet.dart';
import 'package:hamster_project/widgets/record_calendar_action.dart';

import 'care_continuity_test_support.dart';
import 'first_ai_monitoring_cta_test.dart'
    show installRecordCalendarWidgetBackend;
import 'health_individual_analysis_ui_support.dart'
    show showHealthAnalysisUi, healthAnalysisGoldenRoot;
import 'personality_report_v3_test_support.dart'
    show loadPersonalityV3GoldenFonts;

class _CalendarFunctions extends fu.FirebaseFunctionsPlatform {
  _CalendarFunctions() : super(null, 'asia-northeast1');
  final calls = <String>[];
  final continuity = <String, dynamic>{
    'schemaVersion': 1,
    'policyVersion': 'continuity_v1',
    'serverDateKey': '2026-10-14',
    'phase': 'active',
    'todayAchieved': true,
    'periodEarned': 8,
    'lifetimeAchievementDays': 12,
    'periodId': 'calendar-fixture',
    'periodStartedOn': '2026-10-01',
    'lastAchievementDateKey': '2026-10-14',
    'expiresAt': '2026-10-16T15:00:00.000Z',
  };
  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;
  @override
  fu.HttpsCallablePlatform httpsCallable(
      String? origin, String name, fu.HttpsCallableOptions options) {
    expect(name, anyOf('claimDailyOpenStar', 'refreshCareContinuity'));
    return _CalendarCallable(this, origin, name, options);
  }
}

class _CalendarCallable extends fu.HttpsCallablePlatform {
  _CalendarCallable(_CalendarFunctions functions, String? origin, String name,
      fu.HttpsCallableOptions options)
      : super(functions, origin, name, options, null);
  @override
  Future<dynamic> call([dynamic parameters]) async {
    (functions as _CalendarFunctions).calls.add(name!);
    if (name == 'claimDailyOpenStar') return <String, dynamic>{};
    return Map<String, dynamic>.of(
        (functions as _CalendarFunctions).continuity);
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final functions = _CalendarFunctions();
  late ({
    Map<String, Map<String, dynamic>> documents,
    VoidCallback notify,
    Future<void> Function() close
  }) backend;
  setUpAll(() async {
    await loadPersonalityV3GoldenFonts();
    backend = installRecordCalendarWidgetBackend(functions: functions);
  });
  setUp(() {
    functions.calls.clear();
    functions.continuity.addAll({
      'phase': 'active',
      'todayAchieved': true,
      'periodEarned': 8,
      'lifetimeAchievementDays': 12,
      'lastAchievementDateKey': '2026-10-14',
    });
  });
  tearDownAll(() => backend.close());
  testWidgets(
      'calendar AppBar action remains reachable at 280px with large text',
      (tester) async {
    tester.view.physicalSize = const Size(280, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: Scaffold(
          appBar: AppBar(
        title: const Text('今日'),
        actions: [RecordCalendarAction(onPressed: () => taps++)],
      )),
    ));
    await tester.tap(find.byTooltip('記録カレンダー'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(RecordCalendarAction)).width,
        greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'server accepted record is reflected when the same calendar reopens',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    functions.continuity.addAll({
      'phase': 'grace',
      'todayAchieved': false,
      'lastAchievementDateKey': '2026-10-12',
    });
    backend.documents
        .remove('users/onboarding-widget-test/continuity_days/2026-10-14');
    backend.documents['users/onboarding-widget-test/rewards/continuity'] = {
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 14)),
    };
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const TabsScreen()));
    await _frames(tester);
    await tester.tap(find.byTooltip('記録カレンダー'));
    await _frames(tester);
    expect(
        tester
            .widget<CareAchievementHero>(find.byType(CareAchievementHero))
            .state
            .periodEarned,
        8);
    await tester
        .ensureVisible(find.byKey(const ValueKey('care-calendar-today-ring')));
    await _frames(tester);
    final pendingCalendar = tester
        .widget<CareAchievementCalendar>(find.byType(CareAchievementCalendar));
    expect(pendingCalendar.cells.singleWhere((cell) => cell.isToday).achieved,
        isFalse);
    expect(find.byKey(const ValueKey('care-achievement-band-2026-10-14')),
        findsNothing);
    await tester.tap(find.byType(BackButton));
    await _frames(tester);
    // Model a trusted server acknowledgement, not a client reward calculation.
    functions.continuity.addAll({
      'phase': 'active',
      'todayAchieved': true,
      'periodEarned': 9,
      'lifetimeAchievementDays': 13,
      'lastAchievementDateKey': '2026-10-14',
    });
    backend.documents[
        'users/onboarding-widget-test/continuity_days/2026-10-14'] = {
      'achieved': true,
      'periodId': 'calendar-fixture',
      'sourceKind': 'care',
      'sourceDateKey': '2026-10-01',
    };
    backend.documents['users/onboarding-widget-test/rewards/continuity'] = {
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 14, 1)),
    };
    backend.notify();
    await _frames(tester);
    await tester.tap(find.byTooltip('記録カレンダー'));
    await _frames(tester);
    final hero =
        tester.widget<CareAchievementHero>(find.byType(CareAchievementHero));
    expect(hero.state.periodEarned, 9);
    expect(hero.state.todayAchieved, isTrue);
    expect(hero.state.lifetimeAchievementDays, 13);
    await tester
        .ensureVisible(find.byKey(const ValueKey('care-calendar-today-ring')));
    await _frames(tester);
    final acceptedCalendar = tester
        .widget<CareAchievementCalendar>(find.byType(CareAchievementCalendar));
    final today = acceptedCalendar.cells.singleWhere((cell) => cell.isToday);
    final rest = acceptedCalendar.cells
        .singleWhere((cell) => cell.dayKey == '2026-10-13');
    expect(today.achieved, isTrue);
    expect(today.semanticLabel, '2026-10-14、記録保存で達成、今日');
    expect(rest.achieved, isFalse);
    expect(rest.semanticLabel, '2026-10-13、お休み');
    expect(find.byKey(const ValueKey('care-achievement-band-2026-10-14')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('care-achievement-band-2026-10-13')),
        findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
  for (final dark in [false, true]) {
    testWidgets(
        'real AppBar and Drawer open the same calendar and return ($dark)',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      backend.documents['users/onboarding-widget-test/rewards/stars'] = {
        'balance': 11,
        'lifetimeEarned': 20,
      };
      backend.documents['users/onboarding-widget-test/rewards/continuity'] = {
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 14)),
      };
      for (final day in ['2026-10-12', '2026-10-14']) {
        backend.documents['users/onboarding-widget-test/continuity_days/$day'] =
            {
          'achieved': true,
          'periodId': 'calendar-fixture',
          'sourceKind': 'care',
          'sourceDateKey': day,
        };
      }
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: const TabsScreen(),
      ));
      await _frames(tester);
      expect(find.byType(CareContinuityPanel), findsNothing);
      expect(find.text('今日の記録'), findsNothing);
      expect(find.byType(RecordCalendarAction), findsOneWidget);
      expect(find.byTooltip('記録カレンダー'), findsOneWidget);
      final actionSize = tester.getSize(find.byType(RecordCalendarAction));
      expect(actionSize.width, greaterThanOrEqualTo(48));
      expect(actionSize.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byTooltip('記録カレンダー'));
      await _frames(tester);
      expect(find.byType(DailyStarsScreen), findsOneWidget);
      expect(find.text('記録カレンダー'), findsOneWidget);
      expect(find.byType(CareAchievementCalendar), findsOneWidget);
      expect(find.text('2026年10月'), findsOneWidget);
      final appBarDestination =
          tester.widget<DailyStarsScreen>(find.byType(DailyStarsScreen));
      final completion = appBarDestination.completionListenable;
      expect(appBarDestination.onRecord, isNotNull);
      await tester.tap(find.byType(BackButton));
      await _frames(tester);
      expect(find.byType(RecordCalendarAction), findsOneWidget);
      expect(find.byType(DailyStarsScreen), findsNothing);
      Scaffold.of(tester.element(find.byType(RecordCalendarAction)))
          .openDrawer();
      await _frames(tester);
      expect(find.byType(MainDrawer), findsOneWidget);
      expect(find.text('記録カレンダー'), findsOneWidget);
      expect(find.textContaining('の累計'), findsNothing);
      await tester.ensureVisible(find.text('記録カレンダー'));
      await tester.tap(find.text('記録カレンダー'));
      await _frames(tester);
      expect(find.byType(DailyStarsScreen), findsOneWidget);
      expect(find.byType(StarCollectionScreen), findsNothing);
      final drawerDestination =
          tester.widget<DailyStarsScreen>(find.byType(DailyStarsScreen));
      expect(drawerDestination.completionListenable, same(completion));
      await tester.tap(find.byType(BackButton));
      await _frames(tester);
      expect(find.byType(MainDrawer).hitTestable(), findsNothing);
      tester
          .widget<FloatingBottomNavigation>(
              find.byType(FloatingBottomNavigation))
          .onTabSelected(1);
      await _frames(tester);
      expect(find.byType(RecordCalendarAction), findsNothing);
      tester
          .widget<FloatingBottomNavigation>(
              find.byType(FloatingBottomNavigation))
          .onTabSelected(0);
      await _frames(tester);
      await tester.tap(find.byTooltip('記録カレンダー'));
      await _frames(tester);
      await tester.scrollUntilVisible(find.text('今日の記録の内訳'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('今日の記録の内訳'));
      await _frames(tester);
      await tester.ensureVisible(find.text('今日の様子'));
      await _frames(tester);
      await tester.tap(find.text('今日の様子'));
      await _frames(tester);
      expect(find.byType(DailyStarsScreen), findsNothing);
      expect(find.byType(QuickRecordSheet), findsOneWidget);
      expect(functions.calls,
          everyElement(anyOf('claimDailyOpenStar', 'refreshCareContinuity')));
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });
    testWidgets(
        'calendar retains actual days, seed/star and permanent totals ($dark)',
        (tester) async {
      final source = ContinuityTestSource(continuityFixture());
      addTearDown(source.close);
      final completion = ValueNotifier<DailyRecordCompletion?>(
          DailyRecordCompletion(
              wheelCompleted: false,
              conditionCompleted: true,
              latestWeight: null,
              weightReminderDays: 7,
              referenceDate: DateTime(2026, 10, 14)));
      addTearDown(completion.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: DailyStarsScreen(
          completionListenable: completion,
          continuitySource: source,
          rewardsProgressStream: Stream.value(
              const StarRewardsProgress(total: 11, lifetimeEarned: 20)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('記録カレンダー'), findsOneWidget);
      expect(find.byType(CareAchievementCalendar), findsOneWidget);
      expect(find.byType(CollectibleGlyph), findsWidgets);
      expect(
          find.byKey(ValueKey(
              'daily-collectible-background-${dark ? 'night' : 'day'}')),
          findsOneWidget);
      expect(find.text('これまで記録した日'), findsOneWidget);
      expect(find.text('12日'), findsOneWidget);
      final name = dark ? '星' : 'ひまわりの種';
      final unit = dark ? '個' : '粒';
      expect(find.text('これまで集めた$name'), findsOneWidget);
      expect(find.text('保有している$name'), findsOneWidget);
      expect(find.text('20$unit'), findsOneWidget);
      expect(find.text('11$unit'), findsOneWidget);
      expect(source.calendarRequests.last, ('2026-10-01', '2026-10-31'));
      await tester.tap(find.byTooltip('前の月'));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月'), findsOneWidget);
      expect(source.calendarRequests.last, ('2026-09-01', '2026-09-30'));
      await tester.tap(find.byTooltip('次の月'));
      await tester.pumpAndSettle();
      expect(find.text('2026年10月'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final dark in [false, true]) {
    testWidgets('Home and Drawer open the same free main report ($dark)',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: const TabsScreen(),
      ));
      await _frames(tester);
      final mainLink = find.text('うちの子レポートを見る');
      await tester.ensureVisible(mainLink);
      await tester.tap(mainLink);
      await _frames(tester);
      expect(find.byType(PersonalityReportScreen), findsOneWidget);
      expect(find.text('うちの子レポート'), findsOneWidget);
      expect(find.textContaining('無料体験を始める'), findsNothing);
      await tester.pageBack();
      await _frames(tester);
      Scaffold.of(tester.element(find.byType(RecordCalendarAction)))
          .openDrawer();
      await _frames(tester);
      await tester.ensureVisible(find.text('うちの子レポート'));
      await tester.tap(find.text('うちの子レポート'));
      await _frames(tester);
      expect(find.byType(PersonalityReportScreen), findsOneWidget);
      expect(find.text('うちの子レポート'), findsOneWidget);
      expect(find.byType(DailyStarsScreen), findsNothing);
      await tester.pageBack();
      await _frames(tester);
      expect(find.byType(RecordCalendarAction), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });
  }
  for (final dark in [false, true]) {
    for (final drawer in [false, true]) {
      testWidgets('real ${drawer ? 'Drawer' : 'Home'} golden ($dark)',
          (tester) async {
        await showHealthAnalysisUi(tester, const TabsScreen(),
            dark: dark, golden: true, settle: false);
        await _frames(tester);
        final context = tester.element(find.byType(TabsScreen));
        await tester.runAsync(() async {
          for (final asset in [
            'assets/images/theme/bg_default_day.webp',
            'assets/images/theme/bg_default_night.webp',
            AppTheme.analysisPreparationIllustrationAsset,
          ]) {
            await precacheImage(AssetImage(asset), context);
          }
        });
        if (drawer) {
          Scaffold.of(tester.element(find.byType(RecordCalendarAction)))
              .openDrawer();
        }
        await _frames(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
            find.byKey(healthAnalysisGoldenRoot),
            matchesGoldenFile(
                'goldens/record_calendar/${drawer ? 'drawer' : 'home'}_${dark ? 'dark' : 'light'}.png'));
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      }, tags: ['record-calendar-golden']);
    }
  }
}
