import Link from "next/link";

import { MarketingNav } from "@/components/site/marketing-nav";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function Home() {
  return (
    <div className="min-h-screen bg-background flex flex-col">
      <div className="relative overflow-hidden flex flex-col flex-1">
        <div className="pointer-events-none absolute inset-0">
          <div className="absolute -top-40 left-1/2 h-[36rem] w-[36rem] -translate-x-1/2 rounded-full bg-gradient-to-tr from-indigo-500/30 via-cyan-400/20 to-emerald-400/20 blur-3xl" />
          <div className="absolute -bottom-48 right-[-8rem] h-[28rem] w-[28rem] rounded-full bg-gradient-to-tr from-fuchsia-500/20 via-indigo-500/20 to-cyan-400/20 blur-3xl" />
        </div>

        <MarketingNav />

        <main className="mx-auto w-full max-w-6xl px-4 py-16 flex flex-col flex-1">
          <section className="grid gap-10 lg:grid-cols-2 lg:items-center animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="space-y-6">
              <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
                Before you buy it, check FindEZ.
              </h1>
              <p className="text-lg text-muted-foreground">Find out if you already own something similar — in seconds.</p>
              <div className="flex flex-col gap-3 sm:flex-row">
                <Button asChild size="lg" className="transition-transform hover:-translate-y-0.5">
                  <Link href="/signin">Check before buying</Link>
                </Button>
              </div>
            </div>

            <div className="relative">
              <div className="mx-auto w-full max-w-md">
                <Card className="bg-background/60 backdrop-blur">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-base">Check before you buy</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <div className="relative rounded-md border bg-background px-3 py-2">
                      <div className="text-xs text-muted-foreground">Search</div>
                      <div className="mt-1 h-5 overflow-hidden">
                        <div className="findez-typing font-medium">AA batteries</div>
                      </div>
                      <div className="findez-cursor absolute right-3 top-8 h-4 w-px bg-foreground/60" aria-hidden="true" />
                    </div>

                    <div className="space-y-2">
                      <div className="findez-row rounded-md border bg-muted/30 px-3 py-2">
                        <div className="flex items-center justify-between">
                          <div className="text-sm font-medium">AA batteries</div>
                          <div className="text-xs text-muted-foreground">2 in Pantry</div>
                        </div>
                      </div>
                      <div className="findez-row findez-row-2 rounded-md border bg-muted/30 px-3 py-2">
                        <div className="flex items-center justify-between">
                          <div className="text-sm font-medium">Rechargeable AA</div>
                          <div className="text-xs text-muted-foreground">4 in Drawer</div>
                        </div>
                      </div>
                      <div className="findez-row findez-row-3 rounded-md border bg-muted/30 px-3 py-2">
                        <div className="flex items-center justify-between">
                          <div className="text-sm font-medium">Battery charger</div>
                          <div className="text-xs text-muted-foreground">1 in Closet</div>
                        </div>
                      </div>
                      <div className="findez-checkline flex items-center gap-2 pt-1 text-xs text-muted-foreground">
                        <span className="inline-flex h-4 w-4 items-center justify-center rounded-full border">✓</span>
                        You already have this.
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </div>
          </section>

          <section className="mt-16 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="grid gap-4 sm:grid-cols-3">
              <div className="rounded-lg border bg-background/60 p-5 backdrop-blur">
                <div className="text-sm font-semibold">Stop buying duplicates</div>
                <div className="mt-1 text-sm text-muted-foreground">Know what you already have before you spend.</div>
              </div>
              <div className="rounded-lg border bg-background/60 p-5 backdrop-blur">
                <div className="text-sm font-semibold">Find things instantly</div>
                <div className="mt-1 text-sm text-muted-foreground">Search across everything you own in seconds.</div>
              </div>
              <div className="rounded-lg border bg-background/60 p-5 backdrop-blur">
                <div className="text-sm font-semibold">Let AI do the checking</div>
                <div className="mt-1 text-sm text-muted-foreground">FindEZ surfaces overlaps and similarities for you.</div>
              </div>
            </div>
          </section>

          <style>{`
            .findez-typing {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezTyping 6.5s ease-in-out infinite;
            }

            .findez-cursor {
              opacity: 0;
              animation: findezCursor 6.5s ease-in-out infinite;
            }

            .findez-row {
              transform-origin: top;
              animation: findezRow 6.5s ease-in-out infinite;
            }

            .findez-row-2 {
              animation-delay: 0.12s;
            }

            .findez-row-3 {
              animation-delay: 0.24s;
            }

            .findez-checkline {
              opacity: 0;
              transform: translateY(4px);
              animation: findezCheck 6.5s ease-in-out infinite;
            }

            @keyframes findezTyping {
              0% {
                width: 0;
                opacity: 0;
              }
              10% {
                opacity: 1;
              }
              40% {
                width: 12ch;
              }
              55% {
                width: 12ch;
                opacity: 1;
              }
              75% {
                opacity: 0;
                width: 0;
              }
              100% {
                width: 0;
                opacity: 0;
              }
            }

            @keyframes findezCursor {
              0% {
                opacity: 0;
              }
              12% {
                opacity: 1;
              }
              55% {
                opacity: 1;
              }
              75% {
                opacity: 0;
              }
              100% {
                opacity: 0;
              }
            }

            @keyframes findezRow {
              0% {
                opacity: 0.65;
                transform: translateY(0px);
              }
              45% {
                opacity: 0.65;
                transform: translateY(0px);
              }
              62% {
                opacity: 1;
                transform: translateY(-2px);
              }
              78% {
                opacity: 0.6;
                transform: translateY(0px);
              }
              100% {
                opacity: 0.65;
                transform: translateY(0px);
              }
            }

            @keyframes findezCheck {
              0% {
                opacity: 0;
                transform: translateY(4px);
              }
              58% {
                opacity: 0;
                transform: translateY(4px);
              }
              70% {
                opacity: 1;
                transform: translateY(0px);
              }
              88% {
                opacity: 1;
                transform: translateY(0px);
              }
              100% {
                opacity: 0;
                transform: translateY(4px);
              }
            }

            @media (prefers-reduced-motion: reduce) {
              .findez-typing,
              .findez-cursor,
              .findez-row,
              .findez-checkline {
                animation: none !important;
              }
              .findez-typing {
                width: auto;
                opacity: 1;
              }
              .findez-cursor {
                opacity: 0;
              }
              .findez-checkline {
                opacity: 1;
                transform: none;
              }
            }
          `}</style>

          <footer className="mt-auto border-t py-10 text-center text-xs text-muted-foreground">
            <div className="flex flex-col items-center gap-3">
              <div className="flex flex-wrap items-center justify-center gap-3">
                <Link href="/privacy" className="hover:underline">
                  Privacy Policy
                </Link>
                <span aria-hidden="true">·</span>
                <Link href="/terms" className="hover:underline">
                  Terms of Service
                </Link>
                <span aria-hidden="true">·</span>
                <Link href="/terms" className="hover:underline">
                  Terms & Conditions
                </Link>
                © 2026 FindEZ. All rights reserved.
              </div>
              <div>Built with care. Tiny credit: UI-inspired by modern AI product dashboards.</div>
            </div>
          </footer>
        </main>
      </div>
    </div>
  );
}
