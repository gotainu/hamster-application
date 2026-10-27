import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/billing_status.dart';

BillingStatus subscription({
  BillingStatusValue status = BillingStatusValue.active,
  BillingPlan plan = BillingPlan.paid,
  bool expired = false,
  bool cancelAtPeriodEnd = false,
}) =>
    BillingStatus(
      plan: plan,
      status: status,
      provider: plan == BillingPlan.paid ? 'stripe' : null,
      currentPeriodEnd: DateTime.now().add(Duration(days: expired ? -1 : 30)),
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      cancelAt: null,
      updatedAt: null,
    );

void main() {
  test('subscription identity is separate from current paid access', () {
    final ended = subscription(expired: true);
    expect(ended.isPaid, isTrue);
    expect(ended.canUsePaidFeatures, isFalse);
    expect(ended.canManageSubscription, isTrue);
    expect(ended.statusLabel, '利用期間終了');
  });

  for (final status in [
    BillingStatusValue.pastDue,
    BillingStatusValue.unpaid
  ]) {
    test('$status can manage payment without granting paid access', () {
      final billing = subscription(status: status);
      expect(billing.canUsePaidFeatures, isFalse);
      expect(billing.canManageSubscription, isTrue);
      expect(billing.needsPaymentAttention, isTrue);
    });
  }

  test('scheduled cancellation keeps existing access through the paid period',
      () {
    final billing = subscription(cancelAtPeriodEnd: true);
    expect(billing.canUsePaidFeatures, isTrue);
    expect(billing.isCancellationScheduled, isTrue);
    expect(billing.canManageSubscription, isTrue);
    expect(billing.effectiveCancelAt, billing.currentPeriodEnd);
  });

  test('expired cancellation does not retain feature access', () {
    final billing = subscription(expired: true, cancelAtPeriodEnd: true);
    expect(billing.canUsePaidFeatures, isFalse);
    expect(billing.isCancellationScheduled, isFalse);
    expect(billing.canManageSubscription, isTrue);
  });

  test('no subscription and canceled status do not gain access', () {
    expect(BillingStatus.empty().canUsePaidFeatures, isFalse);
    expect(BillingStatus.empty().canManageSubscription, isFalse);
    expect(subscription(status: BillingStatusValue.canceled).canUsePaidFeatures,
        isFalse);
  });
}
