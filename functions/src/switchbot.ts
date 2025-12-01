// functions/src/switchbot.ts
import axios from "axios";
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { open } from "./crypto";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/** プロジェクト共通の Secret（process.env）からヘッダ生成：listSwitchbotDevices 用 */
function buildHeaders() {
  const token = process.env.SWITCHBOT_TOKEN!;
  const secret = process.env.SWITCHBOT_SECRET!;
  const t = Date.now().toString();
  const nonce = crypto.randomUUID();
  const sign = crypto.createHmac("sha256", secret).update(token + t + nonce).digest("base64");
  return {
    Authorization: token,
    "Content-Type": "application/json; charset=utf8",
    t, sign, nonce, signVersion: "1",
  };
}

/** ユーザーごとの TOKEN/SECRET ペアからヘッダ生成：pollOnce 等で使用 */
export function buildHeadersFromPair(token: string, secret: string) {
  const t = Date.now().toString();
  const nonce = crypto.randomUUID();
  const sign = crypto.createHmac("sha256", secret).update(token + t + nonce).digest("base64");
  return {
    Authorization: token,
    "Content-Type": "application/json; charset=utf8",
    t, sign, nonce, signVersion: "1",
  };
}

/** デバイス一覧（/v1.1/devices）を取得：共通 Secret を使用 */
export async function listDevices() {
  const url = "https://api.switch-bot.com/v1.1/devices";
  const { data } = await axios.get(url, { headers: buildHeaders(), timeout: 15000 });
  if (data.statusCode !== 100) throw new Error(`SwitchBot API error ${data.statusCode}: ${data.message}`);
  return (data.body?.deviceList ?? []).map((d: any) => ({
    deviceId: d.deviceId,
    deviceName: d.deviceName,
    deviceType: d.deviceType,
  }));
}

/** 温湿度計の最新ステータス取得：ユーザーのペアを使用 */
async function getMeterStatus(deviceId: string, token: string, secret: string) {
  const url = `https://api.switch-bot.com/v1.1/devices/${deviceId}/status`;
  const { data } = await axios.get(url, { headers: buildHeadersFromPair(token, secret), timeout: 15000 });
  if (data.statusCode !== 100) throw new Error(`SwitchBot API error ${data.statusCode}: ${data.message}`);
  return data.body as { temperature?: number; humidity?: number; battery?: number };
}

/** 全ユーザー分の定期ポーリング */
export async function pollOnce() {
  const usersSnap = await db.collection("users").get();
  let saved = 0, skipped = 0, failed = 0;

  await Promise.all(usersSnap.docs.map(async (userDoc) => {
    try {
      const meterCfg = await userDoc.ref.collection("integrations").doc("switchbot").get();
      const meterId = meterCfg.data()?.meterDeviceId as string | undefined;
      if (!meterId) { skipped++; return; }

      const secDoc = await userDoc.ref.collection("integrations").doc("switchbot_secrets").get();
      const sealed = secDoc.data()?.v1;
      if (!sealed?.token || !sealed?.secret) { skipped++; return; }

      const token = open(sealed.token);
      const secret = open(sealed.secret);

      const status = await getMeterStatus(meterId, token, secret);
      const nowISO = new Date().toISOString();

      await userDoc.ref.collection("switchbot_readings").doc(nowISO).set({
        temperature: status.temperature ?? null,
        humidity: status.humidity ?? null,
        battery: status.battery ?? null,
        ts: nowISO,
        savedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      saved++;
    } catch (e) {
      failed++;
      logger.error(`poll failed for user ${userDoc.id}`, e as Error);
    }
  }));

  logger.info(`pollOnce: users=${usersSnap.size}, saved=${saved}, skipped=${skipped}, failed=${failed}`);
}

export async function listDevicesFromPair(token: string, secret: string) {
  const url = "https://api.switch-bot.com/v1.1/devices";
  const { data } = await axios.get(url, {
    headers: buildHeadersFromPair(token, secret),
    timeout: 15000,
  });
  if (data.statusCode !== 100) {
    throw new Error(`SwitchBot API error ${data.statusCode}: ${data.message}`);
  }
  return (data.body?.deviceList ?? []).map((d: any) => ({
    deviceId: d.deviceId,
    deviceName: d.deviceName,
    deviceType: d.deviceType,
  }));
}