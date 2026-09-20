import * as admin from 'firebase-admin';

import {
  HealthAssessment,
  HealthAssessmentState,
  HealthDomainAssessment,
} from './healthTypes';
import {
  buildHealthIncidentId,
  healthIncidentDocumentId,
  HealthIncidentSeverity,
  HealthIncidentState,
  normalizeHealthIncidentCondition,
} from './healthIncidentDelivery';

const IGNORED_FLAGS = new Set([
  'environmentMissing',
  'activityMissing',
  'activityComparisonMissing',
  'conditionMissing',
  'conditionUnknown',
  'weightMissing',
  'weightComparisonMissing',
  'weightStale',
  'nutritionMissing',
]);

type HealthDomainKey = keyof HealthAssessment['domains'];

export interface ActiveHealthIncident {
  incidentId: string;
  documentId: string;
  domain: HealthDomainKey;
  conditionType: string;
  severity: HealthIncidentSeverity;
  state: HealthIncidentState;
  score: number | null;
  assessmentDateKey: string;
}

function isIncidentState(
  state: HealthAssessmentState,
): state is HealthIncidentState {
  return state === 'changed' || state === 'caution' || state === 'alert';
}

function flagsForDomain(domain: HealthDomainAssessment): string[] {
  const flags = [
    ...domain.flags,
    ...Object.values(domain.components ?? {}).flatMap(
      (component) => component.flags,
    ),
  ].filter((flag) => !IGNORED_FLAGS.has(flag));
  return [...new Set(flags)];
}

export function buildActiveHealthIncidents(
  assessment: HealthAssessment,
): ActiveHealthIncident[] {
  if (assessment.overall.confidence === 'insufficient') return [];

  const incidents = new Map<string, ActiveHealthIncident>();
  const entries = Object.entries(assessment.domains) as Array<
    [HealthDomainKey, HealthDomainAssessment]
  >;

  for (const [domainKey, domain] of entries) {
    if (!isIncidentState(domain.state)) continue;

    const rawFlags = flagsForDomain(domain);
    const flags = rawFlags.length > 0
      ? rawFlags
      : [`${domainKey}_${domain.state}`];

    for (const flag of flags) {
      const conditionType = normalizeHealthIncidentCondition(domainKey, flag);
      const incidentId = buildHealthIncidentId(domainKey, conditionType);
      incidents.set(incidentId, {
        incidentId,
        documentId: healthIncidentDocumentId(incidentId),
        domain: domainKey,
        conditionType,
        severity: domain.state === 'alert' ? 'high' : 'medium',
        state: domain.state,
        score: domain.score,
        assessmentDateKey: assessment.dateKey,
      });
    }
  }

  return [...incidents.values()];
}

function isStateChanged(params: {
  previous: FirebaseFirestore.DocumentData;
  incident: ActiveHealthIncident;
}): boolean {
  const previousScore = params.previous.currentScore;
  const scoreChangedMeaningfully =
    typeof previousScore === 'number' &&
    params.incident.score != null &&
    Math.abs(previousScore - params.incident.score) >= 5;

  return params.previous.status !== 'active' ||
    params.previous.currentSeverity !== params.incident.severity ||
    params.previous.currentState !== params.incident.state ||
    scoreChangedMeaningfully;
}

export async function syncHealthIncidentLifecycle(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  assessment: HealthAssessment;
  now: Date;
}): Promise<void> {
  const collection = params.db
    .collection('users')
    .doc(params.uid)
    .collection('health_incidents');
  const incidents = buildActiveHealthIncidents(params.assessment);
  const refs = incidents.map((incident) => collection.doc(incident.documentId));
  const nowTimestamp = admin.firestore.Timestamp.fromDate(params.now);

  await params.db.runTransaction(async (transaction) => {
    const activeSnapshot = await transaction.get(
      collection.where('status', '==', 'active'),
    );
    const currentSnapshots = refs.length > 0
      ? await transaction.getAll(...refs)
      : [];
    const currentIds = new Set(incidents.map((incident) => incident.documentId));

    incidents.forEach((incident, index) => {
      const snap = currentSnapshots[index];
      const previous = snap?.data() ?? {};
      const isNew = !snap?.exists;
      const isRecurrence = previous.status === 'resolved';
      const changed = isStateChanged({previous, incident});
      const occurrenceCount = typeof previous.occurrenceCount === 'number'
        ? previous.occurrenceCount + (isRecurrence ? 1 : 0)
        : 1;
      const stateVersion = typeof previous.stateVersion === 'number'
        ? previous.stateVersion + (changed ? 1 : 0)
        : 1;

      transaction.set(
        refs[index],
        {
          incidentId: incident.incidentId,
          domain: incident.domain,
          conditionType: incident.conditionType,
          status: 'active',
          currentSeverity: incident.severity,
          currentState: incident.state,
          currentScore: incident.score,
          assessmentDateKey: incident.assessmentDateKey,
          occurrenceCount,
          stateVersion,
          firstDetectedAt: previous.firstDetectedAt ?? nowTimestamp,
          lastDetectedAt: nowTimestamp,
          lastEvaluatedAt: nowTimestamp,
          lastMeaningfulChangeAt:
            changed ? nowTimestamp : previous.lastMeaningfulChangeAt ?? nowTimestamp,
          reactivatedAt:
            isRecurrence ? nowTimestamp : previous.reactivatedAt ?? null,
          resolvedAt: admin.firestore.FieldValue.delete(),
          resolvedNotificationStatus: admin.firestore.FieldValue.delete(),
          resolvedNotificationClaimedAt: admin.firestore.FieldValue.delete(),
          resolvedNotificationSentAt: admin.firestore.FieldValue.delete(),
          resolvedNotificationReason: admin.firestore.FieldValue.delete(),
          createdAt: previous.createdAt ?? nowTimestamp,
          updatedAt: nowTimestamp,
        },
        {merge: true},
      );
    });

    for (const activeDoc of activeSnapshot.docs) {
      if (currentIds.has(activeDoc.id)) continue;
      const previous = activeDoc.data() ?? {};
      const stateVersion = typeof previous.stateVersion === 'number'
        ? previous.stateVersion + 1
        : 1;
      const shouldNotifyResolution = previous.lastNotifiedAt != null;
      transaction.set(
        activeDoc.ref,
        {
          status: 'resolved',
          resolvedAt: nowTimestamp,
          lastEvaluatedAt: nowTimestamp,
          lastMeaningfulChangeAt: nowTimestamp,
          stateVersion,
          resolvedNotificationStatus:
            shouldNotifyResolution ? 'pending' : 'not_applicable',
          resolvedNotificationReason: shouldNotifyResolution
            ? admin.firestore.FieldValue.delete()
            : 'noPreviousNotification',
          updatedAt: nowTimestamp,
        },
        {merge: true},
      );
    }
  });
}
