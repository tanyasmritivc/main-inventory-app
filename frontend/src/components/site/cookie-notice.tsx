"use client";

import Link from "next/link";
import { useSyncExternalStore } from "react";
import { COOKIE_NOTICE_TEXT, LEGAL_VERSION } from "@/lib/legal-content";
import styles from "./cookie-notice.module.css";

const storageKey = "findez-cookie-notice";
const eventName = "findez-cookie-notice-dismissed";
let dismissedForSession = false;
function visible() {
  if (dismissedForSession) return false;
  try { return localStorage.getItem(storageKey) !== LEGAL_VERSION; } catch { return true; }
}
function subscribe(listener: () => void) {
  window.addEventListener(eventName, listener);
  window.addEventListener("storage", listener);
  return () => {
    window.removeEventListener(eventName, listener);
    window.removeEventListener("storage", listener);
  };
}
export function CookieNotice() {
  const show = useSyncExternalStore(subscribe, visible, () => false);
  if (!show) return null;
  function dismiss() {
    dismissedForSession = true;
    try { localStorage.setItem(storageKey, LEGAL_VERSION); } catch { /* Keep the session choice. */ }
    window.dispatchEvent(new Event(eventName));
  }
  return <aside className={styles.notice} aria-label="Cookies and device storage">
    <p>{COOKIE_NOTICE_TEXT} <Link href="/privacy#cookies">Details</Link></p>
    <button onClick={dismiss}>Got it</button>
  </aside>;
}
