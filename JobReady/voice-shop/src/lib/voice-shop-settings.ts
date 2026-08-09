import { db } from "@/lib/db";

export type VoiceShopSettings = {
  freeTrialEnabled: boolean;
  personalRateInr: number;
  businessRateInr: number;
};

const defaults: VoiceShopSettings = {
  freeTrialEnabled: true,
  personalRateInr: 5,
  businessRateInr: 12.5,
};

export function getVoiceShopSettings(): VoiceShopSettings {
  const rows = db.prepare(`
    SELECT setting_key, setting_value FROM platform_settings
    WHERE setting_key IN ('free_trial_enabled', 'wallet_rate_personal_inr', 'wallet_rate_business_inr')
  `).all() as Array<{ setting_key: string; setting_value: string }>;
  const settings = new Map(rows.map((row) => [row.setting_key, row.setting_value]));
  return {
    freeTrialEnabled: settings.get("free_trial_enabled") === "true",
    personalRateInr: positiveNumber(settings.get("wallet_rate_personal_inr"), defaults.personalRateInr),
    businessRateInr: positiveNumber(settings.get("wallet_rate_business_inr"), defaults.businessRateInr),
  };
}

export function updateVoiceShopSettings(settings: VoiceShopSettings) {
  const statement = db.prepare(`
    INSERT INTO platform_settings(setting_key, setting_value, updated_at)
    VALUES (?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(setting_key) DO UPDATE SET setting_value = excluded.setting_value, updated_at = CURRENT_TIMESTAMP
  `);
  db.transaction(() => {
    statement.run("free_trial_enabled", String(settings.freeTrialEnabled));
    statement.run("wallet_rate_personal_inr", String(settings.personalRateInr));
    statement.run("wallet_rate_business_inr", String(settings.businessRateInr));
  })();
  return getVoiceShopSettings();
}

function positiveNumber(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
