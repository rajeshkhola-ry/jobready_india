import crypto from "node:crypto";
import { db } from "@/lib/db";
import { WALLET_TOP_UPS_INR } from "@/lib/pricing";

type RazorpayOrder = { id: string; amount: number; currency: string; status: string };
type TopUpOrderRow = {
  user_id: number;
  amount_paise: number;
  currency: string;
  status: "created" | "paid";
  razorpay_payment_id: string | null;
};

function razorpayCredentials() {
  const keyId = process.env.RAZORPAY_KEY_ID?.trim() || "";
  const keySecret = process.env.RAZORPAY_KEY_SECRET?.trim() || "";
  if (!keyId || !keySecret) throw new Error("Razorpay wallet checkout is not configured.");
  return { keyId, keySecret };
}

export function isAllowedWalletTopUp(amountInr: number) {
  return (WALLET_TOP_UPS_INR as readonly number[]).includes(amountInr);
}

export async function createWalletTopUpOrder(userId: number, amountInr: number) {
  const { keyId, keySecret } = razorpayCredentials();
  const amountPaise = amountInr * 100;
  const receipt = `vs_${userId}_${Date.now()}`.slice(0, 40);
  const response = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      authorization: `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString("base64")}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ amount: amountPaise, currency: "INR", receipt, notes: { product: "voice-shop-wallet", userId: String(userId) } }),
    cache: "no-store",
  });
  const order = await response.json().catch(() => null) as RazorpayOrder | null;
  if (!response.ok || !order?.id || order.amount !== amountPaise || order.currency !== "INR") {
    throw new Error("Unable to create Razorpay wallet order.");
  }

  db.prepare(`
    INSERT INTO wallet_topup_orders(user_id, razorpay_order_id, amount_paise, currency)
    VALUES (?, ?, ?, 'INR')
  `).run(userId, order.id, amountPaise);
  return { keyId, orderId: order.id, amount: amountPaise, currency: "INR" as const };
}

function signaturesMatch(orderId: string, paymentId: string, suppliedSignature: string) {
  const { keySecret } = razorpayCredentials();
  const generated = crypto.createHmac("sha256", keySecret).update(`${orderId}|${paymentId}`).digest("hex");
  const expected = Buffer.from(generated);
  const actual = Buffer.from(suppliedSignature);
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

export function verifyAndCreditWallet(userId: number, orderId: string, paymentId: string, signature: string) {
  if (!signaturesMatch(orderId, paymentId, signature)) throw new Error("Payment signature verification failed.");

  return db.transaction(() => {
    const order = db.prepare(`
      SELECT user_id, amount_paise, currency, status, razorpay_payment_id
      FROM wallet_topup_orders WHERE razorpay_order_id = ?
    `).get(orderId) as TopUpOrderRow | undefined;
    if (!order || order.user_id !== userId) throw new Error("Wallet order was not found for this account.");
    if (order.currency !== "INR") throw new Error("Wallet order currency is invalid.");

    if (order.status === "paid" && order.razorpay_payment_id !== paymentId) {
      throw new Error("Wallet order was already completed with another payment.");
    }

    if (order.status === "created") {
      db.prepare("INSERT OR IGNORE INTO wallets(user_id) VALUES (?)").run(userId);
      db.prepare(`
        UPDATE wallet_topup_orders
        SET status = 'paid', razorpay_payment_id = ?, credited_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE razorpay_order_id = ? AND status = 'created'
      `).run(paymentId, orderId);
      db.prepare(`
        UPDATE wallets
        SET balance_paise = balance_paise + ?, updated_at = CURRENT_TIMESTAMP
        WHERE user_id = ?
      `).run(order.amount_paise, userId);
    }

    const wallet = db.prepare("SELECT balance_paise FROM wallets WHERE user_id = ?").get(userId) as { balance_paise: number };
    return { credited: order.status === "created", balancePaise: wallet.balance_paise };
  })();
}
