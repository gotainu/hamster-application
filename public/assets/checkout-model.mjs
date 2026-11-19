import { PREMIUM_MONTHLY } from './plan-model.mjs';
import { confirmsMissingEmailReview } from './checkout-service.mjs';

const fail = () => { throw { code: 'preview/invalid-response' }; };
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const isoDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})$/.test(value) && Number.isFinite(Date.parse(value));
const dateLabel = value => new Intl.DateTimeFormat('ja-JP', {
  timeZone: 'Asia/Tokyo', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit',
}).format(new Date(value)) + '（日本時間）';

/** Validate only server-provided quote facts. Never infer access or accept browser prices. */
export function projectCheckoutReview(raw, verifyMissingEmailReview) {
  if (!record(raw) || raw.testMode !== true || raw.planKey !== PREMIUM_MONTHLY.key || raw.amount !== 550 || String(raw.currency).toLowerCase() !== 'jpy' || raw.interval !== 'month') fail();
  if (typeof raw.reviewToken !== 'string' || !/^[A-Za-z0-9_-]{16,512}$/.test(raw.reviewToken)) fail();
  if (!record(raw.account) || typeof raw.account.maskedEmail !== 'string') fail();
  const maskedEmail = /^[^@\s]{1,2}\*{3}@[^@\s]+\.[^@\s]+$/.test(raw.account.maskedEmail);
  // A bare display string is not evidence. Only the transport's exact response
  // object, checked against the current Apple identity and own profiles, qualifies.
  const verifiedMissingEmail = raw.account.maskedEmail === '未設定' &&
    confirmsMissingEmailReview(raw, verifyMissingEmailReview);
  if (!maskedEmail && !verifiedMissingEmail) fail();
  const fixture = raw.testDataSource === 'preview_fixture';
  if (raw.testDataSource !== undefined && !['app', 'preview_fixture'].includes(raw.testDataSource)) fail();
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
    trialNote: (fixture ? 'Preview専用のテストデータを使用しています。本番の体験状態は変更しません。' : '') + (billing.kind === 'trial'
      ? fixture ? '本日カードをご登録いただくテストです。本日の請求：0円。初回550円（税込）は、上記の初回請求予定日（Preview専用の体験データに記録した終了日時）に請求される予定です。それまでは請求されません。本番の体験期間を延長・リセットしたり、新たな21日間を追加したりしません。'
        : '本日カードをご登録いただきます。本日の請求：0円。初回550円（税込）は、上記の初回請求予定日（現在の体験終了日時）に請求される予定です。それまでは請求されません。体験期間を延長・リセットしたり、新たな21日間を追加したりしません。'
      : '本日の請求：550円（税込）。申し込み時に即時お支払いいただくテストです。このWeb申込によって、新たな21日体験が始まることはありません。'),
  });
}

/** Keep the client secret in controller memory only; never render it or place it in a URL. */
export function projectCheckoutSession(raw) {
  if (!record(raw) || raw.testMode !== true || typeof raw.publishableKey !== 'string' || !/^pk_test_[A-Za-z0-9]{8,}$/.test(raw.publishableKey) || typeof raw.clientSecret !== 'string' || raw.clientSecret.length > 2048 || !/^cs_test_[\x21-\x7e]+_secret_[\x21-\x7e]+$/.test(raw.clientSecret)) fail();
  return { publishableKey: raw.publishableKey, clientSecret: raw.clientSecret };
}

export function projectCheckoutStatus(raw) {
  if (!record(raw) || raw.testMode !== true) fail();
  const noAccess = '現在はPreview環境のため、HamCareアプリの利用権限には反映されません。WebhookによるPreview契約状態の反映を確認しています。';
  switch (raw.state) {
    case 'none': return { state: 'none', terminal: true, title: '支払い手続きは作成されていません', copy: 'このアカウントに対応するテスト決済の作成記録はありません。支払い完了とは扱わず、プラン確認へ戻ってから内容をお確かめください。' };
    case 'processing': return { state: 'processing', terminal: false, title: 'テスト決済の処理状況を確認しています', copy: `処理結果はまだ確定していません。新しい申込を繰り返さず、少し時間をおいて状況を再確認してください。${noAccess}` };
    case 'complete':
      if (raw.paymentStatus !== 'paid' && raw.paymentStatus !== 'no_payment_required') return { state: 'processing', terminal: false, title: '支払い状態を確認しています', copy: `Stripeの支払い結果はまだ確定していません。少し時間をおいて、状況を再確認してください。${noAccess}` };
      return { state: 'complete', terminal: true, title: 'Stripe Test Modeの支払い情報を確認しています', copy: noAccess };
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
  if (['contact_verification_required','contact_auth_email_unverified','contact_state_invalid','contact_identity_invalid'].includes(error?.code)) return '有料申込の前に連絡用メールの確認を完了してください。アカウント確認へ戻り、連絡先の状態をご確認ください。';
  const code = typeof error?.code === 'string' ? error.code.split('/').pop().replaceAll('-', '_') : '';
  switch (code) {
    case 'auth_required': case 'unauthenticated': case 'session_changed': return 'ログイン状態が変わりました。アカウントを確認し直してください。';
    case 'email_unverified': return 'メールアドレスの確認が完了していません。HamCareアプリで確認してからお試しください。';
    case 'app_account_required': return 'HamCareアプリで使用している既存アカウントでログインしてください。';
    case 'already_subscribed': case 'subscription_exists': case 'existing_subscription': return '有効な契約があるため、新しい申込は行いません。Webのアカウント確認へ戻り、契約管理の案内をご確認ください。';
    case 'trial_unavailable': case 'trial_invalid': case 'trial_unresolved': return '体験状態を確認できませんでした。時間をおいて再度お試しいただくか、サポートへお問い合わせください。';
    case 'trial_too_short': return '現在の体験終了日を変更せずにカード登録できる期限を過ぎています。体験終了後に再度お試しください。';
    case 'billing_unresolved': return '現在の契約状態を確認できませんでした。新しい申込は行わず、Webの契約管理の案内またはサポートでご確認ください。';
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


/** Readonly projection of the server's isolated Webhook mirror; never decide app access. */
export function projectPreviewBilling(raw) {
  if (!record(raw) || raw.testMode !== true || !['none', 'pending', 'synced', 'unavailable'].includes(raw.syncState)) fail();
  const disclaimer = 'Preview専用のテスト契約です。HamCareアプリの本番利用権限には反映されません。';
  const empty = {
    state: raw.syncState, outcome: 'pending', title: '支払い情報を確認しています', copy: `Webhookによる契約状態の反映を待っています。${disclaimer}`,
    statusLabel: '反映待ち', planLabel: '未確認', amountLabel: '未確認', firstChargeLabel: '未記録', nextChargeLabel: '予定を確認できません',
    periodStartLabel: '未記録', periodEndLabel: '未記録', trialEndLabel: '未記録', cancelLabel: '未確認', syncedAtLabel: '未記録', entitlementLabel: '未確認',
    portalManageable: false, managementCardVisible: false, accessLabel: '利用状態は確認できません',
    managementNotice: '管理可能なPreview契約は、アカウント確認画面から支払方法・請求・期間末解約を管理できます。',
  };
  if (raw.syncState === 'none') return Object.freeze({...empty, outcome: 'none', title: 'Preview契約の反映記録はありません', copy: `同期されたテスト契約の記録はありません。未契約や支払い完了とは断定していません。${disclaimer}`, statusLabel: '反映記録なし'});
  if (raw.syncState === 'unavailable') return Object.freeze({...empty, outcome: 'unknown', title: 'Preview契約状態を確認できません', copy: `時間をおいて再確認するか、サポートへお問い合わせください。${disclaimer}`, statusLabel: '確認できません'});
  if (raw.syncState === 'pending') return Object.freeze(empty);
  const billing = raw.billing;
  if (!record(billing) || billing.planKey !== PREMIUM_MONTHLY.key || billing.amount !== 550 || String(billing.currency).toLowerCase() !== 'jpy' || billing.interval !== 'month' || !isoDate(billing.syncedAt)) fail();
  if (billing.cancelAtPeriodEnd !== true && billing.cancelAtPeriodEnd !== false) fail();
  if (billing.entitlementMirror !== true && billing.entitlementMirror !== false && billing.entitlementMirror !== null) fail();
  const date = value => { if (value === null || value === undefined) return '未記録'; if (!isoDate(value)) fail(); return dateLabel(value); };
  const statuses = {
    trialing: '体験期間中・契約登録済み', active: '有料会員', past_due: 'お支払いの確認が必要です', unpaid: 'お支払いを確認できませんでした',
    paused: '契約は一時停止中です', incomplete: 'お申し込みは未完了です', incomplete_expired: 'お申し込みの有効期限が切れました', canceled: '解約済み',
  };
  const fixtureNote = billing.testDataSource === 'preview_fixture' ? 'Preview専用のテストデータを使用しています。本番の体験状態は変更しません。' : '';
  const result = {...empty, state: 'synced', outcome: 'stored', statusLabel: statuses[billing.status] || '契約状態を確認できません', planLabel: PREMIUM_MONTHLY.name,
    amountLabel: '月額550円（税込）／1か月ごとの自動更新', firstChargeLabel: date(billing.firstChargeAt), nextChargeLabel: billing.nextChargeAt ? date(billing.nextChargeAt) : '予定を確認できません',
    periodStartLabel: date(billing.currentPeriodStart), periodEndLabel: date(billing.currentPeriodEnd), trialEndLabel: date(billing.trialEnd),
    cancelLabel: billing.cancelAtPeriodEnd ? '期間末に解約予定' : '期間末の解約予定なし', syncedAtLabel: date(billing.syncedAt),
    entitlementLabel: billing.entitlementMirror === true ? '有効として保存（Preview限定）' : billing.entitlementMirror === false ? '無効として保存（Preview限定）' : '確認できません',
    portalManageable: billing.portalManageable === true && ['trialing', 'active', 'past_due', 'unpaid', 'paused', 'incomplete'].includes(billing.status),
    managementCardVisible: Boolean(statuses[billing.status]),
    accessLabel: ['past_due', 'unpaid'].includes(billing.status) ? 'お支払い方法の確認が必要です。' : ['active', 'trialing'].includes(billing.status) && billing.entitlementMirror === true ? '現在の契約期間終了まで利用可能（Preview限定）' : '現在の利用可否は確認が必要です。',
    title: 'Preview契約状態の反映を確認しました', copy: fixtureNote + disclaimer,
  };
  if (billing.status === 'trialing' && billing.entitlementMirror === true) {
    if (!isoDate(billing.firstChargeAt) || !isoDate(billing.trialEnd) || Date.parse(billing.firstChargeAt) !== Date.parse(billing.trialEnd)) fail();
    result.outcome = 'trialing'; result.title = 'カード登録が完了しました（Stripe Test Mode／Preview）';
    result.copy = fixtureNote + `最初の550円の請求は${dateLabel(billing.firstChargeAt)}の予定です。${billing.testDataSource === 'preview_fixture' ? 'Preview専用データで確認しています。' : '既存の体験終了日時は変更していません。'}${disclaimer}`;
  } else if (billing.status === 'active' && billing.entitlementMirror === true) {
    result.outcome = 'active'; result.title = '有料会員登録が完了しました（Stripe Test Mode／Preview）';
  } else if (['past_due', 'unpaid', 'incomplete', 'incomplete_expired'].includes(billing.status)) {
    result.outcome = 'attention'; result.title = 'お支払いを確認できませんでした（Preview）';
    result.copy = fixtureNote + `支払いに確認が必要な状態として同期されています。新しい申込を繰り返さず、サポートへお問い合わせください。${disclaimer}`;
  } else if (!statuses[billing.status]) {
    result.outcome = 'unknown'; result.title = 'Preview契約状態を確認できません';
  }
  return Object.freeze(result);
}


/** Only the newly issued, dedicated Test Mode Portal destination may navigate. */
export function projectPreviewPortalSession(raw) {
  if (!record(raw) || raw.testMode !== true || typeof raw.url !== 'string' || raw.url.length > 2048 || !/^[\x21-\x7e]+$/.test(raw.url)) fail();
  let url;
  try { url = new URL(raw.url); } catch { fail(); }
  const pathSession = /^\/p\/session\/test_[A-Za-z0-9_-]+$/.test(url.pathname) && !url.search;
  const querySession = url.pathname === '/p/session' && [...url.searchParams.keys()].length === 1 && /^test_[A-Za-z0-9_-]+$/.test(url.searchParams.get('secret') || '') && url.search === '?secret=' + url.searchParams.get('secret');
  if (url.origin !== 'https://billing.stripe.com' || url.username || url.password || url.port || url.hash || (!pathSession && !querySession) || url.href !== raw.url) fail();
  return raw.url;
}

export function portalErrorMessage(error) {
  const code = typeof error?.code === 'string' ? error.code.split('/').pop().replaceAll('-', '_') : '';
  switch (code) {
    case 'unauthenticated': case 'session_changed': case 'auth_required': return 'ログイン状態が変わりました。アカウントを確認し直してください。';
    case 'email_unverified': return 'メールアドレスを確認してから、もう一度お試しください。';
    case 'portal_not_available': case 'subscription_not_manageable': case 'customer_missing': case 'customer_not_found': return '管理できるテスト契約を確認できません。契約状態を再確認してください。';
    case 'network_error': case 'network_request_failed': case 'unavailable': return '契約管理画面へ接続できませんでした。通信を確認してから、もう一度お試しください。';
    case 'too_many_requests': case 'resource_exhausted': return '操作が続いています。少し時間をおいてからお試しください。';
    default: return '安全に契約管理画面を開けませんでした。契約状態を再確認するか、サポートへお問い合わせください。';
  }
}
