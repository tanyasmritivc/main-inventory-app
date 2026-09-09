"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { normalizeAuthNext } from "@/lib/auth-callback";

export function AuthCallbackClient({ code, next }: { code: string | null; next: string }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const exchangeStarted = useRef(false);
  const [failed, setFailed] = useState(!code);

  useEffect(() => {
    if (exchangeStarted.current) return;
    exchangeStarted.current = true;

    if (!code) return;

    async function completeSignIn() {
      const { error } = await supabase.auth.exchangeCodeForSession(code as string);
      if (error) {
        window.history.replaceState({}, "", "/signin");
        setFailed(true);
        return;
      }

      // The browser client persists the session cookie before this navigation.
      window.location.replace(normalizeAuthNext(next));
    }

    void completeSignIn();
  }, [code, next, supabase]);

  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "#050506", color: "#f5f5f7", padding: 24 }}>
      <section style={{ width: "100%", maxWidth: 380, border: "1px solid #242426", borderRadius: 14, background: "#0a0a0b", padding: 32, textAlign: "center" }}>
        <h1 style={{ margin: 0, fontSize: 22 }}>{failed ? "Sign-in link could not be completed" : "Completing sign in…"}</h1>
        <p style={{ margin: "12px 0 0", color: "#a1a1a6", fontSize: 13, lineHeight: 1.5 }}>
          {failed ? "Please return to sign in and try again." : "FindEZ is securely connecting your account."}
        </p>
        {failed ? <Link href="/signin" style={{ display: "inline-flex", marginTop: 18, color: "#9bbcf0", fontSize: 13 }}>Return to sign in</Link> : null}
      </section>
    </main>
  );
}
