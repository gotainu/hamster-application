import {WEB_BILLING_ORIGIN} from './webBillingConfig';

export const BILLING_NOTIFICATION_TEMPLATE_VERSION = 'billing-v1';
export const BILLING_NOTIFICATION_PREVIEW_ORIGIN = 'https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
export type BillingNotificationEnvironment = 'live' | 'preview';
export type BillingNotificationType = 'contract_registered' | 'payment_success' | 'payment_failed' |
  'cancel_reserved' | 'resumed' | 'canceled';
/** Immutable event-time facts only. IDs, contacts, raw Stripe objects and free
 * text are intentionally absent. Old contracts keep their actual old price. */
export interface BillingNotificationSnapshot {
  amount: 550 | 500;
  legacyPrice: boolean;
  currency: 'jpy';
  interval: 'month';
  status: string;
  trialEndSeconds: number | null;
  currentPeriodStartSeconds: number | null;
  currentPeriodEndSeconds: number | null;
  nextChargeAtSeconds: number | null;
  latestInvoicePaymentStatus: 'paid' | 'unpaid' | 'no_payment_required' | 'unknown';
  latestInvoiceAmountPaid: number | null;
  latestInvoiceTotal: number | null;
  canceledAtSeconds: number | null;
  cancelAtPeriodEnd: boolean;
}
export interface BillingNotificationMessage {
  subject: string;
  text: string;
  html: string;
  templateVersion: typeof BILLING_NOTIFICATION_TEMPLATE_VERSION;
}
export class BillingNotificationTemplateError extends Error {
  readonly code = 'template_invalid';
  constructor() {super('Billing notification could not be rendered.');}
}
const fail = (): never => {throw new BillingNotificationTemplateError();};
const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v==='object' && !Array.isArray(v);
const TYPES: BillingNotificationType[] = ['contract_registered','payment_success','payment_failed','cancel_reserved','resumed','canceled'];
const FIELDS = ['amount','legacyPrice','currency','interval','status','trialEndSeconds','currentPeriodStartSeconds',
  'currentPeriodEndSeconds','nextChargeAtSeconds','latestInvoicePaymentStatus','latestInvoiceAmountPaid',
  'latestInvoiceTotal','canceledAtSeconds','cancelAtPeriodEnd'];
const TIMES = ['trialEndSeconds','currentPeriodStartSeconds','currentPeriodEndSeconds','nextChargeAtSeconds','canceledAtSeconds'] as const;
const STATUSES = ['trialing','active','past_due','unpaid','paused','incomplete','incomplete_expired','canceled'];
const validSeconds = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v)>0 && Number(v)<=8_640_000_000_000;
const validAmount = (v: unknown) => v===null || (Number.isSafeInteger(v) && Number(v)>=0);
export function validateBillingNotificationSnapshot(value: unknown): BillingNotificationSnapshot {
  if (!object(value) || Object.keys(value).some(k=>!FIELDS.includes(k)) || FIELDS.some(k=>!Object.prototype.hasOwnProperty.call(value,k)) ||
    value.currency!=='jpy' || value.interval!=='month' || typeof value.legacyPrice!=='boolean' ||
    (value.legacyPrice ? value.amount!==500 : value.amount!==550) || typeof value.status!=='string' || !STATUSES.includes(value.status) ||
    typeof value.latestInvoicePaymentStatus!=='string' || !['paid','unpaid','no_payment_required','unknown'].includes(value.latestInvoicePaymentStatus) ||
    typeof value.cancelAtPeriodEnd!=='boolean' || !validAmount(value.latestInvoiceAmountPaid) || !validAmount(value.latestInvoiceTotal) ||
    TIMES.some(k=>value[k]!==null && !validSeconds(value[k]))) fail();
  const snapshot=value as unknown as BillingNotificationSnapshot;
  if (snapshot.currentPeriodStartSeconds!==null && snapshot.currentPeriodEndSeconds!==null &&
    snapshot.currentPeriodStartSeconds>=snapshot.currentPeriodEndSeconds) fail();
  if (!snapshot.legacyPrice && (snapshot.latestInvoiceTotal!==null && ![0,550].includes(snapshot.latestInvoiceTotal) ||
    snapshot.latestInvoiceAmountPaid!==null && ![0,550].includes(snapshot.latestInvoiceAmountPaid))) fail();
  return Object.freeze({...snapshot});
}
const escapeHtml = (s: string) => s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
export function formatBillingNotificationDate(seconds: number): string {
  if (!validSeconds(seconds)) return fail();
  return new Intl.DateTimeFormat('ja-JP',{timeZone:'Asia/Tokyo',year:'numeric',month:'long',day:'numeric',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date(seconds*1000))+'（日本時間）';
}
export function billingNotificationLinks(mode: BillingNotificationEnvironment): {managementUrl:string; iconUrl:string} {
  const origin = mode==='live' ? WEB_BILLING_ORIGIN : mode==='preview' ? BILLING_NOTIFICATION_PREVIEW_ORIGIN : fail();
  return {managementUrl:origin+'/account/',iconUrl:origin+'/assets/landing/hamcare-mark-outline.png'};
}
function requireDate(value: number | null): string {return value===null ? fail() : formatBillingNotificationDate(value);}

/** Rendering has no transport, Auth, Stripe or Firestore dependencies. Links
 * are fixed management entrances, never opaque Stripe Portal bearer URLs. */
export function renderBillingNotification(input: {
  type: BillingNotificationType;
  mode: BillingNotificationEnvironment;
  snapshot: BillingNotificationSnapshot;
  templateVersion?: typeof BILLING_NOTIFICATION_TEMPLATE_VERSION;
}): BillingNotificationMessage {
  if (!object(input) || Object.keys(input).some(k=>!['type','mode','snapshot','templateVersion'].includes(k)) ||
    !TYPES.includes(input.type) || (input.templateVersion!==undefined && input.templateVersion!==BILLING_NOTIFICATION_TEMPLATE_VERSION)) fail();
  const s=validateBillingNotificationSnapshot(input.snapshot), links=billingNotificationLinks(input.mode);
  const price=`月額${s.amount}円`, rows: string[]=[];
  let title: string;
  if (input.type==='contract_registered') {
    title='プレミアム登録を受け付けました';
    if (s.status==='trialing') {
      if (s.latestInvoiceAmountPaid!==0 || !['paid','no_payment_required'].includes(s.latestInvoicePaymentStatus) || s.latestInvoiceTotal!==0) fail();
      rows.push('カード登録が完了しました。','カード登録時の請求：0円',`初回請求予定日：${requireDate(s.trialEndSeconds)}`,`初回請求予定額：${s.amount}円`);
    } else {
      if (s.status!=='active' || s.latestInvoicePaymentStatus!=='paid' || s.latestInvoiceAmountPaid===null ||
        (!s.legacyPrice && s.latestInvoiceAmountPaid!==550)) fail();
      rows.push('HamCare プレミアムの契約を開始しました。',`今回のお支払い：${s.latestInvoiceAmountPaid}円を確認しました。`);
      if (s.nextChargeAtSeconds!==null) rows.push(`次回請求予定日：${requireDate(s.nextChargeAtSeconds)}`);
    }
    rows.push(`1か月ごとに自動更新され、更新後も${price}です。`);
  } else if (input.type==='payment_success') {
    title='お支払いを確認しました';
    if (s.latestInvoicePaymentStatus!=='paid' || s.latestInvoiceAmountPaid===null || s.latestInvoiceAmountPaid<=0 ||
      (!s.legacyPrice && s.latestInvoiceAmountPaid!==550)) fail();
    rows.push(`お支払い金額：${s.latestInvoiceAmountPaid}円`,`対象期間：${requireDate(s.currentPeriodStartSeconds)} 〜 ${requireDate(s.currentPeriodEndSeconds)}`);
    if (s.nextChargeAtSeconds!==null) rows.push(`次回請求予定日：${requireDate(s.nextChargeAtSeconds)}`);
    else if (s.cancelAtPeriodEnd) rows.push('解約予約済みのため、次回更新は行われません。');
  } else if (input.type==='payment_failed') {
    title='お支払い方法をご確認ください';
    if (s.latestInvoicePaymentStatus==='paid' || s.latestInvoicePaymentStatus==='no_payment_required') fail();
    rows.push('お支払いを確認できませんでした。','契約管理画面からお支払い方法をご確認ください。','カード番号・有効期限・CVCなどのカード情報を、このメールへの返信で送らないでください。');
  } else if (input.type==='cancel_reserved') {
    title='解約予約を受け付けました';
    if (!s.cancelAtPeriodEnd || ['canceled','incomplete_expired'].includes(s.status)) fail();
    rows.push(`現在の契約期間終了予定：${requireDate(s.currentPeriodEndSeconds)}`);
    rows.push(['active','trialing'].includes(s.status) ? '解約手続き後も、現在の契約期間が終了するまではHamCareプレミアムをご利用いただけます。' :
      '契約のご利用状況は、契約管理画面でご確認ください。');
    rows.push('次回更新は行われず、次回更新以降の請求は停止します。','利用者都合の日割り返金は行いません。');
  } else if (input.type==='resumed') {
    title='プレミアムの継続を確認しました';
    if (s.cancelAtPeriodEnd || !['active','trialing'].includes(s.status)) fail();
    rows.push('解約予約の取消を受け付けました。',`HamCare プレミアムは${price}で、1か月ごとの自動更新を継続します。`,
      `次回請求予定日：${requireDate(s.nextChargeAtSeconds)}`);
  } else {
    title='プレミアム契約が終了しました';
    if (s.status!=='canceled') fail();
    rows.push('この契約によるHamCare プレミアムのご利用期間は終了しました。','この契約の次回更新・請求はありません。');
    // Stripe canceled_at can be the earlier period-end cancellation request,
    // so it is not presented as the effective contract-end timestamp.
  }
  const paragraphs = [`対象プラン：HamCare プレミアム（${price}）`,...rows,
    '契約管理・支払方法・請求履歴・解約は、HamCare Webへログインしてご確認ください。'];
  const banner=input.mode==='preview' ? 'これは本人限定のPreviewテスト通知です。本番の契約・請求は変更されていません。' : null;
  const support='お問い合わせ・返信先：gotainu@gmail.com';
  const footer='この通知は契約状態の変更を受け付けた時点の内容です。現在の状態は契約管理画面でご確認ください。このメールは契約・請求に関する重要なお知らせです。広告配信には使用していません。';
  const text=[...(banner?[banner,'']:[]),'HamCare',title,'',...paragraphs,'',`契約管理：${links.managementUrl}`,'',support,footer].join('\n');
  const html='<!doctype html><html lang="ja"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>'+
    '<body style="margin:0;background:#edf7f7;color:#183536;font-family:Arial,\'Hiragino Kaku Gothic ProN\',Meiryo,sans-serif;line-height:1.8">'+
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:24px 12px">'+
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border:1px solid #c5e2e2;border-radius:12px"><tr><td style="padding:24px">'+
    `<p style="margin:0 0 20px"><img src="${escapeHtml(links.iconUrl)}" width="48" height="48" alt="HamCare" style="vertical-align:middle;border-radius:12px"> <strong style="font-size:22px">HamCare</strong></p>`+
    (banner?`<p style="padding:12px;background:#e7f4f4;border-left:4px solid #237c80">${escapeHtml(banner)}</p>`:'')+
    `<h1 style="font-size:22px;line-height:1.5">${escapeHtml(title)}</h1>`+
    paragraphs.map(p=>`<p style="margin:16px 0">${escapeHtml(p)}</p>`).join('')+
    `<p style="margin:24px 0"><a href="${escapeHtml(links.managementUrl)}" style="display:inline-block;background:#206d73;color:#ffffff;padding:12px 20px;border-radius:8px;text-decoration:underline">契約管理を開く</a></p>`+
    `<p style="font-size:14px">${escapeHtml(support)}<br>${escapeHtml(footer)}</p>`+
    '</td></tr></table></td></tr></table></body></html>';
  return {subject:(input.mode==='preview'?'[Preview] ':'')+'【HamCare】'+title,text,html,templateVersion:BILLING_NOTIFICATION_TEMPLATE_VERSION};
}
