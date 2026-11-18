"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
  const [accountId, setAccountId] = useState<string | null>(null);
  const currentAccount = useRef<string | null>(null);
  const generation = useRef(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const request = ++generation.current;
    setLoading(true);
    setError(null);
    try {
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) throw sessionError;
      if (!data.session)
        throw new Error("Your session has expired. Please sign in again.");
      if (request !== generation.current) return null;
      currentAccount.current = data.session.user.id;
      setToken(data.session.access_token);
      setAccountId(data.session.user.id);
      return data.session.access_token;
    } catch (reason) {
      if (request !== generation.current) return null;
      const message = userFacingError(
        reason,
        "Could not verify your session. Please sign in again.",
      );
      setError(message);
      currentAccount.current = null;
      setToken(null);
      setAccountId(null);
      return null;
    } finally {
      if (request === generation.current) setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event, session) => {
      // Keep ordinary refreshes from restarting token-keyed page effects. A
      // recovered or different account must still replace the stale view.
      if (event === "INITIAL_SESSION") return;
      if (
        event === "TOKEN_REFRESHED" &&
        (!session || currentAccount.current === session.user.id)
      ) return;
      generation.current++;
      if (session) {
        currentAccount.current = session.user.id;
        setToken(session.access_token);
        setAccountId(session.user.id);
        setError(null);
        setLoading(false);
      } else if (event === "SIGNED_OUT") {
        currentAccount.current = null;
        setToken(null);
        setAccountId(null);
        setLoading(false);
        setError("Your session has expired. Please sign in again.");
      }
    });
    return () => {
      generation.current++;
      data.subscription.unsubscribe();
    };
  }, [supabase]);

  return { token, accountId, loading, error, refresh, supabase };
}
