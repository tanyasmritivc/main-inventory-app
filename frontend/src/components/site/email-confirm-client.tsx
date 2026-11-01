"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { parseEmailLink, verifyEmailLink, type EmailLink } from "@/lib/email-link";

export function EmailConfirmClient() {
  const initialized = useRef(false);
  const submitting = useRef(false);
  const [link, setLink] = useState<EmailLink | null>(null);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [awaitingConfirmation, setAwaitingConfirmation] = useState(false);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    const parsed = parseEmailLink(window.location.hash);
    // Tokens are only in the fragment (never sent in the page request), then
    // removed from history before any auth request. Keep them only in memory.
    window.history.replaceState({}, "", "/auth/confirm");
    // The fragment is unavailable during SSR; capture it once after hydration.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setLink(parsed);
    setReady(true);
    if (!parsed) setError("This link is incomplete. Reopen the link from your email, or request a new one from sign in.");
  }, []);

  async function confirm() {
    if (!link || submitting.current) return;
    submitting.current = true;
    setBusy(true);
    setError(null);
    const result = await verifyEmailLink(createSupabaseBrowserClient().auth, link);
    if (result.destination) {
      window.location.replace(result.destination);
      return;
    }
    if (result.awaitingConfirmation) {
      setAwaitingConfirmation(true);
      setLink(null);
    } else setError(result.error || "This link could not be verified. Request a new email.");
    submitting.current = false;
    setBusy(false);
  }

  const recovery = link?.type === "recovery";
  return (
    <main className="email-confirm-page">
      <section className="email-confirm-card">
        <h1>{awaitingConfirmation ? "Email confirmation received" : recovery ? "Reset your password" : "Confirm your email link"}</h1>
        <p>{awaitingConfirmation
          ? "If FindEZ sent a confirmation to your other email address, open that link too. Then sign in using your updated email."
          : recovery ? "Continue to verify this link and choose a new password on this device."
          : "Continue to sign in to the FindEZ account that received this email."}</p>
        {error && <p role="alert">{error}</p>}
        {!ready && <p role="status">Checking your link...</p>}
        {link && !awaitingConfirmation && <button type="button" className="product-button primary" onClick={() => void confirm()} disabled={busy}>{busy ? "Verifying..." : recovery ? "Continue to reset password" : "Confirm and continue"}</button>}
        <Link href="/signin">{awaitingConfirmation ? "Go to sign in" : "Return to sign in"}</Link>
        {link && <small>Using the iPhone app? After completing this step, return to the app and sign in.</small>}
      </section>
    </main>
  );
}
