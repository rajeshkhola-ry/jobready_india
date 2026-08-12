import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

import { db } from "@/lib/db";

export const SESSION_COOKIE = "voice_shop_session";

export type ActivePass = {
  code: string;
  customerType: "personal" | "business";
  startsAt: string;
  expiresAt: string;
};

export type SessionUser = {
  id: number;
  email: string;
  fullName: string;
  role?: "user" | "admin";
  hasFreeTrial?: boolean;
  activePass?: ActivePass | null;
};

export { hasVoiceShopAccess } from "@/lib/access";

export function normalizeActivePass(pass: Partial<ActivePass> | null | undefined): ActivePass | null {
  if (!pass || typeof pass !== "object") return null;
  const code = typeof pass.code === "string" ? pass.code.trim() : "";
  const customerType = pass.customerType === "personal" || pass.customerType === "business" ? pass.customerType : null;
  const startsAt = typeof pass.startsAt === "string" ? pass.startsAt.trim() : "";
  const expiresAt = typeof pass.expiresAt === "string" ? pass.expiresAt.trim() : "";

  if (!code || !customerType || !startsAt || !expiresAt) return null;
  return { code, customerType, startsAt, expiresAt };
}

export function buildSessionPayload(user: SessionUser) {
  const payload: Record<string, unknown> = {
    email: user.email,
    fullName: user.fullName,
  };

  if (user.role) payload.role = user.role;
  if (user.hasFreeTrial) payload.hasFreeTrial = true;

  const activePass = normalizeActivePass(user.activePass);
  if (activePass) payload.activePass = activePass;
  return payload;
}

export function hasClaimedFreeTrial(userId: number): boolean {
  return Boolean(db.prepare("SELECT id FROM free_trial_claims WHERE user_id = ?").get(userId));
}

export function parseActivePassFromSession(value: unknown): ActivePass | null {
  if (!value || typeof value !== "object") return null;
  return normalizeActivePass(value as Partial<ActivePass>);
}

export function getActivePassForUser(userId: number): ActivePass | null {
  const row = db.prepare(`
    SELECT pass_code, starts_at, expires_at
    FROM package_passes
    WHERE user_id = ?
      AND datetime(expires_at) > datetime('now')
    ORDER BY datetime(starts_at) DESC
    LIMIT 1
  `).get(userId) as { pass_code?: string; starts_at?: string; expires_at?: string } | undefined;

  if (!row?.pass_code || !row.starts_at || !row.expires_at) return null;

  const [code, customerType] = String(row.pass_code).split(":");
  if (!code || (customerType !== "personal" && customerType !== "business")) return null;

  return normalizeActivePass({
    code,
    customerType,
    startsAt: row.starts_at,
    expiresAt: row.expires_at,
  });
}

function authKey() {
  const secret = process.env.AUTH_SECRET;
  if (!secret || secret.length < 32) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("AUTH_SECRET must contain at least 32 characters.");
    }
    return new TextEncoder().encode("voice-shop-local-development-secret-change-me");
  }
  return new TextEncoder().encode(secret);
}

export async function createSessionToken(user: SessionUser) {
  return new SignJWT(buildSessionPayload(user))
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(String(user.id))
    .setIssuedAt()
    .setExpirationTime("7d")
    .sign(authKey());
}

export async function setSession(user: SessionUser) {
  const normalizedUser: SessionUser = {
    ...user,
    activePass: normalizeActivePass(user.activePass),
  };

  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE, await createSessionToken(normalizedUser), {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    domain: process.env.NODE_ENV === "production" ? ".getreadyjob.com" : undefined,
    path: "/",
    maxAge: 60 * 60 * 24 * 7,
  });
}

export async function clearSession() {
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE, "", {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    domain: process.env.NODE_ENV === "production" ? ".getreadyjob.com" : undefined,
    path: "/",
    maxAge: 0,
  });
}

export async function getSession(): Promise<SessionUser | null> {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, authKey());
    return {
      id: Number(payload.sub),
      email: String(payload.email),
      fullName: String(payload.fullName),
      role: payload.role === "admin" ? "admin" : "user",
      hasFreeTrial: Boolean(payload.hasFreeTrial),
      activePass: parseActivePassFromSession(payload.activePass),
    };
  } catch {
    return null;
  }
}
