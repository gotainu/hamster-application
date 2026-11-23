import type Stripe from 'stripe';
import {accountDeletionRef} from './accountDeletion';
import {syncStripeSubscription} from './stripeSubscriptionSync';
import {validWebBillingUid} from './webBillingShared';
import {WebBillingWebhookError} from './webBillingWebhook';

type Data = Record<string, any>;
const object=(v:unknown):v is Data=>!!v&&typeof v==='object'&&!Array.isArray(v);
const id=(v:unknown,prefix:string):string=>{
  const value=typeof v==='string'?v:object(v)?v.id:null;
  if(typeof value!=='string'||!new RegExp('^'+prefix+'_[A-Za-z0-9_]{1,240}$').test(value)) throw new WebBillingWebhookError('reference_invalid');
  return value;
};
const blocked=(s:FirebaseFirestore.DocumentSnapshot)=>s.exists&&(s.get('billingStopped')===true||s.get('status')==='completed');
const version=(s:FirebaseFirestore.DocumentSnapshot)=>s.exists&&s.updateTime?`${s.updateTime.seconds}:${s.updateTime.nanoseconds}`:null;
const conflict=():never=>{throw Object.assign(new Error('Billing synchronization unavailable.'),{code:9});};

/** Temporary old-signature continuity. Reuses the actually deployed
 * syncStripeSubscription selection/CAS implementation, including 0 JPY legacy
 * invoices. No new receipt/outbox, Customer, Subscription or email is created.
 * The added transaction fence prevents a delayed old event restoring a deleted
 * account. Remove this route only after the new engine owns normal delivery. */
export function createLegacyWebBillingWebhook(d:{db:FirebaseFirestore.Firestore;stripe:Stripe}) {
  async function findUid(subscription:Stripe.Subscription):Promise<string|null> {
    const metadataUid=subscription.metadata?.firebaseUid;
    if(metadataUid!==undefined) {
      if(!validWebBillingUid(metadataUid)) throw new WebBillingWebhookError('uid_binding_invalid');
      return metadataUid;
    }
    // Preserve the deployed metadata-first lookup for older records. A query
    // failure remains retryable; never guess an owner or fall back to email.
    for(const [field,value] of [['stripeSubscriptionId',subscription.id],['stripeCustomerId',id(subscription.customer,'cus')]]) {
      const found=await d.db.collectionGroup('billing').where(field,'==',value).limit(2).get();
      if(found.empty)continue;
      if(found.docs.length!==1) throw new WebBillingWebhookError('uid_binding_invalid');
      const uid=found.docs[0].ref.parent.parent?.id;
      if(!validWebBillingUid(uid)) throw new WebBillingWebhookError('uid_binding_invalid');
      return uid;
    }
    return null;
  }
  return {
    async process(event:Stripe.Event):Promise<{result:'synced'|'ignored'}> {
      if(event.livemode!==true) throw new WebBillingWebhookError('live_mode_required');
      if(!['checkout.session.completed','customer.subscription.created','customer.subscription.updated',
        'customer.subscription.deleted','invoice.payment_failed','invoice.payment_succeeded'].includes(event.type)) return {result:'ignored'};
      const payload=event.data?.object as unknown;
      if(!object(payload)) throw new WebBillingWebhookError('event_invalid');
      let subscriptionId:string,checkoutSessionId:string|undefined;
      if(event.type==='checkout.session.completed') {
        const session=await d.stripe.checkout.sessions.retrieve(id(payload.id,'cs'));
        if(session.livemode!==true||session.mode!=='subscription') throw new WebBillingWebhookError('live_mode_required');
        subscriptionId=id(session.subscription,'sub');checkoutSessionId=session.id;
      } else if(event.type.startsWith('invoice.')) {
        const invoice=await d.stripe.invoices.retrieve(id(payload.id,'in'));
        if(invoice.livemode!==true) throw new WebBillingWebhookError('live_mode_required');
        const v=invoice as unknown as Data;
        subscriptionId=id(v.subscription??v.parent?.subscription_details?.subscription,'sub');
      } else subscriptionId=id(payload.id,'sub');
      const source=await d.stripe.subscriptions.retrieve(subscriptionId);
      if(source.livemode!==true) throw new WebBillingWebhookError('live_mode_required');
      const uid=await findUid(source);
      if(!uid) throw new WebBillingWebhookError('uid_binding_invalid');
      const customerId=id(source.customer,'cus');
      let deleted=false;
      await syncStripeSubscription({db:d.db,stripe:d.stripe,uid,subscriptionId,
        ...(checkoutSessionId?{checkoutSessionId}:{}),
        persist:async({ref,before,data,subscription})=>{
          if(subscription.livemode!==true||id(subscription.customer,'cus')!==customerId||
            (subscription.metadata?.firebaseUid!==undefined&&subscription.metadata.firebaseUid!==uid)) {
            throw new WebBillingWebhookError('uid_binding_mismatch');
          }
          await d.db.runTransaction(async tx=>{
            const [deletion,current]=await Promise.all([tx.get(accountDeletionRef(d.db,uid)),tx.get(ref)]);
            if(blocked(deletion)){deleted=true;return;}
            if(version(current)!==version(before))conflict();
            const saved=current.data();
            if(saved?.stripeCustomerId&&saved.stripeCustomerId!==customerId) throw new WebBillingWebhookError('uid_binding_mismatch');
            if(current.exists)tx.update(ref,data);else tx.create(ref,data as FirebaseFirestore.DocumentData);
          });
        }});
      return {result:deleted?'ignored':'synced'};
    },
  };
}
