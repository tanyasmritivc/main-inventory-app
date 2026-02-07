"use client";

import { useState } from "react";
import { SiteNav } from "@/components/site/nav";
import { AppSidebar } from "@/components/site/app-sidebar";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Barcode, Camera, Search, Sparkles } from "lucide-react";

export function AppShell(props: { children: React.ReactNode }) {
  const [quickOpen, setQuickOpen] = useState(() => {
    if (typeof window === "undefined") return false;
    try {
      const dismissed = window.sessionStorage.getItem("findez_quick_instructions_dismissed");
      return !dismissed;
    } catch {
      return false;
    }
  });

  return (
    <div className="min-h-screen">
      <SiteNav variant="app" />
      <div className="flex flex-col md:flex-row">
        <AppSidebar />
        <main className="w-full px-4 py-10">
          <div className="mx-auto w-full max-w-6xl">{props.children}</div>

          <Dialog open={quickOpen} onOpenChange={setQuickOpen}>
            <DialogContent className="sm:max-w-lg">
              <DialogHeader>
                <DialogTitle>Quick Instructions</DialogTitle>
                <DialogDescription>Here’s how to get value from FindEZ in under 30 seconds.</DialogDescription>
              </DialogHeader>

              <div className="space-y-4 text-sm leading-6">
                <div className="flex gap-3">
                  <Sparkles className="mt-0.5 h-4 w-4 text-muted-foreground" />
                  <div>
                    <div className="font-medium">What FindEZ is for</div>
                    <div className="text-muted-foreground">Track what you own so you can find it fast and avoid duplicates.</div>
                  </div>
                </div>

                <div className="flex gap-3">
                  <Search className="mt-0.5 h-4 w-4 text-muted-foreground" />
                  <div>
                    <div className="font-medium">Search before buying</div>
                    <div className="text-muted-foreground">Use Inventory search to see if you already have it.</div>
                  </div>
                </div>

                <div className="flex gap-3">
                  <Camera className="mt-0.5 h-4 w-4 text-muted-foreground" />
                  <div>
                    <div className="font-medium">Add items</div>
                    <div className="text-muted-foreground">Add manually, upload a photo for AI auto-fill, or scan a barcode.</div>
                  </div>
                </div>

                <div className="flex gap-3">
                  <Barcode className="mt-0.5 h-4 w-4 text-muted-foreground" />
                  <div>
                    <div className="font-medium">Ask FindEZ (AI)</div>
                    <div className="text-muted-foreground">Ask to add, delete, move, or update items.</div>
                  </div>
                </div>

                <div className="rounded-md border px-3 py-2 text-xs text-muted-foreground">
                  “Running low” updates are manual—use +1 / -1 / Out of Stock on items to keep quantities accurate.
                </div>
              </div>

              <DialogFooter>
                <Button
                  type="button"
                  onClick={() => {
                    try {
                      window.sessionStorage.setItem("findez_quick_instructions_dismissed", "1");
                    } catch {
                      // ignore
                    }
                    setQuickOpen(false);
                  }}
                >
                  Got it
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>

          <footer className="mt-20 border-t py-10 text-center text-xs text-muted-foreground">
            <div className="flex flex-col items-center gap-3">
              <div className="flex flex-wrap items-center justify-center gap-3">
                <Link href="/privacy" className="hover:underline">
                  Privacy Policy
                </Link>
                <span aria-hidden="true">·</span>
                <Link href="/terms" className="hover:underline">
                  Terms & Conditions
                </Link>
              </div>
            </div>
          </footer>
        </main>
      </div>
    </div>
  );
}
