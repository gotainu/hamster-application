import Stripe from 'stripe';

export function isPaidStripeSubscription(
  subscription: Stripe.Subscription,
): boolean {
  return subscription.status === 'active' || subscription.status === 'trialing';
}

function subscriptionPeriodEndSeconds(
  subscription: Stripe.Subscription,
): number {
  const value =
    (subscription as any).current_period_end ??
    (subscription.items?.data?.[0] as any)?.current_period_end;

  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

export function selectPreferredPaidSubscription(
  subscriptions: Stripe.Subscription[],
): Stripe.Subscription | null {
  const paidSubscriptions = subscriptions
    .filter(isPaidStripeSubscription)
    .sort((left, right) => {
      const periodDifference =
        subscriptionPeriodEndSeconds(right) -
        subscriptionPeriodEndSeconds(left);

      if (periodDifference !== 0) return periodDifference;
      return right.created - left.created;
    });

  return paidSubscriptions[0] ?? null;
}
