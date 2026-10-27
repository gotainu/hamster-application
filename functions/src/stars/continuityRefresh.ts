import * as admin from 'firebase-admin';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {processCareActionReward} from '../careActions/careActions';
import {continuityView, readContinuityState, reconcileContinuity} from './continuity';

/** Pending server receipts are considered before lazy expiry; no global timer. */
export async function refreshContinuityWithReceipts(params: {
  db: admin.firestore.Firestore; uid: string; now?: Date; limit?: number;
}) {
  const {db, uid} = params; const now = params.now ?? new Date();
  const limit = Math.max(1, Math.min(100, params.limit ?? 100));
  const queue = db.collection(`users/${uid}/care_reward_receipts`);
  const receipts = await queue.orderBy('acceptedAt').limit(limit).get();
  for (const receipt of receipts.docs) {
    try {await processCareActionReward({db, uid, dayKey: receipt.get('dayKey'), mutationId: receipt.get('mutationId'), now});}
    catch (_) {
      const state = await db.doc(`users/${uid}/rewards/continuity`).get();
      return {...continuityView(readContinuityState(state.data()), now), confirmationPending: true};
    }
  }
  // Keep residual work and avoid confirming expiry while its timely receipts
  // remain pending. A later refresh continues the same bounded processing.
  if (!(await queue.limit(1).get()).empty) {
    const state = await db.doc(`users/${uid}/rewards/continuity`).get();
    return {...continuityView(readContinuityState(state.data()), now), confirmationPending: true};
  }
  // A new receipt may arrive after the empty check. Preserve the transaction's
  // pending decision rather than presenting an unconfirmed result as final.
  return reconcileContinuity({db, uid, now});
}
export const refreshCareContinuity = onCall({region: 'asia-northeast1'}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  return refreshContinuityWithReceipts({db: admin.firestore(), uid});
});
