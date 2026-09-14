"use client";

import Link from "next/link";

export function SiteNav(props: { variant: "marketing" | "app" }) {
  if (props.variant === "app") return null;

  return (
    <header className="site-nav">
      <Link href="/" className="landing-wordmark">
        <span className="findez-mark" aria-hidden="true"><i /><i /><i /></span>
        <span>FindEZ</span>
      </Link>
      <nav className="site-nav-links" aria-label="Public navigation">
        <Link href="/docs/api">Developers</Link>
      </nav>
      <div className="site-nav-actions">
        <Link href="/signin" className="landing-nav-ghost">Sign In</Link>
        <Link href="/signup" className="landing-nav-primary">Get Started</Link>
      </div>
    </header>
  );
}
