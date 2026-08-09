import { cookies, headers } from "next/headers";
import { NextResponse } from "next/server";
import { setSession } from "@/lib/auth";
import { db } from "@/lib/db";
import { getOAuthConfig } from "@/lib/oauth-config";

type Provider = "google" | "microsoft";
type SocialProfile = { subject: string; email: string; fullName: string };

export async function GET(request: Request, context: RouteContext<"/api/auth/oauth/[provider]/callback">) {
  const { provider } = await context.params;
  if (provider !== "google" && provider !== "microsoft") return NextResponse.json({ error: "Unsupported OAuth provider." }, { status: 404 });

  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const returnedState = url.searchParams.get("state");
  const cookieStore = await cookies();
  const expectedState = cookieStore.get(`voice_shop_${provider}_state`)?.value;
  if (!code || !returnedState || !expectedState || returnedState !== expectedState) {
    return NextResponse.redirect(new URL("/?authError=invalid_oauth_state", request.url));
  }

  try {
    const accessToken = await exchangeCode(provider, code);
    const profile = await loadProfile(provider, accessToken);
    const countryHeader = (await headers()).get("x-vercel-ip-country") || (await headers()).get("cf-ipcountry") || "Unknown";
    const user = upsertSocialUser(provider, profile, countryHeader);
    await setSession({ id: user.id, email: profile.email, fullName: profile.fullName });
    cookieStore.delete(`voice_shop_${provider}_state`);
    return NextResponse.redirect(new URL("/?socialLogin=success", request.url));
  } catch {
    return NextResponse.redirect(new URL("/?authError=oauth_failed", request.url));
  }
}

async function exchangeCode(provider: Provider, code: string) {
  const isGoogle = provider === "google";
  const { clientId, clientSecret, redirectUri } = getOAuthConfig(provider);
  if (!clientId || !clientSecret || !redirectUri) throw new Error("OAuth credentials are incomplete");

  const tenant = process.env.MICROSOFT_TENANT_ID || "common";
  const tokenUrl = isGoogle
    ? "https://oauth2.googleapis.com/token"
    : `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token`;
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    code,
    redirect_uri: redirectUri,
    grant_type: "authorization_code",
  });
  if (!isGoogle) body.set("scope", "openid email profile User.Read");

  const response = await fetch(tokenUrl, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body });
  const payload = (await response.json()) as { access_token?: string };
  if (!response.ok || !payload.access_token) throw new Error("OAuth token exchange failed");
  return payload.access_token;
}

async function loadProfile(provider: Provider, accessToken: string): Promise<SocialProfile> {
  const endpoint = provider === "google" ? "https://www.googleapis.com/oauth2/v3/userinfo" : "https://graph.microsoft.com/v1.0/me";
  const response = await fetch(endpoint, { headers: { authorization: `Bearer ${accessToken}` } });
  if (!response.ok) throw new Error("OAuth profile request failed");
  const profile = await response.json() as Record<string, unknown>;
  const subject = String(profile.sub || profile.id || "");
  const email = String(profile.email || profile.mail || profile.userPrincipalName || "").trim().toLowerCase();
  const fullName = String(profile.name || profile.displayName || email.split("@")[0] || "Voice Shop User").trim();
  if (!subject || !email) throw new Error("OAuth profile did not include a verified identity");
  return { subject, email, fullName };
}

function upsertSocialUser(provider: Provider, profile: SocialProfile, country: string) {
  const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(profile.email) as { id: number } | undefined;
  if (existing) {
    db.prepare("UPDATE users SET full_name = ?, provider_subject = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?")
      .run(profile.fullName, profile.subject, existing.id);
    return existing;
  }

  const result = db.prepare(`
    INSERT INTO users(full_name, email, mobile, country, auth_provider, provider_subject)
    VALUES (?, ?, '', ?, ?, ?)
  `).run(profile.fullName, profile.email, country, provider, profile.subject);
  const user = { id: Number(result.lastInsertRowid) };
  db.prepare("INSERT INTO wallets(user_id) VALUES (?)").run(user.id);
  return user;
}
