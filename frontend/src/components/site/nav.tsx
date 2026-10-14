"use client";

import Link from "next/link";
import { FindEZWordmark } from "@/components/site/findez-brand";
import { useMarketingSession } from "@/lib/use-marketing-session";
import styles from "./public-nav.module.css";

export function SiteNav(props: { variant: "marketing" | "app"; theme?: "light" | "dark" }) {
  const signedIn = useMarketingSession();
  if (props.variant === "app") return null;
  return <header className={styles.header}>
    <Link href="/" className={styles.brand} aria-label="FindEZ home"><FindEZWordmark width={100} height={27} /></Link>
    <nav aria-label="Public navigation">
      <Link href="/docs/api">API docs</Link>
      <Link href={signedIn ? "/home" : "/signin"}>{signedIn ? "Dashboard" : "Sign in"}</Link>
    </nav>
  </header>;
}
