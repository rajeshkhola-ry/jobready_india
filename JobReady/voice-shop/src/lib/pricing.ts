export type CurrencyCode = "INR" | "USD";
export type CustomerType = "personal" | "business";

export const WALLET_RATE_INR: Record<CustomerType, number> = {
  personal: 5,
  business: 12.5,
};

export const PASS_PRICES_INR = {
  "1-day": { personal: 99, business: 249 },
  "7-day": { personal: 499, business: 1249 },
  "30-day": { personal: 1499, business: 3749 },
  "1-year": { personal: 14999, business: 37499 },
} as const;

export const WALLET_TOP_UPS_INR = [100, 250, 500, 1000, 2500] as const;

export function currencyForCountry(countryCode: string | null | undefined): CurrencyCode {
  return countryCode?.trim().toUpperCase() === "IN" ? "INR" : "USD";
}

export function convertInrPrice(amountInr: number, currency: CurrencyCode, usdInrRate: number) {
  if (currency === "INR") return amountInr;
  if (!Number.isFinite(usdInrRate) || usdInrRate <= 0) throw new Error("Invalid USD-INR exchange rate");
  return Math.max(1, Math.round(amountInr / usdInrRate));
}

export function convertWalletRate(amountInr: number, currency: CurrencyCode, usdInrRate: number) {
  if (currency === "INR") return amountInr;
  if (!Number.isFinite(usdInrRate) || usdInrRate <= 0) throw new Error("Invalid USD-INR exchange rate");
  return Math.max(0.01, Number((amountInr / usdInrRate).toFixed(2)));
}

export function buildPriceCatalog(
  currency: CurrencyCode,
  usdInrRate: number,
  walletRatesInr: Record<CustomerType, number> = WALLET_RATE_INR,
) {
  return {
    currency,
    symbol: currency === "INR" ? "₹" : "$",
    exchangeRate: usdInrRate,
    walletRates: {
      personal: convertWalletRate(walletRatesInr.personal, currency, usdInrRate),
      business: convertWalletRate(walletRatesInr.business, currency, usdInrRate),
    },
    walletTopUps: WALLET_TOP_UPS_INR.map((amount) => convertInrPrice(amount, currency, usdInrRate)),
    passes: Object.entries(PASS_PRICES_INR).map(([code, prices]) => ({
      code,
      personal: convertInrPrice(prices.personal, currency, usdInrRate),
      business: convertInrPrice(prices.business, currency, usdInrRate),
    })),
  };
}
