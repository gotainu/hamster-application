import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/billing_status.dart';
import 'package:hamster_project/models/entitlement_snapshot.dart';
import 'package:hamster_project/models/initial_trial_access.dart';

// These tests preserve the temporary management/deletion boundary. They do not
// certify that account deletion is safe: the server-side contract/deletion
// lifecycle remains a documented release blocker and is outside this change.
String _source(String path) => File(path).readAsStringSync();

BillingStatus _subscription(
  BillingStatusValue status, {
  BillingPlan plan = BillingPlan.paid,
  required DateTime periodEnd,
  bool cancelAtPeriodEnd = false,
}) =>
    BillingStatus(
      plan: plan,
      status: status,
      provider: 'stripe',
      currentPeriodEnd: periodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      cancelAt: null,
      updatedAt: null,
    );

void main() {
  group('temporary deletion management exception', () {
    test('deletion warning retains the route to existing contract management',
        () {
      final source = _source('lib/screens/settings.dart');
      final start = source.indexOf('Future<void> _deleteAccount()');
      final end = source.indexOf('Future<void> _revokeAiTextConsent()', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final deletion = source.substring(start, end);
      expect(deletion, contains('アカウントを削除しても'));
      expect(deletion, contains('自動では解約されません'));
      expect(deletion, contains("subscriptionChoice == 'manage-plan'"));
      expect(deletion, contains('const SubscriptionPlanScreen()'));
      expect(deletion, isNot(contains('createStripeCheckoutSession')));
      expect(deletion, isNot(contains('checkoutUrl')));
    });

    test(
        'existing contract Portal callable is retained without client purchase',
        () {
      final source = _source('lib/screens/subscription_plan_screen.dart');
      expect(source, contains('createStripeCustomerPortalSession'));
      expect(source, contains('_openCustomerPortal'));
      expect(source, contains('canManageSubscription'));
      expect(source, isNot(contains('createStripeCheckoutSession')));
      expect(source, isNot(contains('checkoutUrl')));
    });

    test('deletion request does not gain a client-controlled contract identity',
        () {
      final source = _source('lib/services/account_delete_service.dart');
      expect(source, contains("httpsCallable('deleteMyAccountAndData')"));
      expect(source, contains("'confirmText': confirmText"));
      expect(source, contains("'deleteAuthUser': deleteAuthUser"));
      expect(source, isNot(contains("'uid':")));
      expect(source, isNot(contains('stripeCustomerId')));
    });

    test('known deletion risk stays an explicit release blocker', () {
      final audit =
          _source('docs/release/flutter_strategy_c_cta_audit_20261121.md');
      expect(audit, contains('契約中ユーザーのアカウント削除'));
      expect(audit, contains('NO-GO'));
      expect(audit, contains('Portalを残す'));
      expect(audit, contains('Stripe状態確認/解約'));
    });
  });

  group('UID subscription access remains independent of purchasing', () {
    final now = DateTime.utc(2034, 1, 1);
    final end = now.add(const Duration(days: 30));

    for (final status in [
      BillingStatusValue.active,
      BillingStatusValue.trialing,
    ]) {
      test('$status retains access without another purchase', () {
        final billing = _subscription(status, periodEnd: end);
        expect(billing.canUsePaidFeaturesAt(now), isTrue);
        expect(billing.canManageSubscription, isTrue);
      });

      test('$status cancellation reservation retains access until exact end',
          () {
        final billing =
            _subscription(status, periodEnd: end, cancelAtPeriodEnd: true);
        expect(billing.cancelAtPeriodEnd, isTrue);
        expect(billing.effectiveCancelAt, end);
        expect(
            billing.canUsePaidFeaturesAt(
                end.subtract(const Duration(microseconds: 1))),
            isTrue);
        expect(billing.canUsePaidFeaturesAt(end), isFalse);
        expect(billing.canManageSubscription, isTrue);
      });
    }

    for (final status in [
      BillingStatusValue.pastDue,
      BillingStatusValue.unpaid,
    ]) {
      test('$status retains payment management without granting access', () {
        final billing =
            _subscription(status, plan: BillingPlan.none, periodEnd: end);
        expect(billing.canUsePaidFeaturesAt(now), isFalse);
        expect(billing.canManageSubscription, isTrue);
        expect(billing.needsPaymentAttention, isTrue);
      });
    }

    for (final status in [
      BillingStatusValue.canceled,
      BillingStatusValue.incomplete,
      BillingStatusValue.unknown,
      BillingStatusValue.none,
    ]) {
      test('$status cannot unlock paid features', () {
        expect(_subscription(status, periodEnd: end).canUsePaidFeaturesAt(now),
            isFalse);
      });
    }

    test('no contract cannot unlock paid features or Portal management', () {
      expect(BillingStatus.empty().canUsePaidFeaturesAt(now), isFalse);
      expect(BillingStatus.empty().canManageSubscription, isFalse);
    });

    test('pending or unsigned snapshots do not grant confirmed access', () {
      expect(
          const EntitlementSnapshot<BillingStatus>.pending('synthetic-owner')
              .isServerConfirmed,
          isFalse);
      expect(
          EntitlementSnapshot<BillingStatus>.confirmed(null,
                  _subscription(BillingStatusValue.active, periodEnd: end))
              .isServerConfirmed,
          isFalse);
      expect(
          EntitlementSnapshot<BillingStatus>.confirmed('synthetic-owner',
                  _subscription(BillingStatusValue.active, periodEnd: end))
              .isServerConfirmed,
          isTrue);
    });
  });

  test('initial trial remains 21 days even after the AI count is exhausted',
      () {
    final start = DateTime.utc(2034, 1, 1);
    final end = start.add(const Duration(days: 21));
    final trial = InitialTrialAccess(
      status: 'active',
      endsAt: end,
      policyVersion: 'initial_trial_v2',
      aiRequestLimit: 20,
      aiRequestUsed: 20,
    );
    expect(trial.isActiveAt(start), isTrue);
    expect(trial.isActiveAt(end.subtract(const Duration(microseconds: 1))),
        isTrue);
    expect(trial.isActiveAt(end), isFalse);
    expect(trial.aiRequestLimit, 20);
    expect(trial.aiRequestUsed, 20);
  });
}
