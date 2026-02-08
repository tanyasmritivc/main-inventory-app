"use client";

import { useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { extractFromImageMulti } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { USAGE_TYPE_OPTIONS, type UsageType } from "@/lib/personalization";

type ProblemKey = "dupes" | "cant_find" | "forget_storage" | "disorganized";

const PROBLEM_OPTIONS: Array<{ key: ProblemKey; label: string }> = [
  { key: "dupes", label: "I buy things I already own" },
  { key: "cant_find", label: "I can’t find things when I need them" },
  { key: "forget_storage", label: "I forget what’s in storage" },
  { key: "disorganized", label: "My garage / closet is disorganized" },
];

type DemoItem = { name: string; category: string; location: string; quantity: number };

const DEMO_ITEMS: DemoItem[] = [
  { name: "Extension cord", category: "Tools", location: "Garage", quantity: 1 },
  { name: "Painter’s tape", category: "Hardware", location: "Garage", quantity: 2 },
  { name: "AA batteries", category: "Home", location: "Closet", quantity: 8 },
];

export function UsageOnboardingClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirect = searchParams.get("redirect") || "/dashboard";
  const normalizedRedirect = redirect.startsWith("/onboarding/usage") ? "/dashboard" : redirect;

  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const [step, setStep] = useState<1 | 2 | 3 | 4>(1);
  const [usageType, setUsageType] = useState<UsageType>("homeowner");
  const [problems, setProblems] = useState<ProblemKey[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [scanning, setScanning] = useState(false);
  const [scanStep, setScanStep] = useState<0 | 1 | 2>(0);
  const [detectedItems, setDetectedItems] = useState<DemoItem[]>([]);

  const progressPct = step === 1 ? 25 : step === 2 ? 50 : step === 3 ? 75 : 100;

  async function finish() {
    router.push(normalizedRedirect);
    router.refresh();
  }

  async function onSkip() {
    if (saving || scanning) return;
    await finish();
  }

  async function saveUsageTypeAndContinue() {
    if (saving) return;
    setSaving(true);
    setError(null);
    try {
      const {
        data: { user },
        error: userErr,
      } = await supabase.auth.getUser();
      if (userErr) throw userErr;
      if (user) {
        await supabase.from("profiles").upsert({ id: user.id, usage_type: usageType });
      }
      setStep(2);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to save preference";
      setError(msg);
    } finally {
      setSaving(false);
    }
  }

  function toggleProblem(k: ProblemKey) {
    setProblems((prev) => {
      if (prev.includes(k)) return prev.filter((p) => p !== k);
      if (prev.length >= 2) return prev;
      return [...prev, k];
    });
  }

  async function startScan(file: File) {
    if (scanning) return;
    setError(null);
    setScanning(true);
    setScanStep(0);

    const t1 = window.setTimeout(() => setScanStep(1), 700);
    const t2 = window.setTimeout(() => setScanStep(2), 2200);

    try {
      const { data, error: sessionErr } = await supabase.auth.getSession();
      if (sessionErr) throw sessionErr;
      const token = data.session?.access_token;
      if (!token) throw new Error("Missing session");

      const res = await extractFromImageMulti({ token, file });
      const items = (res.items || []).slice(0, 3).map((it) => ({
        name: (it.name || "").trim() || "Item",
        category: (it.category || "").trim() || "Unsorted",
        location: (it.location || "").trim() || "Unsorted",
        quantity: typeof it.quantity === "number" && Number.isFinite(it.quantity) ? it.quantity : 1,
      }));

      setDetectedItems(items.length ? items : DEMO_ITEMS);
      setStep(4);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Scan failed";
      setError(msg);
    } finally {
      window.clearTimeout(t1);
      window.clearTimeout(t2);
      setScanning(false);
    }
  }

  function useDemo() {
    if (scanning) return;
    setDetectedItems(DEMO_ITEMS);
    setStep(4);
  }

  return (
    <div className="w-full max-w-xl">
      <div className="mb-4 flex items-center justify-end">
        <Button type="button" variant="ghost" className="text-xs text-muted-foreground" onClick={onSkip} disabled={saving || scanning}>
          Skip
        </Button>
      </div>

      <Card className="w-full rounded-2xl border-neutral-800/60 bg-neutral-950/60 shadow-[0_0_0_1px_rgba(255,255,255,0.04),0_20px_60px_rgba(0,0,0,0.55)] backdrop-blur">
        <div className="h-1 w-full overflow-hidden rounded-t-2xl bg-neutral-800">
          <div className="h-full bg-neutral-200" style={{ width: `${progressPct}%` }} />
        </div>

        {step === 1 ? (
          <>
            <CardHeader>
              <CardTitle>What best describes how you’ll use FindEZ?</CardTitle>
              <CardDescription>
                FindEZ is built homeowner-first. This helps personalize suggestions. You can skip now and change this later.
              </CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3">
              {USAGE_TYPE_OPTIONS.map((opt) => {
                const selected = usageType === opt.value;
                return (
                  <Button
                    key={opt.value}
                    type="button"
                    variant={selected ? "default" : "outline"}
                    className="h-12 justify-start"
                    disabled={saving}
                    onClick={() => setUsageType(opt.value)}
                  >
                    {opt.label}
                  </Button>
                );
              })}

              {error ? <p className="text-sm text-destructive">{error}</p> : null}

              <div className="pt-2">
                <Button type="button" className="w-full" disabled={saving} onClick={saveUsageTypeAndContinue}>
                  Continue
                </Button>
              </div>
            </CardContent>
          </>
        ) : null}

        {step === 2 ? (
          <>
            <CardHeader>
              <CardTitle>What’s the hardest part about managing your items?</CardTitle>
              <CardDescription>Pick up to 2. This helps FindEZ focus on what matters most.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3">
              {PROBLEM_OPTIONS.map((opt) => {
                const selected = problems.includes(opt.key);
                return (
                  <Button
                    key={opt.key}
                    type="button"
                    variant={selected ? "default" : "outline"}
                    className="h-12 justify-start"
                    onClick={() => toggleProblem(opt.key)}
                  >
                    {opt.label}
                  </Button>
                );
              })}

              <div className="pt-2">
                <Button type="button" className="w-full" onClick={() => setStep(3)}>
                  Continue
                </Button>
              </div>
            </CardContent>
          </>
        ) : null}

        {step === 3 ? (
          <>
            <CardHeader>
              <CardTitle>Let’s add your first item the fast way</CardTitle>
              <CardDescription>Upload a photo — FindEZ will scan and organize items automatically.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-4">
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) void startScan(f);
                }}
              />

              <Button
                type="button"
                className="w-full h-12"
                disabled={scanning}
                onClick={() => fileInputRef.current?.click()}
              >
                {scanning ? "Scanning…" : "Upload a photo"}
              </Button>

              <Button type="button" variant="outline" className="w-full h-12" disabled={scanning} onClick={useDemo}>
                Try a demo photo
              </Button>

              {scanning ? (
                <div className="space-y-1 text-sm text-muted-foreground">
                  <div>{scanStep >= 0 ? "✓ Photo uploaded" : "Photo uploaded"}</div>
                  <div>{scanStep >= 1 ? "✓ Detecting items" : "Detecting items"}</div>
                  <div>{scanStep >= 2 ? "✓ Extracting details" : "Extracting details"}</div>
                </div>
              ) : null}

              {error ? <p className="text-sm text-destructive">{error}</p> : null}
            </CardContent>
          </>
        ) : null}

        {step === 4 ? (
          <>
            <CardHeader>
              <CardTitle>You’re all set</CardTitle>
              <CardDescription>Before you buy something, search FindEZ first.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-4">
              <div className="rounded-lg border border-neutral-800/60 bg-neutral-950/40 p-3">
                <div className="text-xs text-muted-foreground">Detected items</div>
                <div className="mt-2 grid gap-2">
                  {(detectedItems.length ? detectedItems : DEMO_ITEMS).slice(0, 3).map((it) => (
                    <div key={`${it.name}-${it.location}`} className="flex items-start justify-between gap-3">
                      <div className="text-sm">
                        <div className="font-medium">{it.name}</div>
                        <div className="text-xs text-muted-foreground">
                          {it.category} • {it.location}
                        </div>
                      </div>
                      <div className="text-xs text-muted-foreground">Qty {it.quantity}</div>
                    </div>
                  ))}
                </div>
              </div>

              <Button type="button" className="w-full h-12" onClick={finish}>
                Go to Dashboard
              </Button>
            </CardContent>
          </>
        ) : null}
      </Card>
    </div>
  );
}
