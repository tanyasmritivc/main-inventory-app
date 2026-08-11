"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { getMyTeams, type TeamData } from "@/lib/api";

export function BillingSuccessClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [team, setTeam] = useState<TeamData | null>(null);
  const [copied, setCopied] = useState(false);
  const [timedOut, setTimedOut] = useState(false);
  const [polling, setPolling] = useState(true);

  const startPolling = useCallback(() => {
    let attempts = 0;
    const MAX_ATTEMPTS = 15; // 15 × 2 s = 30 s

    const attempt = async () => {
      const { data } = await supabase.auth.getSession();
      const token = data.session?.access_token;
      if (!token) {
        setPolling(false);
        setTimedOut(true);
        return;
      }
      try {
        const result = await getMyTeams({ token });
        const owned = (result.teams ?? []).filter((t) => t.role === "owner" && t.join_code);
        if (owned.length > 0) {
          setTeam(owned[0]);
          setPolling(false);
          return;
        }
      } catch (_) {
        // retry on error
      }
      attempts++;
      if (attempts >= MAX_ATTEMPTS) {
        setPolling(false);
        setTimedOut(true);
        return;
      }
      setTimeout(attempt, 2000);
    };

    void attempt();
  }, [supabase]);

  useEffect(() => { startPolling(); }, [startPolling]);

  async function copyCode() {
    if (!team?.join_code) return;
    try {
      await navigator.clipboard.writeText(team.join_code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    } catch (_) {}
  }

  const pageStyle: React.CSSProperties = {
    background: "#0a0a0a",
    minHeight: "100vh",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    padding: "40px 24px",
    fontFamily: "var(--font-dm-sans, 'DM Sans', system-ui, sans-serif)",
    color: "#f5f5f7",
    textAlign: "center",
  };

  // Still polling
  if (polling) {
    return (
      <div style={pageStyle}>
        <div
          style={{
            width: 48,
            height: 48,
            borderRadius: "50%",
            border: "2px solid rgba(255,255,255,0.08)",
            borderTopColor: "#a78bfa",
            animation: "spin 0.8s linear infinite",
            marginBottom: 28,
          }}
        />
        <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
        <h1 style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 24, fontWeight: 700, color: "#fff", marginBottom: 10 }}>
          Setting up your team…
        </h1>
        <p style={{ fontSize: 15, color: "rgba(255,255,255,0.4)", maxWidth: 320, lineHeight: 1.6 }}>
          Hang tight — this usually takes just a moment.
        </p>
      </div>
    );
  }

  // 30 s timeout fallback
  if (timedOut) {
    return (
      <div style={pageStyle}>
        <div style={{ fontSize: 40, marginBottom: 20 }}>⏱</div>
        <h1 style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 24, fontWeight: 700, color: "#fff", marginBottom: 10 }}>
          Still setting up…
        </h1>
        <p style={{ fontSize: 15, color: "rgba(255,255,255,0.4)", maxWidth: 360, lineHeight: 1.6, marginBottom: 32 }}>
          Your team is being created — it can take a couple of minutes. Your join code will appear in Settings once it&apos;s ready.
        </p>
        <div style={{ display: "flex", flexDirection: "column", gap: 12, width: "100%", maxWidth: 280 }}>
          <Link
            href="/settings"
            style={{ display: "block", background: "#fff", color: "#000", textDecoration: "none", borderRadius: 99, padding: "13px 0", fontSize: 14, fontWeight: 700 }}
          >
            Go to Settings
          </Link>
          <Link
            href="/home"
            style={{ display: "block", color: "rgba(255,255,255,0.35)", textDecoration: "none", fontSize: 14, padding: "12px 0" }}
          >
            Go to Dashboard
          </Link>
        </div>
      </div>
    );
  }

  // Success — join code ready
  if (team) {
    const expiryDate = team.plan_expires_at
      ? new Date(team.plan_expires_at).toLocaleDateString(undefined, { month: "long", day: "numeric", year: "numeric" })
      : null;

    return (
      <div style={pageStyle}>
        {/* Check circle */}
        <div
          style={{
            width: 64,
            height: 64,
            borderRadius: "50%",
            background: "rgba(48,209,88,0.1)",
            border: "1px solid rgba(48,209,88,0.25)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#30d158",
            fontSize: 26,
            marginBottom: 28,
          }}
        >
          ✓
        </div>

        <h1 style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 28, fontWeight: 700, color: "#fff", marginBottom: 8 }}>
          Your team is ready!
        </h1>
        <p style={{ fontSize: 15, color: "rgba(255,255,255,0.45)", marginBottom: 40, maxWidth: 360, lineHeight: 1.6 }}>
          Share this join code with your students. They enter it on iOS or the web to access your team&apos;s inventory.
        </p>

        {/* Join code */}
        <div
          style={{
            background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.12)",
            borderRadius: 20,
            padding: "28px 48px",
            marginBottom: 16,
          }}
        >
          <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "rgba(255,255,255,0.35)", marginBottom: 12 }}>
            {team.name} — Join Code
          </div>
          <div
            style={{
              fontFamily: "monospace",
              fontSize: "clamp(36px, 8vw, 56px)",
              fontWeight: 700,
              letterSpacing: "0.18em",
              color: "#fff",
              lineHeight: 1,
            }}
          >
            {team.join_code}
          </div>
        </div>

        {/* Copy button */}
        <button
          type="button"
          onClick={() => void copyCode()}
          style={{
            background: copied ? "rgba(48,209,88,0.15)" : "rgba(255,255,255,0.08)",
            color: copied ? "#30d158" : "#fff",
            border: `1px solid ${copied ? "rgba(48,209,88,0.3)" : "rgba(255,255,255,0.12)"}`,
            borderRadius: 99,
            padding: "12px 28px",
            fontSize: 14,
            fontWeight: 600,
            cursor: "pointer",
            marginBottom: 8,
            fontFamily: "inherit",
            transition: "all 200ms",
          }}
        >
          {copied ? "Copied!" : "Copy join code"}
        </button>

        {expiryDate && (
          <p style={{ fontSize: 12, color: "rgba(255,255,255,0.25)", marginBottom: 32, marginTop: 8 }}>
            Season active · expires {expiryDate}
          </p>
        )}
        {!expiryDate && <div style={{ marginBottom: 32 }} />}

        <div style={{ display: "flex", flexDirection: "column", gap: 12, width: "100%", maxWidth: 280 }}>
          <Link
            href="/home"
            style={{ display: "block", background: "#fff", color: "#000", textDecoration: "none", borderRadius: 99, padding: "13px 0", fontSize: 14, fontWeight: 700 }}
          >
            Go to Dashboard
          </Link>
          <Link
            href="/settings"
            style={{ display: "block", color: "rgba(255,255,255,0.35)", textDecoration: "none", fontSize: 14, padding: "12px 0" }}
          >
            View Settings
          </Link>
        </div>
      </div>
    );
  }

  return null;
}
