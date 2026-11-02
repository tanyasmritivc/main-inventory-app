import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { accountToken } from "@/lib/account-request";

export const PLAN_INTRO_VERSION = 1;
const dismissed = new Set<string>();
const key = (accountId: string) => `findez-plan-introduction:${accountId}`;
export function locallyDismissed(accountId: string) {
  try { return dismissed.has(accountId) || localStorage.getItem(key(accountId)) === String(PLAN_INTRO_VERSION); }
  catch { return dismissed.has(accountId); }
}
export function dismissLocally(accountId: string) {
  dismissed.add(accountId);
  try { localStorage.setItem(key(accountId), String(PLAN_INTRO_VERSION)); } catch { /* Optional browser storage. */ }
}

/** Bind the metadata write to the captured user's bearer, even if another
 * account signs in while it is pending. This marker never grants plan access. */
export async function persistPlanIntroduction(accountId: string, signal?: AbortSignal) {
  const token = await accountToken(accountId);
  const response = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/auth/v1/user`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}` },
    body: JSON.stringify({ data: { findez_plan_intro_version: PLAN_INTRO_VERSION } }),
    signal,
  });
  if (!response.ok) throw new Error("Could not sync plan introduction.");
  const user = await response.json();
  if (user.id !== accountId || user.user_metadata?.findez_plan_intro_version !== PLAN_INTRO_VERSION) throw new Error("Plan introduction was not confirmed.");
}

export async function shouldIntroducePlans(accountId: string, signal?: AbortSignal) {
  const { data, error } = await createSupabaseBrowserClient().auth.getUser();
  if (error || data.user?.id !== accountId || !data.user.email_confirmed_at) return false;
  if (data.user.user_metadata?.findez_plan_intro_version === PLAN_INTRO_VERSION) {
    dismissLocally(accountId);
    return false;
  }
  if (locallyDismissed(accountId)) {
    // Retry a previously offline dismissal without interrupting the user.
    await persistPlanIntroduction(accountId, signal).catch(() => {});
    return false;
  }
  return true;
}
