/**
 * Pilot-mode logic tests — no React renderer needed.
 *
 * These tests cover the data-layer behaviour: what fields the LimitsResponse
 * type accepts and how the pilot-mode flag should influence UI decisions.
 *
 * Run with: npx jest src/__tests__/pilot-mode.test.ts
 * (add jest + ts-jest to devDependencies if a test runner is not yet configured)
 */

import type { LimitsResponse } from "../lib/api";

// ── helpers ──────────────────────────────────────────────────────────────────

function makeLimits(overrides: Partial<LimitsResponse> = {}): LimitsResponse {
  return {
    tier: "free",
    items: { used: 0, max: null },
    spaces: { used: 0, max: null },
    chats: { used: 0, max: null, resets_at: "2026-10-01T00:00:00Z" },
    scans: { used: 0, max: null, daily_used: 0, daily_max: null, resets_at: "2026-10-01T00:00:00Z" },
    pilot_mode: false,
    pilot_ends_at: null,
    pilot_notice: null,
    ...overrides,
  };
}

function isPilotActive(limits: LimitsResponse): boolean {
  return limits.pilot_mode === true;
}

function shouldShowUpgradeCta(limits: LimitsResponse): boolean {
  return !isPilotActive(limits) && limits.tier === "free";
}

function shouldShowManageBilling(limits: LimitsResponse): boolean {
  return !isPilotActive(limits) && limits.tier !== "free";
}

function shouldBlockCheckout(limits: LimitsResponse): boolean {
  return isPilotActive(limits);
}

// ── pilot active ─────────────────────────────────────────────────────────────

describe("pilot mode active", () => {
  const pilotLimits = makeLimits({
    pilot_mode: true,
    pilot_ends_at: "2026-09-11T23:59:59Z",
    pilot_notice:
      "Free Pilot: Unlimited access through September 11, 2026. " +
      "Standard free-plan limits and optional paid plans begin September 12. " +
      "You will not be charged automatically.",
  });

  test("isPilotActive returns true", () => {
    expect(isPilotActive(pilotLimits)).toBe(true);
  });

  test("upgrade CTA is hidden during pilot", () => {
    expect(shouldShowUpgradeCta(pilotLimits)).toBe(false);
  });

  test("manage billing is hidden during pilot", () => {
    expect(shouldShowManageBilling(pilotLimits)).toBe(false);
  });

  test("checkout is blocked during pilot", () => {
    expect(shouldBlockCheckout(pilotLimits)).toBe(true);
  });

  test("pilot_ends_at is present", () => {
    expect(pilotLimits.pilot_ends_at).toBe("2026-09-11T23:59:59Z");
  });

  test("pilot_notice mentions September 11", () => {
    expect(pilotLimits.pilot_notice).toContain("September 11, 2026");
  });

  test("pilot_notice mentions September 12", () => {
    expect(pilotLimits.pilot_notice).toContain("September 12");
  });

  test("pilot_notice says no automatic charge", () => {
    expect(pilotLimits.pilot_notice).toContain("not be charged automatically");
  });

  test("limits remain unlimited (null max) during pilot", () => {
    expect(pilotLimits.items.max).toBeNull();
    expect(pilotLimits.spaces.max).toBeNull();
    expect(pilotLimits.chats.max).toBeNull();
    expect(pilotLimits.scans.max).toBeNull();
  });
});

// ── pilot inactive ────────────────────────────────────────────────────────────

describe("pilot mode inactive — free tier", () => {
  const freeLimits = makeLimits({
    items: { used: 5, max: 30 },
    spaces: { used: 1, max: 3 },
    chats: { used: 3, max: 20, resets_at: "2026-10-01T00:00:00Z" },
    scans: { used: 2, max: 10, daily_used: 1, daily_max: null, resets_at: "2026-10-01T00:00:00Z" },
  });

  test("isPilotActive returns false", () => {
    expect(isPilotActive(freeLimits)).toBe(false);
  });

  test("upgrade CTA is shown on free tier", () => {
    expect(shouldShowUpgradeCta(freeLimits)).toBe(true);
  });

  test("manage billing is hidden on free tier", () => {
    expect(shouldShowManageBilling(freeLimits)).toBe(false);
  });

  test("checkout is not blocked", () => {
    expect(shouldBlockCheckout(freeLimits)).toBe(false);
  });

  test("pilot fields are absent / null", () => {
    expect(freeLimits.pilot_mode).toBe(false);
    expect(freeLimits.pilot_ends_at).toBeNull();
    expect(freeLimits.pilot_notice).toBeNull();
  });
});

describe("pilot mode inactive — pro tier", () => {
  const proLimits = makeLimits({ tier: "pro" });

  test("upgrade CTA is hidden on pro tier", () => {
    expect(shouldShowUpgradeCta(proLimits)).toBe(false);
  });

  test("manage billing is shown on pro tier", () => {
    expect(shouldShowManageBilling(proLimits)).toBe(true);
  });
});

// ── LimitsResponse type accepts pilot fields (compile-time check) ─────────────

describe("LimitsResponse type", () => {
  test("accepts pilot_mode, pilot_ends_at, pilot_notice", () => {
    const l: LimitsResponse = makeLimits({
      pilot_mode: true,
      pilot_ends_at: "2026-09-11T23:59:59Z",
      pilot_notice: "Free Pilot notice",
    });
    expect(l.pilot_mode).toBe(true);
    expect(l.pilot_ends_at).toBe("2026-09-11T23:59:59Z");
    expect(l.pilot_notice).toBe("Free Pilot notice");
  });

  test("pilot fields are optional — omitting them is valid", () => {
    const l: LimitsResponse = {
      tier: "free",
      items: { used: 0, max: 30 },
      spaces: { used: 0, max: 3 },
      chats: { used: 0, max: 20, resets_at: "2026-10-01T00:00:00Z" },
      scans: { used: 0, max: 5, daily_used: 0, daily_max: null, resets_at: "2026-10-01T00:00:00Z" },
    };
    expect(l.pilot_mode).toBeUndefined();
    expect(l.pilot_ends_at).toBeUndefined();
    expect(l.pilot_notice).toBeUndefined();
  });
});
