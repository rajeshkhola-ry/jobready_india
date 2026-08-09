import { NextResponse } from "next/server";
import { createVoiceShopAdminSession } from "@/lib/admin-auth";

const defaultAdminApiUrl = "https://jobready-india.onrender.com";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const token = typeof body?.token === "string" ? body.token.trim() : "";
  if (!token || token.length > 4096) {
    return NextResponse.json({ error: "A valid admin session is required." }, { status: 401 });
  }

  const adminApiUrl = (process.env.GETREADYJOB_ADMIN_API_URL || defaultAdminApiUrl).replace(/\/$/, "");
  const verification = await fetch(`${adminApiUrl}/admin/me`, {
    headers: { authorization: `Bearer ${token}` },
    cache: "no-store",
  }).catch(() => null);

  if (!verification?.ok) {
    return NextResponse.json({ error: "Your main admin session is invalid or expired." }, { status: 401 });
  }

  const verified = await verification.json().catch(() => null);
  if (verified?.admin?.role !== "admin") {
    return NextResponse.json({ error: "Administrator access is required." }, { status: 403 });
  }

  const session = createVoiceShopAdminSession();
  const response = NextResponse.json({ success: true });
  response.cookies.set(session.name, session.value, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: session.maxAge,
  });
  return response;
}
