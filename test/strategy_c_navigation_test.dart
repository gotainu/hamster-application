// Uses installed FlutterFire interfaces and the existing offline real-Tabs
// harness. No Golden font loader, screenshot generation or real service runs.
// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart'
    as fu;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hamster_project/main.dart';
import 'package:hamster_project/screens/settings.dart';
import 'package:hamster_project/screens/subscription_plan_screen.dart';
import 'package:hamster_project/screens/tabs.dart';
import 'package:hamster_project/services/ai_text_consent_store.dart';
import 'package:hamster_project/services/app_analytics.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/floating_bottom_navigation.dart';
import 'package:hamster_project/widgets/main_drawer.dart';
import 'package:hamster_project/widgets/record_calendar_action.dart';

import 'first_ai_monitoring_cta_test.dart'
    show installRecordCalendarWidgetBackend;

const _uid = 'onboarding-widget-test';
const _trialPath = 'users/$_uid/feature_access/initial_trial_v2';
const _neutral = 'このアカウントでは、現在この機能を利用できません。';

// Settings reads its enclosing MyApp theme. Keep that real ancestor type while
// bypassing production startup/FCM, as the existing owner UI harness does.
class _NavigationApp extends MyApp {
  const _NavigationApp({required this.dark});
  final bool dark;
  @override
  State<MyApp> createState() => _NavigationAppState();
}

class _NavigationAppState extends MyAppState {
  @override
  // ignore: must_call_super
  void initState() {}

  @override
  ThemeMode get themeMode =>
      (widget as _NavigationApp).dark ? ThemeMode.dark : ThemeMode.light;

  @override
  Widget build(BuildContext context) => MaterialApp(
      theme: (widget as _NavigationApp).dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: const TabsScreen());
}

class _NavigationFunctions extends fu.FirebaseFunctionsPlatform {
  _NavigationFunctions() : super(null, 'asia-northeast1');
  final calls = <String>[];
  VoidCallback? startTrial;
  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;
  @override
  fu.HttpsCallablePlatform httpsCallable(
      String? origin, String name, fu.HttpsCallableOptions options) {
    expect(
        name,
        anyOf('claimDailyOpenStar', 'refreshCareContinuity',
            'startInitialTrial'));
    return _NavigationCallable(this, origin, name, options);
  }
}

class _NavigationCallable extends fu.HttpsCallablePlatform {
  _NavigationCallable(_NavigationFunctions functions, String? origin,
      String name, fu.HttpsCallableOptions options)
      : super(functions, origin, name, options, null);
  @override
  Future<dynamic> call([dynamic parameters]) async {
    final fake = functions as _NavigationFunctions;
    fake.calls.add(name!);
    if (name == 'startInitialTrial') fake.startTrial?.call();
    if (name != 'refreshCareContinuity') return <String, dynamic>{};
    return <String, dynamic>{
      'schemaVersion': 1,
      'policyVersion': 'continuity_v1',
      'serverDateKey': '2026-11-21',
      'phase': 'active',
      'todayAchieved': false,
      'periodEarned': 0,
      'lifetimeAchievementDays': 0,
    };
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _noPurchaseUi() {
  expect(
      find.textContaining(
          RegExp(r'月額|500円|550円|Webで購入|プランに登録|プレミアムに登録|有料プランに切り替え')),
      findsNothing);
}

Future<void> _mountTabs(WidgetTester tester, {bool dark = false}) async {
  // Same narrowly scoped, pre-task Settings diagnostic as owner_nickname_test.
  // Forward every other error; do not change production ListTile/visual code.
  final originalErrorHandler = FlutterError.onError;
  var existingListTileWarnings = 0;
  FlutterError.onError = (details) {
    if (details.exception is FlutterError &&
        details.exceptionAsString().startsWith(
            'ListTile background color or ink splashes may be invisible.')) {
      existingListTileWarnings++;
      return;
    }
    originalErrorHandler?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = originalErrorHandler;
    if (existingListTileWarnings > 0) {
      debugPrint('Recorded existing Settings ListTile debug diagnostics: '
          '$existingListTileWarnings');
    }
  });
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_NavigationApp(dark: dark));
  await _frames(tester);
}

Future<void> _openDrawer(WidgetTester tester) async {
  Scaffold.of(tester.element(find.byType(RecordCalendarAction))).openDrawer();
  await _frames(tester);
  expect(find.byType(MainDrawer), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final functions = _NavigationFunctions();
  late ({
    Map<String, Map<String, dynamic>> documents,
    VoidCallback notify,
    Future<void> Function() close
  }) backend;
  late Map<String, Map<String, dynamic>> initial;
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
        appName: 'HamCare',
        packageName: 'synthetic.strategy.navigation',
        version: '0.0.0',
        buildNumber: '0',
        buildSignature: 'synthetic');
    backend = installRecordCalendarWidgetBackend(functions: functions);
    initial =
        backend.documents.map((key, value) => MapEntry(key, Map.of(value)));
    // Settle the existing Analytics identity barrier outside FakeAsync. The
    // backend harness forbids external HTTP and no SDK event can be sent.
    await AppAnalytics.logHomeView(source: 'synthetic_strategy_c_navigation');
    functions.startTrial = () {
      backend.documents[_trialPath] = {
        'policyVersion': 'initial_trial_v2',
        'status': 'active',
        'endsAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 21))),
        'aiRequestLimit': 20,
        'aiRequestUsed': 0,
      };
      backend.notify();
    };
  });
  setUp(() async {
    functions.calls.clear();
    backend.documents
      ..clear()
      ..addAll(initial.map((key, value) => MapEntry(key, Map.of(value))));
    FlutterSecureStorage.setMockInitialValues({});
    await AiTextConsentStore().accept(_uid);
  });
  tearDownAll(() => backend.close());

  for (final dark in [false, true]) {
    testWidgets('Home Drawer Settings usage status stays reachable ($dark)',
        (tester) async {
      backend.documents[_trialPath] = {
        ...backend.documents[_trialPath]!,
        'status': 'expired',
        'endsAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1))),
      };
      await _mountTabs(tester, dark: dark);
      expect(find.byType(RecordCalendarAction), findsOneWidget);
      _noPurchaseUi();
      await _openDrawer(tester);
      await tester.ensureVisible(find.text('アプリの設定'));
      await tester.tap(find.text('アプリの設定'));
      await _frames(tester);
      expect(find.byType(SettingScreen), findsOneWidget);
      final usageTile = find.text('このアカウントの利用状態と期限');
      await tester.scrollUntilVisible(usageTile, 250,
          scrollable: find
              .descendant(
                  of: find.byType(SettingScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.tap(usageTile);
      await _frames(tester);
      expect(find.byType(SubscriptionPlanScreen), findsOneWidget);
      expect(find.text('無料体験は終了しました。'), findsOneWidget);
      expect(find.text('このアカウントでは、現在プレミアム機能を利用できません。'), findsOneWidget);
      expect(find.text('利用規約'), findsOneWidget);
      expect(find.text('プライバシーポリシー'), findsOneWidget);
      _noPurchaseUi();
      expect(functions.calls, everyElement('claimDailyOpenStar'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });
  }

  testWidgets('expired AI tab offers a neutral read-only recheck',
      (tester) async {
    backend.documents[_trialPath] = {
      ...backend.documents[_trialPath]!,
      'status': 'expired',
      'endsAt':
          Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
    };
    final before = Map.of(backend.documents[_trialPath]!);
    await _mountTabs(tester);
    tester
        .widget<FloatingBottomNavigation>(find.byType(FloatingBottomNavigation))
        .onTabSelected(1);
    await _frames(tester);
    expect(find.textContaining(_neutral), findsOneWidget);
    await tester.ensureVisible(find.text('利用状況を再確認'));
    await tester.tap(find.text('利用状況を再確認'));
    await _frames(tester);
    expect(find.textContaining(_neutral), findsOneWidget);
    expect(backend.documents[_trialPath], before);
    _noPurchaseUi();
    expect(functions.calls, everyElement('claimDailyOpenStar'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets('unstarted AI trial requires and preserves the explicit start',
      (tester) async {
    backend.documents.remove(_trialPath);
    await _mountTabs(tester);
    tester
        .widget<FloatingBottomNavigation>(find.byType(FloatingBottomNavigation))
        .onTabSelected(1);
    await _frames(tester);
    expect(
        functions.calls.where((name) => name == 'startInitialTrial'), isEmpty);
    final start = find.text('21日間の無料体験を始める');
    expect(start, findsOneWidget);
    await tester.ensureVisible(start);
    await tester.tap(start);
    await _frames(tester);
    expect(
        functions.calls.where((name) => name == 'startInitialTrial').length, 1);
    expect(backend.documents[_trialPath]!['aiRequestLimit'], 20);
    expect(backend.documents[_trialPath]!['status'], 'active');
    expect(find.byType(TextField), findsWidgets);
    _noPurchaseUi();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets('Drawer record destination retains its neutral expired gate',
      (tester) async {
    backend.documents[_trialPath] = {
      ...backend.documents[_trialPath]!,
      'status': 'expired',
      'endsAt':
          Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
    };
    await _mountTabs(tester);
    await _openDrawer(tester);
    await tester.tap(find.text('記録する'));
    await _frames(tester);
    expect(find.textContaining(_neutral), findsOneWidget);
    _noPurchaseUi();
    expect(functions.calls, everyElement('claimDailyOpenStar'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
}
