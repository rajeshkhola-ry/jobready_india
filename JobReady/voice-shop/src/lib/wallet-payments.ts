import crypto from "node:crypto";
import { db } from "@/lib/db";
import { convertInrPrice, type CurrencyCode, WALLET_TOP_UPS_INR } from "@/lib/pricing";

type RazorpayOrder = { id: string; amount: number; currency: string; status: string };
type TopUpOrderRow = {
  user_id: number;
  amount_paise: number;
  currency: string;
  status: "created" | "paid";
  razorpay_payment_id: string | null;
  wallet_credit_paise: number;
};

export type WalletTaxQuote = {
  currency: CurrencyCode;
  totalMinor: number;
  baseMinor: number;
  gstMinor: number;
  taxRatePercent: 0 | 18;
  taxTreatment: "gst_inclusive_domestic" | "export_of_services";
  walletCreditPaise: number;
  exchangeRate: number | null;
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

export function buildWalletTaxQuote(amountInr: number, currency: CurrencyCode, usdInrRate: number): WalletTaxQuote {
  const walletCreditPaise = amountInr * 100;
  const chargedAmount = convertInrPrice(amountInr, currency, usdInrRate);
  const totalMinor = chargedAmount * 100;
  if (currency === "INR") {
    const baseMinor = Math.round(totalMinor / 1.18);
    return {
      currency,
      totalMinor,
      baseMinor,
      gstMinor: totalMinor - baseMinor,
      taxRatePercent: 18,
      taxTreatment: "gst_inclusive_domestic",
      walletCreditPaise,
      exchangeRate: null,
    };
  }
  return {
    currency,
    totalMinor,
    baseMinor: totalMinor,
    gstMinor: 0,
    taxRatePercent: 0,
    taxTreatment: "export_of_services",
    walletCreditPaise,
    exchangeRate: usdInrRate,
  };
}

export async function createWalletTopUpOrder(userId: number, amountInr: number, currency: CurrencyCode, usdInrRate: number) {
  const { keyId, keySecret } = razorpayCredentials();
  const quote = buildWalletTaxQuote(amountInr, currency, usdInrRate);
  const receipt = `vs_${userId}_${Date.now()}`.slice(0, 40);
  const response = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      authorization: `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString("base64")}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ amount: quote.totalMinor, currency: quote.currency, receipt, notes: { product: "voice-shop-wallet", userId: String(userId), taxTreatment: quote.taxTreatment } }),
    cache: "no-store",
  });
  const order = await response.json().catch(() => null) as RazorpayOrder | null;
  if (!response.ok || !order?.id || order.amount !== quote.totalMinor || order.currency !== quote.currency) {
    throw new Error("Unable to create Razorpay wallet order.");
  }

  db.transaction(() => {
    const result = db.prepare(`
      INSERT INTO wallet_topup_orders(user_id, razorpay_order_id, amount_paise, currency)
      VALUES (?, ?, ?, ?)
    `).run(userId, order.id, quote.totalMinor, quote.currency);
    db.prepare(`
      INSERT INTO wallet_topup_tax_records(
        order_id, tax_treatment, tax_rate_bps, total_minor, base_minor, gst_minor, wallet_credit_paise, exchange_rate
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      Number(result.lastInsertRowid), quote.taxTreatment, quote.taxRatePercent * 100,
      quote.totalMinor, quote.baseMinor, quote.gstMinor, quote.walletCreditPaise, quote.exchangeRate,
    );
  })();
  return {
    keyId,
    orderId: order.id,
    amount: quote.totalMinor,
    currency: quote.currency,
    tax: {
      treatment: quote.taxTreatment,
      ratePercent: quote.taxRatePercent,
      total: quote.totalMinor / 100,
      base: quote.baseMinor / 100,
      gst: quote.gstMinor / 100,
    },
  };
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
      SELECT o.user_id, o.amount_paise, o.currency, o.status, o.razorpay_payment_id,
             t.wallet_credit_paise
      FROM wallet_topup_orders o
      JOIN wallet_topup_tax_records t ON t.order_id = o.id
      WHERE o.razorpay_order_id = ?
    `).get(orderId) as TopUpOrderRow | undefined;
    if (!order || order.user_id !== userId) throw new Error("Wallet order was not found for this account.");

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
      `).run(order.wallet_credit_paise, userId);
    }

    const wallet = db.prepare("SELECT balance_paise FROM wallets WHERE user_id = ?").get(userId) as { balance_paise: number };
    return { credited: order.status === "created", balancePaise: wallet.balance_paise };
  })();
}
