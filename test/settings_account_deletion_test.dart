// Offline Settings + actual callable wrapper. No account is really deleted.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:hamster_project/services/apple_account_deletion_service.dart';
import 'package:hamster_project/services/ai_text_consent_store.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'first_ai_monitoring_cta_test.dart'
    show installRecordCalendarWidgetBackend;

const _uid = 'onboarding-widget-test';
const _billingPath = 'users/$_uid/billing/subscription';
const _trialPath = 'users/$_uid/feature_access/initial_trial_v2';
const _billingNotice = '有料契約中の場合は、今後の自動請求を停止します。';
final _notice = find.textContaining(_billingNotice);
final _completion = find.text('アカウントの削除が完了しました。');

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String? get email => null;
  @override
  List<UserInfo> get providerData => [];
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
  Object? failure;
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
    if (fake.failure case final error?) throw error;
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

class _AppleDeletion extends AppleAccountDeletionService {
  _AppleDeletion(_Auth auth) : super(auth: auth);
  AppleDeletionRevocation outcome = AppleDeletionRevocation.revoked;
  bool identityChanged = false;
  int calls = 0;
  VoidCallback? beforeReturn;

  @override
  Future<AppleDeletionRevocation> prepare(String expectedUid) async {
    expect(expectedUid, _uid);
    calls++;
    if (identityChanged) throw AppleDeletionIdentityChanged();
    beforeReturn?.call();
    return outcome;
  }
}

class _DeleteApp extends MyApp {
  const _DeleteApp(
      {required this.auth, required this.guard, this.appleDeletion});
  final _Auth auth;
  final AccountDeletionGuard guard;
  final AppleAccountDeletionService? appleDeletion;
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
      home: SettingScreen(
        auth: app.auth,
        accountDeletionGuard: app.guard,
        appleDeletionService: app.appleDeletion,
      ),
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
    {AccountDeletionGuard? guard,
    AppleAccountDeletionService? appleDeletion,
    bool doubleTap = false}) async {
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
      appleDeletion: appleDeletion,
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
    functions.failure = null;
    functions.beforeReturn = null;
    backend.documents.remove(_billingPath);
    backend.documents.remove(_trialPath);
    FlutterSecureStorage.setMockInitialValues({});
    await AiTextConsentStore().accept(_uid);
  });
  tearDownAll(() => backend.close());

  for (final billing in <Map<String, dynamic>?>[
    null,
    {'plan': 'none', 'status': 'none'},
    {'stripeCustomerId': 'synthetic-customer'},
    {'plan': 'none', 'status': 'canceled'},
    for (final status in ['canceled', 'incomplete_expired'])
      {
        'plan': 'none',
        'status': status,
        'cancelAtPeriodEnd': false,
        'stripeSubscriptionId': 'sub_synthetic',
        'stripeCustomerId': 'cus_synthetic',
      },
  ]) {
    testWidgets('confirmed free user deletes with existing payload: $billing',
        (tester) async {
      if (billing != null) backend.documents[_billingPath] = billing;
      await _openDelete(tester, auth);
      expect(_notice, findsNothing);
      await _confirm(tester);
      expect(_completion, findsOneWidget);
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
    testWidgets('contract state requires a billing notice: $billing',
        (tester) async {
      backend.documents[_billingPath] = billing;
      await _openDelete(tester, auth);
      expect(_notice, findsOneWidget);
      expect(find.text('プランを管理する'), findsNothing);
      expect(functions.requests, isEmpty);
      await _confirm(tester);
      expect(functions.requests, [
        {
          'confirmText': 'DELETE_MY_ACCOUNT',
          'deleteAuthUser': true,
          'stopBillingConfirmed': true,
        }
      ]);
      expect(_completion, findsOneWidget);
      expect(auth.signOutCalls, 1);
      expect(await AiTextConsentStore().hasAccepted(_uid), isFalse);
      await _finish(tester);
    });
  }

  testWidgets('paid deletion stays operable with a small view and keyboard',
      (tester) async {
    backend.documents[_billingPath] = {'plan': 'paid', 'status': 'active'};
    await _openDelete(tester, auth);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await _frames(tester);

    await tester.ensureVisible(_notice);
    expect(_notice.hitTestable(), findsOneWidget);
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    expect(field.hitTestable(), findsOneWidget);
    expect(find.text('削除する').hitTestable(), findsOneWidget);
    await _confirm(tester);
    expect(functions.requests.single['stopBillingConfirmed'], isTrue);
    expect(_completion, findsOneWidget);
    await _finish(tester);
  });

  testWidgets('free trial has no billing notice', (tester) async {
    backend.documents[_trialPath] = {'status': 'active'};
    await _openDelete(tester, auth);
    expect(_notice, findsNothing);
    await _confirm(tester);
    expect(
        functions.requests.single.containsKey('stopBillingConfirmed'), isFalse);
    expect(auth.signOutCalls, 1);
    await _finish(tester);
  });

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
  testWidgets('server-discovered contract requires another paid confirmation',
      (tester) async {
    functions.failure = FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'synthetic failure',
      details: {'reason': 'paid_confirmation_required'},
    );
    await _openDelete(tester, auth);
    expect(_notice, findsNothing);
    await _confirm(tester);
    expect(
        functions.requests.single.containsKey('stopBillingConfirmed'), isFalse);
    expect(_completion, findsNothing);
    expect(auth.signOutCalls, 0);

    functions.failure = null;
    await tester.tap(find.text('アカウントを削除'));
    await _frames(tester);
    expect(_notice, findsOneWidget);
    await _confirm(tester);
    expect(functions.requests.last['stopBillingConfirmed'], isTrue);
    expect(auth.signOutCalls, 1);
    await _finish(tester);
  });

  testWidgets('manual review directs the user to existing support',
      (tester) async {
    functions.failure = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'synthetic failure',
      details: {'reason': 'manual_review'},
    );
    await _openDelete(tester, auth);
    await _confirm(tester);
    expect(find.textContaining('「お問い合わせ」からご連絡ください。'), findsOneWidget);
    expect(_completion, findsNothing);
    expect(auth.signOutCalls, 0);
    expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
    await _finish(tester);
  });

  for (final code in ['aborted', 'unavailable', 'deadline-exceeded']) {
    testWidgets('unfinished remote deletion can be retried: $code',
        (tester) async {
      functions.failure = FirebaseFunctionsException(
        code: code,
        message: 'synthetic failure',
      );
      await _openDelete(tester, auth);
      await _confirm(tester);
      expect(find.textContaining('もう一度お試しください。'), findsOneWidget);
      expect(_completion, findsNothing);
      expect(auth.signOutCalls, 0);
      expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
      await _finish(tester);
    });
  }

  for (final fail in [false, true]) {
    testWidgets(
        'unconfirmed server deletion cannot report success: throws=$fail',
        (tester) async {
      functions.response = {'ok': false};
      functions.failure =
          fail ? StateError('synthetic callable failure') : null;
      await _openDelete(tester, auth);
      await _confirm(tester);
      expect(functions.requests, hasLength(1));
      expect(find.textContaining('削除に失敗しました。'), findsOneWidget);
      expect(_completion, findsNothing);
      expect(auth.signOutCalls, 0);
      expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
      await _finish(tester);
    });
  }

  testWidgets('Apple revocation precedes the unchanged paid server request',
      (tester) async {
    backend.documents[_billingPath] = {'plan': 'paid', 'status': 'active'};
    final apple = _AppleDeletion(auth)
      ..beforeReturn = () => expect(functions.requests, isEmpty);
    await _openDelete(tester, auth, appleDeletion: apple);
    expect(apple.calls, 0);
    await _confirm(tester);
    expect(apple.calls, 1);
    expect(functions.requests, [
      {
        'confirmText': 'DELETE_MY_ACCOUNT',
        'deleteAuthUser': true,
        'stopBillingConfirmed': true
      }
    ]);
    expect(_completion, findsOneWidget);
    expect(auth.signOutCalls, 1);
    await _finish(tester);
  });

  for (final outcome in [
    AppleDeletionRevocation.cancelled,
    AppleDeletionRevocation.unavailable
  ]) {
    testWidgets('Apple $outcome waits for an explicit manual-revoke choice',
        (tester) async {
      final apple = _AppleDeletion(auth)..outcome = outcome;
      await _openDelete(tester, auth, appleDeletion: apple);
      await _confirm(tester);
      expect(find.text('Apple連携の解除について'), findsOneWidget);
      expect(find.textContaining('「Appleでサインイン」'), findsOneWidget);
      expect(functions.requests, isEmpty);
      expect(auth.signOutCalls, 0);
      await tester.tap(find.text('削除を続ける'));
      await _frames(tester);
      expect(functions.requests, hasLength(1));
      expect(find.textContaining('アカウントの削除が完了しました。Apple設定'), findsOneWidget);
      expect(auth.signOutCalls, 1);
      await _finish(tester);
    });
  }

  testWidgets('returning from Apple fallback preserves the account',
      (tester) async {
    final apple = _AppleDeletion(auth)
      ..outcome = AppleDeletionRevocation.cancelled;
    await _openDelete(tester, auth, appleDeletion: apple);
    await _confirm(tester);
    await tester.tap(find.text('戻る'));
    await _frames(tester);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
    await _finish(tester);
  });

  testWidgets('different Apple identity cannot use the fallback to delete',
      (tester) async {
    final apple = _AppleDeletion(auth)..identityChanged = true;
    await _openDelete(tester, auth, appleDeletion: apple);
    await _confirm(tester);
    expect(find.textContaining('本人のアカウントを確認できませんでした。'), findsOneWidget);
    expect(find.text('削除を続ける'), findsNothing);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    await _finish(tester);
  });

  testWidgets(
      'UID switch while preparing Apple deletion never deletes the new UID',
      (tester) async {
    final apple = _AppleDeletion(auth)
      ..beforeReturn = () => auth.currentUser = _User('another-owner');
    await _openDelete(tester, auth, appleDeletion: apple);
    await _confirm(tester);
    expect(functions.requests, isEmpty);
    expect(auth.signOutCalls, 0);
    await _finish(tester);
  });

  testWidgets(
      'a server failure after Apple revoke is unfinished and retry prepares again',
      (tester) async {
    final apple = _AppleDeletion(auth);
    functions.failure =
        FirebaseFunctionsException(code: 'unavailable', message: 'synthetic');
    await _openDelete(tester, auth, appleDeletion: apple);
    await _confirm(tester);
    expect(apple.calls, 1);
    expect(_completion, findsNothing);
    expect(auth.signOutCalls, 0);
    expect(await AiTextConsentStore().hasAccepted(_uid), isTrue);
    await tester.pump(const Duration(seconds: 5));
    functions.failure = null;
    await tester.tap(find.text('アカウントを削除'));
    await _frames(tester);
    await _confirm(tester);
    expect(apple.calls, 2);
    expect(functions.requests, hasLength(2));
    expect(auth.signOutCalls, 1);
    expect(_completion, findsOneWidget);
    await _finish(tester);
  });
}
