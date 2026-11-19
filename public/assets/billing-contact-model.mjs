const validMaskedEmail = value => typeof value === 'string' && /^[^@\s]{1,2}\*{3}@[^@\s]+\.[^@\s]+$/u.test(value);
const date = value => value === null || (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})$/u.test(value) && Number.isFinite(Date.parse(value)));
const invalid = () => { throw {code: 'contact_invalid_response'}; };

/** Display projection only. The server decides contact verification and access. */
export function projectBillingContact(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw) || raw.testMode !== true ||
      !['verified', 'missing', 'pending', 'invalid', 'unverified'].includes(raw.state) ||
      !['normal', 'apple_relay', 'missing', 'unverified', 'invalid'].includes(raw.category) ||
      typeof raw.canCheckout !== 'boolean' ||
      (raw.maskedEmail !== null && !validMaskedEmail(raw.maskedEmail)) ||
      (raw.pendingMaskedEmail !== null && !validMaskedEmail(raw.pendingMaskedEmail)) ||
      !date(raw.resendAfter) || !date(raw.expiresAt) ||
      ![undefined,null,'sent','uncertain','failed'].includes(raw.deliveryState) ||
      ![null, 'auth_verified', 'apple_provider', 'apple_relay', 'user_supplied'].includes(raw.source)) invalid();
  if (raw.canCheckout && (!validMaskedEmail(raw.maskedEmail) || raw.state !== 'verified' || raw.source === null)) invalid();
  if (['invalid', 'unverified'].includes(raw.category) && raw.canCheckout) invalid();
  if (raw.state === 'pending' && !validMaskedEmail(raw.pendingMaskedEmail)) invalid();
  return Object.freeze({testMode: true, state: raw.state, category: raw.category,
    maskedEmail: raw.maskedEmail, pendingMaskedEmail: raw.pendingMaskedEmail,
    canCheckout: raw.canCheckout, source: raw.source, resendAfter: raw.resendAfter, expiresAt: raw.expiresAt,
    deliveryState: raw.deliveryState ?? null});
}

/** Input syntax is not proof of delivery or identity, including Apple relay domains. */
export function normalizeBillingEmail(value) {
  if (typeof value !== 'string') return null;
  const email = value.trim();
  if (email.length > 254 || /[\s\u0000-\u001f\u007f<>"(),;:\\]/u.test(email) ||
      !/^[^@.][^@]*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$/iu.test(email)) return null;
  const at = email.lastIndexOf('@');
  if (at > 64 || email.slice(0,at).endsWith('.') || email.slice(0,at).includes('..')) return null;
  return email.slice(0, at) + '@' + email.slice(at + 1).toLowerCase();
}

/** Remove a confirmation fragment before Firebase or any remote SDK is loaded. */
export function consumeVerificationFragment(location, history) {
  const fragment = typeof location?.hash === 'string' ? location.hash : '';
  if (fragment || location?.search) history?.replaceState(null, '', '/account/contact/');
  if (!fragment) return {token: null, error: null};
  const values = new URLSearchParams(fragment.slice(1));
  const token = values.get('token');
  if ([...values.keys()].length !== 1 || values.getAll('token').length !== 1 ||
      typeof token !== 'string' || !/^[A-Za-z0-9_-]{43,128}$/u.test(token)) return {token: null, error: 'contact_invalid_token'};
  return {token, error: null};
}

export function billingContactError(error) {
  switch (error?.code) {
    case 'contact_invalid_email': return '受信できるメールアドレスを入力してください。';
    case 'contact_not_required': return '登録済みの確認済みメールを利用できます。追加のメール登録は必要ありません。';
    case 'contact_required':
    case 'contact_unverified': return '有料申込の前に、連絡用メールの確認を完了してください。';
    case 'contact_invalid_token': return 'この確認リンクは無効です。新しい確認メールを送信してください。';
    case 'contact_expired': return '確認リンクの有効期限が切れています。新しい確認メールを送信してください。';
    case 'contact_used': return 'この確認リンクはすでに使用されています。現在の連絡先を再確認してください。';
    case 'contact_wrong_user': return '確認メールを申し込んだHamCareアカウントと異なります。同じアカウントでログインし、メールのリンクを開き直してください。';
    case 'contact_rate_limited': return '再送が続いています。しばらく待ってからお試しください。';
    case 'contact_sending': return '送信処理を確認しています。すぐに再送せず、しばらく待ってから状態を再確認してください。';
    case 'contact_delivery_unknown': return '送信結果を確認できませんでした。メールの受信状況を確認し、すぐに再送せず、状態を再確認してください。';
    case 'contact_mail_unavailable': return 'このPreviewの確認メール送信は、まだ利用できません。メールは送信されていません。';
    case 'app_account_required': return '先にHamCareアプリでアカウントとペットプロフィールを準備してください。';
    case 'unauthenticated':
    case 'session_changed': return 'ログイン状態を確認し直してください。確認リンクを使う場合は、同じアカウントでログインしてからメールのリンクを開き直してください。';
    case 'network_error': return '通信結果を確認できませんでした。接続を確認して、現在の連絡先を再確認してください。';
    default: return '連絡用メールの状態を確認できませんでした。時間をおいて再確認してください。';
  }
}
