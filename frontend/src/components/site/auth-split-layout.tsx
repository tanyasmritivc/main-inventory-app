"use client";

import { useSyncExternalStore, type ReactNode } from "react";
import { AuthArt, AUTH_MARK } from "./auth-art";
import styles from "./auth-form.module.css";

// Match Appearance's existing default, dark, and system choices locally.
// Auth routes deliberately do not change the document-wide app theme.
function darkSnapshot() {
  try {
    const theme = localStorage.getItem("findez-app-theme");
    return theme === "dark" || (theme === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  } catch { return false; }
}
function subscribe(listener: () => void) {
  const media = matchMedia("(prefers-color-scheme: dark)");
  window.addEventListener("storage", listener);
  media.addEventListener("change", listener);
  return () => {
    window.removeEventListener("storage", listener);
    media.removeEventListener("change", listener);
  };
}
const serverSnapshot = () => false;

export function AuthSplitBrand() {
  return <span className={styles.darkBrand}>
    <svg width="32" height="32" viewBox="0 0 100 100" fill="currentColor" aria-hidden="true"><path d={AUTH_MARK} /></svg>
    <span>FindEZ</span>
  </span>;
}

export function AuthSplitLayout({ children }: { children: ReactNode }) {
  const dark = useSyncExternalStore(subscribe, darkSnapshot, serverSnapshot);
  return <div className={`auth-page-shell ${styles.shell}`} data-auth-theme={dark ? "dark" : "light"}>
    <div className={styles.side}>{children}</div>
    <AuthArt active={dark} />
  </div>;
}
