"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { useApiSession } from "@/lib/use-api-session";
import { accountToken } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import styles from "./account-verification.module.css";

const prompted = new Set<string>();
const cooldowns = new Map<string, number>();
async function bounded<T>(request: PromiseLike<T>): Promise<T> {
  let timer: ReturnType<typeof setTimeout>;
  try {
    return await Promise.race([Promise.resolve(request), new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new Error("Verification timed out. Check your connection and try again.")), 10000);
    })]);
  } finally { clearTimeout(timer!); }
}
export function AccountVerification({ prompt = false }: { prompt?: boolean }) {
  const { accountId } = useApiSession();
  return accountId ? <Verification key={accountId} accountId={accountId} prompt={prompt} /> : null;
}
function Verification({ accountId, prompt }: { accountId: string; prompt: boolean }) {
  const auth = useMemo(() => createSupabaseBrowserClient().auth, []);
  const [status, setStatus] = useState<"checking" | "verified" | "unverified" | "unknown">("checking");
  const [email, setEmail] = useState(""), [error, setError] = useState(""), [notice, setNotice] = useState("");
  const [open, setOpen] = useState(false), [busy, setBusy] = useState(false), [seconds, setSeconds] = useState(0);
  const alive = useRef(true), pending = useRef(false), sequence = useRef(0);
  const key = `findez-verification:${accountId}`;
  const check = useCallback(async () => {
    const ticket = ++sequence.current;
    try {
      const { data, error: authError } = await bounded(auth.getUser());
      if (!alive.current || ticket !== sequence.current) return null;
      if (authError) throw authError;
      if (data.user?.id !== accountId || !data.user.email) throw new Error("Your account changed. Reopen Settings and try again.");
      const user = data.user;
      setEmail(user.email!); setError("");
      const verified = !!user.email_confirmed_at;
      setStatus(verified ? "verified" : "unverified");
      if (verified) { setOpen(false); setNotice(""); }
      else if (prompt) {
        let shown = prompted.has(key);
        try { shown ||= sessionStorage.getItem(key) === "shown"; } catch { /* In-memory dismissal still works. */ }
        if (!shown) {
          prompted.add(key);
          try { sessionStorage.setItem(key, "shown"); } catch { /* In-memory dismissal still works. */ }
          setOpen(true);
        }
      }
      return user;
    } catch (reason) {
      if (alive.current && ticket === sequence.current) { setStatus("unknown"); setError(userFacingError(reason, "Verification status could not be checked.")); }
      return null;
    }
  }, [auth, accountId, key, prompt]);
  useEffect(() => {
    alive.current = true;
    const requests = sequence;
    void check();
    const focus = () => { if (!pending.current) void check(); };
    window.addEventListener("focus", focus);
    // Defer outside the auth callback so getUser does not wait on its own lock.
    const { data } = auth.onAuthStateChange(event => {
      if (event === "USER_UPDATED" || event === "SIGNED_IN") queueMicrotask(focus);
    });
    const tick = () => {
      let until = cooldowns.get(key) || 0;
      try { until = Math.max(until, Number(sessionStorage.getItem(`${key}:cooldown`)) || 0); } catch { /* Optional persistence. */ }
      setSeconds(Math.max(0, Math.min(60, Math.ceil((until - Date.now()) / 1000))));
    };
    tick(); const interval = setInterval(tick, 1000);
    return () => { alive.current = false; requests.current++; clearInterval(interval); data.subscription.unsubscribe(); window.removeEventListener("focus", focus); };
  }, [auth, check, key]);
  async function resend() {
    if (pending.current || seconds > 0 || status !== "unverified") return;
    pending.current = true; setBusy(true); setNotice(""); setError("");
    try {
      await bounded(accountToken(accountId));
      const user = await check();
      if (!alive.current || !user || user.email_confirmed_at) return;
      const callback = new URL("/auth/callback", window.location.origin);
      callback.searchParams.set("next", "/settings/account");
      // Cool down attempts too: a lost response must not trigger repeated emails.
      const until = Date.now() + 60000;
      cooldowns.set(key, until); setSeconds(60);
      try { sessionStorage.setItem(`${key}:cooldown`, String(until)); } catch { /* Optional persistence. */ }
      const { error: resendError } = await bounded(auth.resend({type:"signup", email:user.email!, options:{emailRedirectTo:callback.toString()}}));
      if (!alive.current) return;
      if (resendError) throw resendError;
      await bounded(accountToken(accountId));
      if (alive.current) setNotice("Verification email requested. Open the latest FindEZ email, then return here and check verification. Check spam if it does not arrive.");
    } catch (reason) {
      if (alive.current) setError(userFacingError(reason, "The verification email could not be requested. Try again after the cooldown."));
    } finally { pending.current = false; if (alive.current) setBusy(false); }
  }
  const content = <div className={styles.content}>
    {status === "checking" ? <p role="status">Checking email verification...</p> : status === "verified" ? <p role="status">Verified email: <strong>{email}</strong></p> : <>
      {status === "unverified" && <p>Verify <strong>{email}</strong> to confirm this email belongs to you. Use your sign-in email, not a separate profile contact address.</p>}
      {error && <p role="alert">{error}</p>}
      {notice && <p role="status">{notice}</p>}
      <div className="product-actions">
        {status === "unverified" && <button className="product-button" disabled={busy || seconds > 0} onClick={()=>void resend()}>{busy ? "Requesting email..." : seconds > 0 ? `Resend in ${seconds}s` : "Send verification email"}</button>}
        <button className="product-button" disabled={busy} onClick={()=>void check()}>Check verification</button>
      </div>
    </>}
  </div>;
  if (prompt) return <Dialog open={open} onOpenChange={value=>{if(!busy)setOpen(value);}}>
    <DialogContent className="workspace-dialog"><DialogTitle>Verify your email</DialogTitle><DialogDescription>Confirm your sign-in email to finish setting up your account.</DialogDescription>{content}<button className="product-button" disabled={busy} onClick={()=>setOpen(false)}>Later</button></DialogContent>
  </Dialog>;
  return <section className={`settings-panel ${styles.panel}`} aria-label="Email verification"><header><h2>Email verification</h2></header>{content}</section>;
}
