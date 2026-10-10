// FlutterFire platform fakes use the interfaces already installed with the SDK.
// No Firebase initialization against a real project or external HTTP is allowed.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart'
    as fu;
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fp;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as ap;
import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart'
    as ac;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    as cp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/screens/monitoring_introduction_screen.dart';
import 'package:hamster_project/screens/search_function.dart';
import 'package:hamster_project/screens/tabs.dart';
import 'package:hamster_project/services/onboarding_state_repo.dart';
import 'package:hamster_project/widgets/floating_bottom_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _uid = 'onboarding-widget-test';
const _statePath = 'users/$_uid/app_state/onboarding';
const _cta = '次へ：記録を始める';
const _answer = 'テスト用AI回答です。落ち着いて読んでください。';
const _ctaKey = ValueKey('monitoring-intro-cta');

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

class _AppCheck extends ac.FirebaseAppCheckPlatform {
  @override
  ac.FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  ac.FirebaseAppCheckPlatform setInitialValues() => this;
  @override
  Future<String?> getToken(bool forceRefresh) async => 'fake-app-check-token';
}

class _Functions extends fu.FirebaseFunctionsPlatform {
  _Functions() : super(null, 'asia-northeast1');
  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;
  @override
  fu.HttpsCallablePlatform httpsCallable(
      String? origin, String name, fu.HttpsCallableOptions options) {
    // Tabs claims an open-star on mount; any unrelated callable is forbidden.
    expect(name, 'claimDailyOpenStar');
    return _Callable(this, origin, name, options);
  }
}

class _Callable extends fu.HttpsCallablePlatform {
  _Callable(fu.FirebaseFunctionsPlatform functions, String? origin, String name,
      fu.HttpsCallableOptions options)
      : super(functions, origin, name, options, null);
  @override
  Future<dynamic> call([dynamic parameters]) async => <String, dynamic>{};
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

  void reset({bool guided = true, bool pending = false, bool paid = false}) {
    // Never retain a Future tied to a previous widget test's fake clock.
    _transactions = Future.value();
    documents.clear();
    documents[_statePath] = {
      'introCompleted': true,
      'setupChecklistViewed': true,
      'setupCoachMarkStep': 3,
      'completedSetupSteps': ['pet', 'environment', 'owner'],
      'firstAiConsultationCompleted': pending,
      'homeAiOnboardingPending': guided && !pending,
      'monitoringIntroCtaPending': pending,
    };
    if (paid) {
      documents['users/$_uid/billing/subscription'] = {
        'plan': 'paid',
        'status': 'active',
        'currentPeriodEnd':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      };
    } else {
      documents['users/$_uid/feature_access/initial_trial_v2'] = {
        'policyVersion': 'initial_trial_v2',
        'status': 'active',
        'endsAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 21))),
        'aiRequestLimit': 20,
        'aiRequestUsed': 0,
      };
    }
  }

  Map<String, dynamic> get onboarding => documents[_statePath]!;
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
        fp.PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
      );

  Stream<T> watch<T>(T Function() value) => Stream.multi((controller) {
        controller.add(value());
        final sub = changes.stream.listen((_) => controller.add(value()));
        controller.onCancel = sub.cancel;
      });

  void write(String path, Map<String, dynamic> data, fp.SetOptions? options) {
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
      db.watch(() => db.snapshot(path));
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
    // Drain futures created before the widget test's fake clock (analytics).
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final tabs = GlobalKey<TabsScreenState>();
  final observer = _Observer();
  int requests = 0;
  Completer<http.Response>? response;
  bool fail = false;
  late final client = MockClient((request) async {
    expect(request.method, 'POST');
    expect(request.url.path, '/chat');
    requests++;
    return response?.future ??
        http.Response(
          fail ? '{}' : jsonEncode({'answer': _answer, 'chunks': []}),
          fail ? 500 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [observer],
      home: TabsScreen(key: tabs),
    ));
    // Select the real consultation tab before the delayed Home coach can run.
    tester
        .widget<FloatingBottomNavigation>(find.byType(FloatingBottomNavigation))
        .onTabSelected(1);
    await _frames(tester);
  }

  Future<void> send(WidgetTester tester) async {
    tester
        .state<FuncSearchScreenState>(find.byType(FuncSearchScreen))
        .setDraftText('テストの質問', focus: false);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _frames(tester);
  }

  Future<void> tapCta(WidgetTester tester) async {
    await tester.ensureVisible(find.text(_cta));
    await tester.tap(find.text(_cta));
    await _frames(tester);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = _Firestore();
  final oldHttpOverrides = HttpOverrides.current;
  setUpAll(() {
    HttpOverrides.global = _NoNetwork();
    cp.FirebasePlatform.instance = _Core();
    ap.FirebaseAuthPlatform.instance = _Auth();
    ac.FirebaseAppCheckPlatform.instance = _AppCheck();
    fp.FirebaseFirestorePlatform.instance = db;
    fu.FirebaseFunctionsPlatform.instance = _Functions();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            (call) async => null);
  });
  setUp(() => db.reset());
  tearDownAll(() async {
    HttpOverrides.global = oldHttpOverrides;
    await db.changes.close();
  });

  test(
      'first guided success persists A1 and pending without changing monitoring fields',
      () async {
    final initialTime = Timestamp.fromDate(DateTime(2026, 10, 1));
    db.onboarding.addAll({
      'monitoringMethod': 'weight',
      'monitoringMethodSelectedAt': initialTime,
      'firstMonitoringDataRecordedAt': initialTime,
      'firstMonitoringDataSource': 'weight',
    });
    await OnboardingStateRepo().markFirstAiConsultationCompleted();
    final state = await OnboardingStateRepo().fetchState();
    expect(state.firstAiConsultationCompleted, isTrue);
    expect(state.homeAiOnboardingPending, isFalse);
    expect(state.monitoringIntroCtaPending, isTrue);
    expect(state.monitoringIntroductionViewedAt, isNull);
    expect(state.monitoringMethod, 'weight');
    expect(state.monitoringMethodSelectedAt, initialTime.toDate().toLocal());
    expect(state.firstMonitoringDataRecordedAt, initialTime.toDate().toLocal());
    expect(state.firstMonitoringDataSource, 'weight');
  });

  test('repeat success preserves pending and never rearms consumed pending',
      () async {
    final repo = OnboardingStateRepo();
    await repo.markFirstAiConsultationCompleted();
    await repo.markFirstAiConsultationCompleted();
    expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
    await repo.markMonitoringIntroductionViewed();
    final viewedAt = db.onboarding['monitoringIntroductionViewedAt'];
    await repo.markFirstAiConsultationCompleted();
    expect(db.onboarding['monitoringIntroCtaPending'], isFalse);
    expect(db.onboarding['monitoringIntroductionViewedAt'], viewedAt);
  });

  test(
      'method selection and first monitoring record keep their existing semantics',
      () async {
    final repo = OnboardingStateRepo();
    await repo.markFirstAiConsultationCompleted();
    await repo.markMonitoringIntroductionViewed();
    await repo.selectMonitoringMethod('daily_checkin');
    await repo.recordFirstMonitoringData('daily_checkin');
    final firstRecordedAt = db.onboarding['firstMonitoringDataRecordedAt'];
    await repo.recordFirstMonitoringData('weight');
    final state = await repo.fetchState();
    expect(state.monitoringIntroCtaPending, isFalse);
    expect(state.monitoringIntroductionViewedAt, isNotNull);
    expect(state.monitoringMethod, 'daily_checkin');
    expect(state.monitoringMethodSelectedAt, isNotNull);
    expect(state.firstMonitoringDataRecordedAt,
        firstRecordedAt.toDate().toLocal());
    expect(state.firstMonitoringDataSource, 'daily_checkin');
    expect(state.hasStartedMonitoring, isTrue);
  });

  testWidgets('guided AI success leaves answer and one CTA without navigating',
      (tester) async {
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      final pushes = h.observer.pushes;
      await h.send(tester);
      expect(h.requests, 1);
      expect(db.onboarding['firstAiConsultationCompleted'], isTrue);
      expect(db.onboarding['homeAiOnboardingPending'], isFalse);
      expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
      expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
      expect(find.textContaining(_answer), findsOneWidget);
      expect(find.byKey(_ctaKey), findsOneWidget);
      expect(h.observer.pushes, pushes);
      expect(find.byType(MonitoringIntroductionScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets('CTA is hidden during generation and appears only after success',
      (tester) async {
    db.reset(pending: true);
    final h = _Harness()..response = Completer<http.Response>();
    await http.runWithClient(() async {
      await h.mount(tester);
      expect(find.byKey(_ctaKey), findsOneWidget);
      await h.send(tester);
      expect(find.byKey(_ctaKey, skipOffstage: false), findsNothing);
      expect(db.onboarding['firstAiConsultationCompleted'], isTrue);
      h.response!.complete(http.Response(
        jsonEncode({'answer': _answer, 'chunks': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));
      await _frames(tester);
      expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
      expect(find.textContaining(_answer), findsOneWidget);
      expect(find.byKey(_ctaKey), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets(
      'AI failure preserves error UI, leaves A1/pending false and never navigates',
      (tester) async {
    final h = _Harness()..fail = true;
    await http.runWithClient(() async {
      await h.mount(tester);
      final pushes = h.observer.pushes;
      await h.send(tester);
      expect(db.onboarding['firstAiConsultationCompleted'], isFalse);
      expect(db.onboarding['monitoringIntroCtaPending'], isFalse);
      expect(find.byKey(_ctaKey), findsNothing);
      expect(find.textContaining('エラー:'), findsOneWidget);
      expect(h.observer.pushes, pushes);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets('double CTA press pushes once and back preserves pending/CTA',
      (tester) async {
    db.reset(pending: true);
    final h = _Harness();
    await h.mount(tester);
    await tester.ensureVisible(find.text(_cta));
    final button = tester.widget<FilledButton>(find.ancestor(
      of: find.text(_cta),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    ));
    final pushes = h.observer.pushes;
    button.onPressed!();
    button.onPressed!();
    await _frames(tester);
    expect(find.byType(MonitoringIntroductionScreen), findsOneWidget);
    expect(h.observer.pushes, pushes + 1);
    expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
    h.navigator.currentState!.pop();
    await _frames(tester);
    expect(find.byKey(_ctaKey), findsOneWidget);
    expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets(
      'record-method button clears pending in the same write as intro viewed',
      (tester) async {
    db.reset(pending: true);
    final h = _Harness();
    await h.mount(tester);
    await h.tapCta(tester);
    await tester.tap(find.text('記録方法を選ぶ'));
    await _frames(tester);
    expect(db.onboarding['monitoringIntroCtaPending'], isFalse);
    expect(db.onboarding['monitoringIntroductionViewedAt'], isA<Timestamp>());
    expect(db.onboarding['monitoringMethodSelectedAt'], isNull);
    expect(db.onboarding['firstMonitoringDataRecordedAt'], isNull);
    expect(find.byType(MonitoringMethodSelectionScreen), findsOneWidget);
    h.navigator.currentState!.popUntil((route) => route.isFirst);
    await _frames(tester);
    expect(find.byKey(_ctaKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets(
      'pending CTA is restored after leaving and returning to consultation tab',
      (tester) async {
    db.reset(pending: true);
    final h = _Harness();
    await h.mount(tester);
    expect(find.byKey(_ctaKey), findsOneWidget);
    tester
        .widget<FloatingBottomNavigation>(find.byType(FloatingBottomNavigation))
        .onTabSelected(2);
    await _frames(tester);
    expect(find.byType(FuncSearchScreen), findsNothing);
    tester
        .widget<FloatingBottomNavigation>(find.byType(FloatingBottomNavigation))
        .onTabSelected(1);
    await _frames(tester);
    expect(find.byKey(_ctaKey), findsOneWidget);
    expect(find.byType(MonitoringIntroductionScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets(
      'widget restart restores persisted pending and answer without navigation',
      (tester) async {
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
      final restarted = _Harness();
      await restarted.mount(tester);
      expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
      // The restored-history card can leave the bottom CTA outside the viewport.
      // It must still exist once, and remain available by scrolling to it.
      final restoredCta = find.byKey(_ctaKey, skipOffstage: false);
      expect(restoredCta, findsOneWidget);
      await tester.ensureVisible(restoredCta);
      await _frames(tester);
      expect(find.textContaining(_answer), findsOneWidget);
      expect(find.byKey(_ctaKey), findsOneWidget);
      expect(find.byType(MonitoringIntroductionScreen), findsNothing);
      expect(restarted.observer.pushes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets(
      'later answers keep exactly one pending CTA; consumed CTA does not return',
      (tester) async {
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester);
      await h.send(tester);
      expect(h.requests, 2);
      expect(find.byKey(_ctaKey), findsOneWidget);
      await OnboardingStateRepo().markMonitoringIntroductionViewed();
      await _frames(tester);
      await h.send(tester);
      expect(h.requests, 3);
      expect(find.byKey(_ctaKey), findsNothing);
      expect(find.byType(MonitoringIntroductionScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets('ordinary paid first success never creates CTA or navigation',
      (tester) async {
    db.reset(guided: false, paid: true);
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      final pushes = h.observer.pushes;
      await h.send(tester);
      expect(db.onboarding['firstAiConsultationCompleted'], isTrue);
      expect(db.onboarding['monitoringIntroCtaPending'], isFalse);
      expect(find.textContaining(_answer), findsOneWidget);
      expect(find.byKey(_ctaKey), findsNothing);
      expect(h.observer.pushes, pushes);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });
}
