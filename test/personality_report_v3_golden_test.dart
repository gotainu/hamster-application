import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'personality_report_v3_test_support.dart';

/// The binding configures painting and its own end-of-test invariant together.
/// Golden shadows use the real production blur without changing a debug flag.
class _PersonalityGoldenBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _PersonalityGoldenBinding();
  final oldLocale = Intl.defaultLocale;
  setUpAll(() async {
    // The ViewModel fixes the saved timestamp to JST. Keep the Golden runner
    // timezone fixed too, so future date-label changes remain reproducible.
    if (Platform.environment['TZ'] != 'Asia/Tokyo') {
      throw StateError('Run personality v3 goldens with TZ=Asia/Tokyo.');
    }
    Intl.defaultLocale = 'ja_JP';
    await loadPersonalityV3GoldenFonts();
  });
  tearDownAll(() {
    Intl.defaultLocale = oldLocale;
  });

  for (final scenario in [
    (name: 'both_dark', type: 'both', dark: true, research: true),
    (name: 'both_light', type: 'both', dark: false, research: true),
    (name: 'body_dark', type: 'weight_only', dark: true, research: true),
    (name: 'activity_dark', type: 'activity_only', dark: true, research: true),
    (
      name: 'body_without_research',
      type: 'weight_only',
      dark: true,
      research: false
    ),
  ]) {
    testWidgets('Japanese golden ${scenario.name}', (tester) async {
      await showPersonalityV3(
          tester,
          personalityV3Fixture(
              type: scenario.type, researchAvailable: scenario.research),
          dark: scenario.dark,
          goldenFont: true,
          bottomInset: 28);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(personalityV3GoldenRoot),
          matchesGoldenFile('goldens/personality_v3/${scenario.name}.png'));
    });
  }

  testWidgets('Japanese golden narrow and enlarged text', (tester) async {
    await showPersonalityV3(tester, personalityV3Fixture(type: 'activity_only'),
        goldenFont: true,
        width: 320,
        height: 1200,
        textScale: 1.5,
        bottomInset: 34);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(personalityV3GoldenRoot),
        matchesGoldenFile('goldens/personality_v3/narrow_activity.png'));
  });

  testWidgets('Japanese golden width240 at text scale3', (tester) async {
    await showPersonalityV3(
      tester,
      personalityV3Fixture(type: 'weight_only'),
      goldenFont: true,
      width: 240,
      height: 1600,
      textScale: 3,
      bottomInset: 34,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(personalityV3GoldenRoot),
      matchesGoldenFile('goldens/personality_v3/extreme_body_text_scale.png'),
    );
  });

  testWidgets('Japanese golden saved daily report', (tester) async {
    await showPersonalityV3(tester, savedPersonalityV3Fixture('both'),
        goldenFont: true, bottomInset: 28);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(personalityV3GoldenRoot),
        matchesGoldenFile('goldens/personality_v3/saved_daily.png'));
  });

  testWidgets('Japanese golden Samsung compact initial viewport',
      (tester) async {
    await showPersonalityV3(
      tester,
      personalitySamsungV3Fixture(),
      goldenFont: true,
      width: personalitySamsungViewport.width,
      height: personalitySamsungViewport.height,
      topInset: personalitySamsungTopInset,
      bottomInset: personalitySamsungBottomInset,
      asPushedRoute: true,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(personalityV3GoldenRoot),
      matchesGoldenFile('goldens/personality_v3/samsung_compact_initial.png'),
    );
  });

  testWidgets('Japanese golden Samsung compact expanded details',
      (tester) async {
    await showPersonalityV3(
      tester,
      personalitySamsungV3Fixture(),
      goldenFont: true,
      width: personalitySamsungViewport.width,
      height: personalitySamsungViewport.height,
      topInset: personalitySamsungTopInset,
      bottomInset: personalitySamsungBottomInset,
      asPushedRoute: true,
    );
    await expandPersonalityV3Details(tester);
    await Scrollable.ensureVisible(
      tester.element(find.text('記録の詳細・研究の出典')),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(personalityV3GoldenRoot),
      matchesGoldenFile(
          'goldens/personality_v3/samsung_compact_statistics.png'),
    );
    await tester.ensureVisible(find.textContaining('10.1111/jsap.13527'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(personalityV3GoldenRoot),
      matchesGoldenFile('goldens/personality_v3/samsung_compact_details.png'),
    );
  });

  testWidgets('Japanese golden expanded statistics and DOI', (tester) async {
    await showPersonalityV3(tester, personalityV3Fixture(type: 'weight_only'),
        goldenFont: true, height: 1300, bottomInset: 28);
    await expandPersonalityV3Details(tester);
    await tester.ensureVisible(find.textContaining('10.1111/jsap.13527'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(personalityV3GoldenRoot),
        matchesGoldenFile('goldens/personality_v3/expanded_details.png'));
  });
}
