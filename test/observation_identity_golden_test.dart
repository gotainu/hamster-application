import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_observation_history.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';
import 'care_action_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';
import 'observation_identity_ui_test.dart' show ObservationUiStore;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _Binding();
  setUpAll(loadPersonalityV3GoldenFonts);
  for (final scenario in [
    (name: 'new_dark', dark: true, width: 393.0, scale: 1.0, editing: false),
    (
      name: 'correction_light',
      dark: false,
      width: 393.0,
      scale: 1.0,
      editing: true
    ),
    (name: 'narrow_large', dark: true, width: 320.0, scale: 1.5, editing: true),
  ]) {
    testWidgets('observation history ${scenario.name}', (tester) async {
      final health = ObservationUiStore(), care = CareTestStore();
      if (scenario.editing) {
        health.revision = 1;
        health.initial = DailyCheckin(
            dayKey: '2026-10-12',
            date: DateTime(2026, 10, 12),
            condition: DailyCondition.normal,
            concernTags: const [],
            memo: '',
            subjectId: 'subject_one',
            eventId: 'event_one',
            revision: 1,
            timing: const ObservationTiming.dateOnly('2026-10-12'));
      }
      await showHealthAnalysisUi(
          tester,
          Scaffold(
              appBar: AppBar(title: const Text('今日の記録')),
              body: Builder(
                  builder: (context) => DecoratedBox(
                      decoration: AppTheme.dataPageDecoration(context),
                      child: SafeArea(
                          top: false,
                          child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                DailyConditionInputCard(
                                    repo: health,
                                    careRepo: care,
                                    date: DateTime(2026, 10, 12)),
                              ]))))),
          dark: scenario.dark,
          size: Size(scenario.width, 1000),
          textScale: scenario.scale,
          golden: true);
      await tester.runAsync(() => precacheImage(
          const AssetImage('store_assets/icons/google_play_icon_512.png'),
          tester.element(find.byType(DailyConditionInputCard))));
      await tester.pumpAndSettle();
      if (scenario.editing) {
        await tester.tap(find.text('編集'));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('observation-intent-correction')));
      } else {
        await tester.tap(find.text('いつも通り'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('observation-time-date')));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile(
              'goldens/observation_history/${scenario.name}.png'));
      await tester.runAsync(() async {
        final root = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(healthAnalysisGoldenRoot));
        final image = await root.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory(
            Platform.environment['HAMCARE_OBSERVATION_UI_DIR'] ??
                '${Directory.systemTemp.path}/hamcare-observation-ui');
        await folder.create(recursive: true);
        await File('${folder.path}/${scenario.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
