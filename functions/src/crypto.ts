// functions/src/crypto.ts
import * as crypto from "crypto";

// 解析時(デプロイ前)は secrets が未注入のため、トップレベルで触らない。
// 呼び出し時にだけ取り出す & キャッシュする。
let _key: Buffer | null = null;

function getKey(): Buffer {
  if (_key) return _key;

  const keyB64 = process.env.ENVELOPE_KEY;
  if (!keyB64) {
    throw new Error(
      "ENVELOPE_KEY is not set. Deploy/run with functions v2 secrets, or set it in the emulator."
    );
  }
  const buf = Buffer.from(keyB64, "base64");
  if (buf.length !== 32) {
    throw new Error(
      `ENVELOPE_KEY must be 32 bytes (base64). Got ${buf.length} bytes.`
    );
  }
  _key = buf;
  return _key!;
}

export function seal(plain: string): string {
  const key = getKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString("base64");
}

export function open(sealedB64: string): string {
  const key = getKey();
  const buf = Buffer.from(sealedB64, "base64");
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const enc = buf.subarray(28);
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(enc), decipher.final()]);
  return dec.toString("utf8");
}