"use client";
import Link from "next/link";
import { invitationAppSchemeLink, isIosDevice } from "@/lib/app-store";
import { invitationHandoff, INVITATION_METADATA_KEY } from "@/lib/invitation";
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
  const { accountId, loading, error: sessionError, supabase } = useApiSession(), router = useRouter();
  const [code, setCode] = useState(initialCode), [invitation, setInvitation] = useState<AccessInvitation | null>(null);
  const [ios, setIos] = useState(false);
  const [saved, setSaved] = useState(false);
  useEffect(() => { setIos(isIosDevice(navigator.userAgent, navigator.maxTouchPoints)); }, []);
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
      const confirmed = result.invitation;
      if (confirmed.invitation_id !== invitation.invitation_id || confirmed.scope !== invitation.scope || confirmed.resource_id !== invitation.resource_id || confirmed.status !== (action === "accept" ? "accepted" : "declined")) throw new Error("Decision could not be confirmed. Refresh the invitation before retrying.");
      if (live.current) { setInvitation(confirmed); publishNotificationSnapshot(accountId, null); }
    } catch (reason) { if (live.current) setError(invitationError(reason)); }
    finally { if (live.current) setBusy(false); }
  }
  async function saveForApp() {
    if (!accountId || !invitation || busy) return;
    setBusy(true); setError("");
    try {
      const handoff = invitationHandoff(path);
      if (!handoff) throw new Error("Keep this link and reopen it in FindEZ.");
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (sessionError || data.session?.user.id !== accountId) throw new Error("Your account changed. Sign in again to save this invitation.");
      const { error: saveError } = await supabase.auth.updateUser({ data: { [INVITATION_METADATA_KEY]: handoff } });
      if (saveError) throw saveError;
      const { data: current } = await supabase.auth.getSession();
      if (current.session?.user.id !== accountId) throw new Error("Your account changed. Save the invitation again.");
      if (live.current) setSaved(true);
    } catch (reason) { if (live.current) setError(userFacingError(reason, "Could not save the invitation. Keep this link and try again.")); }
    finally { if (live.current) setBusy(false); }
  }
  const validCode = /^[A-Z2-9]{12}$/.test(code);
  const destination = invitation ? invitation.scope === "organization" ? `/organizations/${encodeURIComponent(invitation.resource_id)}` : invitation.scope === "workspace" ? `/workspaces/${encodeURIComponent(invitation.resource_id)}` : `/home?inventory=${encodeURIComponent(invitation.resource_id)}` : "";
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
      {invitation.status === "accepted" && <Link className="product-button" href={destination}>Open {invitation.scope}</Link>}
    </> : <>
      <p className="workspace-muted">Sign in with the invited email, then review the requested access.</p>
      <form onSubmit={(event) => void review(event)}><label>Invitation code<input className="product-input" autoComplete="off" autoCapitalize="characters" maxLength={12} value={code} disabled={busy || !!invitationId} onChange={(e) => setCode(e.target.value.replace(/[^a-z2-9]/gi, "").toUpperCase())} /></label>
        <button className="product-button" disabled={busy || loading || (!invitationId && code.length !== 12)}>{busy ? "Checking..." : "Review invitation"}</button>
      </form>
      {!loading && !accountId && <Link href={`/signin?redirect=${encodeURIComponent(path)}`}>Sign in</Link>}
    </>}
    {ios && validCode && <div className="product-actions"><a className="product-button" href={invitationAppSchemeLink("access", code)}>Open in FindEZ</a></div>}
    {validCode && accountId && invitation && invitation.status === "pending" && !expired && <>
      <button className="product-button" disabled={busy} onClick={() => void saveForApp()}>Save invitation for app</button>
      {saved && <p role="status">Invitation saved. Open FindEZ and sign in to this same account to review it.</p>}
    </>}
    {!loading && !accountId && <p><Link href={`/signup?redirect=${encodeURIComponent(path)}`}>Create account with invited email</Link></p>}
    {(error || sessionError) && <p className="notice-error" role="alert">{error || sessionError}</p>}
    {busy && <span className="sr-only" role="status">Please wait...</span>}
  </section></main>;
}
