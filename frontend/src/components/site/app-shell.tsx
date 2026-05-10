"use client";

import { useState } from "react";
import { SiteNav } from "@/components/site/nav";
import { AppSidebar } from "@/components/site/app-sidebar";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { X } from "lucide-react";

export function AppShell(props: { children: React.ReactNode }) {
  const [bannerOpen, setBannerOpen] = useState(() => {
    if (typeof window === "undefined") return false;
    try {
      return !window.sessionStorage.getItem("findez_welcome_dismissed");
    } catch {
      return false;
    }
  });

  function dismissBanner() {
    try { window.sessionStorage.setItem("findez_welcome_dismissed", "1"); } catch { /* ignore */ }
    setBannerOpen(false);
  }

  return (
    <div className="min-h-screen flex flex-col">
      <SiteNav variant="app" />
      <div className="flex flex-1 flex-col md:flex-row">
        <AppSidebar />
        <main className="w-full px-4 md:px-10 py-8 md:py-12 flex flex-col flex-1">
          <div className="mx-auto w-full max-w-[960px] flex-1">
            {bannerOpen && (
              <div className="mb-6 flex items-start justify-between gap-3 rounded-[14px] border border-white/[0.10] bg-white/[0.04] px-4 py-3 text-sm">
                <div className="text-white/75">
                  <span className="font-medium text-white">Welcome to FindEZ.</span>{" "}
                  Add items, ask AI to search or update, scan barcodes, or upload receipts to get started.
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  onClick={dismissBanner}
                  className="shrink-0 -mt-0.5 text-white/40 hover:text-white"
                  aria-label="Dismiss"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            )}
            {props.children}
          </div>

          <footer className="mt-auto border-t border-white/[0.08] py-10 text-center text-xs text-white/20">
            <div className="flex flex-col items-center gap-3">
              <div className="flex flex-wrap items-center justify-center gap-3">
                <Link href="/privacy" className="hover:underline">
                  Privacy Policy
                </Link>
                <span aria-hidden="true">·</span>
                <Link href="/terms" className="hover:underline">
                  Terms & Conditions
                </Link>
                © 2026 FindEZ. All rights reserved.
              </div>
            </div>
          </footer>
        </main>
      </div>
    </div>
  );
}
