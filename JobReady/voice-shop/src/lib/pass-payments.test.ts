import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const databaseDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "voice-pass-test-"));
process.env.DATABASE_DIR = databaseDirectory;
process.env.DATABASE_PATH = "pass-test.db";
process.env.RAZORPAY_KEY_ID = "rzp_test_pass";
process.env.RAZORPAY_KEY_SECRET = "pass-test-secret";

test("verified pass payment activates exactly once", async () => {
  const { db } = await import("@/lib/db");
  const { verifyAndActivatePass } = await import("@/lib/pass-payments");
  const user = db.prepare(`INSERT INTO users(full_name, email, mobile, country, password_hash) VALUES ('Pass Test', 'pass@example.com', '9999999999', 'India', 'test')`).run();
  const userId = Number(user.lastInsertRowid);
  db.prepare(`INSERT INTO package_pass_orders(user_id, razorpay_order_id, pass_code, customer_type, amount_minor, currency) VALUES (?, 'order_pass_test', '7-day', 'personal', 49900, 'INR')`).run(userId);
  const paymentId = "pay_pass_test";
  const signature = crypto.createHmac("sha256", process.env.RAZORPAY_KEY_SECRET!).update(`order_pass_test|${paymentId}`).digest("hex");

  const firstResult = verifyAndActivatePass(userId, "order_pass_test", paymentId, signature);
  assert.deepEqual(firstResult, {
    activated: true,
    passCode: "7-day",
    customerType: "personal",
    activePass: {
      code: "7-day",
      customerType: "personal",
      startsAt: firstResult.activePass!.startsAt,
      expiresAt: firstResult.activePass!.expiresAt,
    },
  });

  const secondResult = verifyAndActivatePass(userId, "order_pass_test", paymentId, signature);
  assert.deepEqual(secondResult, {
    activated: false,
    passCode: "7-day",
    customerType: "personal",
    activePass: {
      code: "7-day",
      customerType: "personal",
      startsAt: secondResult.activePass!.startsAt,
      expiresAt: secondResult.activePass!.expiresAt,
    },
  });

  const count = db.prepare("SELECT COUNT(*) AS count FROM package_passes WHERE user_id = ?").get(userId) as { count: number };
  assert.equal(count.count, 1);
});
