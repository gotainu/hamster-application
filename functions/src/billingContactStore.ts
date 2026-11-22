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

/** Fixed Live-wide permanent slots count irreversible Gmail requests across
 * processes, days, retries and config edits. They are never TTL/daily records.
 * An explicitly approved cumulative second send requires the original receipt. */
export const LIVE_BILLING_CONTACT_TEST_RESERVATION_PATH='billing_notification_delivery_limits/_limited_contact_test';
export const LIVE_BILLING_CONTACT_TEST_SECOND_RESERVATION_PATH='billing_notification_delivery_limits/_limited_contact_test_2';
const digest=(v:string)=>createHash('sha256').update(v).digest('hex');
const validHash=(v:unknown):v is string=>typeof v==='string' && /^[a-f0-9]{64}$/.test(v);
function firstReservation(value:unknown,subjectHash:string,nowMillis:number):value is Record<string,any> {
  if (!value || typeof value!=='object' || Array.isArray(value)) return false;
  const v=value as Record<string,any>;
  return Object.keys(v).sort().join(',')==='expiresAtMillis,notificationIdHash,purpose,recipientHash,reservedAtMillis,schemaVersion,subjectHash' &&
    v.purpose==='billing_contact_live_limited_test' && v.schemaVersion===1 && v.subjectHash===subjectHash &&
    [v.subjectHash,v.recipientHash,v.notificationIdHash].every(validHash) && Number.isSafeInteger(v.reservedAtMillis) &&
    v.reservedAtMillis>0 && v.reservedAtMillis<nowMillis && Number.isSafeInteger(v.expiresAtMillis) &&
    v.expiresAtMillis>v.reservedAtMillis && v.expiresAtMillis<=8640000000000000;
}
function nextLimitedSlot(first:FirebaseFirestore.DocumentSnapshot,second:FirebaseFirestore.DocumentSnapshot,
  subjectHash:string,maxTotalSends:1|2,nowMillis:number,notificationIdHash?:string):1|2|null {
  if (second.exists) return null;
  if (maxTotalSends===1) return first.exists?null:1;
  if (maxTotalSends!==2 || !first.exists || !firstReservation(first.data(),subjectHash,nowMillis)) return null;
  // Retrying the original irreversible request must not consume the additional
  // approval. Its stable Message-ID alone cannot deduplicate Gmail delivery.
  if (notificationIdHash!==undefined && first.get('notificationIdHash')===notificationIdHash) return null;
  return 2;
}
/** Read-only preguard keeps an earlier proof intact when no slot remains.
 * The transaction immediately before Gmail remains the final authority. */
export async function canRequestLimitedLiveBillingContact(db:FirebaseFirestore.Firestore,uid:string,maxTotalSends:1|2,nowMillis:number):Promise<boolean> {
  if (!validWebBillingUid(uid) || !Number.isSafeInteger(nowMillis) || nowMillis<=0 || ![1,2].includes(maxTotalSends)) return false;
  const [first,second]=await Promise.all([db.doc(LIVE_BILLING_CONTACT_TEST_RESERVATION_PATH).get(),db.doc(LIVE_BILLING_CONTACT_TEST_SECOND_RESERVATION_PATH).get()]);
  return nextLimitedSlot(first,second,digest(uid),maxTotalSends,nowMillis)!==null;
}
export function createLimitedLiveBillingContactReservation(db:FirebaseFirestore.Firestore,uid:string,maxTotalSends:1|2=1) {
  if (!validWebBillingUid(uid) || ![1,2].includes(maxTotalSends)) throw new BillingContactError('contact_configuration_invalid');
  const subjectHash=digest(uid),slot=db.doc(LIVE_BILLING_CONTACT_TEST_RESERVATION_PATH),secondSlot=db.doc(LIVE_BILLING_CONTACT_TEST_SECOND_RESERVATION_PATH);
  return async(input:LimitedContactTestReservation):Promise<boolean>=>{
    if (input.subjectHash!==subjectHash || ![input.recipientHash,input.notificationIdHash].every(validHash) ||
      !Number.isSafeInteger(input.nowMillis) || input.nowMillis<=0 || !Number.isSafeInteger(input.expiresAtMillis) ||
      input.expiresAtMillis>8640000000000000 || input.nowMillis>=input.expiresAtMillis) throw new BillingContactError('contact_configuration_invalid');
    return db.runTransaction(async tx=>{
      const [deletion,first,second]=await Promise.all([tx.get(accountDeletionRef(db,uid)),tx.get(slot),tx.get(secondSlot)]);
      if (deletion.exists) return false;
      const ordinal=nextLimitedSlot(first,second,subjectHash,maxTotalSends,input.nowMillis,input.notificationIdHash);
      if (ordinal===null) return false;
      tx.create(ordinal===1?slot:secondSlot,{purpose:'billing_contact_live_limited_test',schemaVersion:1,
        subjectHash,recipientHash:input.recipientHash,notificationIdHash:input.notificationIdHash,
        reservedAtMillis:input.nowMillis,expiresAtMillis:input.expiresAtMillis,
        ...(ordinal===2?{reservationOrdinal:2,previousNotificationIdHash:first.get('notificationIdHash')}:{}),
      });
      return true;
    });
  };
}
