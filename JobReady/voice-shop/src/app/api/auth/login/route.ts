import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { setSession } from "@/lib/auth";
import { db } from "@/lib/db";
import { loginSchema } from "@/lib/schemas";

export async function POST(request: Request) {
  const parsed = loginSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Enter a valid email and password." }, { status: 400 });

  const user = db.prepare("SELECT id, full_name, email, password_hash FROM users WHERE email = ?").get(parsed.data.email) as
    | { id: number; full_name: string; email: string; password_hash: string | null }
    | undefined;
  if (!user?.password_hash || !(await bcrypt.compare(parsed.data.password, user.password_hash))) {
    return NextResponse.json({ error: "Invalid email or password." }, { status: 401 });
  }

  await setSession({ id: user.id, email: user.email, fullName: user.full_name });
  return NextResponse.json({ success: true, user: { id: user.id, email: user.email, fullName: user.full_name } });
}
