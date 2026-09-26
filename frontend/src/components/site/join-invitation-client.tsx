"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { ApiError, getJoinedShares, getMyShares, joinShare, joinTeam } from "@/lib/api";
import { APP_STORE_URL, invitationAppSchemeLink, isIosDevice } from "@/lib/app-store";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";

function openUrl(url: string) {
  window.location.assign(url);
}

/**
 * Reaching this page on iOS means the Universal Link did not open the app, which
 * usually means FindEZ is not installed. Send the visitor to the App Store once per
 * invitation; a later visit shows the page so an installed app can still be opened
 * with the custom-scheme fallback instead of looping back to the store.
 */
function claimAppStoreRedirect(kind: string, code: string): boolean {
  const key = `findez:invite-app-store:${kind}:${code}`;
  try {
    if (window.localStorage.getItem(key)) return false;
    window.localStorage.setItem(key, new Date().toISOString());
    return true;
  } catch {
    return false;
  }
}

export function JoinInvitationClient({ code, kind, navigate = openUrl }: {
  code: string;
  kind: "space" | "team";
  navigate?: (url: string) => void;
}) {
  const router = useRouter();
  const { token, loading } = useApiSession();
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ios, setIos] = useState(false);

  useEffect(() => {
    const onIos = isIosDevice(navigator.userAgent, navigator.maxTouchPoints);
    setIos(onIos);
    if (onIos && code && claimAppStoreRedirect(kind, code)) navigate(APP_STORE_URL);
  }, [code, kind, navigate]);
  const invitationPath = kind === "team" ? `/join/team/${code}` : `/join/${code}`;
  const title = kind === "team" ? "Join a FindEZ team" : "Join a shared Space";

  async function accept() {
    if (!token || joining) return;
    setJoining(true);
    setError(null);
    try {
      if (kind === "team") {
        await joinTeam({ token, code });
        router.replace("/teams");
      } else {
        const share = await joinShare({ token, share_code: code });
        router.replace(`/sharing/${encodeURIComponent(share.share_id)}`);
      }
    } catch (reason) {
      const message = reason instanceof ApiError
        ? `${reason.message} ${String(reason.limitData)}`.toLowerCase()
        : reason instanceof Error ? reason.message.toLowerCase() : "";
      if (kind === "team" && message.includes("already a member")) {
        router.replace("/teams");
        return;
      }
      if (kind === "space" && (message.includes("already a member") || message.includes("already have access") || message.includes("already own"))) {
        try {
          const [joined, owned] = await Promise.all([getJoinedShares({ token }), getMyShares({ token })]);
          const match = [...joined.shares, ...owned.shares].find((share) => share.share_code?.toUpperCase() === code);
          if (match) { router.replace(`/sharing/${encodeURIComponent(match.share_id)}`); return; }
        } catch { /* Keep the original join error visible if lookup fails. */ }
      }
      setError(userFacingError(reason, "This invitation could not be accepted. Ask the owner for a current link."));
    } finally {
      setJoining(false);
    }
  }

  return (
    <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24, background: "var(--light-page)", color: "var(--text-primary)" }}>
      <section style={{ width: "100%", maxWidth: 430, padding: "36px 32px", border: "1px solid var(--light-line)", borderRadius: 12, background: "var(--light-panel)" }}>
        <Link href="/" style={{ color: "var(--text-primary)", textDecoration: "none", fontWeight: 700 }}>FindEZ</Link>
        <h1 style={{ margin: "34px 0 8px", fontSize: 28, letterSpacing: "-.04em" }}>{title}</h1>
        <p style={{ margin: "0 0 25px", color: "var(--light-muted)", lineHeight: 1.5 }}>Use this link to join on the web. You can open the same inventory on your phone after signing in.</p>
        <div style={{ marginBottom: 22, color: "var(--light-muted)", fontSize: 12 }}>Invitation code <strong style={{ display: "block", marginTop: 6, color: "var(--text-primary)", fontSize: 20, letterSpacing: ".16em" }}>{code || "Invalid code"}</strong></div>
        {!code ? <p role="alert" style={{ color: "var(--danger-ink)" }}>This invitation link is incomplete. Ask the owner to share a new one.</p> : loading ? <p>Checking your session…</p> : token ? (
          <button type="button" onClick={() => void accept()} disabled={joining} style={{ width: "100%", padding: "12px 16px", border: 0, borderRadius: 7, background: "var(--copper)", color: "var(--text-primary)", font: "inherit", fontWeight: 650, cursor: joining ? "wait" : "pointer" }}>{joining ? "Joining…" : `Join ${kind}`}</button>
        ) : <Link href={`/signin?redirect=${encodeURIComponent(invitationPath)}`} style={{ display: "block", padding: "12px 16px", borderRadius: 7, background: "var(--copper)", color: "var(--text-primary)", textAlign: "center", textDecoration: "none", fontWeight: 650 }}>Sign in to join</Link>}
        {error && <p role="alert" style={{ marginTop: 14, color: "var(--danger-ink)", lineHeight: 1.5 }}>{error}</p>}
        {ios && code && (
          <div style={{ marginTop: 22, paddingTop: 18, borderTop: "1px solid var(--light-line)" }}>
            <a href={APP_STORE_URL} style={{ display: "block", padding: "12px 16px", borderRadius: 7, border: "1px solid var(--light-line)", color: "var(--text-primary)", textAlign: "center", textDecoration: "none", fontWeight: 650 }}>Get FindEZ on the App Store</a>
            <p style={{ margin: "12px 0 0", color: "var(--light-muted)", fontSize: 13, lineHeight: 1.5 }}>After installing, open your invitation email and tap the link again to join in the app.</p>
            <a href={invitationAppSchemeLink(kind, code)} style={{ display: "inline-block", marginTop: 12, color: "var(--copper)", fontSize: 13 }}>Already have FindEZ? Open in app</a>
          </div>
        )}
        {!ios && kind === "team" && code && <a href={invitationAppSchemeLink("team", code)} style={{ display: "inline-block", marginTop: 18, color: "var(--copper)", fontSize: 13 }}>Open in iPhone app</a>}
      </section>
    </main>
  );
}
