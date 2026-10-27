import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/screens/personality_report_history_screen.dart';
import 'package:hamster_project/services/legacy_first_reports_repo.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/services/personality_report_view_service.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'personality_report_v3_test_support.dart';

class _Reports implements PersonalityReportsHistorySource {
  final report = PersonalityReport.fromMap(personalityV3Fixture());
  @override
  Stream<PersonalityReportState> watchLatest() =>
      Stream.value(PersonalityReportState.available('synthetic-owner', report));
  @override
  Stream<PersonalityReportState> watchReport(String id) => watchLatest();
  @override
  Stream<String?> watchOwnerUid() => Stream.value('synthetic-owner');
  @override
  Future<PersonalityHistoryPage> fetchHistory(
          {PersonalityHistoryCursor? after, int pageSize = 20}) async =>
      PersonalityHistoryPage(
          'synthetic-owner', [PersonalityHistoryEntry(report, isViewed: true)]);
}

class _First implements LegacyFirstReportSource {
  @override
  String? get currentUid => 'synthetic-owner';
  @override
  Stream<LegacyFirstReportState> watchFirstReport() =>
      Stream.value(const LegacyFirstReportState.available('synthetic-owner', {
        'analysisRevision': 2,
        'readyMetrics': ['body', 'activity'],
        'generation': {
          'status': 'generated',
          'generatedAt': '2026-10-01T23:30:00Z'
        },
        'metricStates': [
          {
            'metric': 'body',
            'validRecordCount': 8,
            'observationStartDateKey': '2026-09-17',
            'observationEndDateKey': '2026-09-30'
          },
          {
            'metric': 'activity',
            'validRecordCount': 7,
            'observationStartDateKey': '2026-09-16',
            'observationEndDateKey': '2026-09-29'
          },
        ],
      }));
}

void main() {
  setUpAll(() async {
    if (Platform.environment['TZ'] != 'Asia/Tokyo') {
      throw StateError('Golden TZ required');
    }
    await loadPersonalityV3GoldenFonts();
  });
  for (final name in ['modern', 'first_narrow_light', 'history']) {
    testWidgets('unified child report $name', (tester) async {
      final narrow = name == 'first_narrow_light';
      tester.view.physicalSize = Size(narrow ? 320 : 393, narrow ? 1100 : 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var theme = narrow ? AppTheme.lightTheme : AppTheme.darkTheme;
      theme = theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: personalityV3GoldenFont),
          primaryTextTheme:
              theme.primaryTextTheme.apply(fontFamily: personalityV3GoldenFont),
          appBarTheme: theme.appBarTheme.copyWith(
              titleTextStyle: theme.appBarTheme.titleTextStyle
                  ?.copyWith(fontFamily: personalityV3GoldenFont)));
      final source = _Reports(), first = _First();
      final views = PersonalityReportViewService(
          currentUid: () => first.currentUid,
          markFirstView: (_) async => false,
          markLegacyFirstView: (_) async => false,
          logView: (_) async {});
      final screen = name == 'history'
          ? PersonalityReportHistoryScreen(
              repo: source, legacySource: first, viewService: views)
          : PersonalityReportScreen(
              repo: source,
              legacySource: first,
              legacyFirst: narrow,
              viewService: views,
              onReportViewed: (_) async {},
              onLegacyReportViewed: () async {},
              logLegacyView: (_, __) async {});
      const key = ValueKey('unified-report-golden');
      await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ja', 'JP'),
          supportedLocales: const [Locale('ja', 'JP')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: theme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(narrow ? 1.5 : 1),
                  padding: const EdgeInsets.only(bottom: 34),
                  viewPadding: const EdgeInsets.only(bottom: 34)),
              child: RepaintBoundary(key: key, child: child!)),
          home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (name == 'modern') expect(find.byTooltip('レポート履歴'), findsOneWidget);
      if (narrow) expect(find.text('作成 2026/10/2'), findsOneWidget);
      await expectLater(find.byKey(key),
          matchesGoldenFile('goldens/unified_child_report/$name.png'));
    });
  }
}
