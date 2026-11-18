"use client";
import { Barcode, FileText, Eye, Activity, ShoppingCart, ArrowLeftRight, Tag } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { InventoryChatArchive } from "./inventory-chat-archive";
import styles from "./world-tools.module.css";
import { CommerceDashboardCard } from "./commerce-dashboard-card";

const tools = [
  ["Capture / Import", "Photos, barcodes and spreadsheets", "/scan"],
  ["Documents", "Files and notes", "/documents"],
  ["Review", "Check items before saving", "/review"],
  ["Activity", "Recent item changes", "/activity"],
  ["Restock", "Plan what to replenish", "/restock"],
  ["Check-outs", "Track borrowed items", "/checkout"],
  ["Labels", "Print and identify items", "/labels"],
] as const;
const toolIcons = [Barcode, FileText, Eye, Activity, ShoppingCart, ArrowLeftRight, Tag];
type Inventory = { inventory_id: string; name: string; workspace_name: string; can_edit: boolean; spaces?: { id: string; name: string }[] };
export function WorldTools({accountId, inventories, organizationId}: {accountId: string; inventories: Inventory[]; organizationId?: string}) {
  const [selected, setSelected] = useState("");
  const spaces = inventories.flatMap(i => (i.spaces || []).map(space => ({ ...space, inventory: i })));
  const space = spaces.find(s => s.id === selected) || spaces[0];
  const inventory = space?.inventory;
  if (!inventory) return <div className={styles.page}><CommerceDashboardCard organizationId={organizationId} /><p className={styles.empty}>Create a Space to use these tools.</p></div>;
  return <div className={styles.page}>
    <div className={styles.toolbar}>
      <label className={styles.selector}>Space
        <select value={space.id} onChange={e => setSelected(e.target.value)}>
          {spaces.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </label>
      {!inventory.can_edit && <small>View only</small>}
      <InventoryChatArchive key={inventory.inventory_id} accountId={accountId} inventoryId={inventory.inventory_id} name={space.name} />
    </div>
    <CommerceDashboardCard inventoryId={inventory.inventory_id} />
    <div className={styles.grid}>
      {tools.map(([label, detail, path], index) => { const Icon = toolIcons[index]; return <Link key={path} className={`${styles.card} theme-card`} href={`${path}?inventory=${encodeURIComponent(inventory.inventory_id)}&space=${encodeURIComponent(space.name)}`}>
        <span className="theme-tool-icon"><Icon size={18} aria-hidden="true" /></span><span><strong>{label}</strong><small>{detail}</small></span>
      </Link>; })}
    </div>
  </div>;
}
