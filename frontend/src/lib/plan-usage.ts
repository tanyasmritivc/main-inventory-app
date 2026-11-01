import type { LimitsResponse } from "@/lib/api";

export function usageCount(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null;
}
export function usagePeriod(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return null;
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", timeZone: "UTC" }).format(date);
}
export function currentAccess(data: LimitsResponse) {
  if (data.pilot_mode === true) return "Free early access";
  // Legacy pro/team entitlements must not be relabeled as new subscriptions.
  if (data.tier === "pro") return "Pro · legacy access";
  if (data.tier === "team_member") return "Team access";
  return "Free";
}
