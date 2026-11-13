"use client";
import { useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { DirectSpreadsheetImport } from "./direct-spreadsheet-import";
type Destination = {inventoryId: string; spaceId: string; name: string};
type Inventory = {inventory_id: string; name: string; can_edit: boolean; spaces: {id: string; name: string}[]};
type Props = { file: File; accountId: string; worldId: string; onClose: () => void };
export function WorldSpreadsheetImport(props: Props) {
  return <ScopedSpreadsheetImport key={`${props.accountId}:${props.worldId}`} {...props} />;
}
function ScopedSpreadsheetImport({file, accountId, worldId, onClose}: Props) {
  const active = useRef(false);
  const [inventories, setInventories] = useState<Inventory[]>();
  const [destination, setDestination] = useState<Destination>();
  const [error, setError] = useState("");
  useEffect(() => {
    active.current = true;
    let current = true;
    const prefix = `/worlds/${encodeURIComponent(worldId)}`;
    void Promise.all([
      accountRequest<{world: string; inventories: {inventory_id: string; can_edit: boolean}[]}>(accountId, `${prefix}/directory`),
      accountRequest<{inventories: Inventory[]}>(accountId, `${prefix}/spaces`),
    ]).then(([directory, groups]) => {
      if (!current) return;
      if (directory.world !== worldId) throw new Error("The organization could not be verified. Reopen this import.");
      const allowed = new Set(directory.inventories.filter(i => i.can_edit).map(i => i.inventory_id));
      setInventories(groups.inventories.filter(i => i.can_edit && allowed.has(i.inventory_id)));
    }).catch(e => {if (current) setError(userFacingError(e, "Could not load Spaces."));});
    return () => {current = false; active.current = false;};
  }, [accountId, worldId]);
  return <Dialog open onOpenChange={open => {if (!open) onClose();}}><DialogContent>
    <DialogTitle>Import spreadsheet</DialogTitle>
    <DialogDescription>{destination ? `Save to ${destination.name}` : "Choose a Space for your items."}</DialogDescription>
    {error && <p role="alert">{error}</p>}
    {!destination && <div>{!inventories && !error && <p role="status">Loading Spaces...</p>}
      {inventories?.map(i => <section key={i.inventory_id}><h3>{i.name}</h3>{i.spaces.map(s =>
        <button className="button-secondary" key={s.id} onClick={() => setDestination({inventoryId: i.inventory_id, spaceId: s.id, name: s.name})}>{s.name}</button>)}</section>)}
      {inventories && !inventories.some(i => i.spaces.length) && <p>Create a Space before importing.</p>}
    </div>}
    {destination && <DirectSpreadsheetImport initialFile={file} spaceName={destination.name} spaceId={destination.spaceId}
      request={async (path, body) => {
        if (!active.current) throw new Error("The organization changed. Reopen this import.");
        const result = await accountRequest(accountId, `/inventories/${encodeURIComponent(destination.inventoryId)}${path}`, {method: "POST", body});
        if (!active.current) throw new Error("The organization changed. Reopen this import.");
        return result;
      }}
      onSuccess={() => window.dispatchEvent(new Event("findez-inventory-changed"))}/>}
  </DialogContent></Dialog>;
}
