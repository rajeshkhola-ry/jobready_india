import crypto from "node:crypto";
import { NextResponse } from "next/server";
import { getOAuthConfig } from "@/lib/oauth-config";

type Provider = "google" | "microsoft";

export async function GET(_: Request, context: RouteContext<"/api/auth/oauth/[provider]">) {
  const { provider } = await context.params;
  if (provider !== "google" && provider !== "microsoft") return NextResponse.json({ error: "Unsupported OAuth provider." }, { status: 404 });

  const normalizedProvider = provider as Provider;
  const { clientId, clientSecret, redirectUri } = getOAuthConfig(normalizedProvider);
  if (!clientId || !clientSecret || !redirectUri) {
    return NextResponse.json({
      error: `${normalizedProvider === "google" ? "Google" : "Microsoft"} OAuth is ready for credentials. Add the client ID, client secret, and redirect URI environment variables.`,
    }, { status: 503 });
  }

  const state = crypto.randomBytes(24).toString("hex");
  const callbackScope = normalizedProvider === "google" ? "openid email profile" : "openid email profile User.Read";
  const tenant = process.env.MICROSOFT_TENANT_ID || "common";
  const authorizationUrl = normalizedProvider === "google"
    ? new URL("https://accounts.google.com/o/oauth2/v2/auth")
    : new URL(`https://login.microsoftonline.com/${tenant}/oauth2/v2.0/authorize`);
  authorizationUrl.search = new URLSearchParams({ client_id: clientId, redirect_uri: redirectUri, response_type: "code", scope: callbackScope, state }).toString();

  const response = NextResponse.redirect(authorizationUrl);
  response.cookies.set(`voice_shop_${normalizedProvider}_state`, state, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: 600,
    path: "/",
  });
  return response;
}
