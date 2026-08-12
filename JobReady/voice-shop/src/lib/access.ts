export type AccessAwareUser = {
  id?: number;
  email?: string;
  fullName?: string;
  role?: "user" | "admin";
  hasFreeTrial?: boolean;
  activePass?: { code: string; customerType: "personal" | "business"; startsAt: string; expiresAt: string } | null;
};

function normalizeActivePass(pass: AccessAwareUser["activePass"]): AccessAwareUser["activePass"] {
  if (!pass || typeof pass !== "object") return null;
  if (!pass.code || !pass.customerType || !pass.startsAt || !pass.expiresAt) return null;
  return pass;
}

export function hasVoiceShopAccess(user: AccessAwareUser | null | undefined): boolean {
  if (!user) return false;
  if (user.role === "admin") return true;
  if (normalizeActivePass(user.activePass)) return true;
  return Boolean(user.hasFreeTrial);
}
