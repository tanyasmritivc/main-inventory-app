"use client";

import Link from "next/link";
import { FindEZMark } from "@/components/site/findez-brand";
import { useMarketingSession } from "@/lib/use-marketing-session";
import styles from "./public-nav.module.css";

export function SiteNav(props: { variant: "marketing" | "app"; theme?: "light" | "dark" }) {
  const signedIn = useMarketingSession();
  if (props.variant === "app") return null;
  return <header className={styles.header}>
    <Link href="/" className={styles.brand} aria-label="FindEZ home"><FindEZMark width={24} height={24} />FindEZ</Link>
    <nav aria-label="Public navigation">
      <Link href="/docs/api">API docs</Link>
      <Link href={signedIn ? "/home" : "/signin"}>{signedIn ? "Dashboard" : "Sign in"}</Link>
    </nav>
  </header>;
}
