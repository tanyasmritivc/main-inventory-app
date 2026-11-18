"use client";

import { ArrowRight, RefreshCw, Sparkles } from "lucide-react";
import Link from "@/components/site/inventory-link";
import styles from "./inventory-enrichment.module.css";

export function InventoryEnrichmentLink() {
  return <div className={styles.entryRow}><Link href="/review/enrichment" className={styles.entry} aria-label="Review photo and classification suggestions"><Sparkles size={14} aria-hidden="true" />Review AI suggestions<ArrowRight size={14} aria-hidden="true" /></Link></div>;
}

export function InventoryReadError({ message, loading, onRetry }: { message: string; loading: boolean; onRetry: () => void }) {
  return <div className={styles.readError} role="alert"><div><strong>Inventory couldn’t be loaded</strong><p>{message === "Failed to load inventory" ? "Your items are unavailable right now. Try loading them again." : message}</p></div><button type="button" onClick={onRetry} disabled={loading}><RefreshCw size={14} aria-hidden="true" />{loading ? "Loading…" : "Retry"}</button></div>;
}
