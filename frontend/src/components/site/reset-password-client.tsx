"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";

import { useAppDialog } from "@/components/site/app-dialog-provider";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { userFacingError } from "@/lib/user-facing-error";

export function ResetPasswordClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const router = useRouter();
  const searchParams = useSearchParams();
  const { showNotice } = useAppDialog();
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [checking, setChecking] = useState(true);
  const [hasSession, setHasSession] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setHasSession(Boolean(data.session));
      setChecking(false);
    }).catch(() => {
      if (active) setChecking(false);
    });
    return () => { active = false; };
  }, [supabase]);

  async function save(event: FormEvent) {
    event.preventDefault();
    if (password.length < 8) {
      setError("Use at least 8 characters.");
      return;
    }
    if (password !== confirmation) {
      setError("The passwords do not match.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      await showNotice({ title: "Password updated", message: "Your new password is ready to use.", confirmLabel: "Continue" });
      router.replace("/inventory");
      router.refresh();
    } catch (reason) {
      setError(userFacingError(reason, "Your password could not be updated. Request a new reset link and try again."));
    } finally {
      setSaving(false);
    }
  }

  const expired = searchParams.get("error") === "expired";

  return (
    <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 20, background: "#08090b", color: "#f5f5f7" }}>
      <section style={{ width: "min(420px, 100%)", padding: 28, border: "1px solid rgba(255,255,255,.1)", borderRadius: 16, background: "#101116", boxShadow: "0 28px 90px rgba(0,0,0,.5)" }}>
        <div style={{ width: 34, height: 34, display: "grid", placeItems: "center", borderRadius: 9, background: "#fff", color: "#08090b", fontWeight: 800, marginBottom: 22 }}>F</div>
        <h1 style={{ margin: 0, fontSize: 24, letterSpacing: "-.035em" }}>Choose a new password</h1>
        <p style={{ margin: "8px 0 24px", color: "#858891", fontSize: 13, lineHeight: 1.55 }}>Use at least 8 characters and choose a password you don’t use elsewhere.</p>

        {checking ? <p style={{ color: "#858891", fontSize: 13 }}>Checking your reset link…</p> : null}
        {!checking && (!hasSession || expired) ? (
          <div>
            <p role="alert" style={{ color: "#ff7770", fontSize: 13, lineHeight: 1.55 }}>This reset link is invalid or has expired. Request a new one from the sign-in page.</p>
            <Link href="/signin" style={{ display: "inline-flex", marginTop: 10, color: "#9bbcf0", fontSize: 13 }}>Return to sign in</Link>
          </div>
        ) : null}

        {!checking && hasSession && !expired ? (
          <form onSubmit={save} style={{ display: "grid", gap: 15 }}>
            <label style={{ display: "grid", gap: 7, color: "#a8aab2", fontSize: 12 }}>
              New password
              <input autoFocus type="password" autoComplete="new-password" minLength={8} required value={password} onChange={(event) => setPassword(event.target.value)} style={{ height: 44, padding: "0 12px", border: "1px solid rgba(255,255,255,.13)", borderRadius: 10, outline: 0, background: "#090a0f", color: "#f5f5f7", fontSize: 14 }} />
            </label>
            <label style={{ display: "grid", gap: 7, color: "#a8aab2", fontSize: 12 }}>
              Confirm password
              <input type="password" autoComplete="new-password" minLength={8} required value={confirmation} onChange={(event) => setConfirmation(event.target.value)} style={{ height: 44, padding: "0 12px", border: "1px solid rgba(255,255,255,.13)", borderRadius: 10, outline: 0, background: "#090a0f", color: "#f5f5f7", fontSize: 14 }} />
            </label>
            {error ? <p role="alert" style={{ margin: 0, color: "#ff7770", fontSize: 12, lineHeight: 1.5 }}>{error}</p> : null}
            <button type="submit" disabled={saving} style={{ height: 44, border: 0, borderRadius: 10, background: "#fff", color: "#090a0f", fontWeight: 650, cursor: saving ? "not-allowed" : "pointer", opacity: saving ? .55 : 1 }}>{saving ? "Updating…" : "Update password"}</button>
          </form>
        ) : null}
      </section>
    </main>
  );
}
