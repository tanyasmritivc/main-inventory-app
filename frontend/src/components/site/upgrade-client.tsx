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
  const [ctaHovered, setCtaHovered] = useState(false);

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

  const ctaLabel = loading
    ? "Redirecting…"
    : plan === "monthly"
    ? "Get Pro — $6.99/mo"
    : "Get Pro — $59.99/yr";

  return (
    <div style={{ maxWidth: 520, margin: "0 auto", padding: "48px 0 24px" }}>

      {/* ── Icon ── */}
      <div style={{
        width: 48, height: 48,
        background: "rgba(245,158,11,0.12)",
        borderRadius: "50%",
        display: "flex", alignItems: "center", justifyContent: "center",
        margin: "0 auto 20px",
      }}>
        <span style={{ fontSize: 22, lineHeight: 1 }}>⚡</span>
      </div>

      {/* ── Title ── */}
      <h1 style={{
        fontFamily: "var(--font-syne, 'Syne', sans-serif)",
        fontSize: 32, fontWeight: 700,
        color: "#fff", textAlign: "center",
        margin: 0,
      }}>
        FindEZ Pro
      </h1>

      {/* ── Subtitle ── */}
      <p style={{
        fontFamily: "var(--font-dm-sans, sans-serif)",
        fontSize: 16,
        color: "rgba(255,255,255,0.50)",
        textAlign: "center",
        marginTop: 8, marginBottom: 0,
      }}>
        Unlock the full power of FindEZ
      </p>

      {/* ── Feature list ── */}
      <div style={{ marginTop: 32 }}>
        {proFeatures.map((f, i) => (
          <div
            key={f}
            style={{
              display: "flex", alignItems: "center", gap: 12,
              padding: "14px 0",
              borderBottom: i < proFeatures.length - 1 ? "1px solid rgba(255,255,255,0.06)" : "none",
            }}
          >
            <div style={{
              width: 20, height: 20, flexShrink: 0,
              background: "rgba(245,158,11,0.15)",
              borderRadius: "50%",
              display: "flex", alignItems: "center", justifyContent: "center",
              color: "#f59e0b",
              fontSize: 11,
            }}>
              ✓
            </div>
            <span style={{
              fontFamily: "var(--font-dm-sans, sans-serif)",
              fontSize: 15,
              color: "rgba(255,255,255,0.85)",
            }}>
              {f}
            </span>
          </div>
        ))}
      </div>

      {/* ── Billing toggle ── */}
      <div style={{
        marginTop: 32,
        background: "rgba(255,255,255,0.06)",
        borderRadius: 99,
        padding: 4,
        display: "flex",
        width: "100%",
        boxSizing: "border-box",
      }}>
        <button
          onClick={() => setPlan("monthly")}
          style={{
            flex: 1,
            padding: "10px",
            borderRadius: 99,
            border: "none",
            background: plan === "monthly" ? "#fff" : "transparent",
            color: plan === "monthly" ? "#000" : "rgba(255,255,255,0.50)",
            fontSize: 14,
            fontWeight: plan === "monthly" ? 600 : 500,
            fontFamily: "var(--font-dm-sans, sans-serif)",
            cursor: "pointer",
            transition: "all 150ms",
          }}
        >
          Monthly
        </button>
        <button
          onClick={() => setPlan("yearly")}
          style={{
            flex: 1,
            padding: "10px",
            borderRadius: 99,
            border: "none",
            background: plan === "yearly" ? "#fff" : "transparent",
            color: plan === "yearly" ? "#000" : "rgba(255,255,255,0.50)",
            fontSize: 14,
            fontWeight: plan === "yearly" ? 600 : 500,
            fontFamily: "var(--font-dm-sans, sans-serif)",
            cursor: "pointer",
            transition: "all 150ms",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 6,
          }}
        >
          Yearly
          <span style={{ color: "#f59e0b", fontWeight: 600, fontSize: 12 }}>SAVE 28%</span>
        </button>
      </div>

      {/* ── Price display ── */}
      <div style={{ marginTop: 28, textAlign: "center" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "center", gap: 2 }}>
          <span style={{
            fontFamily: "var(--font-syne, 'Syne', sans-serif)",
            fontSize: 48, fontWeight: 700,
            color: "#fff",
          }}>
            {plan === "monthly" ? "$6.99" : "$59.99"}
          </span>
          <span style={{
            fontFamily: "var(--font-dm-sans, sans-serif)",
            fontSize: 15,
            color: "rgba(255,255,255,0.40)",
            marginLeft: 2,
          }}>
            {plan === "monthly" ? "/mo" : "/yr"}
          </span>
        </div>
        {plan === "yearly" && (
          <div style={{
            fontFamily: "var(--font-dm-sans, sans-serif)",
            fontSize: 13,
            color: "rgba(255,255,255,0.35)",
            marginTop: 4,
          }}>
            That&apos;s $5.00/mo — save $24/yr
          </div>
        )}
      </div>

      {/* ── Error ── */}
      {error && (
        <div style={{
          fontFamily: "var(--font-dm-sans, sans-serif)",
          fontSize: 13, color: "#ff453a",
          textAlign: "center", marginTop: 12,
        }}>
          {error}
        </div>
      )}

      {/* ── CTA button ── */}
      <button
        onClick={() => void handleUpgrade()}
        disabled={loading}
        onMouseEnter={() => setCtaHovered(true)}
        onMouseLeave={() => setCtaHovered(false)}
        style={{
          marginTop: 28,
          width: "100%",
          height: 52,
          background: loading ? "rgba(255,255,255,0.5)" : ctaHovered ? "rgba(255,255,255,0.90)" : "#fff",
          color: "#000",
          border: "none",
          borderRadius: 99,
          fontFamily: "var(--font-syne, 'Syne', sans-serif)",
          fontSize: 16,
          fontWeight: 600,
          cursor: loading ? "not-allowed" : "pointer",
          transition: "background 150ms",
        }}
      >
        {ctaLabel}
      </button>

      {/* ── Fine print ── */}
      <p style={{
        fontFamily: "var(--font-dm-sans, sans-serif)",
        fontSize: 12,
        color: "rgba(255,255,255,0.25)",
        textAlign: "center",
        marginTop: 16, marginBottom: 0,
      }}>
        Cancel anytime · No hidden fees
      </p>
    </div>
  );
}
