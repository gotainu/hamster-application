import {createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {billingNotificationsFromHooks} from './billingNotificationEvents';
import {accountDeletionRef} from './accountDeletion';
import {
  WebBillingWebhookError, WebBillingWebhookStore, WebBillingSubject,
  WebBillingSubscription, WebBillingCommit,
} from './webBillingWebhook';

export const WEB_BILLING_EVENT_COLLECTION = 'billing_webhook_events';
export const WEB_BILLING_CUSTOMER_COLLECTION = 'billing_customers';
export const WEB_BILLING_SYNC_COLLECTION = 'billing_webhook_subjects';
export const WEB_BILLING_OUTBOX_COLLECTION = 'billing_notification_outbox';
const digest = (value: string) => createHash('sha256').update(value).digest('hex');
const conflict = (): never => {throw new WebBillingWebhookError('sync_conflict', true);};
// An unconfirmed deletion may still be declined. Preserve normal billing until
// cancellation has been durably confirmed, before any account data is removed.
const deletionFinal = (snap: FirebaseFirestore.DocumentSnapshot): boolean =>
  snap.exists && (snap.get('billingStopped') === true || snap.get('status') === 'completed');
function assertHash(value: string): void {
  if (!/^[a-f0-9]{64}$/.test(value)) throw new WebBillingWebhookError('reference_invalid');
}
function assertUid(uid: string): void {
  if (typeof uid !== 'string' || uid.length > 128 || !/^[^/\s\u0000-\u001f\u007f]+$/u.test(uid)) throw new WebBillingWebhookError('uid_binding_invalid');
}
function assertLease(lease: string, nowMs?: number, untilMs?: number): void {
  if (typeof lease !== 'string' || !/^[A-Za-z0-9-]{1,128}$/.test(lease) ||
      (nowMs !== undefined && (!Number.isSafeInteger(nowMs) || nowMs <= 0)) ||
      (untilMs !== undefined && (!Number.isSafeInteger(untilMs) || untilMs <= (nowMs ?? 0)))) throw new WebBillingWebhookError('lease_invalid');
}
function version(s: FirebaseFirestore.DocumentSnapshot): string | null {
  return s.exists && s.updateTime ? `${s.updateTime.seconds}:${s.updateTime.nanoseconds}` : null;
}
function timestamp(value: number | null): Timestamp | null {
  return value === null ? null : Timestamp.fromMillis(value * 1000);
}
function binding(state: WebBillingSubject, uid: string, customer: string): void {
  const m = state.mapping, b = state.billing;
  if (m && (m.firebaseUid !== uid || m.customerId !== customer || m.stripeLivemode === false)) conflict();
  if (b?.stripeCustomerId && (b.stripeCustomerId !== customer || b.stripeLivemode === false || (b.firebaseUid && b.firebaseUid !== uid))) conflict();
  if (!m && b?.stripeCustomerId !== customer) conflict();
}
function assertBilling(uid: string, billing: WebBillingSubscription): void {
  if (billing.firebaseUid !== uid || billing.stripeLivemode !== true || billing.provider !== 'stripe' ||
      billing.billingSyncVersion !== 1 || ![500,550].includes(billing.amount) ||
      billing.currency !== 'jpy' || billing.interval !== 'month' ||
      !/^cus_[A-Za-z0-9_]+$/.test(billing.stripeCustomerId) ||
      !/^sub_[A-Za-z0-9_]+$/.test(billing.stripeSubscriptionId) ||
      !/^price_[A-Za-z0-9_]+$/.test(billing.stripePriceId) ||
      Object.prototype.hasOwnProperty.call(billing, 'testMode') || Object.prototype.hasOwnProperty.call(billing, 'previewFirebaseUid')) throw new WebBillingWebhookError('billing_invalid');
}
/** Database dependency is explicit: constructing this adapter never initializes
 * Firebase or opens a network connection. No retention TTL is selected here.
 * Notification delivery is a separate consumer; a delivery failure cannot undo
 * the committed entitlement or make a processed Stripe receipt run again. */
export function createWebBillingWebhookStore(db: FirebaseFirestore.Firestore, now: () => number = Date.now): WebBillingWebhookStore {
  const eventRef = (hash: string) => {assertHash(hash); return db.doc(`${WEB_BILLING_EVENT_COLLECTION}/${hash}`);};
  const refs = (uid: string) => {
    assertUid(uid); const hash = digest(uid);
    return {mapping:db.doc(`${WEB_BILLING_CUSTOMER_COLLECTION}/${hash}`),
      billing:db.doc(`users/${uid}/billing/subscription`), subject:db.doc(`${WEB_BILLING_SYNC_COLLECTION}/${hash}`)};
  };
  const subject = (mapping: FirebaseFirestore.DocumentSnapshot, billing: FirebaseFirestore.DocumentSnapshot): WebBillingSubject => ({
    mapping:mapping.exists?mapping.data() as WebBillingSubject['mapping']:null,
    billing:billing.exists?billing.data()!:null,mappingVersion:version(mapping),billingVersion:version(billing),
  });
  return {
    async claimEvent(eventHash, lease, nowMs, untilMs, meta) {
      assertLease(lease,nowMs,untilMs);
      if (meta.version!==1 || !Number.isSafeInteger(meta.createdSeconds) || meta.createdSeconds<=0) throw new WebBillingWebhookError('event_invalid');
      return db.runTransaction(async tx => {
        const ref = eventRef(eventHash), snap = await tx.get(ref), old = snap.data() ?? {};
        if (old.result==='processed') return 'processed';
        if (old.lease && old.leaseUntil>nowMs) return 'busy';
        tx.set(ref,{...meta,stripeLivemode:true,result:'processing',lease,leaseUntil:untilMs,
          attempts:Number.isSafeInteger(old.attempts)?old.attempts+1:1});
        return 'claimed';
      });
    },
    async readSubject(uid) {
      const ref = refs(uid);
      const [mapping,billing,deletion] = await db.getAll(ref.mapping,ref.billing,accountDeletionRef(db,uid));
      return {...subject(mapping,billing),...(deletionFinal(deletion)?{deletionRequested:true}:{})};
    },
    async claimSubject(uid, lease, nowMs, untilMs) {
      assertLease(lease,nowMs,untilMs);
      return db.runTransaction(async tx => {
        const ref = refs(uid).subject, snap = await tx.get(ref), old = snap.data() ?? {};
        if (old.lease && old.untilMs>nowMs) return false;
        tx.set(ref,{lease,untilMs,stripeLivemode:true});
        return true;
      });
    },
    async ignoreDeletedSubject({uid,eventHash,lease,nowMs}) {
      const ref=refs(uid), receipt=eventRef(eventHash);
      await db.runTransaction(async tx=>{
        const [deletion,event,locked]=await Promise.all([
          tx.get(accountDeletionRef(db,uid)),tx.get(receipt),tx.get(ref.subject),
        ]);
        if (!deletionFinal(deletion) || event.data()?.lease!==lease || locked.data()?.lease!==lease) conflict();
        tx.set(receipt,{result:'processed',reason:'account_deletion',processedAtMillis:nowMs,
          stripeLivemode:true,lease:null,leaseUntil:0},{merge:true});
        tx.set(ref.subject,{lease:null,untilMs:0,stripeLivemode:true});
      });
    },
    async commit(input: WebBillingCommit) {
      const {uid,eventHash,lease,nowMs,before,billing,hooks,eventRecord} = input;
      assertUid(uid); assertLease(lease,nowMs); assertBilling(uid,billing);
      if (eventRecord.version!==1 || eventRecord.processedAtMillis!==nowMs) throw new WebBillingWebhookError('event_invalid');
      const ref = refs(uid), receipt = eventRef(eventHash);
      for (const hook of hooks) {
        assertHash(hook.id);
        if (hook.id!==digest(hook.transitionKey) || hook.firebaseUid!==uid || hook.subscriptionId!==billing.stripeSubscriptionId ||
            hook.eventHash!==eventHash || hook.status!=='pending') throw new WebBillingWebhookError('hook_invalid');
      }
      const notifications = billingNotificationsFromHooks({billing,hooks,environment:'live'});
      const outbox = notifications.map(notification=>db.doc(`${WEB_BILLING_OUTBOX_COLLECTION}/${notification.id}`));
      return db.runTransaction(async tx => {
        // Firestore requires all reads before writes, including outbox dedupe.
        const [locked,event,mapping,current,deletion,...existingHooks] = await Promise.all([
          tx.get(ref.subject),tx.get(receipt),tx.get(ref.mapping),tx.get(ref.billing),tx.get(accountDeletionRef(db,uid)),...outbox.map(r=>tx.get(r)),
        ]);
        const lock = locked.data() ?? {}, e = event.data() ?? {};
        const commitTime = Math.max(nowMs,now());
        if (!Number.isSafeInteger(commitTime) || lock.lease!==lease || lock.untilMs<=commitTime || e.lease!==lease || e.leaseUntil<=commitTime || e.result!=='processing') conflict();
        if (deletionFinal(deletion)) {
          tx.set(receipt,{result:'processed',reason:'account_deletion',processedAtMillis:nowMs,
            stripeLivemode:true,lease:null,leaseUntil:0},{merge:true});
          tx.set(ref.subject,{lease:null,untilMs:0,stripeLivemode:true});
          return 'ignored' as const;
        }
        if (version(mapping)!==before.mappingVersion || version(current)!==before.billingVersion) conflict();
        binding(subject(mapping,current),uid,billing.stripeCustomerId);
        const previousFence = current.data()?.billingSyncFence;
        const committedAt = Timestamp.fromMillis(nowMs);
        tx.set(ref.billing,{...billing,billingSyncFence:Number.isSafeInteger(previousFence)?previousFence+1:1,
          currentPeriodStart:timestamp(billing.currentPeriodStartSeconds),currentPeriodEnd:timestamp(billing.currentPeriodEndSeconds),
          trialStart:timestamp(billing.trialStartSeconds),trialEnd:timestamp(billing.trialEndSeconds),
          cancelAt:timestamp(billing.cancelAtSeconds),canceledAt:timestamp(billing.canceledAtSeconds),
          firstChargeAt:timestamp(billing.firstChargeAtSeconds),nextChargeAt:timestamp(billing.nextChargeAtSeconds),
          latestStripeEventAt:committedAt,updatedAt:committedAt},{merge:true});
        tx.set(receipt,{...eventRecord,stripeLivemode:true,result:'processed',lease:null,leaseUntil:0});
        tx.set(ref.subject,{lease:null,untilMs:0,stripeLivemode:true});
        for (let i=0;i<notifications.length;i++) if (!existingHooks[i].exists) tx.create(outbox[i],notifications[i]);
      });
    },
    async release({uid,eventHash,lease,errorCode}) {
      assertLease(lease);
      // Only known safe internal error codes can reach stored operational data.
      if (!/^[a-z_]{1,64}$/.test(errorCode)) throw new WebBillingWebhookError('error_invalid');
      const receipt = eventRef(eventHash), lockRef = uid ? refs(uid).subject : null;
      await db.runTransaction(async tx => {
        const event = await tx.get(receipt), lock = lockRef ? await tx.get(lockRef) : null;
        if (event.data()?.lease===lease && event.data()?.result!=='processed') tx.update(receipt,{result:'retryable',lease:null,leaseUntil:0,errorCode});
        if (lockRef && lock?.data()?.lease===lease) tx.set(lockRef,{lease:null,untilMs:0,stripeLivemode:true});
      });
    },
  };
}
