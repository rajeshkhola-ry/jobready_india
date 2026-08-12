import { NextResponse } from "next/server";
import { getSession, setSession, hasClaimedFreeTrial } from "@/lib/auth";
import { claimFreeTrial } from "@/lib/trial";
import { getVoiceShopSettings } from "@/lib/voice-shop-settings";

export async function POST() {
  if (!getVoiceShopSettings().freeTrialEnabled) {
    return NextResponse.json({ granted: false, reason: "trial_disabled" }, { status: 403 });
  }
  const user = await getSession();
  const result = claimFreeTrial(user?.id ?? null);
  if (user && result.granted) {
    await setSession({ ...user, hasFreeTrial: true });
  }
  const status = result.granted
    ? 201
    : result.reason === "authentication_required"
      ? 401
      : result.reason === "trial_disabled"
        ? 403
        : 409;
  return NextResponse.json({ ...result, hasFreeTrial: result.granted || hasClaimedFreeTrial(user?.id ?? 0) }, { status });
}
