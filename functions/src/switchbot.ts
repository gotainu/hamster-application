import axios from "axios";
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function buildHeaders() {
  const token = process.env.SWITCHBOT_TOKEN!;
  const secret = process.env.SWITCHBOT_SECRET!;
  const t = Date.now().toString();
  const nonce = crypto.randomUUID();
  const sign = crypto.createHmac("sha256", secret).update(token + t + nonce).digest("base64");
  return {
    Authorization: token,
    "Content-Type": "application/json; charset=utf8",
    t, sign, nonce,
    signVersion: "1",
  };
}

async function getMeterStatus(deviceId: string) {
  const url = `https://api.switch-bot.com/v1.1/devices/${deviceId}/status`;
  const { data } = await axios.get(url, { headers: buildHeaders(), timeout: 15000 });
  if (data.statusCode !== 100) throw new Error(`SwitchBot API error ${data.statusCode}: ${data.message}`);
  return data.body as { temperature?: number; humidity?: number; battery?: number };
}

export async function pollOnce() {
  const usersSnap = await db.collection("users").get();
  let saved = 0, skipped = 0, failed = 0;

  await Promise.all(usersSnap.docs.map(async (userDoc) => {
    try {
      const cfg = await userDoc.ref.collection("integrations").doc("switchbot").get();
      const meterId = cfg.data()?.meterDeviceId as string | undefined;
      if (!meterId) { skipped++; return; }

      const status = await getMeterStatus(meterId);
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