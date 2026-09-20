import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const region = 'asia-northeast1';
export const aiTrialLimit = 3;
export const changesTrialDays = 5;

function accessRef(uid: string) {
  return admin.firestore()
    .collection('users')
    .doc(uid)
    .collection('feature_access')
    .doc('trial');
}

export const activateFeatureTrial = onCall({region}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const ref = accessRef(uid);
  await admin.firestore().runTransaction(async (transaction) => {
    const current = await transaction.get(ref);
    if (current.exists) return;
    const now = admin.firestore.Timestamp.now();
    transaction.set(ref, {
      version: 1,
      activatedAt: now,
      changesTrialEndsAt: admin.firestore.Timestamp.fromMillis(
        now.toMillis() + changesTrialDays * 24 * 60 * 60 * 1000,
      ),
      aiTrialLimit,
      aiTrialUsed: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  const snap = await ref.get();
  return snap.data();
});

// RAG APIをプロキシ化するまでの移行用のサーバー権限。クライアントは応答成功後に
// この呼び出しで確定するため、料金判定を端末ローカルに置かない。
export const consumeAiTrial = onCall({region}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  const ref = accessRef(uid);
  const result = await admin.firestore().runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) throw new HttpsError('failed-precondition', '無料体験を開始してください。');
    const data = snap.data() ?? {};
    const used = typeof data.aiTrialUsed === 'number' ? data.aiTrialUsed : 0;
    const limit = typeof data.aiTrialLimit === 'number' ? data.aiTrialLimit : aiTrialLimit;
    if (used >= limit) throw new HttpsError('resource-exhausted', 'AI無料体験は3回までです。');
    const nextUsed = used + 1;
    transaction.update(ref, {
      aiTrialUsed: nextUsed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {aiTrialUsed: nextUsed, aiTrialLimit: limit};
  });
  return result;
});
