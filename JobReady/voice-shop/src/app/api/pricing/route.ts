import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { getMonthlyAverageUsdInrRate } from "@/lib/exchange-rate";
import { buildPriceCatalog, currencyForCountry } from "@/lib/pricing";
import { getVoiceShopSettings } from "@/lib/voice-shop-settings";

export async function GET() {
  const requestHeaders = await headers();
  const country = requestHeaders.get("x-vercel-ip-country") || requestHeaders.get("cf-ipcountry") || requestHeaders.get("x-country-code");
  const currency = currencyForCountry(country);
  const rate = await getMonthlyAverageUsdInrRate();
  const settings = getVoiceShopSettings();
  return NextResponse.json({
    country: country || "international",
    trialEnabled: settings.freeTrialEnabled,
    ...buildPriceCatalog(currency, rate, {
      personal: settings.personalRateInr,
      business: settings.businessRateInr,
    }),
  });
}
