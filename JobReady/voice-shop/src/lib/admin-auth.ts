import crypto from "node:crypto";

const adminSessionCookie = "voice_shop_admin_session";
const adminSessionLifetimeSeconds = 12 * 60 * 60;

function sessionSecret() {
  return process.env.AUTH_SECRET || "";
}

function signSession(expiry: number) {
  return crypto.createHmac("sha256", sessionSecret()).update(String(expiry)).digest("base64url");
}

export function createVoiceShopAdminSession() {
  const expiry = Math.floor(Date.now() / 1000) + adminSessionLifetimeSeconds;
  return {
    name: adminSessionCookie,
    value: `${expiry}.${signSession(expiry)}`,
    maxAge: adminSessionLifetimeSeconds,
  };
}

function hasValidAdminSession(request: Request) {
  const secret = sessionSecret();
  if (!secret) return false;
  const cookieHeader = request.headers.get("cookie") || "";
  const encodedSession = cookieHeader
    .split(";")
    .map((cookie) => cookie.trim())
    .find((cookie) => cookie.startsWith(`${adminSessionCookie}=`))
    ?.slice(adminSessionCookie.length + 1);
  if (!encodedSession) return false;

  const [expiryText, suppliedSignature] = encodedSession.split(".");
  const expiry = Number(expiryText);
  if (!Number.isInteger(expiry) || expiry <= Math.floor(Date.now() / 1000) || !suppliedSignature) return false;

  const expectedSignature = signSession(expiry);
  const expected = Buffer.from(expectedSignature);
  const actual = Buffer.from(suppliedSignature);
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

export function isVoiceShopAdminAuthorized(request: Request) {
  if (hasValidAdminSession(request)) return true;
  const configuredKey = process.env.VOICE_SHOP_ADMIN_KEY || (process.env.NODE_ENV === "production" ? "" : "voice-shop-local-admin-key");
  const suppliedKey = request.headers.get("x-voice-shop-admin-key") || "";
  if (!configuredKey || !suppliedKey) return false;
  const expected = Buffer.from(configuredKey);
  const actual = Buffer.from(suppliedKey);
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}
