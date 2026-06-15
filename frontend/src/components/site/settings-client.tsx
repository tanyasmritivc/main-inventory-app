"use client";

import { useEffect, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

export function SettingsClient(props: { email: string | null }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [signingOut, setSigningOut] = useState(false);
  const [isPro, setIsPro] = useState<boolean | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      const token = data.session?.access_token;
      if (!token) return;
      return fetch(`${apiBase()}/stripe/subscription-status`, {
        headers: { Authorization: `Bearer ${token}` },
      })
        .then((r) => (r.ok ? r.json() : null))
        .then((d: { is_pro?: boolean } | null) => {
          if (d && typeof d.is_pro === "boolean") setIsPro(d.is_pro);
        });
    }).catch(() => {});
  }, [supabase]);

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
      {/* PLAN */}
      <div style={{ marginBottom: 32 }}>
        <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 12 }}>Plan</p>
        {isPro === false && (
          <div style={{
            background: 'rgba(245,158,11,0.04)',
            border: '1px solid rgba(245,158,11,0.2)',
            borderRadius: 16,
            padding: '20px 24px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span>⭐</span>
              <span style={{ color: 'white', fontWeight: 600, fontSize: 15 }}>FindEZ Pro</span>
              <span style={{ marginLeft: 'auto', fontSize: 11, color: '#f59e0b', fontWeight: 600 }}>$6.99/mo or $59.99/yr</span>
            </div>
            <p style={{ color: '#a1a1a6', fontSize: 13, margin: '0 0 16px' }}>Unlimited items, spaces, AI scans, and sharing.</p>
            <a
              href="/upgrade"
              style={{
                display: 'block',
                textAlign: 'center',
                background: '#f59e0b',
                color: '#000',
                padding: '10px 20px',
                borderRadius: 99,
                fontWeight: 600,
                fontSize: 13,
                textDecoration: 'none',
              }}
            >
              Upgrade to Pro
            </a>
          </div>
        )}
        {isPro === true && (
          <div style={{
            background: 'rgba(34,197,94,0.04)',
            border: '1px solid rgba(34,197,94,0.15)',
            borderRadius: 16,
            padding: '16px 24px',
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}>
            <span style={{ color: '#22c55e', fontSize: 18 }}>✓</span>
            <div>
              <div style={{ color: 'white', fontWeight: 600, fontSize: 14 }}>FindEZ Pro — Active</div>
              <div style={{ color: '#a1a1a6', fontSize: 12 }}>Unlimited access to all features</div>
            </div>
          </div>
        )}
        {isPro === null && (
          <div style={{ height: 80, background: '#0a0a0a', borderRadius: 16, border: '1px solid #1c1c1e' }} />
        )}
      </div>
    </div>
  );
}
