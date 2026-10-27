import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/viewmodels/personality_report_view_model.dart';
import 'checkin_only_report_test_support.dart';
import 'personality_report_v3_test_support.dart';

void main() {
  setUpAll(loadPersonalityV3GoldenFonts);
  for (final kind in [
    'checkin_item_repetition',
    'checkin_concern_frequency',
    'checkin_record_continuity',
  ]) {
    test('observation-only daily accepts committed $kind, no invented baseline',
        () {
      final report =
          PersonalityReport.fromMap(checkinOnlyReportFixture(kind: kind));
      expect(report.type.name, 'observationOnly');
      expect(report.isDaily, isTrue);
      expect(report.body, isNull);
      expect(report.activity, isNull);
      expect(
          report.checkinInsightSnapshot!.insights.single.kind.name, isNotEmpty);
      final vm = PersonalityReportViewModel(report);
      expect(vm.overviewSummary, '14日間の様子の記録から見えてきたこと。');
      expect(vm.headerLabel, '様子の記録で見えてきた個性');
      expect(vm.metricLabel, '今日の様子');
      expect(vm.checkinInsights.items, hasLength(1));
    });
  }

  Map<String, dynamic> actualBackendReport() =>
      jsonDecode(File('test/fixtures/checkin_only_backend_report_fixture.json')
          .readAsStringSync()) as Map<String, dynamic>;

  test(
      'actual Emulator daily payload decodes immutable observation evidence and ViewModel',
      () {
    final data = actualBackendReport();
    final report =
        PersonalityReport.fromMap(data, expectedReportId: 'daily_2026-10-08');
    final vm = PersonalityReportViewModel(report);
    expect(report.type, PersonalityReportType.observationOnly);
    expect(report.body, isNull);
    expect(report.activity, isNull);
    expect(report.generatedAt, DateTime.utc(2026, 10, 8));
    expect(vm.generatedAtLabel, '2026/10/8 09:00 JST');
    expect(vm.evaluationDateLabel, '2026-10-08');
    expect(vm.cutoffDateLabel, '2026-10-07');
    expect(vm.checkinInsights.items.single.text,
        '確認できた7日分の記録で、食欲が3日、気になる箇所として選ばれました');
    expect(vm.checkinInsights.items.single.periodLabel,
        '2026-09-24〜2026-10-07（14日間）');
    expect(vm.checkinInsights.items.single.evidenceLabel, '有効記録 7日 · 未記録 7日');
    expect(report.checkinInsightSnapshot!.evidenceHash,
        data['insightSnapshot']['checkinInsights']['evidenceHash']);
    expect(
        report.checkinInsightSnapshot!.insights.single.evidence
            .itemAnsweredDayCount,
        isNull);
  });

  testWidgets(
      'actual backend observation-only report is rendered before a view is recorded',
      (tester) async {
    final viewed = <String>[];
    await showPersonalityV3(tester, actualBackendReport(),
        goldenFont: true, onViewed: (report) => viewed.add(report.reportId));
    expect(find.textContaining('食欲が3日'), findsOneWidget);
    expect(find.textContaining('2026-09-24〜2026-10-07'), findsOneWidget);
    expect(find.byKey(const ValueKey('personality-body-card')), findsNothing);
    expect(
        find.byKey(const ValueKey('personality-activity-card')), findsNothing);
    expect(viewed, ['daily_2026-10-08']);
    expect(tester.takeException(), isNull);
  });

  test('observation-only requires new daily identity and empty ready metrics',
      () {
    for (final patch in <Map<String, dynamic>>[
      {'reportId': 'personality_v1_body'},
      {'reportId': 'personality_v1_condition'},
      {
        'readyMetrics': ['body']
      },
      {
        'readyMetrics': ['condition']
      },
      {'readyMetrics': null},
      {
        'readyMetrics': [null]
      },
      {'cutoffDateKey': '2026-10-11'},
    ]) {
      final data = checkinOnlyReportFixture()..addAll(patch);
      expect(() => PersonalityReport.fromMap(data), throwsFormatException);
    }
  });

  test(
      'missing, empty, mismatched observation snapshot is not an available report',
      () {
    final missing = checkinOnlyReportFixture()..remove('insightSnapshot');
    final empty = checkinOnlyReportFixture();
    empty['insightSnapshot']['checkinInsights']['insights'] = [];
    final mismatch = checkinOnlyReportFixture();
    mismatch['insightSnapshot']['checkinInsights']['windowEndDateKey'] =
        '2026-10-11';
    final obsoleteGeneration = checkinOnlyReportFixture();
    obsoleteGeneration['insightSnapshot']['generatedAt'] =
        '2026-10-10T02:00:00Z';
    for (final data in [missing, empty, mismatch, obsoleteGeneration]) {
      expect(() => PersonalityReport.fromMap(data), throwsFormatException);
    }
  });

  for (final dark in [true, false]) {
    testWidgets(
        'observation-only detail has saved evidence, no scores or baselines $dark',
        (tester) async {
      final seen = <String>[];
      await showPersonalityV3(tester, checkinOnlyReportFixture(),
          dark: dark,
          goldenFont: true,
          onViewed: (report) => seen.add(report.reportId));
      expect(find.text('14日間の様子の記録から見えてきたこと。'), findsOneWidget);
      expect(find.textContaining('食欲が3日'), findsOneWidget);
      expect(find.byKey(const ValueKey('personality-body-card')), findsNothing);
      expect(find.byKey(const ValueKey('personality-activity-card')),
          findsNothing);
      expect(find.text('体重・活動量はこれから'), findsOneWidget);
      expect(find.textContaining('100g'), findsNothing);
      expect(find.textContaining('628'), findsNothing);
      expect(seen, ['daily_2026-10-11']);
      await expandPersonalityV3Details(tester);
      expect(find.text('生成時点の記録を保存しています。後日の記録では変わりません。'), findsOneWidget);
      expect(find.text('2026-10-10'), findsOneWidget);
      expect(find.text('中央値'), findsNothing);
      expect(find.textContaining('DOI'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(seen, ['daily_2026-10-11']);
    });
  }
  testWidgets(
      'observation-only narrow large-text presentation remains readable',
      (tester) async {
    await showPersonalityV3(
        tester, checkinOnlyReportFixture(kind: 'checkin_concern_frequency'),
        width: 320,
        height: 1200,
        textScale: 1.5,
        bottomInset: 48,
        goldenFont: true);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('checkin-insights-card')), 150);
    expect(find.textContaining('「少し違う」「心配」は3日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'prior v1 report still renders its immutable body/activity values',
      (tester) async {
    await showPersonalityV3(tester, personalityV3Fixture(), goldenFont: true);
    expect(find.byKey(const ValueKey('personality-body-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('personality-activity-card')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('checkin-insights-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
