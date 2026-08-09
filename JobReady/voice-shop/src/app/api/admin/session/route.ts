import { NextResponse } from "next/server";
import { createVoiceShopAdminSession, isVoiceShopAdminAuthorized } from "@/lib/admin-auth";

export async function POST(request: Request) {
  if (!isVoiceShopAdminAuthorized(request)) {
    return NextResponse.json({ error: "Invalid Voice Shop admin control key." }, { status: 401 });
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
