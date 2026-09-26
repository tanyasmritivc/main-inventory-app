"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { userFacingError } from "@/lib/user-facing-error";

/**
 * React view of the signed-in session for client components. The token follows
 * sign-in and sign-out events. It may be older than the live token after an
 * hourly refresh; that is harmless because API requests read the live token.
 *
 * Request code should prefer `apiRequest`/`getAccessToken`, which read the
 * current token at request time; `token` here is for gating UI and for API
 * helpers that still take an explicit token.
 */
export function useApiSession() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) throw sessionError;
      if (!data.session) throw new Error("Your session has expired. Please sign in again.");
      setToken(data.session.access_token);
      return data.session.access_token;
    } catch (reason) {
      const message = userFacingError(reason, "Could not verify your session. Please sign in again.");
      setError(message); setToken(null); return null;
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => { void refresh(); }, [refresh]);

  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event, session) => {
      // INITIAL_SESSION is covered by refresh(). TOKEN_REFRESHED is ignored on
      // purpose: API requests read the live token themselves, and updating state
      // here would re-run every token-keyed effect once an hour.
      if (event === "INITIAL_SESSION" || event === "TOKEN_REFRESHED") return;
      if (session) {
        setToken(session.access_token);
        setError(null);
      } else if (event === "SIGNED_OUT") {
        setToken(null);
        setError("Your session has expired. Please sign in again.");
      }
    });
    return () => data.subscription.unsubscribe();
  }, [supabase]);

  return { token, loading, error, refresh, supabase };
}
