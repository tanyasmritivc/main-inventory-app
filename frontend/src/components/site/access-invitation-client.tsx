"use client";
import Link from "next/link";
import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { type AccessInvitation, invitationRole } from "@/lib/access-invitation";
import { requireInventoryContext, selectInventory } from "@/lib/inventory-selection";
import { publishNotificationSnapshot } from "@/lib/notification-state";
import { userFacingError } from "@/lib/user-facing-error";
import { AppThemeProvider } from "@/components/site/use-app-theme";

export function AccessInvitationClient({ code = "", invitationId = "" }: { code?: string; invitationId?: string }) {
  const { accountId } = useApiSession();
  return <AppThemeProvider><Review key={`${accountId}:${code}:${invitationId}`} initialCode={code} invitationId={invitationId} /></AppThemeProvider>;
}
function Review({ initialCode, invitationId }: { initialCode: string; invitationId: string }) {
  const { accountId, loading, error: sessionError } = useApiSession(), router = useRouter();
  const [code, setCode] = useState(initialCode), [invitation, setInvitation] = useState<AccessInvitation | null>(null);
  const [error, setError] = useState(""), [busy, setBusy] = useState(false);
  const live = useRef(true), generation = useRef(0);
  useLayoutEffect(() => { requireInventoryContext(false); selectInventory(null); }, []);
  useEffect(() => { live.current = true; return () => { live.current = false; }; }, []);
  const lookup = invitationId ? { invitation_id: invitationId } : { code: code.toUpperCase() };
  const path = `/join/access?${invitationId ? `invitation=${encodeURIComponent(invitationId)}` : `code=${encodeURIComponent(code.toUpperCase())}`}`;
  useEffect(() => {
    if (!accountId || (!initialCode && !invitationId)) return;
    let active = true;
    setBusy(true);
    void accountRequest<{ invitation: AccessInvitation }>(accountId, "/access-invitations/preview", { method: "POST", body: invitationId ? { invitation_id: invitationId } : { code: initialCode.toUpperCase() } }).then((result) => {
      if (active) setInvitation(result.invitation);
    }).catch((reason) => { if (active) setError(invitationError(reason)); }).finally(() => { if (active) setBusy(false); });
    return () => { active = false; };
  }, [accountId, initialCode, invitationId]);
  function invitationError(reason: unknown) {
    if (reason instanceof ApiError && reason.status === 403) return "Use the account whose confirmed email received this invitation. The sender must still have permission to invite you.";
    return userFacingError(reason, "This invitation is unavailable. Ask the sender for a new link or code.");
  }
  async function review(event: FormEvent) {
    event.preventDefault(); if (busy) return;
    if (!accountId) { router.push(`/signin?redirect=${encodeURIComponent(path)}`); return; }
    const ticket = ++generation.current;
    setBusy(true); setError(""); setInvitation(null);
    try {
      const result = await accountRequest<{ invitation: AccessInvitation }>(accountId, "/access-invitations/preview", { method: "POST", body: lookup });
      if (live.current && ticket === generation.current) setInvitation(result.invitation);
    } catch (reason) { if (live.current && ticket === generation.current) setError(invitationError(reason)); }
    finally { if (live.current && ticket === generation.current) setBusy(false); }
  }
  async function decide(action: "accept" | "decline") {
    if (!accountId || !invitation || busy) return;
    setBusy(true); setError("");
    try {
      const result = await accountRequest<{ invitation: AccessInvitation }>(accountId, `/access-invitations/${invitation.invitation_id}/decision`, { method: "POST", body: { action } });
      if (live.current) { setInvitation(result.invitation); publishNotificationSnapshot(accountId, null); }
    } catch (reason) { if (live.current) setError(invitationError(reason)); }
    finally { if (live.current) setBusy(false); }
  }
  const expired = invitation && new Date(invitation.expires_at).getTime() <= Date.now();
  return <main className="invitation-review"><section>
    <Link className="invitation-brand" href="/">FindEZ</Link>
    <h1>{invitation ? invitation.name : "Review invitation"}</h1>
    {invitation ? <>
      <p>{invitation.scope.charAt(0).toUpperCase() + invitation.scope.slice(1)} | {invitationRole(invitation.role)}</p>
      {invitation.invited_by_name && <p className="workspace-muted">Invited by {invitation.invited_by_name}</p>}
      {invitation.status === "pending" && !expired ? <>
        <p className="workspace-muted">You choose whether to join. Access starts only after you accept.</p>
        <div className="product-actions"><button className="product-button" disabled={busy} onClick={() => void decide("decline")}>Decline</button><button className="product-button" disabled={busy} onClick={() => void decide("accept")}>Accept invitation</button></div>
      </> : <p role="status">{expired && invitation.status === "pending" ? "This invitation has expired. Ask the sender for a new one." : `Invitation ${invitation.status}.`}</p>}
      {invitation.status === "accepted" && <Link className="product-button" href={invitation.destination}>Open {invitation.scope}</Link>}
    </> : <>
      <p className="workspace-muted">Sign in with the invited email, then review the requested access.</p>
      <form onSubmit={(event) => void review(event)}><label>Invitation code<input className="product-input" autoComplete="off" autoCapitalize="characters" maxLength={12} value={code} disabled={busy || !!invitationId} onChange={(e) => setCode(e.target.value.replace(/[^a-z2-9]/gi, "").toUpperCase())} /></label>
        <button className="product-button" disabled={busy || loading || (!invitationId && code.length !== 12)}>{busy ? "Checking..." : "Review invitation"}</button>
      </form>
      {!loading && !accountId && <Link href={`/signin?redirect=${encodeURIComponent(path)}`}>Sign in</Link>}
    </>}
    {(error || sessionError) && <p className="notice-error" role="alert">{error || sessionError}</p>}
    {busy && <span className="sr-only" role="status">Please wait...</span>}
  </section></main>;
}
