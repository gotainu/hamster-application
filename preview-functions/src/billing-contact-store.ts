import type {Firestore} from 'firebase-admin/firestore';
import {BILLING_CONTACT_NAMESPACE, BillingContactError, BillingContactStore} from './billing-contact';

/** Isolated Preview document only; never users/{uid}/billing or Firebase Auth. */
export function createFirestoreBillingContactStore(db: Firestore): BillingContactStore {
  const ref = (uid: string) => {
    if (typeof uid !== 'string' || !uid || uid.length > 128 || /[\/\s\u0000-\u001f\u007f]/u.test(uid)) throw new BillingContactError('unauthenticated');
    return db.collection(BILLING_CONTACT_NAMESPACE).doc(uid);
  };
  return {
    async read(uid) {return (await ref(uid).get()).data() || {};},
    async mutate(uid, update) {
      return db.runTransaction(async tx => {
        const doc = ref(uid);
        const current = (await tx.get(doc)).data() || {};
        const next = update(current);
        tx.set(doc, next.state);
        return next.result;
      });
    },
  };
}
