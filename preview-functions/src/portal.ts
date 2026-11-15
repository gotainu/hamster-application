import {onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import Stripe from 'stripe';
import {CheckoutError,hash,PREVIEW_ORIGIN} from './engine';
import {readPreviewFacts,subjectRef,parseWebhookConfig} from './preview-runtime';
import {PREVIEW_SYNC_EVENT_TYPES} from './subscription-sync';
import {authorizePreviewIdentity} from './auth-policy';
import {createPreviewPortalEngine} from './portal-engine';

const credentials=defineSecret('HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS');
const price=defineSecret('HAMCARE_PREVIEW_STRIPE_TEST_PRICE');
const webhook=defineSecret('HAMCARE_PREVIEW_STRIPE_WEBHOOK_CONFIG');
const portalConfig=defineSecret('HAMCARE_PREVIEW_STRIPE_PORTAL_CONFIG');
const validUid=(uid:unknown):uid is string=>typeof uid==='string' && uid.length>0 && uid.length<=128 && /^[^/\s\u0000-\u001f\u007f]+$/u.test(uid);

/** Session URLs are never written. Only issuance counts for an already bound
 * Preview subject are stored, separate from Checkout and application quotas. */
export async function reservePreviewPortalRequest(uid:string,nowMs=Date.now()) {
  if(!validUid(uid) || !Number.isSafeInteger(nowMs))throw new CheckoutError('unauthenticated');
  const root=subjectRef(hash(uid));const rate=root.collection('portal').doc('rate');
  await getFirestore().runTransaction(async tx=>{
    const [a,b]=await Promise.all([tx.get(root),tx.get(rate)]);const s=a.data()||{};const r=b.data()||{};
    if(s.previewFirebaseUid!==uid || typeof s.customerId!=='string' || !/^cus_[A-Za-z0-9_]+$/.test(s.customerId))throw new CheckoutError('customer_unresolved');
    const day=new Date(nowMs).toISOString().slice(0,10);
    const start=typeof r.windowStart==='number' && nowMs-r.windowStart<600000?r.windowStart:nowMs;
    const count=start===r.windowStart?(r.count||0):0;const daily=r.day===day?(r.daily||0):0;
    if(typeof r.lastRequestAt==='number' && nowMs-r.lastRequestAt<3000)throw new CheckoutError('processing');
    if(count>=20 || daily>=80)throw new CheckoutError('portal_limit');
    tx.set(rate,{windowStart:start,count:count+1,day,daily:daily+1,lastRequestAt:nowMs});
  });
}

export const createPreviewStripeCustomerPortalSession=onRequest({region:'us-central1',secrets:[credentials,price,webhook,portalConfig],maxInstances:2,concurrency:10,timeoutSeconds:60,memory:'256MiB',invoker:'public',cors:false},async(req,res)=>{
  res.set('Cache-Control','no-store, max-age=0');res.set('Pragma','no-cache');res.set('X-Content-Type-Options','nosniff');res.set('Referrer-Policy','no-referrer');
  if(req.get('Origin')!==PREVIEW_ORIGIN){res.status(403).json({code:'origin_not_allowed'});return;}
  res.set('Access-Control-Allow-Origin',PREVIEW_ORIGIN);res.set('Vary','Origin');
  if(req.method==='OPTIONS'){res.set('Access-Control-Allow-Methods','POST');res.set('Access-Control-Allow-Headers','Authorization, Content-Type');res.set('Access-Control-Max-Age','600');res.status(204).send('');return;}
  if(req.method!=='POST' || !req.is('application/json') || !['','/'].includes(req.path) || Object.keys(req.query).length || !Buffer.isBuffer(req.rawBody) || req.rawBody.length>512 || !req.body || Array.isArray(req.body) || typeof req.body!=='object' || Object.keys(req.body).length){res.status(400).json({code:'request_invalid'});return;}
  try {
    const bearer=req.get('Authorization');if(!bearer?.startsWith('Bearer ') || bearer.length>8192)throw new CheckoutError('unauthenticated');
    const token=await getAuth().verifyIdToken(bearer.slice(7),true);
    if(!validUid(token.uid))throw new CheckoutError('unauthenticated');
    const user=await getAuth().getUser(token.uid);
    const identity=authorizePreviewIdentity(token,user);
    const facts=await readPreviewFacts(user.uid);if(!facts.appAccountExists)throw new CheckoutError('app_account_required');
    const keys=JSON.parse(credentials.value());const config=JSON.parse(portalConfig.value());
    if(typeof keys.secretKey!=='string' || !keys.secretKey.startsWith('sk_test_') || !/^bpc_[A-Za-z0-9]+$/.test(config.configurationId))throw new CheckoutError('portal_configuration_invalid');
    const wh=parseWebhookConfig(webhook.value());
    const stripe=new Stripe(keys.secretKey,{apiVersion:'2025-02-24.acacia',maxNetworkRetries:1,timeout:15000,telemetry:false});
    const engine=createPreviewPortalEngine({stripe,store:{read:async subject=>(await subjectRef(subject).get()).data()||{}},readFacts:readPreviewFacts,now:()=>new Date(),priceId:price.value().trim(),configurationId:config.configurationId,allowedWebhook:{id:wh.endpointId,url:wh.endpointUrl,events:PREVIEW_SYNC_EVENT_TYPES}});
    await reservePreviewPortalRequest(user.uid);
    res.json(await engine.create(identity));
  }catch(error){
    // Never serialize SDK errors, bearer tokens, Portal URLs or billing identifiers.
    const raw=(error as any)?.code;
    const authErrors=new Set(['auth/argument-error','auth/id-token-expired','auth/id-token-revoked','auth/invalid-id-token','auth/user-disabled','auth/user-not-found']);
    const allowed=new Set(['unauthenticated','email_unverified','app_account_required','customer_unresolved','portal_configuration_invalid','portal_unavailable','portal_not_available','portal_limit','processing','test_mode_required','price_mismatch','test_webhook_unresolved']);
    const code=authErrors.has(raw)?'unauthenticated':typeof raw==='string' && allowed.has(raw)?raw:'portal_unavailable';
    res.status(code==='unauthenticated'?401:code==='portal_limit'?429:code==='processing'?409:400).json({code});
  }
});
