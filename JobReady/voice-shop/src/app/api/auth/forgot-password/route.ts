import crypto from "node:crypto";
import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { emailSchema } from "@/lib/schemas";

export async function POST(request: Request) {
  const parsed = emailSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Enter a valid email address." }, { status: 400 });

  const user = db.prepare("SELECT id FROM users WHERE email = ?").get(parsed.data.email) as { id: number } | undefined;
  let developmentResetUrl: string | undefined;
  if (user) {
    const token = crypto.randomBytes(32).toString("hex");
    const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();
    db.prepare("UPDATE password_reset_tokens SET used_at = CURRENT_TIMESTAMP WHERE user_id = ? AND used_at IS NULL").run(user.id);
    db.prepare("INSERT INTO password_reset_tokens(user_id, token_hash, expires_at) VALUES (?, ?, ?)").run(user.id, tokenHash, expiresAt);
    if (process.env.NODE_ENV !== "production") developmentResetUrl = `/reset-password?token=${token}`;
  }

  return NextResponse.json({
    success: true,
    message: "If that email is registered, password reset instructions have been prepared.",
    developmentResetUrl,
  });
}
