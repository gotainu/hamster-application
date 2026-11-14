import { PREMIUM_MONTHLY } from './plan-model.mjs';

const fail = () => { throw { code: 'preview/invalid-response' }; };
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const isoDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})$/.test(value) && Number.isFinite(Date.parse(value));
const dateLabel = value => new Intl.DateTimeFormat('ja-JP', {
  timeZone: 'Asia/Tokyo', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit',
}).format(new Date(value)) + '（日本時間）';

/** Validate only server-provided quote facts. Never infer access or accept browser prices. */
export function projectCheckoutReview(raw) {
  if (!record(raw) || raw.testMode !== true || raw.planKey !== PREMIUM_MONTHLY.key || raw.amount !== 550 || String(raw.currency).toLowerCase() !== 'jpy' || raw.interval !== 'month') fail();
  if (typeof raw.reviewToken !== 'string' || !/^[A-Za-z0-9_-]{16,512}$/.test(raw.reviewToken)) fail();
  if (!record(raw.account) || typeof raw.account.maskedEmail !== 'string' || !/^[^@\s]{1,2}\*{3}@[^@\s]+\.[^@\s]+$/.test(raw.account.maskedEmail)) fail();
  const billing = raw.billing;
  if (!record(billing) || !['trial', 'immediate'].includes(billing.kind) || billing.firstChargeAmount !== 550 || !isoDate(billing.cardRegistrationAt) || !isoDate(billing.firstChargeAt)) fail();
  if (billing.kind === 'trial') {
    if (!isoDate(billing.trialEndsAt) || Date.parse(billing.firstChargeAt) !== Date.parse(billing.trialEndsAt)) fail();
    const remaining = Date.parse(billing.trialEndsAt) - Date.parse(billing.cardRegistrationAt);
    if (remaining <= 0 || remaining > 21 * 86400000 + 999) fail();
  } else if (billing.trialEndsAt !== null && billing.trialEndsAt !== undefined) fail();
  return Object.freeze({
    reviewToken: raw.reviewToken,
    nickname: typeof raw.account.nickname === 'string' && raw.account.nickname.trim() ? raw.account.nickname.trim().slice(0, 120) : '未設定',
    maskedEmail: raw.account.maskedEmail,
    planName: PREMIUM_MONTHLY.name,
    amountLabel: '月額550円（税込）／税抜500円',
    cardRegistrationLabel: dateLabel(billing.cardRegistrationAt),
    firstChargeLabel: billing.kind === 'trial' ? dateLabel(billing.firstChargeAt) : '申込時（即時）',
    firstChargeAmountLabel: '550円（税込）',
    trialNote: billing.kind === 'trial'
      ? '本日カードをご登録いただきます。最初の550円の請求は、現在の体験終了日時に行われる予定です。それまでは請求されません。体験期間を延長・リセットしたり、新たな21日間を追加したりしません。'
      : '申し込み時に550円（税込）をお支払いいただくテストです。このWeb申込によって、新たな21日体験が始まることはありません。',
  });
}

/** Keep the client secret in controller memory only; never render it or place it in a URL. */
export function projectCheckoutSession(raw) {
  if (!record(raw) || raw.testMode !== true || typeof raw.publishableKey !== 'string' || !/^pk_test_[A-Za-z0-9]{8,}$/.test(raw.publishableKey) || typeof raw.clientSecret !== 'string' || raw.clientSecret.length > 2048 || !/^cs_test_[\x21-\x7e]+_secret_[\x21-\x7e]+$/.test(raw.clientSecret)) fail();
  return { publishableKey: raw.publishableKey, clientSecret: raw.clientSecret };
}

export function projectCheckoutStatus(raw) {
  if (!record(raw) || raw.testMode !== true) fail();
  const noAccess = '現在はPreview環境のため、HamCareアプリの利用権限には反映されません。契約状態の同期は次の開発タスクで実装します。';
  switch (raw.state) {
    case 'none': return { state: 'none', terminal: true, title: '支払い手続きは作成されていません', copy: 'このアカウントに対応するテスト決済の作成記録はありません。支払い完了とは扱わず、プラン確認へ戻ってから内容をお確かめください。' };
    case 'processing': return { state: 'processing', terminal: false, title: 'テスト決済の処理状況を確認しています', copy: `処理結果はまだ確定していません。新しい申込を繰り返さず、少し時間をおいて状況を再確認してください。${noAccess}` };
    case 'complete':
      if (raw.paymentStatus !== 'paid' && raw.paymentStatus !== 'no_payment_required') return { state: 'processing', terminal: false, title: '支払い状態を確認しています', copy: `Stripeの支払い結果はまだ確定していません。少し時間をおいて、状況を再確認してください。${noAccess}` };
      return { state: 'complete', terminal: true, title: 'Stripe Test Modeでの支払い操作が完了しました', copy: noAccess };
    case 'open': return { state: 'open', terminal: false, title: '支払い操作はまだ完了していません', copy: 'Stripeの画面で操作を続けるか、キャンセルしてください。拒否や3D Secureの案内がある場合は、Stripe画面内の表示をご確認ください。' };
    case 'expired': return { state: 'expired', terminal: true, title: '支払い画面の期限が切れました', copy: '以前の支払い画面は再利用しません。プラン確認へ戻って、内容と請求日をもう一度ご確認ください。' };
    case 'canceled': return { state: 'canceled', terminal: true, title: '支払い操作をキャンセルしました', copy: 'プラン確認へ戻れます。HamCareアプリの体験期間や利用権限は変更していません。' };
    case 'payment_failed': return { state: 'payment_failed', terminal: false, title: 'テスト決済を完了できませんでした', copy: 'Stripe画面の拒否理由をご確認ください。HamCareアプリの利用権限は変更していません。' };
    case 'authentication_failed': return { state: 'authentication_failed', terminal: false, title: '本人認証を完了できませんでした', copy: 'Stripe画面の3D Secureの案内をご確認ください。支払い完了とは扱っていません。' };
    default: fail();
  }
}

/** Never echo Stripe/Firebase payloads, resource IDs, or arbitrary backend messages. */
export function checkoutErrorMessage(error) {
  const code = typeof error?.code === 'string' ? error.code.split('/').pop().replaceAll('-', '_') : '';
  switch (code) {
    case 'auth_required': case 'unauthenticated': case 'session_changed': return 'ログイン状態が変わりました。アカウントを確認し直してください。';
    case 'email_unverified': return 'メールアドレスの確認が完了していません。HamCareアプリで確認してからお試しください。';
    case 'app_account_required': return 'HamCareアプリで使用している既存アカウントでログインしてください。';
    case 'already_subscribed': case 'subscription_exists': case 'existing_subscription': return '有効な契約があるため、新しい申込は行いません。HamCareアプリで現在の契約をご確認ください。';
    case 'trial_unavailable': case 'trial_invalid': case 'trial_unresolved': return '体験状態を確認できませんでした。時間をおいて再度お試しいただくか、サポートへお問い合わせください。';
    case 'trial_too_short': return '現在の体験終了日を変更せずにカード登録できる期限を過ぎています。体験終了後に再度お試しください。';
    case 'billing_unresolved': return '現在の契約状態を確認できませんでした。新しい申込は行わず、HamCareアプリまたはサポートでご確認ください。';
    case 'test_webhook_unresolved': return '以前のテスト決済の状態を確認できないため、新しい申込を止めています。状況を再確認するか、サポートへお問い合わせください。';
    case 'processing': return '前の申込処理を確認しています。新しい申込を繰り返さず、支払い状況を再確認してください。';
    case 'preview_limit': return 'Previewのテスト利用上限に達しています。新しい申込は行わず、サポートへお問い合わせください。';
    case 'price_mismatch': return '表示料金と支払い内容の一致を確認できないため、支払い画面へは進みません。サポートへお問い合わせください。';
    case 'test_configuration_invalid': return 'テスト用の支払い設定を安全に確認できませんでした。支払い操作は開始せず、時間をおいて再度お試しください。';
    case 'server_clock_invalid': return '申込日時を安全に確認できませんでした。時間をおいて再度お試しください。';
    case 'invalid_plan': case 'plan_not_allowed': case 'invalid_response': case 'mode_mismatch': case 'server_config': return '申込内容を安全に確認できませんでした。支払い画面へは進んでいません。時間をおいてお試しください。';
    case 'review_expired': case 'review_mismatch': return '確認内容の有効期限が切れました。請求日と条件をもう一度確認してください。';
    case 'session_expired': return '支払い画面の期限が切れました。プラン確認へ戻ってからお試しください。';
    case 'too_many_requests': case 'resource_exhausted': return '操作が続いています。少し時間をおいてからお試しください。';
    case 'network_error': case 'network_request_failed': case 'unavailable': return '通信に失敗しました。申込を繰り返す前に、支払い状況を再確認してください。';
    case 'stripe_load_failed': return 'Stripeの安全な支払い画面を読み込めませんでした。接続を確認してから再度お試しください。';
    default: return '現在、支払い操作の結果を確認できません。状況を再確認するか、サポートへお問い合わせください。';
  }
}
