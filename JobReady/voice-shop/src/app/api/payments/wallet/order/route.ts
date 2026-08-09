import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { db } from "@/lib/db";
import { getMonthlyAverageUsdInrRate } from "@/lib/exchange-rate";
import { currencyForCountry } from "@/lib/pricing";
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
    const requestHeaders = await headers();
    const account = db.prepare("SELECT country FROM users WHERE id = ?").get(user.id) as { country?: string } | undefined;
    const accountCountry = account?.country?.trim().toUpperCase() || "";
    const fallbackCountry = accountCountry === "INDIA" || accountCountry === "IN" ? "IN" : accountCountry || null;
    const country = requestHeaders.get("x-vercel-ip-country") || requestHeaders.get("cf-ipcountry") || requestHeaders.get("x-country-code") || fallbackCountry;
    const currency = currencyForCountry(country);
    const usdInrRate = await getMonthlyAverageUsdInrRate();
    return NextResponse.json(await createWalletTopUpOrder(user.id, amountInr, currency, usdInrRate));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to create wallet order.";
    return NextResponse.json({ error: message }, { status: message.includes("not configured") ? 503 : 502 });
  }
}
