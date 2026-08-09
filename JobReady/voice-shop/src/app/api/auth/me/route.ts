import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { availableOAuthProviders } from "@/lib/oauth-config";
import { isVoiceShopAdminAuthorized } from "@/lib/admin-auth";

export async function GET(request: Request) {
  if (isVoiceShopAdminAuthorized(request)) {
    return NextResponse.json({
      authenticated: true,
      user: { id: 0, email: "admin@getreadyjob.com", fullName: "GETREADYJOB Admin", role: "admin" },
      adminUnlimited: true,
      oauthProviders: availableOAuthProviders(),
    });
  }
  const user = await getSession();
  return NextResponse.json({ authenticated: Boolean(user), user: user ? { ...user, role: "user" } : null, adminUnlimited: false, oauthProviders: availableOAuthProviders() });
}
