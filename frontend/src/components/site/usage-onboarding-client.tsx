"use client";

import { useLayoutEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { bulkCreate, extractFromImageMulti, joinShare } from "@/lib/api";
import { cn } from "@/lib/utils";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { USAGE_TYPE_OPTIONS, type UsageType } from "@/lib/personalization";

type ProblemKey = "dupes" | "cant_find" | "forget_storage" | "disorganized";

const PROBLEM_OPTIONS: Array<{ key: ProblemKey; label: string }> = [
  { key: "dupes",         label: "I buy things I already own" },
  { key: "cant_find",     label: "I can't find things when I need them" },
  { key: "forget_storage",label: "I lose track of what's in storage" },
  { key: "disorganized",  label: "My space is disorganized" },
];

type DemoItem = { name: string; category: string; location: string; quantity: number };

const DEMO_ITEMS: DemoItem[] = [
  { name: "Extension cord",   category: "Tools",    location: "Garage", quantity: 1 },
  { name: "Painter's tape",   category: "Hardware", location: "Garage", quantity: 2 },
  { name: "AA batteries",     category: "Home",     location: "Closet", quantity: 8 },
];

const DM = "var(--font-dm-sans,'DM Sans',sans-serif)";
const SYNE = "var(--font-syne,'Syne',sans-serif)";

export function UsageOnboardingClient() {
  const router        = useRouter();
  const searchParams  = useSearchParams();
  const redirect      = searchParams.get("redirect") || "/dashboard";
  const normalizedRedirect = redirect.startsWith("/onboarding/usage") ? "/dashboard" : redirect;

  const supabase    = useMemo(() => createSupabaseBrowserClient(), []);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const [step, setStep]           = useState<1 | 2 | 3 | 4>(1);
  const [usageType, setUsageType] = useState<UsageType>("homeowner");
  const [problems, setProblems]   = useState<ProblemKey[]>([]);
  const [saving, setSaving]       = useState(false);
  const [error, setError]         = useState<string | null>(null);

  const [scanning, setScanning]   = useState(false);
  const [scanStep, setScanStep]   = useState<0 | 1 | 2>(0);
  const [detectedItems, setDetectedItems] = useState<DemoItem[]>([]);

  // Team join-code flow
  const [showJoinInput, setShowJoinInput] = useState(false);
  const [joinCode,  setJoinCode]  = useState("");
  const [joinSaving, setJoinSaving] = useState(false);
  const [joinError,  setJoinError]  = useState<string | null>(null);

  // Height animation: measure content after each step mount
  const contentRef    = useRef<HTMLDivElement>(null);
  const [cardBodyH, setCardBodyH] = useState<number | null>(null);

  useLayoutEffect(() => {
    const el = contentRef.current;
    if (!el) return;
    // scrollHeight includes padding — give the browser one rAF to finish layout
    const id = requestAnimationFrame(() => {
      if (contentRef.current) setCardBodyH(contentRef.current.scrollHeight);
    });
    return () => cancelAnimationFrame(id);
  }, [step]);

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
      const { data: { user }, error: userErr } = await supabase.auth.getUser();
      if (userErr) throw userErr;
      if (user) {
        if (!["homeowner","diy","mechanic","student","other"].includes(usageType)) return;
        await supabase.from("profiles").upsert({ id: user.id, usage_type: usageType });
      }
      setStep(2);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to save preference");
    } finally {
      setSaving(false);
    }
  }

  async function handleJoinCode() {
    const code = joinCode.trim().toUpperCase();
    if (code.length !== 6) { setJoinError("Enter a 6-character code."); return; }
    setJoinSaving(true);
    setJoinError(null);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) throw new Error("Not signed in");
      await joinShare({ token, share_code: code });
      await saveUsageTypeAndContinue();
    } catch (err: unknown) {
      setJoinError(err instanceof Error ? err.message : "Invalid code — check with your organiser.");
      setJoinSaving(false);
    }
  }

  function toggleProblem(k: ProblemKey) {
    setProblems(prev =>
      prev.includes(k) ? prev.filter(p => p !== k) : prev.length >= 2 ? prev : [...prev, k]
    );
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
        items: extracted.map(it => ({
          ...it,
          quantity: typeof it.quantity === "number" && Number.isFinite(it.quantity) ? it.quantity : 1,
          location: (it.location ?? "").trim() || "Unsorted",
        })),
      });
      if ((saveRes.inserted || []).length === 0)
        throw new Error("No items were saved. Try a clearer photo or add items from the dashboard.");
      await finish();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Scan failed");
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

  // ── shared sub-components ──────────────────────────────────────

  function StepHeading({ title, sub }: { title: string; sub: string }) {
    return (
      <div style={{ display: "grid", gap: 6 }}>
        <h2 style={{ fontFamily: SYNE, fontSize: "1.2rem", fontWeight: 700, color: "#fff", margin: 0 }}>
          {title}
        </h2>
        <p style={{ fontFamily: DM, fontSize: "0.8125rem", color: "rgba(255,255,255,0.45)", margin: 0 }}>
          {sub}
        </p>
      </div>
    );
  }

  function PrimaryBtn({ children, onClick, disabled }: { children: React.ReactNode; onClick?: () => void; disabled?: boolean }) {
    return (
      <button type="button" className="ob-btn-primary" onClick={onClick} disabled={disabled}>
        {children}
      </button>
    );
  }

  // ── render ─────────────────────────────────────────────────────

  return (
    <div style={{ width: "100%", maxWidth: 520 }}>
      {/* Skip */}
      <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: 12 }}>
        <button
          type="button"
          onClick={onSkip}
          disabled={saving || scanning}
          style={{ fontFamily: DM, fontSize: "0.75rem", color: "rgba(255,255,255,0.38)", background: "none", border: "none", cursor: "pointer", transition: "color 180ms ease" }}
          onMouseEnter={e => (e.currentTarget.style.color = "rgba(255,255,255,0.6)")}
          onMouseLeave={e => (e.currentTarget.style.color = "rgba(255,255,255,0.38)")}
        >
          Skip
        </button>
      </div>

      {/* Card */}
      <div className="ob-glass" style={{ width: "100%" }}>

        {/* Progress bar */}
        <div style={{ height: 3, width: "100%", overflow: "hidden", borderRadius: "20px 20px 0 0", background: "rgba(255,255,255,0.07)" }}>
          <div className="ob-progress-fill" style={{ height: "100%", width: `${progressPct}%` }} />
        </div>

        {/* Animated height wrapper */}
        <div
          className="ob-body-height"
          style={cardBodyH != null ? { height: cardBodyH } : undefined}
        >
          {/* Measured content */}
          <div ref={contentRef} style={{ padding: "28px 28px 28px" }}>

            {/* ── STEP 1 ─────────────────────────────────────── */}
            {step === 1 && (
              <div key={1} className="ob-step" style={{ display: "grid", gap: 20 }}>
                <StepHeading
                  title="What are you keeping track of?"
                  sub="Helps us set up your spaces. You can change it any time."
                />

                {/* Option rows */}
                <div style={{ display: "grid", gap: 8 }}>
                  {USAGE_TYPE_OPTIONS.map((opt, i) => {
                    const sel = usageType === opt.value;
                    return (
                      <div
                        key={opt.value}
                        className="ob-option-row"
                        style={{ animationDelay: `${i * 45}ms` }}
                      >
                        <button
                          type="button"
                          disabled={saving}
                          onClick={() => {
                            setUsageType(opt.value);
                            setShowJoinInput(false);
                            setJoinCode("");
                            setJoinError(null);
                          }}
                          className={cn("ob-option", sel && "ob-selected")}
                          style={{ width: "100%", textAlign: "left", padding: "12px 14px", border: "none" }}
                        >
                          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                            {/* Icon chip */}
                            <div style={{
                              flexShrink: 0, width: 36, height: 36, borderRadius: 10,
                              display: "flex", alignItems: "center", justifyContent: "center",
                              fontSize: "1.1rem",
                              background: sel ? "rgba(20,184,166,0.18)" : "rgba(255,255,255,0.06)",
                              transition: "background 180ms ease",
                            }}>
                              {opt.icon}
                            </div>
                            {/* Text */}
                            <div style={{ minWidth: 0, flex: 1 }}>
                              <div style={{ fontFamily: DM, fontSize: "0.875rem", fontWeight: 600, color: sel ? "#fff" : "rgba(255,255,255,0.85)", lineHeight: 1.3 }}>
                                {opt.label}
                              </div>
                              <div style={{ fontFamily: DM, fontSize: "0.75rem", color: sel ? "rgba(255,255,255,0.55)" : "rgba(255,255,255,0.38)", marginTop: 2, lineHeight: 1.4 }}>
                                {opt.sub}
                              </div>
                            </div>
                            {/* Teal check */}
                            {sel && (
                              <div style={{
                                flexShrink: 0, width: 20, height: 20, borderRadius: "50%",
                                background: "var(--ob-accent)",
                                display: "flex", alignItems: "center", justifyContent: "center",
                              }}>
                                <svg width="10" height="8" viewBox="0 0 10 8" fill="none">
                                  <path d="M1 4l2.5 2.5L9 1" stroke="white" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
                                </svg>
                              </div>
                            )}
                          </div>
                        </button>
                      </div>
                    );
                  })}
                </div>

                {error && <p style={{ fontFamily: DM, fontSize: "0.8125rem", color: "rgba(239,68,68,0.9)", margin: 0 }}>{error}</p>}

                <div style={{ display: "grid", gap: 10 }}>
                  <PrimaryBtn disabled={saving} onClick={saveUsageTypeAndContinue}>
                    {saving ? "Saving…" : "Continue"}
                  </PrimaryBtn>

                  {/* Team join-code follow-up */}
                  {isTeamGear && (
                    <div style={{
                      borderRadius: 14, padding: "14px 16px",
                      background: "rgba(20,184,166,0.06)",
                      border: "1px solid rgba(20,184,166,0.22)",
                    }}>
                      <p style={{ fontFamily: DM, fontSize: "0.8125rem", color: "rgba(255,255,255,0.55)", margin: 0 }}>
                        Have a join code from your organiser or coach?
                      </p>
                      {showJoinInput ? (
                        <div style={{ marginTop: 10, display: "grid", gap: 8 }}>
                          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                            <input
                              type="text"
                              placeholder="ABC123"
                              maxLength={6}
                              value={joinCode}
                              onChange={e => setJoinCode(e.target.value.toUpperCase())}
                              onKeyDown={e => { if (e.key === "Enter") void handleJoinCode(); }}
                              disabled={joinSaving}
                              autoFocus
                              style={{
                                width: 90, padding: "7px 10px", textAlign: "center",
                                fontFamily: DM, fontSize: "0.875rem", fontWeight: 600,
                                letterSpacing: "0.18em", textTransform: "uppercase",
                                color: "#fff", background: "rgba(255,255,255,0.07)",
                                border: "1px solid rgba(255,255,255,0.15)", borderRadius: 10,
                                outline: "none",
                              }}
                            />
                            <button
                              type="button"
                              onClick={() => void handleJoinCode()}
                              disabled={joinSaving || joinCode.trim().length < 6}
                              style={{
                                padding: "7px 16px", borderRadius: 10, border: "none",
                                background: "var(--ob-accent)", color: "#fff",
                                fontFamily: DM, fontSize: "0.8125rem", fontWeight: 600,
                                cursor: "pointer", opacity: (joinSaving || joinCode.trim().length < 6) ? 0.45 : 1,
                                transition: "opacity 150ms ease",
                              }}
                            >
                              {joinSaving ? "Joining…" : "Join"}
                            </button>
                            <button
                              type="button"
                              onClick={() => { setShowJoinInput(false); setJoinCode(""); setJoinError(null); }}
                              disabled={joinSaving}
                              style={{ background: "none", border: "none", cursor: "pointer", fontFamily: DM, fontSize: "0.75rem", color: "rgba(255,255,255,0.35)" }}
                            >
                              Cancel
                            </button>
                          </div>
                          {joinError && <p style={{ fontFamily: DM, fontSize: "0.75rem", color: "rgba(239,68,68,0.85)", margin: 0 }}>{joinError}</p>}
                        </div>
                      ) : (
                        <div style={{ marginTop: 8, display: "flex", flexWrap: "wrap", gap: 8 }}>
                          <button
                            type="button"
                            onClick={() => setShowJoinInput(true)}
                            style={{
                              padding: "6px 14px", borderRadius: 8, border: "none",
                              background: "var(--ob-accent)", color: "#fff",
                              fontFamily: DM, fontSize: "0.75rem", fontWeight: 600,
                              cursor: "pointer",
                            }}
                          >
                            Enter code
                          </button>
                          <a
                            href="/robotics"
                            style={{
                              padding: "6px 14px", borderRadius: 8,
                              border: "1px solid rgba(255,255,255,0.12)",
                              fontFamily: DM, fontSize: "0.75rem", color: "rgba(255,255,255,0.45)",
                              textDecoration: "none",
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
            )}

            {/* ── STEP 2 ─────────────────────────────────────── */}
            {step === 2 && (
              <div key={2} className="ob-step" style={{ display: "grid", gap: 20 }}>
                <StepHeading
                  title="What's the hardest part?"
                  sub="Pick up to 2 — this helps FindEZ focus on what matters most to you."
                />
                <div style={{ display: "grid", gap: 8 }}>
                  {PROBLEM_OPTIONS.map((opt, i) => {
                    const sel = problems.includes(opt.key);
                    return (
                      <div key={opt.key} className="ob-option-row" style={{ animationDelay: `${i * 45}ms` }}>
                        <button
                          type="button"
                          onClick={() => toggleProblem(opt.key)}
                          className={cn("ob-option", sel && "ob-selected")}
                          style={{
                            width: "100%", textAlign: "left", padding: "13px 16px", border: "none",
                            fontFamily: DM, fontSize: "0.875rem", fontWeight: 500,
                            color: sel ? "#fff" : "rgba(255,255,255,0.78)",
                          }}
                        >
                          {opt.label}
                        </button>
                      </div>
                    );
                  })}
                </div>
                <PrimaryBtn onClick={() => setStep(3)}>Continue</PrimaryBtn>
              </div>
            )}

            {/* ── STEP 3 ─────────────────────────────────────── */}
            {step === 3 && (
              <div key={3} className="ob-step" style={{ display: "grid", gap: 20 }}>
                <StepHeading
                  title="Add your first item in seconds"
                  sub="Snap a photo of a shelf, a bin, or a pile — FindEZ reads and organises it automatically."
                />
                <div style={{ display: "grid", gap: 10 }}>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    style={{ display: "none" }}
                    onChange={e => { const f = e.target.files?.[0]; if (f) void startScan(f); }}
                  />
                  <PrimaryBtn disabled={scanning} onClick={() => fileInputRef.current?.click()}>
                    {scanning ? "Scanning…" : "Upload a photo"}
                  </PrimaryBtn>
                  <button
                    type="button"
                    disabled={scanning}
                    onClick={useDemo}
                    style={{
                      width: "100%", padding: "0.75rem 0", borderRadius: 12, border: "1px solid rgba(255,255,255,0.11)",
                      background: "rgba(255,255,255,0.03)", color: "rgba(255,255,255,0.55)",
                      fontFamily: DM, fontSize: "0.875rem", cursor: "pointer", transition: "background 180ms ease",
                    }}
                  >
                    Try with a demo photo
                  </button>
                  {scanning && (
                    <div style={{ display: "grid", gap: 4, fontFamily: DM, fontSize: "0.75rem" }}>
                      {[["Photo uploaded", scanStep >= 0], ["Detecting items", scanStep >= 1], ["Extracting details", scanStep >= 2]].map(([label, done]) => (
                        <div key={label as string} style={{ color: done ? "var(--ob-accent-hover)" : "rgba(255,255,255,0.38)" }}>
                          {done ? "✓" : "·"} {label}
                        </div>
                      ))}
                    </div>
                  )}
                  {error && <p style={{ fontFamily: DM, fontSize: "0.8125rem", color: "rgba(239,68,68,0.9)", margin: 0 }}>{error}</p>}
                </div>
              </div>
            )}

            {/* ── STEP 4 ─────────────────────────────────────── */}
            {step === 4 && (
              <div key={4} className="ob-step" style={{ display: "grid", gap: 20 }}>
                <StepHeading
                  title="You're all set"
                  sub="Before you buy something, search FindEZ first."
                />
                <div style={{
                  borderRadius: 14, padding: "14px 16px",
                  background: "rgba(255,255,255,0.03)",
                  border: "1px solid rgba(255,255,255,0.09)",
                }}>
                  <div style={{ fontFamily: DM, fontSize: "0.75rem", color: "rgba(255,255,255,0.38)", marginBottom: 12 }}>
                    Detected items
                  </div>
                  <div style={{ display: "grid", gap: 12 }}>
                    {(detectedItems.length ? detectedItems : DEMO_ITEMS).slice(0, 3).map(it => (
                      <div key={`${it.name}-${it.location}`} style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 12 }}>
                        <div>
                          <div style={{ fontFamily: DM, fontSize: "0.875rem", fontWeight: 500, color: "#fff" }}>{it.name}</div>
                          <div style={{ fontFamily: DM, fontSize: "0.75rem", color: "rgba(255,255,255,0.38)" }}>{it.category} · {it.location}</div>
                        </div>
                        <div style={{ fontFamily: DM, fontSize: "0.75rem", color: "rgba(255,255,255,0.35)", flexShrink: 0 }}>Qty {it.quantity}</div>
                      </div>
                    ))}
                  </div>
                </div>
                <PrimaryBtn onClick={finish}>Go to dashboard</PrimaryBtn>
              </div>
            )}

          </div>{/* /contentRef */}
        </div>{/* /ob-body-height */}
      </div>{/* /ob-glass */}
    </div>
  );
}
