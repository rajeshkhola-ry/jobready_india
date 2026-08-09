import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { db } from "@/lib/db";
import { getMonthlyAverageUsdInrRate } from "@/lib/exchange-rate";
import { createPassOrder, isCustomerType, isPassSelection } from "@/lib/pass-payments";
import { currencyForCountry } from "@/lib/pricing";

export async function POST(request: Request) {
  const user = await getSession();
  if (!user) return NextResponse.json({ error: "Sign in before purchasing a pass." }, { status: 401 });
  const body = await request.json().catch(() => null);
  if (!isPassSelection(body?.passCode) || !isCustomerType(body?.customerType)) return NextResponse.json({ error: "Choose a valid pass and usage type." }, { status: 400 });
  const requestHeaders = await headers();
  const account = db.prepare("SELECT country FROM users WHERE id = ?").get(user.id) as { country?: string } | undefined;
  const accountCountry = account?.country?.trim().toUpperCase() || "";
  const fallbackCountry = accountCountry === "INDIA" || accountCountry === "IN" ? "IN" : accountCountry || null;
  const country = requestHeaders.get("x-vercel-ip-country") || requestHeaders.get("cf-ipcountry") || requestHeaders.get("x-country-code") || fallbackCountry;
  try {
    return NextResponse.json(await createPassOrder(user.id, body.passCode, body.customerType, currencyForCountry(country), await getMonthlyAverageUsdInrRate()));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to create pass order.";
    return NextResponse.json({ error: message }, { status: message.includes("not configured") ? 503 : 502 });
  }
}
