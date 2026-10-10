import * as admin from 'firebase-admin';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {formatDateKey, normalizeDateKey} from './dateKey';
import {enqueueDailyPersonalityReport, enqueueDailyPersonalityRecord} from './personalityDaily';
import {syncPersonalityReport} from './personalityReport';

export const personalityHealthFeaturesWritten = onDocumentWritten({
  document:'users/{uid}/daily_health_features/{dateKey}',
  region:'asia-northeast1',timeoutSeconds:120,memory:'256MiB',retry:true,
},async event=>{
  const now = new Date();
  if (!event.data?.after.exists || event.params.dateKey !== formatDateKey(now)) return;
  const db = admin.firestore();
  // Preserve the v1 ready-set publisher and pointer for installed clients. Both
  // publications are idempotent; retries cannot rewrite immutable reports.
  await syncPersonalityReport({db,uid:event.params.uid,evaluationDateKey:event.params.dateKey,now});
  await enqueueDailyPersonalityReport({db,uid:event.params.uid,sourceDateKey:event.params.dateKey,now});
});

/** Queue-only bridge for today's activity records, which the existing health
 * trigger intentionally defers to the following day's assessment. */
export const personalityDistanceRecordWritten = onDocumentWritten({
  document: 'users/{uid}/distance_records/{recordId}',
  region: 'asia-northeast1', timeoutSeconds: 120, memory: '256MiB', retry: true,
}, async event => {
  if (!event.data?.after.exists) return;
  const now = new Date();
  const data = event.data.after.data() ?? {};
  let observed: string;
  try {observed = normalizeDateKey(typeof data.dayKey === 'string' ? data.dayKey : event.params.recordId);} catch (_) {return;}
  if (observed !== formatDateKey(now) || typeof data.distance !== 'number' || !Number.isFinite(data.distance) || data.distance < 0) return;
  await enqueueDailyPersonalityRecord({db: admin.firestore(), uid: event.params.uid, recordDateKey: observed, now});
});
