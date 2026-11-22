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
