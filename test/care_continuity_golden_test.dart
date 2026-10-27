import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/care_continuity.dart';
import 'package:hamster_project/models/daily_star_progress.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/screens/daily_stars.dart';
import 'package:hamster_project/models/star_rewards_progress.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/care_continuity_panel.dart';
import 'care_continuity_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _audit = '/private/tmp/hamcare-calendar-nav-20261012-9s3iqeaz/ui';
List<CareContinuityDay> _days(List<int> days,
        {String period = 'fixture-period'}) =>
    days
        .map((day) => CareContinuityDay(
            dayKey: '2026-10-${day.toString().padLeft(2, '0')}',
            achieved: true,
            periodId: period))
        .toList();
void main() {
  _Binding();
  setUpAll(loadPersonalityV3GoldenFonts);
  final cases = [
    (
      name: 'dark_active',
      dark: true,
      phase: CareContinuityPhase.active,
      width: 393.0,
      scale: 1.0,
      earned: 8,
      days: [10, 11, 12, 13, 14],
      today: true,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'light_grace',
      dark: false,
      phase: CareContinuityPhase.grace,
      width: 393.0,
      scale: 1.0,
      earned: 8,
      days: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      today: false,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'dark_expired',
      dark: true,
      phase: CareContinuityPhase.expired,
      width: 393.0,
      scale: 1.0,
      earned: 0,
      days: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      today: false,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'narrow_large',
      dark: true,
      phase: CareContinuityPhase.active,
      width: 280.0,
      scale: 2.0,
      earned: 12345678,
      days: [12, 13, 14],
      today: true,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'single_day',
      dark: false,
      phase: CareContinuityPhase.active,
      width: 393.0,
      scale: 1.0,
      earned: 1,
      days: [14],
      today: true,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'long_continuation',
      dark: true,
      phase: CareContinuityPhase.active,
      width: 393.0,
      scale: 1.0,
      earned: 60,
      days: List.generate(26, (i) => i + 1),
      today: true,
      serverDay: '2026-10-26',
      home: false
    ),
    (
      name: 'rest_days',
      dark: true,
      phase: CareContinuityPhase.active,
      width: 393.0,
      scale: 1.0,
      earned: 8,
      days: [1, 2, 3, 5, 6, 8, 10, 11, 12, 14],
      today: true,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'grace_return',
      dark: false,
      phase: CareContinuityPhase.active,
      width: 393.0,
      scale: 1.0,
      earned: 8,
      days: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14],
      today: true,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'restart',
      dark: true,
      phase: CareContinuityPhase.active,
      width: 393.0,
      scale: 1.0,
      earned: 1,
      days: [1, 2, 3, 4, 5, 6, 7, 8, 14],
      today: true,
      serverDay: '2026-10-14',
      home: false
    ),
    (
      name: 'home_compact',
      dark: true,
      phase: CareContinuityPhase.active,
      width: 393.0,
      scale: 1.0,
      earned: 8,
      days: [10, 11, 12, 13, 14],
      today: true,
      serverDay: '2026-10-14',
      home: true
    ),
  ];
  for (final fixture in cases) {
    testWidgets('continuity ${fixture.name}', (tester) async {
      final source = ContinuityTestSource(continuityFixture(
          phase: fixture.phase,
          achieved: fixture.today,
          earned: fixture.earned,
          serverDateKey: fixture.serverDay,
          lifetimeAchievementDays: fixture.days.length))
        ..recordedDays = _days(fixture.days);
      if (fixture.name == 'restart') {
        source.recordedDays = [
          ..._days(fixture.days.where((d) => d < 14).toList(),
              period: 'expired-period'),
          ..._days([14], period: 'new-period')
        ];
      }
      addTearDown(source.close);
      final completion = ValueNotifier<DailyRecordCompletion?>(
          DailyRecordCompletion(
              conditionCompleted: fixture.today,
              wheelCompleted: false,
              latestWeight: null,
              weightReminderDays: 7,
              referenceDate: DateTime.parse(fixture.serverDay)));
      addTearDown(completion.dispose);
      final screen = fixture.home
          ? Scaffold(
              appBar: AppBar(title: const Text('今日')),
              body: Builder(
                  builder: (context) => DecoratedBox(
                      decoration: AppTheme.dataPageDecoration(context),
                      child: ListView(
                          padding: AppTheme.careHomePadding,
                          children: [
                            CareContinuityPanel(
                                source: source,
                                progress: DailyStarProgress.fromCompletion(
                                    completion.value!),
                                onOpenDetails: () {},
                                onRecord: () {})
                          ]))))
          : DailyStarsScreen(
              completionListenable: completion,
              continuitySource: source,
              rewardsProgressStream: Stream.value(
                  const StarRewardsProgress(total: 11, lifetimeEarned: 20)),
              onRecord: () async {});
      await showHealthAnalysisUi(tester, screen,
          dark: fixture.dark,
          size: Size(fixture.width, 852),
          textScale: fixture.scale,
          golden: true);
      await tester.runAsync(() async {
        final context = tester.element(
            find.byType(DailyStarsScreen).evaluate().isNotEmpty
                ? find.byType(DailyStarsScreen)
                : find.byType(Scaffold).first);
        if (!fixture.home) {
          await precacheImage(
              AssetImage(fixture.dark
                  ? 'assets/images/theme/bg_default_night.webp'
                  : 'assets/images/theme/bg_default_day.webp'),
              context);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile('goldens/care_continuity/${fixture.name}.png'));
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(healthAnalysisGoldenRoot));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(_audit).create(recursive: true);
        await File('$_audit/continuity_${fixture.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
