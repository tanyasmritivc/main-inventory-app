"use client";
import { useEffect, useState } from "react";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import type { Space } from "@/lib/api";
import { activeInventory, type AppInventory } from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";

export function MoveSpaceInventory({ space, onClose, onMoved }: { space: Space; onClose: () => void; onMoved: () => void }) {
  const source = activeInventory();
  const [query,setQuery] = useState("");
  const [inventories,setInventories] = useState<AppInventory[]>([]);
  const [target,setTarget] = useState("");
  const [busy,setBusy] = useState(false), [error,setError] = useState("");
  useEffect(() => {
    if (!source) return;
    let live = true;
    const timer = setTimeout(() => {
      void accountRequest<{ inventories: AppInventory[] }>(source.accountId, `/inventory-workspaces/${encodeURIComponent(source.workspace.workspace_id)}/inventories?q=${encodeURIComponent(query)}`)
        .then((result) => { if(live) setInventories(result.inventories.filter((inventory) => inventory.inventory_id !== source.inventory_id)); })
        .catch((reason) => { if(live) setError(userFacingError(reason,"Could not load inventories.")); });
    },query ? 180 : 0);
    return () => { live=false; clearTimeout(timer); };
  },[source,query]);
  async function move() {
    if (!source || !target) return;
    setBusy(true); setError("");
    try {
      await accountRequest(source.accountId, `/inventories/${encodeURIComponent(source.inventory_id)}/spaces/${encodeURIComponent(space.id)}/move`, { method:"POST", body:{ inventory_id:target } });
      onMoved();
    } catch(reason) { setError(userFacingError(reason,"This Space could not be moved.")); }
    finally { setBusy(false); }
  }
  return <Dialog open onOpenChange={(open) => { if(!open && !busy) onClose(); }}><DialogContent className="workspace-dialog inventory-creation-dialog" aria-describedby={undefined}>
    <DialogTitle>Move {space.name}</DialogTitle>
    <p>Its items, photos and linked records move together.</p>
    <form onSubmit={(event) => { event.preventDefault(); void move(); }}>
      <label>Search inventories<input type="search" className="product-input" value={query} onChange={(event) => { setQuery(event.target.value); setTarget(""); }} /></label>
      <label>Destination<select className="product-select" required value={target} onChange={(event) => setTarget(event.target.value)}><option value="">Choose inventory</option>{inventories.map((inventory) => <option key={inventory.inventory_id} value={inventory.inventory_id}>{inventory.name}</option>)}</select></label>
      {error && <p role="alert" className="notice-error">{error}</p>}
      <button className="product-button" disabled={busy || !target}>{busy ? "Moving..." : "Move Space"}</button>
    </form>
  </DialogContent></Dialog>;
}
