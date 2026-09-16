"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { ApiError, getJoinedShares, getMyShares, joinShare, joinTeam } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";

export function JoinInvitationClient({ code, kind }: { code: string; kind: "space" | "team" }) {
  const router = useRouter();
  const { token, loading } = useApiSession();
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState<string | null>(null);
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
    <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24, background: "#101512", color: "#f5f5f2" }}>
      <section style={{ width: "100%", maxWidth: 430, padding: "36px 32px", border: "1px solid #29362e", borderRadius: 12, background: "#171e19" }}>
        <Link href="/" style={{ color: "#f5f5f2", textDecoration: "none", fontWeight: 700 }}>FindEZ</Link>
        <h1 style={{ margin: "34px 0 8px", fontSize: 28, letterSpacing: "-.04em" }}>{title}</h1>
        <p style={{ margin: "0 0 25px", color: "#a8b3aa", lineHeight: 1.5 }}>Use this link to join on the web. You can open the same inventory on your phone after signing in.</p>
        <div style={{ marginBottom: 22, color: "#a8b3aa", fontSize: 12 }}>Invitation code <strong style={{ display: "block", marginTop: 6, color: "#f5f5f2", fontSize: 20, letterSpacing: ".16em" }}>{code || "Invalid code"}</strong></div>
        {!code ? <p role="alert" style={{ color: "#e9a49a" }}>This invitation link is incomplete. Ask the owner to share a new one.</p> : loading ? <p>Checking your session…</p> : token ? (
          <button type="button" onClick={() => void accept()} disabled={joining} style={{ width: "100%", padding: "12px 16px", border: 0, borderRadius: 7, background: "#315a43", color: "#fff", font: "inherit", fontWeight: 650, cursor: joining ? "wait" : "pointer" }}>{joining ? "Joining…" : `Join ${kind}`}</button>
        ) : <Link href={`/signin?redirect=${encodeURIComponent(invitationPath)}`} style={{ display: "block", padding: "12px 16px", borderRadius: 7, background: "#315a43", color: "#fff", textAlign: "center", textDecoration: "none", fontWeight: 650 }}>Sign in to join</Link>}
        {error && <p role="alert" style={{ marginTop: 14, color: "#e9a49a", lineHeight: 1.5 }}>{error}</p>}
        {kind === "team" && code && <a href={`findez://team-invite?code=${encodeURIComponent(code)}`} style={{ display: "inline-block", marginTop: 18, color: "#becfc2", fontSize: 13 }}>Open in iPhone app</a>}
      </section>
    </main>
  );
}
