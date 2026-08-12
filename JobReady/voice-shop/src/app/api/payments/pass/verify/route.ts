import { NextResponse } from "next/server";
import { getActivePassForUser, getSession, setSession } from "@/lib/auth";
import { verifyAndActivatePass } from "@/lib/pass-payments";

export async function POST(request: Request) {
  const user = await getSession();
  if (!user) return NextResponse.json({ error: "Sign in before verifying a pass payment." }, { status: 401 });
  const body = await request.json().catch(() => null);
  const orderId = typeof body?.razorpay_order_id === "string" ? body.razorpay_order_id.trim() : "";
  const paymentId = typeof body?.razorpay_payment_id === "string" ? body.razorpay_payment_id.trim() : "";
  const signature = typeof body?.razorpay_signature === "string" ? body.razorpay_signature.trim() : "";
  if (!orderId || !paymentId || !signature) return NextResponse.json({ error: "Payment verification details are incomplete." }, { status: 400 });
  try {
    const result = verifyAndActivatePass(user.id, orderId, paymentId, signature);
    const activePass = getActivePassForUser(user.id) ?? result.activePass ?? null;
    await setSession({ ...user, activePass });
    return NextResponse.json({ success: true, ...result, activePass });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "Payment verification failed." }, { status: 400 });
  }
}
