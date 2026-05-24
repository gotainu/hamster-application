// functions/src/index.ts

import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import crypto from 'crypto';
import { executeAnomalyNotificationPipeline } from './anomalyNotification';
import { defineSecret } from 'firebase-functions/params';

admin.initializeApp();
const db = admin.firestore();
const ENVELOPE_KEY_SECRET = defineSecret('ENVELOPE_KEY');

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

function wrapSecret(plain: string): string {
  const key = getEnvelopeKey();
  const iv = crypto.randomBytes(12);

  const enc = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ct = Buffer.concat([
    enc.update(plain, 'utf8'),
    enc.final(),
  ]);

  const tag = enc.getAuthTag();

  // format: base64(iv + ciphertext + tag)
  return Buffer.concat([iv, ct, tag]).toString('base64');
}

function unwrapSecret(b64: string): string {
  const key = getEnvelopeKey();
  const buf = Buffer.from(b64, 'base64');

  if (buf.length < 12 + 16 + 1) {
    throw new Error('encrypted secret is too short');
  }

  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(buf.length - 16);
  const ct = buf.subarray(12, buf.length - 16);

  const dec = crypto.createDecipheriv('aes-256-gcm', key, iv);
  dec.setAuthTag(tag);

  return Buffer.concat([
    dec.update(ct),
    dec.final(),
  ]).toString('utf8');
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

/** ★ TOKEN / SECRET を “検証してから” 暗号化保存（v2_encrypted） */
export const registerSwitchbotSecrets = onCall(
  { 
    region: 'asia-northeast1',
    secrets: [ENVELOPE_KEY_SECRET],
   },
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

    const userRef = db.collection('users').doc(uid);
    const integCol = userRef.collection('integrations');
    const secretsRef = integCol.doc('switchbot_secrets');
    const switchbotRef = integCol.doc('switchbot');
    const switchbotUserRef = db.collection('switchbot_users').doc(uid);

    const encryptedToken = wrapSecret(token);
    const encryptedSecret = wrapSecret(secret);

    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db.batch();

    batch.set(
      secretsRef,
      {
        v2_encrypted: {
          token: encryptedToken,
          secret: encryptedSecret,
          algorithm: 'aes-256-gcm',
          keyRef: 'functions-secret:ENVELOPE_KEY',
          updatedAt: now,
        },
        v1_plain: admin.firestore.FieldValue.delete(),
        v1: admin.firestore.FieldValue.delete(),
        disabledAt: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );

    batch.set(
      switchbotRef,
      {
        enabled: true,
        hasSecrets: true,
        authVersion: 'v2_encrypted',
        secretsUpdatedAt: now,
        disabledAt: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );

    batch.set(
      switchbotUserRef,
      {
        hasSwitchbot: true,
        updatedAt: now,
        disabledAt: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );

    await batch.commit();

    const verifySnap = await secretsRef.get();

    return {
      ok: true,
      verified: true,
      uid,
      projectId: process.env.GCLOUD_PROJECT ?? null,
      debugMarker: 'registerSwitchbotSecrets_v2_encrypted_20260523',
      savedDocExists: verifySnap.exists,
      savedPath: secretsRef.path,
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

  // prefer v2_encrypted
  const v2 = (secSnap.exists ? (secSnap.get('v2_encrypted') as any) : null) ?? null;
  if (v2 && typeof v2 === 'object') {
    try {
      const t = typeof v2.token === 'string' ? unwrapSecret(v2.token) : undefined;
      const s = typeof v2.secret === 'string' ? unwrapSecret(v2.secret) : undefined;

      if (typeof t === 'string') token = t;
      if (typeof s === 'string') secret = s;
    } catch (e: any) {
      logger.error('failed to decrypt v2_encrypted switchbot secrets', {
        uid,
        error: String(e?.message ?? e),
      });
    }
  }

  // fallback to v1_plain during migration
  if (!token || !secret) {
    const v1p = (secSnap.exists ? (secSnap.get('v1_plain') as any) : null) ?? null;
    if (v1p && typeof v1p === 'object') {
      token = typeof v1p.token === 'string' ? v1p.token : token;
      secret = typeof v1p.secret === 'string' ? v1p.secret : secret;
    }
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
  } else if (humRatio < 0.7 && humState === '高め') {
  todayAction = 'まずは部屋全体の湿度・ケージ周辺の風通し・濡れた床材がないかを確認してください。床材の厚み自体は、掘る行動を支える大切な要素なので、安易に減らす必要はありません。';
  why = '平均湿度が高めで推移していますが、床材の厚さそのものよりも、部屋の湿度・通気・局所的な濡れや汚れが影響している可能性を先に確認したいからです。';
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

type EnvironmentAssessmentForAi = ReturnType<typeof buildEnvironmentAssessment>;

type TrendDirection = 'improving' | 'worsening' | 'stable' | 'unknown';
type TrendMainMetric = 'temperature' | 'humidity' | 'overall';

type LatestTrendSummary = {
  direction: TrendDirection;
  mainMetric: TrendMainMetric;
  summary: string;
  deltaText: string;
  currentHumRatio: number | null;
  previousHumRatio: number | null;
  currentTempRatio: number | null;
  previousTempRatio: number | null;
};

type LatestAnomalySummary = {
  hasAnomaly: boolean;
  topTitle: string | null;
  severity: 'info' | 'low' | 'medium' | 'high' | null;
  description: string | null;
  flags: string[];
};

type SensorEvaluationSummary = {
  overallState: 'good' | 'caution' | 'alert' | 'unknown';
  flags: string[];
};

type AiAdvisorContext = {
  status: 'available' | 'insufficient_data';
  summary: string;
  priority: string | null;
  promptText: string;
  generatedAt: FirebaseFirestore.Timestamp;
  version: number;
};

async function fetchRecentEnvironmentHistory(
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
      lastEvaluatedAt: null,
      updatedAt: null,
    } as HistoryRow;
  });

  rows.sort((a, b) => String(a.dateKey ?? '').localeCompare(String(b.dateKey ?? '')));
  return rows;
}

function averageNullable(values: Array<number | null | undefined>): number | null {
  const nums = values.filter((v): v is number => typeof v === 'number' && Number.isFinite(v));
  if (nums.length === 0) return null;
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

function buildTrendSummary(params: {
  latest: EnvironmentAssessmentForAi;
  history: HistoryRow[];
}): LatestTrendSummary {
  const { latest, history } = params;

  const currentTempRatio =
    typeof latest.tempRatio === 'number' ? latest.tempRatio : null;
  const currentHumRatio =
    typeof latest.humRatio === 'number' ? latest.humRatio : null;

  if (history.length < 4 || currentTempRatio == null || currentHumRatio == null) {
    return {
      direction: 'unknown',
      mainMetric: 'overall',
      summary: '推移を判断するには、もう少し履歴データが必要です。',
      deltaText: '比較データ不足',
      currentHumRatio,
      previousHumRatio: null,
      currentTempRatio,
      previousTempRatio: null,
    };
  }

  const recent = history.slice(-3);
  const previous = history.slice(0, Math.max(0, history.length - 3));

  const previousTempRatio = averageNullable(previous.map((e) => e.tempRatio));
  const previousHumRatio = averageNullable(previous.map((e) => e.humRatio));

  if (previousTempRatio == null || previousHumRatio == null) {
    return {
      direction: 'unknown',
      mainMetric: 'overall',
      summary: '過去平均との差分を判断するには、もう少し履歴データが必要です。',
      deltaText: '比較データ不足',
      currentHumRatio,
      previousHumRatio,
      currentTempRatio,
      previousTempRatio,
    };
  }

  const recentTempRatio = averageNullable(recent.map((e) => e.tempRatio)) ?? currentTempRatio;
  const recentHumRatio = averageNullable(recent.map((e) => e.humRatio)) ?? currentHumRatio;

  const tempDelta = recentTempRatio - previousTempRatio;
  const humDelta = recentHumRatio - previousHumRatio;

  const absTempDelta = Math.abs(tempDelta);
  const absHumDelta = Math.abs(humDelta);

  const mainMetric: TrendMainMetric =
    absHumDelta >= absTempDelta ? 'humidity' : 'temperature';

  const mainDelta = mainMetric === 'humidity' ? humDelta : tempDelta;
  const mainLabel = mainMetric === 'humidity' ? '湿度' : '温度';
  const deltaPt = Math.round(mainDelta * 100);

  let direction: TrendDirection = 'stable';
  if (mainDelta >= 0.10) {
    direction = 'improving';
  } else if (mainDelta <= -0.10) {
    direction = 'worsening';
  }

  const deltaText =
    direction === 'stable'
      ? `${mainLabel}の適正率は大きく変わっていません。`
      : `${mainLabel}の適正率が過去平均との差で${deltaPt >= 0 ? '+' : ''}${deltaPt}pt変化しています。`;

  let summary = '温湿度の推移はおおむね安定しています。';

  if (direction === 'improving') {
    summary = `${mainLabel}は以前より改善傾向です。`;
  } else if (direction === 'worsening') {
    summary = `${mainLabel}は以前より悪化傾向です。`;
  } else if (currentHumRatio !== null && currentHumRatio < 0.6) {
    summary = '湿度はまだ不安定ですが、急激な悪化は見られません。';
  }

  return {
    direction,
    mainMetric,
    summary,
    deltaText,
    currentHumRatio,
    previousHumRatio,
    currentTempRatio,
    previousTempRatio,
  };
}

function buildLightweightAnomalySummary(params: {
  latest: EnvironmentAssessmentForAi;
  history: HistoryRow[];
}): LatestAnomalySummary {
  const { latest, history } = params;
  const flags: string[] = [];

  const sorted = [...history].sort((a, b) =>
    String(a.dateKey ?? '').localeCompare(String(b.dateKey ?? '')),
  );

  const tailCount = (predicate: (row: HistoryRow) => boolean): number => {
    let count = 0;
    for (let i = sorted.length - 1; i >= 0; i--) {
      if (predicate(sorted[i])) count++;
      else break;
    }
    return count;
  };

  const highHumStreak = tailCount(
    (e) => (e.avgHum ?? Number.NEGATIVE_INFINITY) > HUM_MAX,
  );
  const lowTempStreak = tailCount(
    (e) => (e.avgTemp ?? Number.POSITIVE_INFINITY) < TEMP_MIN,
  );
  const highTempStreak = tailCount(
    (e) => (e.avgTemp ?? Number.NEGATIVE_INFINITY) > TEMP_MAX,
  );
  const cautionStreak = tailCount((e) => e.level === '注意');

  const recent3 = sorted.length <= 3 ? sorted : sorted.slice(sorted.length - 3);
  const dangerHit = recent3.some((e) => e.level === '危険');
  const dangerMinutesMax = recent3.reduce(
    (max, e) => Math.max(max, e.dangerMinutes ?? 0),
    0,
  );
  const tempSpikeTotal = recent3.reduce((sum, e) => sum + (e.spikesTemp ?? 0), 0);
  const humSpikeTotal = recent3.reduce((sum, e) => sum + (e.spikesHum ?? 0), 0);

  if (highHumStreak >= 3) flags.push('humidityHighStreak');
  if (lowTempStreak >= 3) flags.push('temperatureLowStreak');
  if (highTempStreak >= 3) flags.push('temperatureHighStreak');
  if (cautionStreak >= 3) flags.push('cautionLevelStreak');
  if (dangerHit || dangerMinutesMax > 0) flags.push('dangerDetected');
  if (tempSpikeTotal >= 3) flags.push('temperatureSpike');
  if (humSpikeTotal >= 3) flags.push('humiditySpike');

  if (dangerHit || dangerMinutesMax >= 30) {
    return {
      hasAnomaly: true,
      topTitle: '危険評価が検出されています',
      severity: 'high',
      description: '直近の環境評価で危険サインが出ています。温度・湿度・行動の変化を優先して確認してください。',
      flags,
    };
  }

  if (highHumStreak >= 5) {
    const hum =
      typeof latest.avgHum === 'number' ? Math.round(latest.avgHum) : null;
    return {
      hasAnomaly: true,
      topTitle: '高湿が続いています',
      severity: 'high',
      description:
        hum != null
          ? `湿度が高めの状態が${highHumStreak}日連続です。最新の平均湿度は${hum}%です。`
          : `湿度が高めの状態が${highHumStreak}日連続です。`,
      flags,
    };
  }

  if (highTempStreak >= 5 || lowTempStreak >= 5) {
    const isHigh = highTempStreak >= 5;
    const streak = isHigh ? highTempStreak : lowTempStreak;
    return {
      hasAnomaly: true,
      topTitle: isHigh ? '高温が続いています' : '低温が続いています',
      severity: 'high',
      description: `温度が${isHigh ? '高め' : '低め'}の状態が${streak}日連続です。`,
      flags,
    };
  }

  if (highHumStreak >= 3) {
    return {
      hasAnomaly: true,
      topTitle: '湿度が高めです',
      severity: 'medium',
      description: `湿度が高めの状態が${highHumStreak}日連続です。`,
      flags,
    };
  }

  if (tempSpikeTotal >= 3 || humSpikeTotal >= 3) {
    return {
      hasAnomaly: true,
      topTitle: '温湿度の急変が見られます',
      severity: tempSpikeTotal >= 6 || humSpikeTotal >= 6 ? 'high' : 'medium',
      description: `直近3日で温度急変${tempSpikeTotal}回、湿度急変${humSpikeTotal}回が記録されています。`,
      flags,
    };
  }

  if (cautionStreak >= 3) {
    return {
      hasAnomaly: true,
      topTitle: '注意評価が続いています',
      severity: cautionStreak >= 5 ? 'high' : 'medium',
      description: `環境評価の「注意」が${cautionStreak}日連続です。`,
      flags,
    };
  }

  return {
    hasAnomaly: false,
    topTitle: null,
    severity: null,
    description: null,
    flags,
  };
}

function buildSensorEvaluationSummary(params: {
  latest: EnvironmentAssessmentForAi;
  anomaly: LatestAnomalySummary;
}): SensorEvaluationSummary {
  const { latest, anomaly } = params;
  const flags = new Set<string>(anomaly.flags);

  if (latest.humState === '高め') flags.add('humidityHigh');
  if (latest.humState === '低め') flags.add('humidityLow');
  if (latest.tempState === '高め') flags.add('temperatureHigh');
  if (latest.tempState === '低め') flags.add('temperatureLow');
  if ((latest.dangerMinutes ?? 0) > 0) flags.add('dangerMinutesDetected');
  if ((latest.spikesTemp ?? 0) > 0) flags.add('temperatureSpike');
  if ((latest.spikesHum ?? 0) > 0) flags.add('humiditySpike');

  let overallState: SensorEvaluationSummary['overallState'] = 'unknown';

  if (latest.status !== 'ok') {
    overallState = 'unknown';
  } else if (latest.level === '危険' || anomaly.severity === 'high') {
    overallState = 'alert';
  } else if (latest.level === '注意' || anomaly.hasAnomaly) {
    overallState = 'caution';
  } else if (latest.level === '良好') {
    overallState = 'good';
  }

  return {
    overallState,
    flags: Array.from(flags),
  };
}

function buildAiAdvisorContext(params: {
  latest: EnvironmentAssessmentForAi;
  trend: LatestTrendSummary;
  anomaly: LatestAnomalySummary;
  sensorEvaluation: SensorEvaluationSummary;
  evaluatedAt: Date;
}): AiAdvisorContext {
  const { latest, trend, anomaly, sensorEvaluation, evaluatedAt } = params;

  if (latest.status !== 'ok') {
    return {
      status: 'insufficient_data',
      summary: '温湿度データが不足しているため、AI相談で参照できる環境評価は限定的です。',
      priority: 'SwitchBotの記録が継続して入っているか確認してください。',
      promptText:
        '【現在のセンサー評価】\n' +
        '温湿度データが不足しています。環境評価は参考程度に扱ってください。\n' +
        `状態: ${latest.headline}\n` +
        `今日やること: ${latest.todayAction}\n`,
      generatedAt: admin.firestore.Timestamp.fromDate(evaluatedAt),
      version: 1,
    };
  }

  const avgTempText =
    typeof latest.avgTemp === 'number' ? `${latest.avgTemp.toFixed(1)}℃` : '不明';
  const avgHumText =
    typeof latest.avgHum === 'number' ? `${Math.round(latest.avgHum)}%` : '不明';

  const tempRatioText =
    typeof latest.tempRatio === 'number' ? fmtPct01(latest.tempRatio) : '不明';
  const humRatioText =
    typeof latest.humRatio === 'number' ? fmtPct01(latest.humRatio) : '不明';

  const anomalyText = anomaly.hasAnomaly
    ? [
        anomaly.topTitle ?? '気になる変化があります',
        anomaly.description ?? '',
        anomaly.severity ? `重要度: ${anomaly.severity}` : '',
      ].filter(Boolean).join('\n')
    : '目立った異常検知はありません。';

  const priority =
    anomaly.severity === 'high'
      ? anomaly.description
      : latest.todayAction ?? null;

  const promptText = [
    '【現在のセンサー評価】',
    `総合評価: ${latest.level}`,
    `見出し: ${latest.headline}`,
    `平均温度: ${avgTempText}`,
    `平均湿度: ${avgHumText}`,
    `温度適正率: ${tempRatioText}`,
    `湿度適正率: ${humRatioText}`,
    `温度の解釈: ${latest.tempInterpretation ?? ''}`,
    `湿度の解釈: ${latest.humInterpretation ?? ''}`,
    `今日やること: ${latest.todayAction}`,
    `理由: ${latest.why}`,
    '',
    '【最近の推移】',
    trend.summary,
    trend.deltaText,
    '',
    '【最近の気になる変化】',
    anomalyText,
    '',
    '【注意フラグ】',
    sensorEvaluation.flags.length > 0
      ? sensorEvaluation.flags.join(', ')
      : '特になし',
    '',
    '【回答方針】',
'ユーザーの質問に関係する場合だけ、上記のセンサー評価を自然に参照してください。',
'関係ない質問では、無理に温湿度や異常検知へ言及しないでください。',
'体調不良の可能性がある相談では、センサー情報だけで病気や原因を断定しないでください。',
'必要に応じて「環境要因としては」という表現で、観察・環境調整・受診検討を分けて提案してください。',
'床材が十分に深い場合は、その厚みをまず肯定してください。',
'高湿対策として、床材を安易に減らす・掘り返す・全交換する提案は避けてください。',
'湿度が高い場合は、まず部屋全体の湿度、ケージ周辺の風通し、エアコンや除湿、濡れた床材・汚れた部分の局所確認を優先してください。',
'床材の交換や除去を提案する場合は、濡れている・カビ臭い・汚れているなどの明確な根拠がある場合に限定してください。',
  ].join('\n');

  const summary = anomaly.hasAnomaly
    ? `${latest.level}。${anomaly.topTitle ?? '気になる変化があります'}`
    : `${latest.level}。${trend.summary}`;

  return {
    status: 'available',
    summary,
    priority,
    promptText,
    generatedAt: admin.firestore.Timestamp.fromDate(evaluatedAt),
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

  // AI相談用に、直近履歴から trend / anomaly / prompt context を生成
  const recentHistory = await fetchRecentEnvironmentHistory(uid, 14);

  const trend = buildTrendSummary({
    latest: latestAssessment,
    history: recentHistory,
  });

  const anomaly = buildLightweightAnomalySummary({
    latest: latestAssessment,
    history: recentHistory,
  });

  const sensorEvaluation = buildSensorEvaluationSummary({
    latest: latestAssessment,
    anomaly,
  });

  const aiAdvisorContext = buildAiAdvisorContext({
    latest: latestAssessment,
    trend,
    anomaly,
    sensorEvaluation,
    evaluatedAt,
  });

  await db
    .collection('users')
    .doc(uid)
    .collection('environment_assessments')
    .doc('latest')
    .set(
      {
        ...latestAssessment,
        trend,
        anomaly,
        sensorEvaluation,
        aiAdvisorContext,
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
    trendDirection: trend.direction,
    trendSummary: trend.summary,
    hasAnomaly: anomaly.hasAnomaly,
    anomalySeverity: anomaly.severity,
    aiAdvisorContextStatus: aiAdvisorContext.status,
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
        hasSecrets: false,
        disabledAt: now,
      },
      { merge: true },
    );

    batch.set(
      integCol.doc('switchbot_secrets'),
      {
        v2_encrypted: admin.firestore.FieldValue.delete(),
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
export const switchbotDebugEcho = onCall(
  { 
    region: 'asia-northeast1',
    secrets: [ENVELOPE_KEY_SECRET],
  }, 
  async (req) => {
    if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };
    const { token, secret, meterDeviceId } = await loadUserConfig(req.auth.uid);
    const headTail = (s?: string) => (!s ? null : { head: s.slice(0, 5), len: s.length, tail: s.slice(-5) });
    return { ok: true, uid: req.auth.uid, meterDeviceId, token: headTail(token), secret: headTail(secret) };
    }
  );

export const pollMySwitchbotNow = onCall(
  { 
    region: 'asia-northeast1',
    secrets: [ENVELOPE_KEY_SECRET],
  },
  async (req) => {
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
        }
      );

    return { ok: true, uid: req.auth.uid, saved: 1, status };
  } catch (e: any) {
    logger.error('pollMine error', { uid: req.auth?.uid, error: String(e?.message ?? e) });
    return { ok: false, uid: req.auth?.uid ?? null, error: String(e?.message ?? e) };
  }
});

/* =================================================================== */
/*  Flutter から呼ぶ本命: listSwitchbotDevices                         */
/* =================================================================== */

export const listSwitchbotDevices = onCall(
  {
    region: 'asia-northeast1',
    secrets: [ENVELOPE_KEY_SECRET],
  },
  async (req) => {
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

export const switchbotPollNow = onRequest(
  {
    region: 'asia-northeast1',
    secrets: [ENVELOPE_KEY_SECRET],
  },
  async (_req, res) => {
  const result = await pollAllUsersOnce();
  res.json({ ok: true, ...result });
});

/* ===== Scheduler ===== */

export const switchbotPoller = onSchedule(
  {
    region: 'asia-northeast1',
    secrets: [ENVELOPE_KEY_SECRET],
    schedule: 'every 60 minutes',
  },
  async () => {
    await pollAllUsersOnce();
  },
);