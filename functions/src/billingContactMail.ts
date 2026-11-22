import {BillingContactError,BillingContactMail,BILLING_CONTACT_LIVE_ORIGIN} from './billingContact';
import {createBillingNotificationGmailSender,BillingNotificationMailConfig,BillingNotificationMailError} from './billingNotificationGmail';
import {createLimitedLiveBillingContactReservation} from './billingContactStore';
import {createBillingNotificationBudget,deferBillingNotificationSender} from './billingNotificationBudget';

export interface LiveBillingContactMailDependencies {
  db:FirebaseFirestore.Firestore;
  config:BillingNotificationMailConfig;
  dailyLimit:number;
  now?:()=>number;
  fetchRequest?:typeof fetch;
  sleep?:(millis:number)=>Promise<void>;
}
/** Reuse the notification sender, OAuth config, account-wide reservations and
 * sender pause. A verification recipient is pending, so this sender deliberately
 * does not use the already-verified notification recipient resolver. */
export function createLiveBillingContactSender(d:LiveBillingContactMailDependencies,uid:string) {
  const now=d.now??Date.now;
  const reserve=createBillingNotificationBudget(d.db,'live',d.dailyLimit);
  const sender=createBillingNotificationGmailSender(d.config,{fetchRequest:d.fetchRequest,now:()=>new Date(now()),
    ...(d.config.limitedContactTest ? {reserveLimitedContactTest:createLimitedLiveBillingContactReservation(d.db,uid,d.config.limitedContactTest.maxTotalSends)} : {})});
  const sleep=d.sleep??(ms=>new Promise(resolve=>setTimeout(resolve,ms)));
  return async(message:BillingContactMail):Promise<void>=>{
    if (d.config.environment!=='live' || (d.config.limitedContactTest && d.dailyLimit>d.config.limitedContactTest.maxTotalSends) || !/^[a-f0-9]{64}$/.test(message.idempotencyKey) ||
      !new RegExp('^'+BILLING_CONTACT_LIVE_ORIGIN.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'/account/contact/#token=[A-Za-z0-9_-]{43}$').test(message.verificationUrl)) {
      throw Object.assign(new BillingContactError('contact_configuration_invalid'),{delivery:'not_sent'});
    }
    let allowed:Awaited<ReturnType<typeof reserve>>;
    try {allowed=await reserve({uid,notificationId:message.idempotencyKey,attemptId:'contact-verification',nowMillis:now()});}
    catch {throw Object.assign(new BillingContactError('contact_delivery_failed'),{delivery:'not_sent'});}
    if (!allowed.allowed) throw Object.assign(new BillingContactError('contact_rate_limited'),{delivery:'not_sent'});
    const escape=(s:string)=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
    for(let attempt=0;attempt<2;attempt++) {
      try {
        await sender.send({notificationId:message.idempotencyKey,uid,to:message.to,subject:message.subject,text:message.text,
          html:'<!doctype html><html lang="ja"><body><p>'+escape(message.text).replace(/\n/g,'<br>')+'</p></body></html>'});
        return;
      } catch(error) {
        if (error instanceof BillingNotificationMailError) {
          if (error.delivery==='not_sent' && ['quota_exceeded','sending_limit','rate_limited'].includes(error.category)) {
            const category=error.category as 'quota_exceeded'|'sending_limit'|'rate_limited';
            const delayMillis=Math.max(category==='rate_limited'?60000:86400000,error.retryAfterMillis??0);
            try {await deferBillingNotificationSender(d.db,'live',{nowMillis:now(),category,delayMillis});} catch { /* Preserve the provider outcome. */ }
            throw Object.assign(new BillingContactError('contact_rate_limited'),{delivery:'not_sent'});
          }
          // Exactly one bounded backoff for a known pre-send failure. A Gmail
          // send timeout/5xx may have been accepted and is never retried here.
          if (attempt===0 && error.delivery==='not_sent' && error.retryable && (error.retryAfterMillis??0)<=1000) {
            await sleep(1000); continue;
          }
          throw Object.assign(new BillingContactError(error.delivery==='uncertain'?'contact_delivery_uncertain':'contact_delivery_failed'),
            {delivery:error.delivery});
        }
        throw Object.assign(new BillingContactError('contact_delivery_uncertain'),{delivery:'uncertain'});
      }
    }
  };
}
