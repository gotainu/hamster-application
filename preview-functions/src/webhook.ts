import {onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import Stripe from 'stripe';
import {parseWebhookConfig,readPreviewFacts} from './preview-runtime';
import {createPreviewSyncStore} from './subscription-store';
import {createPreviewSubscriptionSync,PreviewSyncError,PREVIEW_SYNC_EVENT_TYPES} from './subscription-sync';
import {verifyPreviewEvent} from './webhook-verification';
const credentials=defineSecret('HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS');
const price=defineSecret('HAMCARE_PREVIEW_STRIPE_TEST_PRICE');
const webhook=defineSecret('HAMCARE_PREVIEW_STRIPE_WEBHOOK_CONFIG');

export const stripePreviewWebhook=onRequest({region:'us-central1',secrets:[credentials,price,webhook],maxInstances:2,concurrency:10,timeoutSeconds:60,memory:'256MiB',invoker:'public',cors:false},async(req,res)=>{
  res.set('Cache-Control','no-store');res.set('X-Content-Type-Options','nosniff');
  if(req.method!=='POST' || !req.is('application/json') || Object.keys(req.query).length || !Buffer.isBuffer(req.rawBody) || req.rawBody.length>262144){res.status(400).json({code:'request_invalid'});return;}
  const signature=req.get('stripe-signature');
  if(typeof signature!=='string' || signature.length>4096){res.status(400).json({code:'signature_invalid'});return;}
  try {
    const cfg=parseWebhookConfig(webhook.value());const keys=JSON.parse(credentials.value());
    if(typeof keys.secretKey!=='string' || !keys.secretKey.startsWith('sk_test_'))throw new PreviewSyncError('test_configuration_invalid',false);
    const stripe=new Stripe(keys.secretKey,{apiVersion:'2025-02-24.acacia',maxNetworkRetries:1,timeout:15000,telemetry:false});
    let event:Stripe.Event;
    try{event=verifyPreviewEvent(stripe,req.rawBody,signature,cfg.signingSecret);}catch{res.status(400).json({code:'signature_or_event_invalid'});return;}
    const sync=createPreviewSubscriptionSync({stripe,priceId:price.value().trim(),store:createPreviewSyncStore(),readOriginalFacts:uid=>readPreviewFacts(uid,true),now:()=>new Date()});
    await sync.process(event);
    res.status(200).json({received:true});
  }catch(error){
    // Never serialize SDK errors, payloads, request headers, references, or secrets.
    const retryable=!(error instanceof PreviewSyncError) || error.retryable;
    res.status(retryable?503:400).json({code:retryable?'sync_retry_required':'sync_rejected'});
  }
});
