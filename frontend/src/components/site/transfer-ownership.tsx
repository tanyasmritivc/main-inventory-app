"use client";
import { useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";

export function TransferOwnership({ scope, resourceId, name, onTransferred }: {
  scope: "organization" | "workspace"; resourceId: string; name: string; onTransferred: () => void;
}) {
  const { accountId } = useApiSession();
  const actor = useRef(accountId);
  useEffect(() => { actor.current = accountId; return () => { actor.current = null; }; }, [accountId]);
  const [open, setOpen] = useState(false), [busy, setBusy] = useState(false);
  const [members, setMembers] = useState<{user_id:string;display_name:string}[]>([]);
  const [target, setTarget] = useState(""), [confirmation, setConfirmation] = useState(""), [error, setError] = useState("");
  const base = scope === "organization" ? `/organizations/${resourceId}` : `/inventory-workspaces/${resourceId}`;
  useEffect(() => {
    if (!open || !accountId) return;
    let live = true;
    setTarget(""); setConfirmation(""); setMembers([]); setError("");
    void accountRequest<{members:typeof members}>(accountId, `${base}${scope === "workspace" ? "/overview" : ""}`)
      .then(result => { if (live) setMembers(result.members.filter(m => m.user_id !== accountId)); })
      .catch(reason => { if (live) setError(userFacingError(reason, "Members could not be loaded.")); });
    return () => { live = false; };
  }, [open, accountId, base, scope]);
  async function transfer(event: React.FormEvent) {
    event.preventDefault();
    if (!accountId || busy || !target || confirmation !== name) return;
    setBusy(true); setError("");
    try {
      const result = await accountRequest<{transferred:boolean;scope:string;resource_id:string;owner_user_id:string}>(accountId, `${base}/transfer-owner`, {
        method:"POST", body:{user_id:target,name:confirmation,confirmed:true},
      });
      if (result.transferred !== true || result.scope !== scope || result.resource_id !== resourceId || result.owner_user_id !== target) throw new Error("The transfer could not be confirmed. Refresh before retrying.");
      if (actor.current !== accountId) return;
      window.dispatchEvent(new Event("findez-permissions-changed"));
      setOpen(false); onTransferred();
    } catch (reason) { if (actor.current === accountId) setError(userFacingError(reason, "Ownership could not be transferred.")); }
    finally { if (actor.current === accountId) setBusy(false); }
  }
  return <>
    <button className="product-button" onClick={() => setOpen(true)}>Transfer ownership</button>
    <Dialog open={open} onOpenChange={value => { if (!busy) setOpen(value); }}><DialogContent>
      <DialogTitle>Transfer {scope} ownership</DialogTitle>
      <DialogDescription>The selected member becomes Owner and you become Admin. Restricted inventory access stays unchanged.</DialogDescription>
      <form onSubmit={event => void transfer(event)} className="collaboration-form">
        <label>New owner<select required className="product-select" value={target} onChange={event => setTarget(event.target.value)} disabled={busy}>
          <option value="">Choose a current member</option>{members.map(member => <option key={member.user_id} value={member.user_id}>{member.display_name}</option>)}
        </select></label>
        <label>Type {name} to confirm<input className="product-input" value={confirmation} onChange={event => setConfirmation(event.target.value)} autoComplete="off" disabled={busy} /></label>
        {error && <p role="alert" className="notice-error">{error}</p>}
        <div className="product-actions"><button type="button" className="product-button" disabled={busy} onClick={() => setOpen(false)}>Cancel</button><button className="product-button" disabled={busy || !target || confirmation !== name}>{busy ? "Transferring..." : "Confirm transfer"}</button></div>
      </form>
    </DialogContent></Dialog>
  </>;
}
