// functions/src/switchbot.ts
// 強化版: ユーザーごとのスキップ理由を詳細にログ出力し、単体実行APIからも使い回せるように分離

import axios from "axios";
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { open } from "./crypto";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/** 共通: TOKEN/SECRET からヘッダ生成 */
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

async function getMeterStatus(deviceId: string, token: string, secret: string) {
  const url = `https://api.switch-bot.com/v1.1/devices/${deviceId}/status`;
  const { data } = await axios.get(url, { headers: buildHeadersFromPair(token, secret), timeout: 15000 });
  if (data.statusCode !== 100) throw new Error(`SwitchBot API error ${data.statusCode}: ${data.message}`);
  return data.body as { temperature?: number; humidity?: number; battery?: number };
}

/** 単一ユーザー分のポーリング（保存/スキップ理由を返す） */
export async function pollForUser(uid: string): Promise<{
  uid: string;
  saved: boolean;
  docPath?: string;
  reason?: string; // スキップ理由
}> {
  try {
    const userRef = db.collection("users").doc(uid);

    // 1) デバイス設定
    const meterCfg = await userRef.collection("integrations").doc("switchbot").get();
    const meterId = meterCfg.data()?.meterDeviceId as string | undefined;
    if (!meterId) {
      const reason = "no meterDeviceId";
      logger.info(`[poll] ${uid}: skipped (${reason})`);
      return { uid, saved: false, reason };
    }

    // 2) 資格情報
    const secDoc = await userRef.collection("integrations").doc("switchbot_secrets").get();
    const sealed = secDoc.data()?.v1;
    if (!sealed?.token || !sealed?.secret) {
      const reason = "no secrets";
      logger.info(`[poll] ${uid}: skipped (${reason})`);
      return { uid, saved: false, reason };
    }

    // 3) 復号
    const token = open(sealed.token);
    const secret = open(sealed.secret);

    // 4) 取得
    const status = await getMeterStatus(meterId, token, secret);
    const nowISO = new Date().toISOString();

    // 5) 保存
    const docRef = userRef.collection("switchbot_readings").doc(nowISO);
    await docRef.set({
      temperature: status.temperature ?? null,
      humidity: status.humidity ?? null,
      battery: status.battery ?? null,
      ts: nowISO,
      savedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const docPath = docRef.path;
    logger.info(`[poll] ${uid}: saved -> ${docPath} (t=${status.temperature}, h=${status.humidity}, b=${status.battery})`);
    return { uid, saved: true, docPath };
  } catch (e) {
    logger.error(`[poll] ${uid}: failed`, e as Error);
    return { uid, saved: false, reason: "failed" };
  }
}

/** 既存: 全ユーザー分の定期ポーリング（詳細ログ付き） */
export async function pollOnce() {
  const usersSnap = await db.collection("users").get();
  const results = await Promise.all(usersSnap.docs.map(d => pollForUser(d.id)));

  const saved = results.filter(r => r.saved).length;
  const failed = results.filter(r => r.reason === "failed").length;
  const skipped = results.length - saved - failed;

  logger.info(`pollOnce: users=${results.length}, saved=${saved}, skipped=${skipped}, failed=${failed}`);
}

/** （参考）ユーザー資格で /devices を叩くヘルパー */
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