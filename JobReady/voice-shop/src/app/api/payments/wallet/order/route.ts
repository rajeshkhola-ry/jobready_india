import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { createWalletTopUpOrder, isAllowedWalletTopUp } from "@/lib/wallet-payments";

export async function POST(request: Request) {
  const user = await getSession();
  if (!user) return NextResponse.json({ error: "Sign in before adding wallet funds." }, { status: 401 });
  const body = await request.json().catch(() => null);
  const amountInr = Number(body?.amountInr);
  if (!Number.isInteger(amountInr) || !isAllowedWalletTopUp(amountInr)) {
    return NextResponse.json({ error: "Choose a valid wallet top-up amount." }, { status: 400 });
  }

  try {
    return NextResponse.json(await createWalletTopUpOrder(user.id, amountInr));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to create wallet order.";
    return NextResponse.json({ error: message }, { status: message.includes("not configured") ? 503 : 502 });
  }
}
