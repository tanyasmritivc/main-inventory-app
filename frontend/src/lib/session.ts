import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

/**
 * The one client-side source for the signed-in user's API access token.
 *
 * Read the token at request time instead of keeping it in component state:
 * Supabase refreshes access tokens roughly hourly, and `getSession()` returns the
 * current (refreshed) session from the singleton browser client without a
 * network round trip when the token is still valid.
 *
 * Returns null when there is no session. Server components use
 * `requireUser()` in `lib/auth-guard.ts` instead.
 */
export async function getAccessToken(): Promise<string | null> {
  try {
    const { data, error } = await createSupabaseBrowserClient().auth.getSession();
    if (error) return null;
    return data.session?.access_token ?? null;
  } catch {
    return null;
  }
}
