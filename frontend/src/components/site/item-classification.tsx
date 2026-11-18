"use client";
import { useState } from "react";
import { intelligenceRequest, inventoryRoles, type InventoryRole } from "@/lib/inventory-intelligence";
import { userFacingError } from "@/lib/user-facing-error";
export function ItemClassification({ itemId, role, canEdit, onChanged }: {
  itemId: string; role: InventoryRole; canEdit: boolean; onChanged: (role: InventoryRole) => void;
}) {
  const [chosen, setChosen] = useState(role);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  async function save() {
    setBusy(true); setMessage("");
    try {
      const result = await intelligenceRequest<{ inventory_role: InventoryRole }>(`/items/${encodeURIComponent(itemId)}/classification`, { method: "PUT", body: { role: chosen } });
      onChanged(result.inventory_role); setMessage("Classification saved. Stock alert settings are unchanged.");
    } catch (reason) { setMessage(userFacingError(reason, "Classification could not be saved.")); }
    finally { setBusy(false); }
  }
  return <section style={{ marginBlock: 24 }}>
    <label htmlFor={`classification-${itemId}`}>Inventory classification</label>
    <div className="workspace-actions" style={{ marginTop: 8 }}><select className="product-input" id={`classification-${itemId}`} value={chosen} onChange={event => setChosen(event.target.value as InventoryRole)} disabled={!canEdit || busy}>
      {Object.entries(inventoryRoles).map(([value, label]) => <option value={value} key={value}>{label}</option>)}
    </select>{canEdit && <button className="workspace-button" disabled={busy || chosen === role} onClick={() => void save()}>{busy ? "Saving..." : "Save classification"}</button>}</div>
    <p className="workspace-muted" style={{ fontSize: 13 }}>What this item is used for. Low-stock alerts require your chosen minimum in Restock.</p>
    {message && <p role="status">{message}</p>}
  </section>;
}
