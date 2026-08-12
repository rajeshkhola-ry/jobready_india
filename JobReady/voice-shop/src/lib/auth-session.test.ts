import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { buildSessionPayload, hasVoiceShopAccess, parseActivePassFromSession } from "@/lib/auth";

describe("auth session payload", () => {
  it("includes the active pass in the signed session payload", () => {
    const payload = buildSessionPayload({
      id: 42,
      email: "user@example.com",
      fullName: "Test User",
      activePass: {
        code: "1-day",
        customerType: "personal",
        startsAt: "2026-08-12T10:00:00.000Z",
        expiresAt: "2026-08-13T10:00:00.000Z",
      },
    });

    assert.equal(payload.email, "user@example.com");
    assert.deepEqual(payload.activePass, {
      code: "1-day",
      customerType: "personal",
      startsAt: "2026-08-12T10:00:00.000Z",
      expiresAt: "2026-08-13T10:00:00.000Z",
    });
  });

  it("normalizes pass metadata from the signed session", () => {
    const pass = parseActivePassFromSession({
      code: "30-day",
      customerType: "business",
      startsAt: "2026-08-10T00:00:00.000Z",
      expiresAt: "2026-09-09T00:00:00.000Z",
    });

    assert.deepEqual(pass, {
      code: "30-day",
      customerType: "business",
      startsAt: "2026-08-10T00:00:00.000Z",
      expiresAt: "2026-09-09T00:00:00.000Z",
    });
  });

  it("grants direct tool access for admin, active pass, and trial users", () => {
    assert.equal(hasVoiceShopAccess({ id: 1, email: "admin@example.com", fullName: "Admin", role: "admin" }), true);
    assert.equal(hasVoiceShopAccess({
      id: 2,
      email: "trial@example.com",
      fullName: "Trial User",
      hasFreeTrial: true,
    }), true);
    assert.equal(hasVoiceShopAccess({
      id: 3,
      email: "pass@example.com",
      fullName: "Pass User",
      activePass: {
        code: "7-day",
        customerType: "personal",
        startsAt: "2026-08-12T10:00:00.000Z",
        expiresAt: "2026-08-19T10:00:00.000Z",
      },
    }), true);
    assert.equal(hasVoiceShopAccess(null), false);
  });
});
