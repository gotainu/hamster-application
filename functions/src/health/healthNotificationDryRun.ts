import {
  buildGoldHealthNotificationCandidate,
  GoldDomainKey,
} from './goldHealthNotification';
import {
  CautionNotificationFrequency,
  decideHealthIncidentDelivery,
  healthNotificationWeekKey,
  HealthIncidentDeliveryPolicy,
  HealthIncidentEventType,
  HealthIncidentSeverity,
  HealthIncidentState,
  isWithinQuietHours,
} from './healthIncidentDelivery';
import {buildActiveHealthIncidents} from './healthIncidentLifecycle';
import {HealthAssessment} from './healthTypes';

export interface HealthNotificationDryRunPolicy
  extends HealthIncidentDeliveryPolicy {
  enabled: boolean;
  resolvedNotificationsEnabled: boolean;
  notificationCategories: Record<GoldDomainKey, boolean>;
}

export interface HealthNotificationDryRunEvent {
  dateKey: string;
  incidentId: string;
  domain: GoldDomainKey;
  eventType: HealthIncidentEventType | null;
  severity: HealthIncidentSeverity;
  outcome: 'sent' | 'suppressed';
  reason: string;
}

export interface HealthNotificationDryRunReport {
  assessmentCount: number;
  legacyCandidateCount: number;
  notificationCount: number;
  eventCounts: Record<string, number>;
  suppressionCounts: Record<string, number>;
  events: HealthNotificationDryRunEvent[];
}

interface SimulatedIncident {
  active: boolean;
  domain: GoldDomainKey;
  conditionType: string;
  sentAt: Date | null;
  claimedAt: Date | null;
  severity: HealthIncidentSeverity | null;
  state: HealthIncidentState | null;
  score: number | null;
  reactivatedAt: Date | null;
}

export const defaultHealthNotificationDryRunPolicy:
  HealthNotificationDryRunPolicy = {
  enabled: true,
  criticalAlertsEnabled: true,
  cautionFrequency: 'state_changes_only',
  quietHoursEnabled: true,
  quietHoursStart: 21,
  quietHoursEnd: 8,
  timeZone: 'Asia/Tokyo',
  weeklyCautionLimit: 2,
  resolvedNotificationsEnabled: true,
  notificationCategories: {
    environment: true,
    activity: true,
    body: true,
    condition: true,
    nutrition: true,
  },
};

function assessmentTime(assessment: HealthAssessment): Date {
  const value = assessment.evaluatedAt as unknown;
  if (value instanceof Date) return value;
  if (value && typeof value === 'object' && 'toDate' in value) {
    const date = (value as {toDate: () => Date}).toDate();
    if (date instanceof Date && !Number.isNaN(date.getTime())) return date;
  }
  return new Date(`${assessment.dateKey}T03:00:00.000Z`);
}

function count(map: Record<string, number>, key: string): void {
  map[key] = (map[key] ?? 0) + 1;
}

function addEvent(
  report: HealthNotificationDryRunReport,
  event: HealthNotificationDryRunEvent,
): void {
  report.events.push(event);
  if (event.outcome === 'sent') {
    report.notificationCount += 1;
    count(report.eventCounts, event.eventType ?? 'unknown');
  } else {
    count(report.suppressionCounts, event.reason);
  }
}

export function replayHealthNotificationHistory(
  assessments: HealthAssessment[],
  policy: HealthNotificationDryRunPolicy =
    defaultHealthNotificationDryRunPolicy,
): HealthNotificationDryRunReport {
  const sorted = [...assessments].sort(
    (a, b) => assessmentTime(a).getTime() - assessmentTime(b).getTime(),
  );
  const report: HealthNotificationDryRunReport = {
    assessmentCount: sorted.length,
    legacyCandidateCount: 0,
    notificationCount: 0,
    eventCounts: {},
    suppressionCounts: {},
    events: [],
  };
  const incidents = new Map<string, SimulatedIncident>();
  const weeklyCautionCounts = new Map<string, number>();

  for (const assessment of sorted) {
    const now = assessmentTime(assessment);
    const active = buildActiveHealthIncidents(assessment);
    const currentIds = new Set(active.map((incident) => incident.incidentId));

    for (const [incidentId, previous] of incidents.entries()) {
      if (!previous.active || currentIds.has(incidentId)) continue;
      previous.active = false;
      if (!previous.sentAt) continue;

      if (!policy.enabled ||
        !policy.resolvedNotificationsEnabled ||
        !policy.notificationCategories[previous.domain]
      ) {
        addEvent(report, {
          dateKey: assessment.dateKey,
          incidentId,
          domain: previous.domain,
          eventType: null,
          severity: 'medium',
          outcome: 'suppressed',
          reason: 'resolvedDisabledByPreference',
        });
      } else if (policy.quietHoursEnabled && isWithinQuietHours({
        now,
        startHour: policy.quietHoursStart,
        endHour: policy.quietHoursEnd,
        timeZone: policy.timeZone,
      })) {
        addEvent(report, {
          dateKey: assessment.dateKey,
          incidentId,
          domain: previous.domain,
          eventType: null,
          severity: 'medium',
          outcome: 'suppressed',
          reason: 'resolvedDeferredByQuietHours',
        });
      } else {
        addEvent(report, {
          dateKey: assessment.dateKey,
          incidentId,
          domain: previous.domain,
          eventType: 'resolved',
          severity: 'medium',
          outcome: 'sent',
          reason: 'resolved',
        });
      }
    }

    for (const current of active) {
      const previous = incidents.get(current.incidentId);
      if (!previous) {
        incidents.set(current.incidentId, {
          active: true,
          domain: current.domain,
          conditionType: current.conditionType,
          sentAt: null,
          claimedAt: null,
          severity: null,
          state: null,
          score: null,
          reactivatedAt: null,
        });
      } else if (!previous.active) {
        previous.active = true;
        previous.reactivatedAt = now;
        previous.domain = current.domain;
        previous.conditionType = current.conditionType;
      }
    }

    const candidate = buildGoldHealthNotificationCandidate(assessment);
    if (!candidate) continue;
    report.legacyCandidateCount += 1;

    const incident = incidents.get(candidate.incidentId) ?? {
      active: true,
      domain: candidate.domainKey,
      conditionType: candidate.conditionType,
      sentAt: null,
      claimedAt: null,
      severity: null,
      state: null,
      score: null,
      reactivatedAt: null,
    };
    incidents.set(candidate.incidentId, incident);

    if (!policy.enabled || !policy.notificationCategories[candidate.domainKey]) {
      addEvent(report, {
        dateKey: assessment.dateKey,
        incidentId: candidate.incidentId,
        domain: candidate.domainKey,
        eventType: null,
        severity: candidate.severity,
        outcome: 'suppressed',
        reason: 'categoryDisabled',
      });
      continue;
    }

    const weekKey = healthNotificationWeekKey(now, policy.timeZone);
    const decision = decideHealthIncidentDelivery({
      now,
      severity: candidate.severity,
      state: candidate.overallState as HealthIncidentState,
      score: candidate.overallScore,
      previous: {
        sentAt: incident.sentAt,
        claimedAt: incident.claimedAt,
        severity: incident.severity,
        state: incident.state,
        score: incident.score,
        acknowledgedAt: null,
        snoozedUntil: null,
        reactivatedAt: incident.reactivatedAt,
        cautionNotificationsThisWeek: weeklyCautionCounts.get(weekKey) ?? 0,
      },
      policy,
    });

    if (!decision.shouldNotify || !decision.eventType) {
      addEvent(report, {
        dateKey: assessment.dateKey,
        incidentId: candidate.incidentId,
        domain: candidate.domainKey,
        eventType: null,
        severity: candidate.severity,
        outcome: 'suppressed',
        reason: decision.suppressionReason ?? 'unknown',
      });
      continue;
    }

    incident.sentAt = now;
    incident.severity = candidate.severity;
    incident.state = candidate.overallState as HealthIncidentState;
    incident.score = candidate.overallScore;
    if (candidate.severity === 'medium') {
      weeklyCautionCounts.set(
        weekKey,
        (weeklyCautionCounts.get(weekKey) ?? 0) + 1,
      );
    }
    addEvent(report, {
      dateKey: assessment.dateKey,
      incidentId: candidate.incidentId,
      domain: candidate.domainKey,
      eventType: decision.eventType,
      severity: candidate.severity,
      outcome: 'sent',
      reason: 'sent',
    });
  }

  return report;
}

export function healthNotificationDryRunPolicyFromSettings(
  data: Record<string, unknown> | null | undefined,
): HealthNotificationDryRunPolicy {
  const categories = data?.notificationCategories;
  const categoryValue = (key: GoldDomainKey): boolean => {
    if (!categories || typeof categories !== 'object') return true;
    const value = (categories as Record<string, unknown>)[key];
    return typeof value === 'boolean' ? value : true;
  };
  const frequency = data?.cautionNotificationFrequency;
  const cautionFrequency: CautionNotificationFrequency =
    frequency === 'every_three_days' || frequency === 'off'
      ? frequency
      : 'state_changes_only';

  return {
    ...defaultHealthNotificationDryRunPolicy,
    enabled:
      typeof data?.goldHealthNotificationsEnabled === 'boolean'
        ? data.goldHealthNotificationsEnabled
        : typeof data?.anomalyNotificationsEnabled === 'boolean'
          ? data.anomalyNotificationsEnabled
          : true,
    criticalAlertsEnabled:
      typeof data?.criticalAlertsEnabled === 'boolean'
        ? data.criticalAlertsEnabled
        : true,
    cautionFrequency,
    quietHoursEnabled:
      typeof data?.quietHoursEnabled === 'boolean'
        ? data.quietHoursEnabled
        : true,
    quietHoursStart:
      typeof data?.quietHoursStart === 'number' ? data.quietHoursStart : 21,
    quietHoursEnd:
      typeof data?.quietHoursEnd === 'number' ? data.quietHoursEnd : 8,
    timeZone:
      typeof data?.timeZone === 'string' && data.timeZone
        ? data.timeZone
        : 'Asia/Tokyo',
    weeklyCautionLimit: 2,
    resolvedNotificationsEnabled:
      typeof data?.resolvedNotificationsEnabled === 'boolean'
        ? data.resolvedNotificationsEnabled
        : true,
    notificationCategories: {
      environment: categoryValue('environment'),
      activity: categoryValue('activity'),
      body: categoryValue('body'),
      condition: categoryValue('condition'),
      nutrition: categoryValue('nutrition'),
    },
  };
}
