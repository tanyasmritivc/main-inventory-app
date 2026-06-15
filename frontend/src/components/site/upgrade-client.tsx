"use client";

import { useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

async function apiFetch<T>(
  path: string,
  opts: { method?: string; token: string; body?: BodyInit; headers?: Record<string, string> }
): Promise<T> {
  const res = await fetch(`${apiBase()}${path}`, {
    method: opts.method || "GET",
    headers: { Authorization: `Bearer ${opts.token}`, ...(opts.headers || {}) },
    body: opts.body,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${res.status}`);
  }
  return (await res.json()) as T;
}

const freeFeatures = [
  "Up to 30 items",
  "Up to 3 spaces",
  "5 AI photo scans/month",
  "10 AI chat messages/month",
];

const proFeatures = [
  "Unlimited items & spaces",
  "Unlimited AI photo scans",
  "Unlimited AI chat",
  "Share spaces with anyone",
  "Spreadsheet import",
  "Document attachments",
];

export function UpgradeClient() {
  const [plan, setPlan] = useState<"monthly" | "yearly">("monthly");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleUpgrade() {
    setLoading(true);
    setError(null);
    try {
      const sb = createSupabaseBrowserClient();
      const { data: { session } } = await sb.auth.getSession();
      if (!session) throw new Error("Not authenticated");
      const result = await apiFetch<{ url: string }>("/stripe/create-checkout-session", {
        method: "POST",
        token: session.access_token,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ plan }),
      });
      window.location.href = result.url;
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong");
      setLoading(false);
    }
  }

  return (
    <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "flex-start" }}>

      {/* ── Free Card ─────────────────────────────────────────── */}
      <div
        style={{
          flex: 1,
          minWidth: 260,
          background: "#0a0a0a",
          border: "1px solid #1c1c1e",
          borderRadius: 16,
          padding: "28px 24px",
        }}
      >
        <div style={{ marginBottom: 20 }}>
          <div style={{ fontSize: 11, color: "#6e6e73", fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", marginBottom: 10 }}>
            Free
          </div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 4 }}>
            <span style={{ fontSize: 36, fontWeight: 700, color: "#f5f5f7", fontFamily: "var(--font-syne, 'Syne', sans-serif)" }}>$0</span>
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 28 }}>
          {freeFeatures.map((f) => (
            <div key={f} style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 13, color: "#6e6e73" }}>
              <span style={{ color: "#3a3a3c", fontSize: 14, lineHeight: 1 }}>○</span>
              {f}
            </div>
          ))}
        </div>

        <button
          disabled
          style={{
            width: "100%",
            padding: "11px 0",
            borderRadius: 99,
            border: "1px solid #2c2c2e",
            background: "transparent",
            color: "#6e6e73",
            fontSize: 13,
            fontWeight: 500,
            cursor: "not-allowed",
            letterSpacing: "-0.01em",
          }}
        >
          Current Plan
        </button>
      </div>

      {/* ── Pro Card ──────────────────────────────────────────── */}
      <div
        style={{
          flex: 1,
          minWidth: 260,
          background: "#0a0a0a",
          border: "1px solid rgba(245,158,11,0.4)",
          borderRadius: 16,
          padding: "28px 24px",
          position: "relative",
        }}
      >
        {/* Header row */}
        <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 14 }}>
          <span style={{ fontSize: 14 }}>⭐</span>
          <span style={{ fontSize: 11, color: "#f59e0b", fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase" }}>Pro</span>
        </div>

        {/* Plan toggle */}
        <div style={{ display: "flex", gap: 6, marginBottom: 16 }}>
          {(["monthly", "yearly"] as const).map((p) => (
            <button
              key={p}
              onClick={() => setPlan(p)}
              style={{
                padding: "5px 12px",
                borderRadius: 99,
                border: plan === p ? "1px solid #f59e0b" : "1px solid #2c2c2e",
                background: plan === p ? "rgba(245,158,11,0.1)" : "transparent",
                color: plan === p ? "#f59e0b" : "#6e6e73",
                fontSize: 12,
                fontWeight: 500,
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                gap: 6,
                transition: "all 150ms",
              }}
            >
              {p === "monthly" ? "Monthly" : "Yearly"}
              {p === "yearly" && (
                <span
                  style={{
                    background: "#f59e0b",
                    color: "#000",
                    fontSize: 8,
                    fontWeight: 700,
                    padding: "2px 5px",
                    borderRadius: 99,
                    letterSpacing: "0.04em",
                  }}
                >
                  SAVE 28%
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Price */}
        <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginBottom: plan === "yearly" ? 4 : 20 }}>
          <span style={{ fontSize: 36, fontWeight: 700, color: "#f5f5f7", fontFamily: "var(--font-syne, 'Syne', sans-serif)" }}>
            {plan === "monthly" ? "$6.99" : "$59.99"}
          </span>
          <span style={{ fontSize: 13, color: "#6e6e73" }}>/{plan === "monthly" ? "mo" : "yr"}</span>
        </div>
        {plan === "yearly" && (
          <div style={{ fontSize: 12, color: "#f59e0b", marginBottom: 20 }}>Save 28% vs monthly</div>
        )}

        {/* Feature list */}
        <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 28 }}>
          {proFeatures.map((f) => (
            <div key={f} style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 13, color: "#a1a1a6" }}>
              <span style={{ color: "#f59e0b", fontSize: 13, lineHeight: 1 }}>✓</span>
              {f}
            </div>
          ))}
        </div>

        {error && (
          <div style={{ fontSize: 12, color: "#ff453a", marginBottom: 10 }}>{error}</div>
        )}

        <button
          onClick={() => void handleUpgrade()}
          disabled={loading}
          style={{
            width: "100%",
            padding: "12px 0",
            borderRadius: 99,
            border: "none",
            background: loading ? "#3a3a3c" : "#fff",
            color: "#000",
            fontSize: 14,
            fontWeight: 600,
            cursor: loading ? "not-allowed" : "pointer",
            letterSpacing: "-0.01em",
            transition: "background 150ms",
          }}
        >
          {loading ? "Redirecting…" : "Upgrade Now"}
        </button>
      </div>
    </div>
  );
}
