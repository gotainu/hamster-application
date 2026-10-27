import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';
import 'care_action_test_support.dart';
import 'health_individual_analysis_ui_support.dart';
import 'personality_report_v3_test_support.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _Binding();
  setUpAll(loadPersonalityV3GoldenFonts);
  for (final scenario in [
    (
      name: 'dark_initial',
      dark: true,
      width: 393.0,
      scale: 1.0,
      selected: false,
      pending: false
    ),
    (
      name: 'light_details',
      dark: false,
      width: 393.0,
      scale: 1.0,
      selected: true,
      pending: false
    ),
    (
      name: 'narrow_large',
      dark: true,
      width: 320.0,
      scale: 1.5,
      selected: false,
      pending: false
    ),
    (
      name: 'pending_sync',
      dark: true,
      width: 360.0,
      scale: 1.0,
      selected: false,
      pending: true
    ),
  ]) {
    testWidgets('care capture ${scenario.name}', (tester) async {
      final health = CareHealthTestStore(), care = CareTestStore();
      if (scenario.pending) {
        care.initial = CareActionLoadResult(
            pending: CareActionMutation(
                dayKey: '2026-10-12',
                expectedRevision: 0,
                mutationId: '00000000-0000-4000-8000-000000000001',
                actions: {
                  'cageCleaning': const CareActionResponse(
                      answer: CareActionAnswer.notPerformed),
                  'roomWalk': const CareActionResponse()
                }),
            serverConfirmed: false);
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
                                RepaintBoundary(
                                    key: const ValueKey('care-full-content'),
                                    child: DailyConditionInputCard(
                                        repo: health,
                                        careRepo: care,
                                        date: DateTime(2026, 10, 12)))
                              ]))))),
          dark: scenario.dark,
          size: Size(scenario.width, 852),
          textScale: scenario.scale,
          golden: true);
      // Image decoding must finish before comparisons in cold or warm runs.
      await tester.runAsync(() => precacheImage(
          const AssetImage('store_assets/icons/google_play_icon_512.png'),
          tester.element(find.byType(DailyConditionInputCard))));
      await tester.pumpAndSettle();
      if (scenario.selected) {
        await tester.tap(
            find.byKey(const ValueKey('care-cageCleaning-partial_cleaning')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(
            const ValueKey('care-cageCleaning-beddingReplacement-partial')));
        tester
            .widget<Slider>(
                find.byKey(const ValueKey('care-duration-slider-roomWalk')))
            .onChanged!(20);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile('goldens/care_capture/${scenario.name}.png'));
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(healthAnalysisGoldenRoot));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = Directory(
            '/private/tmp/hamcare-achievement-care-redesign-20261012-gtqx6xio/ui');
        await out.create(recursive: true);
        await File('${out.path}/care_${scenario.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      // Capture the entire form against its real themed backdrop, at the same
      // Samsung width. BackdropFilter cannot be captured as an isolated card.
      final fullHeight = tester
              .getSize(find.byKey(const ValueKey('care-full-content')))
              .height +
          150;
      tester.view.physicalSize = Size(scenario.width, fullHeight);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final root = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(healthAnalysisGoldenRoot));
        final fullImage = await root.toImage(pixelRatio: 2);
        final fullBytes =
            await fullImage.toByteData(format: ui.ImageByteFormat.png);
        await File(
                '/private/tmp/hamcare-achievement-care-redesign-20261012-gtqx6xio/ui/care_${scenario.name}_full.png')
            .writeAsBytes(fullBytes!.buffer.asUint8List());
        fullImage.dispose();
      });
    });
  }
}
