"use client";

import Link from "next/link";

export function SiteNav(props: { variant: "marketing" | "app" }) {
  if (props.variant === "app") return null;

  return (
    <header
      style={{
        position: "relative",
        width: "100%",
        background: "rgba(0,0,0,0.78)",
        backdropFilter: "blur(20px)",
        WebkitBackdropFilter: "blur(20px)",
        borderBottom: "1px solid rgba(255,255,255,0.06)",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "16px 32px",
        zIndex: 50,
      }}
    >
      <Link
        href="/"
        className="font-display"
        style={{ fontSize: 20, fontWeight: 700, color: "#fff", textDecoration: "none", letterSpacing: "-0.04em" }}
      >
        FindEZ
      </Link>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <Link href="/signin" className="landing-nav-ghost">Sign In</Link>
        <Link href="/signup" className="landing-nav-primary">Get Started</Link>
      </div>
    </header>
  );
}
