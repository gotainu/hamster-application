const test = require('node:test');
const assert = require('node:assert/strict');

const {
  isPaidStripeSubscription,
  selectPreferredPaidSubscription,
} = require('../lib/stripeSubscriptionPriority');

function subscription(id, status, currentPeriodEnd, created) {
  return {
    id,
    status,
    created,
    items: {
      data: [
        {
          current_period_end: currentPeriodEnd,
        },
      ],
    },
  };
}

test('active and trialing subscriptions are paid', () => {
  assert.equal(isPaidStripeSubscription(subscription('a', 'active', 10, 1)), true);
  assert.equal(isPaidStripeSubscription(subscription('b', 'trialing', 10, 1)), true);
  assert.equal(isPaidStripeSubscription(subscription('c', 'incomplete', 10, 1)), false);
  assert.equal(isPaidStripeSubscription(subscription('d', 'canceled', 10, 1)), false);
});

test('a paid subscription wins over incomplete and canceled subscriptions', () => {
  const active = subscription('active', 'active', 200, 2);
  const selected = selectPreferredPaidSubscription([
    subscription('incomplete', 'incomplete', 300, 3),
    active,
    subscription('canceled', 'canceled', 400, 4),
  ]);

  assert.equal(selected?.id, 'active');
});

test('the paid subscription with the latest period end wins', () => {
  const selected = selectPreferredPaidSubscription([
    subscription('older', 'active', 100, 10),
    subscription('newer', 'trialing', 200, 5),
  ]);

  assert.equal(selected?.id, 'newer');
});

test('no paid subscription returns null', () => {
  const selected = selectPreferredPaidSubscription([
    subscription('incomplete', 'incomplete', 100, 1),
    subscription('expired', 'canceled', 200, 2),
  ]);

  assert.equal(selected, null);
});
