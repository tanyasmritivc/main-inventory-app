"use client";

import Link from "next/link";
import { ArrowUpRight, Sparkles } from "lucide-react";
import styles from "./sidebar-founders.module.css";

export function SidebarUpgrade({ onOpen }: { onOpen?: () => void }) {
  return (
    <Link
      href="/founders"
      prefetch={false}
      onClick={onOpen}
      className={`app-upgrade-link ${styles.link}`}
      aria-label="Founders Access"
      title="Founders Access"
    >
      <Sparkles size={18} aria-hidden="true" />
      <span className={styles.label}>Founders Access</span>
      <ArrowUpRight size={16} className="app-upgrade-arrow" aria-hidden="true" />
    </Link>
  );
}
