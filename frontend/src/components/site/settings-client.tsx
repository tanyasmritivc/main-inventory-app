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
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <div className="glass-card" style={{ padding: "20px 24px" }}>
        <div className="label-section" style={{ marginBottom: 16 }}>Account</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <span style={{ fontSize: 14, color: "var(--text-secondary)" }}>Email</span>
            <span style={{ fontSize: 13, color: "var(--text-muted)" }}>{props.email || "—"}</span>
          </div>
          <div className="divider" />
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <span style={{ fontSize: 14, color: "var(--text-secondary)" }}>Session</span>
            <button
              type="button"
              onClick={() => void onSignOut()}
              disabled={signingOut}
              style={{ fontSize: 13, color: "var(--text-secondary)", background: "none", border: "none", cursor: "pointer", padding: 0, opacity: signingOut ? 0.5 : 1 }}
            >
              {signingOut ? "Signing out…" : "Sign out"}
            </button>
          </div>
        </div>
      </div>

      {/* Preferences section */}
      <div className="glass-card" style={{ padding: "20px 24px" }}>
        <div className="label-section" style={{ marginBottom: 16 }}>Preferences</div>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16 }}>
          <div>
            <div style={{ fontSize: 14, color: "var(--text-secondary)", marginBottom: 4 }}>AI usage type</div>
            <div style={{ fontSize: 12, color: "var(--text-muted)" }}>Controls how the AI interprets your inventory</div>
          </div>
          <select
            value={usageType || ""}
            onChange={(e) => void saveUsageType(asUsageType(e.target.value) as UsageType | null)}
            style={{ width: 180, flexShrink: 0 }}
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
        {usageError && <p style={{ fontSize: 12, color: "var(--danger)", marginTop: 12 }}>{usageError}</p>}
        <div style={{ display: "flex", justifyContent: "end", marginTop: 12 }}>
          <Button type="button" variant="outline" onClick={() => saveUsageType(null)} disabled={usageLoading || !usageType}>
            Clear
          </Button>
        </div>
      </div>
    </div>
  );
}
