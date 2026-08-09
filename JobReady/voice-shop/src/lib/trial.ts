import { db } from "@/lib/db";

export const FREE_TRIAL_MINUTES = 2;
export const GLOBAL_FREE_TRIAL_CAP = 1000;

export type TrialClaimResult =
  | { granted: true; minutes: number; remainingGlobalClaims: number }
  | { granted: false; reason: "authentication_required" | "already_claimed" | "trial_disabled" | "global_cap_reached" };

export function claimFreeTrial(userId: number | null): TrialClaimResult {
  if (!userId) return { granted: false, reason: "authentication_required" };

  const transaction = db.transaction((): TrialClaimResult => {
    const existing = db.prepare("SELECT id FROM free_trial_claims WHERE user_id = ?").get(userId);
    if (existing) return { granted: false, reason: "already_claimed" };

    const count = Number((db.prepare("SELECT COUNT(*) AS count FROM free_trial_claims").get() as { count: number }).count);
    const setting = db.prepare("SELECT setting_value FROM platform_settings WHERE setting_key = 'free_trial_enabled'").get() as
      | { setting_value: string }
      | undefined;

    if (setting?.setting_value !== "true") {
      return { granted: false, reason: "trial_disabled" };
    }

    if (count >= GLOBAL_FREE_TRIAL_CAP) {
      db.prepare("UPDATE platform_settings SET setting_value = 'false', updated_at = CURRENT_TIMESTAMP WHERE setting_key = 'free_trial_enabled'").run();
      const hasAlert = db.prepare("SELECT id FROM admin_alerts WHERE alert_type = 'free_trial_cap' AND acknowledged_at IS NULL").get();
      if (!hasAlert) {
        db.prepare("INSERT INTO admin_alerts(alert_type, message) VALUES ('free_trial_cap', ?)").run(
          `The global ${GLOBAL_FREE_TRIAL_CAP}-account free-trial cap has been reached.`,
        );
      }
      return { granted: false, reason: "global_cap_reached" };
    }

    db.prepare("INSERT INTO free_trial_claims(user_id, minutes_granted) VALUES (?, ?)").run(userId, FREE_TRIAL_MINUTES);
    return { granted: true, minutes: FREE_TRIAL_MINUTES, remainingGlobalClaims: GLOBAL_FREE_TRIAL_CAP - count - 1 };
  });

  return transaction();
}
