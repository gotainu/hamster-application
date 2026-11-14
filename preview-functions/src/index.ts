import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import Stripe from 'stripe';
import {CheckoutError,createPreviewEngine,hash,PREVIEW_ORIGIN,PreviewStore,RecordData} from './engine';

initializeApp();
const credentials=defineSecret('HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS');
const price=defineSecret('HAMCARE_PREVIEW_STRIPE_TEST_PRICE');
const NAMESPACE='preview_checkout_task4';
const db=getFirestore();
const subjectRef=(subject:string)=>{if(!/^[a-f0-9]{64}$/.test(subject))throw new CheckoutError('unauthenticated');return db.collection(NAMESPACE).doc(subject);};
const store: PreviewStore={
  async read(subject){return (await subjectRef(subject).get()).data() || {};},
  async mutate(subject,update){return db.runTransaction(async tx=>{const ref=subjectRef(subject);const snap=await tx.get(ref);const next=update(snap.data() || {});tx.set(ref,next.state);return next.result;});},
  async reserveBudget(subject,day,attempt){
    if(!/^\d{4}-\d{2}-\d{2}$/.test(day))throw new CheckoutError('processing');
    await db.runTransaction(async tx=>{
      const owner=subjectRef(subject);const global=db.collection(NAMESPACE).doc('_limits_'+day);
      const [a,b]=await Promise.all([tx.get(owner),tx.get(global)]);const s=a.data()||{};const g=b.data()||{};
      if(s.budgetAttempts?.includes(attempt))return;
      const count=s.budgetDay===day?(s.budgetCount||0):0;
      if(count>=10 || (g.count||0)>=100)throw new CheckoutError('preview_limit');
      tx.set(owner,{...s,budgetDay:day,budgetCount:count+1,budgetAttempts:[...(s.budgetAttempts||[]).slice(-99),attempt]});tx.set(global,{count:(g.count||0)+1});
    });
  },
};
function maskEmail(value:string):string {const [name,domain]=value.split('@');return domain?name.slice(0,2)+'***@'+domain:'未設定';}
const allowedErrors=new Set(['unauthenticated','email_unverified','app_account_required','plan_not_allowed','billing_unresolved','existing_subscription','already_subscribed','subscription_unresolved','trial_unresolved','trial_invalid','trial_too_short','server_clock_invalid','test_mode_required','test_configuration_invalid','price_mismatch','customer_unresolved','confirmation_required','review_expired','processing','preview_limit','checkout_unresolved','session_expired','test_webhook_unresolved']);

export const createPreviewStripeCheckoutSession=onRequest({region:'us-central1',secrets:[credentials,price],maxInstances:2,concurrency:10,timeoutSeconds:60,memory:'256MiB',invoker:'public',cors:false},async(req,res)=>{
  res.set('Cache-Control','no-store, max-age=0');res.set('Pragma','no-cache');res.set('X-Content-Type-Options','nosniff');res.set('Referrer-Policy','no-referrer');
  const origin=req.get('Origin');
  if(origin!==PREVIEW_ORIGIN){res.status(403).json({code:'origin_not_allowed'});return;}
  res.set('Access-Control-Allow-Origin',PREVIEW_ORIGIN);res.set('Vary','Origin');
  if(req.method==='OPTIONS'){res.set('Access-Control-Allow-Methods','POST');res.set('Access-Control-Allow-Headers','Authorization, Content-Type');res.set('Access-Control-Max-Age','600');res.status(204).send('');return;}
  if(req.method!=='POST'||!req.is('application/json')||Object.keys(req.query).length||req.rawBody.length>2048){res.status(400).json({code:'request_invalid'});return;}
  const operation=req.path.replace(/^\//,'');
  const body=req.body;
  const keys=operation==='session'?['planKey','reviewToken','termsAccepted']:['planKey'];
  if(!['review','session','status','cancel'].includes(operation)||!body||Array.isArray(body)||typeof body!=='object'||Object.keys(body).some(k=>!keys.includes(k))||body.planKey!=='premium_monthly') {res.status(400).json({code:'plan_not_allowed'});return;}
  try {
    const bearer=req.get('Authorization');if(!bearer?.startsWith('Bearer ')||bearer.length>8192)throw new CheckoutError('unauthenticated');
    const token=await getAuth().verifyIdToken(bearer.slice(7),true);
    const user=await getAuth().getUser(token.uid);
    if(user.disabled||!user.email)throw new CheckoutError('unauthenticated');
    if(token.email_verified!==true||!user.emailVerified)throw new CheckoutError('email_unverified');
    const config=JSON.parse(credentials.value());
    if(typeof config.secretKey!=='string'||!config.secretKey.startsWith('sk_test_')||typeof config.publishableKey!=='string'||!config.publishableKey.startsWith('pk_test_'))throw new CheckoutError('test_configuration_invalid');
    const stripe=new Stripe(config.secretKey,{apiVersion:'2025-02-24.acacia',maxNetworkRetries:1,timeout:20000,telemetry:false});
    const engine=createPreviewEngine({stripe,store,priceId:price.value().trim(),publishableKey:config.publishableKey,now:()=>new Date(),readFacts:async uid=>{
      const root=db.collection('users').doc(uid);
      const [pet,billing,trial,owner]=await db.getAll(root.collection('pet_profiles').doc('main_pet'),root.collection('billing').doc('subscription'),root.collection('feature_access').doc('initial_trial_v2'),root.collection('owner_profiles').doc('main'));
      const item=(snap:typeof billing)=>snap.exists?{kind:'found',data:snap.data()}:{kind:'missing'};
      const name=owner.data()?.displayName;
      return {appAccountExists:pet.exists,billing:item(billing),trial:item(trial),nickname:typeof name==='string'&&name.trim()?name.trim().slice(0,80):'未設定',maskedEmail:maskEmail(user.email!)};
    }});
    const identity={uid:user.uid,emailVerified:user.emailVerified,email:user.email};
    // Read-only auth/account verification applies to every operation, including status/cancel.
    if(operation==='review')res.json(await engine.review(identity,body.planKey));
    else if(operation==='session')res.json(await engine.create(identity,body));
    else {const pet=await db.doc(`users/${user.uid}/pet_profiles/main_pet`).get();if(!pet.exists)throw new CheckoutError('app_account_required');res.json(operation==='status'?await engine.status(identity):await engine.cancel(identity));}
  }catch(error){
    // Do not log SDK errors, request headers, tokens, identifiers or user data.
    const rawCode=(error as any)?.code;
    const rejectedAuth=new Set(['auth/argument-error','auth/id-token-expired','auth/id-token-revoked','auth/invalid-id-token','auth/user-disabled','auth/user-not-found']);
    const code=rejectedAuth.has(rawCode)?'unauthenticated':typeof rawCode==='string'&&allowedErrors.has(rawCode)?rawCode:'service_unavailable';
    res.status(code==='unauthenticated'?401:code==='processing'?409:code==='preview_limit'?429:400).json({code});
  }
});
