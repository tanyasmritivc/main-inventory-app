"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { APP_THEME_STORAGE_KEY } from "@/lib/app-theme-constants";

export type AppThemeChoice = "light" | "dark" | "system";
export type AppThemeResolved = "light" | "dark";

function readStoredChoice(): AppThemeChoice {
  if (typeof window === "undefined") return "system";
  const stored = window.localStorage.getItem(APP_THEME_STORAGE_KEY);
  return stored === "light" || stored === "dark" ? stored : "system";
}

function systemPrefersDark(): boolean {
  return typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: dark)").matches;
}

type AppThemeContextValue = {
  theme: AppThemeChoice;
  resolvedTheme: AppThemeResolved;
  setTheme: (next: AppThemeChoice) => void;
};

const AppThemeContext = createContext<AppThemeContextValue | null>(null);

/**
 * Applies the interior's dark class to <html> only while AppShell (the
 * authenticated app frame) is mounted, and removes it on unmount. This
 * keeps dark mode scoped to app-frame routes: the landing page, marketing
 * routes and sign-in never render AppShell, so they never see the .dark
 * class regardless of the visitor's system preference. <html> rather than
 * <body> because the blocking script in layout.tsx (which sets the same
 * class before first paint, to avoid a flash) runs in <head>, before
 * <body> exists.
 */
export function AppThemeProvider({ children }: { children: React.ReactNode }) {
  const [choice, setChoice] = useState<AppThemeChoice>(() => readStoredChoice());
  const [systemDark, setSystemDark] = useState<boolean>(() => systemPrefersDark());
  const resolved: AppThemeResolved = choice === "system" ? (systemDark ? "dark" : "light") : choice;

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setSystemDark(media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", resolved === "dark");
    return () => { document.documentElement.classList.remove("dark"); };
  }, [resolved]);

  const setTheme = useCallback((next: AppThemeChoice) => {
    if (next === "system") window.localStorage.removeItem(APP_THEME_STORAGE_KEY);
    else window.localStorage.setItem(APP_THEME_STORAGE_KEY, next);
    setChoice(next);
  }, []);

  const value = useMemo(() => ({ theme: choice, resolvedTheme: resolved, setTheme }), [choice, resolved, setTheme]);

  return <AppThemeContext.Provider value={value}>{children}</AppThemeContext.Provider>;
}

export function useAppTheme(): AppThemeContextValue {
  const context = useContext(AppThemeContext);
  if (!context) throw new Error("useAppTheme must be used within AppThemeProvider");
  return context;
}
