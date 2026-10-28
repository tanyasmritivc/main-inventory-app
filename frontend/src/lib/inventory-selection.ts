export type InventoryWorkspace = {
  workspace_id: string;
  owner_user_id?: string;
  organization_id?: string | null;
  organization_name?: string;
  organization_role?: "owner" | "admin" | "member" | null;
  name: string;
  kind: "personal" | "team";
  team_id: string | null;
  role: "owner" | "mentor" | "member" | "viewer";
};
export type AppInventory = {
  inventory_id: string;
  name: string;
  owner_user_id: string;
  team_id: string | null;
  is_default: boolean;
  can_rename?: boolean;
  item_count?: number;
};
export type InventorySelection = AppInventory & {
  accountId: string;
  workspace: InventoryWorkspace;
  can_edit: boolean;
  role?: "owner" | "admin" | "editor" | "viewer" | null;
  can_open?: boolean;
  can_manage?: boolean;
  can_delete_space?: boolean;
};

// Window-local and URL-selected: another tab cannot switch this tab's inventory.
// Object identity also invalidates in-flight results when switching away and back.
let selection: InventorySelection | null = null;
let contextRequired = false;
export function requireInventoryContext(required: boolean) { contextRequired = required; }
export const activeInventory = () => selection;
export const canEditInventory = () => selection?.can_edit ?? true;
export const canDeleteSpace = () => !selection || (selection.can_delete_space ?? ["owner", "admin"].includes(selection.role || ""));
export function permissionFingerprint(value: InventorySelection) {
  return JSON.stringify([value.accountId, value.inventory_id, value.role, value.can_open,
    value.can_edit, value.can_manage, value.can_rename, value.can_delete_space, value.name, value.workspace]);
}
export function selectInventory(value: InventorySelection | null) { selection = value; }
export function assertInventory(value: InventorySelection | null) {
  if (selection !== value) throw new Error("The inventory changed. Reopen this page and try again.");
}

const dataRoutes = /^\/(?:search_items|add_item|update_item|delete_item|items|inventory|spaces|bins|documents|activity|review-items|conversations|checkouts|project-kits|sharing|ai_command|ai_photo_question|ai_actions|ai_upload|extract_from_image|process_barcode|barcode_lookup|eezy|import|connectors)(?:[/?]|$)/;
export function inventoryApiPath(path: string, selected = selection) {
  if (contextRequired && !selected && dataRoutes.test(path)) throw new Error("Choose an inventory before opening this page.");
  return selected && dataRoutes.test(path) ? `/inventories/${selected.inventory_id}${path}` : path;
}
export function isInventoryPage(path: string) {
  return /^\/(?:home|scan|assist|inventory|inventory-access|spaces|documents|activity|review|restock|checkout|project-kits|collections|labels)(?:\/|$)/.test(path.split("?")[0]);
}
export function inventoryHref(href: string, selected = selection): string {
  if (!selected || !href.startsWith("/") || href.startsWith("//")) return href;
  const url = new URL(href, "https://findez.invalid");
  if (!isInventoryPage(url.pathname)) return href;
  url.searchParams.set("inventory", selected.inventory_id);
  return url.pathname + url.search + url.hash;
}

export function canRenameWorkspace(workspace: InventoryWorkspace) {
  return workspace.kind === "team" && ["owner", "mentor", "member"].includes(workspace.role);
}
export function canAdministerWorkspace(workspace: InventoryWorkspace, accountId: string) {
  return workspace.owner_user_id === accountId || ["owner", "admin"].includes(workspace.organization_role || "");
}

export function canDeleteWorkspace(workspace: InventoryWorkspace, accountId: string) {
  return workspace.kind === "team" && (["owner", "mentor"].includes(workspace.role) || canAdministerWorkspace(workspace, accountId));
}
