// functions/src/index.ts

import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import crypto from 'crypto';
import { executeAnomalyNotificationPipeline } from './anomalyNotification';

admin.initializeApp();
const db = admin.firestore();

function getProjectId(): string | null {
  return (
    process.env.GCLOUD_PROJECT ||
    process.env.PROJECT_ID ||
    admin.app().options.projectId ||
    null
  );
}

/** ---- Envelope 復号（今回は未使用だけど残してOK） ---- */
function getEnvelopeKey(): Buffer {
  const raw = process.env.ENVELOPE_KEY || '';
  if (!raw) throw new Error('ENVELOPE_KEY is not set');
  if (raw.length === 32) return Buffer.from(raw, 'utf8');
  const isB64 = /^[A-Za-z0-9+/]+=*$/.test(raw);
  const buf = isB64 ? Buffer.from(raw, 'base64') : Buffer.from(raw, 'hex');
  if (buf.length !== 32) throw new Error('ENVELOPE_KEY must be 32 bytes');
  return buf;
}

function unwrapIfWrapped(b64OrPlain?: string): string | undefined {
  if (!b64OrPlain) return undefined;
  try {
    const buf = Buffer.from(b64OrPlain, 'base64');
    if (buf.length >= 12 + 16 + 1) {
      const iv = buf.subarray(0, 12);
      const tag = buf.subarray(buf.length - 16);
      const ct = buf.subarray(12, buf.length - 16);
      const key = getEnvelopeKey();
      const dec = crypto.createDecipheriv('aes-256-gcm', key, iv);
      dec.setAuthTag(tag);
      const plain = Buffer.concat([dec.update(ct), dec.final()]).toString('utf8');
      return plain;
    }
  } catch {
    // ignore
  }
  return b64OrPlain;
}

/** SwitchBot auth header (v1.1)
 *  string_to_sign = token + t + nonce
 *  sign = base64(HMAC-SHA256(string_to_sign, secret))
 */
function buildHeaders(token: string, secret: string) {
  const t = Date.now().toString(); // 13 digits
  const nonce = crypto.randomUUID();
  const stringToSign = `${token}${t}${nonce}`;
  const sign = crypto.createHmac('sha256', secret).update(stringToSign).digest('base64');

  return {
    'Content-Type': 'application/json; charset=utf-8',
    Authorization: token,
    t,
    nonce,
    sign,
  } as Record<string, string>;
}

/** SwitchBot /devices を叩いて token/secret の正当性を検証 */
async function verifySwitchbotTokenSecret(token: string, secret: string): Promise<void> {
  const url = 'https://api.switch-bot.com/v1.1/devices';

  let res: Response;
  try {
    res = await fetch(url, { method: 'GET', headers: buildHeaders(token, secret) });
  } catch (e: any) {
    logger.error('SwitchBot fetch failed', { error: String(e?.message ?? e) });
    throw new HttpsError('unavailable', 'SwitchBot API に接続できませんでした（ネットワーク/一時障害）。');
  }

  const text = await res.text().catch(() => '');

  if (res.ok) return;

  if (res.status === 401 || res.status === 403) {
    throw new HttpsError(
      'permission-denied',
      'SwitchBot の TOKEN/SECRET が正しくありません（認証に失敗しました）。',
    );
  }

  throw new HttpsError('unavailable', `SwitchBot API エラー(${res.status}): ${text.slice(0, 300)}`);
}

/** ★ TOKEN / SECRET を “検証してから” 平文保存（v1_plain） */
export const registerSwitchbotSecrets = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const token = String(req.data?.token ?? '').trim();
    const secret = String(req.data?.secret ?? '').trim();

    if (token.length === 0 || secret.length === 0) {
      throw new HttpsError('invalid-argument', 'TOKEN/SECRET は必須です。');
    }
    if (token.length < 20 || secret.length < 10) {
      throw new HttpsError('invalid-argument', 'TOKEN/SECRET の形式が不正です（短すぎます）。');
    }

    await verifySwitchbotTokenSecret(token, secret);

    const docRef = db
      .collection('users')
      .doc(uid)
      .collection('integrations')
      .doc('switchbot_secrets');

    await docRef.set(
      {
        v1_plain: {
          token,
          secret,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        disabledAt: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );

    await db.collection('switchbot_users').doc(uid).set(
      {
        hasSwitchbot: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        disabledAt: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );

    const verifySnap = await docRef.get();

    return {
      ok: true,
      verified: true,
      uid,
      projectId: process.env.GCLOUD_PROJECT ?? null,
      debugMarker: 'registerSwitchbotSecrets_v2_20260301',
      savedDocExists: verifySnap.exists,
      savedDocData: verifySnap.data() ?? null,
      savedPath: docRef.path,
    };
  },
);

/** Firestore からユーザーの SwitchBot 設定を読み出す */
async function loadUserConfig(uid: string) {
  const integ = db.collection('users').doc(uid).collection('integrations');
  const secSnap = await integ.doc('switchbot_secrets').get();
  const swSnap = await integ.doc('switchbot').get();

  let token: string | undefined;
  let secret: string | undefined;

  // prefer v1_plain
  const v1p = (secSnap.exists ? (secSnap.get('v1_plain') as any) : null) ?? null;
  if (v1p && typeof v1p === 'object') {
    token = typeof v1p.token === 'string' ? v1p.token : undefined;
    secret = typeof v1p.secret === 'string' ? v1p.secret : undefined;
  }

  // fallback to legacy v1
  if (!token || !secret) {
    const v1 = (secSnap.exists ? (secSnap.get('v1') as any) : null) ?? null;
    if (v1 && typeof v1 === 'object') {
      const t = unwrapIfWrapped(v1.token);
      const s = unwrapIfWrapped(v1.secret);
      if (typeof t === 'string') token = token ?? t;
      if (typeof s === 'string') secret = secret ?? s;
    }
  }

  const meterDeviceId = swSnap.exists
    ? (swSnap.get('meterDeviceId') as string | undefined)
    : undefined;

  return { token, secret, meterDeviceId };
}

/** 温湿度計 1台分の /status を取得 */
async function getMeterStatus(deviceId: string, token: string, secret: string) {
  const url = `https://api.switch-bot.com/v1.1/devices/${deviceId}/status`;
  const res = await fetch(url, { method: 'GET', headers: buildHeaders(token, secret) });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`switchbot http ${res.status} ${body}`);
  }

  const j = (await res.json()) as any;
  const b = j?.body ?? {};
  return {
    temperature: typeof b.temperature === 'number' ? b.temperature : null,
    humidity: typeof b.humidity === 'number' ? b.humidity : null,
    battery: typeof b.battery === 'number' ? b.battery : null,
  };
}

/** Firestore への保存 */
async function saveReading(
  uid: string,
  r: { temperature: number | null; humidity: number | null; battery: number | null },
) {
  const ts = new Date().toISOString();
  await db.collection('users').doc(uid).collection('switchbot_readings').doc(ts).set(
    {
      ts,
      temperature: r.temperature,
      humidity: r.humidity,
      battery: r.battery,
      source: 'status',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

type PollAllResult = { total: number; saved: number; skipped: number; failed: number };
type SwitchbotReading = {
  ts?: string;
  temperature?: number | null;
  humidity?: number | null;
  battery?: number | null;
};

type BreedingEnvironment = {
  cageWidth?: number | null;
  cageDepth?: number | null;
  beddingThickness?: number | null;
  wheelDiameter?: number | null;
  temperatureControl?: string | null;
};

const WINDOW_DAYS = 7;
const TEMP_MIN = 20.0;
const TEMP_MAX = 26.0;
const TEMP_DANGER_LOW = 18.0;
const TEMP_DANGER_HIGH = 28.0;
const HUM_MIN = 40.0;
const HUM_MAX = 60.0;
const TEMP_SPIKE_THRESHOLD = 2.0;
const HUM_SPIKE_THRESHOLD = 15.0;

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

function parseIsoSafe(ts: unknown): Date | null {
  if (typeof ts !== 'string' || !ts.trim()) return null;
  const d = new Date(ts);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function toDateKeyJst(d: Date): string {
  const jst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const y = jst.getUTCFullYear();
  const m = String(jst.getUTCMonth() + 1).padStart(2, '0');
  const day = String(jst.getUTCDate()).padStart(2, '0');
  return `${y}${m}${day}`;
}

function getJstDayRangeFromDateKey(dateKey: string): {
  dateKey: string;
  startUtc: Date;
  endUtc: Date;
} {
  if (!/^\d{8}$/.test(dateKey)) {
    throw new Error(`invalid dateKey: ${dateKey}`);
  }

  const y = Number(dateKey.slice(0, 4));
  const m = Number(dateKey.slice(4, 6));
  const d = Number(dateKey.slice(6, 8));

  // JST 00:00 を UTC に直す（JST = UTC+9）
  const startUtc = new Date(Date.UTC(y, m - 1, d, 0, 0, 0) - 9 * 60 * 60 * 1000);
  const endUtc = new Date(startUtc.getTime() + 24 * 60 * 60 * 1000);

  return { dateKey, startUtc, endUtc };
}

function getJstDayRange(base: Date): {
  dateKey: string;
  startUtc: Date;
  endUtc: Date;
} {
  return getJstDayRangeFromDateKey(toDateKeyJst(base));
}

function chunkArray<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
}

function mean(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function fmtPct01(x: number): string {
  return `${Math.round(x * 100)}%`;
}

function levelFromMetrics(params: {
  dangerMinutes: number;
  tempRatio: number;
  humRatio: number;
  spikesTemp: number;
  spikesHum: number;
}): { level: '良好' | '注意' | '危険'; emoji: string } {
  const { dangerMinutes, tempRatio, humRatio, spikesTemp, spikesHum } = params;

  if (dangerMinutes >= 30) return { level: '危険', emoji: '🚨' };
  if (dangerMinutes > 0) return { level: '注意', emoji: '⚠️' };
  if (tempRatio < 0.6 || humRatio < 0.6) return { level: '注意', emoji: '⚠️' };
  if (spikesTemp >= 3 || spikesHum >= 3) return { level: '注意', emoji: '⚠️' };

  return { level: '良好', emoji: '✅' };
}

async function fetchBreedingEnvironment(uid: string): Promise<BreedingEnvironment | null> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('breeding_environments')
    .doc('main_env')
    .get();

  if (!snap.exists) return null;
  const m = snap.data() ?? {};

  return {
    cageWidth: asNumber(m.cageWidth),
    cageDepth: asNumber(m.cageDepth),
    beddingThickness: asNumber(m.beddingThickness),
    wheelDiameter: asNumber(m.wheelDiameter),
    temperatureControl: asString(m.temperatureControl),
  };
}

async function fetchRecentSwitchbotReadings(uid: string, limit = 1000): Promise<SwitchbotReading[]> {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('switchbot_readings')
    .orderBy('ts', 'desc')
    .limit(limit)
    .get();

  const rows = snap.docs.map((d) => d.data() ?? {});

  // old -> new に並べ替え
  rows.sort((a: any, b: any) => {
    const at = typeof a.ts === 'string' ? a.ts : '';
    const bt = typeof b.ts === 'string' ? b.ts : '';
    return at.localeCompare(bt);
  });

  return rows.map((m: any) => ({
    ts: typeof m.ts === 'string' ? m.ts : undefined,
    temperature: asNumber(m.temperature),
    humidity: asNumber(m.humidity),
    battery: asNumber(m.battery),
  }));
}

async function fetchAllSwitchbotReadings(uid: string): Promise<SwitchbotReading[]> {
  const out: SwitchbotReading[] = [];
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  while (true) {
    let q: FirebaseFirestore.Query = db
      .collection('users')
      .doc(uid)
      .collection('switchbot_readings')
      .orderBy('ts')
      .limit(1000);

    if (lastDoc) {
      q = q.startAfter(lastDoc);
    }

    const snap = await q.get();
    if (snap.empty) break;

    for (const d of snap.docs) {
      const m = d.data() ?? {};
      out.push({
        ts: typeof m.ts === 'string' ? m.ts : undefined,
        temperature: asNumber(m.temperature),
        humidity: asNumber(m.humidity),
        battery: asNumber(m.battery),
      });
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < 1000) break;
  }

  return out;
}

function buildEnvironmentAssessment(params: {
  readings: SwitchbotReading[];
  env: BreedingEnvironment | null;
  sourceDocCount: number;
  windowDays?: number;
  periodStart?: Date;
  periodEnd?: Date;
}) {
  const {
    readings,
    env,
    sourceDocCount,
    windowDays = WINDOW_DAYS,
    periodStart,
    periodEnd,
  } = params;

  const now = new Date();
  const start = periodStart ?? new Date(now.getTime() - windowDays * 24 * 60 * 60 * 1000);
  const end = periodEnd ?? now;

  const filtered = readings.filter((r) => {
    const d = parseIsoSafe(r.ts);
    return d !== null && d >= start && d < end;
  });

  if (filtered.length === 0) {
    return {
      status: 'no_recent',
      level: 'データ不足',
      headline:
        windowDays === 1
          ? 'この日の温湿度データが不足しています。'
          : `直近${windowDays}日の温湿度データが不足しています。`,
      todayAction: 'SwitchBot の記録が継続して入るか確認してみてください。',
      why: 'データが少ないと環境評価が安定しないからです。',
      avgTemp: null,
      avgHum: null,
      tempRatio: 0,
      humRatio: 0,
      spikesTemp: 0,
      spikesHum: 0,
      dangerMinutes: 0,
      evidence: [],
      notes: [],
      sourceDocCount,
      windowDays,
      version: 1,
    };
  }

  const temps: number[] = [];
  const hums: number[] = [];
  let spikesTemp = 0;
  let spikesHum = 0;
  let dangerMinutes = 0;

  let prev: SwitchbotReading | null = null;

  for (const r of filtered) {
    const t = r.temperature;
    const h = r.humidity;

    if (typeof t === 'number') temps.push(t);
    if (typeof h === 'number') hums.push(h);

    if (typeof t === 'number') {
      if (t < TEMP_DANGER_LOW || t > TEMP_DANGER_HIGH) {
        dangerMinutes += 10;
      }
    }

    if (prev) {
      if (typeof t === 'number' && typeof prev.temperature === 'number') {
        if (Math.abs(t - prev.temperature) >= TEMP_SPIKE_THRESHOLD) spikesTemp += 1;
      }
      if (typeof h === 'number' && typeof prev.humidity === 'number') {
        if (Math.abs(h - prev.humidity) >= HUM_SPIKE_THRESHOLD) spikesHum += 1;
      }
    }

    prev = r;
  }

  const tempInRange = temps.filter((t) => t >= TEMP_MIN && t <= TEMP_MAX).length;
  const humInRange = hums.filter((h) => h >= HUM_MIN && h <= HUM_MAX).length;

  const tempRatio = temps.length ? tempInRange / temps.length : 0;
  const humRatio = hums.length ? humInRange / hums.length : 0;
  const avgTemp = mean(temps);
  const avgHum = mean(hums);

  const { level, emoji } = levelFromMetrics({
    dangerMinutes,
    tempRatio,
    humRatio,
    spikesTemp,
    spikesHum,
  });

  const tempState =
    avgTemp == null ? '不明' : avgTemp < TEMP_MIN ? '低め' : avgTemp > TEMP_MAX ? '高め' : '適正';

  const humState =
    avgHum == null ? '不明' : avgHum < HUM_MIN ? '低め' : avgHum > HUM_MAX ? '高め' : '適正';

  const tempInterpretation =
    tempState === '適正'
      ? '温度はおおむね適正です。'
      : tempState === '低め'
        ? '温度はやや低めです。'
        : tempState === '高め'
          ? '温度はやや高めです。'
          : '温度情報が不足しています。';

  const humInterpretation =
    humState === '適正'
      ? '湿度はおおむね適正です。'
      : humState === '低め'
        ? '湿度はやや低めです。'
        : humState === '高め'
          ? '湿度はやや高めです。'
          : '湿度情報が不足しています。';

  const cageWidth = env?.cageWidth ?? null;
  const cageDepth = env?.cageDepth ?? null;
  const beddingThickness = env?.beddingThickness ?? null;
  const temperatureControl = env?.temperatureControl ?? null;

  let todayAction = '今の環境は概ね安定しています。このまま温湿度の推移を見守って大丈夫です。';
  let why = '大きな危険サインは見られないからです。';

  if (dangerMinutes > 0) {
    todayAction = 'まずは危険温度帯に入らないように空調を優先して調整してください。';
    why = '危険温度帯は健康リスクに直結するからです。';
  } else if (spikesTemp > 0 && temperatureControl === 'エアコン') {
    todayAction = 'エアコンの風がケージに直接当たっていないか確認してください。';
    why = '温度の急変が空調由来で起きている可能性があるからです。';
  } else if (humRatio < 0.7 && beddingThickness !== null && beddingThickness >= 5) {
    todayAction = '床材が厚めなら、通気性を少し改善して湿気のこもりを減らしてみてください。';
    why = '平均湿度が高めで、厚い床材は湿気がこもりやすいからです。';
  } else if (humRatio < 0.7 && humState === '高め') {
    todayAction = 'ケージ周辺の通気を少し見直して、湿度がこもりすぎないか確認してください。';
    why = '湿度がやや高めで推移しているからです。';
  }

  const notes: string[] = [];
  if (temperatureControl) notes.push(`現在の温度管理方法：${temperatureControl}`);
  if (cageWidth !== null && cageDepth !== null) notes.push(`ケージサイズ：${cageWidth}×${cageDepth}cm`);
  if (beddingThickness !== null) notes.push(`床材の厚み：${beddingThickness}cm`);

  const evidence: string[] = [];
  evidence.push(`温度適正率 ${fmtPct01(tempRatio)}`);
  evidence.push(`湿度適正率 ${fmtPct01(humRatio)}`);
  if (avgTemp !== null) evidence.push(`平均温度 ${avgTemp.toFixed(1)}℃`);
  if (avgHum !== null) evidence.push(`平均湿度 ${Math.round(avgHum)}%`);

  const headlineParts: string[] = [];
  if (avgTemp !== null) headlineParts.push(`平均${avgTemp.toFixed(1)}℃`);
  if (avgHum !== null) headlineParts.push(`平均${Math.round(avgHum)}%`);

  const headlineBase =
    headlineParts.length > 0
      ? headlineParts.join(' / ')
      : windowDays === 1
        ? 'この日の温湿度を評価しました'
        : `直近${windowDays}日の温湿度を評価しました`;

  const headline = `${emoji} ${level}：${headlineBase}`;

  return {
    status: 'ok',
    level,
    headline,
    tempState,
    humState,
    tempInterpretation,
    humInterpretation,
    todayAction,
    why,
    avgTemp,
    avgHum,
    tempRatio,
    humRatio,
    spikesTemp,
    spikesHum,
    dangerMinutes,
    evidence,
    notes,
    sourceDocCount,
    windowDays,
    version: 1,
  };
}

async function saveEnvironmentAssessmentLatest(uid: string): Promise<void> {
  const [env, readings] = await Promise.all([
    fetchBreedingEnvironment(uid),
    fetchRecentSwitchbotReadings(uid, 1000),
  ]);

  // latest は「直近7日評価」
  const latestAssessment = buildEnvironmentAssessment({
    readings,
    env,
    sourceDocCount: readings.length,
    windowDays: WINDOW_DAYS,
  });

  const evaluatedAt = new Date();

  await db
    .collection('users')
    .doc(uid)
    .collection('environment_assessments')
    .doc('latest')
    .set(
      {
        ...latestAssessment,
        evaluatedAt: admin.firestore.Timestamp.fromDate(evaluatedAt),
      },
      { merge: true },
    );

  // history は「当日1日評価」
  const todayRange = getJstDayRange(evaluatedAt);
  const dailyAssessment = buildEnvironmentAssessment({
    readings,
    env,
    sourceDocCount: readings.length,
    windowDays: 1,
    periodStart: todayRange.startUtc,
    periodEnd: todayRange.endUtc,
  });

  await saveEnvironmentAssessmentHistoryDaily(uid, dailyAssessment, evaluatedAt);

  logger.info('saveEnvironmentAssessmentLatest done', {
    uid,
    latestLevel: latestAssessment.level,
    dailyLevel: dailyAssessment.level,
    sourceDocCount: readings.length,
  });

  // ===== 異常検知通知パイプライン =====
  try {
    const notificationResult = await executeAnomalyNotificationPipeline({
      db,
      messaging: admin.messaging(),
      uid,
      windowDays: 14,
      now: evaluatedAt,
    });

    logger.info('executeAnomalyNotificationPipeline done', {
      uid,
      shouldNotify: notificationResult.decision.shouldNotify,
      reason: notificationResult.decision.reason,
      notificationKey: notificationResult.notificationKey,
      tokenCount: notificationResult.tokenCount,
      sentCount: notificationResult.sentCount,
      failedCount: notificationResult.failedCount,
      noTokens: notificationResult.noTokens,
    });
  } catch (e: any) {
    logger.error('executeAnomalyNotificationPipeline error', {
      uid,
      error: String(e?.message ?? e),
    });
  }
}

async function saveEnvironmentAssessmentHistoryDaily(
  uid: string,
  assessment: ReturnType<typeof buildEnvironmentAssessment>,
  evaluatedAt: Date,
): Promise<void> {
  const dateKey = toDateKeyJst(evaluatedAt);

  await db
    .collection('users')
    .doc(uid)
    .collection('environment_assessments_history')
    .doc(dateKey)
    .set(
      {
        ...assessment,
        dateKey,
        date: dateKey,
        aggregatedUnit: 'day',
        lastEvaluatedAt: admin.firestore.Timestamp.fromDate(evaluatedAt),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  logger.info('saveEnvironmentAssessmentHistoryDaily done', {
    uid,
    dateKey,
    level: assessment.level,
    status: assessment.status,
  });
}

async function pollAllUsersOnce(): Promise<PollAllResult> {
  const usersSnap = await db.collection('switchbot_users').where('hasSwitchbot', '==', true).get();

  let saved = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of usersSnap.docs) {
    const uid = doc.id;
    try {
      const { token, secret, meterDeviceId } = await loadUserConfig(uid);
      if (!token || !secret || !meterDeviceId) {
        skipped++;
        logger.info('pollAllUsersOnce skip', {
          uid,
          reason: !token || !secret ? 'missing_secrets' : 'missing_meterDeviceId',
        });
        continue;
      }

      const status = await getMeterStatus(meterDeviceId, token, secret);
      await saveReading(uid, status);
      await saveEnvironmentAssessmentLatest(uid);
      saved++;
    } catch (e: any) {
      failed++;
      logger.error('pollAllUsersOnce error', { uid, error: String(e?.message ?? e) });
    }
  }

  const result = { total: usersSnap.size, saved, skipped, failed };
  logger.info('pollAllUsersOnce result', result);
  return result;
}

/* =================================================================== */
/*  連携解除: disableSwitchbotIntegration                              */
/* =================================================================== */

export const disableSwitchbotIntegration = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const deleteReadings = !!req.data?.deleteReadings;

    const userRef = db.collection('users').doc(uid);
    const integCol = userRef.collection('integrations');
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db.batch();

    batch.set(
      integCol.doc('switchbot'),
      {
        meterDeviceId: admin.firestore.FieldValue.delete(),
        meterDeviceName: admin.firestore.FieldValue.delete(),
        meterDeviceType: admin.firestore.FieldValue.delete(),
        enabled: false,
        disabledAt: now,
      },
      { merge: true },
    );

    batch.set(
      integCol.doc('switchbot_secrets'),
      {
        v1_plain: admin.firestore.FieldValue.delete(),
        v1: admin.firestore.FieldValue.delete(),
        disabledAt: now,
      },
      { merge: true },
    );

    batch.set(
      db.collection('switchbot_users').doc(uid),
      { hasSwitchbot: false, disabledAt: now, updatedAt: now },
      { merge: true },
    );

    await batch.commit();

    let deletedReadings = 0;
    if (deleteReadings) {
      const snap = await userRef.collection('switchbot_readings').limit(500).get();
      if (!snap.empty) {
        const b2 = db.batch();
        snap.docs.forEach((d) => {
          b2.delete(d.ref);
          deletedReadings++;
        });
        await b2.commit();
      }
    }

    return { ok: true, deletedReadings };
  },
);

/** Debug: token/secret がちゃんと読めているか head/tail を返す */
export const switchbotDebugEcho = onCall({ region: 'asia-northeast1' }, async (req) => {
  if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };
  const { token, secret, meterDeviceId } = await loadUserConfig(req.auth.uid);

  const headTail = (s?: string) => (!s ? null : { head: s.slice(0, 5), len: s.length, tail: s.slice(-5) });

  return { ok: true, uid: req.auth.uid, meterDeviceId, token: headTail(token), secret: headTail(secret) };
});

export const pollMySwitchbotNow = onCall({ region: 'asia-northeast1' }, async (req) => {
  if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };
  try {
    const { token, secret, meterDeviceId } = await loadUserConfig(req.auth.uid);
    if (!token || !secret || !meterDeviceId) {
      return { ok: false, uid: req.auth.uid, error: 'missing config (token/secret/deviceId)' };
    }
    const status = await getMeterStatus(meterDeviceId, token, secret);
    await saveReading(req.auth.uid, status);
    await saveEnvironmentAssessmentLatest(req.auth.uid);

    logger.info('pollMySwitchbotNow success', {
      uid: req.auth.uid,
      meterDeviceId,
    });

    return { ok: true, uid: req.auth.uid, saved: 1, status };
  } catch (e: any) {
    logger.error('pollMine error', { uid: req.auth?.uid, error: String(e?.message ?? e) });
    return { ok: false, uid: req.auth?.uid ?? null, error: String(e?.message ?? e) };
  }
});

/* =================================================================== */
/*  Flutter から呼ぶ本命: listSwitchbotDevices                         */
/* =================================================================== */

export const listSwitchbotDevices = onCall({ region: 'asia-northeast1' }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', '認証ユーザーのみが呼び出せます。');

  const { token, secret } = await loadUserConfig(uid);
  if (!token || !secret) {
    throw new HttpsError('failed-precondition', 'SwitchBot の TOKEN / SECRET が登録されていません。');
  }

  const url = 'https://api.switch-bot.com/v1.1/devices';
  const res = await fetch(url, { headers: buildHeaders(token, secret) });
  const text = await res.text().catch(() => '');
  let json: any = null;
  try { json = JSON.parse(text); } catch {}

  if (!res.ok) {
    if (res.status === 401 || res.status === 403) {
      throw new HttpsError('permission-denied', 'SwitchBot の TOKEN/SECRET が正しくありません（認証に失敗しました）。');
    }
    throw new HttpsError('unavailable', `SwitchBot /devices error ${res.status}: ${text.slice(0, 300)}`);
  }

  const body = json?.body ?? {};
  const devices = Array.isArray(body.deviceList) ? body.deviceList : [];

  return { ok: true, devices, body };
});

export const backfillMyEnvironmentAssessmentsHistory = onCall(
  { region: 'asia-northeast1', timeoutSeconds: 540, memory: '1GiB' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'ログインが必要です。');
    }

    try {
      const [env, allReadings] = await Promise.all([
        fetchBreedingEnvironment(uid),
        fetchAllSwitchbotReadings(uid),
      ]);

      if (allReadings.length === 0) {
        return {
          ok: true,
          uid,
          message: 'switchbot_readings が0件のため、バックフィル対象がありません。',
          totalReadings: 0,
          totalDays: 0,
          writtenDays: 0,
        };
      }

      const grouped = new Map<string, SwitchbotReading[]>();

      for (const r of allReadings) {
        const d = parseIsoSafe(r.ts);
        if (!d) continue;

        const dateKey = toDateKeyJst(d);
        if (!grouped.has(dateKey)) {
          grouped.set(dateKey, []);
        }
        grouped.get(dateKey)!.push(r);
      }

      const dateKeys = Array.from(grouped.keys()).sort();

      const docs: Array<{ dateKey: string; data: FirebaseFirestore.DocumentData }> = [];

      for (const dateKey of dateKeys) {
        const dayReadings = grouped.get(dateKey) ?? [];
        const range = getJstDayRangeFromDateKey(dateKey);

        const assessment = buildEnvironmentAssessment({
          readings: dayReadings,
          env,
          sourceDocCount: dayReadings.length,
          windowDays: 1,
          periodStart: range.startUtc,
          periodEnd: range.endUtc,
        });

        docs.push({
          dateKey,
          data: {
            ...assessment,
            dateKey,
            date: dateKey,
            aggregatedUnit: 'day',
            lastEvaluatedAt: admin.firestore.Timestamp.fromDate(range.endUtc),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            backfilledAt: admin.firestore.FieldValue.serverTimestamp(),
            source: 'backfill_v1',
          },
        });
      }

      for (const chunk of chunkArray(docs, 400)) {
        const batch = db.batch();

        for (const item of chunk) {
          const ref = db
            .collection('users')
            .doc(uid)
            .collection('environment_assessments_history')
            .doc(item.dateKey);

          batch.set(ref, item.data, { merge: true });
        }

        await batch.commit();
      }

      logger.info('backfillMyEnvironmentAssessmentsHistory done', {
        uid,
        totalReadings: allReadings.length,
        totalDays: dateKeys.length,
      });

      return {
        ok: true,
        uid,
        totalReadings: allReadings.length,
        totalDays: dateKeys.length,
        writtenDays: dateKeys.length,
        firstDateKey: dateKeys[0] ?? null,
        lastDateKey: dateKeys[dateKeys.length - 1] ?? null,
      };
    } catch (e: any) {
      logger.error('backfillMyEnvironmentAssessmentsHistory error', {
        uid,
        error: String(e?.message ?? e),
      });
      throw new HttpsError(
        'internal',
        `バックフィルに失敗しました: ${String(e?.message ?? e)}`,
      );
    }
  },
);


/* ===== HTTP: 手動で叩きたいとき用 ===== */

export const switchbotPollNow = onRequest({ region: 'asia-northeast1' }, async (_req, res) => {
  const result = await pollAllUsersOnce();
  res.json({ ok: true, ...result });
});

/* ===== Scheduler ===== */

export const switchbotPoller = onSchedule(
  { region: 'asia-northeast1', schedule: 'every 15 minutes' },
  async () => {
    await pollAllUsersOnce();
  },
);