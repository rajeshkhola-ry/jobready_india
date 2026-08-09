import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const databaseDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "voice-wallet-test-"));
process.env.DATABASE_DIR = databaseDirectory;
process.env.DATABASE_PATH = "wallet-test.db";
process.env.RAZORPAY_KEY_ID = "rzp_test_wallet";
process.env.RAZORPAY_KEY_SECRET = "wallet-test-secret";

test("verified wallet payment credits exactly once", async () => {
  const { db } = await import("@/lib/db");
  const { verifyAndCreditWallet } = await import("@/lib/wallet-payments");
  const user = db.prepare(`
    INSERT INTO users(full_name, email, mobile, country, password_hash)
    VALUES ('Wallet Test', 'wallet-test@example.com', '9999999999', 'India', 'test')
  `).run();
  const userId = Number(user.lastInsertRowid);
  db.prepare("INSERT INTO wallets(user_id) VALUES (?)").run(userId);
  db.prepare(`
    INSERT INTO wallet_topup_orders(user_id, razorpay_order_id, amount_paise, currency)
    VALUES (?, 'order_wallet_test', 10000, 'INR')
  `).run(userId);

  const paymentId = "pay_wallet_test";
  const signature = crypto.createHmac("sha256", process.env.RAZORPAY_KEY_SECRET!).update(`order_wallet_test|${paymentId}`).digest("hex");
  const first = verifyAndCreditWallet(userId, "order_wallet_test", paymentId, signature);
  const retry = verifyAndCreditWallet(userId, "order_wallet_test", paymentId, signature);

  assert.deepEqual(first, { credited: true, balancePaise: 10000 });
  assert.deepEqual(retry, { credited: false, balancePaise: 10000 });
  const wallet = db.prepare("SELECT balance_paise FROM wallets WHERE user_id = ?").get(userId) as { balance_paise: number };
  assert.equal(wallet.balance_paise, 10000);
});

test("completed order rejects another payment id", async () => {
  const { verifyAndCreditWallet } = await import("@/lib/wallet-payments");
  const signature = crypto.createHmac("sha256", process.env.RAZORPAY_KEY_SECRET!).update("order_wallet_test|pay_other").digest("hex");
  assert.throws(
    () => verifyAndCreditWallet(1, "order_wallet_test", "pay_other", signature),
    /already completed|not found/,
  );
});
