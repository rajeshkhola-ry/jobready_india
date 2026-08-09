import crypto from "node:crypto";

export function isVoiceShopAdminAuthorized(request: Request) {
  const configuredKey = process.env.VOICE_SHOP_ADMIN_KEY || (process.env.NODE_ENV === "production" ? "" : "voice-shop-local-admin-key");
  const suppliedKey = request.headers.get("x-voice-shop-admin-key") || "";
  if (!configuredKey || !suppliedKey) return false;
  const expected = Buffer.from(configuredKey);
  const actual = Buffer.from(suppliedKey);
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}
