import {createHash} from 'crypto';
import {BILLING_CONTACT_FROM,BillingContactError,BillingContactMail,normalizeBillingEmail} from './billing-contact';

export const CONTACT_MAIL_SECRET='HAMCARE_PREVIEW_CONTACT_MAIL_CONFIG';
export interface ContactMailConfig {
  enabled:boolean; environment:'preview'; from:typeof BILLING_CONTACT_FROM;
  clientId?:string; clientSecret?:string; refreshToken?:string;
  allowedSubjectHashes:string[]; allowedRecipientHashes:string[];
}
const digest=(v:string)=>createHash('sha256').update(v).digest('hex');
const denied=()=>new BillingContactError('contact_mail_unavailable');
const hashes=(v:unknown):v is string[]=>Array.isArray(v)&&v.length>0&&v.length<=5&&v.every(x=>typeof x==='string'&&/^[a-f0-9]{64}$/.test(x));
export function parseContactMailConfig(raw:string):ContactMailConfig {
  let v:any;try{v=JSON.parse(raw);}catch{throw denied();}
  if(!v||v.environment!=='preview'||v.from!==BILLING_CONTACT_FROM||typeof v.enabled!=='boolean'||!Array.isArray(v.allowedSubjectHashes)||!Array.isArray(v.allowedRecipientHashes))throw denied();
  if(v.enabled && (!hashes(v.allowedSubjectHashes)||!hashes(v.allowedRecipientHashes)||
      typeof v.clientId!=='string'||!v.clientId.endsWith('.apps.googleusercontent.com')||/[\s\r\n]/.test(v.clientId)||
      typeof v.clientSecret!=='string'||v.clientSecret.length<8||/[\r\n]/.test(v.clientSecret)||
      typeof v.refreshToken!=='string'||v.refreshToken.length<16||/[\r\n]/.test(v.refreshToken)))throw denied();
  return v;
}
export function assertContactTestSubject(config:ContactMailConfig,uid:string):void {
  if(!config.enabled||!config.allowedSubjectHashes.includes(digest(uid)))throw denied();
}
/** Preview-only, gmail.send OAuth. No SMTP password, impersonation or fallback sender. */
export function createPreviewGmailSender(config:ContactMailConfig,uid:string,{fetchRequest=globalThis.fetch,reserve=async()=>{}}:{fetchRequest?:typeof fetch;reserve?:()=>Promise<void>}={}) {
  assertContactTestSubject(config,uid);
  return async(message:BillingContactMail):Promise<void>=>{
    const email=normalizeBillingEmail(message.to);
    if(!email||message.from!==BILLING_CONTACT_FROM||!config.allowedRecipientHashes.includes(digest(email))||
       !message.verificationUrl.startsWith('https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/contact/#token=')||
       !/^[A-Za-z0-9_-]{43}$/.test(message.verificationUrl.split('#token=')[1]||''))throw Object.assign(denied(),{delivery:'not_sent'});
    // Global and per-UID quotas are reservations, never reset after an unknown result.
    await reserve();
    let access:string;
    try {
      const r=await fetchRequest('https://oauth2.googleapis.com/token',{method:'POST',redirect:'error',signal:AbortSignal.timeout(10000),headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:config.clientId!,client_secret:config.clientSecret!,refresh_token:config.refreshToken!,grant_type:'refresh_token'})});
      if(!r.ok)throw denied();const value:any=await r.json();
      if(typeof value.access_token!=='string'||!value.access_token||/[\s\r\n]/.test(value.access_token))throw denied();
      access=value.access_token;
    }catch{throw Object.assign(denied(),{delivery:'not_sent'});}
    const mime=['From: HamCare Preview <'+BILLING_CONTACT_FROM+'>','To: <'+email+'>',
      'Subject: =?UTF-8?B?'+Buffer.from(message.subject,'utf8').toString('base64')+'?=',
      'MIME-Version: 1.0','Content-Type: text/plain; charset=UTF-8','Content-Transfer-Encoding: base64','',Buffer.from(message.text,'utf8').toString('base64')].join('\r\n');
    let response:Response;
    try {
      response=await fetchRequest('https://gmail.googleapis.com/gmail/v1/users/gotainu%40gmail.com/messages/send',{method:'POST',redirect:'error',signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+access,'Content-Type':'application/json'},body:JSON.stringify({raw:Buffer.from(mime,'utf8').toString('base64url')})});
    }catch{throw new BillingContactError('contact_delivery_uncertain');}
    if(!response.ok){if([400,401,403,404].includes(response.status))throw Object.assign(new BillingContactError('contact_delivery_failed'),{delivery:'not_sent'});throw new BillingContactError('contact_delivery_uncertain');}
    try{const value:any=await response.json();if(typeof value.id!=='string'||!value.id)throw denied();}catch{throw new BillingContactError('contact_delivery_uncertain');}
    // Do not return/store Gmail message IDs, access tokens, MIME, addresses or links.
  };
}
