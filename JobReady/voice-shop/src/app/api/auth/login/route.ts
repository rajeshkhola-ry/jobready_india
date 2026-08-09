import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { setSession } from "@/lib/auth";
import { db } from "@/lib/db";
import { loginSchema } from "@/lib/schemas";
import { authCorsOptions, withAuthCors } from "@/lib/auth-cors";

export async function POST(request: Request) {
  const parsed = loginSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return withAuthCors(NextResponse.json({ error: "Enter a valid email and password." }, { status: 400 }), request);

  const user = db.prepare("SELECT id, full_name, email, mobile, country, password_hash, auth_provider FROM users WHERE email = ?").get(parsed.data.email) as
    | { id: number; full_name: string; email: string; mobile: string; country: string; password_hash: string | null; auth_provider: string }
    | undefined;
  if (!user?.password_hash || !(await bcrypt.compare(parsed.data.password, user.password_hash))) {
    return withAuthCors(NextResponse.json({ error: "Invalid email or password." }, { status: 401 }), request);
  }

  await setSession({ id: user.id, email: user.email, fullName: user.full_name });
  const wallet = db.prepare("SELECT balance_paise FROM wallets WHERE user_id = ?").get(user.id) as { balance_paise?: number } | undefined;
  return withAuthCors(NextResponse.json({ success: true, user: { id: user.id, email: user.email, fullName: user.full_name, mobile: user.mobile, country: user.country, role: "user", walletBalancePaise: wallet?.balance_paise || 0 } }), request);
}

export async function OPTIONS(request: Request) { return authCorsOptions(request); }
