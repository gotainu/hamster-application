import * as admin from 'firebase-admin';
import {createHash} from 'crypto';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {SENSOR_POLLING_POLICY_VERSION, SENSOR_CAPTURE_BLOCK_FIELD} from './acquisition';

export const SENSOR_POLLING_POLICY = Object.freeze({
  version: SENSOR_POLLING_POLICY_VERSION, schedule: 'every 60 minutes', timeZone: 'UTC', slotAnchor: null,
});

function config(value: Record<string, unknown> | null) {
  return {
    deviceId: typeof value?.meterDeviceId === 'string' && value.meterDeviceId.length > 0 ? value.meterDeviceId : null,
    enabled: typeof value?.enabled === 'boolean' ? value.enabled : null,
    hasSecrets: typeof value?.hasSecrets === 'boolean' ? value.hasSecrets : null,
  };
}

/** Source update time is evidence about configuration, never proof of paid
 * eligibility or physical placement throughout the surrounding interval. */
export async function recordSensorConfiguration(input: {
  db: FirebaseFirestore.Firestore; uid: string; sourcePath: string;
  sourceUpdatedAt: FirebaseFirestore.Timestamp | null;
  before: Record<string, unknown> | null; after: Record<string, unknown> | null;
}) {
  const {db, uid, sourcePath, sourceUpdatedAt} = input;
  if (!sourceUpdatedAt) return {changed: false, reason: 'source_version_unknown'};
  if (sourcePath !== `users/${uid}/integrations/switchbot`) throw new Error('configuration_owner_mismatch');
  const previousConfig = config(input.before), nextConfig = config(input.after);
  if (input.before !== null && input.after !== null && JSON.stringify(previousConfig) === JSON.stringify(nextConfig)) return {changed: false};
  const sourceVersion = `${sourceUpdatedAt.seconds}:${sourceUpdatedAt.nanoseconds}`;
  const stateId = createHash('sha256').update(`${sourcePath}|${sourceVersion}`).digest('hex');
  const payload = {sourcePath, sourceVersion, previousConfig, config: nextConfig, deleted: input.after === null};
  const payloadHash = createHash('sha256').update(JSON.stringify(payload)).digest('hex');
  const ref = db.doc(`users/${uid}/sensor_polling_state/${stateId}`);
  return db.runTransaction(async tx => {
    const [source, existing] = await Promise.all([tx.get(db.doc(sourcePath)), tx.get(ref)]);
    if (!source.exists || source.get(SENSOR_CAPTURE_BLOCK_FIELD) === true) return {changed: false, reason: 'source_unavailable'};
    if (existing.exists) {
      if (existing.get('payloadHash') !== payloadHash) throw new Error('configuration_evidence_collision');
      return {changed: true, stateId, replayed: true};
    }
    tx.create(ref, {
      schemaVersion: 1, stateId, ownerUid: uid, ...payload, payloadHash,
      sourceUpdatedAt, acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      policy: SENSOR_POLLING_POLICY, eligibility: 'unknown', continuity: 'transition_only',
      subjectAssociation: 'unknown',
    });
    return {changed: true, stateId, replayed: false};
  });
}

/** Serialize account deletion against the new asynchronous sensor writers.
 * Missing configuration is never recreated just to store a deletion marker. */
export async function blockSensorCaptureForDeletion(db: FirebaseFirestore.Firestore, uid: string): Promise<void> {
  const ref = db.doc(`users/${uid}/integrations/switchbot`);
  await db.runTransaction(async tx => {
    const source = await tx.get(ref);
    if (source.exists && source.get(SENSOR_CAPTURE_BLOCK_FIELD) !== true) {
      tx.update(ref, {[SENSOR_CAPTURE_BLOCK_FIELD]: true});
    }
  });
}

// Covers existing direct device-selection writes as well as registration and
// disconnect. No reads/writes of credentials, health, rewards or notifications.
export const sensorPollingConfigurationWritten = onDocumentWritten({
  region: 'asia-northeast1', document: 'users/{uid}/integrations/switchbot',
}, async event => {
  const change = event.data;
  // The normal disconnect updates the existing document. A physical deletion
  // may be account cleanup; never recreate a descendant after recursive delete.
  if (!change || !change.after.exists) return;
  const after = change.after.data() ?? null;
  const before = change.before.exists ? change.before.data() ?? null : null;
  const sourceUpdatedAt = change.after.updateTime ?? null;
  await recordSensorConfiguration({
    db: admin.firestore(), uid: event.params.uid, sourcePath: change.after.ref.path,
    sourceUpdatedAt, before, after,
  });
});
