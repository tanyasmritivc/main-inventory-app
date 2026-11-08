"use client";
import { useEffect, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { DirectSpreadsheetImport } from "./direct-spreadsheet-import";
type Destination = {inventoryId: string; spaceId: string; name: string};
type Inventory = {inventory_id: string; name: string; can_edit: boolean; spaces: {id: string; name: string}[]};
export function WorldSpreadsheetImport({file, accountId, worldId, onClose}: {
  file: File; accountId: string; worldId: string; onClose: () => void;
}) {
  const [inventories, setInventories] = useState<Inventory[]>();
  const [destination, setDestination] = useState<Destination>();
  const [error, setError] = useState("");
  useEffect(() => {
    let active = true;
    void accountRequest<{inventories: Inventory[]}>(accountId, `/worlds/${encodeURIComponent(worldId)}/spaces`)
      .then(r => {if (active) setInventories(r.inventories.filter(i => i.can_edit));})
      .catch(e => {if (active) setError(userFacingError(e, "Could not load Spaces."));});
    return () => {active = false;};
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
      request={(path, body) => accountRequest(accountId, `/inventories/${encodeURIComponent(destination.inventoryId)}${path}`, {method: "POST", body})}
      onSuccess={() => window.dispatchEvent(new Event("findez-inventory-changed"))}/>}
  </DialogContent></Dialog>;
}
