"use client";

import { useState } from "react";
import Link from "next/link";

const FAQ_ITEMS = [
  {
    q: "Which program should I choose?",
    a: "The FTC/VEX/FLL plan covers those three programs at $99. The FRC plan is built for large FRC parts inventories at $199. The School Bundle covers all programs and is ideal for districts or schools running multiple teams.",
  },
  {
    q: "How does my team join?",
    a: "After purchase you receive a 6-character join code. Share it in your team chat — members enter it on iOS or the web to get instant access to your team inventory.",
  },
  {
    q: "Do all students need accounts?",
    a: "Yes. Each student creates a free FindEZ account, then enters the join code to join your team. Account creation takes under a minute.",
  },
  {
    q: "When does the plan expire?",
    a: "All plans run through August 31 — the full competitive season. Renew each fall for the next season.",
  },
  {
    q: "Is there a free option?",
    a: "Yes. New teams can start with the free Rookie Plan: core inventory features for one season, no card required.",
  },
];

function FaqRow({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div style={{ borderTop: "1px solid rgba(255,255,255,0.07)", padding: "20px 0" }}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        style={{
          background: "none", border: "none", width: "100%", textAlign: "left",
          cursor: "pointer", color: "#f5f5f7",
          fontFamily: "var(--font-dm-sans, 'DM Sans', sans-serif)",
          fontSize: 15, fontWeight: 500,
          display: "flex", justifyContent: "space-between", alignItems: "center", gap: 16, padding: 0,
        }}
      >
        {q}
        <span
          style={{
            color: "rgba(255,255,255,0.3)", fontSize: 18, flexShrink: 0,
            transform: open ? "rotate(45deg)" : "none",
            transition: "transform 200ms", display: "inline-block",
          }}
        >
          +
        </span>
      </button>
      {open && (
        <p style={{ marginTop: 12, fontSize: 14, color: "rgba(255,255,255,0.45)", lineHeight: 1.65 }}>{a}</p>
      )}
    </div>
  );
}

const FEATURES = [
  { icon: "📸", title: "AI photo scanning", desc: "Point your phone at a bin — FindEZ identifies and catalogs parts automatically." },
  { icon: "🔍", title: "Barcode lookup", desc: "Scan any barcode to pull specs and add the part to your inventory in one tap." },
  { icon: "🤖", title: "AI inventory chat", desc: "Ask questions like \"where are the motor controllers?\" and get an instant answer." },
  { icon: "👥", title: "Team join codes", desc: "Share a 6-character code. Teammates join instantly — no admin approvals needed." },
];

export function RoboticsClient({ isAuthed }: { isAuthed: boolean }) {
  const font = "var(--font-dm-sans, 'DM Sans', system-ui, sans-serif)";

  return (
    <div style={{ background: "#0a0a0a", minHeight: "100vh", color: "#f5f5f7", fontFamily: font }}>
      {/* Nav */}
      <nav style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "20px 32px", borderBottom: "1px solid rgba(255,255,255,0.06)",
        position: "sticky", top: 0,
        background: "rgba(10,10,10,0.85)", backdropFilter: "blur(16px)", zIndex: 40,
      }}>
        <Link href="/" style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 18, fontWeight: 700, color: "#fff", textDecoration: "none", letterSpacing: "-0.01em" }}>
          FindEZ
        </Link>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <Link href="/pricing" style={{ fontSize: 13, color: "rgba(255,255,255,0.6)", textDecoration: "none", padding: "7px 14px" }}>
            Pricing
          </Link>
          {isAuthed ? (
            <Link href="/home" style={{ fontSize: 13, color: "rgba(255,255,255,0.6)", textDecoration: "none", padding: "7px 14px" }}>
              Dashboard
            </Link>
          ) : (
            <Link href="/signup" style={{ fontSize: 13, fontWeight: 600, color: "#000", background: "#fff", textDecoration: "none", borderRadius: 99, padding: "7px 16px" }}>
              Get started
            </Link>
          )}
        </div>
      </nav>

      {/* Hero */}
      <section style={{ textAlign: "center", padding: "80px 24px 64px", maxWidth: 640, margin: "0 auto" }}>
        <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "#a78bfa", marginBottom: 16 }}>
          For coaches &amp; mentors
        </div>
        <h1 style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: "clamp(36px, 6vw, 56px)", fontWeight: 700, lineHeight: 1.1, letterSpacing: "-0.03em", color: "#fff", margin: 0 }}>
          Stop losing parts.<br />Start winning.
        </h1>
        <p style={{ fontSize: 16, color: "rgba(255,255,255,0.45)", marginTop: 18, lineHeight: 1.6, maxWidth: 480, margin: "18px auto 0" }}>
          FindEZ gives your team one organized inventory — AI-scanned, barcode-tracked, and accessible from the pit, the shop, or the practice field.
        </p>
        <div style={{ display: "flex", gap: 12, justifyContent: "center", marginTop: 36, flexWrap: "wrap" }}>
          <Link
            href="/pricing"
            style={{ background: "#fff", color: "#000", textDecoration: "none", borderRadius: 99, padding: "13px 28px", fontSize: 14, fontWeight: 700 }}
          >
            See pricing
          </Link>
          <Link
            href="/signup"
            style={{ background: "rgba(255,255,255,0.08)", color: "#fff", textDecoration: "none", borderRadius: 99, padding: "13px 28px", fontSize: 14, fontWeight: 600, border: "1px solid rgba(255,255,255,0.12)" }}
          >
            Start free
          </Link>
        </div>
      </section>

      {/* Features */}
      <div className="features-grid" style={{ display: "grid", gap: 16, maxWidth: 1040, margin: "0 auto 80px", padding: "0 24px" }}>
        {FEATURES.map((f) => (
          <div
            key={f.title}
            style={{
              background: "rgba(255,255,255,0.02)",
              border: "1px solid rgba(255,255,255,0.07)",
              borderRadius: 16,
              padding: "24px",
            }}
          >
            <div style={{ fontSize: 28, marginBottom: 14 }}>{f.icon}</div>
            <div style={{ fontSize: 15, fontWeight: 600, color: "#fff", marginBottom: 6 }}>{f.title}</div>
            <div style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", lineHeight: 1.55 }}>{f.desc}</div>
          </div>
        ))}
      </div>
      <style>{`
        .features-grid { grid-template-columns: repeat(4, 1fr); }
        @media (max-width: 800px) { .features-grid { grid-template-columns: repeat(2, 1fr); } }
        @media (max-width: 480px) { .features-grid { grid-template-columns: 1fr; } }
      `}</style>

      {/* Plans */}
      <div style={{ maxWidth: 1040, margin: "0 auto 80px", padding: "0 24px" }}>
        <h2 style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 22, fontWeight: 600, letterSpacing: "-0.02em", color: "#fff", textAlign: "center", marginBottom: 32 }}>
          Season plans for every program
        </h2>
        <div className="robotics-grid" style={{ display: "grid", gap: 16 }}>
          {/* Rookie */}
          <div style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 18, padding: "24px" }}>
            <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "rgba(255,255,255,0.35)", marginBottom: 10 }}>Rookie</div>
            <div style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 32, fontWeight: 700, color: "#fff", marginBottom: 6 }}>Free</div>
            <p style={{ fontSize: 13, color: "rgba(255,255,255,0.35)", marginBottom: 20, lineHeight: 1.4 }}>New &amp; first-year teams. Core features, no card needed.</p>
            <Link href="/pricing" style={{ display: "block", textAlign: "center", background: "rgba(255,255,255,0.07)", color: "#fff", textDecoration: "none", borderRadius: 10, padding: "11px 0", fontSize: 14, fontWeight: 600 }}>
              Get started free
            </Link>
          </div>
          {/* FTC / VEX / FLL */}
          <div style={{ background: "rgba(167,139,250,0.03)", border: "1px solid rgba(167,139,250,0.22)", borderRadius: 18, padding: "24px" }}>
            <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "#a78bfa", marginBottom: 10 }}>FTC · VEX · FLL</div>
            <div style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 32, fontWeight: 700, color: "#fff", marginBottom: 6 }}>
              $99 <span style={{ fontSize: 16, color: "rgba(255,255,255,0.35)", fontFamily: font }}>/ season</span>
            </div>
            <p style={{ fontSize: 13, color: "rgba(255,255,255,0.35)", marginBottom: 20, lineHeight: 1.4 }}>Unlimited inventory, AI scanning, team join code.</p>
            <Link href="/pricing" style={{ display: "block", textAlign: "center", background: "rgba(167,139,250,0.12)", color: "#a78bfa", textDecoration: "none", borderRadius: 10, padding: "11px 0", fontSize: 14, fontWeight: 600 }}>
              Get team plan
            </Link>
          </div>
          {/* FRC */}
          <div style={{ background: "rgba(245,158,11,0.04)", border: "1.5px solid rgba(245,158,11,0.30)", borderRadius: 18, padding: "24px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
              <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "#f59e0b" }}>FRC</div>
              <div style={{ background: "rgba(245,158,11,0.15)", color: "#f59e0b", fontSize: 9, fontWeight: 700, letterSpacing: "0.04em", textTransform: "uppercase", borderRadius: 99, padding: "2px 7px" }}>Popular</div>
            </div>
            <div style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 32, fontWeight: 700, color: "#fff", marginBottom: 6 }}>
              $199 <span style={{ fontSize: 16, color: "rgba(255,255,255,0.35)", fontFamily: font }}>/ season</span>
            </div>
            <p style={{ fontSize: 13, color: "rgba(255,255,255,0.35)", marginBottom: 20, lineHeight: 1.4 }}>Built for large FRC parts inventories.</p>
            <Link href="/pricing" style={{ display: "block", textAlign: "center", background: "#f59e0b", color: "#000", textDecoration: "none", borderRadius: 10, padding: "11px 0", fontSize: 14, fontWeight: 700 }}>
              Get FRC plan
            </Link>
          </div>
          {/* School Bundle */}
          <div style={{ background: "rgba(48,209,88,0.03)", border: "1px solid rgba(48,209,88,0.18)", borderRadius: 18, padding: "24px" }}>
            <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "#30d158", marginBottom: 10 }}>School Bundle</div>
            <div style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 32, fontWeight: 700, color: "#fff", marginBottom: 6 }}>
              $499 <span style={{ fontSize: 16, color: "rgba(255,255,255,0.35)", fontFamily: font }}>/ season</span>
            </div>
            <p style={{ fontSize: 13, color: "rgba(255,255,255,0.35)", marginBottom: 20, lineHeight: 1.4 }}>Up to 10 teams, all programs — one purchase.</p>
            <Link href="/pricing" style={{ display: "block", textAlign: "center", background: "rgba(48,209,88,0.12)", color: "#30d158", textDecoration: "none", borderRadius: 10, padding: "11px 0", fontSize: 14, fontWeight: 600 }}>
              Get school bundle
            </Link>
          </div>
        </div>
        <style>{`
          .robotics-grid { grid-template-columns: repeat(4, 1fr); }
          @media (max-width: 900px) { .robotics-grid { grid-template-columns: repeat(2, 1fr); } }
          @media (max-width: 520px) { .robotics-grid { grid-template-columns: 1fr; } }
        `}</style>
      </div>

      {/* FAQ */}
      <section style={{ maxWidth: 640, margin: "0 auto 96px", padding: "0 24px" }}>
        <h2 style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: 22, fontWeight: 600, letterSpacing: "-0.02em", color: "#fff", marginBottom: 32 }}>
          Common questions
        </h2>
        {FAQ_ITEMS.map((item) => (
          <FaqRow key={item.q} q={item.q} a={item.a} />
        ))}
        <div style={{ borderTop: "1px solid rgba(255,255,255,0.07)" }} />
      </section>

      {/* Footer */}
      <footer style={{ textAlign: "center", padding: "24px", borderTop: "1px solid rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.25)", fontSize: 12 }}>
        © {new Date().getFullYear()} FindEZ ·{" "}
        <Link href="/pricing" style={{ color: "rgba(255,255,255,0.35)", textDecoration: "none" }}>Pricing</Link>
      </footer>
    </div>
  );
}
