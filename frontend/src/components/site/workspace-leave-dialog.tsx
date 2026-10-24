"use client";
import { useEffect, useRef, useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
export function WorkspaceLeaveDialog({ accountId, workspace, onClose, onLeft }: {
  accountId: string; workspace: { workspace_id: string; name: string }; onClose: () => void; onLeft: () => void;
}) {
  const [busy, setBusy] = useState(false), [error, setError] = useState("");
  const pending = useRef(false), alive = useRef(true);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  async function leave() {
    if (pending.current) return;
    pending.current = true; setBusy(true); setError("");
    try {
      const result = await accountRequest<{left:boolean}>(accountId, `/teams/${encodeURIComponent(workspace.workspace_id)}/leave`, {method:"DELETE"});
      if (!alive.current) return;
      if (result.left !== true) throw new Error("Leaving could not be confirmed. Refresh your workspaces before trying again.");
      window.dispatchEvent(new Event("findez-permissions-changed")); onLeft();
    } catch (reason) { if (alive.current) setError(userFacingError(reason, "The workspace could not be left.")); }
    finally { pending.current = false; if (alive.current) setBusy(false); }
  }
  return <Dialog open onOpenChange={open => { if (!open && !pending.current) onClose(); }}>
    <DialogContent className="workspace-dialog">
      <DialogTitle>Leave {workspace.name}?</DialogTitle>
      <DialogDescription>Your workspace membership will be removed. Shared items, tasks and files stay with the team. You will need a new invitation to join again.</DialogDescription>
      {error && <p className="notice-error" role="alert">{error}</p>}
      <div className="product-actions"><button className="product-button" disabled={busy} onClick={onClose}>Cancel</button><button className="product-button" disabled={busy} onClick={()=>void leave()}>{busy ? "Leaving..." : "Leave workspace"}</button></div>
    </DialogContent>
  </Dialog>;
}
