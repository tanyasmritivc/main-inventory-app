"use client";

import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";

export type OrganizationTarget = { organization_id: string; name: string };
function deleteError(reason: unknown): string {
  if (reason instanceof ApiError) {
    const messages = ["Only organizations with no workspaces can be deleted.", "The organization name changed. Reopen the confirmation.", "Only the organization owner can delete it.", "Organization not found.", "The organization is being updated. Try again."];
    if (typeof reason.limitData === "string" && messages.includes(reason.limitData)) return reason.limitData;
    return reason.message;
  }
  return userFacingError(reason, "The organization could not be deleted.");
}

export function OrganizationDeleteDialog({ accountId, organization, onClose, onDeleted }: {
  accountId: string; organization: OrganizationTarget; onClose: () => void; onDeleted: () => void;
}) {
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState(""), [busy, setBusy] = useState(false);
  const live = useRef(true), pending = useRef(false);
  useLayoutEffect(() => { live.current = true; return () => { live.current = false; }; }, []);
  async function remove(event: FormEvent) {
    event.preventDefault();
    if (pending.current || confirmation.trim() !== organization.name) return;
    pending.current = true; setBusy(true); setError("");
    try {
      const result = await accountRequest<{ deleted: boolean; organization_id: string }>(accountId, `/organizations/${encodeURIComponent(organization.organization_id)}`, { method: "DELETE", body: { name: confirmation.trim() } });
      if (!live.current) return;
      if (result.deleted !== true || result.organization_id !== organization.organization_id) { setError("Deletion could not be confirmed. Refresh before retrying."); return; }
      onDeleted();
    } catch (reason) { if (live.current) setError(deleteError(reason)); }
    finally { pending.current = false; if (live.current) setBusy(false); }
  }
  return <Dialog open onOpenChange={(open) => { if (!open && !pending.current) onClose(); }}>
    <DialogContent className="workspace-dialog inventory-creation-dialog">
      <DialogTitle>Delete organization</DialogTitle>
      <DialogDescription className="workspace-muted">Only an organization with no workspaces can be deleted. Its memberships and invitations are removed. This cannot be undone.</DialogDescription>
      <form onSubmit={remove}>
        <label>Type {organization.name} to confirm<input autoFocus autoComplete="off" className="product-input" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} /></label>
        {error && <p role="alert" className="notice-error">{error}</p>}
        <div className="product-actions"><button type="button" className="product-button" disabled={busy} onClick={onClose}>Cancel</button><button className="product-button organization-delete-submit" disabled={busy || confirmation.trim() !== organization.name}>{busy ? "Deleting..." : "Delete organization"}</button></div>
      </form>
    </DialogContent>
  </Dialog>;
}
