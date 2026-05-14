"use client";

import Link from "next/link";

export function SiteNav(props: { variant: "marketing" | "app" }) {
  if (props.variant === "app") return null;

  return (
    <header
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        right: 0,
        height: 60,
        background: "rgba(0,0,0,0.80)",
        backdropFilter: "blur(20px)",
        WebkitBackdropFilter: "blur(20px)",
        borderBottom: "1px solid var(--fz-border)",
        zIndex: 50,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "0 40px",
      }}
    >
      <Link
        href="/"
        className="font-display"
        style={{ fontSize: 18, fontWeight: 700, color: "#fff", textDecoration: "none", letterSpacing: "-0.3px" }}
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
