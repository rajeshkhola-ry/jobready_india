import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { verifyAndCreditWallet } from "@/lib/wallet-payments";

export async function POST(request: Request) {
  const user = await getSession();
  if (!user) return NextResponse.json({ error: "Sign in before verifying a payment." }, { status: 401 });
  const body = await request.json().catch(() => null);
  const orderId = typeof body?.razorpay_order_id === "string" ? body.razorpay_order_id.trim() : "";
  const paymentId = typeof body?.razorpay_payment_id === "string" ? body.razorpay_payment_id.trim() : "";
  const signature = typeof body?.razorpay_signature === "string" ? body.razorpay_signature.trim() : "";
  if (!orderId || !paymentId || !signature || orderId.length > 100 || paymentId.length > 100 || signature.length > 256) {
    return NextResponse.json({ error: "Payment verification details are incomplete." }, { status: 400 });
  }

  try {
    const result = verifyAndCreditWallet(user.id, orderId, paymentId, signature);
    return NextResponse.json({ success: true, ...result, balanceInr: result.balancePaise / 100 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Payment verification failed.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
