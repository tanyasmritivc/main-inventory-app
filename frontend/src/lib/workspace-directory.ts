export type DirectoryInventory = {
  inventory_id: string; workspace_id: string; name: string; description?: string;
  can_open?: boolean; can_edit?: boolean; can_manage?: boolean; can_rename?: boolean;
  directory_visibility?: "workspace" | "hidden"; item_count?: number;
};
export function directoryInventoryHref(inventory: DirectoryInventory) {
  if (inventory.can_open === false && inventory.can_manage) return `/inventory-access?inventory=${encodeURIComponent(inventory.inventory_id)}`;
  return inventory.can_open === false ? `/inventory-access-request/${encodeURIComponent(inventory.inventory_id)}` : `/inventory?inventory=${encodeURIComponent(inventory.inventory_id)}`;
}
