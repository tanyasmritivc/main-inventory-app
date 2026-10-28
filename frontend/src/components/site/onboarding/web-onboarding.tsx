"use client";
import { continuePreview, previewPrompt } from "@/lib/landing-preview";

import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useApiSession } from "@/lib/use-api-session";
import { accountToken } from "@/lib/account-request";
import { requireInventoryContext, selectInventory } from "@/lib/inventory-selection";
import { checkSetupEligibility, doneSetupKey, finishSetup, personalDashboard, provisionSetup, readSetup, saveSetup, setupOrder, withSetupLock, type SetupDraft, type SetupPath, type SetupStep } from "@/lib/web-onboarding";
import { miniModel, WorldModel } from "./world-model";
import styles from "./web-onboarding.module.css";

const PURPOSES = { team: ["R&D", "Production", "Competition"], personal: ["Home", "Workshop", "Studio"] };
const INVENTORIES = { team: ["Hardware", "Electronics", "Software"], personal: ["Tools", "Electronics", "Household"] };
const CHECK = <svg width="16" height="13" viewBox="0 0 16 13" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M1.5 6.8 6 11 14.5 1.8" /></svg>;

function World({ draft, hover }: { draft: SetupDraft; hover: SetupPath | null }) {
  const svg = useRef<SVGSVGElement>(null), model = useRef<WorldModel | null>(null);
  useEffect(() => {
    if (!svg.current) return;
    const world = new WorldModel(svg.current);
    model.current = world;
    return () => { world.dispose(); model.current = null; };
  }, []);
  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => model.current?.update(draft, hover, media.matches);
    update(); media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, [draft, hover]);
  const path = hover || draft.path;
  const caption = draft.step === "welcome" ? "FindEZ sees what you own" : draft.step === "choose"
    ? path ? path === "team" ? "Organization, workspace, inventory" : "Personal workspace" : "Pick one to preview it"
    : draft.step === "setup" ? "Saving to your account" : "Your world";
  return <section className={styles.world} aria-label="Your world, a preview of what you are setting up">
    <svg ref={svg} viewBox="0 0 640 640" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Isometric model of your organization, workspace and inventory" />
    <div className={styles.caption}>{caption}</div>
  </section>;
}

function NameField({ label, value, placeholder, maxLength, helper, onChange, onConfirm, autoFocus = false }: {
  label: string; value: string; placeholder: string; maxLength: number; helper?: string;
  onChange: (value: string) => void; onConfirm: () => void; autoFocus?: boolean;
}) {
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => { if (autoFocus) input.current?.focus(); }, [autoFocus]);
  const id = `setup-${label.toLowerCase().replaceAll(" ", "-")}`;
  function submit(event: FormEvent) { event.preventDefault(); if (value.trim()) onConfirm(); }
  return <form className={styles.field} onSubmit={submit}>
    <label htmlFor={id}>{label}</label>
    <div className={styles.inputWrap}><input ref={input} id={id} className={styles.input} value={value}
      onChange={e => onChange(e.target.value)} maxLength={maxLength} placeholder={placeholder}
      autoComplete={label === "Organization name" ? "organization" : "off"}
      aria-describedby={helper ? `${id}-help` : undefined}
      onKeyDown={event => { if (event.key === "Enter" && event.nativeEvent.isComposing) event.preventDefault(); }} />
      <button className={styles.tick} type="submit" aria-label="Continue" disabled={!value.trim()}>{CHECK}</button>
    </div>
    {helper && <div id={`${id}-help`} className={styles.helper}>{helper}</div>}
  </form>;
}

export function WebOnboarding({ userId, initialPrompt = "" }: { userId: string; initialPrompt?: string }) {
  const prompt = previewPrompt(initialPrompt);
  const { accountId, loading: sessionLoading, error: sessionError } = useApiSession();
  if (!sessionLoading && accountId !== userId) return <div className={styles.loading} role="alert"><p>{sessionError || "Your account changed. Sign in to continue."}</p><Link href={`/signin?redirect=${encodeURIComponent(`/onboarding${prompt ? `?${new URLSearchParams({ prompt })}` : ""}`)}`}>Sign in</Link></div>;
  return <SetupAccount key={userId} userId={userId} prompt={prompt} />;
}

function SetupAccount({ userId, prompt }: { userId: string; prompt: string }) {
  const router = useRouter();
  const [draft, setDraft] = useState<SetupDraft | null>(null), current = useRef<SetupDraft | null>(null);
  const [error, setError] = useState(""), [loadAttempt, setLoadAttempt] = useState(0);
  const [hover, setHover] = useState<SetupPath | null>(null), [custom, setCustom] = useState(false);
  const [advance, setAdvance] = useState<{ duration: number; key: number } | null>(null);
  const [busy, setBusy] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null), timerKey = useRef(0);
  const mounted = useRef(true), saving = useRef(false), resumed = useRef(false);
  const heading = useRef<HTMLHeadingElement>(null);

  useLayoutEffect(() => { requireInventoryContext(false); selectInventory(null); }, []);
  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; if (timer.current) clearTimeout(timer.current); };
  }, []);
  useEffect(() => {
    let live = true;
    async function load() {
      try {
        if (localStorage.getItem(doneSetupKey(userId))) { router.replace(continuePreview(await personalDashboard(userId), prompt)); return; }
        const pending = readSetup(localStorage, userId);
        const eligible = await checkSetupEligibility(userId, pending);
        if (!live) return;
        if (!eligible) { router.replace(continuePreview("/organizations", prompt)); return; }
        saveSetup(localStorage, userId, pending);
        current.current = pending; setDraft(pending); setError("");
        const options = pending.step === "purpose" ? PURPOSES[pending.path || "team"] : INVENTORIES[pending.path || "team"];
        const answer = pending.step === "purpose" ? pending.purpose : pending.inventory;
        setCustom(!!answer && !options.includes(answer));
      } catch { if (live) setError("Your setup could not be loaded. Check your connection and site storage, then try again."); }
    }
    void load();
    return () => { live = false; };
  }, [userId, loadAttempt, router, prompt]);

  function cancelAdvance() { if (timer.current) clearTimeout(timer.current); timer.current = null; setAdvance(null); }
  function update(patch: Partial<SetupDraft>) {
    const previous = current.current;
    if (!previous || saving.current) return null;
    const next = { ...previous, ...patch };
    try { saveSetup(localStorage, userId, next); }
    catch { cancelAdvance(); setError("Your answers could not be saved. Check site storage and try again."); return null; }
    current.current = next; setDraft(next); setError("");
    return next;
  }
  function go(step: SetupStep) {
    cancelAdvance(); setHover(null);
    const next = update({ step });
    if (!next) return;
    const options = step === "purpose" ? PURPOSES[next.path || "team"] : INVENTORIES[next.path || "team"];
    const answer = step === "purpose" ? next.purpose : next.inventory;
    setCustom(!!answer && !options.includes(answer));
  }
  function next() {
    if (!current.current) return;
    const order = setupOrder(current.current.path), index = order.indexOf(current.current.step);
    if (order[index + 1]) go(order[index + 1]);
  }
  function back() {
    if (!current.current) return;
    const order = setupOrder(current.current.path), index = order.indexOf(current.current.step);
    if (index > 0) go(order[index - 1]);
  }
  function autoAdvance(duration: number) {
    cancelAdvance();
    const step = current.current?.step;
    setAdvance({ duration, key: ++timerKey.current });
    timer.current = setTimeout(() => { if (mounted.current && current.current?.step === step) next(); }, duration);
  }
  function choose(path: SetupPath) {
    const changed = current.current?.path !== path;
    if (update({ path, ...(changed ? { purpose: "", inventory: "", orgName: "" } : {}) })) autoAdvance(900);
  }
  function answer(value: string, typed = false) {
    cancelAdvance();
    const step = current.current?.step;
    if (update(step === "purpose" ? { purpose: value } : { inventory: value }) && value.trim() && !typed) autoAdvance(step === "purpose" ? 1100 : 1900);
  }

  async function setup() {
    if (saving.current || !current.current) return;
    cancelAdvance(); saving.current = true; setBusy(true); setError("");
    try {
      const destination = await withSetupLock(userId, async () => {
        await accountToken(userId);
        // Another tab may have progressed while this tab waited for the lock.
        if (localStorage.getItem(doneSetupKey(userId))) return "/organizations";
        return provisionSetup(userId, readSetup(localStorage, userId), localStorage, (value) => {
          if (mounted.current) { current.current = value; setDraft(value); }
        });
      });
      if (mounted.current) router.replace(continuePreview(destination, prompt));
    } catch { if (mounted.current) setError("We couldn't finish setting up. Try again."); }
    finally { saving.current = false; if (mounted.current) setBusy(false); }
  }
  useEffect(() => {
    if (draft?.step === "setup" && !resumed.current) { resumed.current = true; void setup(); }
    // Resume only the persisted setup step. Interactive setup runs from the button.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [draft?.step]);
  useEffect(() => {
    if (draft?.step && draft.step !== "org") heading.current?.focus({ preventScroll: true });
  }, [draft?.step]);

  async function skip() {
    if (saving.current) return;
    cancelAdvance(); saving.current = true; setBusy(true);
    try {
      await withSetupLock(userId, async () => {
        await accountToken(userId);
        const latest = readSetup(localStorage, userId);
        if (latest.step === "setup" || Object.values(latest.createdIds).some(Boolean)) throw new Error("Setup is already saving.");
        const href = await personalDashboard(userId);
        finishSetup(localStorage, userId);
        if (mounted.current) router.replace(continuePreview(href, prompt));
      });
    } catch { if (mounted.current) setError("Your dashboard could not be opened. Try again."); }
    finally { saving.current = false; if (mounted.current) setBusy(false); }
  }

  if (!draft) return <div className={styles.loading} role={error ? "alert" : "status"}><p>{error || "Getting your world ready..."}</p>{error && <button className={styles.primary} onClick={() => setLoadAttempt(v => v + 1)}>Try again</button>}</div>;
  const { step, path } = draft, team = path === "team";
  const title = { welcome: "Let's set up your first inventory.", choose: "Who's FindEZ for?", org: "Name your organization", purpose: "What's this workspace for?", inventory: "Create your first inventory", world: "This is your world.", setup: "Setting up your dashboard" }[step];
  const subtitle = { welcome: "Three quick questions. Then point your camera at a shelf and FindEZ fills it in for you.", choose: "Pick one to start. You can change it later.", org: "Use the name of your company, lab or team.", purpose: team ? "Each purpose gets its own dashboard." : "Your personal space. Only you can see it.", inventory: team ? "Group your things by team, like hardware or software." : "Group your things, like tools or electronics.", world: "Add more workspaces and inventories anytime. Spaces like a parts wall go inside each inventory.", setup: "Creating what you picked. This takes a moment." }[step];
  const steps = setupOrder(path).filter(s => !["welcome", "setup"].includes(s));
  const chips = step === "purpose" ? PURPOSES[path || "team"] : INVENTORIES[path || "team"];
  const value = step === "purpose" ? draft.purpose : draft.inventory;
  const legend = [[team ? "Organization" : "Personal", team ? draft.orgName : "Only you", team ? "#E8590C" : "#3E9B63"], ["Workspace", draft.purpose, "#A3B8E2"], ["Inventory", draft.inventory, "#EDBB9C"]];

  return <div className={styles.app} onKeyDown={event => {
    if (event.key === "Enter" && !event.nativeEvent.isComposing && event.target === heading.current && step === "welcome") { event.preventDefault(); next(); }
  }}>
    <header className={styles.top}>
      <div className={styles.brand} aria-label="FindEZ"><svg width="24" height="24" viewBox="0 0 100 100" aria-hidden="true"><path fill="#E8590C" d="M55.5 1H99V44H55.5z" /><path fill="#111112" d="M0 23.5H76V46H0zM53.5 23.5H76V100H53.5z" /></svg><span>Find<b>EZ</b></span></div>
      <div className={styles.progress} aria-label={`Setup step ${Math.max(0, steps.indexOf(step) + 1)} of ${steps.length}`}>{steps.map((s, i) => <i key={s} className={i <= steps.indexOf(step) ? styles.progressOn : ""} />)}</div>
      {step !== "setup" && <button className={styles.skip} type="button" disabled={busy} onClick={() => void skip()}>Skip for now</button>}
    </header>
    <main className={styles.stage}>
      <section className={styles.panel} aria-label="Set up your first inventory">
        <div className={styles.step} key={step}>
          {step === "welcome" && <div className={styles.eyebrow}>Welcome to FindEZ</div>}
          <h1 ref={heading} tabIndex={-1}>{title}</h1><p className={styles.subtitle}>{subtitle}</p>
          {step === "choose" && <div className={styles.body}>
            <div className={styles.tiles} role="radiogroup" aria-label="Who is FindEZ for">{(["personal", "team"] as SetupPath[]).map(option => <button key={option} type="button" role="radio" aria-checked={path === option} className={`${styles.tile} ${path === option ? styles.selectedTile : ""}`} onClick={() => choose(option)} onMouseEnter={() => setHover(option)} onMouseLeave={() => setHover(null)} onFocus={() => setHover(option)} onBlur={() => setHover(null)}>
              <span><span className={styles.tileTitle}>{option === "personal" ? "Just me" : "My team"}</span><span className={styles.tileDescription}>{option === "personal" ? "Home, garage, desk or dorm." : "A company, lab or team."}</span></span>
              <svg width={option === "personal" ? 62 : 76} height={option === "personal" ? 56 : 60} viewBox={option === "personal" ? "-40 -40 80 70" : "-60 -48 120 90"} aria-hidden="true" dangerouslySetInnerHTML={{ __html: miniModel(option) }} />
            </button>)}</div><div className={styles.note}>Starting solo? You can add an organization anytime.</div>
          </div>}
          {step === "org" && <div className={styles.body}><NameField autoFocus label="Organization name" placeholder="e.g. Kestrel Labs" maxLength={60} value={draft.orgName} onChange={orgName => update({ orgName })} onConfirm={next} helper="Your team will see this. You can change it later." /></div>}
          {(step === "purpose" || step === "inventory") && <div className={styles.body}>
            <div className={styles.chips}>{chips.map(chip => <button key={chip} type="button" className={`${styles.chip} ${!custom && value === chip ? styles.selectedChip : ""}`} aria-pressed={!custom && value === chip} onClick={() => { setCustom(false); answer(chip); }}>{chip}</button>)}<button type="button" className={`${styles.chip} ${styles.addChip} ${custom ? styles.selectedChip : ""}`} aria-pressed={custom} onClick={() => { cancelAdvance(); setCustom(true); answer(custom ? value : "", true); }}>+ Custom</button></div>
            {custom && <NameField autoFocus label={step === "purpose" ? "Your own purpose" : "Your own inventory"} placeholder={step === "purpose" ? "e.g. Field service" : "e.g. Lab supplies"} maxLength={40} value={value} onChange={v => answer(v, true)} onConfirm={next} />}
          </div>}
          {step === "world" && <dl className={styles.legend}>{legend.map(([label, text, color]) => <div key={label}><dt><i style={{ background: color }} />{label}</dt><dd>{text}</dd></div>)}</dl>}
          {step === "setup" && <div className={styles.checks} role="status" aria-label="Setup progress">{(team ? ["organization", "workspace", "inventory"] : ["workspace", "inventory"]).map(kind => {
            const resource = kind as keyof SetupDraft["createdIds"], label = resource === "organization" ? draft.orgName : resource === "workspace" ? draft.purpose : draft.inventory;
            const done = !!draft.createdIds[resource];
            return <div key={kind} className={done ? styles.checkDone : ""}><span className={styles.checkIcon}>{done ? CHECK : <i className={styles.checkPending} />}</span><span>{kind.charAt(0).toUpperCase() + kind.slice(1)} &quot;{label}&quot;{done && <span className={styles.srOnly}> created</span>}</span></div>;
          })}</div>}
          {error && <p className={styles.error} role="alert">{error}</p>}
          <div className={styles.actions}>
            {step === "welcome" && <><button type="button" className={styles.primary} onClick={next}>Get started</button><span className={styles.keyboard}>Press Enter</span></>}
            {step === "world" && <button type="button" className={styles.primary} onClick={() => void setup()} disabled={busy}>Open my dashboard</button>}
            {!["welcome", "setup"].includes(step) && <button className={styles.back} type="button" onClick={back}>Back</button>}
            {advance && <span key={advance.key} className={styles.advance} aria-hidden="true"><i style={{ "--advance-duration": `${advance.duration}ms` } as CSSProperties} /></span>}
            {step === "setup" && error && <button type="button" className={styles.primary} disabled={busy} onClick={() => void setup()}>Try again</button>}
          </div>
        </div>
      </section>
      <World draft={draft} hover={hover} />
    </main>
  </div>;
}
