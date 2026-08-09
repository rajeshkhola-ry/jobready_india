import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { setSession } from "@/lib/auth";
import { db } from "@/lib/db";
import { signupSchema } from "@/lib/schemas";

export async function POST(request: Request) {
  const parsed = signupSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Please check all registration fields.", issues: parsed.error.flatten() }, { status: 400 });

  const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(parsed.data.email);
  if (existing) return NextResponse.json({ error: "An account already exists for this email." }, { status: 409 });

  const passwordHash = await bcrypt.hash(parsed.data.password, 12);
  const result = db.prepare(`
    INSERT INTO users(full_name, email, mobile, country, password_hash)
    VALUES (?, ?, ?, ?, ?)
  `).run(parsed.data.fullName, parsed.data.email, parsed.data.mobile, parsed.data.country, passwordHash);
  const userId = Number(result.lastInsertRowid);
  db.prepare("INSERT INTO wallets(user_id) VALUES (?)").run(userId);
  await setSession({ id: userId, email: parsed.data.email, fullName: parsed.data.fullName });
  return NextResponse.json({ success: true, user: { id: userId, email: parsed.data.email, fullName: parsed.data.fullName } }, { status: 201 });
}
