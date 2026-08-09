import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { claimFreeTrial } from "@/lib/trial";
import { getVoiceShopSettings } from "@/lib/voice-shop-settings";

export async function POST() {
  if (!getVoiceShopSettings().freeTrialEnabled) {
    return NextResponse.json({ granted: false, reason: "trial_disabled" }, { status: 403 });
  }
  const user = await getSession();
  const result = claimFreeTrial(user?.id ?? null);
  const status = result.granted
    ? 201
    : result.reason === "authentication_required"
      ? 401
      : result.reason === "trial_disabled"
        ? 403
        : 409;
  return NextResponse.json(result, { status });
}
