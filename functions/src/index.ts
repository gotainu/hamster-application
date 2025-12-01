// functions/src/index.ts
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import axios from "axios";

import {
  pollOnce,
  buildHeadersFromPair,
  listDevicesFromPair,        // ★ ここを使います
} from "./switchbot";
import { seal, open } from "./crypto"; // ★ 復号のため open を追加

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/**
 * ユーザーごとの暗号化済み TOKEN/SECRET を復号して、その資格情報で
 * SwitchBot /devices を叩き、該当ユーザーのデバイス一覧を返す。
 */
export const listSwitchbotDevices = onCall(
  { region: "asia-northeast1", secrets: ["ENVELOPE_KEY"] }, // ★ ENVELOPE_KEY のみ
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "auth required");
    const uid = req.auth.uid;

    // 暗号化保存された資格情報を取得
    const secDoc = await db
      .collection("users").doc(uid)
      .collection("integrations").doc("switchbot_secrets")
      .get();

    const sealed = secDoc.data()?.v1;
    if (!sealed?.token || !sealed?.secret) {
      throw new HttpsError("failed-precondition", "no secrets stored yet");
    }

    // 復号
    const token = open(sealed.token);
    const secret = open(sealed.secret);

    // ユーザー本人の資格情報で一覧取得
    const devices = await listDevicesFromPair(token, secret);
    return { devices };
  }
);

// 既存: 定期ポーラ
export const switchbotPoller = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
    secrets: ["ENVELOPE_KEY"],
  },
  async () => {
    logger.info("switchbotPoller: start");
    await pollOnce();
    logger.info("switchbotPoller: done");
  }
);

// 既存: 手動ポーラ
export const switchbotPollNow = onRequest(
  { region: "asia-northeast1", secrets: ["ENVELOPE_KEY"] },
  async (_req, res) => {
    await pollOnce();
    res.json({ ok: true });
  }
);

// 既存: TOKEN/SECRET の検証＋暗号化保存
export const registerSwitchbotSecrets = onCall<{ token: string; secret: string }>(
  { region: "asia-northeast1", secrets: ["ENVELOPE_KEY"] },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "auth required");

    const token = (req.data?.token ?? "").trim();
    const secret = (req.data?.secret ?? "").trim();
    if (!token || !secret) throw new HttpsError("invalid-argument", "token/secret required");

    // 接続検証（/devices）
    try {
      const { data } = await axios.get("https://api.switch-bot.com/v1.1/devices", {
        headers: buildHeadersFromPair(token, secret),
        timeout: 10000,
      });
      if (data.statusCode !== 100) {
        throw new HttpsError("failed-precondition", `SwitchBot error ${data.statusCode}`);
      }
    } catch {
      throw new HttpsError("failed-precondition", "TOKEN/SECRET invalid or unreachable");
    }

    await db.collection("users").doc(uid)
      .collection("integrations").doc("switchbot_secrets")
      .set({
        v1: {
          token: seal(token),
          secret: seal(secret),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }
      }, { merge: true });

    return { ok: true };
  }
);