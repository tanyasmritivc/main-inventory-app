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
                        <div className="relative">
                          <div className="findez-example findez-example-1 font-medium">AA batteries</div>
                          <div className="findez-example findez-example-2 font-medium">Phone charger</div>
                          <div className="findez-example findez-example-3 font-medium">Screwdriver</div>
                          <div className="findez-example findez-example-4 font-medium">Light bulbs</div>
                          <div className="findez-example findez-example-5 font-medium">Notebook</div>
                        </div>
                      </div>
                    </div>

                    <div className="space-y-2">
                      <div className="relative findez-demo-rows">
                        <div className="findez-frame findez-frame-1 space-y-2">
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">AA batteries</div>
                              <div className="text-xs text-muted-foreground">2 in Pantry</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Rechargeable AA</div>
                              <div className="text-xs text-muted-foreground">4 in Drawer</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
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

                        <div className="findez-frame findez-frame-2 space-y-2">
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Phone charger</div>
                              <div className="text-xs text-muted-foreground">1 in Desk</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">USB‑C cable</div>
                              <div className="text-xs text-muted-foreground">3 in Bag</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Wall adapter</div>
                              <div className="text-xs text-muted-foreground">2 in Drawer</div>
                            </div>
                          </div>
                          <div className="findez-checkline flex items-center gap-2 pt-1 text-xs text-muted-foreground">
                            <span className="inline-flex h-4 w-4 items-center justify-center rounded-full border">✓</span>
                            You already have this.
                          </div>
                        </div>

                        <div className="findez-frame findez-frame-3 space-y-2">
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Screwdriver</div>
                              <div className="text-xs text-muted-foreground">1 in Toolbox</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Phillips set</div>
                              <div className="text-xs text-muted-foreground">1 in Closet</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Flathead</div>
                              <div className="text-xs text-muted-foreground">1 in Drawer</div>
                            </div>
                          </div>
                          <div className="findez-checkline flex items-center gap-2 pt-1 text-xs text-muted-foreground">
                            <span className="inline-flex h-4 w-4 items-center justify-center rounded-full border">✓</span>
                            You already have this.
                          </div>
                        </div>

                        <div className="findez-frame findez-frame-4 space-y-2">
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Light bulbs</div>
                              <div className="text-xs text-muted-foreground">6 in Closet</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">LED (warm)</div>
                              <div className="text-xs text-muted-foreground">4 in Shelf</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Spare lamp bulb</div>
                              <div className="text-xs text-muted-foreground">1 in Drawer</div>
                            </div>
                          </div>
                          <div className="findez-checkline flex items-center gap-2 pt-1 text-xs text-muted-foreground">
                            <span className="inline-flex h-4 w-4 items-center justify-center rounded-full border">✓</span>
                            You already have this.
                          </div>
                        </div>

                        <div className="findez-frame findez-frame-5 space-y-2">
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Notebook</div>
                              <div className="text-xs text-muted-foreground">3 in Desk</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Legal pad</div>
                              <div className="text-xs text-muted-foreground">2 in Shelf</div>
                            </div>
                          </div>
                          <div className="rounded-md border bg-muted/30 px-3 py-2">
                            <div className="flex items-center justify-between">
                              <div className="text-sm font-medium">Spiral notebook</div>
                              <div className="text-xs text-muted-foreground">1 in Bag</div>
                            </div>
                          </div>
                          <div className="findez-checkline flex items-center gap-2 pt-1 text-xs text-muted-foreground">
                            <span className="inline-flex h-4 w-4 items-center justify-center rounded-full border">✓</span>
                            You already have this.
                          </div>
                        </div>
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
            .findez-example {
              position: absolute;
              left: 0;
              top: 0;
              opacity: 0;
              visibility: hidden;
              transform: none;
              display: inline-block;
            }

            .findez-demo-rows {
              height: 132px;
            }

            .findez-example-1 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType1 17.5s steps(11, end) infinite;
            }

            .findez-example-2 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType2 17.5s steps(13, end) infinite;
            }

            .findez-example-3 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType3 17.5s steps(11, end) infinite;
            }

            .findez-example-4 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType4 17.5s steps(10, end) infinite;
            }

            .findez-example-5 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType5 17.5s steps(8, end) infinite;
            }

            .findez-frame {
              position: absolute;
              left: 0;
              right: 0;
              top: 0;
              opacity: 0;
              visibility: hidden;
              transform: none;
              pointer-events: none;
            }

            .findez-frame-1 {
              animation: findezResults1 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-2 {
              animation: findezResults2 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-3 {
              animation: findezResults3 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-4 {
              animation: findezResults4 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-5 {
              animation: findezResults5 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-checkline {
              opacity: 0.9;
            }

            @keyframes findezType1 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              6.857% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              11.143% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              22.8% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              24.343% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType2 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              25.486% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              26.343% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              30.629% {
                opacity: 1;
                visibility: visible;
                width: 13ch;
              }
              41.429% {
                opacity: 1;
                visibility: visible;
                width: 13ch;
              }
              42.971% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType3 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              44.114% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              44.971% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              49.257% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              60.057% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              61.6% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType4 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              62.743% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              63.6% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              67.886% {
                opacity: 1;
                visibility: visible;
                width: 10ch;
              }
              78.686% {
                opacity: 1;
                visibility: visible;
                width: 10ch;
              }
              80.229% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType5 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              81.371% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              82.229% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              86.514% {
                opacity: 1;
                visibility: visible;
                width: 8ch;
              }
              97.314% {
                opacity: 1;
                visibility: visible;
                width: 8ch;
              }
              98.857% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezResults1 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              14.0% {
                opacity: 0;
                visibility: hidden;
              }
              14.571% {
                opacity: 1;
                visibility: visible;
              }
              23.657% {
                opacity: 1;
                visibility: visible;
              }
              24.343% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults2 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              32.0% {
                opacity: 0;
                visibility: hidden;
              }
              33.2% {
                opacity: 1;
                visibility: visible;
              }
              42.286% {
                opacity: 1;
                visibility: visible;
              }
              42.971% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults3 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              50.629% {
                opacity: 0;
                visibility: hidden;
              }
              51.829% {
                opacity: 1;
                visibility: visible;
              }
              60.914% {
                opacity: 1;
                visibility: visible;
              }
              61.6% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults4 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              69.257% {
                opacity: 0;
                visibility: hidden;
              }
              70.457% {
                opacity: 1;
                visibility: visible;
              }
              79.543% {
                opacity: 1;
                visibility: visible;
              }
              80.229% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults5 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              87.886% {
                opacity: 0;
                visibility: hidden;
              }
              89.086% {
                opacity: 1;
                visibility: visible;
              }
              98.171% {
                opacity: 1;
                visibility: visible;
              }
              98.857% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @media (prefers-reduced-motion: reduce) {
              .findez-example,
              .findez-frame {
                animation: none !important;
              }
              .findez-example {
                position: static;
                opacity: 0;
                visibility: hidden;
                width: auto;
              }
              .findez-example-1 {
                opacity: 1;
                visibility: visible;
                width: auto;
              }
              .findez-frame {
                position: static;
                opacity: 0;
                visibility: hidden;
                transform: none;
              }
              .findez-frame-1 {
                opacity: 1;
                visibility: visible;
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
