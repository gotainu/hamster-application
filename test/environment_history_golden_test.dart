import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/screens/breeding_environment_edit_screen.dart';
import 'package:hamster_project/screens/environment_history_screen.dart';
import 'environment_history_test_support.dart';
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
    (name: 'input_dark', dark: true, width: 393.0, scale: 1.0, history: false),
    (
      name: 'input_light',
      dark: false,
      width: 393.0,
      scale: 1.0,
      history: false
    ),
    (
      name: 'input_narrow_large',
      dark: true,
      width: 320.0,
      scale: 1.5,
      history: false
    ),
    (name: 'history_dark', dark: true, width: 393.0, scale: 1.0, history: true),
    (
      name: 'history_narrow_large',
      dark: false,
      width: 320.0,
      scale: 1.5,
      history: true
    ),
  ]) {
    testWidgets('environment history ${scenario.name}', (tester) async {
      final store = EnvironmentTestStore()
        ..entries = [
          environmentHistoryFixture(revision: 4, kind: 'correction'),
          environmentHistoryFixture(revision: 3),
          environmentHistoryFixture(revision: 2, precision: 'unknown'),
        ];
      await showHealthAnalysisUi(
          tester,
          scenario.history
              ? EnvironmentHistoryScreen(store: store)
              : BreedingEnvironmentEditScreen(
                  store: store,
                  now: () => DateTime(2026, 10, 12, 12),
                  onSaved: () async {}),
          dark: scenario.dark,
          size: Size(scenario.width, 852),
          textScale: scenario.scale,
          golden: true);
      if (!scenario.history) {
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('environment-save')), 450,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile(
              'goldens/environment_history/${scenario.name}.png'));
      final output = Platform.environment['HAMCARE_ENVIRONMENT_UI_OUTPUT'];
      if (output != null) {
        await exportEnvironmentUi(tester, output, scenario.name);
        if (!scenario.history) {
          tester.view.physicalSize = Size(scenario.width, 2200);
          await tester.pumpAndSettle();
          await exportEnvironmentUi(tester, output, '${scenario.name}_full');
        }
      }
    });
  }
}

Future<void> exportEnvironmentUi(
        WidgetTester tester, String output, String name) =>
    tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(healthAnalysisGoldenRoot));
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
