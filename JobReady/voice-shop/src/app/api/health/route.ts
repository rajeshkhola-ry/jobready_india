import { NextResponse } from "next/server";
import { db } from "@/lib/db";

export async function GET() {
  db.prepare("SELECT 1").get();
  return NextResponse.json({
    ok: true,
    service: "voice-shop",
  });
}
