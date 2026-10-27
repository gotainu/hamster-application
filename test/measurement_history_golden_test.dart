import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/widgets/weight_input_card.dart';
import 'package:hamster_project/widgets/wheel_rotation_input_card.dart';
import 'measurement_history_test_support.dart';
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
    (name: 'weight_light', dark: false, width: 393.0, scale: 1.0, weight: true),
    (
      name: 'rotation_dark',
      dark: true,
      width: 393.0,
      scale: 1.0,
      weight: false
    ),
    (
      name: 'rotation_narrow_large',
      dark: true,
      width: 320.0,
      scale: 1.5,
      weight: false
    )
  ]) {
    testWidgets('measurement history ${scenario.name}', (tester) async {
      final child = scenario.weight
          ? WeightInputCard(
              repo: WeightHistoryUiRepo(record: historyWeight(subject: null)),
              initialDate: DateTime(2026, 10, 12))
          : WheelRotationInputCard(
              distanceRepo: DistanceHistoryUiRepo(
                  record: historyDistance(
                      diameter: scenario.scale > 1 ? null : 20,
                      subject: scenario.scale > 1 ? null : 'subject-one')),
              initialDate: DateTime(2026, 10, 12));
      await showHealthAnalysisUi(
          tester,
          Scaffold(
              appBar: AppBar(title: const Text('記録入力')),
              body: ListView(
                  padding: const EdgeInsets.all(16), children: [child])),
          dark: scenario.dark,
          size: Size(scenario.width, 1100),
          textScale: scenario.scale,
          golden: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byKey(healthAnalysisGoldenRoot),
          matchesGoldenFile(
              'goldens/measurement_history/${scenario.name}.png'));
      final renderDir = Platform.environment['HAMCARE_RENDER_DIR'];
      if (renderDir == null) return;
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(healthAnalysisGoldenRoot));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory(renderDir);
        await folder.create(recursive: true);
        await File('${folder.path}/${scenario.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
