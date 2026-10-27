// Offline adapters for the installed FlutterFire interfaces.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/app_analytics.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('External network is forbidden in analytics tests');
}

class _Core extends core.FirebasePlatform {
  final appValue = core.FirebaseAppPlatform(
    core.defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'synthetic',
      appId: 'synthetic',
      messagingSenderId: 'synthetic',
      projectId: 'synthetic-journey',
    ),
  );
  @override
  List<core.FirebaseAppPlatform> get apps => [appValue];
  @override
  core.FirebaseAppPlatform app([String name = core.defaultFirebaseAppName]) =>
      appValue;
}

class _Analytics extends FirebaseAnalyticsPlatform {
  final events =
      <({String name, Map<String, Object?> parameters, String? uid})>[];
  final identityCalls = <String?>[];
  String? uid;
  Completer<void>? blockIdentity;
  bool failIdentity = false;
  bool failLog = false;

  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) => this;

  @override
  Future<void> setUserId({
    String? id,
    AnalyticsCallOptions? callOptions,
  }) async {
    identityCalls.add(id);
    final block = blockIdentity;
    blockIdentity = null;
    if (block != null) await block.future;
    if (failIdentity) throw StateError('synthetic identity failure');
    uid = id;
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    if (failLog) throw StateError('synthetic analytics failure');
    events.add((name: name, parameters: Map.of(parameters ?? {}), uid: uid));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final analytics = _Analytics();
  final previousOverrides = HttpOverrides.current;

  setUpAll(() {
    HttpOverrides.global = _NoNetwork();
    core.FirebasePlatform.instance = _Core();
    FirebaseAnalyticsPlatform.instance = analytics;
  });
  tearDownAll(() => HttpOverrides.global = previousOverrides);
  setUp(() async {
    analytics.failIdentity = false;
    analytics.failLog = false;
    analytics.blockIdentity = null;
    await AppAnalytics.clearUserId();
    await AppAnalytics.setUserId('synthetic-owner-a');
    analytics.events.clear();
    analytics.identityCalls.clear();
  });

  test(
    'GA4 identity uses standard User-ID and explicit test classification',
    () async {
      await AppAnalytics.logHomeView(source: 'app_start');
      final event = analytics.events.single;
      expect(event.uid, 'synthetic-owner-a');
      expect(event.parameters['analytics_identity_version'], 'firebase_uid_v1');
      const environment = String.fromEnvironment(
        'HAMCARE_ANALYTICS_ENVIRONMENT',
      );
      expect(
        event.parameters['analytics_environment'],
        environment == 'emulator' ? 'emulator' : 'test',
      );
      expect(event.parameters['test_only'], 1);
      expect(event.parameters['event_id'], startsWith('client_'));
      expect(event.parameters.values, isNot(contains('synthetic-owner-a')));
      expect(event.parameters.keys, isNot(contains('uid')));
    },
  );

  test('health answers and memo metadata are not sent to GA4', () async {
    await AppAnalytics.logDailyInputComplete(
      condition: 'veryConcerned',
      concernTagCount: 4,
      hasMemo: true,
    );
    final event = analytics.events.single;
    expect(event.name, 'daily_input_complete');
    expect(event.parameters.keys, isNot(contains('condition')));
    expect(event.parameters.keys, isNot(contains('concern_tag_count')));
    expect(event.parameters.keys, isNot(contains('has_memo')));
    expect(event.parameters.values, isNot(contains('veryConcerned')));
  });

  test('ordinary genuine actions receive different event IDs', () async {
    await AppAnalytics.logCheckoutStarted();
    await AppAnalytics.logCheckoutStarted();
    expect(
      analytics.events.map((e) => e.parameters['event_id']).toSet(),
      hasLength(2),
    );
    expect(
      analytics.events.map((e) => e.name),
      everyElement('checkout_started'),
    );
    expect(
      analytics.events.any((e) => e.name == 'subscription_activated'),
      isFalse,
    );
  });

  test('presentation retries keep one stable deduplication ID', () async {
    for (var i = 0; i < 2; i++) {
      await AppAnalytics.logPaywallPresented(
        featureName: 'monitoring',
        presentationId: 'synthetic-presentation-one',
      );
    }
    await AppAnalytics.logPaywallPresented(
      featureName: 'monitoring',
      presentationId: 'synthetic-presentation-two',
    );
    final ids = analytics.events.map((e) => e.parameters['event_id']).toList();
    expect(ids[0], ids[1]);
    expect(ids[0], isNot(ids[2]));
    expect((ids[0] as String).length, lessThanOrEqualTo(100));
  });

  test(
    'changed report or revision in one presentation is a new display',
    () async {
      Future<void> report(String id, int revision) =>
          AppAnalytics.logAnalysisReportViewed(
            reportId: id,
            petId: 'main_pet',
            revision: revision,
            presentationId: 'synthetic-shared-route',
            autoPresented: false,
          );
      await report('synthetic-report-one', 1);
      await report('synthetic-report-one', 1);
      await report('synthetic-report-one', 2);
      await report('synthetic-report-two', 2);
      final ids = analytics.events
          .map((e) => e.parameters['event_id'])
          .toList();
      expect(ids[0], ids[1]);
      expect(ids.toSet(), hasLength(3));
    },
  );

  test('changed gated feature in one presentation is a new display', () async {
    await AppAnalytics.logPaywallPresented(
      featureName: 'monitoring',
      presentationId: 'synthetic-shared-route',
    );
    await AppAnalytics.logPaywallPresented(
      featureName: 'ai',
      presentationId: 'synthetic-shared-route',
    );
    expect(
      analytics.events.map((e) => e.parameters['event_id']).toSet(),
      hasLength(2),
    );
  });

  test(
    'actual report view contract and first-view metadata are preserved',
    () async {
      await AppAnalytics.logPersonalityReportViewed(
        expectedUserId: 'synthetic-owner-a',
        reportId: 'synthetic-report',
        petId: 'main_pet',
        revision: 3,
        presentationId: 'synthetic-report-presentation',
        isFirstView: true,
      );
      final event = analytics.events.single;
      expect(event.name, 'personalized_report_viewed');
      expect(event.parameters['report_kind'], 'personality');
      expect(event.parameters['is_first_view'], 1);
      expect(event.parameters['report_id'], 'synthetic-report');
    },
  );

  test('events with wrong expected owner are dropped', () async {
    await AppAnalytics.logAnalysisReportViewed(
      expectedUserId: 'synthetic-owner-b',
      reportId: 'synthetic-first',
      petId: 'main_pet',
      revision: 1,
      presentationId: 'synthetic-first-presentation',
      autoPresented: false,
    );
    expect(analytics.events, isEmpty);
  });

  test(
    'logged-out events are not attributed to the previous account',
    () async {
      await AppAnalytics.clearUserId();
      await AppAnalytics.logHomeView(source: 'app_start');
      expect(analytics.events, isEmpty);
    },
  );

  test('an action waits for confirmed Analytics identity', () async {
    final block = Completer<void>();
    analytics.blockIdentity = block;
    final identity = AppAnalytics.setUserId('synthetic-owner-b');
    await Future<void>.delayed(Duration.zero);
    final event = AppAnalytics.logHomeView(source: 'app_start');
    await Future<void>.delayed(Duration.zero);
    expect(analytics.events, isEmpty);
    block.complete();
    await identity;
    await event;
    expect(analytics.events.single.uid, 'synthetic-owner-b');
  });

  test(
    'A action queued before account switch cannot be attributed to B',
    () async {
      final block = Completer<void>();
      analytics.blockIdentity = block;
      final identityA = AppAnalytics.setUserId('synthetic-owner-a');
      await Future<void>.delayed(Duration.zero);
      final oldEvent = AppAnalytics.logHomeView(source: 'app_start');
      final identityB = AppAnalytics.setUserId('synthetic-owner-b');
      block.complete();
      await Future.wait([identityA, oldEvent, identityB]);
      expect(analytics.events, isEmpty);
      await AppAnalytics.logHomeView(source: 'bottom_navigation');
      expect(analytics.events.single.uid, 'synthetic-owner-b');
    },
  );

  test(
    'failed identity confirmation cannot leak an action under old identity',
    () async {
      analytics.failIdentity = true;
      await AppAnalytics.setUserId('synthetic-owner-b');
      await AppAnalytics.logCheckoutStarted();
      expect(analytics.events, isEmpty);
    },
  );

  test(
    'long presentation IDs stay deterministic within GA4 value limits',
    () async {
      final presentation = List.filled(400, 'synthetic').join();
      await AppAnalytics.logMonitoringMethodPresented(
        presentationId: presentation,
      );
      await AppAnalytics.logMonitoringMethodPresented(
        presentationId: presentation,
      );
      final ids = analytics.events
          .map((e) => e.parameters['event_id'])
          .toList();
      expect(ids[0], ids[1]);
      expect((ids[0] as String).length, lessThanOrEqualTo(100));
    },
  );

  test(
    'logout and same-account relogin cannot revive an older queued action',
    () async {
      final block = Completer<void>();
      analytics.blockIdentity = block;
      final identity = AppAnalytics.setUserId('synthetic-owner-a');
      await Future<void>.delayed(Duration.zero);
      final oldEvent = AppAnalytics.logCheckoutStarted();
      final logout = AppAnalytics.clearUserId();
      final relogin = AppAnalytics.setUserId('synthetic-owner-a');
      block.complete();
      await Future.wait([identity, oldEvent, logout, relogin]);
      expect(analytics.events, isEmpty);
    },
  );

  test('analytics transport failure never fails a product action', () async {
    analytics.failLog = true;
    await expectLater(AppAnalytics.logCheckoutOpened(), completes);
    expect(analytics.events, isEmpty);
  });
}
