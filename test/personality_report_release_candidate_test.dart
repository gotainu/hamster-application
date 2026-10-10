// Offline Widget E2E uses installed FlutterFire platform interfaces only.
// All reads/writes are in memory, and external HTTP is forbidden.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fp;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as ap;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    as cp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/home.dart';
import 'package:hamster_project/screens/personalized_report_screen.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/screens/personality_report_history_screen.dart';
import 'package:hamster_project/widgets/main_drawer.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';

const _uid = 'release-candidate-synthetic-owner';
const _statePath = 'users/$_uid/app_state/onboarding';
const _firstPath = 'users/$_uid/personalized_reports/first';
const _goldPath =
    'users/$_uid/personality_reports/personality_v1_body_activity';
const _pointerPath = 'users/$_uid/report_pointers/personality';
const _dailyPointerPath = 'users/$_uid/report_pointers/personality_daily';

// These Gold contracts were produced by the actual Admin Firestore Emulator
// and syncPersonalityAfterFirstReportFreezeForAcceptedUser(), using synthetic
// B-equivalent Bronze (100g, 20cm wheel, 1000 rotations). They contain no real
// account data. The local-only provenance is retained with the test fixture.
Map<String, dynamic> _gold([String kind = 'both']) =>
    jsonDecode(File('test/fixtures/personality_report_emulator_gold_$kind.json')
        .readAsStringSync()) as Map<String, dynamic>;

String _canonical(dynamic value) {
  dynamic normalize(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: normalize(value[key])};
    }
    if (value is List) return value.map(normalize).toList();
    return value;
  }

  return jsonEncode(normalize(value));
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('External HTTP is forbidden in onboarding tests');
}

class _Core extends cp.FirebasePlatform {
  final _app = cp.FirebaseAppPlatform(
    cp.defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'fake-api-key',
      appId: 'fake-app-id',
      messagingSenderId: 'fake-sender',
      projectId: 'offline-widget-test',
    ),
  );
  @override
  List<cp.FirebaseAppPlatform> get apps => [_app];
  @override
  cp.FirebaseAppPlatform app([String name = cp.defaultFirebaseAppName]) => _app;
}

class _Auth extends ap.FirebaseAuthPlatform {
  late final _user = _User(this);
  @override
  ap.FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  ap.FirebaseAuthPlatform setInitialValues({
    ap.PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;
  @override
  ap.UserPlatform get currentUser => _user;
  @override
  Stream<ap.UserPlatform?> authStateChanges() => Stream.value(_user);
  @override
  Stream<ap.UserPlatform?> idTokenChanges() => Stream.value(_user);
  @override
  Stream<ap.UserPlatform?> userChanges() => Stream.value(_user);
}

class _MultiFactor extends ap.MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends ap.UserPlatform {
  _User(ap.FirebaseAuthPlatform auth)
      : super(
            auth,
            _MultiFactor(auth),
            ap.PigeonUserDetails(
              userInfo: ap.PigeonUserInfo(
                uid: _uid,
                isAnonymous: false,
                isEmailVerified: false,
              ),
              providerData: [],
            ));
  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'fake-id-token';
}

/// A fake backend shared across widget recreation. All writes stay in memory.

class _Firestore extends fp.FirebaseFirestorePlatform {
  final documents = <String, Map<String, dynamic>>{};
  final changes = StreamController<void>.broadcast(sync: true);
  Future<void> _transactions = Future.value();
  int _clock = 0;

  final writes = <String>[];
  final reads = <String>[];
  final cachedPaths = <String>{};

  void reset() {
    _transactions = Future.value();
    documents.clear();
    writes.clear();
    reads.clear();
    cachedPaths.clear();
    documents[_statePath] = {
      'firstAiConsultationCompleted': true,
      'homeAiOnboardingPending': false,
      'monitoringIntroCtaPending': false,
      'firstMonitoringDataSource': 'daily_checkin',
    };
    documents[_firstPath] = {
      'reportId': 'first',
      'readyMetrics': ['body'],
      'analysisSpecVersion': 'personal_baseline_v1',
      'analysisRevision': 1,
      'generation': {
        'status': 'generated',
        'generatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 7, 2, 52, 29)),
      },
    };
    documents[_goldPath] = _gold();
    documents[_pointerPath] = {
      'reportId': 'personality_v1_body_activity',
      'petId': 'main_pet',
      'readyMetrics': ['body', 'activity'],
    };
    for (final metric in ['body', 'activity']) {
      documents['users/$_uid/analysis_readiness/$metric'] = {
        'currentStatus': 'ready',
        'validRecordCount': 8,
        'observationSpanDays': 14,
      };
    }
    // An expired trial and absent billing must not gate either owner report.
    documents['users/$_uid/feature_access/initial_trial_v2'] = {
      'status': 'expired',
      'endsAt': Timestamp.fromDate(DateTime.utc(2026, 9)),
    };
  }

  @override
  fp.FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) =>
      this;
  @override
  fp.DocumentReferencePlatform doc(String path) => _Document(this, path);
  @override
  fp.CollectionReferencePlatform collection(String path) =>
      _Collection(this, path);
  @override
  fp.Settings get settings => const fp.Settings();

  fp.DocumentSnapshotPlatform snapshot(String path) =>
      fp.DocumentSnapshotPlatform(
        this,
        path,
        documents[path] == null
            ? null
            : Map<String, dynamic>.from(documents[path]!),
        fp.PigeonSnapshotMetadata(
            hasPendingWrites: false, isFromCache: cachedPaths.contains(path)),
      );

  Stream<T> watch<T>(T Function() value) => Stream.multi((controller) {
        controller.add(value());
        final sub = changes.stream.listen((_) => controller.add(value()));
        controller.onCancel = sub.cancel;
      });

  void write(String path, Map<String, dynamic> data, fp.SetOptions? options) {
    writes.add(path);
    final resolved = <String, dynamic>{};
    for (final entry in data.entries) {
      // These tested methods only use the serverTimestamp sentinel.
      resolved[entry.key] = entry.value is fp.FieldValuePlatform
          ? Timestamp.fromMillisecondsSinceEpoch(1791200000000 + _clock++)
          : entry.value;
    }
    documents[path] = {
      if (options?.merge == true) ...?documents[path],
      ...resolved,
    };
    changes.add(null);
  }

  @override
  Future<T?> runTransaction<T>(
    fp.TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final previous = _transactions;
    final done = Completer<void>();
    _transactions = done.future;
    await previous;
    try {
      final transaction = _Transaction(this);
      final value = await handler(transaction);
      for (final write in transaction.writes) {
        this.write(write.$1, write.$2, write.$3);
      }
      return value;
    } finally {
      done.complete();
    }
  }
}

class _Transaction extends fp.TransactionPlatform {
  _Transaction(this.db);
  final _Firestore db;
  final writes = <(String, Map<String, dynamic>, fp.SetOptions?)>[];
  @override
  Future<fp.DocumentSnapshotPlatform> get(String path) async =>
      db.snapshot(path);
  @override
  fp.TransactionPlatform set(String path, Map<String, dynamic> data,
      [fp.SetOptions? options]) {
    writes.add((path, data, options));
    return this;
  }
}

class _Document extends fp.DocumentReferencePlatform {
  _Document(this.db, String path) : super(db, path);
  final _Firestore db;
  @override
  Future<fp.DocumentSnapshotPlatform> get(
          [fp.GetOptions options = const fp.GetOptions()]) async =>
      db.snapshot(path);
  @override
  Stream<fp.DocumentSnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required fp.ListenSource listenSource,
  }) =>
      db.watch(() {
        db.reads.add(path);
        return db.snapshot(path);
      });
  @override
  Future<void> set(Map<String, dynamic> data, [fp.SetOptions? options]) async =>
      db.write(path, data, options);
}

class _Collection extends fp.CollectionReferencePlatform {
  _Collection(this.db, String path) : super(db, path) {
    parameters.addAll({
      'where': [],
      'orderBy': [],
      'startAt': null,
      'startAfter': null,
      'endAt': null,
      'endBefore': null,
      'limit': null,
      'limitToLast': null
    });
  }
  final _Firestore db;
  @override
  bool get isCollectionGroupQuery => false;
  @override
  fp.DocumentReferencePlatform doc([String? name]) =>
      db.doc('$path/${name ?? 'fake-auto-id'}');

  _Collection _with(String key, dynamic value) {
    final result = _Collection(db, path);
    result.parameters.addAll(parameters);
    result.parameters[key] = value;
    return result;
  }

  @override
  fp.QueryPlatform orderBy(Iterable<List<dynamic>> orders) =>
      _with('orderBy', orders.toList());
  @override
  fp.QueryPlatform limit(int limit) => _with('limit', limit);
  @override
  fp.QueryPlatform where(List<List<dynamic>> conditions) =>
      _with('where', conditions);
  @override
  fp.QueryPlatform whereFilter(fp.FilterPlatformInterface filter) => this;

  fp.QuerySnapshotPlatform _snapshot() {
    final rows = db.documents.keys
        .where((key) =>
            key.startsWith('$path/') &&
            key.substring(path.length + 1).split('/').length == 1)
        .map(db.snapshot)
        .toList();
    final orders = parameters['orderBy'] as List;
    if (orders.isNotEmpty) {
      final order = orders.first as List;
      rows.sort((a, b) {
        final av = a.data()?[order[0]], bv = b.data()?[order[0]];
        if (av is Timestamp && bv is Timestamp) {
          final comparison = av.compareTo(bv);
          return order[1] == true ? -comparison : comparison;
        }
        return 0;
      });
    }
    final limit = parameters['limit'] as int?;
    return fp.QuerySnapshotPlatform(
      limit == null ? rows : rows.take(limit).toList(),
      [],
      fp.SnapshotMetadataPlatform(false, false),
    );
  }

  @override
  Future<fp.QuerySnapshotPlatform> get(
          [fp.GetOptions options = const fp.GetOptions()]) async =>
      _snapshot();
  @override
  Stream<fp.QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required fp.ListenSource listenSource,
  }) =>
      db.watch(_snapshot);
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _home(WidgetTester tester, _Observer observer) async {
  final completion = ValueNotifier<DailyRecordCompletion?>(null);
  addTearDown(completion.dispose);
  await tester.pumpWidget(MaterialApp(
    navigatorObservers: [observer],
    home: Scaffold(
        body: HomeScreen(
      recordCompletionListenable: completion,
      onTabSelected: (_) => throw StateError('Unexpected tab navigation'),
      onOpenAiWithDraft: (_) => throw StateError('AI is forbidden'),
    )),
  ));
  await _frames(tester);
}

Future<void> _openHistory(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(HomeScreen))).push(MaterialPageRoute(
      builder: (_) => const PersonalityReportHistoryScreen()));
  await _frames(tester);
}

Future<void> _openOld(WidgetTester tester) async {
  await _openHistory(tester);
  final button = find.text('初回コンディションレポート');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _frames(tester);
  expect(find.byType(PersonalizedReportScreen), findsOneWidget);
  expect(find.byType(PersonalityReportScreen), findsNothing);
  expect(find.text('初回レポート'), findsOneWidget);
  expect(find.text('対象指標: 体重'), findsOneWidget);
  expect(find.text('対象指標: 体重・活動量'), findsNothing);
  expect(find.text('改訂: 1'), findsOneWidget);
}

Future<void> _returnHome(WidgetTester tester) async {
  while (find.byType(HomeScreen).evaluate().isEmpty) {
    await tester.pageBack();
    await _frames(tester);
  }
}

Future<void> _openNew(WidgetTester tester) async {
  final button = find.text('個性レポートを見る');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _frames(tester);
  expect(find.byType(PersonalityReportScreen), findsOneWidget);
  expect(find.byType(PersonalizedReportScreen), findsNothing);
  expect(find.byKey(const ValueKey('personality-overview')), findsOneWidget);
  expect(find.text('100'), findsWidgets);
  await tester.scrollUntilVisible(find.byType(MetricComparisonBar), 200);
  final comparison =
      tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
  expect(comparison.value, 100);
  expect(comparison.referenceValue, 133);
  expect(comparison.referenceStart, 100);
  expect(comparison.referenceEnd, 160);
  expect(
      find.descendant(
          of: find.byKey(const ValueKey('body-comparison-delta')),
          matching: find.text('33g')),
      findsOneWidget);
  expect(
      find.descendant(
          of: find.byKey(const ValueKey('body-comparison-delta')),
          matching: find.text('軽め')),
      findsOneWidget);
  expect(
      find.descendant(
          of: find.byKey(const ValueKey('body-comparison-delta')),
          matching: find.text('参考中央値より')),
      findsOneWidget);
  await tester.scrollUntilVisible(find.text('活動量'), 200);
  expect(find.text('628'), findsWidgets);
  expect(find.text('m / 日'), findsOneWidget);
  expect(find.text('活動量はこれから'), findsNothing);
  expect(find.textContaining('無料体験を始める'), findsNothing);
  expect(find.textContaining('未契約'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  final db = _Firestore();
  HttpOverrides? previous;
  setUpAll(() {
    previous = HttpOverrides.current;
    HttpOverrides.global = _NoNetwork();
    cp.FirebasePlatform.instance = _Core();
    ap.FirebaseAuthPlatform.instance = _Auth();
    fp.FirebaseFirestorePlatform.instance = db;
  });
  setUp(db.reset);
  tearDownAll(() async {
    HttpOverrides.global = previous;
    await db.changes.close();
  });

  test('B-equivalent Gold retains unrounded measurements and both readiness',
      () {
    final report = PersonalityReport.fromMap(_gold());
    expect(report.reportId, 'personality_v1_body_activity');
    expect(report.body!.median, 100);
    final rawActivity = (_gold()['metrics'] as Map)['activity'] as Map;
    final rawMedian = (rawActivity['baseline'] as Map)['median'];
    expect(report.activity!.median, rawMedian);
    expect(report.activity!.latestValue, rawActivity['latestValue']);
    expect(report.activity!.median, closeTo(628.3185307, 0.0000001));
    expect(report.generatedAt, DateTime.utc(2026, 10, 8, 2));
    expect(report.activity!.firstDateKey, '2026-09-23');
    expect(report.activity!.lastDateKey, '2026-10-06');
    expect(report.activity!.recordCount, 8);
    expect(report.activity!.spanDays, 14);
  });

  testWidgets(
      'actual Home shows only latest unread and no constant old first after both ready',
      (tester) async {
    final observer = _Observer();
    await _home(tester, observer);
    expect(find.text('レポートを見る'), findsNothing);
    expect(find.text('個体別コンディション分析を準備中'), findsNothing);
    expect(find.text('新しい個性レポートが届きました'), findsOneWidget);
    expect(find.byType(PersonalityReportScreen), findsNothing);
    expect(observer.pushes, 1);
    expect(db.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'Home removes latest after actual viewing then displays next daily report',
      (tester) async {
    await _home(tester, _Observer());
    await _openNew(tester);
    await _returnHome(tester);
    expect(find.text('個性レポートを見る'), findsNothing);
    expect(
        db.documents[
                'users/$_uid/report_view_states/personality_v1_body_activity']![
            'viewedAt'],
        isA<Timestamp>());
    final next = _gold()
      ..['reportId'] = 'daily_2026-10-10'
      ..['evaluationDateKey'] = '2026-10-10'
      ..['silverDateKey'] = '2026-10-10'
      ..['cutoffDateKey'] = '2026-10-09'
      ..['reportKind'] = 'daily';
    db.documents['users/$_uid/personality_reports/daily_2026-10-10'] = next;
    db.documents[_dailyPointerPath] = {
      'reportId': 'daily_2026-10-10',
      'petId': 'main_pet'
    };
    db.changes.add(null);
    await _frames(tester);
    expect(find.text('新しい個性レポートが届きました'), findsOneWidget);
    expect(
        db.documents
            .containsKey('users/$_uid/report_view_states/daily_2026-10-10'),
        isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Home drawing is write-free; daily detail alone marks daily and hides it',
      (tester) async {
    final legacyBefore = _canonical(db.documents[_pointerPath]);
    final firstBefore = _canonical(db.documents[_firstPath]);
    final daily = _gold()
      ..['reportId'] = 'daily_2026-10-10'
      ..['evaluationDateKey'] = '2026-10-10'
      ..['silverDateKey'] = '2026-10-10'
      ..['cutoffDateKey'] = '2026-10-09'
      ..['reportKind'] = 'daily';
    const dailyReportPath = 'users/$_uid/personality_reports/daily_2026-10-10';
    const dailyViewPath = 'users/$_uid/report_view_states/daily_2026-10-10';
    db.documents[dailyReportPath] = daily;
    db.documents[_dailyPointerPath] = {
      'reportId': 'daily_2026-10-10',
      'petId': 'main_pet'
    };
    final dailyBefore = _canonical(daily);
    await _home(tester, _Observer());
    expect(find.text('新しい個性レポートが届きました'), findsOneWidget);
    expect(db.writes, isEmpty);
    expect(db.documents.containsKey(dailyViewPath), isFalse);
    await _openNew(tester);
    expect(db.documents[dailyViewPath]!['reportId'], 'daily_2026-10-10');
    expect(db.documents[dailyViewPath]!['viewedAt'], isA<Timestamp>());
    await _returnHome(tester);
    expect(find.text('個性レポートを見る'), findsNothing);
    expect(_canonical(db.documents[_pointerPath]), legacyBefore);
    expect(_canonical(db.documents[dailyReportPath]), dailyBefore);
    expect(_canonical(db.documents[_firstPath]), firstBefore);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'viewing old history does not create latest daily view or consume Home unread',
      (tester) async {
    final daily = _gold()
      ..['reportId'] = 'daily_2026-10-10'
      ..['evaluationDateKey'] = '2026-10-10'
      ..['silverDateKey'] = '2026-10-10'
      ..['cutoffDateKey'] = '2026-10-09'
      ..['reportKind'] = 'daily';
    db.documents['users/$_uid/personality_reports/daily_2026-10-10'] = daily;
    db.documents[_dailyPointerPath] = {
      'reportId': 'daily_2026-10-10',
      'petId': 'main_pet'
    };
    await _home(tester, _Observer());
    expect(db.writes, isEmpty);
    await _openHistory(tester);
    await tester.ensureVisible(find.text('個性レポート'));
    await tester.tap(find.text('個性レポート'));
    await _frames(tester);
    expect(
        db.documents.containsKey(
            'users/$_uid/report_view_states/personality_v1_body_activity'),
        isTrue);
    expect(
        db.documents
            .containsKey('users/$_uid/report_view_states/daily_2026-10-10'),
        isFalse);
    await _returnHome(tester);
    expect(find.text('個性レポートを見る'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'Home cached missing daily never shows fallback; confirmed missing does',
      (tester) async {
    db.cachedPaths.add(_dailyPointerPath);
    await _home(tester, _Observer());
    expect(find.text('個性レポートを見る'), findsNothing);
    expect(db.writes, isEmpty);
    db.cachedPaths.remove(_dailyPointerPath);
    db.changes.add(null);
    await _frames(tester);
    expect(find.text('個性レポートを見る'), findsOneWidget);
    expect(db.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'Home has no report without latest or without server-confirmed read marker',
      (tester) async {
    db.documents.remove(_pointerPath);
    await _home(tester, _Observer());
    expect(find.text('個性レポートを見る'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    db.documents[_pointerPath] = {
      'reportId': 'personality_v1_body_activity',
      'petId': 'main_pet'
    };
    final marker =
        'users/$_uid/report_view_states/personality_v1_body_activity';
    db.cachedPaths.add(marker);
    await _home(tester, _Observer());
    expect(find.text('個性レポートを見る'), findsNothing);
    db.cachedPaths.remove(marker);
    db.changes.add(null);
    await _frames(tester);
    expect(find.text('個性レポートを見る'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('actual Home keeps health alert and anomaly before unread report',
      (tester) async {
    db.documents['users/$_uid/health_assessments/latest'] = {
      'dateKey': '2026-10-10',
      'overall': {'state': 'alert', 'observedState': 'alert', 'score': 30}
    };
    db.documents['users/$_uid/environment_assessments_history/2026-10-09'] = {
      'dateKey': '2026-10-09',
      'avgTemp': 25,
      'avgHum': 50,
      'dangerMinutes': 60,
      'level': '危険'
    };
    await _home(tester, _Observer());
    final report = find.text('新しい個性レポートが届きました');
    expect(find.text('総合コンディション'), findsOneWidget);
    expect(find.text('最近の気になる変化'), findsOneWidget);
    expect(tester.getTopLeft(find.text('総合コンディション')).dy,
        lessThan(tester.getTopLeft(report).dy));
    expect(tester.getTopLeft(find.text('最近の気になる変化')).dy,
        lessThan(tester.getTopLeft(report).dy));
    expect(db.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'actual Emulator body-only Gold keeps missing activity progress and immutable detail',
      (tester) async {
    final body = _gold('body');
    final path = 'users/$_uid/personality_reports/personality_v1_body';
    db.documents[path] = body;
    db.documents[_pointerPath] = {
      'reportId': 'personality_v1_body',
      'petId': 'main_pet'
    };
    db.documents['users/$_uid/analysis_readiness/activity'] = {
      'currentStatus': 'learning',
      'validRecordCount': 5,
      'observationSpanDays': 5
    };
    final before = _canonical(body),
        firstBefore = _canonical(db.documents[_firstPath]);
    await _home(tester, _Observer());
    expect(find.textContaining('活動量: 有効記録 5/7'), findsOneWidget);
    await tester.ensureVisible(find.text('個性レポートを見る'));
    await tester.tap(find.text('個性レポートを見る'));
    await _frames(tester);
    expect(find.byKey(const ValueKey('personality-overview')), findsOneWidget);
    expect(find.text('100'), findsWidgets);
    await tester.scrollUntilVisible(find.text('活動量はこれから'), 200);
    expect(find.text('活動量'), findsNothing);
    expect(_canonical(db.documents[path]), before);
    expect(_canonical(db.documents[_firstPath]), firstBefore);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'pointer upgrade never replaces an open immutable history; latest unread remains',
      (tester) async {
    final path = 'users/$_uid/personality_reports/personality_v1_body';
    db.documents[path] = _gold('body');
    db.documents[_pointerPath] = {
      'reportId': 'personality_v1_body',
      'petId': 'main_pet'
    };
    final before = _canonical(db.documents[path]),
        firstBefore = _canonical(db.documents[_firstPath]);
    await _home(tester, _Observer());
    await tester.ensureVisible(find.text('個性レポートを見る'));
    await tester.tap(find.text('個性レポートを見る'));
    await _frames(tester);
    db.documents[_pointerPath] = {
      'reportId': 'personality_v1_body_activity',
      'petId': 'main_pet'
    };
    db.changes.add(null);
    await _frames(tester);
    expect(find.byKey(const ValueKey('personality-body-card')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('personality-activity-card')), findsNothing);
    await _returnHome(tester);
    expect(find.text('個性レポートを見る'), findsOneWidget);
    await _openNew(tester);
    expect(_canonical(db.documents[path]), before);
    expect(_canonical(db.documents[_firstPath]), firstBefore);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'actual MainDrawer report history callback leaves all other entries available',
      (tester) async {
    final completion = ValueNotifier<DailyRecordCompletion?>(null);
    addTearDown(completion.dispose);
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MainDrawer(
                recordCompletionListenable: completion,
                onSelectScreen: (value) => selected = value))));
    await _frames(tester);
    await tester.ensureVisible(find.text('レポート履歴'));
    await tester.tap(find.text('レポート履歴'));
    expect(selected, 'report_history');
    expect(find.text('記録する'), findsOneWidget);
    expect(find.text('ペットのプロフィール'), findsOneWidget);
    expect(find.text('アプリの設定'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'legacy absent in server shows empty state, not permanent spinner',
      (tester) async {
    db.documents.remove(_firstPath);
    await _home(tester, _Observer());
    await _openHistory(tester);
    await tester.tap(find.text('初回コンディションレポート'));
    await _frames(tester);
    expect(find.text('初回レポートはまだありません'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(db.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final newFirst in [false, true]) {
    testWidgets(
        'Home and old first history preserve frozen documents and earliest A3 in either order $newFirst',
        (tester) async {
      final firstBefore = _canonical(db.documents[_firstPath]),
          goldBefore = _canonical(db.documents[_goldPath]),
          pointerBefore = _canonical(db.documents[_pointerPath]);
      final observer = _Observer();
      await _home(tester, observer);
      if (newFirst) {
        await _openNew(tester);
      } else {
        await _openOld(tester);
      }
      final earliest =
          db.documents[_statePath]!['firstPersonalizedAnalysisViewedAt'];
      expect(earliest, isA<Timestamp>());
      if (!newFirst) {
        expect(db.documents[_statePath]!['firstPersonalityReportViewedAt'],
            isNull);
      }
      await _returnHome(tester);
      if (newFirst) {
        await _openOld(tester);
      } else {
        await _openNew(tester);
      }
      expect(db.documents[_statePath]!['firstPersonalizedAnalysisViewedAt'],
          earliest);
      expect(db.documents[_statePath]!['firstPersonalityReportViewedAt'],
          isA<Timestamp>());
      expect(_canonical(db.documents[_firstPath]), firstBefore);
      expect(_canonical(db.documents[_goldPath]), goldBefore);
      expect(_canonical(db.documents[_pointerPath]), pointerBefore);
      expect(
          db.writes.every((path) =>
              path == _statePath ||
              path.startsWith('users/$_uid/report_view_states/')),
          isTrue);
      expect(db.documents[_statePath]!['firstAiConsultationCompleted'], isTrue);
      expect(db.documents[_statePath]!['firstMonitoringDataSource'],
          'daily_checkin');
      expect(db.documents.containsKey('users/$_uid/billing/subscription'),
          isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
