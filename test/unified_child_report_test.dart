import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/legacy_first_report.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/screens/personality_report_history_screen.dart';
import 'package:hamster_project/services/legacy_first_reports_repo.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/services/personality_report_view_service.dart';
import 'package:hamster_project/services/child_report_navigation.dart';
import 'package:hamster_project/viewmodels/legacy_first_report_view_model.dart';
import 'personality_report_fixtures.dart';

Map<String, dynamic> firstData() => {
      'analysisRevision': 3,
      'readyMetrics': ['body'],
      'generation': {
        'status': 'generated',
        'generatedAt': '2026-10-01T00:00:00Z',
        'sourceDateKey': '2026-10-01'
      },
      'metricStates': [
        {
          'metric': 'body',
          'status': 'ready',
          'validRecordCount': 8,
          'observationSpanDays': 14,
          'observationStartDateKey': '2026-09-17',
          'observationEndDateKey': '2026-09-30'
        }
      ]
    };

class _Legacy implements LegacyFirstReportSource {
  _Legacy(this.state);
  LegacyFirstReportState state;
  @override
  String? currentUid = 'owner-a';
  @override
  Stream<LegacyFirstReportState> watchFirstReport() => Stream.value(state);
}

class _Reports implements PersonalityReportsHistorySource {
  _Reports(this.state);
  PersonalityReportState state;
  List<PersonalityHistoryEntry> entries = [];
  @override
  Stream<PersonalityReportState> watchLatest() => Stream.value(state);
  @override
  Stream<PersonalityReportState> watchReport(String id) => Stream.value(state);
  @override
  Stream<String?> watchOwnerUid() => Stream.value('owner-a');
  @override
  Future<PersonalityHistoryPage> fetchHistory(
          {PersonalityHistoryCursor? after, int pageSize = 20}) async =>
      PersonalityHistoryPage('owner-a', entries);
}

void main() {
  test(
      'legacy typed adapter uses saved readiness only and never invents baseline values',
      () {
    final typed = LegacyFirstReportSnapshot.fromMap(firstData());
    expect(typed.analysisRevision, 3);
    expect(typed.metrics.single.metric, 'body');
    expect(typed.metrics.single.validRecordCount, 8);
    expect(typed.metrics.single.startDateKey, '2026-09-17');
    final sparse = LegacyFirstReportSnapshot.fromMap({
      'generation': {'status': 'generated'},
      'readyMetrics': ['body', 'unknown']
    });
    expect(sparse.metrics.length, 1);
    expect(sparse.metrics.single.validRecordCount, isNull);
    expect(sparse.generatedAt, isNull);
    final late = firstData();
    (late['generation'] as Map)['generatedAt'] = '2026-10-01T23:30:00Z';
    expect(
        LegacyFirstReportViewModel(LegacyFirstReportSnapshot.fromMap(late))
            .generatedAtLabel,
        '2026/10/2');
  });
  testWidgets(
      'confirmed absence of both report kinds shows preparation without a phantom first entry',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportScreen(
            repo: _Reports(const PersonalityReportState.learning('owner-a')),
            legacySource:
                _Legacy(const LegacyFirstReportState.missing('owner-a')))));
    await t.pumpAndSettle();
    expect(find.text('うちの子らしさを集めています'), findsOneWidget);
    expect(find.text('初回レポートはまだありません'), findsNothing);
    expect(find.text('初回分析の記録'), findsNothing);
  });
  testWidgets(
      'modern snapshot is primary; legacy is not duplicated on the main screen',
      (t) async {
    final report = PersonalityReport.fromMap(personalityFixture());
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportScreen(
            repo: _Reports(PersonalityReportState.available('owner-a', report)),
            legacySource: _Legacy(
                LegacyFirstReportState.available('owner-a', firstData())),
            onReportViewed: (_) {})));
    await t.pumpAndSettle();
    expect(find.text('うちの子レポート'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('初回分析の記録'), findsNothing);
    expect(find.byTooltip('レポート履歴'), findsOneWidget);
  });
  testWidgets(
      'confirmed absent modern falls back to frozen first in the same named screen',
      (t) async {
    var viewed = 0;
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportScreen(
            repo: _Reports(const PersonalityReportState.learning('owner-a')),
            legacySource: _Legacy(
                LegacyFirstReportState.available('owner-a', firstData())),
            onLegacyReportViewed: () => viewed++,
            logLegacyView: (_, __) async {})));
    await t.pumpAndSettle();
    expect(find.text('うちの子レポート'), findsOneWidget);
    expect(find.text('初回分析の記録'), findsOneWidget);
    expect(find.text('有効記録 8件'), findsOneWidget);
    expect(find.text('100'), findsNothing);
    expect(viewed, 1);
  });
  testWidgets(
      'modern error is retryable and never hidden by frozen first fallback',
      (t) async {
    var viewed = 0;
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportScreen(
            repo: _Reports(const PersonalityReportState.unavailable('owner-a')),
            legacySource: _Legacy(
                LegacyFirstReportState.available('owner-a', firstData())),
            onLegacyReportViewed: () => viewed++)));
    await t.pumpAndSettle();
    expect(find.text('再試行'), findsOneWidget);
    expect(find.text('初回分析の記録'), findsNothing);
    expect(viewed, 0);
  });
  testWidgets(
      'history renders first only after its existence and owner are confirmed',
      (t) async {
    final reports = _Reports(const PersonalityReportState.learning('owner-a'));
    final legacy = _Legacy(const LegacyFirstReportState.missing('owner-a'));
    final views = PersonalityReportViewService(
        currentUid: () => legacy.currentUid,
        markFirstView: (_) async => false,
        logView: (_) async {});
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportHistoryScreen(
            repo: reports, legacySource: legacy, viewService: views)));
    await t.pumpAndSettle();
    expect(find.text('初回分析の記録'), findsNothing);
    await t.pumpWidget(const SizedBox());
    legacy.state = LegacyFirstReportState.available('owner-a', firstData());
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportHistoryScreen(
            repo: reports, legacySource: legacy, viewService: views)));
    await t.pumpAndSettle();
    expect(find.text('初回分析の記録'), findsOneWidget);
    await t.tap(find.text('初回分析の記録'));
    await t.pumpAndSettle();
    expect(find.byType(PersonalityReportScreen), findsOneWidget);
    expect(find.text('うちの子レポート'), findsOneWidget);
    expect(find.text('有効記録 8件'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('レポート履歴'), findsOneWidget);
  });
  testWidgets(
      'common navigation records the exact modern ID once after actual rendering',
      (t) async {
    final report = PersonalityReport.fromMap(personalityFixture());
    final marked = <String>[], events = <String>[];
    final views = PersonalityReportViewService(
        currentUid: () => 'owner-a',
        markFirstView: (_) async => true,
        markReportViewed: (_, id) async => marked.add(id),
        logView: (event) async => events.add(event['report_id']! as String));
    await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => openChildReport(context,
                    repo: _Reports(
                        PersonalityReportState.available('owner-a', report)),
                    viewService: views),
                child: const Text('開く')))));
    expect(marked, isEmpty);
    await t.tap(find.text('開く'));
    await t.pumpAndSettle();
    expect(marked, [report.reportId]);
    expect(events, [report.reportId]);
    expect(find.text('うちの子レポート'), findsOneWidget);
  });
}
