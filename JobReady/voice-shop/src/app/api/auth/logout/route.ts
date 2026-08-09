import { NextResponse } from "next/server";
import { clearSession } from "@/lib/auth";
import { authCorsOptions, withAuthCors } from "@/lib/auth-cors";

export async function POST(request: Request) {
  await clearSession();
  return withAuthCors(NextResponse.json({ success: true }), request);
}

export async function OPTIONS(request: Request) { return authCorsOptions(request); }
