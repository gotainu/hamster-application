import * as admin from 'firebase-admin';
import Stripe from 'stripe';
import {
  isPaidStripeSubscription,
  selectPreferredPaidSubscription,
} from './stripeSubscriptionPriority';

export const MAX_STRIPE_SYNC_ATTEMPTS = 5;

function timestamp(seconds: unknown): FirebaseFirestore.Timestamp | null {
  return typeof seconds === 'number' && Number.isFinite(seconds)
    ? admin.firestore.Timestamp.fromMillis(seconds * 1000)
    : null;
}

function mappedStatus(status: Stripe.Subscription.Status): string {
  switch (status) {
    case 'active':
    case 'trialing':
    case 'past_due':
    case 'canceled':
    case 'unpaid':
    case 'incomplete':
      return status;
    case 'incomplete_expired':
      return 'incomplete';
    case 'paused':
      return 'unpaid';
    default:
      return 'unknown';
  }
}

function isConflict(error: unknown): boolean {
  const code = (error as {code?: unknown})?.code;
  return [6, 9, '6', '9', 'already-exists', 'failed-precondition',
    'ALREADY_EXISTS', 'FAILED_PRECONDITION'].some(value => value === code);
}

/** Refresh from Stripe outside a transaction, then conditionally commit the
 * billing document version read BEFORE that refresh. A conflicting sync must
 * fetch again; it must never retry an old Stripe response. */
export async function syncStripeSubscription(params: {
  db: FirebaseFirestore.Firestore;
  stripe: Stripe;
  uid: string;
  subscriptionId: string;
  checkoutSessionId?: string | null;
}): Promise<Stripe.Subscription> {
  const {db, stripe, uid, subscriptionId, checkoutSessionId} = params;
  const ref = db.doc(`users/${uid}/billing/subscription`);

  for (let attempt = 0; attempt < MAX_STRIPE_SYNC_ATTEMPTS; attempt++) {
    const before = await ref.get();
    let subscription: Stripe.Subscription = await stripe.subscriptions.retrieve(subscriptionId);
    const customerId = typeof subscription.customer === 'string'
      ? subscription.customer : subscription.customer?.id ?? null;

    // Preserve an existing paid subscription when this subscription ended or
    // failed. The list is current state, including recovery of the same ID.
    if (!isPaidStripeSubscription(subscription) && customerId) {
      const subscriptions = await stripe.subscriptions.list({
        customer: customerId, status: 'all', limit: 100,
      });
      subscription = selectPreferredPaidSubscription(subscriptions.data) ?? subscription;
    }

    const status = mappedStatus(subscription.status);
    const paid = status === 'active' || status === 'trialing';
    const data: FirebaseFirestore.UpdateData<FirebaseFirestore.DocumentData> = {
      provider: 'stripe',
      // Trusted mode metadata supports analytics exclusion; never grants access.
      stripeLivemode: typeof subscription.livemode === 'boolean' ? subscription.livemode : null,
      plan: paid ? 'paid' : 'none',
      status,
      stripeCustomerId: typeof subscription.customer === 'string'
        ? subscription.customer : subscription.customer?.id ?? null,
      stripeSubscriptionId: subscription.id,
      stripePriceId: subscription.items.data[0]?.price?.id ?? null,
      stripeProductId: typeof subscription.items.data[0]?.price?.product === 'string'
        ? subscription.items.data[0]?.price?.product
        : subscription.items.data[0]?.price?.product?.id ?? null,
      currentPeriodEnd: timestamp((subscription as any).current_period_end ??
        (subscription.items.data[0] as any)?.current_period_end),
      cancelAtPeriodEnd: Boolean(subscription.cancel_at_period_end),
      cancelAt: timestamp(subscription.cancel_at),
      latestStripeEventAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (checkoutSessionId != null) data.checkoutSessionId = checkoutSessionId;
    else if (before.exists) data.checkoutSessionId = admin.firestore.FieldValue.delete();
    if (paid && before.exists) data.canceledAt = admin.firestore.FieldValue.delete();
    if (status === 'canceled' && !before.get('canceledAt')) {
      data.canceledAt = admin.firestore.FieldValue.serverTimestamp();
    }

    try {
      // Even an identical notification advances the version. Skipping this
      // write would let an older in-flight response overwrite this refresh.
      if (before.exists) await ref.update(data, {lastUpdateTime: before.updateTime!});
      else await ref.create(data);
      return subscription;
    } catch (error) {
      if (!isConflict(error) || attempt + 1 === MAX_STRIPE_SYNC_ATTEMPTS) throw error;
    }
  }
  throw new Error('Stripe subscription synchronization did not complete.');
}
