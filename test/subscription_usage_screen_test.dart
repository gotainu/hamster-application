import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/billing_status.dart';
import 'package:hamster_project/models/entitlement_snapshot.dart';
import 'package:hamster_project/models/initial_trial_access.dart';
import 'package:hamster_project/screens/subscription_plan_screen.dart';
import 'package:hamster_project/services/billing_status_repo.dart';

final _now = DateTime.utc(2030, 1, 1);
BillingStatus _billing({
  BillingStatusValue status = BillingStatusValue.active,
  BillingPlan plan = BillingPlan.paid,
  DateTime? end,
  bool cancel = false,
}) =>
    BillingStatus(
      plan: plan,
      status: status,
      provider: plan == BillingPlan.paid ? 'stripe' : null,
      currentPeriodEnd: end ?? _now.add(const Duration(days: 30)),
      cancelAtPeriodEnd: cancel,
      cancelAt: null,
      updatedAt: null,
    );
InitialTrialAccess _trial({String? status = 'active', DateTime? end}) =>
    InitialTrialAccess(
      status: status,
      endsAt: end ?? _now.add(const Duration(days: 21)),
      policyVersion: 'initial_trial_v2',
      aiRequestLimit: 20,
      aiRequestUsed: 4,
    );

class _Repo extends Fake implements BillingStatusRepo {
  String? uid = 'synthetic-owner-a';
  final auth = StreamController<String?>.broadcast(sync: true);
  final billings =
      <String, StreamController<EntitlementSnapshot<BillingStatus>>>{};
  final trials =
      <String, StreamController<EntitlementSnapshot<InitialTrialAccess>>>{};
  int billingReads = 0, trialReads = 0;
  @override
  String? get currentUserId => uid;
  @override
  Stream<String?> watchUserId() => auth.stream;
  StreamController<EntitlementSnapshot<BillingStatus>> billing([String? id]) =>
      billings.putIfAbsent(
        id ?? uid ?? 'logged-out',
        () => StreamController.broadcast(sync: true),
      );
  StreamController<EntitlementSnapshot<InitialTrialAccess>> trial(
          [String? id]) =>
      trials.putIfAbsent(
        id ?? uid ?? 'logged-out',
        () => StreamController.broadcast(sync: true),
      );
  @override
  Stream<EntitlementSnapshot<BillingStatus>> watchBillingStatus() {
    billingReads++;
    return billing().stream;
  }

  @override
  Stream<EntitlementSnapshot<InitialTrialAccess>> watchInitialTrialAccess() {
    trialReads++;
    return trial().stream;
  }

  void switchUser(String? value) {
    uid = value;
    auth.add(value);
  }

  void emitBilling(BillingStatus value) =>
      billing().add(EntitlementSnapshot.confirmed(uid, value));
  void emitTrial(InitialTrialAccess value) =>
      trial().add(EntitlementSnapshot.confirmed(uid, value));
  Future<void> dispose() async {
    await auth.close();
    for (final value in [...billings.values, ...trials.values]) {
      await value.close();
    }
  }
}

Future<void> _mount(WidgetTester tester, _Repo repo,
    {DateTime Function()? now, MediaQueryData? media}) async {
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: media ?? const MediaQueryData(size: Size(390, 844)),
      child: SubscriptionPlanScreen(billingRepo: repo, now: now ?? () => _now),
    ),
  ));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });
}

void _noPurchaseUi() {
  expect(find.textContaining('月額'), findsNothing);
  expect(find.textContaining('500円'), findsNothing);
  expect(find.textContaining('550円'), findsNothing);
  expect(find.textContaining('登録する'), findsNothing);
  expect(find.textContaining('購入'), findsNothing);
  expect(find.textContaining('Stripe'), findsNothing);
  expect(find.textContaining('Webで'), findsNothing);
  expect(find.text('契約管理'), findsNothing);
  expect(find.textContaining('お支払い方法や解約'), findsNothing);
}

Future<void> _noContract(WidgetTester tester, _Repo repo) async {
  repo.emitBilling(BillingStatus.empty());
  await tester.pump();
}

void main() {
  testWidgets('pending/cached/foreign-UID billing cannot show paid access',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    expect(find.text('利用状況'), findsOneWidget);
    expect(find.text('利用状態を確認しています'), findsOneWidget);
    repo.billing().add(const EntitlementSnapshot.pending('synthetic-owner-a'));
    await tester.pump();
    repo
        .billing()
        .add(EntitlementSnapshot.confirmed('synthetic-other', _billing()));
    await tester.pump();
    expect(find.text('契約管理'), findsNothing);
    expect(find.text('プレミアム利用中です'), findsNothing);
    _noPurchaseUi();
  });

  for (final status in [
    BillingStatusValue.active,
    BillingStatusValue.trialing
  ]) {
    testWidgets('$status shows existing access without billing navigation',
        (tester) async {
      final repo = _Repo();
      await _mount(tester, repo);
      repo.emitBilling(_billing(status: status));
      await tester.pump();
      expect(find.text('プレミアム利用中です'), findsOneWidget);
      expect(find.text('契約管理'), findsNothing);
      expect(find.textContaining('利用可能期限'), findsOneWidget);
      _noPurchaseUi();
    });
  }
  testWidgets(
      'period-end cancellation retains access until end without billing navigation',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    repo.emitBilling(_billing(cancel: true));
    await tester.pump();
    expect(find.text('解約予定です'), findsOneWidget);
    expect(find.textContaining('契約期間が終了するまでは'), findsOneWidget);
    expect(find.text('契約管理'), findsNothing);
    _noPurchaseUi();
  });
  for (final status in [
    BillingStatusValue.pastDue,
    BillingStatusValue.unpaid
  ]) {
    testWidgets('$status shows payment status without billing navigation',
        (tester) async {
      final repo = _Repo();
      await _mount(tester, repo);
      repo.emitBilling(_billing(status: status));
      await tester.pump();
      expect(find.text('お支払いの確認が必要です'), findsOneWidget);
      expect(find.text('契約管理'), findsNothing);
      expect(find.text('プレミアム利用中です'), findsNothing);
      _noPurchaseUi();
    });
  }
  for (final status in [
    BillingStatusValue.none,
    BillingStatusValue.canceled,
    BillingStatusValue.incomplete,
    BillingStatusValue.unknown
  ]) {
    testWidgets('$status offers neither purchase nor a new management session',
        (tester) async {
      final repo = _Repo();
      await _mount(tester, repo);
      repo.emitBilling(_billing(status: status, plan: BillingPlan.none));
      await tester.pump();
      repo.emitTrial(InitialTrialAccess.empty());
      await tester.pump();
      expect(find.text('契約管理'), findsNothing);
      _noPurchaseUi();
    });
  }
  for (final status in [
    BillingStatusValue.canceled,
    BillingStatusValue.incomplete,
    BillingStatusValue.unknown,
  ]) {
    testWidgets('$status marked paid remains status-only without Portal',
        (tester) async {
      final repo = _Repo();
      await _mount(tester, repo);
      repo.emitBilling(_billing(status: status));
      await tester.pump();
      repo.emitTrial(InitialTrialAccess.empty());
      await tester.pump();
      expect(find.text('プレミアム利用中です'), findsNothing);
      _noPurchaseUi();
    });
  }
  testWidgets('billing read errors hide old state; refresh is read-only',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    repo.emitBilling(_billing());
    await tester.pump();
    repo.billing().addError(StateError('synthetic read failure'));
    await tester.pump();
    expect(find.text('利用状態を確認できませんでした'), findsOneWidget);
    expect(find.text('契約管理'), findsNothing);
    await tester.tap(find.text('利用状況を再確認'));
    await tester.pump();
    expect(repo.billingReads, 2);
    expect(repo.trialReads, 2);
    expect(find.text('利用状態を確認しています'), findsOneWidget);
    repo.emitBilling(_billing());
    await tester.pump();
    expect(find.text('プレミアム利用中です'), findsOneWidget);
  });
  testWidgets(
      'UID changes invalidate old billing/trial and management immediately',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    repo.emitBilling(_billing());
    await tester.pump();
    repo.switchUser('synthetic-owner-b');
    await tester.pump();
    repo
        .billing('synthetic-owner-a')
        .add(EntitlementSnapshot.confirmed('synthetic-owner-a', _billing()));
    await tester.pump();
    expect(find.text('契約管理'), findsNothing);
    expect(find.text('プレミアム利用中です'), findsNothing);
    repo.emitBilling(_billing());
    await tester.pump();
    expect(find.text('プレミアム利用中です'), findsOneWidget);
    repo.switchUser(null);
    await tester.pump();
    expect(find.text('契約管理'), findsNothing);
  });
  testWidgets('repository replacement cannot reuse a prior confirmed snapshot',
      (tester) async {
    final a = _Repo(), b = _Repo();
    await _mount(tester, a);
    addTearDown(b.dispose);
    a.emitBilling(_billing());
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: SubscriptionPlanScreen(billingRepo: b, now: () => _now),
      ),
    ));
    expect(find.text('プレミアム利用中です'), findsNothing);
    a.emitBilling(_billing());
    await tester.pump();
    expect(find.text('プレミアム利用中です'), findsNothing);
    b.emitBilling(_billing());
    await tester.pump();
    expect(find.text('プレミアム利用中です'), findsOneWidget);
  });
  testWidgets('free trial remains unstarted without any start/payment action',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    await _noContract(tester, repo);
    repo.emitTrial(InitialTrialAccess.empty());
    await tester.pump();
    expect(find.text('無料体験は未開始です'), findsOneWidget);
    expect(find.textContaining('カード登録は不要'), findsOneWidget);
    expect(find.textContaining('自動課金はありません'), findsOneWidget);
    expect(find.text('21日間の無料体験を始める'), findsNothing);
    _noPurchaseUi();
  });
  testWidgets(
      'server-confirmed active trial shows original deadline and remaining days',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    await _noContract(tester, repo);
    repo.emitTrial(_trial());
    await tester.pump();
    expect(find.text('無料体験中です'), findsOneWidget);
    expect(find.textContaining('残り21日'), findsOneWidget);
    expect(find.textContaining('2030年1月22日'), findsOneWidget);
    _noPurchaseUi();
  });
  testWidgets('cached or different-UID trial cannot display a free-trial state',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    await _noContract(tester, repo);
    repo.trial().add(const EntitlementSnapshot.pending('synthetic-owner-a'));
    await tester.pump();
    repo
        .trial()
        .add(EntitlementSnapshot.confirmed('synthetic-other', _trial()));
    await tester.pump();
    expect(find.text('無料体験中です'), findsNothing);
    expect(find.text('無料体験は未開始です'), findsNothing);
  });
  testWidgets('UID switch cannot reuse a previous account free trial',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    await _noContract(tester, repo);
    repo.emitTrial(_trial());
    await tester.pump();
    expect(find.text('無料体験中です'), findsOneWidget);
    repo.switchUser('synthetic-owner-b');
    await tester.pump();
    await _noContract(tester, repo);
    repo
        .trial('synthetic-owner-a')
        .add(EntitlementSnapshot.confirmed('synthetic-owner-a', _trial()));
    await tester.pump();
    expect(find.text('無料体験中です'), findsNothing);
    expect(find.text('無料体験は未開始です'), findsNothing);
    repo.emitTrial(InitialTrialAccess.empty());
    await tester.pump();
    expect(find.text('無料体験は未開始です'), findsOneWidget);
  });
  for (final status in ['expired', 'ended', 'active']) {
    testWidgets('$status past-deadline trial is neutral and offers no purchase',
        (tester) async {
      final repo = _Repo();
      await _mount(tester, repo);
      await _noContract(tester, repo);
      repo.emitTrial(_trial(
          status: status, end: _now.subtract(const Duration(seconds: 1))));
      await tester.pump();
      expect(find.text('無料体験は終了しました。'), findsOneWidget);
      expect(find.text('このアカウントでは、現在プレミアム機能を利用できません。'), findsOneWidget);
      _noPurchaseUi();
    });
  }
  testWidgets(
      'trial expires at its original deadline without another server event',
      (tester) async {
    var now = _now;
    final repo = _Repo();
    await _mount(tester, repo, now: () => now);
    await _noContract(tester, repo);
    repo.emitTrial(_trial(end: now.add(const Duration(seconds: 2))));
    await tester.pump();
    expect(find.text('無料体験中です'), findsOneWidget);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('無料体験は終了しました。'), findsOneWidget);
  });
  testWidgets('paid access deadline updates display without billing navigation',
      (tester) async {
    var now = _now;
    final repo = _Repo();
    await _mount(tester, repo, now: () => now);
    repo.emitBilling(_billing(end: now.add(const Duration(seconds: 2))));
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('プレミアム利用中です'), findsNothing);
    expect(find.text('プレミアムの利用期間が終了しています'), findsOneWidget);
    expect(find.text('契約管理'), findsNothing);
  });
  testWidgets(
      'resume rechecks both streams without starting or mutating a trial',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    repo.emitBilling(_billing());
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.billingReads, 2);
    expect(repo.trialReads, 2);
    expect(find.text('契約管理'), findsNothing);
    repo.emitBilling(_billing());
    await tester.pump();
    expect(find.text('契約管理'), findsNothing);
  });
  testWidgets('trial failure does not hide verified payment status',
      (tester) async {
    final repo = _Repo();
    await _mount(tester, repo);
    repo.emitBilling(_billing(status: BillingStatusValue.pastDue));
    await tester.pump();
    repo.trial().addError(StateError('synthetic trial failure'));
    await tester.pump();
    expect(find.text('無料体験の状態を確認できませんでした'), findsOneWidget);
    expect(find.text('契約管理'), findsNothing);
  });
  testWidgets('neutral screen keeps legal links at narrow width and large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await _mount(tester, repo,
        media: const MediaQueryData(
            size: Size(360, 800), textScaler: TextScaler.linear(2)));
    repo.emitBilling(_billing());
    await tester.pump();
    await tester.scrollUntilVisible(find.text('利用規約'), 200);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(tester.takeException(), isNull);
    _noPurchaseUi();
  });
}
