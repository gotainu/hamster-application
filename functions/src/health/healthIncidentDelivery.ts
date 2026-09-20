export type HealthIncidentSeverity = 'medium' | 'high';
export type HealthIncidentState = 'changed' | 'caution' | 'alert';
export type HealthIncidentEventType =
  | 'new'
  | 'escalated'
  | 'recurrence'
  | 'resolved'
  | 'reminder';
export type CautionNotificationFrequency =
  | 'state_changes_only'
  | 'every_three_days'
  | 'off';
export type HealthIncidentSuppressionReason =
  | 'claimInProgress'
  | 'acknowledged'
  | 'snoozed'
  | 'improving'
  | 'reminderWindow'
  | 'disabledByPreference'
  | 'quietHours'
  | 'weeklyLimit';

export interface HealthIncidentDeliverySnapshot {
  sentAt: Date | null;
  claimedAt: Date | null;
  severity: HealthIncidentSeverity | null;
  state: HealthIncidentState | null;
  score: number | null;
  acknowledgedAt: Date | null;
  snoozedUntil: Date | null;
  reactivatedAt: Date | null;
  cautionNotificationsThisWeek: number;
}

export interface HealthIncidentDeliveryPolicy {
  criticalAlertsEnabled: boolean;
  cautionFrequency: CautionNotificationFrequency;
  quietHoursEnabled: boolean;
  quietHoursStart: number;
  quietHoursEnd: number;
  timeZone: string;
  weeklyCautionLimit: number;
}

export interface HealthIncidentDeliveryDecision {
  shouldNotify: boolean;
  eventType: HealthIncidentEventType | null;
  suppressionReason: HealthIncidentSuppressionReason | null;
}

const CLAIM_MINUTES = 10;
const CAUTION_REMINDER_HOURS = 72;
const ALERT_REMINDER_HOURS = 12;
const MEANINGFUL_SCORE_IMPROVEMENT = 5;

const CONDITION_ALIASES: Record<string, string> = {
  humidityHigh: 'humidity_high',
  humidityHighRecentWindow: 'humidity_high',
  humidityLow: 'humidity_low',
  humidityLowRecentWindow: 'humidity_low',
  humiditySpike: 'humidity_spike',
  temperatureHigh: 'temperature_high',
  temperatureHighRecentWindow: 'temperature_high',
  dangerMinutesDetected: 'temperature_high',
  temperatureLow: 'temperature_low',
  temperatureLowRecentWindow: 'temperature_low',
  temperatureSpike: 'temperature_spike',
  activityLow: 'activity_drop',
  activityDrop: 'activity_drop',
  activityHigh: 'activity_high',
  conditionSlightlyConcerned: 'concerning_checkin',
  conditionVeryConcerned: 'concerning_checkin',
};

function sanitizeCondition(value: string): string {
  return value
    .trim()
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/[^A-Za-z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase()
    .slice(0, 80) || 'health_state';
}

export function normalizeHealthIncidentCondition(
  domain: string,
  flag: string,
): string {
  const alias = CONDITION_ALIASES[flag];
  if (alias) return alias;

  if (flag.startsWith('weightDecrease')) return 'weight_drop';
  if (flag.startsWith('weightIncrease')) return 'weight_increase';
  if (flag.startsWith('condition_')) return 'concerning_checkin';

  return sanitizeCondition(flag || `${domain}_state`);
}

export function buildHealthIncidentId(
  domain: string,
  conditionType: string,
): string {
  return `${sanitizeCondition(domain)}:${sanitizeCondition(conditionType)}`;
}

export function healthIncidentDocumentId(incidentId: string): string {
  return incidentId.replace(/[^A-Za-z0-9_-]+/g, '__').slice(0, 180);
}

function stateRank(state: HealthIncidentState | null): number {
  switch (state) {
    case 'alert':
      return 3;
    case 'caution':
      return 2;
    case 'changed':
      return 1;
    default:
      return 0;
  }
}

function elapsedHours(now: Date, previous: Date): number {
  return (now.getTime() - previous.getTime()) / (60 * 60 * 1000);
}

export function isWithinQuietHours(params: {
  now: Date;
  startHour: number;
  endHour: number;
  timeZone: string;
}): boolean {
  if (params.startHour === params.endHour) return false;

  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: params.timeZone,
    hour: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(params.now);
  const hour = Number(parts.find((part) => part.type === 'hour')?.value);
  if (!Number.isFinite(hour)) return false;

  if (params.startHour < params.endHour) {
    return hour >= params.startHour && hour < params.endHour;
  }
  return hour >= params.startHour || hour < params.endHour;
}

export function healthNotificationWeekKey(
  now: Date,
  timeZone: string,
): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const year = Number(parts.find((part) => part.type === 'year')?.value);
  const month = Number(parts.find((part) => part.type === 'month')?.value);
  const day = Number(parts.find((part) => part.type === 'day')?.value);

  if (![year, month, day].every(Number.isFinite)) {
    return `week_${now.toISOString().slice(0, 10)}`;
  }

  const localCalendarDate = new Date(Date.UTC(year, month - 1, day));
  const daysSinceMonday = (localCalendarDate.getUTCDay() + 6) % 7;
  localCalendarDate.setUTCDate(localCalendarDate.getUTCDate() - daysSinceMonday);
  return `week_${localCalendarDate.toISOString().slice(0, 10)}`;
}

export function decideHealthIncidentDelivery(params: {
  now: Date;
  severity: HealthIncidentSeverity;
  state: HealthIncidentState;
  score: number | null;
  previous: HealthIncidentDeliverySnapshot;
  policy: HealthIncidentDeliveryPolicy;
}): HealthIncidentDeliveryDecision {
  const {now, previous, policy} = params;

  if (
    previous.claimedAt &&
    elapsedHours(now, previous.claimedAt) < CLAIM_MINUTES / 60
  ) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'claimInProgress',
    };
  }

  const severityEscalated =
    params.severity === 'high' && previous.severity !== 'high';
  const stateEscalated = stateRank(params.state) > stateRank(previous.state);
  const recurred = Boolean(
    previous.sentAt &&
      previous.reactivatedAt &&
      previous.reactivatedAt.getTime() > previous.sentAt.getTime(),
  );

  let eventType: HealthIncidentEventType | null = null;
  if (!previous.sentAt) {
    eventType = 'new';
  } else if (severityEscalated || stateEscalated) {
    eventType = 'escalated';
  } else if (recurred) {
    eventType = 'recurrence';
  }

  if (params.severity === 'high' && !policy.criticalAlertsEnabled) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'disabledByPreference',
    };
  }

  if (
    params.severity === 'medium' &&
    policy.cautionFrequency === 'off'
  ) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'disabledByPreference',
    };
  }

  if (!eventType &&
    previous.acknowledgedAt &&
    previous.acknowledgedAt.getTime() >= previous.sentAt!.getTime()
  ) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'acknowledged',
    };
  }

  if (
    !eventType &&
    previous.snoozedUntil &&
    previous.snoozedUntil.getTime() > now.getTime()
  ) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'snoozed',
    };
  }

  const stateImproved = stateRank(params.state) < stateRank(previous.state);
  const scoreImproved =
    params.score != null &&
    previous.score != null &&
    params.score - previous.score >= MEANINGFUL_SCORE_IMPROVEMENT;

  if (!eventType && (stateImproved || scoreImproved)) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'improving',
    };
  }

  if (!eventType) {
    if (
      params.severity === 'medium' &&
      policy.cautionFrequency === 'state_changes_only'
    ) {
      return {
        shouldNotify: false,
        eventType: null,
        suppressionReason: 'disabledByPreference',
      };
    }

    const reminderHours =
      params.severity === 'high'
        ? ALERT_REMINDER_HOURS
        : CAUTION_REMINDER_HOURS;

    if (elapsedHours(now, previous.sentAt!) < reminderHours) {
      return {
        shouldNotify: false,
        eventType: null,
        suppressionReason: 'reminderWindow',
      };
    }
    eventType = 'reminder';
  }

  if (
    params.severity === 'medium' &&
    previous.cautionNotificationsThisWeek >= policy.weeklyCautionLimit
  ) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'weeklyLimit',
    };
  }

  if (
    params.severity === 'medium' &&
    policy.quietHoursEnabled &&
    isWithinQuietHours({
      now,
      startHour: policy.quietHoursStart,
      endHour: policy.quietHoursEnd,
      timeZone: policy.timeZone,
    })
  ) {
    return {
      shouldNotify: false,
      eventType: null,
      suppressionReason: 'quietHours',
    };
  }

  return {
    shouldNotify: true,
    eventType,
    suppressionReason: null,
  };
}
