"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { getMyLimits, type LimitsResponse } from "@/lib/api";

export function BillingSuccessClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [limits, setLimits] = useState<LimitsResponse | null>(null);
  const [checked, setChecked] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      const token = data.session?.access_token;
      if (!token) {
        setChecked(true);
        return;
      }
      getMyLimits({ token })
        .then((l) => {
          setLimits(l);
          setChecked(true);
        })
        .catch(() => setChecked(true));
    });
  }, [supabase]);

  const tierLabel =
    limits?.tier === "pro"
      ? "Pro"
      : limits?.tier === "team_member"
      ? "Team"
      : null;

  return (
    <div
      style={{
        background: "#0a0a0a",
        minHeight: "100vh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "40px 24px",
        fontFamily: "var(--font-dm-sans, 'DM Sans', system-ui, sans-serif)",
        color: "#f5f5f7",
      }}
    >
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

      <h1
        style={{
          fontFamily: "var(--font-syne, 'Syne', sans-serif)",
          fontSize: 28,
          fontWeight: 700,
          letterSpacing: "-0.02em",
          color: "#fff",
          margin: 0,
          marginBottom: 12,
          textAlign: "center",
        }}
      >
        {checked && tierLabel ? `You're on ${tierLabel}!` : "You're all set!"}
      </h1>

      <p
        style={{
          fontSize: 15,
          color: "rgba(255,255,255,0.45)",
          textAlign: "center",
          maxWidth: 360,
          lineHeight: 1.6,
          marginBottom: 36,
        }}
      >
        {checked && tierLabel
          ? `Your ${tierLabel} plan is active. Everything syncs automatically — open the app and you're good to go.`
          : "Your plan is active. Open the app to start using your full allowance."}
      </p>

      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: 12,
          width: "100%",
          maxWidth: 280,
        }}
      >
        <Link
          href="/settings"
          style={{
            display: "block",
            background: "#fff",
            color: "#000",
            textDecoration: "none",
            borderRadius: 99,
            padding: "13px 0",
            fontSize: 14,
            fontWeight: 700,
            textAlign: "center",
          }}
        >
          View Settings
        </Link>
        <Link
          href="/home"
          style={{
            display: "block",
            color: "rgba(255,255,255,0.4)",
            textDecoration: "none",
            borderRadius: 99,
            padding: "12px 0",
            fontSize: 14,
            textAlign: "center",
          }}
        >
          Go to Dashboard
        </Link>
      </div>
    </div>
  );
}
