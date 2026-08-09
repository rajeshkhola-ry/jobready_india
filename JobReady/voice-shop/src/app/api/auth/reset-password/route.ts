import bcrypt from "bcryptjs";
import crypto from "node:crypto";
import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { resetPasswordSchema } from "@/lib/schemas";

export async function POST(request: Request) {
  const parsed = resetPasswordSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "The reset request is invalid." }, { status: 400 });
  const tokenHash = crypto.createHash("sha256").update(parsed.data.token).digest("hex");
  const reset = db.prepare(`
    SELECT id, user_id FROM password_reset_tokens
    WHERE token_hash = ? AND used_at IS NULL AND expires_at > CURRENT_TIMESTAMP
  `).get(tokenHash) as { id: number; user_id: number } | undefined;
  if (!reset) return NextResponse.json({ error: "This reset link is invalid or expired." }, { status: 400 });

  const passwordHash = await bcrypt.hash(parsed.data.password, 12);
  db.transaction(() => {
    db.prepare("UPDATE users SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?").run(passwordHash, reset.user_id);
    db.prepare("UPDATE password_reset_tokens SET used_at = CURRENT_TIMESTAMP WHERE id = ?").run(reset.id);
  })();
  return NextResponse.json({ success: true, message: "Password updated. You can now sign in." });
}
