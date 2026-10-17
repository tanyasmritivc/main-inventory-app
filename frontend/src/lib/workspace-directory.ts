export type DirectoryInventory = {
  inventory_id: string; workspace_id: string; name: string; description?: string;
  can_open?: boolean; can_edit?: boolean; can_manage?: boolean; can_rename?: boolean;
  directory_visibility?: "workspace" | "hidden"; item_count?: number;
};
export function directoryInventoryHref(inventory: DirectoryInventory) {
  return inventory.can_open === false ? `/inventory-access-request/${encodeURIComponent(inventory.inventory_id)}` : `/home?inventory=${encodeURIComponent(inventory.inventory_id)}`;
}
