import Stripe from 'stripe';
import {PREVIEW_SYNC_EVENT_TYPES,PreviewSyncError} from './subscription-sync';
/** Raw bytes are mandatory. No parsed/re-serialized request body is accepted. */
export function verifyPreviewEvent(stripe:Stripe,raw:Buffer,signature:unknown,secret:string):Stripe.Event {
  if(!Buffer.isBuffer(raw) || raw.length>262144 || typeof signature!=='string' || signature.length>4096 || !secret.startsWith('whsec_'))throw new PreviewSyncError('signature_invalid',false);
  const time=signature.match(/(?:^|,)t=(\d+)(?:,|$)/);
  if(!time || Math.abs(Date.now()/1000-Number(time[1]))>300)throw new PreviewSyncError('signature_invalid',false);
  let event:Stripe.Event;
  try{event=stripe.webhooks.constructEvent(raw,signature,secret,300);}catch{throw new PreviewSyncError('signature_invalid',false);}
  if(event.livemode!==false || !(PREVIEW_SYNC_EVENT_TYPES as readonly string[]).includes(event.type))throw new PreviewSyncError('event_not_allowed',false);
  return event;
}
