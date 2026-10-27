import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'checkin_only_report_test_support.dart';
import 'personality_report_v3_test_support.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _Binding();
  setUpAll(() async {
    if (Platform.environment['TZ'] != 'Asia/Tokyo') {
      throw StateError('Golden TZ required');
    }
    await loadPersonalityV3GoldenFonts();
  });
  for (final scenario in [
    (name: 'dark', dark: true, width: 360.0, scale: 1.0),
    (name: 'light', dark: false, width: 360.0, scale: 1.0),
    (name: 'narrow_large', dark: true, width: 320.0, scale: 1.5),
  ]) {
    testWidgets('observation-only immutable daily ${scenario.name}',
        (tester) async {
      await showPersonalityV3(tester, checkinOnlyReportFixture(),
          dark: scenario.dark,
          width: scenario.width,
          height: 852,
          textScale: scenario.scale,
          bottomInset: 48,
          goldenFont: true);
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byKey(personalityV3GoldenRoot),
          matchesGoldenFile(
              'goldens/checkin_only_report/${scenario.name}.png'));
    });
  }
}
