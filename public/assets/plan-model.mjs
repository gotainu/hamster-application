// Preview-only presentation of stored billing facts. No Stripe or access verdict.
export const PREMIUM_MONTHLY = Object.freeze({
  key: 'premium_monthly',
  name: 'HamCare プレミアム',
  taxExclusiveYen: 500,
  taxAssumptionPercent: 10,
  taxInclusiveYen: 550,
  interval: 'month',
  previewOnly: true,
});

const CHECKOUT_UNCHECKED = '未照合（決済接続時にサーバーで確認）';
const CUSTOMER_UNREADABLE = '保存参照を取得できませんでした（Stripe側は未照合）';
const CUSTOMER_ABSENT = '保存参照なし（Stripe側は未照合）';
const CUSTOMER_PRESENT = '保存参照あり（Stripe側は未照合）';
const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);

function result(route, title, detail, customerRecord) {
  return Object.freeze({
    route, title, detail,
    canSelectPlan: route === 'review',
    customerRecord,
    checkoutCheck: CHECKOUT_UNCHECKED,
  });
}

function resolve(customerRecord) {
  return result(
    'resolve',
    '現在の契約状態を確認してください',
    '契約状態を安全に確認できないため、このPreviewではプラン選択へ進めません。HamCareアプリの利用プランまたはサポートから確認してください。申込・請求は行いません。',
    customerRecord,
  );
}

export function projectPlanReview(billingItem) {
  if (!isRecord(billingItem)) return resolve(CUSTOMER_UNREADABLE);
  if (billingItem.kind === 'missing') {
    return result(
      'review',
      '月額プランを確認できます',
      '契約の保存記録はありません。Stripe側の契約有無はまだ照合していません。本番の契約・請求は変更しません。テスト用の支払い操作は、次の画面でサーバーが再確認します。',
      CUSTOMER_ABSENT,
    );
  }
  if (billingItem.kind !== 'found' || !isRecord(billingItem.data)) return resolve(CUSTOMER_UNREADABLE);

  const data = billingItem.data;
  // This is the existing billing writer's field, not a client-chosen Customer.
  // Its presence never establishes that the Stripe Customer still exists.
  const customerRecord = typeof data.stripeCustomerId === 'string' && data.stripeCustomerId.trim()
    ? CUSTOMER_PRESENT : CUSTOMER_ABSENT;
  if (data.cancelAtPeriodEnd !== undefined && typeof data.cancelAtPeriodEnd !== 'boolean') return resolve(customerRecord);
  if (data.stripeCustomerId !== undefined && data.stripeCustomerId !== null && typeof data.stripeCustomerId !== 'string') return resolve(customerRecord);

  if (data.plan === 'paid' && (data.status === 'active' || data.status === 'trialing')) {
    return result(
      'manage',
      '現在の契約をご確認ください',
      data.cancelAtPeriodEnd === true
        ? '有料契約と期間末の解約予定が保存されています。重複申込を避けるため新しいプラン選択へは進まず、HamCareアプリで現在の契約を確認してください。'
        : '有料契約の記録が保存されています。重複申込を避けるため、このPreviewでは新しいプラン選択へは進みません。HamCareアプリで現在の契約を確認してください。',
      customerRecord,
    );
  }
  if (data.plan === 'none' && data.status === 'none' && data.cancelAtPeriodEnd !== true) {
    return result(
      'review',
      '月額プランを確認できます',
      '未契約として保存されています。Stripe側の契約有無はまだ照合していません。本番の契約・請求は変更しません。テスト用の支払い操作は、次の画面でサーバーが再確認します。',
      customerRecord,
    );
  }
  if (data.plan === 'none' && data.status === 'canceled') {
    return result(
      'review',
      '月額プランを確認できます',
      'キャンセル済みの契約記録が保存されています。Stripe側の最新状態はまだ照合していません。本番の再契約・請求は行いません。テスト用の支払い操作は、次の画面でサーバーが再確認します。',
      customerRecord,
    );
  }
  // Unknown, payment-attention, partial and inconsistent records stay closed.
  // Dates are intentionally not evaluated: saved active may already be stale.
  return resolve(customerRecord);
}
