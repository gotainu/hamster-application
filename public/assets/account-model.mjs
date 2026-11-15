import { projectPlanReview } from './plan-model.mjs';

// Display-only projections of existing server documents. No entitlement decision.
export function maskEmail(email) {
  if (typeof email !== 'string' || !email.trim()) return '未設定';
  const at = email.lastIndexOf('@');
  if (at < 1 || at === email.length - 1 || /\s/.test(email)) return '確認できません';
  return `${email.slice(0, Math.min(2, at))}***@${email.slice(at + 1)}`;
}

export function loginMethods(providerData = []) {
  const labels = { password: 'メールアドレス／パスワード', 'google.com': 'Google', 'apple.com': 'Apple' };
  const items = Array.isArray(providerData) ? providerData : [];
  const methods = [...new Set(items.map(item => labels[item?.providerId]).filter(Boolean))];
  return methods.length ? methods : ['確認できません'];
}

export function safeAuthError(error) {
  switch (error?.code) {
    case 'auth/invalid-email': return 'メールアドレスの形式を確認してください。';
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found': return 'メールアドレスまたはパスワードが違います。HamCareアプリで使用したログイン方法を選択してください。';
    case 'auth/account-exists-with-different-credential':
    case 'auth/credential-already-in-use': return 'HamCareアプリで使用したログイン方法を選択してください。HamCare独自のアカウント統合は行いません。';
    case 'auth/popup-closed-by-user':
    case 'auth/cancelled-popup-request': return 'ログインを中止しました。必要な場合にもう一度お試しください。';
    case 'auth/popup-blocked': return 'ログイン画面を開けませんでした。ブラウザのポップアップ設定を確認し、ChromeやSafariから直接開いてお試しください。';
    case 'auth/network-request-failed': return '通信に失敗しました。接続を確認してからもう一度お試しください。';
    case 'auth/too-many-requests': return '操作が続いているため、少し時間をおいてからお試しください。';
    case 'auth/web-storage-unsupported': return 'このブラウザでは安全にログイン状態を保持できません。ChromeやSafariから直接開いてお試しください。';
    case 'account/apple-consent-required': return 'Appleログインによるアカウントの関連付けについて確認し、同意する場合にチェックしてください。';
    case 'account/apple-redirect-unavailable': return 'このブラウザではAppleログインから安全に戻れませんでした。ログイン画面へ戻り、もう一度お試しください。';
    case 'auth/operation-not-allowed':
    case 'auth/invalid-oauth-client-id':
    case 'auth/unauthorized-domain': return 'この環境ではログイン設定を確認する必要があります。HamCareアプリで普段使用しているログイン方法を選択してください。';
    case 'auth/missing-or-invalid-nonce':
    case 'auth/invalid-auth-event': return 'ログイン情報を確認できませんでした。HamCareアプリで普段使用しているログイン方法を選び、もう一度お試しください。';
    case 'account/apple-setup-required': return 'AppleでのWebログインは設定確認中です。HamCareアプリで普段使用しているログイン方法を選択してください。';
    case 'account/apple-identity-invalid': return 'Appleでのログインを確認できませんでした。HamCareアプリで普段使用しているログイン方法を選択してください。';
    case 'account/signin-in-progress': return 'ログインまたはログアウトの処理中です。完了してからもう一度お試しください。';
    case 'account/app-account-required': return '先にHamCareアプリでアカウントとペット情報を準備してください。';
    case 'account/app-account-unavailable': return 'HamCareアプリの登録状態を確認できませんでした。通信を確認して再読込してください。';
    case 'account/identity-unverified':
    case 'account/identity-unavailable': return 'ログインの本人確認を完了できませんでした。HamCareアプリで普段使用しているログイン方法で、もう一度ログインしてください。';
    case 'account/session-changed': return 'ログイン状態が変わりました。アカウントを確認し直してください。';
    default: return '現在ログインできません。時間をおいてお試しいただくか、サポートへお問い合わせください。';
  }
}

function storedDate(value) {
  try {
    const date = typeof value?.toDate === 'function' ? value.toDate()
      : value instanceof Date ? value
      : typeof value === 'string' ? new Date(value)
      : typeof value?.seconds === 'number' ? new Date(value.seconds * 1000) : null;
    if (!date || !Number.isFinite(date.getTime())) return '未記録';
    return new Intl.DateTimeFormat('ja-JP', { timeZone: 'Asia/Tokyo', year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(date) + '（日本時間）';
  } catch { return '未記録'; }
}

export function summarizeAccount(user, docs) {
  const unavailableFields = [];
  const readable = (name, label) => {
    const item = docs?.[name];
    if (!item || !['found', 'missing'].includes(item.kind)) { unavailableFields.push(label); return false; }
    return true;
  };
  const ownerOK = readable('owner', 'ニックネーム');
  const billingOK = readable('billing', '契約状態');
  const trialOK = readable('trial', '21日体験の状態');
  const nickname = ownerOK ? docs.owner.data?.displayName : null;
  const unavailable = '取得できませんでした。アプリで確認してください。';
  let billingLabel = billingOK ? '契約の保存記録なし' : unavailable;
  if (billingOK && docs.billing.kind === 'found') {
    const data = docs.billing.data || {};
    const plan = data.plan === 'paid' ? '有料プラン' : data.plan === 'none' ? '未契約として保存' : 'プラン不明';
    const labels = { active: '有効として保存', trialing: '決済側トライアルとして保存', past_due: '支払い確認中', canceled: 'キャンセル済み', unpaid: '未払い', incomplete: '未完了', incomplete_expired: '未完了', none: '未契約として保存' };
    billingLabel = `${plan}／保存状態：${labels[data.status] || '不明'}／契約期間末：${storedDate(data.currentPeriodEnd)}`;
    if (data.cancelAtPeriodEnd === true) billingLabel += '／期間末の解約予定あり';
  }
  let trialLabel = trialOK ? '体験の開始記録なし' : unavailable;
  if (trialOK && docs.trial.kind === 'found') {
    const data = docs.trial.data || {};
    const labels = { active: '体験開始済みとして保存', expired: '体験終了として保存', ended: '体験終了として保存' };
    trialLabel = `保存状態：${labels[data.status] || '不明'}／体験終了日時：${storedDate(data.endsAt)}`;
    if (Number.isInteger(data.aiRequestUsed) && data.aiRequestUsed >= 0 && Number.isInteger(data.aiRequestLimit) && data.aiRequestLimit >= 0) {
      trialLabel += `／AI相談の保存済み利用回数：${data.aiRequestUsed}回（上限${data.aiRequestLimit}回）`;
    }
  }
  const appAccountExists = docs?.pet?.kind === 'found' ? true : docs?.pet?.kind === 'missing' ? false : null;
  const planReview = projectPlanReview(docs?.billing);
  return {
    appAccountExists,
    nickname: ownerOK ? typeof nickname === 'string' && nickname.trim() ? nickname.trim() : '未設定' : unavailable,
    maskedEmail: maskEmail(user?.email),
    methods: loginMethods(user?.providerData),
    billingLabel, trialLabel, unavailableFields,
    planReview: {...planReview, canSelectPlan: appAccountExists === true && planReview.canSelectPlan},
  };
}
