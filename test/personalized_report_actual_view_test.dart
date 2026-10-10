import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/screens/personalized_report_screen.dart';

class _Legacy implements LegacyFirstReportSource {
  @override
  String? currentUid = 'a';
  final changes =
      StreamController<LegacyFirstReportState>.broadcast(sync: true);
  @override
  Stream<LegacyFirstReportState> watchFirstReport() => changes.stream;
}

void main() {
  late _Legacy source;
  setUp(() => source = _Legacy());
  tearDown(() => source.changes.close());
  LegacyFirstReportState ready([String uid = 'a']) =>
      LegacyFirstReportState.available(uid, {
        'analysisRevision': 1,
        'readyMetrics': ['body'],
        'analysisSpecVersion': 'personal_baseline_v1',
        'generation': {
          'status': 'generated',
          'generatedAt': '2026-10-07T02:52:29Z'
        }
      });
  Future<void> show(WidgetTester t,
      {FutureOr<void> Function()? view,
      Future<void> Function(String, int)? log,
      GlobalKey<NavigatorState>? nav,
      String? expectedOwnerUid}) async {
    await t.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: PersonalizedReportScreen(
            source: source,
            onReportViewed: view,
            logView: log ?? (_, __) async {},
            expectedOwnerUid: expectedOwnerUid)));
  }

  testWidgets(
      'loading and confirmed missing never save A3; missing is not permanent spinner',
      (t) async {
    int views = 0;
    await show(t, view: () => views++);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    source.changes.add(const LegacyFirstReportState.missing('a'));
    await t.pump();
    expect(find.text('初回レポートはまだありません'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(views, 0);
  });
  testWidgets('legacy actual drawing saves A3 and emits existing event once',
      (t) async {
    int views = 0;
    final logs = <String>[];
    await show(t,
        view: () => views++, log: (uid, rev) async => logs.add('$uid:$rev'));
    source.changes.add(ready());
    await t.pump();
    await t.pump();
    expect(views, 1);
    expect(logs, ['a:1']);
    source.changes.add(ready());
    await t.pump();
    await t.pump();
    expect(views, 1);
    expect(logs, ['a:1']);
  });
  testWidgets(
      'account switch during view persistence never emits old first under new account',
      (t) async {
    final gate = Completer<void>();
    final logs = <String>[];
    await show(t,
        view: () => gate.future, log: (uid, rev) async => logs.add(uid));
    source.changes.add(ready());
    await t.pump();
    source.currentUid = 'b';
    source.changes.add(const LegacyFirstReportState.loading('b'));
    gate.complete();
    await t.pump();
    await t.pump();
    expect(logs, isEmpty);
    expect(find.text('初回レポート'), findsNothing);
  });
  testWidgets(
      'covered legacy report has no view until current route is visible',
      (t) async {
    int views = 0;
    final nav = GlobalKey<NavigatorState>();
    await show(t, nav: nav, view: () => views++);
    nav.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('covered'))));
    await t.pumpAndSettle();
    source.changes.add(ready());
    await t.pump();
    await t.pump();
    expect(views, 0);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(views, 1);
  });
  testWidgets(
      'owner-bound legacy route never displays a switched account same-ID report',
      (t) async {
    int views = 0;
    final logs = <String>[];
    await show(t,
        expectedOwnerUid: 'a',
        view: () => views++,
        log: (uid, rev) async => logs.add(uid));
    source.changes.add(ready());
    await t.pump();
    await t.pump();
    expect(find.text('初回レポート'), findsOneWidget);
    expect(views, 1);
    expect(logs, ['a']);
    source.currentUid = 'b';
    source.changes.add(ready('b'));
    await t.pump();
    await t.pump();
    expect(find.text('初回レポート'), findsNothing);
    expect(find.text('レポートを取得できませんでした。'), findsOneWidget);
    expect(views, 1);
    expect(logs, ['a']);
  });
  testWidgets('legacy errors show retry without view side effects', (t) async {
    int views = 0;
    await show(t, view: () => views++);
    source.changes.add(const LegacyFirstReportState.unavailable('a'));
    await t.pump();
    expect(find.text('再試行'), findsOneWidget);
    expect(views, 0);
  });
}
