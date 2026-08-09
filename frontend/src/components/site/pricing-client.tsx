"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { createBillingCheckout } from "@/lib/api";

// ── Feature definitions ────────────────────────────────────────────────────────

const FREE_FEATURES = [
  "Up to 30 items",
  "3 spaces",
  "20 AI chats / month",
  "10 photo scans / month",
  "1 shared space",
  "Barcode lookup",
];

const PRO_FEATURES = [
  "Unlimited items & spaces",
  "1,000 AI chats / month",
  "300 photo scans / month",
  "Unlimited shared spaces",
  "Spreadsheet import",
  "Document attachments",
];

const TEAM_FEATURES = [
  "Everything in Pro for your team",
  "Shared spaces with edit permissions",
  "Team inventory management",
  "Shared low-stock thresholds (coming soon)",
];

const FAQ_ITEMS = [
  {
    q: "What is the FOUNDING49 discount?",
    a: "Enter the code FOUNDING49 at checkout for $50 off your first season of Team. That brings the first year to $49 — then $99/yr after.",
  },
  {
    q: "Does FindEZ work on iPhone?",
    a: "Yes. Purchase your plan here on the web and everything syncs automatically to the iOS app. Web checkout keeps pricing consistent — in-app purchases aren't available on iOS.",
  },
  {
    q: "What happens when I hit the free limit?",
    a: "The app tells you clearly and offers an upgrade path. Your existing data is never deleted or locked — you just can't add more until you upgrade.",
  },
  {
    q: "Can I cancel my subscription?",
    a: "Any time, from the billing portal in Settings. You keep Pro or Team access through the end of your paid period.",
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
    padding: "72px 24px 48px",
    maxWidth: 560,
    margin: "0 auto",
  } as React.CSSProperties,

  heroHeading: {
    fontFamily: "var(--font-syne, 'Syne', sans-serif)",
    fontSize: "clamp(36px, 5vw, 52px)",
    fontWeight: 700,
    lineHeight: 1.1,
    letterSpacing: "-0.03em",
    color: "#fff",
    margin: 0,
    textWrap: "balance",
  } as React.CSSProperties,

  heroSub: {
    fontFamily: "var(--font-dm-sans, 'DM Sans', sans-serif)",
    fontSize: 17,
    color: "rgba(255,255,255,0.45)",
    marginTop: 16,
    lineHeight: 1.5,
  } as React.CSSProperties,

  toggleWrap: {
    display: "flex",
    justifyContent: "center",
    marginBottom: 40,
  } as React.CSSProperties,

  toggle: {
    display: "inline-flex",
    background: "rgba(255,255,255,0.06)",
    border: "1px solid rgba(255,255,255,0.09)",
    borderRadius: 99,
    padding: 3,
    gap: 2,
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

function ToggleButton({
  label,
  badge,
  active,
  onClick,
}: {
  label: string;
  badge?: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        background: active ? "#fff" : "transparent",
        color: active ? "#000" : "rgba(255,255,255,0.5)",
        border: "none",
        borderRadius: 99,
        padding: "7px 18px",
        fontSize: 13,
        fontWeight: 600,
        cursor: "pointer",
        display: "flex",
        alignItems: "center",
        gap: 7,
        transition: "background 150ms, color 150ms",
        fontFamily: "inherit",
      }}
    >
      {label}
      {badge && (
        <span
          style={{
            background: active ? "#a78bfa" : "rgba(167,139,250,0.2)",
            color: active ? "#fff" : "#a78bfa",
            fontSize: 10,
            fontWeight: 700,
            letterSpacing: "0.02em",
            borderRadius: 99,
            padding: "2px 6px",
            transition: "background 150ms, color 150ms",
          }}
        >
          {badge}
        </span>
      )}
    </button>
  );
}

function FeatureRow({ text, muted }: { text: string; muted?: boolean }) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: 10,
        fontSize: 14,
        color: muted ? "rgba(255,255,255,0.35)" : "rgba(255,255,255,0.7)",
        lineHeight: 1.4,
        paddingBottom: 10,
      }}
    >
      <span
        style={{
          color: muted ? "rgba(255,255,255,0.2)" : "#a78bfa",
          flexShrink: 0,
          marginTop: 1,
          fontSize: 12,
        }}
      >
        ✓
      </span>
      {text}
    </div>
  );
}

function FaqRow({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div
      style={{
        borderTop: "1px solid rgba(255,255,255,0.07)",
        padding: "20px 0",
      }}
    >
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
          }}
        >
          +
        </span>
      </button>
      {open && (
        <p
          style={{
            marginTop: 12,
            fontSize: 14,
            color: "rgba(255,255,255,0.45)",
            lineHeight: 1.65,
            fontFamily: "var(--font-dm-sans, 'DM Sans', sans-serif)",
          }}
        >
          {a}
        </p>
      )}
    </div>
  );
}

// ── Main component ─────────────────────────────────────────────────────────────

export function PricingClient({ isAuthed }: { isAuthed: boolean }) {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [billing, setBilling] = useState<"monthly" | "annual">("monthly");
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleCheckout(plan: "pro_monthly" | "pro_annual" | "team_season") {
    if (!isAuthed) {
      router.push("/signup?next=/pricing");
      return;
    }
    setLoading(plan);
    setError(null);
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session) {
        router.push("/signin?next=/pricing");
        return;
      }
      const result = await createBillingCheckout({ token: session.access_token, plan });
      if (result.url) window.location.href = result.url;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Something went wrong. Try again.";
      setError(msg);
    } finally {
      setLoading(null);
    }
  }

  const proPrice = billing === "monthly" ? "$6.99" : "$4.92";
  const proPeriod = billing === "monthly" ? "/month" : "/month";
  const proSubNote = billing === "monthly" ? "Billed monthly" : "Billed $59/year — save 29%";
  const proPlan: "pro_monthly" | "pro_annual" =
    billing === "monthly" ? "pro_monthly" : "pro_annual";

  return (
    <div style={S.page}>
      {/* Nav */}
      <nav style={S.nav}>
        <Link href="/" style={S.wordmark}>
          FindEZ
        </Link>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          {isAuthed ? (
            <Link
              href="/home"
              style={{
                fontSize: 13,
                color: "rgba(255,255,255,0.6)",
                textDecoration: "none",
                padding: "7px 14px",
              }}
            >
              Dashboard
            </Link>
          ) : (
            <>
              <Link
                href="/signin"
                style={{
                  fontSize: 13,
                  color: "rgba(255,255,255,0.6)",
                  textDecoration: "none",
                  padding: "7px 14px",
                }}
              >
                Sign in
              </Link>
              <Link
                href="/signup"
                style={{
                  fontSize: 13,
                  fontWeight: 600,
                  color: "#000",
                  background: "#fff",
                  textDecoration: "none",
                  borderRadius: 99,
                  padding: "7px 16px",
                }}
              >
                Get started
              </Link>
            </>
          )}
        </div>
      </nav>

      {/* Hero */}
      <section style={S.hero}>
        <h1 style={S.heroHeading}>Simple pricing.</h1>
        <p style={S.heroSub}>Start free. Upgrade when you need more room to grow.</p>
      </section>

      {/* Billing toggle */}
      <div style={S.toggleWrap}>
        <div style={S.toggle}>
          <ToggleButton
            label="Monthly"
            active={billing === "monthly"}
            onClick={() => setBilling("monthly")}
          />
          <ToggleButton
            label="Annual"
            badge="Save 29%"
            active={billing === "annual"}
            onClick={() => setBilling("annual")}
          />
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div
          style={{
            maxWidth: 480,
            margin: "0 auto 24px",
            background: "rgba(255,69,58,0.1)",
            border: "1px solid rgba(255,69,58,0.25)",
            borderRadius: 10,
            padding: "12px 16px",
            fontSize: 13,
            color: "#ff453a",
            textAlign: "center",
          }}
        >
          {error}
        </div>
      )}

      {/* Pricing grid */}
      <div className="pricing-grid" style={S.grid}>
        {/* Free */}
        <div
          style={{
            background: "rgba(255,255,255,0.02)",
            border: "1px solid rgba(255,255,255,0.07)",
            borderRadius: 20,
            padding: "28px 24px 24px",
            display: "flex",
            flexDirection: "column",
          }}
        >
          <div
            style={{
              fontSize: 11,
              fontWeight: 600,
              letterSpacing: "0.08em",
              textTransform: "uppercase",
              color: "rgba(255,255,255,0.35)",
              marginBottom: 16,
            }}
          >
            Free
          </div>
          <div style={{ marginBottom: 20 }}>
            <span
              style={{
                fontFamily: "var(--font-syne, 'Syne', sans-serif)",
                fontSize: 40,
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#fff",
              }}
            >
              $0
            </span>
            <span style={{ fontSize: 14, color: "rgba(255,255,255,0.35)", marginLeft: 4 }}>
              forever
            </span>
          </div>
          <p style={{ fontSize: 13, color: "rgba(255,255,255,0.3)", marginBottom: 24, lineHeight: 1.4 }}>
            No card needed. Good for personal use and trying things out.
          </p>
          <div style={{ flex: 1, marginBottom: 24 }}>
            {FREE_FEATURES.map((f) => (
              <FeatureRow key={f} text={f} muted />
            ))}
          </div>
          <Link
            href={isAuthed ? "/home" : "/signup"}
            style={{
              display: "block",
              textAlign: "center",
              background: "transparent",
              color: "rgba(255,255,255,0.55)",
              border: "1px solid rgba(255,255,255,0.12)",
              borderRadius: 10,
              padding: "12px 0",
              fontSize: 14,
              fontWeight: 600,
              textDecoration: "none",
            }}
          >
            {isAuthed ? "Current plan" : "Get started free"}
          </Link>
        </div>

        {/* Pro */}
        <div
          style={{
            background: "rgba(167,139,250,0.04)",
            border: "1.5px solid rgba(167,139,250,0.28)",
            borderRadius: 20,
            padding: "28px 24px 24px",
            display: "flex",
            flexDirection: "column",
            position: "relative",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
            <div
              style={{
                fontSize: 11,
                fontWeight: 600,
                letterSpacing: "0.08em",
                textTransform: "uppercase",
                color: "#a78bfa",
              }}
            >
              Pro
            </div>
            <div
              style={{
                background: "rgba(167,139,250,0.15)",
                color: "#a78bfa",
                fontSize: 10,
                fontWeight: 700,
                letterSpacing: "0.04em",
                textTransform: "uppercase",
                borderRadius: 99,
                padding: "3px 9px",
              }}
            >
              Most popular
            </div>
          </div>

          <div style={{ marginBottom: 4 }}>
            <span
              style={{
                fontFamily: "var(--font-syne, 'Syne', sans-serif)",
                fontSize: 40,
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#fff",
              }}
            >
              {proPrice}
            </span>
            <span style={{ fontSize: 14, color: "rgba(255,255,255,0.35)", marginLeft: 2 }}>
              {proPeriod}
            </span>
          </div>
          <p style={{ fontSize: 12, color: "rgba(255,255,255,0.3)", marginBottom: 24 }}>
            {proSubNote}
          </p>

          <div style={{ flex: 1, marginBottom: 24 }}>
            {PRO_FEATURES.map((f) => (
              <FeatureRow key={f} text={f} />
            ))}
          </div>

          <button
            type="button"
            onClick={() => void handleCheckout(proPlan)}
            disabled={loading === proPlan}
            style={{
              background: loading === proPlan ? "rgba(255,255,255,0.7)" : "#fff",
              color: "#000",
              border: "none",
              borderRadius: 10,
              padding: "13px 0",
              fontSize: 14,
              fontWeight: 700,
              cursor: loading === proPlan ? "wait" : "pointer",
              width: "100%",
              fontFamily: "inherit",
            }}
          >
            {loading === proPlan
              ? "Redirecting…"
              : isAuthed
              ? "Upgrade to Pro"
              : "Get Pro"}
          </button>
        </div>

        {/* Team Season */}
        <div
          style={{
            background: "rgba(245,158,11,0.03)",
            border: "1px solid rgba(245,158,11,0.18)",
            borderRadius: 20,
            padding: "28px 24px 24px",
            display: "flex",
            flexDirection: "column",
          }}
        >
          <div
            style={{
              fontSize: 11,
              fontWeight: 600,
              letterSpacing: "0.08em",
              textTransform: "uppercase",
              color: "rgba(245,158,11,0.7)",
              marginBottom: 16,
            }}
          >
            Team Season
          </div>
          <div style={{ marginBottom: 4 }}>
            <span
              style={{
                fontFamily: "var(--font-syne, 'Syne', sans-serif)",
                fontSize: 40,
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#fff",
              }}
            >
              $99
            </span>
            <span style={{ fontSize: 14, color: "rgba(255,255,255,0.35)", marginLeft: 4 }}>
              /year
            </span>
          </div>
          <p style={{ fontSize: 12, color: "rgba(255,255,255,0.3)", marginBottom: 4 }}>
            Billed annually
          </p>
          {/* Founding note */}
          <div
            style={{
              background: "rgba(245,158,11,0.08)",
              border: "1px solid rgba(245,158,11,0.15)",
              borderRadius: 8,
              padding: "8px 11px",
              marginBottom: 20,
              fontSize: 12,
              color: "rgba(245,158,11,0.9)",
              lineHeight: 1.4,
            }}
          >
            <strong>Founding teams:</strong> use code{" "}
            <span
              style={{
                fontFamily: "monospace",
                background: "rgba(245,158,11,0.12)",
                padding: "1px 5px",
                borderRadius: 4,
              }}
            >
              FOUNDING49
            </span>{" "}
            at checkout — $49 your first season.
          </div>

          <div style={{ flex: 1, marginBottom: 24 }}>
            {TEAM_FEATURES.map((f) => (
              <FeatureRow key={f} text={f} />
            ))}
          </div>

          <button
            type="button"
            onClick={() => void handleCheckout("team_season")}
            disabled={loading === "team_season"}
            style={{
              background: loading === "team_season" ? "rgba(245,158,11,0.5)" : "rgba(245,158,11,0.12)",
              color: loading === "team_season" ? "rgba(255,255,255,0.5)" : "#f59e0b",
              border: "1px solid rgba(245,158,11,0.25)",
              borderRadius: 10,
              padding: "12px 0",
              fontSize: 14,
              fontWeight: 700,
              cursor: loading === "team_season" ? "wait" : "pointer",
              width: "100%",
              fontFamily: "inherit",
            }}
          >
            {loading === "team_season"
              ? "Redirecting…"
              : isAuthed
              ? "Get Team Season"
              : "Get Team Season"}
          </button>
        </div>
      </div>

      {/* Responsive grid */}
      <style>{`
        .pricing-grid { grid-template-columns: repeat(3, 1fr); }
        @media (max-width: 720px) {
          .pricing-grid { grid-template-columns: 1fr; }
        }
        @media (max-width: 960px) and (min-width: 721px) {
          .pricing-grid { grid-template-columns: 1fr 1fr; }
        }
      `}</style>

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
