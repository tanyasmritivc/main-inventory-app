"use client";

import { createContext, useCallback, useContext, useLayoutEffect, useMemo, useSyncExternalStore } from "react";
import { APP_THEME_STORAGE_KEY, isInteriorPath } from "@/lib/app-theme-constants";

import { usePathname } from "next/navigation";

export type AppThemeChoice = "light" | "dark" | "system";
export type AppThemeResolved = "light" | "dark";

const THEME_CHANGE_EVENT = "findez-theme-change";
let sessionChoice: AppThemeChoice | null = null;

function readStoredChoice(): AppThemeChoice {
  if (typeof window === "undefined") return "system";
  try {
    const stored = window.localStorage.getItem(APP_THEME_STORAGE_KEY);
    return sessionChoice ?? (stored === "light" || stored === "dark" ? stored : "system");
  } catch {
    return sessionChoice ?? "system";
  }
}

function systemPrefersDark(): boolean {
  return typeof window !== "undefined" && !!window.matchMedia?.("(prefers-color-scheme: dark)").matches;
}

function subscribeChoice(notify: () => void) {
  const onStorage = (event: StorageEvent) => {
    if (event.key === APP_THEME_STORAGE_KEY || event.key === null) {
      sessionChoice = null;
      notify();
    }
  };
  window.addEventListener("storage", onStorage);
  window.addEventListener(THEME_CHANGE_EVENT, notify);
  return () => {
    window.removeEventListener("storage", onStorage);
    window.removeEventListener(THEME_CHANGE_EVENT, notify);
  };
}

function subscribeSystem(notify: () => void) {
  const media = window.matchMedia?.("(prefers-color-scheme: dark)");
  media?.addEventListener("change", notify);
  return () => media?.removeEventListener("change", notify);
}
const serverChoice = () => null;
const serverSystemDark = () => false;

type AppThemeContextValue = {
  theme: AppThemeChoice;
  resolvedTheme: AppThemeResolved;
  setTheme: (next: AppThemeChoice) => void;
};

const AppThemeContext = createContext<AppThemeContextValue | null>(null);

/** Shared preferences; document styling is owned by the persistent root. */
function useThemeState() {
  const storedChoice = useSyncExternalStore(subscribeChoice, readStoredChoice, serverChoice);
  const choice = storedChoice ?? "system";
  const systemDark = useSyncExternalStore(subscribeSystem, systemPrefersDark, serverSystemDark);
  const resolved: AppThemeResolved = choice === "system" ? (systemDark ? "dark" : "light") : choice;

  const setTheme = useCallback((next: AppThemeChoice) => {
    try {
      if (next === "system") window.localStorage.removeItem(APP_THEME_STORAGE_KEY);
      else window.localStorage.setItem(APP_THEME_STORAGE_KEY, next);
      sessionChoice = null;
    } catch {
      // Restricted storage must not prevent changing appearance this session.
      sessionChoice = next;
    }
    window.dispatchEvent(new Event(THEME_CHANGE_EVENT));
  }, []);

  const value = useMemo(() => ({ theme: choice, resolvedTheme: resolved, setTheme }), [choice, resolved, setTheme]);

  return { value, ready: storedChoice !== null };
}

/** Remains mounted when an authenticated page or its loading boundary changes. */
export function AppThemeDocument() {
  const pathname = usePathname();
  const { value, ready } = useThemeState();
  useLayoutEffect(() => {
    // Keep the prepaint script's class until browser preference is known.
    // Public routes must clear it even during hydration/sign-out.
    const interior = isInteriorPath(pathname ?? "");
    if (interior && !ready) return;
    const dark = interior && value.resolvedTheme === "dark";
    document.documentElement.classList.toggle("dark", dark);
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", dark ? "#0b0b0d" : "#ffffff");
  }, [pathname, ready, value.resolvedTheme]);
  return null;
}

export function AppThemeProvider({ children }: { children: React.ReactNode }) {
  const { value } = useThemeState();
  return <AppThemeContext.Provider value={value}>{children}</AppThemeContext.Provider>;
}

export function useAppTheme(): AppThemeContextValue {
  const context = useContext(AppThemeContext);
  if (!context) throw new Error("useAppTheme must be used within AppThemeProvider");
  return context;
}
