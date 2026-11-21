import {
  BillingNotificationClaimResult, BillingNotificationEnvironment, BillingNotificationOutcome,
  BillingNotificationStore, BillingNotificationWorkerError, isBillingNotificationHash,
  isBillingNotificationMillis, validBillingNotificationRecord,
} from './billingNotificationWorker';

export const BILLING_NOTIFICATION_OUTBOX = 'billing_notification_outbox';
export const PREVIEW_BILLING_NOTIFICATION_OUTBOX = 'preview_billing_notification_outbox';
const object=(v:unknown):v is Record<string,any>=>!!v && typeof v==='object' && !Array.isArray(v);
const token=(v:unknown):v is string=>typeof v==='string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const safeCategory=(v:unknown):v is string=>typeof v==='string' && /^[a-z_]{1,64}$/.test(v);
const fail=():never=>{throw new BillingNotificationWorkerError('state_invalid');};
function clearDispatch(value:Record<string,any>):Record<string,any> {
  const next={...value};delete next.dispatchAtMillis;delete next.nextAttemptAtMillis;return next;
}
function terminal(value:Record<string,any>,status:string,at:number,category:string):Record<string,any> {
  const next:Record<string,any>={...clearDispatch(value),status,updatedAtMillis:at,lastErrorCategory:category};
  delete next.leaseUntilMillis;
  return next;
}

/** Environment-specific outbox adapter only. It has no billing read/write or
 * Stripe capability. dispatchAtMillis exists only for work eligible for scans;
 * a single-field range index suffices (no broad scan or composite index needed).
 * The database and clock are injected; construction does not initialize Admin. */
export function createBillingNotificationStore(db:FirebaseFirestore.Firestore, environment:BillingNotificationEnvironment):BillingNotificationStore {
  if (!['live','preview'].includes(environment)) fail();
  const collection=environment==='live'?BILLING_NOTIFICATION_OUTBOX:PREVIEW_BILLING_NOTIFICATION_OUTBOX;
  const ref=(id:string)=>{if(!isBillingNotificationHash(id))fail();return db.doc(collection+'/'+id);};
  return {
    async listDue(nowMillis,limit) {
      if (!isBillingNotificationMillis(nowMillis) || !Number.isSafeInteger(limit) || limit<1 || limit>20) fail();
      const result=await db.collection(collection).where('dispatchAtMillis','<=',nowMillis).orderBy('dispatchAtMillis','asc').limit(limit).get();
      return result.docs.map(doc=>doc.id);
    },
    async claim(input) {
      const {id,environment:requested,leaseToken,attemptId,nowMillis,leaseUntilMillis,maxAttempts}=input;
      if (requested!==environment || !token(leaseToken) || !token(attemptId) || !isBillingNotificationMillis(nowMillis) ||
        !isBillingNotificationMillis(leaseUntilMillis) || leaseUntilMillis<=nowMillis || !Number.isSafeInteger(maxAttempts) || maxAttempts<1 || maxAttempts>10) fail();
      const target=ref(id);
      return db.runTransaction(async tx=>{
        const snap=await tx.get(target);if(!snap.exists)return {kind:'skipped'};
        const value=snap.data()!;
        if (!validBillingNotificationRecord(value,id,environment)) {
          tx.set(target,terminal(value,'blocked_invalid_notification',nowMillis,'notification_invalid'));return {kind:'blocked'};
        }
        if (!['pending','failed_retryable','claimed','sending'].includes(value.status)) {
          // A stale dispatch field on a terminal record must not starve the
          // bounded queue scan. It never authorizes another delivery.
          if (value.dispatchAtMillis!==undefined) tx.set(target,clearDispatch(value));
          return {kind:'skipped'};
        }
        if (!isBillingNotificationMillis(value.dispatchAtMillis)) {
          tx.set(target,terminal(value,'blocked_invalid_notification',nowMillis,'schedule_invalid'));return {kind:'blocked'};
        }
        if (value.dispatchAtMillis>nowMillis) return {kind:'skipped'};
        if (['claimed','sending'].includes(value.status)) {
          if (!token(value.leaseToken) || !token(value.attemptId) || !isBillingNotificationMillis(value.leaseUntilMillis)) {
            tx.set(target,terminal(value,'blocked_invalid_notification',nowMillis,'lease_invalid'));return {kind:'blocked'};
          }
          if (Number(value.leaseUntilMillis)>nowMillis) return {kind:'skipped'};
          if (value.status==='sending') {
            // A prior Gmail call might already have accepted this message.
            // Keep the exact owner/attempt for a late positive receipt, but
            // remove dispatch so a successor can never send it a second time.
            tx.set(target,terminal(value,'uncertain',nowMillis,'delivery_uncertain'));return {kind:'uncertain'};
          }
        }
        if ((value.attempts??0)>=maxAttempts) {
          tx.set(target,terminal(value,'failed_permanent',nowMillis,'attempt_limit'));return {kind:'exhausted'};
        }
        const next={...value,status:'claimed' as const,attempts:(value.attempts??0)+1,
          leaseToken,attemptId,leaseUntilMillis,dispatchAtMillis:leaseUntilMillis,updatedAtMillis:nowMillis};
        tx.set(target,next);
        return {kind:'claimed',notification:next,leaseToken,attemptId} as BillingNotificationClaimResult;
      });
    },
    async beginSend(input) {
      const {id,leaseToken,attemptId,nowMillis,leaseUntilMillis,recipientSource,recipientReference}=input;
      if (!token(leaseToken) || !token(attemptId) || !isBillingNotificationMillis(nowMillis) || !isBillingNotificationMillis(leaseUntilMillis) ||
        leaseUntilMillis<=nowMillis || !['auth_verified','apple_relay','user_supplied'].includes(recipientSource) || !isBillingNotificationHash(recipientReference)) fail();
      const target=ref(id);
      return db.runTransaction(async tx=>{
        const snap=await tx.get(target), value=snap.data();
        if (!value || !validBillingNotificationRecord(value,id,environment) || value.status!=='claimed' ||
          value.leaseToken!==leaseToken || value.attemptId!==attemptId || !isBillingNotificationMillis(value.leaseUntilMillis) || value.leaseUntilMillis<=nowMillis) return false;
        tx.set(target,{...value,status:'sending',leaseUntilMillis,dispatchAtMillis:leaseUntilMillis,
          sendStartedAtMillis:nowMillis,updatedAtMillis:nowMillis,recipientSource,recipientReference});
        return true;
      });
    },
    async finish(input) {
      const {id,leaseToken,attemptId,outcome}=input;
      if (!token(leaseToken) || !token(attemptId) || !object(outcome) || !isBillingNotificationMillis(outcome.atMillis) ||
        !['sent','failed_retryable','failed_permanent','blocked_no_verified_contact','blocked_recipient_not_allowed','blocked_invalid_notification','uncertain'].includes(outcome.status) ||
        (outcome.lastErrorCategory!==undefined && !safeCategory(outcome.lastErrorCategory)) ||
        (outcome.status==='sent' && !isBillingNotificationHash(outcome.messageIdHash)) ||
        (outcome.status==='failed_retryable' && (!isBillingNotificationMillis(outcome.nextAttemptAtMillis) || outcome.nextAttemptAtMillis<=outcome.atMillis))) fail();
      const target=ref(id);
      return db.runTransaction(async tx=>{
        const snap=await tx.get(target), value=snap.data();
        if (!value || !validBillingNotificationRecord(value,id,environment) || value.leaseToken!==leaseToken || value.attemptId!==attemptId ||
          !['claimed','sending','uncertain'].includes(value.status)) return false;
        // A worker may record late proof for its exact still-unreplaced send
        // intent. It cannot turn a pre-send claimed row into sent/uncertain.
        if (['sent','uncertain'].includes(outcome.status) && !['sending','uncertain'].includes(value.status)) return false;
        let next:Record<string,any>=terminal(value,outcome.status,outcome.atMillis,outcome.lastErrorCategory??'none');
        if (outcome.status==='failed_retryable') {
          next={...next,nextAttemptAtMillis:outcome.nextAttemptAtMillis,dispatchAtMillis:outcome.nextAttemptAtMillis};
        }
        if (outcome.status==='sent') {
          next.sentAtMillis=outcome.atMillis;next.messageIdHash=outcome.messageIdHash;delete next.lastErrorCategory;
        }
        // Lease expiry is intentionally not sufficient to authorize resending.
        // Preserve attempt fencing for uncertain/late receipts; remove owner
        // data after a confirmed terminal failure/success.
        if (outcome.status!=='uncertain') {delete next.leaseToken;delete next.attemptId;}
        tx.set(target,next);return true;
      });
    },
  };
}
