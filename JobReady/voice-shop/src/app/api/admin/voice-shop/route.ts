import { NextResponse } from "next/server";
import { isVoiceShopAdminAuthorized } from "@/lib/admin-auth";
import { voiceShopSettingsSchema } from "@/lib/schemas";
import { getVoiceShopSettings, updateVoiceShopSettings } from "@/lib/voice-shop-settings";

export async function GET(request: Request) {
  if (!isVoiceShopAdminAuthorized(request)) return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  return NextResponse.json({ settings: getVoiceShopSettings() });
}

export async function PUT(request: Request) {
  if (!isVoiceShopAdminAuthorized(request)) return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  const parsed = voiceShopSettingsSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Enter valid positive rates and a trial toggle value." }, { status: 400 });
  return NextResponse.json({ success: true, settings: updateVoiceShopSettings(parsed.data) });
}
