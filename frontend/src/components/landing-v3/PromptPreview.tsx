"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import { ArrowRight, Box, Check, ChevronRight, Layers3, Search, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { buildLandingPreview } from "@/lib/landing-preview";
import { signupUrl } from "./navigation";
import styles from "./preview.module.css";

export type PreviewOrigin = { left: number; top: number; width: number; height: number };

export function PromptPreview({ prompt, origin, fontClass, onClose }: {
  prompt: string; origin: PreviewOrigin; fontClass: string; onClose: () => void;
}) {
  const router = useRouter();
  const preview = useMemo(() => buildLandingPreview(prompt), [prompt]);
  const morph = useRef<Animation | null>(null);
  const [stage, setStage] = useState(0);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<number | null>(null);
  const [leaving, setLeaving] = useState(false);
  const navigating = useRef(false);
  const navigationTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reduced = useRef(false);
  const href = signupUrl(preview.prompt);

  const attachPanel = useCallback((element: HTMLDivElement | null) => {
    morph.current?.cancel();
    morph.current = null;
    if (!element) return;
    reduced.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced.current || !element.animate) return;
    const target = element.getBoundingClientRect();
    morph.current = element.animate([
      { transform: `translate(${origin.left - target.left}px, ${origin.top - target.top}px) scale(${origin.width / target.width}, ${origin.height / target.height})`, borderRadius: "28px", opacity: 0.7 },
      { transform: "translate(0, 0) scale(1, 1)", borderRadius: "28px", opacity: 1 },
    ], { duration: 650, easing: "cubic-bezier(.22,1,.36,1)" });
  }, [origin]);

  useEffect(() => {
    // These are presentation steps for a local demo, not simulated backend progress.
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const timers = [
      setTimeout(() => setStage(1), query.matches ? 0 : 450),
      setTimeout(() => setStage(2), query.matches ? 0 : 1050),
    ];
    const preference = () => { reduced.current = query.matches; if (query.matches) { morph.current?.cancel(); setStage(2); } };
    query.addEventListener("change", preference);
    router.prefetch(href);
    return () => {
      timers.forEach(clearTimeout);
      query.removeEventListener("change", preference);
      if (navigationTimer.current) clearTimeout(navigationTimer.current);
    };
  }, [href, router]);

  function continueToAccount() {
    if (navigating.current) return;
    navigating.current = true;
    setLeaving(true);
    navigationTimer.current = setTimeout(() => router.push(href), reduced.current ? 0 : 280);
  }
  const visible = preview.items.map((item, index) => ({ ...item, index })).filter(item => item.name.toLowerCase().includes(query.toLowerCase()));
  const steps = ["Your description", "Arranging your preview", "Ready to explore"];

  return <Dialog.Root open onOpenChange={open => { if (!open && !navigating.current) onClose(); }}>
    <Dialog.Portal>
      <Dialog.Overlay className={styles.overlay} data-leaving={leaving} />
      <Dialog.Content ref={attachPanel} className={`${styles.panel} ${fontClass}`} data-leaving={leaving}
        onEscapeKeyDown={event => { if (navigating.current) event.preventDefault(); }}
        onCloseAutoFocus={event => { event.preventDefault(); document.getElementById("ask")?.focus({ preventScroll: true }); }}>
        <header className={styles.header}>
          <span className={styles.eyebrow}><span className={styles.dot} /> INTERACTIVE DEMO</span>
          <Dialog.Close className={styles.close} aria-label="Close preview" disabled={leaving}><X size={18} /></Dialog.Close>
        </header>
        <div className={styles.intro}>
          <Dialog.Title className={styles.title}>{stage < 2 ? "Your words, taking shape." : "A little more organized already."}</Dialog.Title>
          <Dialog.Description className={styles.description}>Explore a preview of your world. Nothing is saved yet.</Dialog.Description>
          <p className={styles.prompt}>{preview.prompt}</p>
          <div className={styles.progress} role="status" aria-live="polite">
            {steps.map((label, index) => <span key={label} data-active={stage >= index}>{stage > index ? <Check size={13} /> : <span className={styles.stepDot} />}<span>{label}</span></span>)}
          </div>
        </div>
        <div className={styles.workspace} data-ready={stage >= 1} aria-busy={stage < 2}>
          <div className={styles.workspaceHeader}>
            <span className={styles.spaceIcon}><Layers3 size={21} strokeWidth={1.5} /></span>
            <div><span className={styles.label}>{preview.intent === "project" ? "PROJECT PREVIEW" : preview.intent === "find" ? "SEARCH PREVIEW" : "INVENTORY PREVIEW"}</span><h3>{preview.title}</h3></div>
            <span className={styles.badge}>Not saved</span>
          </div>
          <div className={styles.path}><Box size={14} /> {preview.space}<ChevronRight size={13} /><span>{preview.items.length} preview entries</span></div>
          <label className={styles.search}><Search size={17} /><input id="preview-filter" name="preview-filter" autoComplete="off" aria-label="Filter preview items" placeholder="Find in this preview" value={query} onChange={event => { setQuery(event.target.value); setSelected(null); }} /></label>
          <div className={styles.items}>
            {visible.map(item => <div className={styles.item} key={item.index}>
              <button onClick={() => setSelected(selected === item.index ? null : item.index)} aria-expanded={selected === item.index} aria-controls={`preview-item-${item.index}`}>
                <span className={styles.itemIcon}><Box size={18} strokeWidth={1.4} /></span>
                <span className={styles.itemName}><b>{item.name}</b><small>{item.source === "example" ? "Example item" : "From your description"}</small></span>
                <span className={styles.quantity}>{item.quantity === null ? "Qty -" : `Qty ${item.quantity}`}</span><ChevronRight size={15} className={styles.chevron} />
              </button>
              {selected === item.index && <p id={`preview-item-${item.index}`} className={styles.detail}>{item.source === "example" ? "An example of how an item could look here. It will not be added to your inventory." : `From your description. ${item.quantity === null ? "The quantity needs review." : "Confirm the quantity when you save."}`} Location shown: {preview.space} (suggested layout).</p>}
            </div>)}
            {!visible.length && <div className={styles.empty}><Box size={28} strokeWidth={1.3} /><b>{query ? "No preview items match" : "Room for your first item"}</b><p>{query ? "Try another name. This filter searches the demo only." : "Your request is kept below. After signup, FindEZ can help turn it into saved items and Spaces."}</p>{query && <button onClick={() => setQuery("")}>Clear filter</button>}</div>}
          </div>
          <p className={styles.note}>{preview.note}</p>
        </div>
        <footer className={styles.footer}>
          <p>Create an account to save your own items and use the full app. Your original request will be ready in chat for review.</p>
          <div className={styles.actions}>
            <button className={styles.edit} onClick={onClose} disabled={leaving}>Edit prompt</button>
            <button className={styles.secondary} onClick={continueToAccount} disabled={leaving}>Open full app</button>
            <button className={styles.primary} onClick={continueToAccount} disabled={leaving}>{leaving ? "Opening signup" : "Sign up to save"}<ArrowRight size={17} /></button>
          </div>
        </footer>
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}
