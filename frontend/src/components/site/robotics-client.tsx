"use client";

import { useState } from "react";
import Link from "next/link";

import { MarketingFooter } from "@/components/site/product-marketing";
import { MarketingNav } from "@/components/site/marketing-nav";

const FAQ_ITEMS = [
  {
    q: "Which robotics programs does FindEZ support?",
    a: "FindEZ works for FTC, FRC, VEX, FLL, and other teams that need to track physical parts, tools, and project inventory.",
  },
  {
    q: "How does my team join?",
    a: "Create a Team, then share its 6-character join code. Members enter it on iOS or the web to get access to the shared workspace.",
  },
  {
    q: "Do all students need accounts?",
    a: "Yes. Each student creates a free FindEZ account, then enters the join code to join your team. Account creation takes under a minute.",
  },
  {
    q: "Can my team use FindEZ now?",
    a: "Yes. FindEZ is currently available without a paid plan or card requirement.",
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
          cursor: "pointer", color: "#f2eee7",
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
  void isAuthed;

  return (
    <div style={{ background: "#0b0b09", minHeight: "100vh", color: "#f2eee7", fontFamily: font }}>
      <MarketingNav />

      {/* Hero */}
      <section style={{ textAlign: "center", padding: "80px 24px 64px", maxWidth: 640, margin: "0 auto" }}>
        <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--brand-accent)", marginBottom: 16 }}>
          For coaches &amp; mentors
        </div>
        <h1 style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)", fontSize: "clamp(36px, 6vw, 56px)", fontWeight: 700, lineHeight: 1.1, letterSpacing: "-0.03em", color: "#f2eee7", margin: 0 }}>
          Stop losing parts.<br />Start winning.
        </h1>
        <p style={{ fontSize: 16, color: "rgba(255,255,255,0.45)", marginTop: 18, lineHeight: 1.6, maxWidth: 480, margin: "18px auto 0" }}>
          FindEZ gives your team one organized inventory — AI-scanned, barcode-tracked, and accessible from the pit, the shop, or the practice field.
        </p>
        <div style={{ display: "flex", gap: 12, justifyContent: "center", marginTop: 36, flexWrap: "wrap" }}>
          <Link
            href="/signup"
            style={{ background: "#f2eee7", color: "#15130f", textDecoration: "none", borderRadius: 7, padding: "13px 28px", fontSize: 14, fontWeight: 700 }}
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

      <MarketingFooter />
    </div>
  );
}
