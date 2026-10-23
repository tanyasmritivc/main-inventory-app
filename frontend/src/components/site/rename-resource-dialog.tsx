"use client";

import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";

export type RenameTarget = { kind: "organization" | "workspace"; id: string; name: string };

export function RenameResourceDialog({ accountId, target, onClose, onSaved }: {
  accountId: string; target: RenameTarget; onClose: () => void; onSaved: (name: string) => void;
}) {
  const [name, setName] = useState(target.name), [error, setError] = useState("");
  const [busy, setBusy] = useState(false), live = useRef(true), pending = useRef(false);
  useLayoutEffect(() => { live.current = true; return () => { live.current = false; }; }, []);
  async function save(event: FormEvent) {
    event.preventDefault();
    if (pending.current || !name.trim()) return;
    pending.current = true; setBusy(true); setError("");
    try {
      const base = target.kind === "organization" ? "organizations" : "inventory-workspaces";
      const result = await accountRequest<Partial<Record<RenameTarget["kind"], { name: string }>>>(accountId, `/${base}/${encodeURIComponent(target.id)}`, { method: "PATCH", body: { name: name.trim() } });
      if (!live.current) return;
      const saved = result[target.kind]?.name;
      if (!saved) throw new Error("The name could not be confirmed saved. Refresh before retrying.");
      onSaved(saved);
    } catch (reason) { if (live.current) setError(userFacingError(reason, "The name could not be saved.")); }
    finally { pending.current = false; if (live.current) setBusy(false); }
  }
  return <Dialog open onOpenChange={(open) => { if (!open && !pending.current) onClose(); }}>
    <DialogContent className="workspace-dialog inventory-creation-dialog" aria-describedby={undefined}>
      <DialogTitle>Rename {target.kind}</DialogTitle>
      <form onSubmit={save}>
        <label>Name<input className="product-input" autoFocus required maxLength={100} value={name} onChange={(event) => setName(event.target.value)} /></label>
        {error && <p className="notice-error" role="alert">{error}</p>}
        <div className="product-actions"><button type="button" className="product-button" disabled={busy} onClick={onClose}>Cancel</button><button className="product-button" disabled={busy || !name.trim()}>{busy ? "Saving..." : "Save"}</button></div>
      </form>
    </DialogContent>
  </Dialog>;
}
