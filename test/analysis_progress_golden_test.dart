import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/analysis_progress_card.dart';
import 'analysis_progress_card_test.dart' show progressStates;
import 'personality_report_v3_test_support.dart'
    show loadPersonalityV3GoldenFonts, personalityV3GoldenFont;

class _PreparationGoldenBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _root = ValueKey('analysis-progress-local-render');

Future<void> _show(
  WidgetTester tester, {
  required bool dark,
  required List<Map<String, dynamic>> states,
  double width = 360,
  double height = 780,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  theme = theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: personalityV3GoldenFont),
    primaryTextTheme:
        theme.primaryTextTheme.apply(fontFamily: personalityV3GoldenFont),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle:
          (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)
              ?.copyWith(fontFamily: personalityV3GoldenFont),
    ),
  );
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 34, bottom: 48),
        viewPadding: const EdgeInsets.only(top: 34, bottom: 48),
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: RepaintBoundary(
      key: _root,
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text('今日')),
        body: Builder(builder: (context) {
          return Container(
            decoration: AppTheme.dataPageDecoration(context),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AnalysisProgressCard(
                  readinessStream: Stream.value(states),
                  onOpenRecord: () {},
                  onOpenSwitchbot: () {},
                  onViewAnalysis: () {},
                ),
              ),
            ),
          );
        }),
      ),
    ),
  ));
  await tester.pump();
  if (find
      .byKey(const ValueKey('analysis-preparation-illustration'))
      .evaluate()
      .isNotEmpty) {
    await tester.runAsync(() => precacheImage(
        const AssetImage(AppTheme.analysisPreparationIllustrationAsset),
        tester.element(find.byType(AnalysisProgressCard))));
  }
  await tester.pumpAndSettle();
}

void main() {
  _PreparationGoldenBinding();
  setUpAll(loadPersonalityV3GoldenFonts);
  final cases = [
    (name: 'samsung_learning_dark', dark: true, body: false, activity: false),
    (
      name: 'samsung_body_ready_light',
      dark: false,
      body: true,
      activity: false
    ),
    (
      name: 'samsung_activity_ready_dark',
      dark: true,
      body: false,
      activity: true
    ),
    (name: 'samsung_all_ready_dark', dark: true, body: true, activity: true),
  ];
  for (final scenario in cases) {
    testWidgets('local preparation golden ${scenario.name}', (tester) async {
      await _show(tester,
          dark: scenario.dark,
          states: progressStates(
              bodyReady: scenario.body, activityReady: scenario.activity));
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(_root),
          matchesGoldenFile('goldens/analysis_progress/${scenario.name}.png'));
    });
  }
  testWidgets('local preparation narrow enlarged text', (tester) async {
    await _show(tester,
        dark: false,
        states: progressStates(),
        width: 320,
        height: 1400,
        scale: 1.5);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(_root),
        matchesGoldenFile('goldens/analysis_progress/narrow_large_light.png'));
  });
}
