import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/personality_report_history_screen.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/services/personality_report_view_service.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/widgets/personality_report_entry.dart';
import 'checkin_only_report_test_support.dart';
import 'personality_report_v3_test_support.dart';

class _Reports
    implements PersonalityReportsHistorySource, PersonalityUnreadReportsSource {
  final PersonalityReport observation =
      PersonalityReport.fromMap(checkinOnlyReportFixture());
  final PersonalityReport prior =
      PersonalityReport.fromMap(personalityV3Fixture());
  final PersonalityReport next =
      PersonalityReport.fromMap(nextCheckinOnlyReportFixture());
  final _unread =
      StreamController<PersonalityReportState>.broadcast(sync: true);
  final reads = <String>[];
  bool viewed = false;
  @override
  Stream<PersonalityReportState> watchLatest() =>
      Stream.value(PersonalityReportState.available('owner', observation));
  @override
  Stream<PersonalityReportState> watchUnreadLatest() => Stream.multi((sink) {
        sink.add(PersonalityReportState.available('owner', observation));
        final subscription = _unread.stream.listen(sink.add);
        sink.onCancel = subscription.cancel;
      });
  void markViewed() {
    viewed = true;
    _unread.add(const PersonalityReportState.learning('owner'));
  }

  void nextUnread() =>
      _unread.add(PersonalityReportState.available('owner', next));
  @override
  Stream<PersonalityReportState> watchReport(String reportId) {
    reads.add(reportId);
    return Stream.value(PersonalityReportState.available(
        'owner', reportId == observation.reportId ? observation : prior));
  }

  @override
  Stream<String?> watchOwnerUid() => Stream.value('owner');
  @override
  Future<PersonalityHistoryPage> fetchHistory(
          {PersonalityHistoryCursor? after, int pageSize = 20}) async =>
      PersonalityHistoryPage('owner', [
        PersonalityHistoryEntry(observation, isViewed: viewed),
        PersonalityHistoryEntry(prior, isViewed: false),
      ]);
  Future<void> close() => _unread.close();
}

void main() {
  testWidgets(
      'observation Home card is unread until detail renders, disappears and can reappear',
      (tester) async {
    final source = _Reports();
    addTearDown(source.close);
    final seen = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: PersonalityReportEntry(
                  source: source,
                  onOpen: (report) =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => PersonalityReportScreen(
                                repo: source,
                                reportId: report.reportId,
                                expectedOwnerUid: 'owner',
                                onReportViewed: (report) {
                                  seen.add(report.reportId);
                                  source.markViewed();
                                },
                              ))),
                )))));
    await tester.pumpAndSettle();
    expect(find.text('新しいうちの子レポートが届きました'), findsOneWidget);
    expect(seen, isEmpty);
    await tester.tap(find.text('うちの子レポートを見る'));
    await tester.pumpAndSettle();
    expect(find.textContaining('食欲が3日'), findsOneWidget);
    expect(seen, [source.observation.reportId]);
    expect(source.reads, [source.observation.reportId]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('新しいうちの子レポートが届きました'), findsNothing);
    source.nextUnread();
    await tester.pumpAndSettle();
    expect(find.text('新しいうちの子レポートが届きました'), findsOneWidget);
    expect(seen, [source.observation.reportId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'history identifies observation-only and opening prior report preserves other unread state',
      (tester) async {
    final source = _Reports();
    addTearDown(source.close);
    final seen = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: PersonalityReportHistoryScreen(
      repo: source,
      viewService: PersonalityReportViewService(
        currentUid: () => 'owner',
        markReportViewed: (_, id) async => seen.add(id),
        markFirstView: (_) async => false,
        logView: (_) async {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('対象: 今日の様子'), findsOneWidget);
    expect(find.textContaining('対象: 体重・活動量'), findsOneWidget);
    expect(find.text('未読'), findsNWidgets(2));
    expect(seen, isEmpty);
    await tester.ensureVisible(
        find.byKey(ValueKey('report-history-${source.prior.reportId}')));
    await tester
        .tap(find.byKey(ValueKey('report-history-${source.prior.reportId}')));
    await tester.pumpAndSettle();
    expect(seen, [source.prior.reportId]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('未読'), findsOneWidget);
    expect(find.text('閲覧済み'), findsOneWidget);
    expect(find.textContaining('対象: 今日の様子'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
