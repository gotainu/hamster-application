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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:hamster_project/screens/breeding_environment_edit_screen.dart';
import 'package:hamster_project/screens/monitoring_introduction_screen.dart';
import 'package:hamster_project/screens/search_function.dart';
import 'package:hamster_project/screens/tabs.dart';
import 'package:hamster_project/services/onboarding_state_repo.dart';
import 'package:hamster_project/services/app_analytics.dart';
import 'package:hamster_project/services/ai_access_failure.dart';
import 'package:hamster_project/services/ai_text_consent_store.dart';
import 'package:hamster_project/services/pet_profile_repo.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/screens/pet_profile_edit_screen.dart';
import 'package:hamster_project/widgets/weight_input_card.dart';
import 'package:hamster_project/widgets/shine_border.dart';
import 'package:hamster_project/widgets/floating_bottom_navigation.dart';
import 'package:hamster_project/widgets/paid_feature_gate.dart';
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

class _UnavailableStorage extends TestFlutterSecureStoragePlatform {
  _UnavailableStorage({this.failRead = false, this.failWrite = false})
      : super({});
  final bool failRead;
  final bool failWrite;
  @override
  Future<String?> read(
      {required String key, required Map<String, String> options}) async {
    if (failRead) {
      throw PlatformException(code: 'synthetic_private_storage_error');
    }
    return super.read(key: key, options: options);
  }

  @override
  Future<void> write(
      {required String key,
      required String value,
      required Map<String, String> options}) async {
    if (failWrite) {
      throw PlatformException(code: 'synthetic_private_storage_error');
    }
    return super.write(key: key, value: value, options: options);
  }
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
  static String activeUid = _uid;
  static Completer<void>? tokenBarrier;
  ap.UserPlatform get _user => _User(this, activeUid);
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
  // FlutterFire caches its delegate. Dispatch through the same fixture adapter
  // rather than replacing a cached adapter between widget test cases.
  static _JourneyFunctions? journey;
  static fu.FirebaseFunctionsException? trialStartError;
  static int trialStartCalls = 0;
  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;
  @override
  fu.HttpsCallablePlatform httpsCallable(
      String? origin, String name, fu.HttpsCallableOptions options) {
    if (journey != null) {
      return _JourneyCallable(journey!, origin, name, options);
    }
    // Tabs claims an open-star on mount; any unrelated callable is forbidden.
    expect(name, anyOf('claimDailyOpenStar', 'startInitialTrial'));
    return _Callable(this, origin, name, options);
  }
}

class _Callable extends fu.HttpsCallablePlatform {
  _Callable(fu.FirebaseFunctionsPlatform functions, String? origin, String name,
      fu.HttpsCallableOptions options)
      : super(functions, origin, name, options, null);
  @override
  Future<dynamic> call([dynamic parameters]) async {
    if (name == 'startInitialTrial') {
      _Functions.trialStartCalls++;
      final error = _Functions.trialStartError;
      if (error != null) throw error;
    }
    return <String, dynamic>{};
  }
}

class _MultiFactor extends ap.MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends ap.UserPlatform {
  _User(ap.FirebaseAuthPlatform auth, String uid)
      : super(
            auth,
            _MultiFactor(auth),
            ap.PigeonUserDetails(
              userInfo: ap.PigeonUserInfo(
                uid: uid,
                isAnonymous: false,
                isEmailVerified: false,
              ),
              providerData: [],
            ));
  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    final barrier = _Auth.tokenBarrier;
    if (barrier != null) await barrier.future;
    return 'fake-id-token-$uid';
  }
}

/// A fake backend shared across widget recreation. All writes stay in memory.
class _Firestore extends fp.FirebaseFirestorePlatform {
  final documents = <String, Map<String, dynamic>>{};
  final changes = StreamController<void>.broadcast(sync: true);
  Future<void>? _transactions;
  int _clock = 0;
  String? pausedWriteRole;
  Completer<void>? writeBarrier;

  void reset({bool guided = true, bool pending = false, bool paid = false}) {
    // No completed Future created outside the widget clock is awaited later.
    _transactions = null;
    pausedWriteRole = null;
    writeBarrier = null;
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
    if (previous != null) await previous;
    try {
      final transaction = _Transaction(this);
      final value = await handler(transaction);
      for (final write in transaction.writes) {
        this.write(write.$1, write.$2, write.$3);
      }
      return value;
    } finally {
      done.complete();
      if (identical(_transactions, done.future)) _transactions = null;
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
  Future<void> set(Map<String, dynamic> data, [fp.SetOptions? options]) async {
    final barrier = db.writeBarrier;
    if (barrier != null && data['role'] == db.pausedWriteRole) {
      await barrier.future;
    }
    db.write(path, data, options);
  }
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
    // These adapters are entirely in-memory: keep their futures and animation
    // frames in the widget test clock rather than crossing real/fake zones.
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final tabs = GlobalKey<TabsScreenState>();
  final observer = _Observer();
  int requests = 0;
  int networkFailuresRemaining = 0;
  final requestBodies = <String>[];
  final requestHeaders = <Map<String, String>>[];
  Completer<http.Response>? response;
  bool fail = false;
  int? errorStatus;
  Map<String, dynamic>? errorBody;
  late final client = MockClient((request) async {
    expect(request.method, 'POST');
    expect(request.url.path, '/chat');
    requests++;
    requestBodies.add(request.body);
    requestHeaders.add(Map<String, String>.from(request.headers));
    if (networkFailuresRemaining > 0) {
      networkFailuresRemaining--;
      throw http.ClientException('synthetic transport failure');
    }
    return response?.future ??
        http.Response(
          errorBody != null
              ? jsonEncode(errorBody)
              : fail
                  ? '{}'
                  : jsonEncode({'answer': _answer, 'chunks': []}),
          errorStatus ?? (fail ? 500 : 200),
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

  Future<void> send(WidgetTester tester, {String text = 'テストの質問'}) async {
    tester
        .state<FuncSearchScreenState>(find.byType(FuncSearchScreen))
        .setDraftText(text, focus: false);
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

/// Reuses this suite's in-memory FlutterFire adapters for real Tabs navigation.
/// The navigation suite injects its own callable replies; no real Firebase
/// initialization or external network is permitted.
({
  Map<String, Map<String, dynamic>> documents,
  VoidCallback notify,
  Future<void> Function() close
}) installRecordCalendarWidgetBackend({
  required fu.FirebaseFunctionsPlatform functions,
}) {
  final db = _Firestore()..reset(guided: false);
  final previousOverrides = HttpOverrides.current;
  HttpOverrides.global = _NoNetwork();
  cp.FirebasePlatform.instance = _Core();
  ap.FirebaseAuthPlatform.instance = _Auth();
  ac.FirebaseAppCheckPlatform.instance = _AppCheck();
  fp.FirebaseFirestorePlatform.instance = db;
  fu.FirebaseFunctionsPlatform.instance = functions;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null);
  return (
    documents: db.documents,
    notify: () => db.changes.add(null),
    close: () async {
      HttpOverrides.global = previousOverrides;
      await db.changes.close();
    },
  );
}

class _ReadOnlyProfileRepo extends PetProfileRepo {
  PetProfile? profile;
  bool fail = false;
  int reads = 0;
  @override
  Future<PetProfile?> fetchMainPet() async {
    reads++;
    if (fail) throw StateError('synthetic_profile_read_failed');
    return profile;
  }

  @override
  Future<PetProfile?> fetchPendingProfile() async => null;
}

/// UI-only receipts: every callable and current document stays in this fixture.
/// This is not a server integration test or a call to the AI/Stripe/Firebase.
class _JourneyFunctions extends fu.FirebaseFunctionsPlatform {
  _JourneyFunctions(this.db) : super(null, 'asia-northeast1');
  final _Firestore db;
  final calls = <({String name, Map<String, dynamic> request})>[];

  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;

  @override
  fu.HttpsCallablePlatform httpsCallable(
          String? origin, String name, fu.HttpsCallableOptions options) =>
      _JourneyCallable(this, origin, name, options);

  Future<Map<String, dynamic>> submit(
      String name, Map<String, dynamic> request) async {
    if (name == 'claimDailyOpenStar') return {};
    calls.add((name: name, request: request));
    final revision = (request['expectedRevision'] as int? ?? 0) + 1;
    const acceptedAt = '2026-10-17T01:00:00.123Z';
    switch (name) {
      case 'saveMainPetProfile':
        db.write(
            'users/$_uid/pet_profiles/main_pet',
            {
              ...Map<String, dynamic>.from(request['values'] as Map),
              'subjectId': 'journey-synthetic-subject',
              'revision': revision,
            },
            null);
        return {
          'subjectId': 'journey-synthetic-subject',
          'revision': revision,
          'acceptedAt': acceptedAt,
          'mutationId': request['mutationId'],
        };
      case 'saveBreedingEnvironment':
        db.write(
            'users/$_uid/breeding_environments/main_env',
            {
              ...Map<String, dynamic>.from(request['values'] as Map),
              'revision': revision,
            },
            null);
        return {
          'saved': true,
          'changed': true,
          'revision': revision,
          'acceptedAt': acceptedAt,
          'mutationId': request['mutationId'],
        };
      case 'saveWeightRecord':
      case 'saveDistanceRecord':
        final kind = name == 'saveWeightRecord' ? 'weight' : 'distance';
        if (kind == 'distance') {
          // The real server selects the confirmed environment diameter; a
          // normal rotations request does not trust a client-computed distance.
          expect(request['mode'], 'rotations');
          expect(
              db.documents['users/$_uid/breeding_environments/main_env']![
                  'wheelDiameter'],
              '28');
        }
        final projection = <String, dynamic>{
          'dayKey': request['dayKey'],
          'date': request['date'],
          'subjectId': request['subjectId'],
          'recordId': 'journey-$kind-record',
          'revision': revision,
          'timing': request['timing'],
          if (kind == 'weight') ...{
            'weightGrams': request['weightGrams'],
            'memo': request['memo'],
          } else ...{
            'rotations': request['rotations'],
            'distance': 87.96459430051421,
            'wheelDiameterCm': 28.0,
          }
        };
        db.write(
            'users/$_uid/${kind}_records/${request['dayKey']}',
            {
              ...projection,
              'date':
                  Timestamp.fromDate(DateTime.parse(request['date'] as String)),
            },
            null);
        return {
          'saved': true,
          'replayed': false,
          'changed': true,
          'subjectId': request['subjectId'],
          'dayKey': request['dayKey'],
          'recordId': projection['recordId'],
          'revision': revision,
          'recordStatus': 'active',
          'projection': projection,
          'acceptedAt': acceptedAt,
          'mutationId': request['mutationId'],
        };
      default:
        throw TestFailure('Unexpected callable in local journey: $name');
    }
  }
}

class _JourneyCallable extends fu.HttpsCallablePlatform {
  _JourneyCallable(this.backend, String? origin, this.callableName,
      fu.HttpsCallableOptions options)
      : super(backend, origin, callableName, options, null);
  final _JourneyFunctions backend;
  final String callableName;
  @override
  Future<dynamic> call([dynamic parameters]) => backend.submit(
      callableName, Map<String, dynamic>.from(parameters as Map? ?? const {}));
}

void _seedJourneyProfile(_Firestore db) {
  db.documents['users/$_uid/pet_profiles/main_pet'] = {
    'name': '架空の子',
    'species': 'シリアン',
    'birthdayPrecision': 'unknown',
    'subjectId': 'journey-synthetic-subject',
    'revision': 1,
  };
}

Future<void> _openFirstMethod(
    WidgetTester tester, _Harness harness, String title) async {
  await harness.mount(tester);
  await harness.send(tester);
  expect(harness.requests, 1);
  expect(find.byKey(_ctaKey), findsOneWidget);
  await harness.tapCta(tester);
  expect(find.byType(MonitoringIntroductionScreen), findsOneWidget);
  await tester.ensureVisible(find.text('記録方法を選ぶ'));
  await tester.tap(find.text('記録方法を選ぶ'));
  await _frames(tester);
  expect(find.byType(MonitoringMethodSelectionScreen), findsOneWidget);
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title));
  await _frames(tester);
  expect(find.byType(FirstMonitoringRecordScreen), findsOneWidget);
}

void _assertReturnedAfterReceipt(_Firestore db) {
  expect(find.byType(TabsScreen), findsOneWidget);
  expect(find.byType(FirstMonitoringRecordScreen), findsNothing);
  expect(find.byType(MonitoringIntroductionScreen), findsNothing);
  expect(find.byType(PetProfileEditScreen), findsNothing);
  expect(db.onboarding['monitoringIntroCtaPending'], isFalse);
  expect(db.onboarding['monitoringIntroductionViewedAt'], isA<Timestamp>());
  expect(db.onboarding['firstMonitoringDataRecordedAt'], isA<Timestamp>());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = _Firestore();
  final oldHttpOverrides = HttpOverrides.current;
  setUpAll(() async {
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
    // Keep the shared Analytics identity barrier in the real test zone, not
    // the first case's FakeAsync clock. No SDK/network event can be sent while
    // the Analytics identity is unconfirmed.
    await AppAnalytics.logHomeView(source: 'synthetic_fixture_initialization');
  });
  setUp(() async {
    db.reset();
    _Auth.activeUid = _uid;
    _Auth.tokenBarrier = null;
    FlutterSecureStorage.setMockInitialValues({});
    await AiTextConsentStore().accept(_uid);
    _Functions.trialStartError = null;
    _Functions.trialStartCalls = 0;
  });
  tearDownAll(() async {
    HttpOverrides.global = oldHttpOverrides;
    await db.changes.close();
  });

  for (final setupComplete in [true, false]) {
    testWidgets(
        'local journey ${setupComplete ? 'completed' : 'partial skipped'} setup: mock A1 to first weight receipt and return',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      db.reset(guided: setupComplete);
      db.onboarding['completedSetupSteps'] =
          setupComplete ? ['pet', 'environment', 'owner'] : ['owner'];
      db.documents['users/$_uid/owner_profiles/main'] = {
        'prefecture': '東京都',
        'municipality': '架空市',
      };
      if (setupComplete) {
        _seedJourneyProfile(db);
        db.documents['users/$_uid/breeding_environments/main_env'] = {
          'wheelDiameter': '20',
          'cageWidth': '60',
          'cageDepth': '40',
          'revision': 1,
        };
      }
      FlutterSecureStorage.setMockInitialValues({});
      await AiTextConsentStore().accept(_uid);
      final functions = _JourneyFunctions(db);
      _Functions.journey = functions;
      addTearDown(() => _Functions.journey = null);
      final h = _Harness();
      await http.runWithClient(() async {
        await _openFirstMethod(tester, h, '体重を記録');
        expect(db.onboarding['firstMonitoringDataRecordedAt'], isNull);
        if (!setupComplete) {
          expect(find.byType(WeightInputCard), findsNothing);
          expect(
              find.byWidgetPredicate(
                  (w) => w is AnimatedShiningBorder && w.active),
              findsOneWidget);
          await tester.tap(find.text('うちの子を登録する'));
          await _frames(tester);
          expect(find.byType(PetProfileEditScreen), findsOneWidget);
          final name = find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == 'ハムスターの名前');
          await tester.ensureVisible(name);
          await tester.enterText(name, '架空の子');
          await tester.ensureVisible(find.text('設定を保存'));
          await tester.tap(find.text('設定を保存'));
          await _frames(tester);
          expect(find.byType(PetProfileEditScreen), findsNothing);
          expect(find.byKey(const ValueKey('first-record-subject-guide')),
              findsNothing);
        }
        expect(find.byType(WeightInputCard), findsOneWidget);
        expect(find.text('飼育環境を登録'), findsNothing);
        expect(find.text('飼い主プロフィールを登録'), findsNothing);
        await tester.enterText(
            find
                .descendant(
                    of: find.byType(WeightInputCard),
                    matching: find.byType(TextField))
                .first,
            '122');
        await tester.ensureVisible(find.byKey(const ValueKey('weight-timing')));
        await tester.tap(find.byKey(const ValueKey('weight-timing')));
        await _frames(tester);
        await tester.tap(find.text('選んだ日に測定（時刻は不要）').last);
        await _frames(tester);
        await tester.ensureVisible(find.text('体重を保存'));
        await tester.tap(find.text('体重を保存'));
        // recordFirstMonitoringData awaits the shared, real-zone Analytics
        // barrier after its fake server write. Drain that queue explicitly.
        await tester.runAsync(() async {});
        await _frames(tester);
        _assertReturnedAfterReceipt(db);
        expect(db.onboarding['firstMonitoringDataSource'], 'weight');
        expect(db.onboarding['monitoringMethod'], 'weight');
        final saves = functions.calls
            .where((call) => call.name == 'saveWeightRecord')
            .toList();
        expect(saves, hasLength(1));
        expect(saves.single.request['weightGrams'], 122);
        expect(saves.single.request['subjectId'], 'journey-synthetic-subject');
        expect(saves.single.request['mutationId'], isNotEmpty);
        expect(
            functions.calls.where((call) => call.name == 'saveMainPetProfile'),
            hasLength(setupComplete ? 0 : 1));
        expect(
            functions.calls
                .where((call) => call.name == 'saveBreedingEnvironment'),
            isEmpty);
        final stored = db.documents[
            'users/$_uid/weight_records/${saves.single.request['dayKey']}']!;
        expect(stored['weightGrams'], 122);
        expect(stored['revision'], 1);
        expect(stored['subjectId'], 'journey-synthetic-subject');
        expect(h.requests, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      }, () => h.client);
    });
  }

  testWidgets(
      'local journey skipped environment: glow focus confirmed settings first wheel receipt and return',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db.reset(guided: false);
    db.onboarding['completedSetupSteps'] = ['pet'];
    _seedJourneyProfile(db);
    FlutterSecureStorage.setMockInitialValues({});
    await AiTextConsentStore().accept(_uid);
    final functions = _JourneyFunctions(db);
    _Functions.journey = functions;
    addTearDown(() => _Functions.journey = null);
    final h = _Harness();
    await http.runWithClient(() async {
      await _openFirstMethod(tester, h, '回し車の記録');
      expect(
          find.byKey(const ValueKey('wheel-diameter-guide')), findsOneWidget);
      expect(functions.calls, isEmpty);
      await tester.ensureVisible(find.text('車輪の直径を設定する'));
      await tester.tap(find.text('車輪の直径を設定する'));
      await _frames(tester);
      expect(find.byType(BreedingEnvironmentEditScreen), findsOneWidget);
      final field = find.byKey(const ValueKey('environment-車輪の直径'));
      final wheel = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)));
      expect(wheel.focusNode!.hasFocus, isTrue);
      expect(
          find.byWidgetPredicate((w) => w is AnimatedShiningBorder && w.active),
          findsOneWidget);
      await tester.enterText(field, '28');
      await tester.pump();
      expect(
          find.byWidgetPredicate((w) => w is AnimatedShiningBorder && w.active),
          findsNothing);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('environment-save')), 450,
          scrollable: find.byType(Scrollable).first);
      await _frames(tester);
      await tester.tap(find.byKey(const ValueKey('environment-date-unknown')));
      await _frames(tester);
      await tester.tap(find.byKey(const ValueKey('environment-save')));
      await _frames(tester);
      expect(find.byType(BreedingEnvironmentEditScreen), findsNothing);
      expect(find.byType(FirstMonitoringRecordScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('wheel-diameter-guide')), findsNothing);
      expect(db.onboarding['firstMonitoringDataRecordedAt'], isNull);
      final settings = functions.calls
          .where((call) => call.name == 'saveBreedingEnvironment')
          .single;
      expect((settings.request['values'] as Map)['wheelDiameter'], '28');
      final input = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '回し車の回転数');
      await tester.ensureVisible(input);
      await tester.enterText(input, '100');
      await _frames(tester);
      expect(find.text('88 m'), findsOneWidget);
      await tester.ensureVisible(find.text('この日付で保存'));
      await tester.tap(find.text('この日付で保存'));
      await tester.runAsync(() async {});
      await _frames(tester);
      _assertReturnedAfterReceipt(db);
      expect(db.onboarding['firstMonitoringDataSource'], 'wheel');
      final saves = functions.calls
          .where((call) => call.name == 'saveDistanceRecord')
          .toList();
      expect(saves, hasLength(1));
      expect(saves.single.request['rotations'], 100);
      expect(saves.single.request.containsKey('wheelDiameterCm'), isFalse);
      expect(saves.single.request['subjectId'], 'journey-synthetic-subject');
      expect((saves.single.request['timing'] as Map)['precision'], 'unknown');
      expect(saves.single.request.containsKey('distance'), isFalse);
      final stored = db.documents[
          'users/$_uid/distance_records/${saves.single.request['dayKey']}']!;
      expect(stored['wheelDiameterCm'], 28);
      expect(stored['distance'], closeTo(87.9646, .01));
      expect(stored['revision'], 1);
      expect(functions.calls.map((call) => call.name).toList(),
          ['saveBreedingEnvironment', 'saveDistanceRecord']);
      expect(h.requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets('first weight record guides only missing pet registration',
      (tester) async {
    final profiles = _ReadOnlyProfileRepo();
    await tester.pumpWidget(MaterialApp(
        home: FirstMonitoringRecordScreen(
            method: 'weight', profileRepo: profiles)));
    await _frames(tester);
    expect(find.byKey(const ValueKey('first-record-subject-guide')),
        findsOneWidget);
    expect(find.byType(WeightInputCard), findsNothing);
    expect(find.text('うちの子を登録する'), findsOneWidget);
    expect(find.text('飼育環境を登録'), findsNothing);
    expect(find.text('飼い主プロフィールを登録'), findsNothing);
    await tester.tap(find.text('うちの子を登録する'));
    await _frames(tester);
    expect(find.byType(PetProfileEditScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets('legacy pet without subject uses existing profile confirmation',
      (tester) async {
    final profiles = _ReadOnlyProfileRepo()
      ..profile = const PetProfile(
          name: '架空の子',
          birthday: null,
          species: 'シリアン',
          color: null,
          imageUrl: null);
    await tester.pumpWidget(MaterialApp(
        home: FirstMonitoringRecordScreen(
            method: 'weight', profileRepo: profiles)));
    await _frames(tester);
    expect(find.text('登録を確認する'), findsOneWidget);
    expect(find.byType(WeightInputCard), findsNothing);
    expect(profiles.reads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets(
      'profile read failure is retryable rather than treated as missing',
      (tester) async {
    final profiles = _ReadOnlyProfileRepo()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: FirstMonitoringRecordScreen(
            method: 'weight', profileRepo: profiles)));
    await _frames(tester);
    expect(find.text('もう一度確認'), findsOneWidget);
    expect(find.text('うちの子を登録する'), findsNothing);
    expect(find.byType(WeightInputCard), findsNothing);
    profiles.fail = false;
    await tester.tap(find.text('もう一度確認'));
    await _frames(tester);
    expect(find.text('うちの子を登録する'), findsOneWidget);
    expect(profiles.reads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  test(
      'first success keeps monitoring history without forcing another start CTA',
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
    expect(state.monitoringIntroCtaPending, isFalse);
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

  test('skipped setup with an existing first record does not force a CTA',
      () async {
    db.reset(guided: false);
    final first = Timestamp.fromDate(DateTime(2026, 10, 1));
    db.onboarding['firstMonitoringDataRecordedAt'] = first;
    db.onboarding['firstMonitoringDataSource'] = 'weight';
    db.onboarding['monitoringIntroCtaPending'] = true;
    await OnboardingStateRepo().markFirstAiConsultationCompleted();
    expect(db.onboarding['firstAiConsultationCompleted'], isTrue);
    expect(db.onboarding['monitoringIntroCtaPending'], isFalse);
    expect(db.onboarding['firstMonitoringDataRecordedAt'], first);
  });

  for (final dismissWithBack in [false, true]) {
    testWidgets(
        'text AI consent ${dismissWithBack ? 'back' : 'cancel'} sends nothing and preserves the unsent draft',
        (tester) async {
      final consent = AiTextConsentStore();
      await consent.revoke(_uid);
      const question = '同意前に保持する質問';
      final h = _Harness();
      await http.runWithClient(() async {
        await h.mount(tester);
        await h.send(tester, text: question);
        expect(find.text('AI相談の情報送信について'), findsOneWidget);
        expect(h.requests, 0);
        expect(
            db.documents.keys.where(
                (key) => key.contains('/ai_chat_threads/main/messages/')),
            isEmpty);
        expect(db.onboarding['firstAiConsultationCompleted'], isFalse);
        if (dismissWithBack) {
          h.navigator.currentState!.pop();
        } else {
          await tester.tap(find.text('送信しない'));
        }
        await _frames(tester);
        expect(find.text('AI相談の情報送信について'), findsNothing);
        expect(h.requests, 0);
        expect(await consent.hasAccepted(_uid), isFalse);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
            question);
        expect(
            db.documents.keys.where(
                (key) => key.contains('/ai_chat_threads/main/messages/')),
            isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      }, () => h.client);
    });
  }

  testWidgets(
      'text AI consent acceptance dispatches once when send is pressed twice while pending',
      (tester) async {
    final consent = AiTextConsentStore();
    await consent.revoke(_uid);
    const question = '同意して一度だけ送る質問';
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester, text: question);
      // Re-enter the actual send callback while the first request awaits consent.
      // The first action follows the suite's real tap path and HTTP mock zone.
      final send = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded));
      send.onPressed!();
      await _frames(tester);
      expect(find.text('AI相談の情報送信について'), findsOneWidget);
      expect(h.requests, 0);
      expect(
          db.documents.keys
              .where((key) => key.contains('/ai_chat_threads/main/messages/')),
          isEmpty);
      await tester.tap(find.text('同意して送信'));
      await _frames(tester);
      expect(find.text('AI相談の情報送信について'), findsNothing);
      expect(await consent.hasAccepted(_uid), isTrue);
      expect(h.requests, 1);
      final body = jsonDecode(h.requestBodies.single) as Map;
      expect(body['query'], question);
      expect((body['history'] as List).last,
          {'role': 'user', 'content': question});
      expect(find.textContaining(_answer), findsOneWidget);
      expect(
          db.documents.entries.where((entry) =>
              entry.key.contains('/ai_chat_threads/main/messages/') &&
              entry.value['role'] == 'user' &&
              entry.value['content'] == question),
          hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets(
      'text AI consent revoke before retry preserves the saved request payload',
      (tester) async {
    // Reuse the existing retry viewport so every conversation turn stays laid out.
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final consent = AiTextConsentStore();
    const question = '同意撤回後も同じ内容で再送する質問';
    final h = _Harness()..networkFailuresRemaining = 1;
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester, text: question);
      expect(h.requests, 1);
      final failedBody = h.requestBodies.single;
      await consent.revoke(_uid);
      await h.send(tester, text: question);
      expect(find.text('AI相談の情報送信について'), findsOneWidget);
      expect(h.requests, 1);
      await tester.tap(find.text('送信しない'));
      await _frames(tester);
      expect(h.requests, 1);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          question);
      await h.send(tester, text: question);
      await tester.tap(find.text('同意して送信'));
      await _frames(tester);
      expect(h.requests, 2);
      expect(h.requestBodies.last, failedBody);
      expect(find.textContaining(_answer), findsOneWidget);
      expect(
          db.documents.entries.where((entry) =>
              entry.key.contains('/ai_chat_threads/main/messages/') &&
              entry.value['role'] == 'user' &&
              entry.value['content'] == question),
          hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets(
      'text AI consent withdrawal during token wait prevents POST and trial consumption',
      (tester) async {
    final barrier = Completer<void>();
    _Auth.tokenBarrier = barrier;
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester, text: '送信直前の同意撤回を確認する質問');
      expect(h.requests, 0);
      await AiTextConsentStore().revoke(_uid);
      barrier.complete();
      await _frames(tester);
      expect(h.requests, 0);
      expect(
          db.documents['users/$_uid/feature_access/initial_trial_v2']!
              ['aiRequestUsed'],
          0);
      expect(_Functions.trialStartCalls, 0);
      expect(db.onboarding['firstAiConsultationCompleted'], isFalse);
      expect(
          db.documents.entries.where((entry) =>
              entry.key.contains('/ai_chat_threads/main/messages/') &&
              entry.value['role'] == 'assistant'),
          isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
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
      expect(find.textContaining('AI相談サービスに問題が発生しています。'), findsOneWidget);
      expect(find.textContaining('Exception:'), findsNothing);
      expect(h.observer.pushes, pushes);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  for (final transportFailure in [true, false]) {
    testWidgets(
        'manual same-question retry preserves exact payload after ${transportFailure ? 'network failure' : 'unknown provider result'}',
        (tester) async {
      // Keep both conversation turns visible so the lazy SliverList can be
      // checked for a duplicate user bubble as well as duplicate wire history.
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _Harness();
      await http.runWithClient(() async {
        await h.mount(tester);
        await h.send(tester, text: '先に成功した質問');
        if (transportFailure) {
          h.networkFailuresRemaining = 1;
        } else {
          h.errorStatus = 502;
          h.errorBody = {
            'detail': {'code': 'ai_provider_unavailable'}
          };
        }
        await h.send(tester, text: '再送を確認する質問');
        expect(h.requests, 2);
        expect(find.text('再送を確認する質問'), findsOneWidget);
        final failed = jsonDecode(h.requestBodies[1]) as Map;
        expect((failed['history'] as List).last,
            {'role': 'user', 'content': '再送を確認する質問'});
        if (transportFailure) {
          expect(find.textContaining('別の相談として送り直さず'), findsOneWidget);
        }
        h.errorStatus = null;
        h.errorBody = null;
        await h.send(tester, text: '再送を確認する質問');
        expect(h.requests, 3);
        expect(h.requestBodies[2], h.requestBodies[1]);
        expect(find.text('再送を確認する質問'), findsOneWidget);
        final userDocuments = db.documents.entries.where((entry) =>
            entry.key.contains('/ai_chat_threads/main/messages/') &&
            entry.value['role'] == 'user' &&
            entry.value['content'] == '再送を確認する質問');
        expect(userDocuments, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      }, () => h.client);
    });
  }

  testWidgets(
      'changed query gets a new request ID and clears the earlier pending retry',
      (tester) async {
    final h = _Harness()..networkFailuresRemaining = 1;
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester, text: '失敗した元の質問');
      await h.send(tester, text: '別の質問');
      await h.send(tester, text: '失敗した元の質問');
      final bodies =
          h.requestBodies.map((body) => jsonDecode(body) as Map).toList();
      expect(bodies.map((body) => body['query']),
          ['失敗した元の質問', '別の質問', '失敗した元の質問']);
      expect(bodies.map((body) => body['request_id']).toSet(), hasLength(3));
      expect((bodies[1]['history'] as List).last,
          {'role': 'user', 'content': '別の質問'});
      expect((bodies[2]['history'] as List).last,
          {'role': 'user', 'content': '失敗した元の質問'});
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  testWidgets(
      'restored unresolved user message retries its saved ID without duplicating history',
      (tester) async {
    final before = _Harness()..networkFailuresRemaining = 1;
    await http.runWithClient(() async {
      await before.mount(tester);
      await before.send(tester, text: '再起動後に確認する質問');
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => before.client);
    final after = _Harness();
    await http.runWithClient(() async {
      await after.mount(tester);
      expect(find.text('再起動後に確認する質問'), findsOneWidget);
      await after.send(tester, text: '再起動後に確認する質問');
      expect(after.requestBodies.single, before.requestBodies.single);
      expect(find.text('再起動後に確認する質問'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => after.client);
  });

  for (final switchDuringToken in [false, true]) {
    testWidgets(
        'account switch during ${switchDuringToken ? 'token' : 'history'} await never dispatches the old payload',
        (tester) async {
      final h = _Harness();
      final barrier = Completer<void>();
      if (switchDuringToken) {
        _Auth.tokenBarrier = barrier;
      } else {
        db.pausedWriteRole = 'user';
        db.writeBarrier = barrier;
      }
      await http.runWithClient(() async {
        await h.mount(tester);
        await h.send(tester, text: 'Aだけの質問');
        expect(h.requests, 0);
        _Auth.activeUid = 'different-account-B';
        barrier.complete();
        await _frames(tester);
        expect(h.requests, 0);
        expect(
            db.documents.keys
                .any((key) => key.startsWith('users/different-account-B/')),
            isFalse);
        expect(find.text('Aだけの質問'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      }, () => h.client);
    });
  }

  testWidgets(
      'account switch during HTTP response never displays or saves A answer under B',
      (tester) async {
    final h = _Harness()..response = Completer<http.Response>();
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester, text: 'Aだけの質問');
      expect(h.requests, 1);
      expect(h.requestHeaders.single['Authorization'],
          'Bearer fake-id-token-$_uid');
      _Auth.activeUid = 'different-account-B';
      h.response!.complete(http.Response(
          jsonEncode({'answer': 'Aだけの回答', 'chunks': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await _frames(tester);
      expect(find.textContaining('Aだけの回答'), findsNothing);
      expect(
          db.documents.keys
              .any((key) => key.startsWith('users/different-account-B/')),
          isFalse);
      expect(db.documents.values.any((value) => value['content'] == 'Aだけの回答'),
          isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  for (final failRead in [true, false]) {
    testWidgets(
        'secure pending ${failRead ? 'read' : 'write'} failure blocks generation without exposing storage details',
        (tester) async {
      FlutterSecureStoragePlatform.instance =
          _UnavailableStorage(failRead: failRead, failWrite: !failRead);
      final h = _Harness();
      await http.runWithClient(() async {
        await h.mount(tester);
        await h.send(tester);
        expect(h.requests, 0);
        expect(find.textContaining('synthetic_private_storage_error'),
            findsNothing);
        expect(find.textContaining('Exception:'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      }, () => h.client);
    });
  }

  testWidgets(
      'late older assistant write cannot hide exact pending request on restart',
      (tester) async {
    final before = _Harness();
    await http.runWithClient(() async {
      await before.mount(tester);
      await before.send(tester, text: '先に回答した質問');
      before.networkFailuresRemaining = 1;
      await before.send(tester, text: '保留中の質問');
      // An old asynchronous save completes after the unresolved user record.
      db.write(
          'users/$_uid/ai_chat_threads/main/messages/late-old-answer',
          {
            'role': 'assistant',
            'content': '先の回答が遅れて保存',
            'originalQuery': '先に回答した質問',
            'createdAt': FieldValue.serverTimestamp(),
          },
          null);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => before.client);
    final after = _Harness();
    await http.runWithClient(() async {
      await after.mount(tester);
      await after.send(tester, text: '保留中の質問');
      expect(after.requestBodies.single, before.requestBodies.last);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => after.client);
  });

  testWidgets(
      'legacy restored request without exact secure body never receives a fresh ID',
      (tester) async {
    db.write(
        'users/$_uid/ai_chat_threads/main/messages/request_legacy',
        {
          'role': 'user',
          'content': '昔の保留中の質問',
          'requestId': 'chat_legacy_pending_123',
          'createdAt': FieldValue.serverTimestamp(),
        },
        null);
    db.write(
        'users/$_uid/ai_chat_threads/main/messages/late_legacy_answer',
        {
          'role': 'assistant',
          'content': '別の質問の遅れた回答',
          'originalQuery': '別の質問',
          'createdAt': FieldValue.serverTimestamp(),
        },
        null);
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      await h.send(tester, text: '昔の保留中の質問');
      expect(h.requests, 0);
      expect(find.textContaining('新しく送り直さず'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await _frames(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });

  for (final errorCase in [
    (code: 'failed-precondition', expected: '運営側の利用設定の確認が必要'),
    (code: 'unauthenticated', expected: 'もう一度ログイン'),
    (code: 'unavailable', expected: '接続を確認'),
  ]) {
    testWidgets(
        'actual trial start button explains ${errorCase.code} without granting access',
        (tester) async {
      db.documents.remove('users/$_uid/feature_access/initial_trial_v2');
      _Functions.trialStartError = fu.FirebaseFunctionsException(
          code: errorCase.code,
          message: 'private backend configuration',
          details: errorCase.code == 'failed-precondition'
              ? {'reason': 'policy_unconfigured'}
              : null);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PaidFeatureGate(
                  featureName: 'AI相談',
                  useInitialTrial: true,
                  canStartInitialTrial: true,
                  child: Text('protected feature')))));
      await _frames(tester);
      await tester.tap(find.text('21日間の無料体験を始める'));
      await _frames(tester);
      expect(_Functions.trialStartCalls, 1);
      expect(find.textContaining(errorCase.expected), findsOneWidget);
      expect(find.text('protected feature'), findsNothing);
      expect(find.textContaining('無料体験は利用上限の設定後'), findsNothing);
      expect(
          find.textContaining('private backend configuration'), findsNothing);
      expect(find.textContaining('Exception:'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await _frames(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });
  }

  for (final failure in [
    (
      status: 429,
      detail: 'AI free usage limit reached.',
      expected: 'trial_limit_reached'
    ),
    (
      status: 429,
      detail: 'The limited validation run has reached its server-side budget.',
      expected: 'operator_unavailable'
    ),
    (
      status: 429,
      detail: 'unknown private internal detail',
      expected: 'request_rejected'
    ),
    (
      status: 503,
      detail: <String, dynamic>{
        'code': 'ai_shared_budget_exhausted',
        'message': 'private internal detail'
      },
      expected: 'operator_unavailable'
    ),
    (
      status: 502,
      detail: <String, dynamic>{
        'code': 'ai_provider_unavailable',
        'message': 'private internal detail'
      },
      expected: 'ai_result_unknown'
    ),
  ]) {
    testWidgets(
        'chat shows safe ${failure.expected} message for ${failure.status}',
        (tester) async {
      final h = _Harness()
        ..errorStatus = failure.status
        ..errorBody = {'detail': failure.detail};
      await http.runWithClient(() async {
        await h.mount(tester);
        await h.send(tester);
        final expected = AiAccessFailure.fromChatResponse(
            failure.status, jsonEncode(h.errorBody));
        expect(expected.code, failure.expected);
        expect(find.textContaining(expected.message), findsOneWidget);
        expect(find.textContaining('Exception:'), findsNothing);
        expect(find.textContaining('private internal detail'), findsNothing);
        expect(find.byKey(_ctaKey), findsNothing);
        expect(h.requests, 1);
        expect(db.onboarding['firstAiConsultationCompleted'], isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      }, () => h.client);
    });
  }

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

  testWidgets(
      'skipped setup paid first success offers one manual monitoring CTA',
      (tester) async {
    db.reset(guided: false, paid: true);
    final h = _Harness();
    await http.runWithClient(() async {
      await h.mount(tester);
      final pushes = h.observer.pushes;
      await h.send(tester);
      expect(db.onboarding['firstAiConsultationCompleted'], isTrue);
      expect(db.onboarding['monitoringIntroCtaPending'], isTrue);
      expect(find.textContaining(_answer), findsOneWidget);
      expect(find.byKey(_ctaKey), findsOneWidget);
      expect(h.observer.pushes, pushes);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    }, () => h.client);
  });
}
