import {confirmsLiveResponse} from './live-checkout-service.mjs';
const fail=()=>{throw {code:'live/invalid_response'};};
const record=v=>v && typeof v==='object' && !Array.isArray(v);
const masked=v=>typeof v==='string' && /^[^@\s]{1,2}\*{3}@[^@\s]+\.[^@\s]+$/.test(v);
function millis(value) {
  return typeof value?.toMillis==='function' ? value.toMillis() : typeof value?.seconds==='number' ? value.seconds*1000 : typeof value==='number' ? value : typeof value==='string' ? Date.parse(value) : NaN;
}
function date(value) {
  const ms=millis(value);
  return Number.isFinite(ms) && ms>0 ? new Intl.DateTimeFormat('ja-JP',{timeZone:'Asia/Tokyo',year:'numeric',month:'long',day:'numeric',hour:'2-digit',minute:'2-digit'}).format(ms)+'（日本時間）' : '未記録';
}
export function projectLiveCheckoutReview(raw,verify) {
  if (!record(raw) || raw.ok!==true || raw.planKey!=='premium_monthly' || raw.unitAmount!==550 || raw.currency!=='jpy' || raw.interval!=='month' ||
    !/^[A-Za-z0-9_-]{16,128}$/.test(raw.reviewToken) || typeof raw.termsVersion!=='string' || !raw.termsVersion ||
    !['immediate','trial_end'].includes(raw.chargeTiming) || !Number.isSafeInteger(raw.firstChargeAtSeconds) || raw.firstChargeAtSeconds<=0 ||
    (!masked(raw.maskedEmail) && !(raw.maskedEmail==='未設定' && confirmsLiveResponse(raw,verify)))) fail();
  return Object.freeze({reviewToken:raw.reviewToken,nickname:typeof raw.nickname==='string' && raw.nickname.trim()?raw.nickname.trim().slice(0,80):'未設定',maskedEmail:raw.maskedEmail,
    planName:'HamCare プレミアム',amountLabel:'月額550円',cardRegistrationLabel:'申込時',firstChargeLabel:raw.chargeTiming==='trial_end'?date(raw.firstChargeAtSeconds*1000):'申込時（即時）',firstChargeAmountLabel:'550円',
    trialNote:raw.chargeTiming==='trial_end'?'本日の請求：0円。初回550円は、現在の体験終了日時に請求されます。体験の延長・リセットは行いません。':'本日の請求：550円。申し込み時に即時お支払いいただきます。新しい21日体験は始まりません。'});
}
export function projectLiveCheckoutSession(raw) {
  if (!record(raw) || raw.ok!==true || 'testMode' in raw || !/^pk_live_[A-Za-z0-9]{8,}$/.test(raw.publishableKey) || typeof raw.clientSecret!=='string' || raw.clientSecret.length>2048 || !/^cs_live_[\x21-\x7e]+_secret_[\x21-\x7e]+$/.test(raw.clientSecret)) fail();
  return {publishableKey:raw.publishableKey,clientSecret:raw.clientSecret};
}
export function projectLiveCheckoutStatus(raw) {
  if (!record(raw) || raw.ok!==true || 'testMode' in raw || !['open','complete','expired'].includes(raw.checkoutStatus) || (raw.billingState!==undefined && !['confirmed','pending'].includes(raw.billingState))) fail();
  if (raw.checkoutStatus==='complete' && raw.billingState==='confirmed') return {state:'complete',terminal:true,title:'契約情報を再確認しています',copy:'同じアカウントの契約反映を読み直しています。'};
  if (raw.checkoutStatus==='complete') return {state:'processing',terminal:false,title:'契約の反映を待っています',copy:'支払い操作後の契約反映を確認しています。新しい申込を繰り返さず、時間をおいて再確認してください。'};
  if (raw.checkoutStatus==='expired') return {state:'expired',terminal:true,title:'支払い画面の期限が切れました',copy:'支払い完了とは扱っていません。アカウントへ戻り、契約状態を確認してください。'};
  return {state:'open',terminal:false,title:'支払い操作はまだ完了していません',copy:'支払い完了とは扱っていません。Stripeの画面で操作状況を確認してください。'};
}
export function projectLiveBilling(raw, {nowMs=Date.now()} = {}) {
  if (!record(raw) || raw.live!==true || !['none','pending','synced'].includes(raw.syncState)) fail();
  const empty={state:raw.syncState,outcome:'pending',title:'契約状態を確認しています',copy:'サーバーに保存された同じアカウントの情報を表示します。この画面だけでは利用権限を変更しません。',statusLabel:'確認待ち',planLabel:'未確認',amountLabel:'未確認',firstChargeLabel:'未記録',nextChargeLabel:'未記録',periodStartLabel:'未記録',periodEndLabel:'未記録',trialEndLabel:'未記録',cancelLabel:'未確認',syncedAtLabel:'未記録',entitlementLabel:'アプリで確認してください',portalManageable:false,managementCardVisible:false,accessLabel:'アプリで確認してください'};
  if (raw.syncState==='none') return {...empty,outcome:'none',title:'契約の保存記録はありません',copy:'契約完了とは扱っていません。現在の申込受付状況と、プランの内容をご確認ください。',statusLabel:'保存記録なし'};
  if (raw.syncState==='pending') return empty;
  const b=raw.billing,labels={active:'契約中',trialing:'体験期間中・契約登録済み',past_due:'お支払いの確認が必要です',unpaid:'未払い',paused:'契約一時停止',incomplete:'申込未完了',incomplete_expired:'申込期限切れ',canceled:'解約済み',none:'未契約'};
  if (!record(b) || !labels[b.status] || !['paid','none'].includes(b.plan) || (b.cancelAtPeriodEnd!==undefined && typeof b.cancelAtPeriodEnd!=='boolean')) fail();
  const knownPrice=b.amount===550 && b.currency==='jpy' && b.interval==='month';
  const periodEnd=millis(b.currentPeriodEnd),trialEnd=millis(b.trialEnd);
  const active=Number.isFinite(nowMs) && Number.isFinite(periodEnd) && periodEnd>nowMs && b.plan==='paid' &&
    (b.status==='active' || (b.status==='trialing' && Number.isFinite(trialEnd) && trialEnd>nowMs));
  return {...empty,state:'synced',outcome:raw.verifiedBinding===true && active?'active':'stored',title:'保存された契約状態を確認しました',statusLabel:labels[b.status],planLabel:b.plan==='paid'?'HamCare プレミアム':'未契約',
    // Old review contracts may have a zero-charge discount. Never present the new
    // public price as their actual invoice; their terms remain visible in Portal.
    amountLabel:knownPrice?'月額550円／1か月ごとの自動更新':'現在の契約・請求額はStripeの契約管理でご確認ください',
    firstChargeLabel:date(b.firstChargeAt),nextChargeLabel:date(b.nextChargeAt),periodStartLabel:date(b.currentPeriodStart),periodEndLabel:date(b.currentPeriodEnd),trialEndLabel:date(b.trialEnd),
    cancelLabel:b.cancelAtPeriodEnd?'期間末に解約予定':'期間末の解約予定なし',syncedAtLabel:date(b.syncedAtMillis || b.updatedAt),
    portalManageable:raw.portalManageable===true && ['active','trialing','past_due','unpaid','paused','incomplete'].includes(b.status),managementCardVisible:b.status!=='none',
    accessLabel:active && b.cancelAtPeriodEnd?'解約予約済み。表示された契約期間の終了までは利用できます。':'現在の利用可否はアプリでご確認ください。'};
}
export function projectLivePortalSession(raw) {
  if (!record(raw) || raw.ok!==true || 'testMode' in raw || typeof raw.portalUrl!=='string' || raw.portalUrl.length>2048) fail();
  let url;try {url=new URL(raw.portalUrl);} catch {fail();}
  if (url.origin!=='https://billing.stripe.com' || url.username || url.password || url.port || url.hash || /[\\\u0000-\u0020\u007f]/u.test(raw.portalUrl) || url.href!==raw.portalUrl) fail();
  const path=/^\/p\/session\/[A-Za-z0-9_-]+$/.test(url.pathname) && !url.search && !/^\/p\/session\/(?:test|preview)(?:_|$)/i.test(url.pathname);
  const secret=url.searchParams.get('secret') || '';
  const query=url.pathname==='/p/session' && [...url.searchParams.keys()].length===1 && /^[A-Za-z0-9_-]+$/.test(secret) && !/^(?:test|preview)(?:_|$)/i.test(secret) && url.search==='?secret='+secret;
  if (!path && !query) fail();
  return raw.portalUrl;
}
