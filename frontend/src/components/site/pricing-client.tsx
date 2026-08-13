"use client";

import { useState, useMemo } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { createBillingCheckout, createTeam } from "@/lib/api";

// ── Types ─────────────────────────────────────────────────────────────────────

type PaidPlan = "ftc_season" | "frc_season" | "district";
type AnyPlan = PaidPlan | "rookie";
type Program = "ftc" | "frc" | "vex" | "fll";

const PROGRAM_LABELS: Record<Program, string> = {
  ftc: "FIRST Tech Challenge",
  frc: "FIRST Robotics Competition",
  vex: "VEX Robotics",
  fll: "FIRST Lego League",
};

const PLAN_PROGRAMS: Record<AnyPlan, Program[]> = {
  ftc_season: ["ftc", "vex", "fll"],
  frc_season: ["frc"],
  district: ["ftc", "frc", "vex", "fll"],
  rookie: ["ftc", "frc", "vex", "fll"],
};

// ── Feature data ───────────────────────────────────────────────────────────────

const COMMON_FEATURES = [
  "Unlimited items & spaces",
  "2,000 AI chats / season per team",
  "600 photo scans / season per team",
  "Team join code — share with your roster",
  "Spreadsheet import & document attachments",
  "iOS app included",
];

const FAQ_ITEMS = [
  {
    q: "What's a join code?",
    a: "A 6-character code your team uses to join your FindEZ account. Share it in your group chat — members enter it on iOS or the web to get instant access to your shared inventory.",
  },
  {
    q: "When does the season plan expire?",
    a: "All plans run through August 31 — the full competitive season. You renew each fall for the next season.",
  },
  {
    q: "Does FindEZ work on iPhone?",
    a: "Yes. Your team plan syncs automatically to the iOS app. AI photo scanning, barcode lookup, and all inventory features are available on-device.",
  },
  {
    q: "What's the Rookie plan?",
    a: "A free plan for new and first-year teams. Core inventory features, no card required. One free team per account.",
  },
  {
    q: "We have multiple teams — what do we buy?",
    a: "The Organization Plan ($499) covers up to 10 teams from a single school or organization. One purchase, one join code per team.",
  },
];

// ── Styles ─────────────────────────────────────────────────────────────────────

const S = {
  page: {
    background: "#0a0a0a",
    minHeight: "100vh",
    color: "#f5f5f7",
    fontFamily: "var(--font-dm-sans, 'DM Sans', system-ui, sans-serif)",
  } as React.CSSProperties,

  nav: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "20px 32px",
    borderBottom: "1px solid rgba(255,255,255,0.06)",
    position: "sticky" as const,
    top: 0,
    background: "rgba(10,10,10,0.8)",
    backdropFilter: "blur(16px)",
    zIndex: 40,
  } as React.CSSProperties,

  wordmark: {
    fontFamily: "var(--font-syne, 'Syne', sans-serif)",
    fontSize: 18,
    fontWeight: 700,
    color: "#fff",
    letterSpacing: "-0.01em",
    textDecoration: "none",
  } as React.CSSProperties,

  hero: {
    textAlign: "center" as const,
    padding: "72px 24px 40px",
    maxWidth: 560,
    margin: "0 auto",
  } as React.CSSProperties,

  heroEyebrow: {
    fontSize: 11,
    fontWeight: 600,
    letterSpacing: "0.1em",
    textTransform: "uppercase" as const,
    color: "#a78bfa",
    marginBottom: 16,
  } as React.CSSProperties,

  heroHeading: {
    fontFamily: "var(--font-syne, 'Syne', sans-serif)",
    fontSize: "clamp(34px, 5vw, 50px)",
    fontWeight: 700,
    lineHeight: 1.1,
    letterSpacing: "-0.03em",
    color: "#fff",
    margin: 0,
  } as React.CSSProperties,

  heroSub: {
    fontSize: 16,
    color: "rgba(255,255,255,0.45)",
    marginTop: 14,
    lineHeight: 1.5,
  } as React.CSSProperties,

  grid: {
    display: "grid",
    gap: 16,
    maxWidth: 1040,
    margin: "0 auto",
    padding: "0 24px",
  } as React.CSSProperties,

  faqSection: {
    maxWidth: 640,
    margin: "80px auto 96px",
    padding: "0 24px",
  } as React.CSSProperties,

  faqHeading: {
    fontFamily: "var(--font-syne, 'Syne', sans-serif)",
    fontSize: 22,
    fontWeight: 600,
    letterSpacing: "-0.02em",
    color: "#fff",
    marginBottom: 32,
  } as React.CSSProperties,

  footer: {
    textAlign: "center" as const,
    padding: "24px",
    borderTop: "1px solid rgba(255,255,255,0.06)",
    color: "rgba(255,255,255,0.25)",
    fontSize: 12,
  } as React.CSSProperties,
};

// ── Sub-components ─────────────────────────────────────────────────────────────

function FeatureRow({ text }: { text: string }) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: 10,
        fontSize: 13.5,
        color: "rgba(255,255,255,0.7)",
        lineHeight: 1.4,
        paddingBottom: 10,
      }}
    >
      <span style={{ color: "#a78bfa", flexShrink: 0, marginTop: 1, fontSize: 12 }}>✓</span>
      {text}
    </div>
  );
}

function FaqRow({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div style={{ borderTop: "1px solid rgba(255,255,255,0.07)", padding: "20px 0" }}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        style={{
          background: "none",
          border: "none",
          width: "100%",
          textAlign: "left",
          cursor: "pointer",
          color: "#f5f5f7",
          fontFamily: "var(--font-dm-sans, 'DM Sans', sans-serif)",
          fontSize: 15,
          fontWeight: 500,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          gap: 16,
          padding: 0,
        }}
      >
        {q}
        <span
          style={{
            color: "rgba(255,255,255,0.3)",
            fontSize: 18,
            flexShrink: 0,
            transform: open ? "rotate(45deg)" : "none",
            transition: "transform 200ms",
            display: "inline-block",
          }}
        >
          +
        </span>
      </button>
      {open && (
        <p style={{ marginTop: 12, fontSize: 14, color: "rgba(255,255,255,0.45)", lineHeight: 1.65 }}>
          {a}
        </p>
      )}
    </div>
  );
}

// ── Checkout Modal ─────────────────────────────────────────────────────────────

function CheckoutModal({
  plan,
  onClose,
  onSubmit,
  loading,
  error,
}: {
  plan: AnyPlan;
  onClose: () => void;
  onSubmit: (teamName: string, program: Program) => void;
  loading: boolean;
  error: string | null;
}) {
  const programs = PLAN_PROGRAMS[plan];
  const isFrcOnly = programs.length === 1 && programs[0] === "frc";
  const [teamName, setTeamName] = useState("");
  const [program, setProgram] = useState<Program>(programs[0]);

  const planLabel = {
    ftc_season: "Team Plan — $99",
    frc_season: "Team Pro — $199",
    district: "Organization Plan — $499",
    rookie: "Rookie Plan — Free",
  }[plan];

  function submit() {
    const trimmed = teamName.trim();
    if (!trimmed) return;
    onSubmit(trimmed, isFrcOnly ? "frc" : program);
  }

  return (
    <div
      onClick={() => { if (!loading) onClose(); }}
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(0,0,0,0.78)",
        zIndex: 100,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 24,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          background: "#111",
          border: "1px solid rgba(255,255,255,0.10)",
          borderRadius: 20,
          padding: "32px 28px",
          maxWidth: 440,
          width: "100%",
          fontFamily: "var(--font-dm-sans, 'DM Sans', sans-serif)",
        }}
      >
        <h2
          style={{
            fontFamily: "var(--font-syne, 'Syne', sans-serif)",
            fontSize: 20,
            fontWeight: 700,
            color: "#fff",
            marginBottom: 6,
          }}
        >
          Set up your team
        </h2>
        <p style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", marginBottom: 28 }}>
          {planLabel}
        </p>

        <label style={{ display: "block", marginBottom: 18 }}>
          <div style={{ fontSize: 12, color: "rgba(255,255,255,0.5)", marginBottom: 6, fontWeight: 500 }}>
            Team name
          </div>
          <input
            autoFocus
            value={teamName}
            onChange={(e) => setTeamName(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") submit(); }}
            placeholder="e.g. Robo Ducks 12345"
            style={{
              width: "100%",
              background: "rgba(255,255,255,0.05)",
              border: "1px solid rgba(255,255,255,0.12)",
              borderRadius: 10,
              padding: "12px 14px",
              color: "#fff",
              fontSize: 14,
              outline: "none",
              boxSizing: "border-box",
              fontFamily: "inherit",
            }}
          />
        </label>

        {!isFrcOnly && (
          <label style={{ display: "block", marginBottom: 28 }}>
            <div style={{ fontSize: 12, color: "rgba(255,255,255,0.5)", marginBottom: 6, fontWeight: 500 }}>
              Program
            </div>
            <select
              value={program}
              onChange={(e) => setProgram(e.target.value as Program)}
              style={{
                width: "100%",
                background: "#1a1a1a",
                border: "1px solid rgba(255,255,255,0.12)",
                borderRadius: 10,
                padding: "12px 14px",
                color: "#fff",
                fontSize: 14,
                outline: "none",
                cursor: "pointer",
                fontFamily: "inherit",
              }}
            >
              {programs.map((p) => (
                <option key={p} value={p}>{PROGRAM_LABELS[p]}</option>
              ))}
            </select>
          </label>
        )}
        {isFrcOnly && (
          <div style={{ marginBottom: 28, fontSize: 13, color: "rgba(255,255,255,0.35)" }}>
            Program: FIRST Robotics Competition
          </div>
        )}

        {error && (
          <div
            style={{
              background: "rgba(255,69,58,0.1)",
              border: "1px solid rgba(255,69,58,0.25)",
              borderRadius: 8,
              padding: "10px 12px",
              fontSize: 13,
              color: "#ff453a",
              marginBottom: 16,
            }}
          >
            {error}
          </div>
        )}

        <div style={{ display: "flex", gap: 10 }}>
          <button
            type="button"
            onClick={() => { if (!loading) onClose(); }}
            style={{
              flex: 1,
              background: "transparent",
              color: "rgba(255,255,255,0.4)",
              border: "1px solid rgba(255,255,255,0.10)",
              borderRadius: 10,
              padding: "12px 0",
              fontSize: 14,
              cursor: "pointer",
              fontFamily: "inherit",
            }}
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={submit}
            disabled={loading || !teamName.trim()}
            style={{
              flex: 2,
              background: loading || !teamName.trim() ? "rgba(255,255,255,0.6)" : "#fff",
              color: "#000",
              border: "none",
              borderRadius: 10,
              padding: "12px 0",
              fontSize: 14,
              fontWeight: 700,
              cursor: loading || !teamName.trim() ? "not-allowed" : "pointer",
              fontFamily: "inherit",
            }}
          >
            {loading
              ? plan === "rookie" ? "Creating…" : "Redirecting…"
              : plan === "rookie" ? "Get Rookie Plan" : "Continue to checkout"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Main component ─────────────────────────────────────────────────────────────

export function PricingClient({ isAuthed }: { isAuthed: boolean }) {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [modalPlan, setModalPlan] = useState<AnyPlan | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function openModal(plan: AnyPlan) {
    if (!isAuthed) {
      router.push("/signup?next=/pricing");
      return;
    }
    setError(null);
    setModalPlan(plan);
  }

  async function handleSubmit(teamName: string, program: Program) {
    if (!modalPlan) return;
    setLoading(true);
    setError(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        router.push("/signin?next=/pricing");
        return;
      }
      const token = session.access_token;

      if (modalPlan === "rookie") {
        await createTeam({ token, name: teamName, program, rookie: true });
        router.push("/billing/success");
        return;
      }

      const result = await createBillingCheckout({ token, plan: modalPlan, program, team_name: teamName });
      if (result.url) window.location.href = result.url;
    } catch (e: unknown) {
      const ae = e as { status?: number; message?: string };
      if (ae.status === 409) {
        setError("You already have a team. Go to your dashboard to manage it.");
      } else {
        setError(ae.message || "Something went wrong. Please try again.");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={S.page}>
      {modalPlan && (
        <CheckoutModal
          plan={modalPlan}
          onClose={() => { if (!loading) setModalPlan(null); }}
          onSubmit={handleSubmit}
          loading={loading}
          error={error}
        />
      )}

      {/* Nav */}
      <nav style={S.nav}>
        <Link href="/" style={S.wordmark}>FindEZ</Link>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          {isAuthed ? (
            <Link href="/home" style={{ fontSize: 13, color: "rgba(255,255,255,0.6)", textDecoration: "none", padding: "7px 14px" }}>
              Dashboard
            </Link>
          ) : (
            <>
              <Link href="/signin" style={{ fontSize: 13, color: "rgba(255,255,255,0.6)", textDecoration: "none", padding: "7px 14px" }}>
                Sign in
              </Link>
              <Link href="/signup" style={{ fontSize: 13, fontWeight: 600, color: "#000", background: "#fff", textDecoration: "none", borderRadius: 99, padding: "7px 16px" }}>
                Get started
              </Link>
            </>
          )}
        </div>
      </nav>

      {/* Hero */}
      <section style={S.hero}>
        <div style={S.heroEyebrow}>Team Inventory Management</div>
        <h1 style={S.heroHeading}>Built for your team.</h1>
        <p style={S.heroSub}>One inventory for your whole team — parts, tools, kits, and everything else.</p>
      </section>

      {/* Rookie banner */}
      <div style={{ maxWidth: 1040, margin: "0 auto 32px", padding: "0 24px" }}>
        <div
          style={{
            background: "rgba(255,255,255,0.03)",
            border: "1px solid rgba(255,255,255,0.09)",
            borderRadius: 16,
            padding: "20px 24px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            gap: 16,
            flexWrap: "wrap",
          }}
        >
          <div>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase", color: "rgba(255,255,255,0.35)", marginBottom: 4 }}>
              New team?
            </div>
            <div style={{ fontSize: 15, fontWeight: 600, color: "#fff" }}>
              Start free with the Rookie Plan
            </div>
            <div style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", marginTop: 2 }}>
              Core inventory features for one season — no card required.
            </div>
          </div>
          <button
            type="button"
            onClick={() => openModal("rookie")}
            style={{
              background: "rgba(255,255,255,0.08)",
              color: "#fff",
              border: "1px solid rgba(255,255,255,0.12)",
              borderRadius: 10,
              padding: "11px 22px",
              fontSize: 14,
              fontWeight: 600,
              cursor: "pointer",
              flexShrink: 0,
              fontFamily: "inherit",
            }}
          >
            Get Rookie Plan →
          </button>
        </div>
      </div>

      {/* Paid plans grid */}
      <div className="pricing-grid" style={S.grid}>
        {/* Team */}
        <div
          style={{
            background: "rgba(167,139,250,0.03)",
            border: "1px solid rgba(167,139,250,0.22)",
            borderRadius: 20,
            padding: "28px 24px 24px",
            display: "flex",
            flexDirection: "column",
          }}
        >
          <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "#a78bfa", marginBottom: 16 }}>
            TEAM
          </div>
          <div style={{ marginBottom: 4 }}>
            <span style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 40, fontWeight: 700, letterSpacing: "-0.03em", color: "#fff" }}>$99</span>
            <span style={{ fontSize: 14, color: "rgba(255,255,255,0.35)", marginLeft: 4 }}>/ season</span>
          </div>
          <p style={{ fontSize: 12, color: "rgba(255,255,255,0.3)", marginBottom: 24 }}>One-time · expires Aug 31</p>
          <div style={{ flex: 1, marginBottom: 24 }}>
            {COMMON_FEATURES.map((f) => <FeatureRow key={f} text={f} />)}
          </div>
          <button
            type="button"
            onClick={() => openModal("ftc_season")}
            style={{
              background: "rgba(167,139,250,0.12)",
              color: "#a78bfa",
              border: "1px solid rgba(167,139,250,0.25)",
              borderRadius: 10,
              padding: "12px 0",
              fontSize: 14,
              fontWeight: 700,
              cursor: "pointer",
              width: "100%",
              fontFamily: "inherit",
            }}
          >
            Get Team Plan
          </button>
        </div>

        {/* Team Pro */}
        <div
          style={{
            background: "rgba(245,158,11,0.04)",
            border: "1.5px solid rgba(245,158,11,0.35)",
            borderRadius: 20,
            padding: "28px 24px 24px",
            display: "flex",
            flexDirection: "column",
            position: "relative",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
            <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "#f59e0b" }}>
              TEAM PRO
            </div>
            <div style={{ background: "rgba(245,158,11,0.15)", color: "#f59e0b", fontSize: 10, fontWeight: 700, letterSpacing: "0.04em", textTransform: "uppercase", borderRadius: 99, padding: "3px 9px" }}>
              Most popular
            </div>
          </div>
          <div style={{ marginBottom: 4 }}>
            <span style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 40, fontWeight: 700, letterSpacing: "-0.03em", color: "#fff" }}>$199</span>
            <span style={{ fontSize: 14, color: "rgba(255,255,255,0.35)", marginLeft: 4 }}>/ season</span>
          </div>
          <p style={{ fontSize: 12, color: "rgba(255,255,255,0.3)", marginBottom: 24 }}>One-time · expires Aug 31</p>
          <div style={{ flex: 1, marginBottom: 24 }}>
            {COMMON_FEATURES.map((f) => <FeatureRow key={f} text={f} />)}
            <FeatureRow text="Built for large, multi-category parts inventories" />
          </div>
          <button
            type="button"
            onClick={() => openModal("frc_season")}
            style={{
              background: "#f59e0b",
              color: "#000",
              border: "none",
              borderRadius: 10,
              padding: "13px 0",
              fontSize: 14,
              fontWeight: 700,
              cursor: "pointer",
              width: "100%",
              fontFamily: "inherit",
            }}
          >
            Get Team Pro
          </button>
        </div>

        {/* Organization */}
        <div
          style={{
            background: "rgba(48,209,88,0.03)",
            border: "1px solid rgba(48,209,88,0.20)",
            borderRadius: 20,
            padding: "28px 24px 24px",
            display: "flex",
            flexDirection: "column",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
            <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "#30d158" }}>
              ORGANIZATION
            </div>
            <div style={{ background: "rgba(48,209,88,0.12)", color: "#30d158", fontSize: 10, fontWeight: 700, letterSpacing: "0.04em", textTransform: "uppercase", borderRadius: 99, padding: "3px 9px" }}>
              10 teams
            </div>
          </div>
          <div style={{ marginBottom: 4 }}>
            <span style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 40, fontWeight: 700, letterSpacing: "-0.03em", color: "#fff" }}>$499</span>
            <span style={{ fontSize: 14, color: "rgba(255,255,255,0.35)", marginLeft: 4 }}>/ season</span>
          </div>
          <p style={{ fontSize: 12, color: "rgba(255,255,255,0.3)", marginBottom: 24 }}>One-time · expires Aug 31</p>
          <div style={{ flex: 1, marginBottom: 24 }}>
            {COMMON_FEATURES.map((f) => <FeatureRow key={f} text={f} />)}
            <FeatureRow text="Up to 10 teams across your organization" />
          </div>
          <button
            type="button"
            onClick={() => openModal("district")}
            style={{
              background: "rgba(48,209,88,0.12)",
              color: "#30d158",
              border: "1px solid rgba(48,209,88,0.25)",
              borderRadius: 10,
              padding: "12px 0",
              fontSize: 14,
              fontWeight: 700,
              cursor: "pointer",
              width: "100%",
              fontFamily: "inherit",
            }}
          >
            Get Organization Plan
          </button>
        </div>
      </div>

      <style>{`
        .pricing-grid { grid-template-columns: repeat(3, 1fr); }
        @media (max-width: 720px) { .pricing-grid { grid-template-columns: 1fr; } }
        @media (max-width: 960px) and (min-width: 721px) { .pricing-grid { grid-template-columns: 1fr 1fr; } }
      `}</style>

      {/* Individual / iOS-only card */}
      <div style={{ maxWidth: 1040, margin: "24px auto 0", padding: "0 24px" }}>
        <div
          style={{
            background: "rgba(255,255,255,0.02)",
            border: "1px solid rgba(255,255,255,0.07)",
            borderRadius: 16,
            padding: "20px 24px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            gap: 16,
            flexWrap: "wrap",
          }}
        >
          <div>
            <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "rgba(255,255,255,0.25)", marginBottom: 4 }}>
              Individual
            </div>
            <div style={{ fontSize: 15, fontWeight: 600, color: "rgba(255,255,255,0.5)" }}>
              Personal plan — iOS only
            </div>
            <div style={{ fontSize: 13, color: "rgba(255,255,255,0.28)", marginTop: 2 }}>
              Available as an in-app purchase in the FindEZ iOS app. Not available via web checkout.
            </div>
          </div>
          <div style={{ fontSize: 13, color: "rgba(255,255,255,0.22)", flexShrink: 0 }}>
            Download the iOS app →
          </div>
        </div>
      </div>

      {/* FAQ */}
      <section style={S.faqSection}>
        <h2 style={S.faqHeading}>Common questions</h2>
        {FAQ_ITEMS.map((item) => (
          <FaqRow key={item.q} q={item.q} a={item.a} />
        ))}
        <div style={{ borderTop: "1px solid rgba(255,255,255,0.07)" }} />
      </section>

      {/* Footer */}
      <footer style={S.footer}>© {new Date().getFullYear()} FindEZ</footer>
    </div>
  );
}
