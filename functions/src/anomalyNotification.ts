// functions/src/anomalyNotification.ts

import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

const DEDUPE_HOURS = 24;
const HISTORY_WINDOW_DAYS = 14;

const TEMP_LOW_THRESHOLD = 20.0;
const TEMP_HIGH_THRESHOLD = 26.0;
const HUM_HIGH_THRESHOLD = 60.0;

type HistoryRow = {
  dateKey?: string;
  level?: string | null;
  avgTemp?: number | null;
  avgHum?: number | null;
  tempRatio?: number | null;
  humRatio?: number | null;
  dangerMinutes?: number | null;
  spikesTemp?: number | null;
  spikesHum?: number | null;
  lastEvaluatedAt?: Date | null;
  updatedAt?: Date | null;
};

type AnomalySeverity = 'info' | 'low' | 'medium' | 'high';

type AnomalyFlag =
  | 'highHumidityStreak'
  | 'lowTemperatureStreak'
  | 'highTemperatureStreak'
  | 'dangerMinutesDetected'
  | 'tempSpikeDetected'
  | 'humiditySpikeDetected'
  | 'tempRatioWorsened'
  | 'humidityRatioWorsened'
  | 'cautionLevelStreak'
  | 'dangerLevelDetected';

type DetectedAnomaly = {
  flag: AnomalyFlag;
  severity: AnomalySeverity;
  title: string;
  description: string;
  count?: number | null;
  value?: number | null;
  startDateKey?: string | null;
  endDateKey?: string | null;
};

type AnomalyDetectionResult = {
  anomalies: DetectedAnomaly[];
  windowDays: number;
  detectedAt: Date;
};

type NotificationDecisionReason =
  | 'noAnomaly'
  | 'belowSeverityThreshold'
  | 'alreadySentRecently'
  | 'inactive'
  | 'shouldNotify';

type NotificationDecision = {
  shouldNotify: boolean;
  reason: NotificationDecisionReason;
  anomaly: DetectedAnomaly | null;
  notificationKey: string | null;
  fingerprint: string | null;
  message: string;
};

type NotificationMessage = {
  title: string;
  body: string;
};

export type AnomalyNotificationExecutionResult = {
  uid: string;
  detectionResult: AnomalyDetectionResult;
  decision: NotificationDecision;
  message: NotificationMessage | null;
  notificationKey: string | null;
  tokenCount: number;
  sentCount: number;
  failedCount: number;
  noTokens: boolean;
};

function asNumber(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

function asString(v: unknown): string | null {
  return typeof v === 'string' && v.trim() !== '' ? v : null;
}

function asDate(v: unknown): Date | null {
  if (v instanceof admin.firestore.Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function severityRank(severity: AnomalySeverity): number {
  switch (severity) {
    case 'info':
      return 0;
    case 'low':
      return 1;
    case 'medium':
      return 2;
    case 'high':
      return 3;
  }
}

function maxSeverity(items: AnomalySeverity[]): AnomalySeverity {
  if (items.length === 0) return 'info';
  return items.reduce((a, b) =>
    severityRank(a) >= severityRank(b) ? a : b,
  );
}

function buildNotificationKey(anomaly: DetectedAnomaly): string {
  const start = anomaly.startDateKey ?? 'unknown_start';
  const end = anomaly.endDateKey ?? 'unknown_end';
  return `${anomaly.flag}__${start}__${end}`;
}

function buildFingerprint(anomaly: DetectedAnomaly): string {
  const countPart = anomaly.count != null ? String(anomaly.count) : 'null';
  const valuePart =
    anomaly.value != null ? anomaly.value.toFixed(2) : 'null';
  const start = anomaly.startDateKey ?? 'unknown_start';
  const end = anomaly.endDateKey ?? 'unknown_end';

  return [
    anomaly.flag,
    anomaly.severity,
    countPart,
    valuePart,
    start,
    end,
  ].join('__');
}

function buildPeriodText(anomaly: DetectedAnomaly): string {
  const start = anomaly.startDateKey ?? null;
  const end = anomaly.endDateKey ?? null;

  if (!start && !end) return '';
  if (start && end) {
    if (start === end) return `[${start}] `;
    return `[${start}〜${end}] `;
  }
  if (start) return `[${start}〜] `;
  return `[〜${end}] `;
}

function buildNotificationMessage(anomaly: DetectedAnomaly): NotificationMessage {
  const severityText = (() => {
    switch (anomaly.severity) {
      case 'info':
        return '情報';
      case 'low':
        return '低';
      case 'medium':
        return '中';
      case 'high':
        return '高';
    }
  })();

  const period = buildPeriodText(anomaly);

  switch (anomaly.flag) {
    case 'highHumidityStreak': {
      const days = anomaly.count ?? 0;
      const hum = anomaly.value != null ? Math.round(anomaly.value) : null;
      return {
        title: '湿度が高めの状態が続いています',
        body:
          hum != null
            ? `${period}湿度が高めの状態が${days}日連続です。最新の平均湿度は${hum}%です。状態をご確認ください。[${severityText}]`
            : `${period}湿度が高めの状態が${days}日連続です。状態をご確認ください。[${severityText}]`,
      };
    }

    case 'lowTemperatureStreak': {
      const days = anomaly.count ?? 0;
      const temp = anomaly.value;
      return {
        title: '温度が低めの状態が続いています',
        body:
          temp != null
            ? `${period}温度が低めの状態が${days}日連続です。最新の平均温度は${temp.toFixed(1)}℃です。[${severityText}]`
            : `${period}温度が低めの状態が${days}日連続です。[${severityText}]`,
      };
    }

    case 'highTemperatureStreak': {
      const days = anomaly.count ?? 0;
      const temp = anomaly.value;
      return {
        title: '温度が高めの状態が続いています',
        body:
          temp != null
            ? `${period}温度が高めの状態が${days}日連続です。最新の平均温度は${temp.toFixed(1)}℃です。[${severityText}]`
            : `${period}温度が高めの状態が${days}日連続です。[${severityText}]`,
      };
    }

    case 'dangerMinutesDetected': {
      const minutes = anomaly.value != null ? Math.round(anomaly.value) : 0;
      return {
        title: '危険域への滞在が検出されました',
        body: `${period}直近の評価で危険域への滞在が検出されました。最大${minutes}分です。早めの確認をおすすめします。[${severityText}]`,
      };
    }

    case 'tempSpikeDetected': {
      const count =
        anomaly.count ?? (anomaly.value != null ? Math.round(anomaly.value) : 0);
      return {
        title: '温度の急変が増えています',
        body: `${period}直近で温度急変が${count}回ありました。温度の安定性が崩れている可能性があります。[${severityText}]`,
      };
    }

    case 'humiditySpikeDetected': {
      const count =
        anomaly.count ?? (anomaly.value != null ? Math.round(anomaly.value) : 0);
      return {
        title: '湿度の急変が増えています',
        body: `${period}直近で湿度急変が${count}回ありました。湿度の安定性が崩れている可能性があります。[${severityText}]`,
      };
    }

    case 'tempRatioWorsened': {
      const deltaPt =
        anomaly.value != null ? Math.round(anomaly.value * 100) : null;
      return {
        title: '温度の適正度が悪化しています',
        body:
          deltaPt != null
            ? `${period}温度の適正度が前回より${deltaPt}pt悪化しました。[${severityText}]`
            : `${period}温度の適正度が悪化しています。[${severityText}]`,
      };
    }

    case 'humidityRatioWorsened': {
      const deltaPt =
        anomaly.value != null ? Math.round(anomaly.value * 100) : null;
      return {
        title: '湿度の適正度が悪化しています',
        body:
          deltaPt != null
            ? `${period}湿度の適正度が前回より${deltaPt}pt悪化しました。[${severityText}]`
            : `${period}湿度の適正度が悪化しています。[${severityText}]`,
      };
    }

    case 'cautionLevelStreak': {
      const days = anomaly.count ?? 0;
      return {
        title: '注意評価が続いています',
        body: `${period}環境評価の「注意」が${days}日連続です。状況の固定化にご注意ください。[${severityText}]`,
      };
    }

    case 'dangerLevelDetected':
      return {
        title: '危険評価が検出されました',
        body: `${period}直近3日以内に環境評価「危険」が検出されました。至急状態をご確認ください。[${severityText}]`,
      };
  }
}

function tailConsecutiveCount(
  history: HistoryRow[],
  predicate: (row: HistoryRow) => boolean,
): number {
  let count = 0;
  for (let i = history.length - 1; i >= 0; i--) {
    if (predicate(history[i])) {
      count++;
    } else {
      break;
    }
  }
  return count;
}

function delta(previous: number | null | undefined, current: number | null | undefined): number | null {
  if (previous == null || current == null) return null;
  return current - previous;
}

function detectHighHumidityStreak(history: HistoryRow[]): DetectedAnomaly[] {
  const streak = tailConsecutiveCount(
    history,
    (e) => (e.avgHum ?? Number.NEGATIVE_INFINITY) > HUM_HIGH_THRESHOLD,
  );

  if (streak < 3) return [];
  const recent = history.slice(history.length - streak);
  const latest = recent[recent.length - 1];
  const latestHum = latest.avgHum ?? null;

  return [
    {
      flag: 'highHumidityStreak',
      severity: streak >= 5 ? 'high' : 'medium',
      title: '高湿が続いています',
      description:
        latestHum != null
          ? `湿度が高めの状態が ${streak} 日連続です。最新の平均湿度は ${Math.round(latestHum)}% です。`
          : `湿度が高めの状態が ${streak} 日連続です。`,
      count: streak,
      value: latestHum,
      startDateKey: recent[0]?.dateKey ?? null,
      endDateKey: recent[recent.length - 1]?.dateKey ?? null,
    },
  ];
}

function detectLowTemperatureStreak(history: HistoryRow[]): DetectedAnomaly[] {
  const streak = tailConsecutiveCount(
    history,
    (e) => (e.avgTemp ?? Number.POSITIVE_INFINITY) < TEMP_LOW_THRESHOLD,
  );

  if (streak < 3) return [];
  const recent = history.slice(history.length - streak);
  const latest = recent[recent.length - 1];
  const latestTemp = latest.avgTemp ?? null;

  return [
    {
      flag: 'lowTemperatureStreak',
      severity: streak >= 5 ? 'high' : 'medium',
      title: '低温が続いています',
      description:
        latestTemp != null
          ? `温度が低めの状態が ${streak} 日連続です。最新の平均温度は ${latestTemp.toFixed(1)}℃ です。`
          : `温度が低めの状態が ${streak} 日連続です。`,
      count: streak,
      value: latestTemp,
      startDateKey: recent[0]?.dateKey ?? null,
      endDateKey: recent[recent.length - 1]?.dateKey ?? null,
    },
  ];
}

function detectHighTemperatureStreak(history: HistoryRow[]): DetectedAnomaly[] {
  const streak = tailConsecutiveCount(
    history,
    (e) => (e.avgTemp ?? Number.NEGATIVE_INFINITY) > TEMP_HIGH_THRESHOLD,
  );

  if (streak < 3) return [];
  const recent = history.slice(history.length - streak);
  const latest = recent[recent.length - 1];
  const latestTemp = latest.avgTemp ?? null;

  return [
    {
      flag: 'highTemperatureStreak',
      severity: streak >= 5 ? 'high' : 'medium',
      title: '高温が続いています',
      description:
        latestTemp != null
          ? `温度が高めの状態が ${streak} 日連続です。最新の平均温度は ${latestTemp.toFixed(1)}℃ です。`
          : `温度が高めの状態が ${streak} 日連続です。`,
      count: streak,
      value: latestTemp,
      startDateKey: recent[0]?.dateKey ?? null,
      endDateKey: recent[recent.length - 1]?.dateKey ?? null,
    },
  ];
}

function detectDangerMinutes(history: HistoryRow[]): DetectedAnomaly[] {
  if (history.length === 0) return [];
  const recent = history.length <= 3 ? history : history.slice(history.length - 3);
  const hit = recent.filter((e) => (e.dangerMinutes ?? 0) > 0);
  if (hit.length === 0) return [];

  const maxDanger = hit
    .map((e) => e.dangerMinutes ?? 0)
    .reduce((max, v) => (v > max ? v : max), 0);

  return [
    {
      flag: 'dangerMinutesDetected',
      severity: maxDanger >= 60 ? 'high' : 'medium',
      title: '危険域への滞在がありました',
      description: `直近3日以内に危険域へ入った記録があります。最大で ${maxDanger} 分の滞在が検出されました。`,
      count: hit.length,
      value: maxDanger,
      startDateKey: hit[0]?.dateKey ?? null,
      endDateKey: hit[hit.length - 1]?.dateKey ?? null,
    },
  ];
}

function detectSpikes(history: HistoryRow[]): DetectedAnomaly[] {
  if (history.length === 0) return [];
  const recent = history.length <= 3 ? history : history.slice(history.length - 3);

  const tempSpikeTotal = recent.reduce((sum, e) => sum + (e.spikesTemp ?? 0), 0);
  const humSpikeTotal = recent.reduce((sum, e) => sum + (e.spikesHum ?? 0), 0);

  const anomalies: DetectedAnomaly[] = [];

  if (tempSpikeTotal >= 3) {
    anomalies.push({
      flag: 'tempSpikeDetected',
      severity: tempSpikeTotal >= 6 ? 'high' : 'medium',
      title: '温度の急変が増えています',
      description: `直近3日で温度急変が合計 ${tempSpikeTotal} 回ありました。温度の安定性が崩れている可能性があります。`,
      count: tempSpikeTotal,
      value: tempSpikeTotal,
      startDateKey: recent[0]?.dateKey ?? null,
      endDateKey: recent[recent.length - 1]?.dateKey ?? null,
    });
  }

  if (humSpikeTotal >= 3) {
    anomalies.push({
      flag: 'humiditySpikeDetected',
      severity: humSpikeTotal >= 6 ? 'high' : 'medium',
      title: '湿度の急変が増えています',
      description: `直近3日で湿度急変が合計 ${humSpikeTotal} 回ありました。湿度の安定性が崩れている可能性があります。`,
      count: humSpikeTotal,
      value: humSpikeTotal,
      startDateKey: recent[0]?.dateKey ?? null,
      endDateKey: recent[recent.length - 1]?.dateKey ?? null,
    });
  }

  return anomalies;
}

function detectRatioWorsening(history: HistoryRow[]): DetectedAnomaly[] {
  if (history.length < 2) return [];

  const recent = history.length <= 3 ? history : history.slice(history.length - 3);
  const latest = recent[recent.length - 1];
  const previous = recent[recent.length - 2];

  const anomalies: DetectedAnomaly[] = [];

  const tempRatioDelta = delta(previous?.tempRatio, latest?.tempRatio);
  if (tempRatioDelta != null && tempRatioDelta >= 0.15) {
    anomalies.push({
      flag: 'tempRatioWorsened',
      severity: tempRatioDelta >= 0.30 ? 'high' : 'medium',
      title: '温度の適正度が悪化しています',
      description: `直近で温度の適正度が悪化しました。前回比で ${Math.round(tempRatioDelta * 100)}pt 変化しています。`,
      value: tempRatioDelta,
      startDateKey: previous?.dateKey ?? null,
      endDateKey: latest?.dateKey ?? null,
    });
  }

  const humRatioDelta = delta(previous?.humRatio, latest?.humRatio);
  if (humRatioDelta != null && humRatioDelta >= 0.15) {
    anomalies.push({
      flag: 'humidityRatioWorsened',
      severity: humRatioDelta >= 0.30 ? 'high' : 'medium',
      title: '湿度の適正度が悪化しています',
      description: `直近で湿度の適正度が悪化しました。前回比で ${Math.round(humRatioDelta * 100)}pt 変化しています。`,
      value: humRatioDelta,
      startDateKey: previous?.dateKey ?? null,
      endDateKey: latest?.dateKey ?? null,
    });
  }

  return anomalies;
}

function detectLevelIssues(history: HistoryRow[]): DetectedAnomaly[] {
  if (history.length === 0) return [];

  const results: DetectedAnomaly[] = [];

  const cautionStreak = tailConsecutiveCount(history, (e) => e.level === '注意');
  if (cautionStreak >= 3) {
    const recent = history.slice(history.length - cautionStreak);
    results.push({
      flag: 'cautionLevelStreak',
      severity: cautionStreak >= 5 ? 'high' : 'medium',
      title: '注意評価が続いています',
      description: `環境評価の「注意」が ${cautionStreak} 日連続です。`,
      count: cautionStreak,
      value: cautionStreak,
      startDateKey: recent[0]?.dateKey ?? null,
      endDateKey: recent[recent.length - 1]?.dateKey ?? null,
    });
  }

  const recent3 = history.length <= 3 ? history : history.slice(history.length - 3);
  const dangerHit = recent3.filter((e) => e.level === '危険');
  if (dangerHit.length > 0) {
    results.push({
      flag: 'dangerLevelDetected',
      severity: 'high',
      title: '危険評価が検出されました',
      description: '直近3日以内に環境評価「危険」が発生しています。',
      count: dangerHit.length,
      value: dangerHit.length,
      startDateKey: dangerHit[0]?.dateKey ?? null,
      endDateKey: dangerHit[dangerHit.length - 1]?.dateKey ?? null,
    });
  }

  return results;
}

function detectAnomalies(history: HistoryRow[], windowDays: number, now: Date): AnomalyDetectionResult {
  const sorted = [...history].sort((a, b) =>
    String(a.dateKey ?? '').localeCompare(String(b.dateKey ?? '')),
  );

  const anomalies: DetectedAnomaly[] = [
    ...detectHighHumidityStreak(sorted),
    ...detectLowTemperatureStreak(sorted),
    ...detectHighTemperatureStreak(sorted),
    ...detectDangerMinutes(sorted),
    ...detectSpikes(sorted),
    ...detectRatioWorsening(sorted),
    ...detectLevelIssues(sorted),
  ];

  anomalies.sort((a, b) => {
    const severityCompare = severityRank(b.severity) - severityRank(a.severity);
    if (severityCompare !== 0) return severityCompare;

    const countCompare = (b.count ?? 0) - (a.count ?? 0);
    if (countCompare !== 0) return countCompare;

    return (b.value ?? 0) - (a.value ?? 0);
  });

  return {
    anomalies,
    windowDays,
    detectedAt: now,
  };
}

function decideNotification(params: {
  detectionResult: AnomalyDetectionResult;
  lastSentAt: Date | null;
  isStillActive: boolean;
  minimumSeverity: AnomalySeverity;
  dedupeHours: number;
}): NotificationDecision {
  const { detectionResult, lastSentAt, isStillActive, minimumSeverity, dedupeHours } = params;
  const anomaly = detectionResult.anomalies[0] ?? null;

  if (!anomaly) {
    return {
      shouldNotify: false,
      reason: 'noAnomaly',
      anomaly: null,
      notificationKey: null,
      fingerprint: null,
      message: '通知対象の異常はありません。',
    };
  }

  const notificationKey = buildNotificationKey(anomaly);
  const fingerprint = buildFingerprint(anomaly);

  if (severityRank(anomaly.severity) < severityRank(minimumSeverity)) {
    return {
      shouldNotify: false,
      reason: 'belowSeverityThreshold',
      anomaly,
      notificationKey,
      fingerprint,
      message: '異常はありますが、通知閾値未満です。',
    };
  }

  if (!isStillActive) {
    return {
      shouldNotify: false,
      reason: 'inactive',
      anomaly,
      notificationKey,
      fingerprint,
      message: '異常は現在アクティブではないため通知しません。',
    };
  }

  if (lastSentAt) {
    const diffMs = detectionResult.detectedAt.getTime() - lastSentAt.getTime();
    if (diffMs < dedupeHours * 60 * 60 * 1000) {
      return {
        shouldNotify: false,
        reason: 'alreadySentRecently',
        anomaly,
        notificationKey,
        fingerprint,
        message: '同種の通知を直近24時間以内に送信済みです。',
      };
    }
  }

  return {
    shouldNotify: true,
    reason: 'shouldNotify',
    anomaly,
    notificationKey,
    fingerprint,
    message: '通知条件を満たしたため送信対象です。',
  };
}

async function fetchRecentHistory(
  db: FirebaseFirestore.Firestore,
  uid: string,
  limit: number,
): Promise<HistoryRow[]> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('environment_assessments_history')
    .orderBy('dateKey', 'desc')
    .limit(limit)
    .get();

  const rows = snap.docs.map((d) => {
    const m = d.data() ?? {};
    return {
      dateKey: asString(m.dateKey) ?? d.id,
      level: asString(m.level),
      avgTemp: asNumber(m.avgTemp),
      avgHum: asNumber(m.avgHum),
      tempRatio: asNumber(m.tempRatio),
      humRatio: asNumber(m.humRatio),
      dangerMinutes: asNumber(m.dangerMinutes),
      spikesTemp: asNumber(m.spikesTemp),
      spikesHum: asNumber(m.spikesHum),
      lastEvaluatedAt: asDate(m.lastEvaluatedAt),
      updatedAt: asDate(m.updatedAt),
    } as HistoryRow;
  });

  rows.sort((a, b) => String(a.dateKey ?? '').localeCompare(String(b.dateKey ?? '')));
  return rows;
}

async function fetchLastSentAt(
  db: FirebaseFirestore.Firestore,
  uid: string,
  notificationKey: string,
): Promise<Date | null> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('anomaly_notification_logs')
    .doc(notificationKey)
    .get();

  if (!snap.exists) return null;
  const data = snap.data() ?? {};
  return asDate(data.sentAt);
}

async function saveNotificationLog(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  decision: NotificationDecision;
  message: NotificationMessage;
  now: Date;
  sentAt: Date | null;
  tokenCount?: number;
  sentCount?: number;
  failedCount?: number;
  invalidTokenCount?: number;
  noTokens?: boolean;
}): Promise<void> {
  const {
    db,
    uid,
    decision,
    message,
    now,
    sentAt,
    tokenCount = 0,
    sentCount = 0,
    failedCount = 0,
    invalidTokenCount = 0,
    noTokens = false,
  } = params;
  if (!decision.anomaly || !decision.notificationKey || !decision.fingerprint) return;

  const ref = db
    .collection('users')
    .doc(uid)
    .collection('anomaly_notification_logs')
    .doc(decision.notificationKey);

  const existing = await ref.get();
  const existingData = existing.exists ? existing.data() ?? {} : {};
  const createdAt = asDate(existingData.createdAt) ?? now;

  await ref.set(
    {
      notificationKey: decision.notificationKey,
      fingerprint: decision.fingerprint,
      anomalyFlag: decision.anomaly.flag,
      severity: decision.anomaly.severity,
      title: message.title,
      body: message.body,
      startDateKey: decision.anomaly.startDateKey ?? null,
      endDateKey: decision.anomaly.endDateKey ?? null,
      sentAt: sentAt ? admin.firestore.Timestamp.fromDate(sentAt) : existingData.sentAt ?? null,
      createdAt: admin.firestore.Timestamp.fromDate(createdAt),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
      lastDecisionReason: decision.reason,
      lastDecisionMessage: decision.message,

      tokenCount,
      sentCount,
      failedCount,
      invalidTokenCount,
      noTokens,
    },
    { merge: true },
  );
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
    const tokenFromField = asString(data.token);
    if (tokenFromField) {
      tokens.add(tokenFromField);
      continue;
    }

    // doc.id を token にする運用も許容
    if (doc.id && doc.id !== '__placeholder__') {
      tokens.add(doc.id);
    }
  }

  return [...tokens];
}

async function disableInvalidTokens(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  invalidTokens: string[];
}): Promise<void> {
  const { db, uid, invalidTokens } = params;
  if (invalidTokens.length === 0) return;

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const token of invalidTokens) {
    const ref = db
      .collection('users')
      .doc(uid)
      .collection('notification_tokens')
      .doc(token);

    batch.set(
      ref,
      {
        enabled: false,
        invalidatedAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  await batch.commit();
}

export async function executeAnomalyNotificationPipeline(params: {
  db: FirebaseFirestore.Firestore;
  messaging: admin.messaging.Messaging;
  uid: string;
  windowDays?: number;
  now?: Date;
}): Promise<AnomalyNotificationExecutionResult> {
  const {
    db,
    messaging,
    uid,
    windowDays = HISTORY_WINDOW_DAYS,
    now = new Date(),
  } = params;

  const history = await fetchRecentHistory(db, uid, windowDays);
  const detectionResult = detectAnomalies(history, windowDays, now);

  const top = detectionResult.anomalies[0] ?? null;

  let lastSentAt: Date | null = null;
  if (top) {
    lastSentAt = await fetchLastSentAt(db, uid, buildNotificationKey(top));
  }

  const decision = decideNotification({
    detectionResult,
    lastSentAt,
    isStillActive: true,
    minimumSeverity: 'high',
    dedupeHours: DEDUPE_HOURS,
  });

  if (!decision.anomaly || !decision.notificationKey || !decision.fingerprint) {
    return {
      uid,
      detectionResult,
      decision,
      message: null,
      notificationKey: null,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const message = buildNotificationMessage(decision.anomaly);

    if (!decision.shouldNotify) {
    await saveNotificationLog({
      db,
      uid,
      decision,
      message,
      now,
      sentAt: null,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      invalidTokenCount: 0,
      noTokens: false,
    });

    return {
      uid,
      detectionResult,
      decision,
      message,
      notificationKey: decision.notificationKey,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: false,
    };
  }

  const tokens = await fetchEnabledFcmTokens(db, uid);

    if (tokens.length === 0) {
    await saveNotificationLog({
      db,
      uid,
      decision,
      message,
      now,
      sentAt: null,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      invalidTokenCount: 0,
      noTokens: true,
    });

    logger.info('anomaly notification skipped: no FCM tokens', {
      uid,
      notificationKey: decision.notificationKey,
    });

    return {
      uid,
      detectionResult,
      decision,
      message,
      notificationKey: decision.notificationKey,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      noTokens: true,
    };
  }

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: message.title,
      body: message.body,
    },
    data: {
      type: 'anomaly',
      notificationKey: decision.notificationKey,
      anomalyFlag: decision.anomaly.flag,
      severity: decision.anomaly.severity,
      startDateKey: decision.anomaly.startDateKey ?? '',
      endDateKey: decision.anomaly.endDateKey ?? '',
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
  response.responses.forEach((r, i) => {
    if (r.success) return;

    const code = r.error?.code ?? '';
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      invalidTokens.push(tokens[i]);
    }
  });

  if (invalidTokens.length > 0) {
    await disableInvalidTokens({
      db,
      uid,
      invalidTokens,
    });
  }

  const sentAt = response.successCount > 0 ? now : null;

  await saveNotificationLog({
    db,
    uid,
    decision,
    message,
    now,
    sentAt,
    tokenCount: tokens.length,
    sentCount: response.successCount,
    failedCount: response.failureCount,
    invalidTokenCount: invalidTokens.length,
    noTokens: false,
  });

  logger.info('anomaly notification executed', {
    uid,
    notificationKey: decision.notificationKey,
    tokenCount: tokens.length,
    sentCount: response.successCount,
    failedCount: response.failureCount,
    invalidTokenCount: invalidTokens.length,
  });

  return {
    uid,
    detectionResult,
    decision,
    message,
    notificationKey: decision.notificationKey,
    tokenCount: tokens.length,
    sentCount: response.successCount,
    failedCount: response.failureCount,
    noTokens: false,
  };
}