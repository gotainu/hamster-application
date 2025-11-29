import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { pollOnce } from "./switchbot";

export const switchbotPoller = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
    // ← ここに secrets を渡す（runWith は使わない）
    secrets: ["ENVELOPE_KEY", "SWITCHBOT_TOKEN", "SWITCHBOT_SECRET"],
  },
  async () => {
    logger.info("switchbotPoller: start");
    await pollOnce();
    logger.info("switchbotPoller: done");
  }
);

export const switchbotPollNow = onRequest(
  {
    region: "asia-northeast1",
    secrets: ["ENVELOPE_KEY", "SWITCHBOT_TOKEN", "SWITCHBOT_SECRET"],
  },
  async (_req, res) => {
    await pollOnce();
    res.json({ ok: true });
  }
);