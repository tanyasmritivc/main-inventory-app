import Link from "next/link";
import { ArrowUpRight, Plug } from "lucide-react";
import styles from "./commerce-dashboard-card.module.css";

export function CommerceDashboardCard({ inventoryId }: { inventoryId: string }) {
  return (
    <Link
      id="findez-connect"
      className={`${styles.card} theme-card`}
      href={`/inventory/connect?inventory=${encodeURIComponent(inventoryId)}`}
      aria-label="Open Amazon and Shopify connections"
    >
      <span className={`theme-tool-icon ${styles.icon}`}><Plug size={22} aria-hidden="true" /></span>
      <span className={styles.content}>
        <span className={styles.eyebrow}>FindEZ Connect</span>
        <strong>Amazon &amp; Shopify</strong>
        <span className={styles.description}>Manage your purchase and store connections.</span>
      </span>
      <span className={styles.action}>Open connections <ArrowUpRight size={18} aria-hidden="true" /></span>
    </Link>
  );
}
