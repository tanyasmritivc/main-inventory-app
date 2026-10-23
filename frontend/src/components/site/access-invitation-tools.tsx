"use client";
import { useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { type AccessInvitation, type InvitationDelivery, invitationRole } from "@/lib/access-invitation";
import { userFacingError } from "@/lib/user-facing-error";

export function InvitationDeliveryDetails({ delivery }: { delivery: InvitationDelivery }) {
  return <div className="invitation-delivery" role="status">
    <p>{delivery.email_sent ? "Invitation sent. Access starts after acceptance." : "Invitation saved, but the email could not be sent. Share the link or code."}</p>
    <label>Invitation link<input className="product-input" readOnly value={delivery.invite_url} onFocus={(e) => e.currentTarget.select()} /></label>
    <p>Code: <code>{delivery.code}</code></p>
    <small className="workspace-muted">Only the invited email account can accept. Expires in 7 days.</small>
  </div>;
}

export function PendingInvitations({ scope, resourceId, revision = 0 }: { scope: AccessInvitation["scope"]; resourceId: string; revision?: number }) {
  const { accountId } = useApiSession();
  return <Pending key={`${accountId}:${scope}:${resourceId}`} scope={scope} resourceId={resourceId} revision={revision} />;
}
function Pending({ scope, resourceId, revision }: { scope: AccessInvitation["scope"]; resourceId: string; revision: number }) {
  const { accountId } = useApiSession();
  const [rows, setRows] = useState<AccessInvitation[]>([]), [error, setError] = useState("");
  const [reload, setReload] = useState(0), [busy, setBusy] = useState(false);
  const live = useRef(true);
  useEffect(() => { live.current = true; return () => { live.current = false; }; }, []);
  useEffect(() => {
    if (!accountId) return;
    let active = true;
    void accountRequest<{ invitations: AccessInvitation[] }>(accountId, `/access-invitations?scope=${scope}&resource_id=${encodeURIComponent(resourceId)}`).then((result) => {
      if (active) { if (!Array.isArray(result.invitations)) throw new Error("Invitations could not be loaded."); setRows(result.invitations); setError(""); }
    }).catch((reason) => { if (active) setError(userFacingError(reason, "Invitations could not be loaded.")); });
    return () => { active = false; };
  }, [accountId, scope, resourceId, revision, reload]);
  async function cancel(id: string) {
    if (!accountId || busy) return;
    setBusy(true); setError("");
    try {
      await accountRequest(accountId, `/access-invitations/${id}/decision`, { method: "POST", body: { action: "cancel" } });
      if (live.current) setReload((v) => v + 1);
    } catch (reason) { if (live.current) setError(userFacingError(reason, "The invitation could not be cancelled.")); }
    finally { if (live.current) setBusy(false); }
  }
  return <>
    {error && <p className="notice-error" role="alert">{error} <button className="product-button" onClick={() => setReload((v) => v + 1)}>Retry invitations</button></p>}
    {!!rows.length && <section className="pending-invitations"><h2>Pending invitations</h2>{rows.map((row) => <div className="context-person" key={row.invitation_id}>
      <div><strong>{row.recipient_email}</strong><small className="workspace-muted">{invitationRole(row.role)} | Expires {new Date(row.expires_at).toLocaleDateString()}</small></div>
      <button className="product-button" disabled={busy} aria-label={`Cancel invitation for ${row.recipient_email}`} onClick={() => void cancel(row.invitation_id)}>Cancel invitation</button>
    </div>)}</section>}
  </>;
}
