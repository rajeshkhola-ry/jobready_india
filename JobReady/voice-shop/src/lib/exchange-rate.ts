const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

let rateCache: { month: string; value: number; cachedAt: number } | null = null;

export async function getMonthlyAverageUsdInrRate(now = new Date()) {
  const month = now.toISOString().slice(0, 7);
  if (rateCache?.month === month && Date.now() - rateCache.cachedAt < CACHE_TTL_MS) return rateCache.value;

  const fallback = Number(process.env.USD_INR_FALLBACK_RATE || 84);
  const start = `${month}-01`;
  const endDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0));
  const end = endDate.toISOString().slice(0, 10);
  const apiBase = process.env.EXCHANGE_RATE_API_URL || "https://api.frankfurter.app";

  try {
    const response = await fetch(`${apiBase}/${start}..${end}?from=USD&to=INR`, { next: { revalidate: 86400 } });
    if (!response.ok) throw new Error(`Exchange-rate API returned ${response.status}`);
    const data = (await response.json()) as { rates?: Record<string, { INR?: number }> };
    const rates = Object.values(data.rates || {}).map((entry) => entry.INR).filter((rate): rate is number => Number.isFinite(rate));
    if (!rates.length) throw new Error("No monthly INR rates returned");
    const average = rates.reduce((sum, rate) => sum + rate, 0) / rates.length;
    rateCache = { month, value: Number(average.toFixed(4)), cachedAt: Date.now() };
    return rateCache.value;
  } catch {
    return fallback;
  }
}
