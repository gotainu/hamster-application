import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

import {
  HealthAssessment,
  HealthAssessmentState,
  HealthDomainAssessment,
} from './healthTypes';
import {
  buildHealthIncidentId,
  CautionNotificationFrequency,
  decideHealthIncidentDelivery,
  healthIncidentDocumentId,
  healthNotificationWeekKey,
  HealthIncidentEventType,
  HealthIncidentDeliveryPolicy,
  HealthIncidentState,
  isWithinQuietHours,
  normalizeHealthIncidentCondition,
} from './healthIncidentDelivery';

const MAX_BODY_LENGTH = 190;
const MAX_RESOLVED_NOTIFICATIONS_PER_RUN = 1;

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

type GoldNotificationSeverity = 'medium' | 'high';
export type GoldDomainKey =
  | 'environment'
  | 'activity'
  | 'body'
  | 'condition'
  | 'nutrition';

type GoldNotificationReason =
  | 'manualRebuild'
  | 'notCurrentAssessment'
  | 'noCandidate'
  | 'notPaid'
  | 'userDisabled'
  | 'alreadySentRecently'
  | 'acknowledged'
  | 'snoozed'
  | 'quietHours'
  | 'weeklyLimit'
  | 'improving'
  | 'noTokens'
  | 'sendFailed'
  | 'sent';

export interface GoldHealthNotificationCandidate {
  dateKey: string;
  domainKey: GoldDomainKey;
  primaryFlag: string;
  conditionType: string;
  incidentId: string;
  overallState: HealthAssessmentState;
  overallScore: number | null;
  severity: GoldNotificationSeverity;
  title: string;
  body: string;
  primaryFactor: string;
  recommendedAction: string | null;
  notificationKey: string;
  fingerprint: string;
}

export interface GoldHealthNotificationExecutionResult {
  uid: string;
  reason: GoldNotificationReason;
  candidate: GoldHealthNotificationCandidate | null;
  notificationKey: string | null;
  tokenCount: number;
  sentCount: number;
  failedCount: number;
  noTokens: boolean;
}

function asDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function stateRank(state: HealthAssessmentState): number {
  switch (state) {
    case 'alert':
      return 6;
    case 'caution':
      return 5;
    case 'changed':
      return 4;
    case 'stable':
      return 3;
    case 'good':
      return 2;
    case 'unknown':
      return 1;
    case 'insufficientData':
      return 0;
  }
}

function isNotifiableState(state: HealthAssessmentState): boolean {
  return state === 'alert' || state === 'caution' || state === 'changed';
}

function severityForState(
  state: HealthAssessmentState,
): GoldNotificationSeverity | null {
  if (state === 'alert') return 'high';
  if (state === 'caution' || state === 'changed') return 'medium';
  return null;
}

function domainFromPrimaryFactor(
  primaryFactor: string | null,
): GoldDomainKey | null {
  const value = primaryFactor?.trim() ?? '';
  if (value.startsWith('環境:')) return 'environment';
  if (value.startsWith('活動量:')) return 'activity';
  if (value.startsWith('体重:')) return 'body';
  if (value.startsWith('今日の様子:')) return 'condition';
  if (value.startsWith('給餌:')) return 'nutrition';
  return null;
}

function selectPrimaryDomain(params: {
  assessment: HealthAssessment;
}): {
  key: GoldDomainKey;
  domain: HealthDomainAssessment;
} | null {
  const explicitKey = domainFromPrimaryFactor(
    params.assessment.overall.primaryFactor,
  );
  if (explicitKey) {
    return {
      key: explicitKey,
      domain: params.assessment.domains[explicitKey],
    };
  }

  const entries = Object.entries(params.assessment.domains) as Array<
    [GoldDomainKey, HealthDomainAssessment]
  >;

  const eligible = entries
    .filter(([, domain]) => isNotifiableState(domain.state))
    .sort((a, b) => stateRank(b[1].state) - stateRank(a[1].state));

  return eligible[0]
    ? {key: eligible[0][0], domain: eligible[0][1]}
    : null;
}

function selectPrimaryFlag(params: {
  domainKey: GoldDomainKey;
  domain: HealthDomainAssessment;
}): string {
  if (params.domainKey === 'environment') {
    const factor = params.domain.summary;
    const componentKey = factor.includes('湿度')
      ? 'humidity'
      : factor.includes('温度')
        ? 'temperature'
        : null;
    const componentFlag = componentKey
      ? params.domain.components?.[componentKey]?.flags.find(
          (flag) => !IGNORED_FLAGS.has(flag),
        )
      : null;
    if (componentFlag) return componentFlag;
  }

  const direct = params.domain.flags.find(
    (flag) => !IGNORED_FLAGS.has(flag),
  );
  if (direct) return direct;

  const componentFlag = Object.values(
    params.domain.components ?? {},
  )
    .flatMap((component) => component.flags)
    .find((flag) => !IGNORED_FLAGS.has(flag));

  return componentFlag ?? `${params.domainKey}_${params.domain.state}`;
}

function stripPrimaryFactorPrefix(value: string): string {
  return value.replace(
    /^(環境|活動量|体重|今日の様子|給餌)\s*:\s*/,
    '',
  );
}

function truncate(value: string, maxLength: number): string {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, Math.max(0, maxLength - 1))}…`;
}

function titleForCondition(params: {
  conditionType: string;
  severity: GoldNotificationSeverity;
  eventType?: HealthIncidentEventType;
}): string {
  const reminder = params.eventType === 'reminder';
  const recurrence = params.eventType === 'recurrence';
  const alert = params.severity === 'high';

  if (recurrence) {
    return alert
      ? '注意が必要な状態が再び検出されました'
      : '気になる変化が再び見つかりました';
  }

  switch (params.conditionType) {
    case 'humidity_high':
      if (reminder) return '湿度の注意状態が続いています';
      return alert
        ? 'ケージの湿度が警戒範囲に入りました'
        : 'ケージの湿度が高めの日が続いています';
    case 'humidity_low':
      if (reminder) return '湿度が低い状態が続いています';
      return alert
        ? 'ケージの湿度が警戒範囲まで下がりました'
        : 'ケージの湿度が低めの日が続いています';
    case 'temperature_high':
      if (reminder) return '温度の注意状態が続いています';
      return alert
        ? 'ケージ温度が警戒範囲に入りました'
        : 'ケージ温度が高めです';
    case 'temperature_low':
      if (reminder) return '温度が低い状態が続いています';
      return alert
        ? 'ケージ温度が警戒範囲まで下がりました'
        : 'ケージ温度が低めです';
    case 'activity_drop':
      return reminder
        ? '活動量が少ない状態が続いています'
        : '前日の活動量が少なめです';
    case 'activity_high':
      return reminder
        ? '活動量が多い状態が続いています'
        : '前日の活動量が多めです';
    case 'weight_drop':
      return reminder ? '体重減少が続いています' : '体重に減少傾向があります';
    case 'weight_increase':
      return reminder ? '体重増加が続いています' : '体重に増加傾向があります';
    case 'concerning_checkin':
      return alert
        ? '今日の様子に強い心配が記録されました'
        : '今日の様子に気になる記録があります';
    default:
      return alert
        ? '確認が必要な変化があります'
        : 'いつもと違う変化があります';
  }
}

function bodyForCondition(params: {
  candidate: GoldHealthNotificationCandidate;
  eventType?: HealthIncidentEventType;
}): string {
  const {candidate} = params;
  const lead = params.eventType === 'reminder'
    ? 'まだ改善が確認できていません。'
    : params.eventType === 'escalated'
      ? '状態が悪化しています。'
      : params.eventType === 'recurrence'
        ? 'いったん落ち着いた状態から、再び変化が見つかりました。'
      : '傾向に変化があります。';

  const conditionAction: Record<string, string> = {
    humidity_high: '今日は換気と濡れた床材がないか確認しましょう。',
    humidity_low: '加湿方法とケージ周辺の乾燥状態を確認しましょう。',
    temperature_high: '早めに空調とケージの設置場所を確認してください。',
    temperature_low: '暖房とケージ周辺の冷気を確認してください。',
  };
  const action = conditionAction[candidate.conditionType]
    ?? candidate.recommendedAction
    ?? 'アプリで詳しい変化を確認してください。';

  return truncate(`${lead}${action}`, MAX_BODY_LENGTH);
}

export function buildGoldHealthNotificationCandidate(
  assessment: HealthAssessment,
): GoldHealthNotificationCandidate | null {
  const state = assessment.overall.observedState;
  const severity = severityForState(state);

  if (!severity || !isNotifiableState(state)) return null;
  if (assessment.overall.confidence === 'insufficient') return null;

  const selected = selectPrimaryDomain({assessment});
  if (!selected) return null;

  const primaryFlag = selectPrimaryFlag({
    domainKey: selected.key,
    domain: selected.domain,
  });

  const rawPrimaryFactor =
    assessment.overall.primaryFactor?.trim() ||
    selected.domain.summary.trim() ||
    assessment.overall.summary.trim();
  const primaryFactor = stripPrimaryFactorPrefix(rawPrimaryFactor);

  const recommendedAction =
    selected.domain.recommendedActions[0] ??
    assessment.overall.recommendedActions[0] ??
    null;

  const conditionType = normalizeHealthIncidentCondition(
    selected.key,
    primaryFlag,
  );
  const incidentId = buildHealthIncidentId(selected.key, conditionType);
  const notificationKey = `health_incident__${incidentId.replace(':', '__')}`;

  const fingerprint = [
    assessment.dateKey,
    state,
    String(assessment.overall.observedScore ?? 'null'),
    incidentId,
    truncate(primaryFactor, 100),
  ].join('__');

  const candidate: GoldHealthNotificationCandidate = {
    dateKey: assessment.dateKey,
    domainKey: selected.key,
    primaryFlag,
    conditionType,
    incidentId,
    overallState: state,
    overallScore: assessment.overall.observedScore,
    severity,
    title: '',
    body: '',
    primaryFactor,
    recommendedAction,
    notificationKey,
    fingerprint,
  };

  candidate.title = titleForCondition({conditionType, severity});
  candidate.body = bodyForCondition({candidate});
  return candidate;
}

async function fetchPaidFeatureEntitlement(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<{
  isEntitled: boolean;
  plan: string | null;
  status: string | null;
}> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('billing')
    .doc('subscription')
    .get();

  const data = snap.data() ?? {};
  const plan = typeof data.plan === 'string' ? data.plan : null;
  const status = typeof data.status === 'string' ? data.status : null;

  return {
    isEntitled:
      plan === 'paid' && (status === 'active' || status === 'trialing'),
    plan,
    status,
  };
}

interface NotificationPreferences extends HealthIncidentDeliveryPolicy {
  enabled: boolean;
  resolvedNotificationsEnabled: boolean;
  notificationCategories: Record<GoldDomainKey, boolean>;
}

const DEFAULT_NOTIFICATION_CATEGORIES: Record<GoldDomainKey, boolean> = {
  environment: true,
  activity: true,
  body: true,
  condition: true,
  nutrition: true,
};

function asHour(value: unknown, fallback: number): number {
  return typeof value === 'number' && value >= 0 && value <= 23
    ? Math.floor(value)
    : fallback;
}

async function fetchNotificationPreferences(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<NotificationPreferences> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('settings')
    .doc('notifications')
    .get();

  if (!snap.exists) {
    return {
      enabled: true,
      criticalAlertsEnabled: true,
      cautionFrequency: 'state_changes_only',
      quietHoursEnabled: true,
      quietHoursStart: 21,
      quietHoursEnd: 8,
      timeZone: 'Asia/Tokyo',
      weeklyCautionLimit: 2,
      resolvedNotificationsEnabled: true,
      notificationCategories: {...DEFAULT_NOTIFICATION_CATEGORIES},
    };
  }
  const data = snap.data() ?? {};
  const enabled = typeof data.goldHealthNotificationsEnabled === 'boolean'
    ? data.goldHealthNotificationsEnabled
    : typeof data.anomalyNotificationsEnabled === 'boolean'
      ? data.anomalyNotificationsEnabled
      : true;
  const frequencyValue = data.cautionNotificationFrequency;
  const cautionFrequency: CautionNotificationFrequency =
    frequencyValue === 'every_three_days' || frequencyValue === 'off'
      ? frequencyValue
      : 'state_changes_only';
  const categoryData = data.notificationCategories;
  const notificationCategories = Object.fromEntries(
    Object.keys(DEFAULT_NOTIFICATION_CATEGORIES).map((domain) => {
      const value = categoryData && typeof categoryData === 'object'
        ? (categoryData as Record<string, unknown>)[domain]
        : null;
      return [domain, typeof value === 'boolean' ? value : true];
    }),
  ) as Record<GoldDomainKey, boolean>;

  return {
    enabled,
    criticalAlertsEnabled:
      typeof data.criticalAlertsEnabled === 'boolean'
        ? data.criticalAlertsEnabled
        : true,
    cautionFrequency,
    quietHoursEnabled:
      typeof data.quietHoursEnabled === 'boolean'
        ? data.quietHoursEnabled
        : true,
    quietHoursStart: asHour(data.quietHoursStart, 21),
    quietHoursEnd: asHour(data.quietHoursEnd, 8),
    timeZone: typeof data.timeZone === 'string' && data.timeZone.trim()
      ? data.timeZone.trim()
      : 'Asia/Tokyo',
    weeklyCautionLimit: 2,
    resolvedNotificationsEnabled:
      typeof data.resolvedNotificationsEnabled === 'boolean'
        ? data.resolvedNotificationsEnabled
        : true,
    notificationCategories,
  };
}

async function fetchEnabledFcmTokens(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<string[]> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('notification_tokens')
    .where('enabled', '==', true)
    .get();

  const tokens = new Set<string>();
  for (const doc of snap.docs) {
    const data = doc.data() ?? {};
    const token =
      typeof data.token === 'string' && data.token.trim()
        ? data.token.trim()
        : doc.id !== '__placeholder__'
          ? doc.id
          : null;
    if (token) tokens.add(token);
  }
  return [...tokens];
}

async function disableInvalidTokens(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  invalidTokens: string[];
}): Promise<void> {
  if (params.invalidTokens.length === 0) return;

  const batch = params.db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const token of params.invalidTokens) {
    const ref = params.db
      .collection('users')
      .doc(params.uid)
      .collection('notification_tokens')
      .doc(token);

    batch.set(
      ref,
      {
        enabled: false,
        invalidatedAt: now,
        updatedAt: now,
      },
      {merge: true},
    );
  }

  await batch.commit();
}

function logRef(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  notificationKey: string;
}) {
  return params.db
    .collection('users')
    .doc(params.uid)
    .collection('anomaly_notification_logs')
    .doc(params.notificationKey);
}

async function claimNotification(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  candidate: GoldHealthNotificationCandidate;
  now: Date;
  triggerReason: string;
  preferences: NotificationPreferences;
}): Promise<{
  claimed: boolean;
  eventType: HealthIncidentEventType | null;
  reason: GoldNotificationReason;
  weeklyCounterKey: string | null;
}> {
  const ref = logRef({
    db: params.db,
    uid: params.uid,
    notificationKey: params.candidate.notificationKey,
  });
  const incidentDocumentId = healthIncidentDocumentId(
    params.candidate.incidentId,
  );
  const userRef = params.db.collection('users').doc(params.uid);
  const actionRef = userRef
    .collection('health_incident_actions')
    .doc(incidentDocumentId);
  const incidentRef = userRef
    .collection('health_incidents')
    .doc(incidentDocumentId);
  const weeklyCounterKey = healthNotificationWeekKey(
    params.now,
    params.preferences.timeZone,
  );
  const weeklyCounterRef = userRef
    .collection('notification_delivery_counters')
    .doc(weeklyCounterKey);

  return params.db.runTransaction(async (transaction) => {
    const [snap, actionSnap, incidentSnap, weeklyCounterSnap] =
      await transaction.getAll(
        ref,
        actionRef,
        incidentRef,
        weeklyCounterRef,
      );
    const data = snap.data() ?? {};
    const actionData = actionSnap.data() ?? {};
    const incidentData = incidentSnap.data() ?? {};
    const weeklyCounterData = weeklyCounterSnap.data() ?? {};
    const cautionNotificationsThisWeek =
      typeof weeklyCounterData.cautionClaimCount === 'number'
        ? weeklyCounterData.cautionClaimCount
        : 0;
    const sentAt = asDate(data.sentAt);
    const claimedAt = asDate(data.claimedAt);

    const previousStateValue = data.lastNotifiedState ?? data.overallState;
    const previousState =
      previousStateValue === 'changed' ||
      previousStateValue === 'caution' ||
      previousStateValue === 'alert'
        ? previousStateValue
        : null;
    const previousSeverityValue = data.lastNotifiedSeverity ?? data.severity;
    const previousSeverity =
      previousSeverityValue === 'medium' || previousSeverityValue === 'high'
        ? previousSeverityValue
        : null;
    const previousScoreValue = data.lastNotifiedScore ?? data.overallScore;
    const previousScore = typeof previousScoreValue === 'number'
      ? previousScoreValue
      : null;
    const acknowledgedAt = asDate(
      actionData.acknowledgedAt ?? data.lastAcknowledgedAt,
    );
    const snoozedUntil = asDate(actionData.snoozedUntil);
    const reactivatedAt = asDate(incidentData.reactivatedAt);
    const hasCurrentWeekReservation =
      params.candidate.severity === 'medium' &&
      claimedAt != null &&
      data.weeklyCounterKey === weeklyCounterKey &&
      (sentAt == null || claimedAt.getTime() > sentAt.getTime());
    const currentWeekReservationIsStale =
      hasCurrentWeekReservation &&
      claimedAt != null &&
      params.now.getTime() - claimedAt.getTime() >= 10 * 60 * 1000;

    const decision = decideHealthIncidentDelivery({
      now: params.now,
      severity: params.candidate.severity,
      state: params.candidate.overallState as HealthIncidentState,
      score: params.candidate.overallScore,
      previous: {
        sentAt,
        claimedAt,
        severity: previousSeverity,
        state: previousState,
        score: previousScore,
        acknowledgedAt,
        snoozedUntil,
        reactivatedAt,
        cautionNotificationsThisWeek: Math.max(
          0,
          cautionNotificationsThisWeek - (hasCurrentWeekReservation ? 1 : 0),
        ),
      },
      policy: params.preferences,
    });

    if (!decision.shouldNotify || !decision.eventType) {
      let reason: GoldNotificationReason = 'alreadySentRecently';
      switch (decision.suppressionReason) {
        case 'acknowledged':
          reason = 'acknowledged';
          break;
        case 'snoozed':
          reason = 'snoozed';
          break;
        case 'quietHours':
          reason = 'quietHours';
          break;
        case 'weeklyLimit':
          reason = 'weeklyLimit';
          break;
        case 'improving':
          reason = 'improving';
          break;
        case 'disabledByPreference':
          reason = 'userDisabled';
          break;
        default:
          break;
      }
      transaction.set(
        ref,
        {
          fingerprint: params.candidate.fingerprint,
          anomalyFlag: params.candidate.primaryFlag,
          incidentId: params.candidate.incidentId,
          conditionType: params.candidate.conditionType,
          severity: params.candidate.severity,
          overallState: params.candidate.overallState,
          overallScore: params.candidate.overallScore,
          assessmentDateKey: params.candidate.dateKey,
          endDateKey: params.candidate.dateKey,
          triggerReason: params.triggerReason,
          updatedAt: admin.firestore.Timestamp.fromDate(params.now),
          lastEvaluatedAt: admin.firestore.Timestamp.fromDate(params.now),
          lastDecisionReason: reason,
          suppressionReason: decision.suppressionReason,
          ...(currentWeekReservationIsStale
            ? {
                claimedAt: admin.firestore.FieldValue.delete(),
                weeklyCounterKey: admin.firestore.FieldValue.delete(),
              }
            : {}),
        },
        {merge: true},
      );
      if (currentWeekReservationIsStale) {
        transaction.set(
          weeklyCounterRef,
          {
            weekKey: weeklyCounterKey,
            cautionClaimCount: Math.max(
              0,
              cautionNotificationsThisWeek - 1,
            ),
            lastReleasedAt: admin.firestore.Timestamp.fromDate(params.now),
            updatedAt: admin.firestore.Timestamp.fromDate(params.now),
          },
          {merge: true},
        );
      }
      return {
        claimed: false,
        eventType: null,
        reason,
        weeklyCounterKey: null,
      };
    }

    transaction.set(
      ref,
      {
        notificationKey: params.candidate.notificationKey,
        fingerprint: params.candidate.fingerprint,
        anomalyFlag: params.candidate.primaryFlag,
        incidentId: params.candidate.incidentId,
        conditionType: params.candidate.conditionType,
        severity: params.candidate.severity,
        title: params.candidate.title,
        body: params.candidate.body,
        startDateKey: params.candidate.dateKey,
        endDateKey: params.candidate.dateKey,
        assessmentDateKey: params.candidate.dateKey,
        overallState: params.candidate.overallState,
        overallScore: params.candidate.overallScore,
        primaryFactor: params.candidate.primaryFactor,
        notificationSource: 'health_assessments/latest',
        triggerReason: params.triggerReason,
        eventType: decision.eventType,
        claimedAt: admin.firestore.Timestamp.fromDate(params.now),
        createdAt:
          data.createdAt ?? admin.firestore.Timestamp.fromDate(params.now),
        updatedAt: admin.firestore.Timestamp.fromDate(params.now),
        lastDecisionReason: 'claimed',
        suppressionReason: admin.firestore.FieldValue.delete(),
        weeklyCounterKey: params.candidate.severity === 'medium'
          ? weeklyCounterKey
          : admin.firestore.FieldValue.delete(),
      },
      {merge: true},
    );

    if (
      params.candidate.severity === 'medium' &&
      !hasCurrentWeekReservation
    ) {
      transaction.set(
        weeklyCounterRef,
        {
          weekKey: weeklyCounterKey,
          cautionClaimCount: cautionNotificationsThisWeek + 1,
          lastClaimedAt: admin.firestore.Timestamp.fromDate(params.now),
          updatedAt: admin.firestore.Timestamp.fromDate(params.now),
        },
        {merge: true},
      );
    }

    return {
      claimed: true,
      eventType: decision.eventType,
      reason: 'sent',
      weeklyCounterKey:
        params.candidate.severity === 'medium' ? weeklyCounterKey : null,
    };
  });
}

async function releaseWeeklyNotificationClaim(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  weeklyCounterKey: string | null;
  now: Date;
}): Promise<void> {
  if (!params.weeklyCounterKey) return;

  const ref = params.db
    .collection('users')
    .doc(params.uid)
    .collection('notification_delivery_counters')
    .doc(params.weeklyCounterKey);

  await params.db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const current = snap.data()?.cautionClaimCount;
    transaction.set(
      ref,
      {
        weekKey: params.weeklyCounterKey,
        cautionClaimCount: Math.max(
          0,
          typeof current === 'number' ? current - 1 : 0,
        ),
        lastReleasedAt: admin.firestore.Timestamp.fromDate(params.now),
        updatedAt: admin.firestore.Timestamp.fromDate(params.now),
      },
      {merge: true},
    );
  });
}

async function saveDecision(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  candidate: GoldHealthNotificationCandidate;
  now: Date;
  reason: GoldNotificationReason;
  triggerReason: string;
  sentAt?: Date | null;
  tokenCount?: number;
  sentCount?: number;
  failedCount?: number;
  invalidTokenCount?: number;
  noTokens?: boolean;
  releaseClaim?: boolean;
  eventType?: HealthIncidentEventType | null;
  title?: string;
  body?: string;
}): Promise<void> {
  const ref = logRef({
    db: params.db,
    uid: params.uid,
    notificationKey: params.candidate.notificationKey,
  });

  const payload: Record<string, unknown> = {
    notificationKey: params.candidate.notificationKey,
    fingerprint: params.candidate.fingerprint,
    anomalyFlag: params.candidate.primaryFlag,
    incidentId: params.candidate.incidentId,
    conditionType: params.candidate.conditionType,
    severity: params.candidate.severity,
    title: params.title ?? params.candidate.title,
    body: params.body ?? params.candidate.body,
    startDateKey: params.candidate.dateKey,
    endDateKey: params.candidate.dateKey,
    assessmentDateKey: params.candidate.dateKey,
    overallState: params.candidate.overallState,
    overallScore: params.candidate.overallScore,
    primaryFactor: params.candidate.primaryFactor,
    notificationSource: 'health_assessments/latest',
    triggerReason: params.triggerReason,
    updatedAt: admin.firestore.Timestamp.fromDate(params.now),
    lastDecisionReason: params.reason,
    eventType: params.eventType ?? null,
    tokenCount: params.tokenCount ?? 0,
    sentCount: params.sentCount ?? 0,
    failedCount: params.failedCount ?? 0,
    invalidTokenCount: params.invalidTokenCount ?? 0,
    noTokens: params.noTokens ?? false,
  };

  if (params.sentAt) {
    payload.sentAt = admin.firestore.Timestamp.fromDate(params.sentAt);
    payload.lastNotifiedAt = admin.firestore.Timestamp.fromDate(params.sentAt);
    payload.lastNotifiedSeverity = params.candidate.severity;
    payload.lastNotifiedState = params.candidate.overallState;
    payload.lastNotifiedScore = params.candidate.overallScore;
  }
  if (params.releaseClaim) {
    payload.claimedAt = admin.firestore.FieldValue.delete();
  }

  const writes: Array<Promise<FirebaseFirestore.WriteResult>> = [
    ref.set(payload, {merge: true}),
  ];
  if (params.sentAt) {
    const incidentRef = params.db
      .collection('users')
      .doc(params.uid)
      .collection('health_incidents')
      .doc(healthIncidentDocumentId(params.candidate.incidentId));
    writes.push(
      incidentRef.set(
        {
          lastNotifiedAt: admin.firestore.Timestamp.fromDate(params.sentAt),
          lastNotificationEventType: params.eventType ?? null,
          updatedAt: admin.firestore.Timestamp.fromDate(params.now),
        },
        {merge: true},
      ),
    );
  }

  await Promise.all(writes);
}

export async function executeGoldHealthNotificationPipeline(params: {
  db: FirebaseFirestore.Firestore;
  messaging: admin.messaging.Messaging;
  uid: string;
  assessment: HealthAssessment;
  triggerReason: string;
  now?: Date;
}): Promise<GoldHealthNotificationExecutionResult> {
  const now = params.now ?? new Date();

  if (params.triggerReason === 'manual_rebuild') {
    return {
      uid: params.uid,
      reason: 'manualRebuild',
      candidate: null,
      notificationKey: null,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const candidate = buildGoldHealthNotificationCandidate(params.assessment);
  if (!candidate) {
    return {
      uid: params.uid,
      reason: 'noCandidate',
      candidate: null,
      notificationKey: null,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const entitlement = await fetchPaidFeatureEntitlement(params.db, params.uid);
  if (!entitlement.isEntitled) {
    logger.info('Gold health notification skipped: not paid', {
      uid: params.uid,
      plan: entitlement.plan,
      status: entitlement.status,
      dateKey: candidate.dateKey,
      primaryFlag: candidate.primaryFlag,
    });
    return {
      uid: params.uid,
      reason: 'notPaid',
      candidate,
      notificationKey: candidate.notificationKey,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const preferences = await fetchNotificationPreferences(
    params.db,
    params.uid,
  );
  if (!preferences.enabled) {
    await saveDecision({
      db: params.db,
      uid: params.uid,
      candidate,
      now,
      reason: 'userDisabled',
      triggerReason: params.triggerReason,
      releaseClaim: true,
    });
    return {
      uid: params.uid,
      reason: 'userDisabled',
      candidate,
      notificationKey: candidate.notificationKey,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  if (!preferences.notificationCategories[candidate.domainKey]) {
    await saveDecision({
      db: params.db,
      uid: params.uid,
      candidate,
      now,
      reason: 'userDisabled',
      triggerReason: params.triggerReason,
      releaseClaim: true,
    });
    return {
      uid: params.uid,
      reason: 'userDisabled',
      candidate,
      notificationKey: candidate.notificationKey,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const tokens = await fetchEnabledFcmTokens(params.db, params.uid);
  if (tokens.length === 0) {
    await saveDecision({
      db: params.db,
      uid: params.uid,
      candidate,
      now,
      reason: 'noTokens',
      triggerReason: params.triggerReason,
      noTokens: true,
      releaseClaim: true,
    });
    return {
      uid: params.uid,
      reason: 'noTokens',
      candidate,
      notificationKey: candidate.notificationKey,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: true,
    };
  }

  const claim = await claimNotification({
    db: params.db,
    uid: params.uid,
    candidate,
    now,
    triggerReason: params.triggerReason,
    preferences,
  });

  if (!claim.claimed || !claim.eventType) {
    return {
      uid: params.uid,
      reason: claim.reason,
      candidate,
      notificationKey: candidate.notificationKey,
      tokenCount: tokens.length,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const title = titleForCondition({
    conditionType: candidate.conditionType,
    severity: candidate.severity,
    eventType: claim.eventType,
  });
  const body = bodyForCondition({candidate, eventType: claim.eventType});
  const androidChannelId = candidate.severity === 'high'
    ? 'health_critical_v2'
    : 'health_care_v2';

  let response: admin.messaging.BatchResponse;
  try {
    response = await params.messaging.sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        type: 'health_incident',
        incidentId: candidate.incidentId,
        eventType: claim.eventType,
        notificationKey: candidate.notificationKey,
        assessmentDateKey: candidate.dateKey,
        primaryFlag: candidate.primaryFlag,
        domain: candidate.domainKey,
        severity: candidate.severity,
        overallState: candidate.overallState,
        overallScore: String(candidate.overallScore ?? ''),
        contextSource: 'health_assessments/latest',
      },
      android: {
        priority: candidate.severity === 'high' ? 'high' : 'normal',
        notification: {
          channelId: androidChannelId,
          tag: candidate.incidentId,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });
  } catch (error: unknown) {
    await releaseWeeklyNotificationClaim({
      db: params.db,
      uid: params.uid,
      weeklyCounterKey: claim.weeklyCounterKey,
      now,
    });
    await saveDecision({
      db: params.db,
      uid: params.uid,
      candidate,
      now,
      reason: 'sendFailed',
      triggerReason: params.triggerReason,
      tokenCount: tokens.length,
      sentCount: 0,
      failedCount: tokens.length,
      releaseClaim: true,
      eventType: claim.eventType,
      title,
      body,
    });
    logger.error('Gold health notification send failed', {
      uid: params.uid,
      incidentId: candidate.incidentId,
      error: error instanceof Error ? error.message : String(error),
    });
    return {
      uid: params.uid,
      reason: 'sendFailed',
      candidate,
      notificationKey: candidate.notificationKey,
      tokenCount: tokens.length,
      sentCount: 0,
      failedCount: tokens.length,
      noTokens: false,
    };
  }

  const invalidTokens: string[] = [];
  response.responses.forEach((item, index) => {
    if (item.success) return;
    const code = item.error?.code ?? '';
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  await disableInvalidTokens({
    db: params.db,
    uid: params.uid,
    invalidTokens,
  });

  const sentAt = response.successCount > 0 ? now : null;
  const reason: GoldNotificationReason = sentAt ? 'sent' : 'sendFailed';

  if (!sentAt) {
    await releaseWeeklyNotificationClaim({
      db: params.db,
      uid: params.uid,
      weeklyCounterKey: claim.weeklyCounterKey,
      now,
    });
  }

  await saveDecision({
    db: params.db,
    uid: params.uid,
    candidate,
    now,
    reason,
    triggerReason: params.triggerReason,
    sentAt,
    tokenCount: tokens.length,
    sentCount: response.successCount,
    failedCount: response.failureCount,
    invalidTokenCount: invalidTokens.length,
    noTokens: false,
    releaseClaim: true,
    eventType: claim.eventType,
    title,
    body,
  });

  logger.info('Gold health notification executed', {
    uid: params.uid,
    dateKey: candidate.dateKey,
    primaryFlag: candidate.primaryFlag,
    overallState: candidate.overallState,
    severity: candidate.severity,
    notificationKey: candidate.notificationKey,
    incidentId: candidate.incidentId,
    eventType: claim.eventType,
    tokenCount: tokens.length,
    sentCount: response.successCount,
    failedCount: response.failureCount,
    invalidTokenCount: invalidTokens.length,
  });

  return {
    uid: params.uid,
    reason,
    candidate,
    notificationKey: candidate.notificationKey,
    tokenCount: tokens.length,
    sentCount: response.successCount,
    failedCount: response.failureCount,
    noTokens: false,
  };
}

export interface ResolvedHealthNotificationExecutionResult {
  uid: string;
  pendingCount: number;
  sentCount: number;
  failedCount: number;
  skippedCount: number;
}

function asGoldDomainKey(value: unknown): GoldDomainKey | null {
  return value === 'environment' ||
    value === 'activity' ||
    value === 'body' ||
    value === 'condition' ||
    value === 'nutrition'
    ? value
    : null;
}

export function titleForResolvedHealthIncident(conditionType: string): string {
  switch (conditionType) {
    case 'humidity_high':
    case 'humidity_low':
    case 'humidity_spike':
      return 'ケージの湿度が目安の範囲に戻りました';
    case 'temperature_high':
    case 'temperature_low':
    case 'temperature_spike':
      return 'ケージ温度が目安の範囲に戻りました';
    case 'activity_drop':
    case 'activity_high':
      return '活動量の変化が落ち着きました';
    case 'weight_drop':
    case 'weight_increase':
      return '体重の変化が落ち着きました';
    case 'concerning_checkin':
      return '今日の様子の注意状態が解消しました';
    default:
      return '気になっていた変化が落ち着きました';
  }
}

async function updateResolvedNotificationStatus(params: {
  db: FirebaseFirestore.Firestore;
  ref: FirebaseFirestore.DocumentReference;
  now: Date;
  status: 'sent' | 'pending' | 'suppressed' | 'expired';
  reason?: string;
  sentAt?: Date;
}): Promise<void> {
  const payload: Record<string, unknown> = {
    resolvedNotificationStatus: params.status,
    resolvedNotificationClaimedAt: admin.firestore.FieldValue.delete(),
    resolvedNotificationReason:
      params.reason ?? admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.Timestamp.fromDate(params.now),
  };
  if (params.sentAt) {
    payload.resolvedNotificationSentAt =
      admin.firestore.Timestamp.fromDate(params.sentAt);
    payload.lastNotificationEventType = 'resolved';
  }
  await params.ref.set(payload, {merge: true});
}

export async function executePendingResolvedHealthNotifications(params: {
  db: FirebaseFirestore.Firestore;
  messaging: admin.messaging.Messaging;
  uid: string;
  triggerReason: string;
  now?: Date;
}): Promise<ResolvedHealthNotificationExecutionResult> {
  const now = params.now ?? new Date();
  const emptyResult: ResolvedHealthNotificationExecutionResult = {
    uid: params.uid,
    pendingCount: 0,
    sentCount: 0,
    failedCount: 0,
    skippedCount: 0,
  };
  if (params.triggerReason === 'manual_rebuild') return emptyResult;

  const collection = params.db
    .collection('users')
    .doc(params.uid)
    .collection('health_incidents');
  const snapshot = await collection
    .where('status', '==', 'resolved')
    .limit(50)
    .get();
  const pendingDocs = snapshot.docs.filter((doc) => {
    const data = doc.data();
    if (data.resolvedNotificationStatus === 'pending') return true;
    const claimedAt = asDate(data.resolvedNotificationClaimedAt);
    return data.resolvedNotificationStatus === 'claimed' &&
      claimedAt != null &&
      now.getTime() - claimedAt.getTime() >= 10 * 60 * 1000;
  });
  emptyResult.pendingCount = pendingDocs.length;
  if (pendingDocs.length === 0) return emptyResult;

  const entitlement = await fetchPaidFeatureEntitlement(params.db, params.uid);
  if (!entitlement.isEntitled) {
    return {...emptyResult, skippedCount: pendingDocs.length};
  }

  const preferences = await fetchNotificationPreferences(params.db, params.uid);
  const globallyDisabled =
    !preferences.enabled || !preferences.resolvedNotificationsEnabled;
  if (globallyDisabled) {
    await Promise.all(
      pendingDocs.map((doc) => updateResolvedNotificationStatus({
        db: params.db,
        ref: doc.ref,
        now,
        status: 'suppressed',
        reason: 'disabledByPreference',
      })),
    );
    return {...emptyResult, skippedCount: pendingDocs.length};
  }

  if (preferences.quietHoursEnabled && isWithinQuietHours({
    now,
    startHour: preferences.quietHoursStart,
    endHour: preferences.quietHoursEnd,
    timeZone: preferences.timeZone,
  })) {
    return {...emptyResult, skippedCount: pendingDocs.length};
  }

  const tokens = await fetchEnabledFcmTokens(params.db, params.uid);
  if (tokens.length === 0) {
    return {...emptyResult, skippedCount: pendingDocs.length};
  }

  let sentCount = 0;
  let failedCount = 0;
  let skippedCount = 0;
  for (const doc of pendingDocs.slice(0, MAX_RESOLVED_NOTIFICATIONS_PER_RUN)) {
    const initialData = doc.data();
    const resolvedAt = asDate(initialData.resolvedAt);
    if (!resolvedAt || now.getTime() - resolvedAt.getTime() > 24 * 60 * 60 * 1000) {
      await updateResolvedNotificationStatus({
        db: params.db,
        ref: doc.ref,
        now,
        status: 'expired',
        reason: 'resolutionTooOld',
      });
      skippedCount += 1;
      continue;
    }

    const domain = asGoldDomainKey(initialData.domain);
    if (!domain || !preferences.notificationCategories[domain]) {
      await updateResolvedNotificationStatus({
        db: params.db,
        ref: doc.ref,
        now,
        status: 'suppressed',
        reason: domain ? 'categoryDisabled' : 'invalidDomain',
      });
      skippedCount += 1;
      continue;
    }

    const claimed = await params.db.runTransaction(async (transaction) => {
      const current = await transaction.get(doc.ref);
      const data = current.data() ?? {};
      if (data.status !== 'resolved') return false;
      const claimedAt = asDate(data.resolvedNotificationClaimedAt);
      const claimIsStale = claimedAt != null &&
        now.getTime() - claimedAt.getTime() >= 10 * 60 * 1000;
      if (data.resolvedNotificationStatus !== 'pending' && !claimIsStale) {
        return false;
      }
      transaction.set(
        doc.ref,
        {
          resolvedNotificationStatus: 'claimed',
          resolvedNotificationClaimedAt:
            admin.firestore.Timestamp.fromDate(now),
          resolvedNotificationReason: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.Timestamp.fromDate(now),
        },
        {merge: true},
      );
      return true;
    });
    if (!claimed) {
      skippedCount += 1;
      continue;
    }

    const incidentId = typeof initialData.incidentId === 'string'
      ? initialData.incidentId
      : doc.id;
    const conditionType = typeof initialData.conditionType === 'string'
      ? initialData.conditionType
      : '';
    const title = titleForResolvedHealthIncident(conditionType);
    const body = '改善を確認できました。アプリで直近の変化を確認できます。';

    try {
      const response = await params.messaging.sendEachForMulticast({
        tokens,
        notification: {title, body},
        data: {
          type: 'health_incident',
          incidentId,
          eventType: 'resolved',
          notificationKey: `health_incident__${doc.id}`,
          assessmentDateKey:
            String(initialData.assessmentDateKey ?? ''),
          primaryFlag: conditionType,
          domain,
          severity: 'medium',
          overallState: 'stable',
          overallScore: '',
          contextSource: 'health_incidents',
        },
        android: {
          priority: 'normal',
          notification: {
            channelId: 'health_care_v2',
            tag: incidentId,
          },
        },
        apns: {payload: {aps: {sound: 'default'}}},
      });
      const invalidTokens: string[] = [];
      response.responses.forEach((item, index) => {
        const code = item.error?.code ?? '';
        if (!item.success && (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        )) {
          invalidTokens.push(tokens[index]);
        }
      });
      await disableInvalidTokens({
        db: params.db,
        uid: params.uid,
        invalidTokens,
      });

      if (response.successCount > 0) {
        await updateResolvedNotificationStatus({
          db: params.db,
          ref: doc.ref,
          now,
          status: 'sent',
          sentAt: now,
        });
        sentCount += 1;
      } else {
        await updateResolvedNotificationStatus({
          db: params.db,
          ref: doc.ref,
          now,
          status: 'pending',
          reason: 'sendFailed',
        });
        failedCount += 1;
      }
    } catch (error: unknown) {
      await updateResolvedNotificationStatus({
        db: params.db,
        ref: doc.ref,
        now,
        status: 'pending',
        reason: 'sendFailed',
      });
      logger.error('Resolved health notification send failed', {
        uid: params.uid,
        incidentId,
        error: error instanceof Error ? error.message : String(error),
      });
      failedCount += 1;
    }
  }

  skippedCount += Math.max(
    0,
    pendingDocs.length - MAX_RESOLVED_NOTIFICATIONS_PER_RUN,
  );
  return {
    uid: params.uid,
    pendingCount: pendingDocs.length,
    sentCount,
    failedCount,
    skippedCount,
  };
}
