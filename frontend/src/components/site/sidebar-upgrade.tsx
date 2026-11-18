"use client";

import { ArrowUpRight, Sparkles } from "lucide-react";
import { useFoundingAccess } from "@/components/founding-access/founding-access";
import styles from "./sidebar-founders.module.css";

export function SidebarUpgrade({ onOpen }: { onOpen?: () => void }) {
  const founding = useFoundingAccess();
  return (
    <button
      type="button"
      disabled={!founding?.accountId}
      onClick={() => {
        onOpen?.();
        founding?.openPlan();
      }}
      className={`app-upgrade-link ${styles.link}`}
      aria-label="Founders Access"
      title="Founders Access"
    >
      <Sparkles size={18} aria-hidden="true" />
      <span className={styles.label}>Founders Access</span>
      <ArrowUpRight size={16} className="app-upgrade-arrow" aria-hidden="true" />
    </button>
  );
}
