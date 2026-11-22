import {createHash} from 'node:crypto';
import type * as admin from 'firebase-admin';
import {accountDeletionRef} from './accountDeletion';
import {authorizeWebBillingIdentity,BillingAuthenticationError,validWebBillingUid,normalizeBillingEmail} from './webBillingShared';
import {BillingContactError,createBillingContactEngine,BillingContactView,BILLING_CONTACT_LIVE_ORIGIN} from './billingContact';
import {createLiveBillingContactStore,canRequestLimitedLiveBillingContact} from './billingContactStore';
import {parseBillingNotificationMailConfig} from './billingNotificationGmail';
import {createLiveBillingContactSender} from './billingContactMail';

export const LIVE_BILLING_CONTACT_MAIL_SECRET='HAMCARE_LIVE_BILLING_MAIL_CONFIG';
export {BILLING_CONTACT_LIVE_ORIGIN};
export interface ProductionBillingContactDependencies {
  db:FirebaseFirestore.Firestore;
  auth:Pick<admin.auth.Auth,'verifyIdToken'|'getUser'>;
  enabled():boolean;
  rawConfig():unknown;
  dailyLimit():number;
  now?:()=>number;
  fetchRequest?:typeof fetch;
  sleep?:(millis:number)=>Promise<void>;
}
export type LiveBillingContactRequest={method:string;path:string;headers:Record<string,unknown>;
  query:unknown;rawBody:unknown;body:unknown};
const object=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==='object'&&!Array.isArray(v);
export function publicLiveBillingContact(view:BillingContactView) {
  const states:Record<string,string>={verified:'verified',missing:'missing',pending:'pending',expired:'missing',delivery_failed:'missing',delivery_uncertain:'pending',unverified:'unverified',invalid:'invalid'};
  const categories:Record<string,string>={A:'normal',B:'apple_relay',C:'missing',unverified:'unverified',invalid:'invalid'};
  return {testMode:false,state:states[view.verificationStatus],category:categories[view.emailClass],maskedEmail:view.maskedEmail,
    pendingMaskedEmail:view.pendingMaskedEmail,canCheckout:view.canCheckout,source:view.source,resendAfter:view.resendAfter,expiresAt:view.expiresAt,
    deliveryState:view.pendingDeliveryState==='dispatching'?'uncertain':view.pendingDeliveryState};
}
function safeError(error:unknown) {
  const code=error instanceof BillingContactError?error.code:error instanceof BillingAuthenticationError?error.code:null;
  const aliases:Record<string,string>={contact_email_invalid:'contact_invalid_email',contact_auth_email_unverified:'contact_unverified',
    email_unverified:'contact_unverified',contact_verification_required:'contact_required',contact_token_invalid:'contact_invalid_token',
    contact_token_expired:'contact_expired',contact_token_used:'contact_used',contact_delivery_pending:'contact_sending',
    contact_delivery_uncertain:'contact_delivery_unknown',mail_unavailable:'contact_mail_unavailable'};
  const known=new Set(['unauthenticated','email_unverified','app_account_required','contact_email_invalid','contact_not_required',
    'contact_auth_email_unverified','contact_verification_required','contact_token_invalid','contact_token_expired','contact_token_used',
    'contact_rate_limited','contact_test_not_allowed','contact_delivery_pending','contact_delivery_failed','contact_delivery_uncertain']);
  const publicCode=code&&known.has(code)?aliases[code]??code:'contact_service_unavailable';
  return {status:publicCode==='contact_test_not_allowed'?403:publicCode==='unauthenticated'?401:publicCode==='contact_rate_limited'?429:publicCode==='contact_sending'?409:
    publicCode==='contact_service_unavailable'?503:400,
    body:{code:publicCode,message:publicCode==='contact_service_unavailable'?'現在、連絡用メールの確認を利用できません。時間をおいてお試しください。':'連絡用メールの確認を完了できませんでした。画面の案内をご確認ください。'}};
}
/** Constructor/import is inert. An explicit enable switch, Live-only OAuth
 * config and finite shared mail budget are required before any Auth/DB access. */
export function createProductionBillingContactRuntime(d:ProductionBillingContactDependencies) {
  const now=d.now??Date.now;
  return {
    async handle(req:LiveBillingContactRequest) {
      const headers:Record<string,string>={'Cache-Control':'no-store, max-age=0',Pragma:'no-cache','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff'};
      if(req.headers.origin!==BILLING_CONTACT_LIVE_ORIGIN) return {status:403,headers,body:{code:'origin_not_allowed'}};
      headers['Access-Control-Allow-Origin']=BILLING_CONTACT_LIVE_ORIGIN;headers.Vary='Origin';
      if(req.method==='OPTIONS') return {status:204,headers:{...headers,'Access-Control-Allow-Methods':'POST',
        'Access-Control-Allow-Headers':'Authorization, Content-Type','Access-Control-Max-Age':'600'},body:{}};
      if(!d.enabled()) return {...safeError(new BillingContactError('contact_configuration_invalid')),headers};
      const op=req.path.replace(/^\//,'');
      const keys=op==='request'?['email']:op==='confirm'?['token']:[];
      if(req.method!=='POST' || !['status','request','confirm'].includes(op) ||
        typeof req.headers['content-type']!=='string' || !/^application\/json(?:\s*;.*)?$/i.test(req.headers['content-type']) ||
        !object(req.query) || Object.keys(req.query).length || !Buffer.isBuffer(req.rawBody) || req.rawBody.length>2048 ||
        !object(req.body) || Object.keys(req.body).sort().join(',')!==keys.sort().join(',')) return {status:400,headers,body:{code:'request_invalid'}};
      try {
        const config=parseBillingNotificationMailConfig(d.rawConfig(),'live'),dailyLimit=d.dailyLimit();
        if(!Number.isSafeInteger(dailyLimit)||dailyLimit<1||dailyLimit>100 ||
          (config.limitedContactTest && (dailyLimit>config.limitedContactTest.maxTotalSends || !Number.isSafeInteger(now()) || now()<=0 || now()>=config.limitedContactTest.expiresAtMillis))) throw new BillingContactError('contact_configuration_invalid');
        const bearer=req.headers.authorization;
        if(typeof bearer!=='string'||!/^Bearer [^\s]{1,8192}$/.test(bearer)) throw new BillingContactError('unauthenticated');
        let token:admin.auth.DecodedIdToken,user:admin.auth.UserRecord;
        try {token=await d.auth.verifyIdToken(bearer.slice(7),true);if(!validWebBillingUid(token.uid))throw Error();user=await d.auth.getUser(token.uid);}
        catch {throw new BillingContactError('unauthenticated');}
        const identity=authorizeWebBillingIdentity(token,user);
        if(config.limitedContactTest) {
          const hash=(v:string)=>createHash('sha256').update(v).digest('hex');
          if(!config.allowedSubjectHashes!.includes(hash(identity.uid))) throw new BillingContactError('contact_test_not_allowed');
          if(op==='request') {
            const recipient=normalizeBillingEmail(req.body.email);
            if(!recipient) throw new BillingContactError('contact_email_invalid');
            if(!config.allowedRecipientHashes!.includes(hash(recipient))) throw new BillingContactError('contact_test_not_allowed');
          }
        }
        if((await accountDeletionRef(d.db,identity.uid).get()).exists)throw new BillingContactError('contact_account_unavailable');
        const [owner,pet]=await Promise.all([d.db.doc('users/'+identity.uid+'/owner_profiles/main').get(),d.db.doc('users/'+identity.uid+'/pet_profiles/main_pet').get()]);
        const context={identity,adminUser:user,appAccountExists:owner.exists&&pet.exists};
        // Keep the first usable proof intact. A repeat request must not replace
        // its pending contact before the final irreversible-send guard rejects it.
        if(config.limitedContactTest && op==='request' &&
          !(await canRequestLimitedLiveBillingContact(d.db,identity.uid,config.limitedContactTest.maxTotalSends,now()))) throw new BillingContactError('contact_rate_limited');
        const sendMail=op==='request'?createLiveBillingContactSender({db:d.db,config,dailyLimit,now,fetchRequest:d.fetchRequest,sleep:d.sleep},identity.uid):undefined;
        const engine=createBillingContactEngine({environment:'live',store:createLiveBillingContactStore(d.db),now:()=>new Date(now()),sendMail});
        const view=op==='status'?await engine.status(context):op==='request'?await engine.request(context,req.body.email):await engine.confirm(context,req.body.token);
        return {status:200,headers,body:publicLiveBillingContact(view)};
      }catch(error) {return {...safeError(error),headers};}
    },
  };
}
