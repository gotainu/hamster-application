import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

import {
  HealthAssessment,
  HealthAssessmentState,
  HealthDomainAssessment,
} from './healthTypes';

const DEDUPE_HOURS = 24;
const CLAIM_MINUTES = 10;
const MAX_BODY_LENGTH = 190;

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
type GoldDomainKey =
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
  | 'noTokens'
  | 'sendFailed'
  | 'sent';

export interface GoldHealthNotificationCandidate {
  dateKey: string;
  domainKey: GoldDomainKey;
  primaryFlag: string;
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

function titleForState(state: HealthAssessmentState): string {
  switch (state) {
    case 'alert':
      return 'ハムスターの状態に警戒が必要です';
    case 'caution':
      return 'ハムスターの状態に注意があります';
    case 'changed':
      return 'ハムスターの変化を確認してください';
    default:
      return 'ハムスターの状態を確認してください';
  }
}

function truncate(value: string, maxLength: number): string {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, Math.max(0, maxLength - 1))}…`;
}

function sanitizeKey(value: string): string {
  return value
    .trim()
    .replace(/[^A-Za-z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80) || 'health_state';
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

  const body = truncate(
    recommendedAction
      ? `${primaryFactor} ${recommendedAction}`
      : primaryFactor,
    MAX_BODY_LENGTH,
  );

  const safeFlag = sanitizeKey(primaryFlag);
  const notificationKey = [
    'gold',
    assessment.dateKey,
    safeFlag,
    severity,
  ].join('__');

  const fingerprint = [
    assessment.dateKey,
    state,
    String(assessment.overall.observedScore ?? 'null'),
    safeFlag,
    truncate(primaryFactor, 100),
  ].join('__');

  return {
    dateKey: assessment.dateKey,
    domainKey: selected.key,
    primaryFlag,
    overallState: state,
    overallScore: assessment.overall.observedScore,
    severity,
    title: titleForState(state),
    body,
    primaryFactor,
    recommendedAction,
    notificationKey,
    fingerprint,
  };
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

async function fetchNotificationsEnabled(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('settings')
    .doc('notifications')
    .get();

  if (!snap.exists) return true;
  const data = snap.data() ?? {};

  if (typeof data.goldHealthNotificationsEnabled === 'boolean') {
    return data.goldHealthNotificationsEnabled;
  }
  if (typeof data.anomalyNotificationsEnabled === 'boolean') {
    return data.anomalyNotificationsEnabled;
  }
  return true;
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
}): Promise<boolean> {
  const ref = logRef({
    db: params.db,
    uid: params.uid,
    notificationKey: params.candidate.notificationKey,
  });

  return params.db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const data = snap.data() ?? {};
    const sentAt = asDate(data.sentAt);
    const claimedAt = asDate(data.claimedAt);

    if (
      sentAt &&
      params.now.getTime() - sentAt.getTime() < DEDUPE_HOURS * 60 * 60 * 1000
    ) {
      return false;
    }

    if (
      claimedAt &&
      params.now.getTime() - claimedAt.getTime() < CLAIM_MINUTES * 60 * 1000
    ) {
      return false;
    }

    transaction.set(
      ref,
      {
        notificationKey: params.candidate.notificationKey,
        fingerprint: params.candidate.fingerprint,
        anomalyFlag: params.candidate.primaryFlag,
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
        claimedAt: admin.firestore.Timestamp.fromDate(params.now),
        createdAt:
          data.createdAt ?? admin.firestore.Timestamp.fromDate(params.now),
        updatedAt: admin.firestore.Timestamp.fromDate(params.now),
        lastDecisionReason: 'claimed',
      },
      {merge: true},
    );

    return true;
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
    updatedAt: admin.firestore.Timestamp.fromDate(params.now),
    lastDecisionReason: params.reason,
    tokenCount: params.tokenCount ?? 0,
    sentCount: params.sentCount ?? 0,
    failedCount: params.failedCount ?? 0,
    invalidTokenCount: params.invalidTokenCount ?? 0,
    noTokens: params.noTokens ?? false,
  };

  if (params.sentAt) {
    payload.sentAt = admin.firestore.Timestamp.fromDate(params.sentAt);
  }
  if (params.releaseClaim) {
    payload.claimedAt = admin.firestore.FieldValue.delete();
  }

  await ref.set(payload, {merge: true});
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

  const enabled = await fetchNotificationsEnabled(params.db, params.uid);
  if (!enabled) {
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

  const claimed = await claimNotification({
    db: params.db,
    uid: params.uid,
    candidate,
    now,
    triggerReason: params.triggerReason,
  });

  if (!claimed) {
    return {
      uid: params.uid,
      reason: 'alreadySentRecently',
      candidate,
      notificationKey: candidate.notificationKey,
      tokenCount: tokens.length,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const response = await params.messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: candidate.title,
      body: candidate.body,
    },
    data: {
      type: 'gold_health_alert',
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
      priority: 'high',
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  });

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
  });

  logger.info('Gold health notification executed', {
    uid: params.uid,
    dateKey: candidate.dateKey,
    primaryFlag: candidate.primaryFlag,
    overallState: candidate.overallState,
    severity: candidate.severity,
    notificationKey: candidate.notificationKey,
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
