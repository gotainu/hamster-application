import {createHash} from 'crypto';
import {normalizeBillingEmail, validWebBillingUid} from './webBillingShared';

export const BILLING_NOTIFICATION_FROM = 'gotainu@gmail.com';
export type BillingNotificationMailEnvironment = 'preview' | 'live';
export interface BillingNotificationMailConfig {
  enabled: true;
  environment: BillingNotificationMailEnvironment;
  from: typeof BILLING_NOTIFICATION_FROM;
  clientId: string;
  clientSecret: string;
  refreshToken: string;
  allowedSubjectHashes?: readonly string[];
  allowedRecipientHashes?: readonly string[];
}
export type BillingNotificationMailErrorCategory = 'configuration_invalid' | 'recipient_not_allowed' |
  'invalid_recipient' | 'request_invalid' | 'authorization_revoked' | 'authorization_failed' |
  'oauth_temporary' | 'rate_limited' | 'quota_exceeded' | 'sending_limit' |
  'gmail_temporary' | 'delivery_uncertain' | 'gmail_permanent';
export class BillingNotificationMailError extends Error {
  constructor(readonly category: BillingNotificationMailErrorCategory,
    readonly delivery: 'not_sent' | 'uncertain', readonly retryable: boolean,
    readonly retryAfterMillis?: number) {
    super('契約通知の送信を完了できませんでした。');
    this.name = 'BillingNotificationMailError';
  }
}
export interface BillingNotificationMailMessage {
  notificationId: string;
  uid: string;
  to: string;
  subject: string;
  text: string;
  html: string;
}
export interface BillingNotificationGmailDependencies {
  fetchRequest?: typeof fetch;
  now?(): Date;
}
const digest = (v: string) => createHash('sha256').update(v).digest('hex');
const object = (v: unknown): v is Record<string, any> => !!v && typeof v === 'object' && !Array.isArray(v);
const fail = (category: BillingNotificationMailErrorCategory, delivery: 'not_sent'|'uncertain' = 'not_sent', retryable = false,
  retryAfterMillis?: number): never => {throw new BillingNotificationMailError(category,delivery,retryable,retryAfterMillis);};
const validHashes = (v: unknown): v is string[] => Array.isArray(v) && v.length>0 && v.length<=5 &&
  new Set(v).size===v.length && v.every(x=>typeof x==='string' && /^[a-f0-9]{64}$/.test(x));
const secretText = (v: unknown, min: number): v is string => typeof v==='string' && v.length>=min && v.length<=4096 &&
  v===v.trim() && !/[\s\u0000-\u001f\u007f]/u.test(v);

/** Dedicated OAuth user consent only. No service-account, SMTP or Test/Live
 * credential fallback. The caller reads Secret Manager in memory; this parser
 * never reads environment/files, persists values or includes them in errors. */
export function parseBillingNotificationMailConfig(raw: unknown, expectedEnvironment: BillingNotificationMailEnvironment): BillingNotificationMailConfig {
  let v: unknown;
  try {v=typeof raw==='string' ? JSON.parse(raw) : raw;} catch {return fail('configuration_invalid');}
  const keys=['enabled','environment','from','clientId','clientSecret','refreshToken','allowedSubjectHashes','allowedRecipientHashes'];
  if (!['preview','live'].includes(expectedEnvironment) || !object(v) || Object.keys(v).some(k=>!keys.includes(k)) ||
    v.enabled!==true || v.environment!==expectedEnvironment || v.from!==BILLING_NOTIFICATION_FROM ||
    !secretText(v.clientId,10) || !/^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$/.test(v.clientId) ||
    !secretText(v.clientSecret,8) || !secretText(v.refreshToken,16)) return fail('configuration_invalid');
  if (expectedEnvironment==='preview' && (!validHashes(v.allowedSubjectHashes) || !validHashes(v.allowedRecipientHashes))) return fail('configuration_invalid');
  if (expectedEnvironment==='live' && (v.allowedSubjectHashes!==undefined || v.allowedRecipientHashes!==undefined)) return fail('configuration_invalid');
  return Object.freeze({enabled:true,environment:expectedEnvironment,from:BILLING_NOTIFICATION_FROM,
    clientId:v.clientId,clientSecret:v.clientSecret,refreshToken:v.refreshToken,
    ...(expectedEnvironment==='preview' ? {allowedSubjectHashes:Object.freeze([...v.allowedSubjectHashes]),allowedRecipientHashes:Object.freeze([...v.allowedRecipientHashes])} : {})});
}

function validateMessage(message: BillingNotificationMailMessage): string {
  if (!object(message) || Object.keys(message).some(k=>!['notificationId','uid','to','subject','text','html'].includes(k)) ||
    typeof message.notificationId!=='string' || !/^[A-Za-z0-9_-]{1,200}$/.test(message.notificationId) ||
    !validWebBillingUid(message.uid) || typeof message.subject!=='string' || !message.subject ||
    Buffer.byteLength(message.subject,'utf8')>512 || /[\u0000-\u001f\u007f]/u.test(message.subject) ||
    typeof message.text!=='string' || !message.text.trim() || Buffer.byteLength(message.text,'utf8')>100000 ||
    typeof message.html!=='string' || !message.html.trim() || Buffer.byteLength(message.html,'utf8')>100000) return fail('request_invalid');
  const recipient=normalizeBillingEmail(message.to);
  if (!recipient) return fail('invalid_recipient');
  return recipient;
}
function subjectHeader(value: string): string {
  const words:string[]=[]; let chunk='';
  for (const char of value) {
    if (Buffer.byteLength(chunk+char,'utf8')>45) {words.push(chunk);chunk='';}
    chunk+=char;
  }
  if (chunk) words.push(chunk);
  return words.map(s=>'=?UTF-8?B?'+Buffer.from(s,'utf8').toString('base64')+'?=').join('\r\n ');
}
const encodedBody=(value:string)=>Buffer.from(value,'utf8').toString('base64').match(/.{1,76}/g)!.join('\r\n');

/** A stable RFC Message-ID supports operator reconciliation; Gmail messages.send
 * does not promise idempotency or duplicate suppression for this header. */
export function buildBillingNotificationMime(message: BillingNotificationMailMessage, now: Date = new Date()): string {
  const to=validateMessage(message), millis=now instanceof Date ? now.getTime() : NaN;
  if (!Number.isSafeInteger(millis) || millis<=0) return fail('request_invalid');
  const id=digest(message.notificationId), boundary='hamcare_billing_'+id.slice(0,48);
  return ['From: HamCare <'+BILLING_NOTIFICATION_FROM+'>','Reply-To: '+BILLING_NOTIFICATION_FROM,
    'To: <'+to+'>','Subject: '+subjectHeader(message.subject),
    'Date: '+now.toUTCString(),'Message-ID: <hamcare-billing-'+id+'@gmail.com>',
    'MIME-Version: 1.0','Content-Type: multipart/alternative; boundary="'+boundary+'"','',
    '--'+boundary,'Content-Type: text/plain; charset=UTF-8','Content-Transfer-Encoding: base64','',encodedBody(message.text),
    '--'+boundary,'Content-Type: text/html; charset=UTF-8','Content-Transfer-Encoding: base64','',encodedBody(message.html),
    '--'+boundary+'--',''].join('\r\n');
}

function retryAfter(response: Response, now: Date): number | undefined {
  const value=response.headers.get('Retry-After');
  if (!value || value.length>128) return undefined;
  const n=/^\d+$/.test(value) ? Number(value)*1000 : Date.parse(value)-now.getTime();
  return Number.isSafeInteger(n) && n>0 ? n : undefined;
}
async function safeErrorFacts(response: Response): Promise<{reasons:string[];message:string}> {
  // The raw Google error can contain PII. Keep it ephemeral; callers receive
  // only categories, never its text, headers, credentials or response body.
  try {
    const value:any=await response.json();
    const raw=typeof value?.error==='string' ? value.error : value?.error?.message;
    const reasons=Array.isArray(value?.error?.errors) ? value.error.errors.slice(0,8).map((e:any)=>String(e?.reason ?? '').slice(0,100)) : [];
    return {reasons,message:typeof raw==='string' ? raw.slice(0,1000) : ''};
  } catch {return {reasons:[],message:''};}
}
async function rejectResponse(response:Response, phase:'oauth'|'send', now:Date):Promise<never> {
  const facts=await safeErrorFacts(response), reasons=facts.reasons.join(' '), message=facts.message;
  const wait=retryAfter(response,now);
  if (response.status===401 || (phase==='oauth' && /invalid_grant/i.test(message))) return fail('authorization_revoked');
  if (phase==='oauth') {
    if (response.status===429 || response.status>=500) return fail('oauth_temporary','not_sent',true,wait);
    return fail('authorization_failed');
  }
  if ([403,429].includes(response.status)) {
    if (/mail.?sending|sending.?limit|daily.?limit|dailyLimitExceeded|mailRateLimitExceeded/i.test(message+' '+reasons)) return fail('sending_limit','not_sent',true,wait);
    if (/quota|quotaExceeded/i.test(message+' '+reasons)) return fail('quota_exceeded','not_sent',true,wait);
    if (response.status===429 || /rateLimitExceeded|userRateLimitExceeded/i.test(reasons)) return fail('rate_limited','not_sent',true,wait);
    return fail('authorization_failed');
  }
  if (response.status===400) return fail(/recipient|to header|invalid.?to/i.test(message+' '+reasons) ? 'invalid_recipient' : 'request_invalid');
  // A failed send response/timeout can follow acceptance. Do not blindly retry
  // an irreversible send using a gmail.send-only token. OAuth failures above
  // happen before sending and can safely follow exponential backoff.
  if (response.status>=500) return fail('gmail_temporary','uncertain',false,wait);
  if (response.status===408) return fail('delivery_uncertain','uncertain',false,wait);
  return fail('gmail_permanent');
}

export function createBillingNotificationGmailSender(rawConfig: BillingNotificationMailConfig, d: BillingNotificationGmailDependencies = {}) {
  const config=parseBillingNotificationMailConfig(rawConfig,rawConfig?.environment);
  const fetchRequest=d.fetchRequest ?? globalThis.fetch, now=d.now ?? (()=>new Date());
  return {
    async send(message:BillingNotificationMailMessage):Promise<{messageIdHash:string}> {
      const recipient=validateMessage(message);
      if (config.environment==='preview' && (!config.allowedSubjectHashes!.includes(digest(message.uid)) ||
        !config.allowedRecipientHashes!.includes(digest(recipient)))) return fail('recipient_not_allowed');
      const mime=buildBillingNotificationMime(message,now());
      let response:Response;
      try {
        response=await fetchRequest('https://oauth2.googleapis.com/token',{method:'POST',redirect:'error',signal:AbortSignal.timeout(10000),
          headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:config.clientId,
            client_secret:config.clientSecret,refresh_token:config.refreshToken,grant_type:'refresh_token'})});
      } catch {return fail('oauth_temporary','not_sent',true);}
      if (!response.ok) return rejectResponse(response,'oauth',now());
      let access:string;
      try {
        const value:any=await response.json();
        if (!secretText(value?.access_token,1) || (value.token_type!==undefined && value.token_type!=='Bearer') ||
          (value.scope!==undefined && (typeof value.scope!=='string' || value.scope!=='https://www.googleapis.com/auth/gmail.send'))) return fail('authorization_failed');
        access=value.access_token;
      } catch (error) {
        if (error instanceof BillingNotificationMailError) throw error;
        return fail('authorization_failed');
      }
      try {
        response=await fetchRequest('https://gmail.googleapis.com/gmail/v1/users/gotainu%40gmail.com/messages/send',{
          method:'POST',redirect:'error',signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+access,'Content-Type':'application/json'},
          body:JSON.stringify({raw:Buffer.from(mime,'utf8').toString('base64url')})});
      } catch {return fail('delivery_uncertain','uncertain',false);}
      if (!response.ok) return rejectResponse(response,'send',now());
      try {
        const value:any=await response.json();
        if (typeof value?.id!=='string' || !/^[A-Za-z0-9_-]{1,256}$/.test(value.id)) return fail('delivery_uncertain','uncertain',false);
        return {messageIdHash:digest(value.id)};
      } catch {return fail('delivery_uncertain','uncertain',false);}
    },
  };
}
