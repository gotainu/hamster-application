// Offline Settings + actual callable wrapper. No account is really deleted.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart'
    as fu;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/main.dart';
import 'package:hamster_project/screens/settings.dart';
import 'package:hamster_project/services/account_deletion_guard.dart';
import 'package:hamster_project/services/ai_text_consent_store.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'first_ai_monitoring_cta_test.dart'
    show installRecordCalendarWidgetBackend;

const _uid = 'onboarding-widget-test';
const _billingPath = 'users/$_uid/billing/subscription';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String? get email => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? currentUser = _User(_uid);
  int signOutCalls = 0;
  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Functions extends fu.FirebaseFunctionsPlatform {
  _Functions() : super(null, 'asia-northeast1');
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic> response = {'ok': true, 'deletedDocuments': 1};
  bool fail = false;
  VoidCallback? beforeReturn;
  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;
  @override
  fu.HttpsCallablePlatform httpsCallable(
      String? origin, String name, fu.HttpsCallableOptions options) {
    expect(name, 'deleteMyAccountAndData');
    return _Callable(this, origin, name, options);
  }
}

class _Callable extends fu.HttpsCallablePlatform {
  _Callable(_Functions functions, String? origin, String name,
      fu.HttpsCallableOptions options)
      : super(functions, origin, name, options, null);
  @override
  Future<dynamic> call([dynamic parameters]) async {
    final fake = functions as _Functions;
    fake.requests.add(Map<String, dynamic>.from(parameters as Map));
    if (fake.fail) throw StateError('synthetic callable failure');
    fake.beforeReturn?.call();
    return fake.response;
  }
}

class _UnavailableGuard extends AccountDeletionGuard {
  _UnavailableGuard(_Auth auth) : super(auth: auth);
  @override
  Future<AccountDeletionEligibility> check(String expectedUid) async =>
      AccountDeletionEligibility.unavailable;
}

class _PausedGuard extends AccountDeletionGuard {
  _PausedGuard(_Auth auth) : super(auth: auth);
  final gate = Completer<void>();
  int checks = 0;
  @override
  Future<AccountDeletionEligibility> check(String expectedUid) async {
    checks++;
    if (checks == 1) await gate.future;
    return super.check(expectedUid);
  }
}

class _DeleteApp extends MyApp {
  const _DeleteApp({required this.auth, required this.guard});
  final _Auth auth;
  final AccountDeletionGuard guard;
  @override
  State<MyApp> createState() => _DeleteAppState();
}

class _DeleteAppState extends MyAppState {
  @override
  // ignore: must_call_super
  void initState() {}
  @override
  ThemeMode get themeMode => ThemeMode.light;
  @override
  Widget build(BuildContext context) {
    final app = widget as _DeleteApp;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: SettingScreen(auth: app.auth, accountDeletionGuard: app.guard),
    );
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openDelete(WidgetTester tester, _Auth auth,
    {AccountDeletionGuard? guard, bool doubleTap = false}) async {
  final originalErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    // Existing Settings decoration diagnostic, unrelated to this change.
    if (details.exception is FlutterError &&
        details.exceptionAsString().startsWith(
            'ListTile background color or ink splashes may be invisible.')) {
      return;
    }
    originalErrorHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalErrorHandler);
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_DeleteApp(
      auth: auth,
      guard: guard ??
          AccountDeletionGuard(db: FirebaseFirestore.instance, auth: auth)));
  await _frames(tester);
  final button = find.text('アカウントを削除');
  await tester.scrollUntilVisible(button, 400,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(button);
  if (doubleTap) await tester.tap(button);
  await _frames(tester);
}

Future<void> _confirm(WidgetTester tester,
    [String text = 'DELETE_MY_ACCOUNT']) async {
  expect(find.text('アカウントを削除しますか？'), findsOneWidget);
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('削除する'));
  await _frames(tester);
}

Future<void> _finish(WidgetTester tester) async {
  // Let the existing transient popup remove its OverlayEntry before unmount.
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await _frames(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final functions = _Functions();
  late ({
    Map<String, Map<String, dynamic>> documents,
    VoidCallback notify,
    Future<void> Function() close
  }) backend;
  late _Auth auth;
  setUpAll(() {
    PackageInfo.setMockInitialValues(
        appName: 'HamCare',
        packageName: 'synthetic.deletion',
        version: '0',
        buildNumber: '0',
        buildSignature: 'synthetic');
    backend = installRecordCalendarWidgetBackend(functions: functions);
  });
  setUp(() async {
    auth = _Auth();
    functions.requests.clear();
    functions.response = {'ok': true, 'deletedDocuments': 1};
    functions.fail = false;
    functions.beforeReturn = null;
    backend.documents.remove(_billingPath);
    FlutterSecureStorage.setMockInitialValues({});
    await AiTextConsentStore().accept(_uid);
  });
  tearDownAll(() => backend.close());

  for (final billing in <Map<String, dynamic>?>[
    null,
    {'plan': 'none', 'status': 'none'},
    {'stripeCustomerId': 'synthetic-customer'},
    {'plan': 'none', 'status': 'canceled'},
  ]) {
    testWidgets('confirmed free user deletes with existing payload: $billing',
        (tester) async {
      if (billing != null) backend.documents[_billingPath] = billing;
      await _openDelete(tester, auth);
      await _confirm(tester);
      expect(functions.requests, [
        {'confirmText': 'DELETE_MY_ACCOUNT', 'deleteAuthUser': true}
      ]);
      expect(auth.signOutCalls, 1);
      expect(await AiTextConsentStore().hasAccepted(_uid), isFalse);
      await _finish(tester);
    });
  }

  for (final billing in [
    {'plan': 'paid', 'status': 'active'},
    {'plan': 'paid', 'status': 'trialing'},
    {'plan': 'paid', 'status': 'active', 'cancelAtPeriodEnd': true},
    {'status': 'past_due'},
    {'status': 'unpaid'},
    {'status': 'incomplete'},
    {'status': 'unknown'},
    {'status': 'canceled', 'stripeSubscriptionId': 'synthetic-subscription'},
  ]) {
    testWidgets('contract state cannot bypass deletion: $billing',
        (tester) async {
      backend.documents[_billingPath] = billing;
      await _openDelete(tester, auth);
      expect(find.text('アカウントを削除しますか？'), findsNothing);
      expect(find.text('現在の契約状態では、アカウント削除を完了できません。'), findsOneWidget);
      expect(find.text('プランを管理する'), findsNothing);
      expect(find.text('削除へ進む'), findsNothing);
      expect(functions.requests, isEmpty);
      expect(auth.signOutCalls, 0);
      expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
      await _finish(tester);
    });
  }

  testWidgets('cancel preserves account and consent', (tester) async {
    await _openDelete(tester, auth);
    await tester.tap(find.text('キャンセル'));
    await _frames(tester);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
    await _finish(tester);
  });
  testWidgets('repeated deletion taps open one confirmation and call once',
      (tester) async {
    final guard = _PausedGuard(auth);
    await _openDelete(tester, auth, guard: guard, doubleTap: true);
    expect(guard.checks, 1);
    guard.gate.complete();
    await _frames(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await _confirm(tester);
    expect(guard.checks, 2);
    expect(functions.requests, hasLength(1));
    expect(auth.signOutCalls, 1);
    await _finish(tester);
  });
  testWidgets('wrong confirmation preserves account', (tester) async {
    await _openDelete(tester, auth);
    await _confirm(tester, 'DELETE_OTHER_ACCOUNT');
    expect(find.text('削除確認文字列が一致しませんでした。'), findsOneWidget);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    await _finish(tester);
  });
  testWidgets('unavailable billing does not delete', (tester) async {
    await _openDelete(tester, auth, guard: _UnavailableGuard(auth));
    expect(find.text('アカウントを削除しますか？'), findsNothing);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    await _finish(tester);
  });
  testWidgets('UID changes during confirmation do not delete either account',
      (tester) async {
    await _openDelete(tester, auth);
    auth.currentUser = _User('another-owner');
    await _confirm(tester);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
    await _finish(tester);
  });
  testWidgets('new contract during confirmation is reread and blocks deletion',
      (tester) async {
    await _openDelete(tester, auth);
    backend.documents[_billingPath] = {'plan': 'paid', 'status': 'active'};
    await _confirm(tester);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    await _finish(tester);
  });
  testWidgets('completed old-account deletion never signs out a new account',
      (tester) async {
    functions.beforeReturn = () => auth.currentUser = _User('another-owner');
    await _openDelete(tester, auth);
    await _confirm(tester);
    expect(functions.requests, hasLength(1));
    expect(auth.currentUser?.uid, 'another-owner');
    expect(auth.signOutCalls, 0);
    expect(await AiTextConsentStore().hasAccepted(_uid), isFalse);
    await _finish(tester);
  });
  for (final fail in [false, true]) {
    testWidgets(
        'unconfirmed server deletion cannot report success: throws=$fail',
        (tester) async {
      functions.response = {'ok': false};
      functions.fail = fail;
      await _openDelete(tester, auth);
      await _confirm(tester);
      expect(functions.requests, hasLength(1));
      expect(find.text('削除に失敗しました。'), findsOneWidget);
      expect(auth.signOutCalls, 0);
      expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
      await _finish(tester);
    });
  }
}
