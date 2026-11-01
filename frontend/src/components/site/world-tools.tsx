"use client";
import Link from "next/link";
import { useState } from "react";
import { InventoryChatArchive } from "./inventory-chat-archive";
import styles from "./world-tools.module.css";

const tools = [
  ["Capture / Import", "Photos, barcodes and spreadsheets", "/scan"],
  ["Documents", "Files for your inventory", "/documents"],
  ["Review", "Check items before saving", "/review"],
  ["Activity", "Recent inventory changes", "/activity"],
  ["Restock", "Plan what to replenish", "/restock"],
  ["Check-outs", "Track borrowed items", "/checkout"],
  ["Project kits", "Parts for your next project", "/project-kits"],
  ["Collections", "Organize saved items", "/collections"],
  ["Labels", "Print and identify items", "/labels"],
  ["Inventory settings", "Access and preferences", "/inventory-access"],
] as const;
type Inventory = { inventory_id: string; name: string; workspace_name: string; can_edit: boolean };
export function WorldTools({accountId, inventories}: {accountId: string; inventories: Inventory[]}) {
  const [selected, setSelected] = useState("");
  const inventory = inventories.find(i => i.inventory_id === selected) || inventories[0];
  if (!inventory) return <p className={styles.empty}>Create an inventory to use these tools.</p>;
  return <div className={styles.page}>
    <div className={styles.toolbar}>
      <label className={styles.selector}>Inventory
        <select value={inventory.inventory_id} onChange={e => setSelected(e.target.value)}>
          {inventories.map(i => <option key={i.inventory_id} value={i.inventory_id}>{i.workspace_name} / {i.name}</option>)}
        </select>
      </label>
      {!inventory.can_edit && <small>View only</small>}
      <InventoryChatArchive key={inventory.inventory_id} accountId={accountId} inventoryId={inventory.inventory_id} name={inventory.name} />
    </div>
    <div className={styles.grid}>
      {tools.map(([label, detail, path]) => <Link key={path} className={styles.card} href={`${path}?inventory=${encodeURIComponent(inventory.inventory_id)}`}>
        <span><strong>{label}</strong><small>{detail}</small></span>
      </Link>)}
    </div>
  </div>;
}
