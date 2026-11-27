import {createHash} from 'node:crypto';
import {LimitedBillingNotificationSelection,validLimitedBillingNotificationSelection,limitedBillingNotificationWindowOpen} from './billingNotificationDispatch';
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

/** This predicate is also used immediately before a limited provider call.
 * Its binding is operator configuration, never a UID/address from a request. */
export function matchesLimitedBillingNotification(value:unknown,id:string,selection:LimitedBillingNotificationSelection):boolean {
  if(!validLimitedBillingNotificationSelection(selection) || id!==selection.notificationId ||
      !validBillingNotificationRecord(value,id,'live'))return false;
  return value.type==='contract_registered' && createHash('sha256').update(value.firebaseUid).digest('hex')===selection.subjectHash &&
    value.createdAtMillis>=selection.notBeforeMillis && value.createdAtMillis<selection.expiresAtMillis &&
    isBillingNotificationMillis(value.eventCreatedAtMillis) && value.eventCreatedAtMillis>=selection.notBeforeMillis &&
    value.eventCreatedAtMillis<selection.expiresAtMillis;
}

/** Environment-specific outbox adapter only. It has no billing read/write or
 * Stripe capability. dispatchAtMillis exists only for work eligible for scans;
 * a single-field range index suffices (no broad scan or composite index needed).
 * The database and clock are injected; construction does not initialize Admin. */
export function createBillingNotificationStore(db:FirebaseFirestore.Firestore, environment:BillingNotificationEnvironment,
  liveDispatchNotBeforeMillis?:number,limitedSelection?:LimitedBillingNotificationSelection,clock:()=>number=Date.now):BillingNotificationStore {
  if (!['live','preview'].includes(environment) ||
      (environment==='live' && (!isBillingNotificationMillis(liveDispatchNotBeforeMillis) || liveDispatchNotBeforeMillis%1000!==0)) ||
      (environment==='preview' && liveDispatchNotBeforeMillis!==undefined) ||
      (limitedSelection!==undefined && (environment!=='live' || !validLimitedBillingNotificationSelection(limitedSelection) ||
        limitedSelection.notBeforeMillis!==liveDispatchNotBeforeMillis))) fail();
  const collection=environment==='live'?BILLING_NOTIFICATION_OUTBOX:PREVIEW_BILLING_NOTIFICATION_OUTBOX;
  const ref=(id:string)=>{if(!isBillingNotificationHash(id))fail();return db.doc(collection+'/'+id);};
  return {
    async listDue(nowMillis,limit) {
      if (!isBillingNotificationMillis(nowMillis) || !Number.isSafeInteger(limit) || limit<1 || limit>20) fail();
      if(limitedSelection) {
        if(!limitedBillingNotificationWindowOpen(limitedSelection,nowMillis))return [];
        const snap=await ref(limitedSelection.notificationId).get(),value=snap.data(),time=clock();
        if(!limitedBillingNotificationWindowOpen(limitedSelection,time) || !matchesLimitedBillingNotification(value,limitedSelection.notificationId,limitedSelection) ||
            !value || !['pending','failed_retryable','claimed','sending'].includes(value.status) ||
            !isBillingNotificationMillis(value.dispatchAtMillis) || value.dispatchAtMillis>time ||
            value.createdAtMillis>time || value.eventCreatedAtMillis>time)return [];
        return [limitedSelection.notificationId];
      }
      const result=await db.collection(collection).where('dispatchAtMillis','<=',nowMillis).orderBy('dispatchAtMillis','asc').limit(limit).get();
      return result.docs.map(doc=>doc.id);
    },
    async claim(input) {
      const {id,environment:requested,leaseToken,attemptId,nowMillis,leaseUntilMillis,maxAttempts}=input;
      if (requested!==environment || !token(leaseToken) || !token(attemptId) || !isBillingNotificationMillis(nowMillis) ||
        !isBillingNotificationMillis(leaseUntilMillis) || leaseUntilMillis<=nowMillis || !Number.isSafeInteger(maxAttempts) || maxAttempts<1 || maxAttempts>10) fail();
      if(limitedSelection && (id!==limitedSelection.notificationId || !limitedBillingNotificationWindowOpen(limitedSelection,clock())))return {kind:'skipped'};
      const target=ref(id);
      return db.runTransaction(async tx=>{
        const snap=await tx.get(target);if(!snap.exists)return {kind:'skipped'};
        const value=snap.data()!;
        if(limitedSelection && (!limitedBillingNotificationWindowOpen(limitedSelection,clock()) ||
            !matchesLimitedBillingNotification(value,id,limitedSelection) || value.createdAtMillis>clock() || value.eventCreatedAtMillis>clock()))return {kind:'skipped'};
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
        if (environment==='live' && (value.createdAtMillis<Number(liveDispatchNotBeforeMillis) ||
            !isBillingNotificationMillis(value.eventCreatedAtMillis) || value.eventCreatedAtMillis<Number(liveDispatchNotBeforeMillis))) {
          // Do not backfill old pending mail, including old events reprocessed
          // after launch. Keep the full record without consuming an attempt or
          // pretending it was sent. Removing dispatch lets later bounded scans
          // reach eligible jobs; no composite index or broad scan is needed.
          const held:Record<string,any>={...value,status:'held_before_dispatch_start',
            holdReason:'before_dispatch_start',heldAtMillis:nowMillis,updatedAtMillis:nowMillis};
          // Keep prior retry/error and delivery evidence for operator review.
          delete held.dispatchAtMillis;delete held.leaseUntilMillis;delete held.leaseToken;delete held.attemptId;
          tx.set(target,held);return {kind:'held'};
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
      if(limitedSelection && (id!==limitedSelection.notificationId || !limitedBillingNotificationWindowOpen(limitedSelection,clock())))return false;
      const target=ref(id);
      return db.runTransaction(async tx=>{
        const snap=await tx.get(target), value=snap.data();
        if(limitedSelection && (!limitedBillingNotificationWindowOpen(limitedSelection,clock()) || !matchesLimitedBillingNotification(value,id,limitedSelection)))return false;
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
      if(limitedSelection && id!==limitedSelection.notificationId)return false;
      const target=ref(id);
      return db.runTransaction(async tx=>{
        const snap=await tx.get(target), value=snap.data();
        if(limitedSelection && !matchesLimitedBillingNotification(value,id,limitedSelection))return false;
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
