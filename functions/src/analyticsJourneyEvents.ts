import {createHash} from 'node:crypto';
import * as admin from 'firebase-admin';
import {region} from 'firebase-functions/v1';
import {onDocumentCreated, onDocumentWritten} from 'firebase-functions/v2/firestore';
import {classifyAnalytics} from './analyticsClassification';

export const ANALYTICS_DELETION_FIELD = 'analyticsDeletionStartedAt';
const REGION = 'asia-northeast1';
const options = {region: REGION, retry: true, maxInstances: 1, timeoutSeconds: 60};
function date(value: unknown): Date | null {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value : null;
  if (value && typeof value === 'object' && typeof (value as {toDate?: unknown}).toDate === 'function')
    return date((value as {toDate(): Date}).toDate());
  if (typeof value === 'string') return date(new Date(value));
  return null;
}
function eventId(namespace: string, source: string): string {
  return `${namespace}_${createHash('sha256').update(source).digest('hex')}`;
}
/** Replayed CloudEvents only create the same immutable metadata row. */
export async function saveJourneyMetadata(params: {
  db: FirebaseFirestore.Firestore; uid: string; id: string; data: Record<string, unknown>;
  sourcePath: string | null;
  validateInsideTransaction?: () => Promise<boolean>;
}): Promise<void> {
  const ref = params.db.doc(`users/${params.uid}/journey_events/${params.id}`);
  await params.db.runTransaction(async tx => {
    // A late trigger must not recreate metadata after its accepted source was deleted.
    const [owner, source, existing] = await Promise.all([
      tx.get(params.db.doc(`users/${params.uid}`)),
      params.sourcePath ? tx.get(params.db.doc(params.sourcePath)) : Promise.resolve(null), tx.get(ref),
    ]);
    if (owner.get(ANALYTICS_DELETION_FIELD) != null) return;
    if (params.sourcePath && !source?.exists) return;
    // Read-only Auth validation runs again if the owner/deletion fence changes.
    if (params.validateInsideTransaction && !await params.validateInsideTransaction()) return;
    if (existing.exists) return;
    const classification = classifyAnalytics(params.uid, params.data);
    tx.create(ref, {...params.data, eventId: params.id, schemaVersion: 1,
      testOnly: classification.accountClassification === 'test',
      environment: classification.environment, accountClassification: classification.accountClassification,
      analyticsSpecVersion: 'launch_journey_v1'});
  });
}

/** Fence the new asynchronous metadata writers before recursive cleanup.
 * The root is retained until Auth deletion; data-only cleanup retains this
 * minimal protected fence so a delayed Auth create event cannot recreate data. */
export async function blockAnalyticsEventsForDeletion(db: FirebaseFirestore.Firestore, uid: string): Promise<void> {
  const root = db.doc(`users/${uid}`);
  await db.runTransaction(async tx => {
    if ((await tx.get(root)).get(ANALYTICS_DELETION_FIELD) != null) return;
    tx.set(root, {[ANALYTICS_DELETION_FIELD]: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
  });
}

// Auth creation is registration authority. Existing accounts are not backfilled
// from a present-day profile or from the deployment date.
export const analyticsAccountRegistered = region(REGION).runWith({maxInstances: 1, timeoutSeconds: 60, failurePolicy: true})
  .auth.user().onCreate(async user => {
    const occurredAt = date(user.metadata.creationTime);
    if (!occurredAt) throw new Error('Registration acceptance time is unavailable.');
    await saveJourneyMetadata({db: admin.firestore(), uid: user.uid, id: 'account_registered', sourcePath: null,
      validateInsideTransaction: async () => {
        try {
          const current = await admin.auth().getUser(user.uid);
          return !current.disabled && date(current.metadata.creationTime)?.getTime() === occurredAt.getTime();
        } catch (error) {
          if ((error as {code?: unknown})?.code === 'auth/user-not-found') return false;
          throw error;
        }
      }, data: {
      eventName: 'account_registered', actor: 'server_auth', source: 'firebase_auth', occurredAt,
    }});
  });

type RecordKind = 'weight' | 'activity' | 'daily_checkin' | 'care_action';
/** Only immutable, accepted, manual revisions represent active record use.
 * Cancellations, sensor writes, unchanged retries and projection fallbacks do not. */
export function validRecordMetadata(kind: RecordKind, data: Record<string, any>, uid: string): Record<string, unknown> | null {
  const acceptedAt = date(data.acceptedAt);
  if (!acceptedAt || data.ownerUid !== uid || !Number.isSafeInteger(data.revision ?? data.recordRevision)) return null;
  let valid = false;
  if (kind === 'weight') valid = data.inputRoute === 'weight_manual' && data.operation !== 'cancel' &&
    Number.isFinite(data.values?.weightGrams) && data.values.weightGrams > 0;
  if (kind === 'activity') valid = ['wheel_rotations_manual', 'distance_manual'].includes(data.inputRoute) &&
    data.operation !== 'cancel' && Number.isFinite(data.values?.distance) && data.values.distance >= 0;
  if (kind === 'daily_checkin') valid = ['new_observation', 'correction'].includes(data.operation) &&
    ['normal', 'slightlyConcerned', 'veryConcerned'].includes(data.answer?.condition) &&
    data.answer?.answerProvenance?.overall === 'explicit_submission';
  if (kind === 'care_action') valid = data.status === 'active' && data.inputRoute === 'daily_checkin' &&
    Object.values(data.actions ?? {}).some((action: any) =>
      ['performed', 'not_performed'].includes(action?.answer) &&
      ['item_selection', 'batch_confirmation'].includes(action?.answerProvenance));
  if (!valid) return null;
  // No answers, values, memo, timing of the pet, or care details are exported.
  return {eventName: 'valid_record_saved', actor: 'user_client', source: 'manual', recordType: kind,
    occurredAt: acceptedAt, serverReceivedAt: acceptedAt};
}
async function recordRevision(event: any, kind: RecordKind): Promise<void> {
  const data = event.data?.data();
  if (!data) return;
  const metadata = validRecordMetadata(kind, data, event.params.uid);
  if (!metadata) return;
  await saveJourneyMetadata({db: admin.firestore(), uid: event.params.uid,
    id: eventId('valid_record', event.data.ref.path), sourcePath: event.data.ref.path, data: metadata});
}
export const analyticsWeightRevisionAccepted = onDocumentCreated(
  {...options, document: 'users/{uid}/weight_record_history/{recordId}/revisions/{revisionId}'},
  event => recordRevision(event, 'weight'));
export const analyticsActivityRevisionAccepted = onDocumentCreated(
  {...options, document: 'users/{uid}/distance_record_history/{recordId}/revisions/{revisionId}'},
  event => recordRevision(event, 'activity'));
export const analyticsObservationRevisionAccepted = onDocumentCreated(
  {...options, document: 'users/{uid}/observation_days/{dayKey}/revisions/{revisionId}'},
  event => recordRevision(event, 'daily_checkin'));
export const analyticsCareRevisionAccepted = onDocumentCreated(
  {...options, document: 'users/{uid}/daily_care_actions/{dayKey}/revisions/{revisionId}'},
  event => recordRevision(event, 'care_action'));

/** Events observe committed Stripe synchronization, never Checkout display or
 * an uncommitted webhook payload. No entitlement calculation is changed. */
export function billingJourneyTransitions(before: Record<string, any> | null, after: Record<string, any> | null, committedAt: Date): string[] {
  if (!after || after.provider !== 'stripe' || typeof after.stripeSubscriptionId !== 'string') return [];
  const sameSubscription = before?.stripeSubscriptionId === after.stripeSubscriptionId;
  // Reporting follows the existing entitlement deadline. Active is a
  // confirmed subscription state, not proof that an invoice was captured.
  const entitledActive = (data: Record<string, any> | null): boolean =>
    data?.plan === 'paid' && data.status === 'active' &&
    (data.currentPeriodEnd == null ||
      (date(data.currentPeriodEnd)?.getTime() ?? -Infinity) > committedAt.getTime());
  if (!date(committedAt)) return [];
  const active = entitledActive(after);
  const wasActive = sameSubscription && entitledActive(before);
  const result: string[] = [];
  if (active && !wasActive) result.push('subscription_activated');
  if (after.cancelAtPeriodEnd === true && (!sameSubscription || before?.cancelAtPeriodEnd !== true)) result.push('subscription_cancel_scheduled');
  if (after.status === 'canceled' && (!sameSubscription || before?.status !== 'canceled')) result.push('subscription_ended');
  if (['past_due', 'unpaid'].includes(after.status) && (!sameSubscription || before?.status !== after.status)) result.push('subscription_payment_failed');
  return result;
}
export const analyticsSubscriptionCommitted = onDocumentWritten(
  {...options, document: 'users/{uid}/billing/subscription'}, async event => {
    const before = event.data?.before.data() ?? null, after = event.data?.after.data() ?? null;
    const occurredAt = date(event.data?.after.updateTime);
    if (!occurredAt || !after) return;
    for (const name of billingJourneyTransitions(before, after, occurredAt)) {
      await saveJourneyMetadata({db: admin.firestore(), uid: event.params.uid,
        id: eventId(name, event.id), sourcePath: event.data!.after.ref.path, data: {eventName: name, actor: 'server_stripe_sync', source: 'stripe',
          occurredAt, currentStatus: after.status,
          billingLivemode: typeof after.stripeLivemode === 'boolean' ? after.stripeLivemode : null}});
    }
  });
