import type * as admin from 'firebase-admin';
import {createHash} from 'node:crypto';
import {parseBillingNotificationMailConfig,createBillingNotificationGmailSender,BillingNotificationMailError} from './billingNotificationGmail';
import {createBillingNotificationStore,matchesLimitedBillingNotification} from './billingNotificationStore';
import {LimitedBillingNotificationSelection,validLimitedBillingNotificationSelection,limitedBillingNotificationWindowOpen} from './billingNotificationDispatch';
import {normalizeBillingEmail} from './webBillingShared';
import {createBillingNotificationWorker} from './billingNotificationWorker';
import {createBillingNotificationBudget,deferBillingNotificationSender} from './billingNotificationBudget';
import {renderBillingNotification, BillingNotificationSnapshot} from './billingNotificationTemplates';
import {resolveBillingNotificationRecipient} from './billingNotificationRecipient';

export const BILLING_NOTIFICATION_RETRY_POLICY=Object.freeze({maxAttempts:5,baseDelayMillis:60000,
  maxDelayMillis:3600000,leaseMillis:120000,batchSize:5});
export interface BillingNotificationRuntimeDependencies {
  db:FirebaseFirestore.Firestore;
  auth:Pick<admin.auth.Auth,'getUser'>;
  environment:'live'|'preview';
  rawConfig():unknown;
  /** Required explicit operator budget for Live, not Gmail's published limit. */
  dailyLimit:number;
  /** Live-only, explicitly approved fixed dispatch start; never a rolling now. */
  liveDispatchNotBeforeMillis?:number;
  liveDispatchScope?:'general'|'limited';
  liveLimitedSelection?:LimitedBillingNotificationSelection;
  now?:()=>number;
  fetchRequest?:typeof fetch;
}
/** Neither constructor nor module import reads secrets or opens a connection.
 * The worker receives only mail OAuth configuration, never Stripe credentials. */
export function createBillingNotificationRuntime(d:BillingNotificationRuntimeDependencies) {
  return {
    async runOnce() {
      const now=d.now??Date.now;
      const limited=d.liveDispatchScope==='limited'?d.liveLimitedSelection:undefined;
      if ((d.environment==='live' && (!['general','limited'].includes(String(d.liveDispatchScope)) ||
          !Number.isSafeInteger(d.liveDispatchNotBeforeMillis) || Number(d.liveDispatchNotBeforeMillis)<=0 ||
          Number(d.liveDispatchNotBeforeMillis)%1000!==0 || Number(d.liveDispatchNotBeforeMillis)>now() ||
          (d.liveDispatchScope==='general' && d.liveLimitedSelection!==undefined) ||
          (d.liveDispatchScope==='limited' && (!validLimitedBillingNotificationSelection(limited) ||
            limited.notBeforeMillis!==d.liveDispatchNotBeforeMillis || !limitedBillingNotificationWindowOpen(limited,now()) || d.dailyLimit!==1)))) ||
          (d.environment==='preview' && (d.liveDispatchNotBeforeMillis!==undefined || d.liveDispatchScope!==undefined || d.liveLimitedSelection!==undefined))) {
        throw new BillingNotificationMailError('configuration_invalid','not_sent',false);
      }
      const config=parseBillingNotificationMailConfig(d.rawConfig(),d.environment);
      // The expired, one-person contact smoke configuration must never turn
      // into an operational notification worker merely by deploying a schedule.
      if (d.environment==='live' && config.limitedContactTest) throw new BillingNotificationMailError('configuration_invalid','not_sent',false);
      const reserveDelivery=createBillingNotificationBudget(d.db,d.environment,d.dailyLimit);
      const sender=createBillingNotificationGmailSender(config,{fetchRequest:d.fetchRequest,now:()=>new Date(now())});
      const digest=(v:string)=>createHash('sha256').update(v).digest('hex');
      const allowedRecipient=d.environment==='preview' ? (uid:string,email:string)=>
        config.allowedSubjectHashes!.includes(digest(uid)) && config.allowedRecipientHashes!.includes(digest(email)) : limited ?
        (uid:string,email:string)=>limitedBillingNotificationWindowOpen(limited,now()) &&
          digest(uid)===limited.subjectHash && digest(email)===limited.recipientHash : undefined;
      const resolveCurrentRecipient=async(uid:string)=>{
        // Always current Admin evidence; never email-based account lookup.
        let user:admin.auth.UserRecord;
        try {user=await d.auth.getUser(uid);} catch(error) {
          if ((error as {code?:string})?.code==='auth/user-not-found') return null;
          throw new Error('Recipient lookup unavailable.');
        }
        const direct=resolveBillingNotificationRecipient({uid,authUser:user,mode:d.environment,nowMillis:now()});
        if (direct.kind==='resolved') return {email:direct.email,source:direct.source};
        const collection=d.environment==='live'?'billing_contacts':'preview_billing_contacts';
        const snap=await d.db.doc(collection+'/'+uid).get();
        const result=resolveBillingNotificationRecipient({uid,authUser:user,mode:d.environment,nowMillis:now(),
          supplementalContact:{uid,state:snap.data()}});
        return result.kind==='resolved'?{email:result.email,source:result.source}:null;
      };
      const worker=createBillingNotificationWorker({config:{environment:d.environment,...BILLING_NOTIFICATION_RETRY_POLICY,
          ...(limited?{batchSize:1}:{})},
        store:createBillingNotificationStore(d.db,d.environment,d.liveDispatchNotBeforeMillis,limited,now),reserveDelivery,now,allowedRecipient,
        resolveRecipient:resolveCurrentRecipient,
        render:notification=>renderBillingNotification({type:notification.type,mode:d.environment,
          snapshot:notification.snapshot as unknown as BillingNotificationSnapshot,templateVersion:notification.templateVersion}),
        send:async message=>{
          let providerDenied=false;
          const verifyLimitedProviderCall=async()=>{
            if(!limited || !limitedBillingNotificationWindowOpen(limited,now()) || message.notificationId!==limited.notificationId ||
                digest(message.uid)!==limited.subjectHash || !normalizeBillingEmail(message.to) ||
                digest(normalizeBillingEmail(message.to)!)!==limited.recipientHash) throw new Error('Limited notification unavailable.');
            const snap=await d.db.doc('billing_notification_outbox/'+limited.notificationId).get(),value=snap.data();
            if(!matchesLimitedBillingNotification(value,limited.notificationId,limited) || value?.status!=='sending' ||
                value.firebaseUid!==message.uid || !Number.isSafeInteger(value.leaseUntilMillis) || value.leaseUntilMillis<=now()) throw new Error('Limited notification unavailable.');
            const current=await resolveCurrentRecipient(message.uid),email=normalizeBillingEmail(current?.email);
            if(!email || email!==normalizeBillingEmail(message.to) || digest(email)!==limited.recipientHash ||
                !limitedBillingNotificationWindowOpen(limited,now())) throw new Error('Limited notification unavailable.');
          };
          try {
            if(!limited)return await sender.send(message);
            try {await verifyLimitedProviderCall();}catch {throw new BillingNotificationMailError('recipient_not_allowed','not_sent',false);}
            const transport=d.fetchRequest??globalThis.fetch;
            const limitedSender=createBillingNotificationGmailSender(config,{now:()=>new Date(now()),fetchRequest:async(input,init)=>{
              // OAuth can take time. Recheck the same UID/current verified
              // address, exact send intent and finite window immediately before
              // the irreversible Gmail request, without changing sender schema.
              const target=String(input);
              if(target==='https://gmail.googleapis.com/gmail/v1/users/gotainu%40gmail.com/messages/send') {
                try {await verifyLimitedProviderCall();} catch {providerDenied=true;throw new Error('Limited notification unavailable.');}
              } else if(target!=='https://oauth2.googleapis.com/token') {
                providerDenied=true;throw new Error('Limited notification unavailable.');
              }
              return transport(input,init);
            }});
            return await limitedSender.send(message);
          } catch(error) {
            // Our pre-provider rejection is certainly unsent. A transport
            // failure after calling Gmail keeps the original uncertain result.
            if(providerDenied)throw new BillingNotificationMailError('recipient_not_allowed','not_sent',false);
            if (error instanceof BillingNotificationMailError && error.delivery==='not_sent' &&
              ['quota_exceeded','sending_limit','rate_limited'].includes(error.category)) {
              const category=error.category as 'quota_exceeded'|'sending_limit'|'rate_limited';
              const base=category==='rate_limited'?60000:86400000;
              const provider=Number.isSafeInteger(error.retryAfterMillis) && Number(error.retryAfterMillis)>0 ? Number(error.retryAfterMillis):0;
              // Honor a longer provider Retry-After; daily Gmail quota is a
              // rolling window shared by all notification jobs, not midnight.
              try {await deferBillingNotificationSender(d.db,d.environment,{nowMillis:now(),category,delayMillis:Math.max(base,provider)});} catch {
                // Preserve the original delivery outcome even if operational
                // cooldown storage is temporarily unavailable. Billing is not
                // a dependency of this worker and cannot be rolled back.
              }
            }
            throw error;
          }
        },
      });
      return worker.runOnce();
    },
  };
}
