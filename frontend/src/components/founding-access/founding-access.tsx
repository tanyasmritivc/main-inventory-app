"use client";

import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { ArrowLeft, Check, Plus, Search, ShieldCheck, X } from "lucide-react";
import { Dialog, DialogPortal } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { isInteriorPath } from "@/lib/app-theme-constants";
import { risoBackground } from "@/lib/riso-palettes";
import styles from "./founding-access.module.css";

const seenInSession = new Set<string>();
const storageKey = (id: string) => `findez_founding_seen_${id}`;
const FoundingContext = createContext<{ accountId: string | null; openPlan: () => void } | null>(null);

export function foundingVersion(createdAt: string | null, now = Date.now()) {
  const age = now - Date.parse(createdAt ?? "");
  return age >= 0 && age < 15 * 60 * 1000 ? "signup" : "signin";
}

function hasSeen(id: string) {
  if (seenInSession.has(id)) return true;
  try { return localStorage.getItem(storageKey(id)) !== null; }
  catch { return false; }
}

function remember(id: string) {
  seenInSession.add(id);
  try { localStorage.setItem(storageKey(id), "true"); }
  catch { /* The current session still remembers dismissal. */ }
}

function anotherDialogIsOpen() {
  return Array.from(document.querySelectorAll<HTMLElement>('[role="dialog"][aria-modal="true"], dialog[open]'))
    .some(node => !node.closest('[data-founding-dialog]') && !node.hidden &&
      node.dataset.state !== "closed" && getComputedStyle(node).display !== "none" &&
      getComputedStyle(node).visibility !== "hidden");
}

type Request = { accountId: string; version: "signup" | "signin"; plan: boolean; open: boolean; sequence: number; returnFocus: HTMLElement | null };

export function FoundingAccessProvider({ accountId, createdAt, pathname, children }: {
  accountId: string | null; createdAt: string | null; pathname: string; children: React.ReactNode;
}) {
  const [request, setRequest] = useState<Request | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const sequence = useRef(0);
  const eligible = Boolean(accountId && isInteriorPath(pathname));
  const open = eligible && request?.accountId === accountId && request.open;
  const show = useCallback((plan: boolean) => {
    if (!accountId || !eligible || anotherDialogIsOpen()) return;
    setRequest({ accountId, version: foundingVersion(createdAt), plan, open: true,
      sequence: ++sequence.current, returnFocus: document.activeElement instanceof HTMLElement ? document.activeElement : null });
  }, [accountId, createdAt, eligible]);

  useEffect(() => {
    if (!accountId || !eligible || open || hasSeen(accountId)) return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const schedule = () => {
      clearTimeout(timer);
      if (hasSeen(accountId) || anotherDialogIsOpen()) return;
      timer = setTimeout(() => {
        if (!hasSeen(accountId) && !anotherDialogIsOpen()) show(false);
      }, 600);
    };
    // Wait until any verification/command/confirmation dialog has finished.
    const observer = new MutationObserver(schedule);
    observer.observe(document.body, { subtree: true, childList: true, attributes: true,
      attributeFilter: ["aria-modal", "data-state", "hidden", "open"] });
    window.addEventListener("storage", schedule);
    schedule();
    return () => { clearTimeout(timer); observer.disconnect(); window.removeEventListener("storage", schedule); };
  }, [accountId, eligible, open, pathname, show]);

  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 5500);
    return () => clearTimeout(timer);
  }, [toast]);

  function close(started = false) {
    if (!request || request.accountId !== accountId) return;
    remember(request.accountId);
    setRequest({ ...request, open: false });
    if (started) setToast(request.accountId);
  }

  return <FoundingContext.Provider value={{ accountId, openPlan: () => show(true) }}>
    {children}
    {request && <FoundingModal key={request.sequence} request={request} open={Boolean(open)} onClose={close} />}
    {eligible && toast === accountId && <div className={styles.toast} role="status">Ask anything, or add your first items with +</div>}
  </FoundingContext.Provider>;
}

function Clove({ size }: { size: number }) {
  return <svg width={size} height={size} viewBox="0 0 34 34" aria-hidden="true">
    <image href="/brand/findez-mark-small-white.svg" width="34" height="34" />
  </svg>;
}

function Art({ small = false }: { small?: boolean }) {
  return <div className={small ? styles.artTile : styles.art} aria-hidden="true">
    <div className={styles.riso} style={{ background: risoBackground("plum") }} />
    {small ? <Clove size={18} /> : <>
      <span className={styles.artChip}>Founding Access</span>
      <span className={styles.logoTile}><Clove size={34} /></span>
      <p className={styles.caption}>Your inventory stays yours, whatever plan you&apos;re on.</p>
    </>}
  </div>;
}

function PlanIdentity() {
  return <><Art small /><div className={styles.planCopy}><strong>Founding Access</strong><span>Your plan right now</span></div><span className={styles.free}>Free</span></>;
}

export function FoundingPlanCard({ accountId }: { accountId: string }) {
  const founding = useContext(FoundingContext);
  return <section className={styles.settingsCard} aria-label="Founding Access">
    <div className={styles.planIdentity}><PlanIdentity /></div>
    <Button variant="outline" className={styles.button} disabled={founding?.accountId !== accountId} onClick={() => founding?.openPlan()}>See what&apos;s included</Button>
  </section>;
}

const points = [
  { Icon: ShieldCheck, title: "Your inventory stays yours", body: "Everything you save stays in your account, even if you never subscribe." },
  { Icon: Search, title: "Always find what you saved", body: "Opening, searching and exporting your items stays free." },
  { Icon: Plus, title: "Adding more will need a plan later", body: "When paid plans launch, you'll get a small free allowance. Adding more will need a subscription." },
];
const rows = [
  ["Open and search items", "included"], ["See item details", "included"],
  ["Export your inventory", "included"], ["Ask FindEZ", "Limited"],
  ["Add new items", "Limited"], ["Add from a photo", "Limited"],
  ["Import a spreadsheet", "Plan"],
] as const;

function Included() {
  return <span className={styles.check}><Check size={16} strokeWidth={2.2} aria-hidden="true" /><span className="sr-only">Included</span></span>;
}

function FoundingModal({ request, open, onClose }: { request: Request; open: boolean; onClose: (started?: boolean) => void }) {
  const [details, setDetails] = useState(request.plan);
  const content = useRef<HTMLDivElement>(null);
  const signup = request.version === "signup";
  function switchView(next: boolean) {
    setDetails(next);
    content.current?.focus({ preventScroll: true });
    content.current?.scrollTo({ top: 0 });
  }
  return <Dialog open={open} onOpenChange={next => { if (!next) onClose(); }}>
    <DialogPortal>
      <DialogPrimitive.Overlay className={styles.overlay} />
      <DialogPrimitive.Content ref={content} data-founding-dialog className={styles.dialog} tabIndex={-1} aria-describedby={undefined}
        onOpenAutoFocus={event => { event.preventDefault(); content.current?.focus({ preventScroll: true }); }}
        onCloseAutoFocus={event => { event.preventDefault(); if (request.returnFocus?.isConnected) request.returnFocus.focus({ preventScroll: true }); }}>
        <Art />
        <div className={styles.body}>
          <DialogPrimitive.Close className={styles.close} aria-label="Close Founding Access"><X size={20} aria-hidden="true" /></DialogPrimitive.Close>
          <div key={details ? "details" : "welcome"} className={styles.view}>
            {details ? <>
              {!request.plan && <button className={styles.back} onClick={() => switchView(false)}><ArrowLeft size={14} aria-hidden="true" />Back</button>}
              <DialogPrimitive.Title className={styles.detailsTitle}>{request.plan ? "Your plan" : "What's included"}</DialogPrimitive.Title>
              <div className={styles.planHeader}><PlanIdentity /></div>
              <div className={styles.tableCard}><table className={styles.table}>
                <thead><tr><th scope="col"><span className="sr-only">Feature</span></th><th scope="col">Now</th><th scope="col">Free plan</th></tr></thead>
                <tbody>{rows.map(([label, value]) => <tr key={label}><th scope="row">{label}</th><td><Included /></td><td>{value === "included" ? <Included /> : <span className={value === "Plan" ? styles.planBadge : styles.limited}>{value}</span>}</td></tr>)}</tbody>
              </table></div>
              <p className={styles.fine}><strong>Free plan</strong> is what you keep without subscribing once paid plans launch. Prices and the date aren&apos;t set yet. We&apos;ll tell you before anything changes, and nothing you&apos;ve saved is ever deleted.</p>
              <div className={styles.actions}><Button className={styles.button} onClick={() => onClose()}>Got it</Button></div>
            </> : <>
              <p className={styles.small}>{signup ? "Welcome to FindEZ" : "Welcome back"}</p>
              <DialogPrimitive.Title className={styles.title}>{signup ? "You're in early." : "You're a Founding member."}</DialogPrimitive.Title>
              <p className={styles.lead}>FindEZ is free while we get ready for launch. {signup ? "Here's how it works." : "Here is what that means for your inventory."}</p>
              <ul className={styles.points}>{points.map(({ Icon, title, body }) => <li className={styles.point} key={title}><span className={styles.icon}><Icon size={18} strokeWidth={1.7} aria-hidden="true" /></span><div><strong>{title}</strong><p>{body}</p></div></li>)}</ul>
              <p className={styles.fine}>We&apos;ll tell you before anything changes. You can find this anytime in Plans &amp; usage.</p>
              <div className={styles.actions}>
                <Button variant="outline" className={styles.button} onClick={() => switchView(true)}>See what&apos;s included</Button>
                <Button className={styles.button} onClick={() => onClose(true)}>Get started</Button>
              </div>
            </>}
          </div>
        </div>
      </DialogPrimitive.Content>
    </DialogPortal>
  </Dialog>;
}
