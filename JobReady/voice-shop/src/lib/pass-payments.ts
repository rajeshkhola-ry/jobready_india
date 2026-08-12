import crypto from "node:crypto";
import { db } from "@/lib/db";
import { getActivePassForUser } from "@/lib/auth";
import { convertInrPrice, PASS_PRICES_INR, type CurrencyCode, type CustomerType } from "@/lib/pricing";

type PassCode = keyof typeof PASS_PRICES_INR;
type RazorpayOrder = { id: string; amount: number; currency: string };
type PassOrder = { user_id: number; pass_code: PassCode; customer_type: CustomerType; status: "created" | "paid"; razorpay_payment_id: string | null };

const passDays: Record<PassCode, number> = { "1-day": 1, "7-day": 7, "30-day": 30, "1-year": 365 };

function credentials() {
  const keyId = process.env.RAZORPAY_KEY_ID?.trim() || "";
  const keySecret = process.env.RAZORPAY_KEY_SECRET?.trim() || "";
  if (!keyId || !keySecret) throw new Error("Razorpay pass checkout is not configured.");
  return { keyId, keySecret };
}

export function isPassSelection(value: unknown): value is PassCode {
  return typeof value === "string" && value in PASS_PRICES_INR;
}

export function isCustomerType(value: unknown): value is CustomerType {
  return value === "personal" || value === "business";
}

export async function createPassOrder(userId: number, passCode: PassCode, customerType: CustomerType, currency: CurrencyCode, usdInrRate: number) {
  const { keyId, keySecret } = credentials();
  const amount = convertInrPrice(PASS_PRICES_INR[passCode][customerType], currency, usdInrRate) * 100;
  const receipt = `vp_${userId}_${Date.now()}`.slice(0, 40);
  const response = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: { authorization: `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString("base64")}`, "content-type": "application/json" },
    body: JSON.stringify({ amount, currency, receipt, notes: { product: "voice-shop-pass", userId: String(userId), passCode, customerType } }),
    cache: "no-store",
  });
  const order = await response.json().catch(() => null) as RazorpayOrder | null;
  if (!response.ok || !order?.id || order.amount !== amount || order.currency !== currency) throw new Error("Unable to create Razorpay pass order.");
  db.prepare(`INSERT INTO package_pass_orders(user_id, razorpay_order_id, pass_code, customer_type, amount_minor, currency) VALUES (?, ?, ?, ?, ?, ?)`)
    .run(userId, order.id, passCode, customerType, amount, currency);
  return { keyId, orderId: order.id, amount, currency };
}

export function verifyAndActivatePass(userId: number, orderId: string, paymentId: string, signature: string) {
  const { keySecret } = credentials();
  const generated = crypto.createHmac("sha256", keySecret).update(`${orderId}|${paymentId}`).digest("hex");
  const expected = Buffer.from(generated);
  const actual = Buffer.from(signature);
  if (expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) throw new Error("Payment signature verification failed.");

  return db.transaction(() => {
    const order = db.prepare(`SELECT user_id, pass_code, customer_type, status, razorpay_payment_id FROM package_pass_orders WHERE razorpay_order_id = ?`).get(orderId) as PassOrder | undefined;
    if (!order || order.user_id !== userId) throw new Error("Pass order was not found for this account.");
    if (order.status === "paid" && order.razorpay_payment_id !== paymentId) throw new Error("Pass order was already completed with another payment.");
    if (order.status === "created") {
      const startsAt = new Date();
      const expiresAt = new Date(startsAt.getTime() + passDays[order.pass_code] * 86400000);
      db.prepare(`UPDATE package_pass_orders SET status = 'paid', razorpay_payment_id = ?, paid_at = CURRENT_TIMESTAMP WHERE razorpay_order_id = ? AND status = 'created'`).run(paymentId, orderId);
      db.prepare(`INSERT INTO package_passes(user_id, pass_code, starts_at, expires_at) VALUES (?, ?, ?, ?)`)
        .run(userId, `${order.pass_code}:${order.customer_type}`, startsAt.toISOString(), expiresAt.toISOString());
    }
    const activePass = getActivePassForUser(userId);
    return {
      activated: order.status === "created",
      passCode: order.pass_code,
      customerType: order.customer_type,
      activePass,
    };
  })();
}
