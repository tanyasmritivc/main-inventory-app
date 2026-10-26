"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { normalizeAuthNext, resolveAuthCallback } from "@/lib/auth-callback";

export function AuthCallbackClient({ code, next, errorCode }: { code: string | null; next: string; errorCode?: string | null }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const exchangeStarted = useRef(false);
  const [message, setMessage] = useState<string | null>(null);
  const failed = Boolean(message);

  useEffect(() => {
    if (exchangeStarted.current) return;
    exchangeStarted.current = true;

    async function completeSignIn() {
      const fragment = new URLSearchParams(window.location.hash.slice(1));
      const result = await resolveAuthCallback(supabase.auth, code, next, errorCode || fragment.get("error_code") || fragment.get("error"));
      if (result.error) {
        // Remove spent codes and provider error fragments from browser history.
        window.history.replaceState({}, "", "/auth/callback");
        setMessage(result.error);
        return;
      }
      window.location.replace(result.destination!);
    }

    void completeSignIn();
  }, [code, next, errorCode, supabase]);

  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "var(--light-page)", color: "var(--text-primary)", padding: 24 }}>
      <section style={{ width: "100%", maxWidth: 380, border: "1px solid var(--light-line)", borderRadius: 14, background: "var(--light-panel)", padding: 32, textAlign: "center" }}>
        <h1 style={{ margin: 0, fontSize: 22 }}>{failed ? "Sign-in link could not be completed" : "Completing sign in…"}</h1>
        <p style={{ margin: "12px 0 0", color: "var(--text-secondary)", fontSize: 13, lineHeight: 1.5 }}>
          {failed ? message : "FindEZ is securely connecting your account."}
        </p>
        {failed ? <Link href={`/signin?redirect=${encodeURIComponent(normalizeAuthNext(next))}`} style={{ display: "inline-flex", marginTop: 18, color: "var(--copper)", fontSize: 13 }}>Return to sign in or request a new link</Link> : null}
      </section>
    </main>
  );
}
