import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/graph_function.dart';
import 'package:hamster_project/services/current_weight_analysis_repo.dart';
import 'package:hamster_project/services/switchbot_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/weight_research_comparison_card.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'current_weight_analysis_test_support.dart';
import 'personality_report_v3_test_support.dart';

class _WeightGoldenBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _GoldenSource implements WeightAnalysisSource {
  @override
  Stream<CurrentWeightAnalysis?> watchCurrent() =>
      Stream.value(currentWeightAnalysisFixture());
}

const _root = ValueKey('weight-analysis-golden-root');

Future<void> _show(WidgetTester tester, {required bool dark}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  theme = theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: personalityV3GoldenFont),
    primaryTextTheme:
        theme.primaryTextTheme.apply(fontFamily: personalityV3GoldenFont),
    appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle
            ?.copyWith(fontFamily: personalityV3GoldenFont)),
  );
  final records = List.generate(8, (index) {
    final date = DateTime(2026, 10, 4 + index);
    return WeightRecord(
        dayKey: DateFormat('yyyy-MM-dd').format(date),
        date: date,
        weightGrams: 100,
        memo: '');
  });
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ja', 'JP'),
    supportedLocales: const [Locale('ja', 'JP')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 24)),
      child: RepaintBoundary(key: _root, child: child!),
    ),
    home: GraphFunctionScreen(
      weightAnalysisSource: _GoldenSource(),
      weightRecordsStream: Stream.value(records),
      switchbotConfigStream: Stream<SwitchbotConfig?>.value(null),
      activityRecordsStream: Stream<List<HealthRecord>>.value(const []),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('体重'));
  await tester.pumpAndSettle();
}

void main() {
  _WeightGoldenBinding();
  final previousLocale = Intl.defaultLocale;
  setUpAll(() async {
    if (Platform.environment['TZ'] != 'Asia/Tokyo') {
      throw StateError('Run weight goldens with TZ=Asia/Tokyo.');
    }
    await initializeDateFormatting('ja_JP');
    Intl.defaultLocale = 'ja_JP';
    await loadPersonalityV3GoldenFonts();
  });
  tearDownAll(() {
    Intl.defaultLocale = previousLocale;
  });

  for (final dark in [true, false]) {
    testWidgets(
        'weight current analysis ${dark ? 'dark' : 'light'} Samsung viewport',
        (tester) async {
      await _show(tester, dark: dark);
      expect(tester.takeException(), isNull);
      final name = dark ? 'dark' : 'light';
      await expectLater(find.byKey(_root),
          matchesGoldenFile('goldens/weight_analysis/${name}_initial.png'));
      await tester.ensureVisible(find.byType(WeightResearchComparisonCard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(_root),
          matchesGoldenFile('goldens/weight_analysis/${name}_comparison.png'));
    });
  }
}
