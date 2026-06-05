"use client";

import { useEffect, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { asUsageType, USAGE_TYPE_OPTIONS, type UsageType } from "@/lib/personalization";

export function SettingsClient(props: { email: string | null }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [signingOut, setSigningOut] = useState(false);
  const [usageType, setUsageType] = useState<UsageType | null>(null);
  const [usageLoading, setUsageLoading] = useState(false);
  const [usageError, setUsageError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    setUsageLoading(true);
    setUsageError(null);
    supabase
      .auth.getUser()
      .then(({ data }) => {
        const user = data.user;
        if (!user) return null;
        return supabase.from("profiles").select("usage_type").eq("id", user.id).maybeSingle();
      })
      .then((res) => {
        if (!mounted) return;
        const data = (res as { data?: Record<string, unknown> | null } | null)?.data || null;
        setUsageType(asUsageType(data?.usage_type));
      })
      .catch(() => {
        if (!mounted) return;
        setUsageType(null);
      })
      .finally(() => {
        if (!mounted) return;
        setUsageLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [supabase]);

  async function saveUsageType(next: UsageType | null) {
    if (usageLoading) return;
    setUsageLoading(true);
    setUsageError(null);
    try {
      const {
        data: { user },
        error: userErr,
      } = await supabase.auth.getUser();
      if (userErr) throw userErr;
      if (!user) return;

      await supabase.from("profiles").upsert({ id: user.id, usage_type: next });
      setUsageType(next);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to save preference";
      setUsageError(msg);
    } finally {
      setUsageLoading(false);
    }
  }

  async function onSignOut() {
    if (signingOut) return;
    setSigningOut(true);
    try {
      await supabase.auth.signOut();
      window.location.href = "/";
    } finally {
      setSigningOut(false);
    }
  }

  return (
    <div>
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "#fff", margin: 0, letterSpacing: "-0.035em" }}>Settings</h1>
        <p style={{ fontSize: 13, color: "#6e6e73", marginTop: 6 }}>Manage your account.</p>
      </div>

      {/* ACCOUNT */}
      <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 12 }}>Account</p>
      <div style={{ background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 12, padding: "0 20px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 0", borderBottom: "1px solid #1c1c1e" }}>
          <span style={{ fontSize: 13, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>Email</span>
          <span style={{ fontSize: 13, color: "#f5f5f7", fontWeight: 400, letterSpacing: "-0.008em" }}>{props.email || "—"}</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 0" }}>
          <span style={{ fontSize: 13, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>Session</span>
          <button
            type="button"
            onClick={() => void onSignOut()}
            disabled={signingOut}
            style={{ background: "none", border: "none", color: "#ff453a", fontSize: 13, cursor: "pointer", padding: 0, opacity: signingOut ? 0.5 : 1, fontWeight: 400, letterSpacing: "-0.008em", transition: "color 150ms" }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = "#ff5a52"; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = "#ff453a"; }}
          >
            {signingOut ? "Signing out…" : "Sign out"}
          </button>
        </div>
      </div>

      {/* PREFERENCES */}
      <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 12, marginTop: 28 }}>Preferences</p>
      <div style={{ background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 12, padding: "0 20px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 0" }}>
          <div>
            <div style={{ fontSize: 13, color: "#f5f5f7", marginBottom: 2, fontWeight: 400, letterSpacing: "-0.008em" }}>AI usage type</div>
            <div style={{ fontSize: 11, color: "#6e6e73", fontWeight: 400, letterSpacing: "-0.005em" }}>Controls how the AI interprets your inventory</div>
          </div>
          <select
            value={usageType || ""}
            onChange={(e) => void saveUsageType(asUsageType(e.target.value) as UsageType | null)}
            style={{ width: 160, flexShrink: 0, background: "#111113", border: "1px solid #2c2c2e", borderRadius: 8, padding: "8px 12px", color: "#f5f5f7", fontSize: 12, fontWeight: 400, letterSpacing: "-0.008em", transition: "all 150ms" }}
            disabled={usageLoading}
          >
            <option value="">Not set</option>
            {USAGE_TYPE_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
      </div>
      {usageError && <p style={{ fontSize: 11, color: "#ff453a", marginTop: 8, fontWeight: 500, letterSpacing: "-0.005em" }}>{usageError}</p>}
      <button
        type="button"
        onClick={() => void saveUsageType(null)}
        disabled={usageLoading || !usageType}
        style={{ background: "#fff", border: "none", borderRadius: 8, padding: "9px 18px", color: "#000", fontSize: 12, cursor: "pointer", marginTop: 14, opacity: usageLoading || !usageType ? 0.4 : 1, fontWeight: 590, letterSpacing: "-0.02em", transition: "all 150ms" }}
      >
        Clear preference
      </button>
    </div>
  );
}
