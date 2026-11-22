import {createHash} from 'node:crypto';
import type {LimitedContactTestReservation} from './billingNotificationGmail';
import {accountDeletionRef} from './accountDeletion';
import {validWebBillingUid} from './webBillingShared';
import {BillingContactError, BillingContactStore, BILLING_CONTACT_LIVE_NAMESPACE} from './billingContact';

/** Live-only server store. Every mutation reads the deletion fence in the same
 * transaction, so a delayed email confirmation cannot recreate a deleted contact. */
export function createLiveBillingContactStore(db:FirebaseFirestore.Firestore):BillingContactStore {
  const ref=(uid:string)=>{
    if (!validWebBillingUid(uid)) throw new BillingContactError('unauthenticated');
    return db.doc(BILLING_CONTACT_LIVE_NAMESPACE+'/'+uid);
  };
  return {
    async read(uid) {
      const [deletion,contact]=await Promise.all([accountDeletionRef(db,uid).get(),ref(uid).get()]);
      if (deletion.exists) throw new BillingContactError('contact_account_unavailable');
      return contact.data()??{};
    },
    async mutate(uid,update) {
      return db.runTransaction(async tx=>{
        const target=ref(uid);
        const [deletion,contact]=await Promise.all([tx.get(accountDeletionRef(db,uid)),tx.get(target)]);
        if (deletion.exists) throw new BillingContactError('contact_account_unavailable');
        const next=update(contact.data()??{});
        tx.set(target,next.state);
        return next.result;
      });
    },
  };
}

/** A fixed Live-wide slot limits this explicitly scoped contact smoke to one
 * irreversible Gmail request across processes, days, retries and config edits.
 * It is a permanent reservation, NOT a TTL record or daily reusable receipt. */
export const LIVE_BILLING_CONTACT_TEST_RESERVATION_PATH='billing_notification_delivery_limits/_limited_contact_test';
export function createLimitedLiveBillingContactReservation(db:FirebaseFirestore.Firestore,uid:string) {
  if (!validWebBillingUid(uid)) throw new BillingContactError('unauthenticated');
  const subjectHash=createHash('sha256').update(uid).digest('hex');
  const slot=db.doc(LIVE_BILLING_CONTACT_TEST_RESERVATION_PATH);
  return async(input:LimitedContactTestReservation):Promise<boolean>=>{
    if (input.subjectHash!==subjectHash || ![input.recipientHash,input.notificationIdHash].every(h=>/^[a-f0-9]{64}$/.test(h)) ||
      !Number.isSafeInteger(input.nowMillis) || input.nowMillis<=0 || !Number.isSafeInteger(input.expiresAtMillis) ||
      input.nowMillis>=input.expiresAtMillis) throw new BillingContactError('contact_configuration_invalid');
    return db.runTransaction(async tx=>{
      const [deletion,reserved]=await Promise.all([tx.get(accountDeletionRef(db,uid)),tx.get(slot)]);
      if (deletion.exists || reserved.exists) return false;
      tx.create(slot,{purpose:'billing_contact_live_limited_test',schemaVersion:1,
        subjectHash,recipientHash:input.recipientHash,notificationIdHash:input.notificationIdHash,
        reservedAtMillis:input.nowMillis,expiresAtMillis:input.expiresAtMillis});
      return true;
    });
  };
}
