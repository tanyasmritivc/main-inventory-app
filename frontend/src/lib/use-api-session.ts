"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { userFacingError } from "@/lib/user-facing-error";

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
  return { token, loading, error, refresh, supabase };
}
