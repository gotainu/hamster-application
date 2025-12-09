// functions/src/index.ts

import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import crypto from 'crypto';

admin.initializeApp();
const db = admin.firestore();

/** ---- Envelope 復号 ----
 * Firestore には Base64 で [iv(12) | ciphertext | tag(16)] が入っている想定。
 * ENVELOPE_KEY は 32byte（ raw/hex/base64 どれでもOK） */
function getEnvelopeKey(): Buffer {
  const raw = process.env.ENVELOPE_KEY || '';
  if (!raw) throw new Error('ENVELOPE_KEY is not set');
  // 32byte raw / base64 / hex を許容
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
    // “十分な長さ”があり、iv/tag を切り出せるなら復号を試す
    if (buf.length >= 12 + 16 + 1) {
      const iv = buf.subarray(0, 12);
      const tag = buf.subarray(buf.length - 16);
      const ct = buf.subarray(12, buf.length - 16);
      const key = getEnvelopeKey();
      const dec = crypto.createDecipheriv('aes-256-gcm', key, iv);
      dec.setAuthTag(tag);
      const plain = Buffer.concat([dec.update(ct), dec.final()]).toString(
        'utf8',
      );
      return plain; // 復号成功
    }
  } catch {
    // Base64 でない/復号失敗 → 平文とみなす
  }
  return b64OrPlain;
}

/** ★ TOKEN / SECRET を “平文” で保存（v1_plain）。Flutter の「検証して保存」が叩く想定 */
export const registerSwitchbotSecrets = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };

    const token = String(req.data?.token ?? '').trim();
    const secret = String(req.data?.secret ?? '').trim();

    const hex64 = /^[0-9a-f]{40,}$/i; // token は長い16進
    const hexMin = /^[0-9a-f]{24,}$/i; // secret は24桁以上の16進

    if (!hex64.test(token))
      return { ok: false, error: 'token must be hex string' };
    if (!hexMin.test(secret))
      return { ok: false, error: 'secret must be hex string' };

    const docRef = db
      .collection('users')
      .doc(req.auth.uid)
      .collection('integrations')
      .doc('switchbot_secrets');

    await docRef.set(
      {
        v1_plain: {
          token,
          secret,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );

    // SwitchBot 連携ユーザー一覧に登録 / 再登録
    await db
      .collection('switchbot_users')
      .doc(req.auth.uid)
      .set(
        {
          hasSwitchbot: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    return { ok: true };
  },
);

/** SwitchBot auth header (signVersion=1)  */
function buildHeaders(token: string, secret: string) {
  const t = Date.now().toString();
  const nonce = crypto.randomUUID();
  const sign = crypto
    .createHmac('sha256', secret)
    .update(token + t + nonce)
    .digest('base64');

  return {
    'Content-Type': 'application/json; charset=utf-8',
    Authorization: token,
    t,
    sign,
    signVersion: '1',
    nonce,
  };
}

/** Firestore からユーザーの SwitchBot 設定を読み出す
 *  - v1_plain（平文）を最優先
 *  - レガシー v1（平文）があればフォールバック
 */
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

  // fallback to legacy v1 (only if they are actually plain strings)
  if (!token || !secret) {
    const v1 = (secSnap.exists ? (secSnap.get('v1') as any) : null) ?? null;
    if (v1 && typeof v1 === 'object') {
      const t = v1.token;
      const s = v1.secret;
      if (
        typeof t === 'string' &&
        !t.includes('/') &&
        !t.includes('+') &&
        !t.endsWith('=')
      )
        token = token ?? t;
      if (
        typeof s === 'string' &&
        !s.includes('/') &&
        !s.includes('+') &&
        !s.endsWith('=')
      )
        secret = secret ?? s;
    }
  }

  const meterDeviceId = swSnap.exists
    ? (swSnap.get('meterDeviceId') as string | undefined)
    : undefined;

  return { token, secret, meterDeviceId };
}

/** 温湿度計 1台分の /status を取得 */
async function getMeterStatus(
  deviceId: string,
  token: string,
  secret: string,
) {
  const url = `https://api.switch-bot.com/v1.1/devices/${deviceId}/status`;
  const res = await fetch(url, {
    method: 'GET',
    headers: buildHeaders(token, secret),
  });

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
  await db
    .collection('users')
    .doc(uid)
    .collection('switchbot_readings')
    .doc(ts)
    .set(
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

/* ===== 共通ロジック: 全ユーザー分を1回ポーリングする ===== */

type PollAllResult = {
  total: number;
  saved: number;
  skipped: number;
  failed: number;
};

async function pollAllUsersOnce(): Promise<PollAllResult> {
  // SwitchBot 連携が有効なユーザーだけ
  const usersSnap = await db
    .collection('switchbot_users')
    .where('hasSwitchbot', '==', true)
    .get();

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
      saved++;
    } catch (e: any) {
      failed++;
      logger.error('pollAllUsersOnce error', {
        uid,
        error: String(e?.message ?? e),
      });
    }
  }

  const result: PollAllResult = {
    total: usersSnap.size,
    saved,
    skipped,
    failed,
  };
  logger.info('pollAllUsersOnce result', result);
  return result;
}

/* =================================================================== */
/*  連携解除: disableSwitchbotIntegration                              */
/* =================================================================== */

/**
 * SwitchBot 連携を「片付け」る callable。
 * - integrations/switchbot の meterDevice* を削除 & enabled=false
 * - integrations/switchbot_secrets の v1 / v1_plain を削除
 * - switchbot_users/{uid}.hasSwitchbot = false
 * - （オプション）switchbot_readings を最大500件削除
 */
export const disableSwitchbotIntegration = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'ログインが必要です。');
    }

    const deleteReadings = !!req.data?.deleteReadings;

    const userRef = db.collection('users').doc(uid);
    const integCol = userRef.collection('integrations');
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db.batch();

    // switchbot integration doc のフィールドを片付ける
    const switchbotRef = integCol.doc('switchbot');
    batch.set(
      switchbotRef,
      {
        meterDeviceId: admin.firestore.FieldValue.delete(),
        meterDeviceName: admin.firestore.FieldValue.delete(),
        meterDeviceType: admin.firestore.FieldValue.delete(),
        enabled: false,
        disabledAt: now,
      },
      { merge: true },
    );

    // secrets を片付ける
    const secretsRef = integCol.doc('switchbot_secrets');
    batch.set(
      secretsRef,
      {
        v1_plain: admin.firestore.FieldValue.delete(),
        v1: admin.firestore.FieldValue.delete(),
        disabledAt: now,
      },
      { merge: true },
    );

    // インデックス側: hasSwitchbot=false にしてスケジューラ対象から外す
    const idxRef = db.collection('switchbot_users').doc(uid);
    batch.set(
      idxRef,
      {
        hasSwitchbot: false,
        disabledAt: now,
      },
      { merge: true },
    );

    await batch.commit();

    // 任意: 読みingsをざっくり削除（開発用。大量データには別の仕組みを推奨）
    let deletedReadings = 0;
    if (deleteReadings) {
      const colRef = userRef.collection('switchbot_readings');
      const snap = await colRef.limit(500).get();
      if (!snap.empty) {
        const batch2 = db.batch();
        snap.docs.forEach((d) => {
          batch2.delete(d.ref);
          deletedReadings++;
        });
        await batch2.commit();
      }
    }

    return { ok: true, deletedReadings };
  },
);

/** Debug: token/secret がちゃんと読めているか head/tail を返す */
export const switchbotDebugEcho = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };
    const { token, secret, meterDeviceId } = await loadUserConfig(req.auth.uid);

    const headTail = (s?: string) =>
      !s ? null : { head: s.slice(0, 5), len: s.length, tail: s.slice(-5) };

    return {
      ok: true,
      uid: req.auth.uid,
      meterDeviceId,
      token: headTail(token),
      secret: headTail(secret),
    };
  },
);

/** Debug: /devices をそのまま返す */
export const switchbotDebugListFromStore = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };
    const { token, secret } = await loadUserConfig(req.auth.uid);
    if (!token || !secret)
      return { ok: false, error: 'missing plain token/secret' };

    const url = 'https://api.switch-bot.com/v1.1/devices';
    const res = await fetch(url, { headers: buildHeaders(token, secret) });
    const text = await res.text().catch(() => '');
    let json: any = null;
    try {
      json = JSON.parse(text);
    } catch {
      // ignore
    }
    return { ok: res.ok, status: res.status, body: json ?? text };
  },
);

/** Debug: /status 1回 */
export const switchbotDebugStatusFromStore = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };
    const { token, secret, meterDeviceId } = await loadUserConfig(req.auth.uid);
    if (!token || !secret || !meterDeviceId)
      return { ok: false, error: 'missing config' };
    try {
      const status = await getMeterStatus(meterDeviceId, token, secret);
      return { ok: true, status };
    } catch (e: any) {
      return { ok: false, error: String(e?.message ?? e) };
    }
  },
);

/** Callable: 自分のメーターを1回ポーリングして保存 */
export const pollMySwitchbotNow = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    if (!req.auth?.uid) return { ok: false, error: 'unauthenticated' };
    try {
      const { token, secret, meterDeviceId } = await loadUserConfig(
        req.auth.uid,
      );
      if (!token || !secret || !meterDeviceId)
        return {
          ok: false,
          error: 'missing config (token/secret/deviceId)',
        };
      const status = await getMeterStatus(meterDeviceId, token, secret);
      await saveReading(req.auth.uid, status);
      return { ok: true, saved: 1, status };
    } catch (e: any) {
      logger.error('pollMine error', e);
      return { ok: false, error: String(e?.message ?? e) };
    }
  },
);

/* =================================================================== */
/*  Flutter から呼ぶ本命: listSwitchbotDevices                         */
/* =================================================================== */

export const listSwitchbotDevices = onCall(
  { region: 'asia-northeast1' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', '認証ユーザーのみが呼び出せます。');
    }

    const { token, secret } = await loadUserConfig(uid);
    if (!token || !secret) {
      throw new HttpsError(
        'failed-precondition',
        'SwitchBot の TOKEN / SECRET が登録されていません。',
      );
    }

    const url = 'https://api.switch-bot.com/v1.1/devices';

    const res = await fetch(url, { headers: buildHeaders(token, secret) });
    const text = await res.text().catch(() => '');
    let json: any = null;
    try {
      json = JSON.parse(text);
    } catch {
      // ignore
    }

    if (!res.ok) {
      // SwitchBot API から 401/500 等が返った場合はここに来る
      throw new HttpsError(
        'internal',
        `SwitchBot /devices error ${res.status}: ${
          typeof text === 'string' ? text.slice(0, 500) : ''
        }`,
      );
    }

    const body = json?.body ?? {};
    const devices = Array.isArray(body.deviceList) ? body.deviceList : [];

    return {
      ok: true,
      devices,
      body, // Flutter 側の後方互換用（body.deviceList を見る実装にも対応）
    };
  },
);

/* ===== HTTP: 手動で叩きたいとき用 ===== */

export const switchbotPollNow = onRequest(
  { region: 'asia-northeast1' },
  async (_req, res) => {
    const result = await pollAllUsersOnce();
    res.json({ ok: true, ...result });
  },
);

/* ===== Scheduler: アプリ閉じてても回すやつ ===== */

export const switchbotPoller = onSchedule(
  { region: 'asia-northeast1', schedule: 'every 15 minutes' },
  async () => {
    await pollAllUsersOnce();
    // 追加のログが欲しければここで logger.info してもOK
  },
);
