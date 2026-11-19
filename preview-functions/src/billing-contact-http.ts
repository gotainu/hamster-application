import {onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {PREVIEW_ORIGIN,Identity} from './engine';
import {authorizePreviewIdentity,validPreviewUid} from './auth-policy';
import {readPreviewFacts} from './preview-runtime';
import {BillingContactError,BillingContactContext,BillingContactView,createBillingContactEngine} from './billing-contact';
import {createFirestoreBillingContactStore} from './billing-contact-store';
import {CONTACT_MAIL_SECRET,parseContactMailConfig,assertContactTestSubject,createPreviewGmailSender} from './billing-contact-mail';

const mailConfig=defineSecret(CONTACT_MAIL_SECRET);
export function publicBillingContact(view:BillingContactView) {
  const states:Record<string,string>={verified:'verified',missing:'missing',pending:'pending',expired:'missing',delivery_failed:'missing',delivery_uncertain:'pending',unverified:'unverified',invalid:'invalid'};
  const categories:Record<string,string>={A:'normal',B:'apple_relay',C:'missing',unverified:'unverified',invalid:'invalid'};
  return {testMode:true,state:states[view.verificationStatus],category:categories[view.emailClass],maskedEmail:view.maskedEmail,
    pendingMaskedEmail:view.pendingMaskedEmail,canCheckout:view.canCheckout,source:view.source,resendAfter:view.resendAfter,expiresAt:view.expiresAt,
    deliveryState:view.pendingDeliveryState==='dispatching'?'uncertain':view.pendingDeliveryState};
}
export async function previewBillingContactContext(identity:Identity,adminUser:unknown):Promise<BillingContactContext> {
  const facts=await readPreviewFacts(identity.uid);
  return {identity,adminUser,appAccountExists:facts.appAccountExists};
}
/** Fresh server contact proof on every new review and Session. No Auth mutation. */
export async function requirePreviewBillingContact(identity:Identity,adminUser:unknown) {
  const engine=createBillingContactEngine({store:createFirestoreBillingContactStore(getFirestore()),now:()=>new Date()});
  return engine.requireVerified(await previewBillingContactContext(identity,adminUser));
}
export async function reserveContactMailBudget(now=Date.now()) {
  const db=getFirestore();const day=new Date(now).toISOString().slice(0,10);
  const ref=db.collection('preview_billing_contact_delivery_limits').doc(day);
  await db.runTransaction(async tx=>{const doc=await tx.get(ref);const count=doc.get('count')||0;
    if(!Number.isSafeInteger(count)||count<0||count>=10)throw Object.assign(new BillingContactError('contact_rate_limited'),{delivery:'not_sent'});
    tx.set(ref,{purpose:'billing_contact_preview',count:count+1,updatedAt:now});
  });
}
const ERRORS=new Set(['unauthenticated','app_account_required','contact_identity_invalid','contact_state_invalid','contact_not_required','contact_auth_email_unverified','contact_email_invalid','mail_unavailable','contact_mail_unavailable','contact_rate_limited','contact_delivery_pending','contact_delivery_failed','contact_delivery_uncertain','contact_token_invalid','contact_token_expired','contact_token_used','contact_verification_required','server_clock_invalid','test_configuration_invalid']);
export function contactHttpError(error:unknown) {
  const raw=(error as any)?.code;
  if(typeof raw==='string'&&raw.startsWith('auth/'))return {status:401,code:'unauthenticated'};
  const aliases:Record<string,string>={contact_email_invalid:'contact_invalid_email',mail_unavailable:'contact_mail_unavailable',contact_auth_email_unverified:'contact_unverified',contact_verification_required:'contact_required',contact_token_invalid:'contact_invalid_token',contact_token_expired:'contact_expired',contact_token_used:'contact_used',contact_delivery_pending:'contact_sending',contact_delivery_uncertain:'contact_delivery_unknown'};
  const known=typeof raw==='string'&&ERRORS.has(raw)?raw:'contact_service_unavailable';
  return {status:known==='unauthenticated'?401:known==='contact_rate_limited'?429:known==='contact_delivery_pending'?409:400,code:aliases[known]||known};
}
export function validContactRequest(req:{method:string;path:string;query:unknown;rawBody:unknown;body:unknown;is:(s:string)=>unknown}) {
  const op=req.path.replace(/^\//,'');const keys=op==='request'?['email']:op==='confirm'?['token']:[];
  if(req.method!=='POST'||!req.is('application/json')||!['status','request','confirm'].includes(op)||
     !req.query||Object.keys(req.query).length||!Buffer.isBuffer(req.rawBody)||req.rawBody.length>2048||
     !req.body||Array.isArray(req.body)||typeof req.body!=='object'||Object.keys(req.body).length!==keys.length||Object.keys(req.body).some(k=>!keys.includes(k)))return null;
  return op;
}
export const previewBillingContactEmail=onRequest({region:'us-central1',secrets:[mailConfig],maxInstances:1,concurrency:5,timeoutSeconds:60,memory:'256MiB',invoker:'public',cors:false},async(req,res)=>{
  res.set('Cache-Control','no-store, max-age=0');res.set('Pragma','no-cache');res.set('Referrer-Policy','no-referrer');res.set('X-Content-Type-Options','nosniff');
  // No cookies/ambient auth: strict Origin + Bearer + JSON/preflight prevents CSRF.
  if(req.get('Origin')!==PREVIEW_ORIGIN){res.status(403).json({code:'origin_not_allowed'});return;}
  res.set('Access-Control-Allow-Origin',PREVIEW_ORIGIN);res.set('Vary','Origin');
  if(req.method==='OPTIONS'){res.set('Access-Control-Allow-Methods','POST');res.set('Access-Control-Allow-Headers','Authorization, Content-Type');res.set('Access-Control-Max-Age','600');res.status(204).send('');return;}
  const operation=validContactRequest(req);if(!operation){res.status(400).json({code:'request_invalid'});return;}
  try {
    const bearer=req.get('Authorization');if(!bearer?.startsWith('Bearer ')||bearer.length>8192)throw new BillingContactError('unauthenticated');
    const token=await getAuth().verifyIdToken(bearer.slice(7),true);if(!validPreviewUid(token.uid))throw new BillingContactError('unauthenticated');
    const user=await getAuth().getUser(token.uid);const identity=authorizePreviewIdentity(token,user);
    const context=await previewBillingContactContext(identity,user);
    let sendMail;
    if(operation!=='status'){
      const config=parseContactMailConfig(mailConfig.value());assertContactTestSubject(config,identity.uid);
      if(operation==='request')sendMail=createPreviewGmailSender(config,identity.uid,{reserve:()=>reserveContactMailBudget()});
    }
    const engine=createBillingContactEngine({store:createFirestoreBillingContactStore(getFirestore()),now:()=>new Date(),sendMail});
    const result=operation==='status'?await engine.status(context):operation==='request'?await engine.request(context,req.body.email):await engine.confirm(context,req.body.token);
    res.json(publicBillingContact(result));
  }catch(error){const safe=contactHttpError(error);res.status(safe.status).json({code:safe.code});}
});
