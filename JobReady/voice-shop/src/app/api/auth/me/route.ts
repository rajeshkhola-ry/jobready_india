import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { availableOAuthProviders } from "@/lib/oauth-config";

export async function GET() {
  const user = await getSession();
  return NextResponse.json({ authenticated: Boolean(user), user, oauthProviders: availableOAuthProviders() });
}
