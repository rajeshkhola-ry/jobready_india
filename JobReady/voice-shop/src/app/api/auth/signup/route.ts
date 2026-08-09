import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { setSession } from "@/lib/auth";
import { db } from "@/lib/db";
import { signupSchema } from "@/lib/schemas";
import { authCorsOptions, withAuthCors } from "@/lib/auth-cors";

export async function POST(request: Request) {
  const parsed = signupSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return withAuthCors(NextResponse.json({ error: "Please check all registration fields.", issues: parsed.error.flatten() }, { status: 400 }), request);

  const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(parsed.data.email);
  if (existing) return withAuthCors(NextResponse.json({ error: "An account already exists for this email." }, { status: 409 }), request);

  const passwordHash = await bcrypt.hash(parsed.data.password, 12);
  const result = db.prepare(`
    INSERT INTO users(full_name, email, mobile, country, password_hash)
    VALUES (?, ?, ?, ?, ?)
  `).run(parsed.data.fullName, parsed.data.email, parsed.data.mobile, parsed.data.country, passwordHash);
  const userId = Number(result.lastInsertRowid);
  db.prepare("INSERT INTO wallets(user_id) VALUES (?)").run(userId);
  await setSession({ id: userId, email: parsed.data.email, fullName: parsed.data.fullName });
  return withAuthCors(NextResponse.json({ success: true, user: { id: userId, email: parsed.data.email, fullName: parsed.data.fullName, mobile: parsed.data.mobile, country: parsed.data.country, role: "user", walletBalancePaise: 0 } }, { status: 201 }), request);
}

export async function OPTIONS(request: Request) { return authCorsOptions(request); }
