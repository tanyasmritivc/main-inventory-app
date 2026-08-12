"use client";

import { useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { bulkCreate, extractFromImageMulti, joinShare } from "@/lib/api";
import { cn } from "@/lib/utils";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { USAGE_TYPE_OPTIONS, type UsageType } from "@/lib/personalization";

type ProblemKey = "dupes" | "cant_find" | "forget_storage" | "disorganized";

const PROBLEM_OPTIONS: Array<{ key: ProblemKey; label: string }> = [
  { key: "dupes", label: "I buy things I already own" },
  { key: "cant_find", label: "I can't find things when I need them" },
  { key: "forget_storage", label: "I forget what's in storage" },
  { key: "disorganized", label: "My garage / closet is disorganized" },
];

type DemoItem = { name: string; category: string; location: string; quantity: number };

const DEMO_ITEMS: DemoItem[] = [
  { name: "Extension cord", category: "Tools", location: "Garage", quantity: 1 },
  { name: "Painter's tape", category: "Hardware", location: "Garage", quantity: 2 },
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

  // Team join-code flow
  const [showJoinInput, setShowJoinInput] = useState(false);
  const [joinCode, setJoinCode] = useState("");
  const [joinSaving, setJoinSaving] = useState(false);
  const [joinError, setJoinError] = useState<string | null>(null);

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
        if (!["homeowner", "diy", "mechanic", "student", "other"].includes(usageType)) {
          return;
        }
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

  async function handleJoinCode() {
    const code = joinCode.trim().toUpperCase();
    if (code.length !== 6) {
      setJoinError("Enter a 6-character code.");
      return;
    }
    setJoinSaving(true);
    setJoinError(null);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) throw new Error("Not signed in");
      await joinShare({ token, share_code: code });
      await saveUsageTypeAndContinue();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Invalid code — check with your coach.";
      setJoinError(msg);
      setJoinSaving(false);
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

      const extracted = res.items || [];
      const saveRes = await bulkCreate({
        token,
        items: extracted.map((it) => ({
          ...it,
          quantity: typeof it.quantity === "number" && Number.isFinite(it.quantity) ? it.quantity : 1,
          location: (it.location ?? "").trim() || "Unsorted",
        })),
      });

      if ((saveRes.inserted || []).length === 0) {
        throw new Error("No items were saved. Please try a clearer photo or add items from the dashboard.");
      }

      await finish();
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

  const isTeamGear = usageType === "mechanic";

  return (
    <div className="w-full max-w-xl">
      <div className="mb-4 flex items-center justify-end">
        <button
          type="button"
          className="text-xs text-white/40 transition-colors hover:text-white/60"
          onClick={onSkip}
          disabled={saving || scanning}
        >
          Skip
        </button>
      </div>

      <div
        className="w-full rounded-2xl"
        style={{
          background: "rgba(255,255,255,0.025)",
          border: "1px solid rgba(255,255,255,0.08)",
          backdropFilter: "blur(24px)",
          WebkitBackdropFilter: "blur(24px)",
          boxShadow: "0 0 0 0.5px rgba(255,255,255,0.04), 0 20px 60px rgba(0,0,0,0.5)",
        }}
      >
        {/* Progress bar */}
        <div className="h-0.5 w-full overflow-hidden rounded-t-2xl" style={{ background: "rgba(255,255,255,0.06)" }}>
          <div
            className="h-full"
            style={{
              width: `${progressPct}%`,
              background: "linear-gradient(90deg, rgba(139,92,246,0.9), rgba(167,139,250,0.7))",
              transition: "width 400ms ease",
            }}
          />
        </div>

        <div className="p-6 sm:p-8">
          {step === 1 ? (
            <div className="grid gap-6">
              <div className="grid gap-1.5">
                <h2
                  className="text-xl font-bold text-white"
                  style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)" }}
                >
                  What are you keeping track of?
                </h2>
                <p className="text-sm" style={{ color: "rgba(255,255,255,0.45)", fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)" }}>
                  This helps us set up your spaces. You can change it later.
                </p>
              </div>

              <div className="grid gap-2">
                {USAGE_TYPE_OPTIONS.map((opt) => {
                  const selected = usageType === opt.value;
                  return (
                    <button
                      key={opt.value}
                      type="button"
                      disabled={saving}
                      onClick={() => {
                        setUsageType(opt.value);
                        setShowJoinInput(false);
                        setJoinCode("");
                        setJoinError(null);
                      }}
                      className={cn(
                        "group relative w-full cursor-pointer rounded-2xl px-4 py-3.5 text-left",
                        "transition-all duration-200",
                        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-500/60",
                        selected
                          ? "border-violet-400/40 bg-violet-500/[0.08]"
                          : "border-white/[0.09] bg-white/[0.02] hover:border-white/[0.18] hover:bg-white/[0.04]"
                      )}
                      style={{
                        border: selected
                          ? "1px solid rgba(167,139,250,0.4)"
                          : undefined,
                        boxShadow: selected
                          ? "0 0 0 1px rgba(139,92,246,0.25), 0 4px 20px rgba(139,92,246,0.12), inset 0 1px 0 rgba(255,255,255,0.06)"
                          : "inset 0 1px 0 rgba(255,255,255,0.04)",
                        borderWidth: selected ? undefined : "1px",
                        borderStyle: selected ? undefined : "solid",
                        borderColor: selected ? undefined : "rgba(255,255,255,0.09)",
                      }}
                    >
                      <div className="flex items-center gap-3">
                        <div
                          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-lg"
                          style={{
                            background: selected
                              ? "rgba(139,92,246,0.15)"
                              : "rgba(255,255,255,0.05)",
                            transition: "background 200ms ease",
                          }}
                        >
                          {opt.icon}
                        </div>
                        <div className="min-w-0">
                          <div
                            className="text-sm font-semibold leading-tight"
                            style={{
                              color: selected ? "rgba(255,255,255,1)" : "rgba(255,255,255,0.85)",
                              fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                            }}
                          >
                            {opt.label}
                          </div>
                          <div
                            className="mt-0.5 text-xs leading-snug"
                            style={{
                              color: selected ? "rgba(255,255,255,0.55)" : "rgba(255,255,255,0.4)",
                              fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                            }}
                          >
                            {opt.sub}
                          </div>
                        </div>
                        {selected && (
                          <div className="ml-auto shrink-0">
                            <div
                              className="flex h-5 w-5 items-center justify-center rounded-full"
                              style={{ background: "rgba(139,92,246,0.9)" }}
                            >
                              <svg width="10" height="8" viewBox="0 0 10 8" fill="none">
                                <path d="M1 4l2.5 2.5L9 1" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                              </svg>
                            </div>
                          </div>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>

              {error ? (
                <p className="text-sm" style={{ color: "rgba(239,68,68,0.9)" }}>{error}</p>
              ) : null}

              <div className="grid gap-3">
                <button
                  type="button"
                  disabled={saving}
                  onClick={saveUsageTypeAndContinue}
                  className="w-full rounded-xl py-3 text-sm font-semibold text-white transition-opacity duration-150 hover:opacity-90 disabled:opacity-50"
                  style={{
                    background: "linear-gradient(135deg, rgba(124,58,237,0.9) 0%, rgba(109,40,217,0.95) 100%)",
                    fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                  }}
                >
                  {saving ? "Saving…" : "Continue"}
                </button>

                {/* Team gear follow-up */}
                {isTeamGear && (
                  <div
                    className="rounded-xl p-4"
                    style={{
                      background: "rgba(245,158,11,0.05)",
                      border: "1px solid rgba(245,158,11,0.18)",
                    }}
                  >
                    <p
                      className="text-sm"
                      style={{ color: "rgba(255,255,255,0.55)", fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)" }}
                    >
                      Have a join code from your coach or teammate?
                    </p>

                    {showJoinInput ? (
                      <div className="mt-3 grid gap-2">
                        <div className="flex gap-2">
                          <input
                            type="text"
                            placeholder="ABC123"
                            maxLength={6}
                            value={joinCode}
                            onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
                            onKeyDown={(e) => { if (e.key === "Enter") void handleJoinCode(); }}
                            className="w-24 rounded-lg px-3 py-2 text-center text-sm font-semibold uppercase tracking-widest text-white placeholder:text-white/25 focus:outline-none focus:ring-1 focus:ring-violet-500/60"
                            style={{
                              background: "rgba(255,255,255,0.06)",
                              border: "1px solid rgba(255,255,255,0.14)",
                              fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                            }}
                            disabled={joinSaving}
                            autoFocus
                          />
                          <button
                            type="button"
                            onClick={() => void handleJoinCode()}
                            disabled={joinSaving || joinCode.trim().length < 6}
                            className="rounded-lg px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-80 disabled:opacity-40"
                            style={{ background: "rgba(139,92,246,0.7)" }}
                          >
                            {joinSaving ? "Joining…" : "Join"}
                          </button>
                          <button
                            type="button"
                            onClick={() => { setShowJoinInput(false); setJoinCode(""); setJoinError(null); }}
                            className="rounded-lg px-2 text-xs transition-colors"
                            style={{ color: "rgba(255,255,255,0.35)" }}
                            disabled={joinSaving}
                          >
                            Cancel
                          </button>
                        </div>
                        {joinError && (
                          <p className="text-xs" style={{ color: "rgba(239,68,68,0.85)" }}>{joinError}</p>
                        )}
                      </div>
                    ) : (
                      <div className="mt-2 flex flex-wrap gap-2">
                        <button
                          type="button"
                          onClick={() => setShowJoinInput(true)}
                          className="rounded-lg px-3 py-1.5 text-xs font-semibold text-white transition-opacity hover:opacity-80"
                          style={{ background: "rgba(139,92,246,0.5)" }}
                        >
                          Enter code
                        </button>
                        <a
                          href="/robotics"
                          className="rounded-lg px-3 py-1.5 text-xs font-medium transition-colors"
                          style={{
                            color: "rgba(255,255,255,0.45)",
                            border: "1px solid rgba(255,255,255,0.12)",
                          }}
                        >
                          I&apos;m setting up for my team
                        </a>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          ) : null}

          {step === 2 ? (
            <div className="grid gap-6">
              <div className="grid gap-1.5">
                <h2
                  className="text-xl font-bold text-white"
                  style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)" }}
                >
                  What&apos;s the hardest part about managing your items?
                </h2>
                <p className="text-sm" style={{ color: "rgba(255,255,255,0.45)", fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)" }}>
                  Pick up to 2. This helps FindEZ focus on what matters most.
                </p>
              </div>
              <div className="grid gap-2">
                {PROBLEM_OPTIONS.map((opt) => {
                  const selected = problems.includes(opt.key);
                  return (
                    <button
                      key={opt.key}
                      type="button"
                      onClick={() => toggleProblem(opt.key)}
                      className={cn(
                        "w-full cursor-pointer rounded-2xl px-4 py-3.5 text-left text-sm font-medium transition-all duration-200",
                        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-500/60",
                        selected
                          ? "text-white"
                          : "hover:border-white/[0.18] hover:bg-white/[0.04]"
                      )}
                      style={{
                        color: selected ? "white" : "rgba(255,255,255,0.75)",
                        border: selected
                          ? "1px solid rgba(167,139,250,0.4)"
                          : "1px solid rgba(255,255,255,0.09)",
                        background: selected ? "rgba(139,92,246,0.08)" : "rgba(255,255,255,0.02)",
                        boxShadow: selected
                          ? "0 0 0 1px rgba(139,92,246,0.25), inset 0 1px 0 rgba(255,255,255,0.06)"
                          : "inset 0 1px 0 rgba(255,255,255,0.04)",
                        fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                      }}
                    >
                      {opt.label}
                    </button>
                  );
                })}
              </div>
              <button
                type="button"
                onClick={() => setStep(3)}
                className="w-full rounded-xl py-3 text-sm font-semibold text-white transition-opacity hover:opacity-90"
                style={{
                  background: "linear-gradient(135deg, rgba(124,58,237,0.9) 0%, rgba(109,40,217,0.95) 100%)",
                  fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                }}
              >
                Continue
              </button>
            </div>
          ) : null}

          {step === 3 ? (
            <div className="grid gap-6">
              <div className="grid gap-1.5">
                <h2
                  className="text-xl font-bold text-white"
                  style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)" }}
                >
                  Let&apos;s add your first item the fast way
                </h2>
                <p className="text-sm" style={{ color: "rgba(255,255,255,0.45)", fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)" }}>
                  Upload a photo — FindEZ will scan and organize items automatically.
                </p>
              </div>
              <div className="grid gap-3">
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
                <button
                  type="button"
                  disabled={scanning}
                  onClick={() => fileInputRef.current?.click()}
                  className="w-full rounded-xl py-3 text-sm font-semibold text-white transition-opacity hover:opacity-90 disabled:opacity-50"
                  style={{
                    background: "linear-gradient(135deg, rgba(124,58,237,0.9) 0%, rgba(109,40,217,0.95) 100%)",
                    fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                  }}
                >
                  {scanning ? "Scanning…" : "Upload a photo"}
                </button>
                <button
                  type="button"
                  disabled={scanning}
                  onClick={useDemo}
                  className="w-full rounded-xl py-3 text-sm font-medium transition-colors disabled:opacity-50"
                  style={{
                    color: "rgba(255,255,255,0.55)",
                    border: "1px solid rgba(255,255,255,0.1)",
                    background: "rgba(255,255,255,0.02)",
                    fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                  }}
                >
                  Try a demo photo
                </button>
                {scanning && (
                  <div className="grid gap-1 text-xs" style={{ color: "rgba(255,255,255,0.45)", fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)" }}>
                    <div style={{ color: scanStep >= 0 ? "rgba(167,139,250,0.9)" : undefined }}>
                      {scanStep >= 0 ? "✓" : "·"} Photo uploaded
                    </div>
                    <div style={{ color: scanStep >= 1 ? "rgba(167,139,250,0.9)" : undefined }}>
                      {scanStep >= 1 ? "✓" : "·"} Detecting items
                    </div>
                    <div style={{ color: scanStep >= 2 ? "rgba(167,139,250,0.9)" : undefined }}>
                      {scanStep >= 2 ? "✓" : "·"} Extracting details
                    </div>
                  </div>
                )}
                {error ? (
                  <p className="text-sm" style={{ color: "rgba(239,68,68,0.9)" }}>{error}</p>
                ) : null}
              </div>
            </div>
          ) : null}

          {step === 4 ? (
            <div className="grid gap-6">
              <div className="grid gap-1.5">
                <h2
                  className="text-xl font-bold text-white"
                  style={{ fontFamily: "var(--font-syne,'Syne',sans-serif)" }}
                >
                  You&apos;re all set
                </h2>
                <p className="text-sm" style={{ color: "rgba(255,255,255,0.45)", fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)" }}>
                  Before you buy something, search FindEZ first.
                </p>
              </div>
              <div
                className="rounded-xl p-4"
                style={{
                  background: "rgba(255,255,255,0.03)",
                  border: "1px solid rgba(255,255,255,0.08)",
                }}
              >
                <div className="mb-3 text-xs" style={{ color: "rgba(255,255,255,0.4)", fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)" }}>
                  Detected items
                </div>
                <div className="grid gap-3">
                  {(detectedItems.length ? detectedItems : DEMO_ITEMS).slice(0, 3).map((it) => (
                    <div key={`${it.name}-${it.location}`} className="flex items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-medium text-white">{it.name}</div>
                        <div className="text-xs" style={{ color: "rgba(255,255,255,0.4)" }}>
                          {it.category} · {it.location}
                        </div>
                      </div>
                      <div className="text-xs shrink-0" style={{ color: "rgba(255,255,255,0.35)" }}>
                        Qty {it.quantity}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
              <button
                type="button"
                onClick={finish}
                className="w-full rounded-xl py-3 text-sm font-semibold text-white transition-opacity hover:opacity-90"
                style={{
                  background: "linear-gradient(135deg, rgba(124,58,237,0.9) 0%, rgba(109,40,217,0.95) 100%)",
                  fontFamily: "var(--font-dm-sans,'DM Sans',sans-serif)",
                }}
              >
                Go to Dashboard
              </button>
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
