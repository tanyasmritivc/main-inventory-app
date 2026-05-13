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
      {/* ACCOUNT */}
      <p className="text-[10px] font-medium tracking-[1.6px] uppercase text-white/30 mb-4">Account</p>
      <div style={{ borderBottom: "1px solid rgba(255,255,255,0.06)", paddingBottom: 0 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "16px 0", borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <span style={{ fontSize: 14, color: "rgba(255,255,255,0.6)" }}>Email</span>
          <span style={{ fontSize: 14, color: "white" }}>{props.email || "—"}</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "16px 0", borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <span style={{ fontSize: 14, color: "rgba(255,255,255,0.6)" }}>Session</span>
          <button
            type="button"
            onClick={() => void onSignOut()}
            disabled={signingOut}
            style={{ fontSize: 14, color: "white", background: "none", border: "none", cursor: "pointer", padding: 0, opacity: signingOut ? 0.5 : 1 }}
          >
            {signingOut ? "Signing out…" : "Sign out"}
          </button>
        </div>
      </div>

      {/* PREFERENCES */}
      <p className="text-[10px] font-medium tracking-[1.6px] uppercase text-white/30 mb-4" style={{ marginTop: 32 }}>Preferences</p>
      <div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "16px 0", borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <div>
            <div style={{ fontSize: 14, color: "rgba(255,255,255,0.6)", marginBottom: 2 }}>AI usage type</div>
            <div style={{ fontSize: 12, color: "rgba(255,255,255,0.3)" }}>Controls how the AI interprets your inventory</div>
          </div>
          <select
            value={usageType || ""}
            onChange={(e) => void saveUsageType(asUsageType(e.target.value) as UsageType | null)}
            style={{ width: 180, flexShrink: 0, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 8, color: "white", fontSize: 13, padding: "6px 10px" }}
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
        {usageError && <p style={{ fontSize: 12, color: "var(--danger)", marginTop: 8 }}>{usageError}</p>}
        <div style={{ display: "flex", justifyContent: "flex-end", marginTop: 16 }}>
          <button
            type="button"
            onClick={() => saveUsageType(null)}
            disabled={usageLoading || !usageType}
            style={{ fontSize: 13, color: "rgba(255,255,255,0.5)", background: "none", border: "none", cursor: "pointer", padding: 0, opacity: usageLoading || !usageType ? 0.4 : 1 }}
          >
            Clear
          </button>
        </div>
      </div>
    </div>
  );
}
