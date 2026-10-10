import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/services/personality_report_view_service.dart';
import 'package:hamster_project/screens/personality_report_history_screen.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'personality_report_v2_ui_fixtures.dart';

class _History implements PersonalityReportsHistorySource {
  String? owner = 'owner-a';
  final owners = StreamController<String?>.broadcast(sync: true);
  final requests = <PersonalityHistoryCursor?>[];
  final reads = <String>[];
  final reports = <String, PersonalityReport>{};
  final pages = <Future<PersonalityHistoryPage> Function()>[];
  @override
  Stream<String?> watchOwnerUid() async* {
    yield owner;
    yield* owners.stream;
  }

  @override
  Future<PersonalityHistoryPage> fetchHistory(
      {PersonalityHistoryCursor? after, int pageSize = 20}) {
    requests.add(after);
    return pages.removeAt(0)();
  }

  @override
  Stream<PersonalityReportState> watchLatest() =>
      throw StateError('History must not read latest');
  @override
  Stream<PersonalityReportState> watchReport(String id) {
    reads.add(id);
    return Stream.value(PersonalityReportState.available(owner, reports[id]));
  }

  void switchTo(String? uid) {
    owner = uid;
    owners.add(uid);
  }
}

void main() {
  late _History source;
  late List<String> marked;
  late List<Map<String, Object>> events;
  setUp(() {
    source = _History();
    marked = [];
    events = [];
  });
  tearDown(() => source.owners.close());
  PersonalityReport daily(String day) =>
      PersonalityReport.fromMap(personalityV2UiFixture(reportId: 'daily_$day'));
  PersonalityReportViewService views() => PersonalityReportViewService(
      currentUid: () => source.owner,
      markReportViewed: (uid, id) async {
        marked.add(id);
      },
      markFirstView: (_) async => false,
      logView: (metadata) async => events.add(metadata));
  Future<void> show(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportHistoryScreen(
            repo: source, viewService: views())));
    await t.pumpAndSettle();
  }

  testWidgets(
      'history shows date, type, metrics, features, seen and old first entry',
      (t) async {
    final a = daily('2026-10-10');
    source.reports[a.reportId] = a;
    source.pages.add(() async => PersonalityHistoryPage(
        'owner-a', [PersonalityHistoryEntry(a, isViewed: false)]));
    await show(t);
    expect(find.text('レポート履歴'), findsOneWidget);
    expect(find.text('初回コンディションレポート'), findsOneWidget);
    expect(find.text('日次の個性レポート'), findsOneWidget);
    expect(find.textContaining('対象: 体重・活動量'), findsOneWidget);
    expect(find.textContaining('628m/日'), findsOneWidget);
    expect(find.text('未読'), findsOneWidget);
    expect(marked, isEmpty);
    expect(events, isEmpty);
  });
  testWidgets('paging preserves loaded immutable reports and uses cursor',
      (t) async {
    final a = daily('2026-10-10'), b = daily('2026-10-09');
    final cursor =
        PersonalityHistoryCursor('owner-a', Timestamp.now(), a.reportId);
    source.pages.addAll([
      () => Future.value(PersonalityHistoryPage(
          'owner-a', [PersonalityHistoryEntry(a, isViewed: true)],
          nextCursor: cursor)),
      () => Future.value(PersonalityHistoryPage(
          'owner-a', [PersonalityHistoryEntry(b, isViewed: false)]))
    ]);
    await show(t);
    await t.tap(find.text('さらに読み込む'));
    await t.pumpAndSettle();
    expect(source.requests, [null, cursor]);
    expect(find.text('日次の個性レポート'), findsNWidgets(2));
    expect(find.text('閲覧済み'), findsOneWidget);
    expect(find.text('未読'), findsOneWidget);
    expect(find.text('さらに読み込む'), findsNothing);
  });
  testWidgets(
      'old history exact-ID detail marks only after drawing and retains newer unread',
      (t) async {
    final latest = daily('2026-10-10');
    final old =
        PersonalityReport.fromMap(personalityV2UiFixture(type: 'weight_only'));
    source.reports[old.reportId] = old;
    source.pages.add(() => Future.value(PersonalityHistoryPage('owner-a', [
          PersonalityHistoryEntry(latest, isViewed: false),
          PersonalityHistoryEntry(old, isViewed: false)
        ])));
    await show(t);
    expect(marked, isEmpty);
    await t.ensureVisible(find.text('個性レポート'));
    await t.tap(find.text('個性レポート'));
    await t.pumpAndSettle();
    expect(find.byType(PersonalityReportScreen), findsOneWidget);
    expect(
        t
            .widget<PersonalityReportScreen>(
                find.byType(PersonalityReportScreen))
            .expectedOwnerUid,
        'owner-a');
    expect(source.reads, [old.reportId]);
    expect(marked, [old.reportId]);
    expect(events.single['report_id'], old.reportId);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('閲覧済み'), findsOneWidget);
    expect(find.text('未読'), findsOneWidget);
  });
  testWidgets(
      'empty history retains first access and shows no invented personality',
      (t) async {
    source.pages
        .add(() => Future.value(const PersonalityHistoryPage('owner-a', [])));
    await show(t);
    expect(find.text('個性レポートはまだ届いていません。'), findsOneWidget);
    expect(find.text('初回コンディションレポート'), findsOneWidget);
  });
  testWidgets('unavailable history is retryable and never treated as empty',
      (t) async {
    source.pages.add(() => Future.error(StateError('offline')));
    source.pages
        .add(() => Future.value(const PersonalityHistoryPage('owner-a', [])));
    await show(t);
    expect(find.text('レポート履歴を取得できませんでした。'), findsOneWidget);
    expect(find.text('個性レポートはまだ届いていません。'), findsNothing);
    await t.tap(find.text('再試行'));
    await t.pumpAndSettle();
    expect(source.requests, hasLength(2));
    expect(find.text('個性レポートはまだ届いていません。'), findsOneWidget);
  });
  testWidgets(
      'account switch clears prior history and rejects old in-flight page',
      (t) async {
    final pending = Completer<PersonalityHistoryPage>();
    source.pages.add(() => pending.future);
    source.pages
        .add(() => Future.value(const PersonalityHistoryPage('owner-b', [])));
    await t.pumpWidget(MaterialApp(
        home: PersonalityReportHistoryScreen(
            repo: source, viewService: views())));
    await t.pump();
    await t.pump();
    source.switchTo('owner-b');
    await t.pump();
    await t.pump();
    pending.complete(PersonalityHistoryPage('owner-a',
        [PersonalityHistoryEntry(daily('2026-10-10'), isViewed: false)]));
    await t.pumpAndSettle();
    expect(find.text('日次の個性レポート'), findsNothing);
    expect(find.text('個性レポートはまだ届いていません。'), findsOneWidget);
  });
}
