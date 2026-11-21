import type * as admin from 'firebase-admin';
import {createHash} from 'node:crypto';
import {parseBillingNotificationMailConfig,createBillingNotificationGmailSender,BillingNotificationMailError} from './billingNotificationGmail';
import {createBillingNotificationStore} from './billingNotificationStore';
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
  now?:()=>number;
  fetchRequest?:typeof fetch;
}
/** Neither constructor nor module import reads secrets or opens a connection.
 * The worker receives only mail OAuth configuration, never Stripe credentials. */
export function createBillingNotificationRuntime(d:BillingNotificationRuntimeDependencies) {
  return {
    async runOnce() {
      const config=parseBillingNotificationMailConfig(d.rawConfig(),d.environment);
      const now=d.now??Date.now;
      const reserveDelivery=createBillingNotificationBudget(d.db,d.environment,d.dailyLimit);
      const sender=createBillingNotificationGmailSender(config,{fetchRequest:d.fetchRequest,now:()=>new Date(now())});
      const digest=(v:string)=>createHash('sha256').update(v).digest('hex');
      const allowedRecipient=d.environment==='preview' ? (uid:string,email:string)=>
        config.allowedSubjectHashes!.includes(digest(uid)) && config.allowedRecipientHashes!.includes(digest(email)) : undefined;
      const worker=createBillingNotificationWorker({config:{environment:d.environment,...BILLING_NOTIFICATION_RETRY_POLICY},
        store:createBillingNotificationStore(d.db,d.environment),reserveDelivery,now,allowedRecipient,
        resolveRecipient:async uid=>{
          // Always current Admin evidence. Never search by email or use a
          // Stripe Customer's contact as Firebase account ownership proof.
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
        },
        render:notification=>renderBillingNotification({type:notification.type,mode:d.environment,
          snapshot:notification.snapshot as unknown as BillingNotificationSnapshot,templateVersion:notification.templateVersion}),
        send:async message=>{
          try {return await sender.send(message);} catch(error) {
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
