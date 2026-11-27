import {createHash} from 'node:crypto';
import type {WebBillingHook, WebBillingSubscription} from './webBillingWebhook';
import type {BillingNotificationRecord, BillingNotificationType} from './billingNotificationWorker';
import {BILLING_NOTIFICATION_TEMPLATE_VERSION} from './billingNotificationTemplates';

const hash=(value:string)=>createHash('sha256').update(value).digest('hex');
/** Convert trusted canonical billing transitions into semantic notifications.
 * No recipient, message body, mail credentials or mail delivery is involved.
 * Registration + trial hooks and alternate payment-success event names collapse
 * to the same stable meaning, independently of Stripe event receipt IDs. */
export function billingNotificationsFromHooks(input:{billing:WebBillingSubscription;hooks:WebBillingHook[];
  environment:'live'|'preview';trustedSource?:'stripe_webhook'|'preview_fixture'}):BillingNotificationRecord[] {
  const {billing:b,hooks,environment}=input;
  const snapshot={amount:b.amount,legacyPrice:b.legacyPrice,currency:b.currency,interval:b.interval,status:b.status,
    trialEndSeconds:b.trialEndSeconds,currentPeriodStartSeconds:b.currentPeriodStartSeconds,currentPeriodEndSeconds:b.currentPeriodEndSeconds,
    nextChargeAtSeconds:b.nextChargeAtSeconds,latestInvoicePaymentStatus:b.latestInvoicePaymentStatus,
    latestInvoiceAmountPaid:b.latestInvoiceAmountPaid,latestInvoiceTotal:b.latestInvoiceTotal,
    canceledAtSeconds:b.canceledAtSeconds,cancelAtPeriodEnd:b.cancelAtPeriodEnd};
  const records=new Map<string,BillingNotificationRecord>();
  for (const hook of hooks) {
    let type:BillingNotificationType,meaning:string;
    switch(hook.type) {
      case 'contract_started':case 'trial_started':type='contract_registered';meaning='registered:'+hook.subscriptionId;break;
      case 'first_charge':case 'renewal':type='payment_success';meaning='paid:'+hook.subscriptionId+':'+hook.invoiceId;break;
      case 'payment_failed':type='payment_failed';meaning='unpaid:'+hook.subscriptionId+':'+hook.invoiceId;break;
      case 'cancel_reserved':case 'resumed':type=hook.type;meaning=hook.transitionKey;break;
      case 'canceled':type='canceled';meaning='ended:'+hook.subscriptionId+':'+String(b.canceledAtSeconds ?? b.currentPeriodEndSeconds);break;
      default:continue;
    }
    const transitionKey=[environment,type,meaning,BILLING_NOTIFICATION_TEMPLATE_VERSION].join(':');
    const id=hash(transitionKey),uidHash=hash(hook.firebaseUid);
    records.set(id,{id,schemaVersion:1,environment,trustedSource:input.trustedSource??'stripe_webhook',
      templateVersion:BILLING_NOTIFICATION_TEMPLATE_VERSION,type,firebaseUid:hook.firebaseUid,uidHash,
      transitionKey,billingEventKey:hook.transitionKey,eventHash:hook.eventHash,
      subscriptionId:hook.subscriptionId,invoiceId:hook.invoiceId,subscriptionStatus:b.status,
      recipientReference:uidHash,status:'pending',attempts:0,createdAtMillis:hook.createdAtMillis,
      ...(Number.isSafeInteger(b.sourceEventCreatedSeconds) && b.sourceEventCreatedSeconds>0 && Number.isSafeInteger(b.sourceEventCreatedSeconds*1000)
        ? {eventCreatedAtMillis:b.sourceEventCreatedSeconds*1000} : {}),
      nextAttemptAtMillis:hook.createdAtMillis,dispatchAtMillis:hook.createdAtMillis,idempotencyKey:id,snapshot});
  }
  return [...records.values()];
}
