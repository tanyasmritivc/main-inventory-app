import Link from "next/link";

import { MarketingNav } from "@/components/site/marketing-nav";

const features = [
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
    ),
    title: "Stop buying duplicates",
    body: "Know what you already own before you spend again.",
  },
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="m13 2 3 3-3 3"/><path d="M2 13h13"/><path d="m13 22-3-3 3-3"/><path d="M22 11H9"/></svg>
    ),
    title: "Find anything instantly",
    body: "Search across everything you own in natural language.",
  },
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 8V4H8"/><rect width="16" height="12" x="4" y="8" rx="2"/><path d="M2 14h2"/><path d="M20 14h2"/><path d="M15 13v2"/><path d="M9 13v2"/></svg>
    ),
    title: "AI does the heavy lifting",
    body: "Scan barcodes, upload receipts — FindEZ extracts the details automatically.",
  },
];

export default function Home() {
  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
      <MarketingNav />

      {/* Hero */}
      <main style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", paddingTop: 120, paddingBottom: 80, paddingLeft: 24, paddingRight: 24 }}>
        <section style={{ maxWidth: 600, width: "100%", textAlign: "center" }} className="animate-fade-up">
          <div className="pill" style={{ marginBottom: 24, display: "inline-flex" }}>AI-powered inventory</div>
          <h1
            className="font-display"
            style={{ fontSize: "clamp(38px, 6vw, 58px)", fontWeight: 700, lineHeight: 1.08, letterSpacing: "-0.03em", color: "#fff", marginBottom: 24 }}
          >
            AI that remembers<br />everything you own.
          </h1>
          <p style={{ fontSize: 17, color: "var(--text-secondary)", lineHeight: 1.65, maxWidth: 420, margin: "0 auto 36px" }}>
            Scan anything. Ask anything. Never buy something you already have.
          </p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 12, justifyContent: "center", marginBottom: 16 }}>
            <Link href="/signup" className="landing-btn-primary">Get Started free</Link>
            <Link href="/signin" className="landing-btn-ghost">Sign In</Link>
          </div>
          <p style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 16 }}>Free · No credit card required</p>
        </section>

        {/* Feature cards */}
        <section style={{ marginTop: 80, width: "100%", maxWidth: 960, padding: "0 0 40px" }} className="animate-fade-up">
          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, minmax(0, 1fr))", gap: 16 }}>
            {features.map((f) => (
              <div
                key={f.title}
                className="glass-card"
                style={{ padding: "28px 24px" }}
              >
                <div style={{ color: "var(--text-secondary)", marginBottom: 14 }}>{f.icon}</div>
                <div style={{ fontSize: 14, fontWeight: 600, color: "#fff", marginBottom: 6 }}>{f.title}</div>
                <div style={{ fontSize: 13, color: "var(--text-secondary)", lineHeight: 1.6 }}>{f.body}</div>
              </div>
            ))}
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer style={{ borderTop: "1px solid rgba(255,255,255,0.06)", padding: "32px 40px", display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: 12 }}>
        <span className="font-display" style={{ fontSize: 14, fontWeight: 700, color: "var(--text-muted)" }}>FindEZ</span>
        <div style={{ display: "flex", gap: 24, alignItems: "center" }}>
          <Link href="/privacy" style={{ fontSize: 12, color: "var(--text-muted)", textDecoration: "none" }}>Privacy</Link>
          <Link href="/terms" style={{ fontSize: 12, color: "var(--text-muted)", textDecoration: "none" }}>Terms</Link>
          <span style={{ fontSize: 12, color: "var(--text-muted)" }}>© 2026 FindEZ</span>
        </div>
      </footer>
    </div>
  );
}
