import type { ReactNode } from "react";
import { ArrowRight } from "lucide-react";
import Link from "next/link";

import { MarketingNav } from "@/components/site/marketing-nav";
import { MarketingFooter } from "@/components/site/product-marketing";

import styles from "./product-detail.module.css";

export function ProductDetailShell({ children }: { children: ReactNode }) {
  return (
    <div className={styles.page}>
      <MarketingNav theme="light" />
      <main>{children}</main>
      <MarketingFooter theme="light" />
    </div>
  );
}

export function ProductDetailHero({
  label,
  title,
  description,
  visual,
}: {
  label: string;
  title: string;
  description: string;
  visual: ReactNode;
}) {
  return (
    <section className={styles.hero}>
      <div className={styles.heroCopy}>
        <span>{label}</span>
        <h1>{title}</h1>
        <p>{description}</p>
        <div>
          <Link href="/signup" className={styles.primaryButton}>Start free <ArrowRight size={15} /></Link>
          <Link href="/product" className={styles.textLink}>Product overview</Link>
        </div>
      </div>
      <div className={styles.heroVisual}>{visual}</div>
    </section>
  );
}

export function ProductDetailCta({ title, body }: { title: string; body: string }) {
  return (
    <section className={styles.cta}>
      <div><h2>{title}</h2><p>{body}</p></div>
      <Link href="/signup" className={styles.primaryButton}>Start free <ArrowRight size={15} /></Link>
    </section>
  );
}

export { styles as productDetailStyles };
