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
                Keep track of your stuff — effortlessly.
              </div>
              <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
                Your stuff, organized — automatically.
              </h1>
              <p className="text-lg text-muted-foreground">
                Add things by typing, taking a photo, or scanning a barcode.
                Everything stays organized and easy to find.
              </p>
              <div className="flex flex-col gap-3 sm:flex-row">
                <Button asChild size="lg" className="transition-transform hover:-translate-y-0.5">
                  <Link href="/signup">Get Started</Link>
                </Button>
                <Button asChild size="lg" variant="outline" className="transition-transform hover:-translate-y-0.5">
                  <Link href="/signin">Sign In</Link>
                </Button>
              </div>
              <p className="text-sm text-muted-foreground">Private by default. Your stuff stays yours.</p>

              <div className="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-4">
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Set up in minutes</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold"> </CardContent>
                </Card>
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Scan or type</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold"> </CardContent>
                </Card>
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Find things fast</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold"> </CardContent>
                </Card>
                <Card className="bg-background/60 backdrop-blur transition-transform hover:-translate-y-0.5">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Private by default</CardTitle>
                  </CardHeader>
                  <CardContent className="text-2xl font-semibold"> </CardContent>
                </Card>
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Image-based capture</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Take a photo of something and we’ll help fill in the details for you.
                </CardContent>
              </Card>
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Barcode scanning</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Scan a barcode to quickly save items you already own.
                </CardContent>
              </Card>
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Natural language search</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Search your stuff like you’d ask a question.
                </CardContent>
              </Card>
              <Card className="transition-transform hover:-translate-y-0.5">
                <CardHeader>
                  <CardTitle className="text-base">Secure by default</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">
                  Only you can see what you add.
                </CardContent>
              </Card>
            </div>
          </section>

          <section className="mt-16 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <h2 className="text-lg font-semibold tracking-tight">Useful for everyday life</h2>
              <p className="text-sm text-muted-foreground">School · Dorms · Apartments · Small projects</p>
            </div>
            <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">School</div>
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">Dorms</div>
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">Apartments</div>
              <div className="rounded-md border bg-background/60 px-4 py-3 text-sm text-muted-foreground backdrop-blur">Small projects</div>
            </div>
          </section>

          <footer className="mt-20 border-t py-10 text-center text-xs text-muted-foreground">
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
              </div>
              <div>Built with care. Tiny credit: UI-inspired by modern AI product dashboards.</div>
            </div>
          </footer>
        </main>
      </div>
    </div>
  );
}
