// functions/src/index.ts

import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import crypto from 'crypto';

admin.initializeApp();
const db = admin.firestore();

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

    // ✅ TS: string.isEmpty は無い。length で判定。
    if (token.length === 0 || secret.length === 0) {
      throw new HttpsError('invalid-argument', 'TOKEN/SECRET は必須です。');
    }
    if (token.length < 20 || secret.length < 10) {
      throw new HttpsError('invalid-argument', 'TOKEN/SECRET の形式が不正です（短すぎます）。');
    }

    // ✅ ここが本命：保存前に検証（401/403ならここで落ちる）
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

    return { ok: true, verified: true };
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
    if (!token || !secret || !meterDeviceId) return { ok: false, error: 'missing config (token/secret/deviceId)' };
    const status = await getMeterStatus(meterDeviceId, token, secret);
    await saveReading(req.auth.uid, status);
    return { ok: true, saved: 1, status };
  } catch (e: any) {
    logger.error('pollMine error', e);
    return { ok: false, error: String(e?.message ?? e) };
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