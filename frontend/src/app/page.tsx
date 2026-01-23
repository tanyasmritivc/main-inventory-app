import Link from "next/link";

import { MarketingNav } from "@/components/site/marketing-nav";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function Home() {
  return (
    <div className="min-h-screen bg-background">
      <div className="relative overflow-hidden">
        <div className="pointer-events-none absolute inset-0">
          <div className="absolute -top-40 left-1/2 h-[36rem] w-[36rem] -translate-x-1/2 rounded-full bg-gradient-to-tr from-indigo-500/30 via-cyan-400/20 to-emerald-400/20 blur-3xl" />
          <div className="absolute -bottom-48 right-[-8rem] h-[28rem] w-[28rem] rounded-full bg-gradient-to-tr from-fuchsia-500/20 via-indigo-500/20 to-cyan-400/20 blur-3xl" />
        </div>

        <MarketingNav />

        <main className="mx-auto w-full max-w-6xl px-4 py-16">
          <section className="grid gap-10 lg:grid-cols-2 lg:items-center animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="space-y-6">
              <div className="inline-flex items-center rounded-full border bg-background/60 px-3 py-1 text-sm text-muted-foreground backdrop-blur">
                AI + vision + barcode → clean inventory
              </div>
              <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
                Inventory management that fills itself in.
              </h1>
              <p className="text-lg text-muted-foreground">
                Add items manually, from a receipt photo, or by scanning a barcode. Search your inventory
                with natural language and keep item photos attached.
              </p>
              <div className="flex flex-col gap-3 sm:flex-row">
                <Button asChild size="lg" className="transition-transform hover:-translate-y-0.5">
                  <Link href="/signup">Get Started</Link>
                </Button>
                <Button asChild size="lg" variant="outline" className="transition-transform hover:-translate-y-0.5">
                  <Link href="/signin">Sign In</Link>
                </Button>
              </div>
              <p className="text-sm text-muted-foreground">Powered by Supabase Auth + Postgres and OpenAI vision.</p>

              <div className="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-4">
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Fast setup</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold">5m</CardContent>
                </Card>
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Capture modes</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold">3</CardContent>
                </Card>
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Search time</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold">&lt;1s</CardContent>
                </Card>
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">RLS security</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold">On</CardContent>
                </Card>
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Image-based capture</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Upload an item photo or receipt and auto-fill name, category, quantity, and location.
                </CardContent>
              </Card>
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Barcode scanning</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Scan in-browser using ZXing, then attach the barcode to items.
                </CardContent>
              </Card>
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Natural language search</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Search like: “snacks in pantry” or “electronics with barcode”.
                </CardContent>
              </Card>
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Secure by default</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Supabase RLS ensures each user only sees their own inventory items.
                </CardContent>
              </Card>
            </div>
          </section>

          <section className="mt-16 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <h2 className="text-lg font-semibold tracking-tight">Trusted by</h2>
              <p className="text-sm text-muted-foreground">Placeholder logos</p>
            </div>
            <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">Acme</div>
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">Northwind</div>
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">Umbrella</div>
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">Globex</div>
            </div>
          </section>

          <footer className="mt-20 border-t py-10 text-center text-xs text-muted-foreground">
            Built with care. Tiny credit: UI-inspired by modern AI product dashboards.
          </footer>
        </main>
      </div>
    </div>
  );
}
