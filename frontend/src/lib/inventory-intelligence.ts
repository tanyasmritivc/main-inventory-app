import { accountRequest, accountToken } from "@/lib/account-request";
import { apiBase, type ApiRequestOptions } from "@/lib/api";
import { activeInventory, assertInventory } from "@/lib/inventory-selection";

export const intelligenceEnabled = process.env.NEXT_PUBLIC_INVENTORY_INTELLIGENCE === "true";
export const inventoryRoles = {
  personal_asset: "Personal asset", consumable: "Consumable", replenishable_supply: "Replenishable supply",
  equipment: "Equipment", retail_stock: "Retail stock", raw_material: "Raw material", unclassified: "Unclassified",
} as const;
export type InventoryRole = keyof typeof inventoryRoles;
export type Suggestion = {
  id: string; item_id: string; name: string; kind: "image" | "classification";
  status: string; due_at: string; has_preview: boolean;
  result: { role?: InventoryRole; confidence?: string; reason?: string; source_url?: string; product_name?: string; match_basis?: string };
};
export type EnrichmentReview = {
  items: Suggestion[]; next_offset: number | null; can_edit: boolean;
  settings: { timezone: string; images_enabled: boolean };
};
export async function intelligenceRequest<T>(path: string, options: ApiRequestOptions = {}) {
  const scope = activeInventory();
  if (!scope) throw new Error("Choose an inventory first.");
  const result = await accountRequest<T>(scope.accountId, `/inventories/${encodeURIComponent(scope.inventory_id)}/enrichment${path}`, options);
  assertInventory(scope);
  return result;
}
export async function suggestionPhoto(id: string, signal: AbortSignal) {
  const scope = activeInventory();
  if (!scope) throw new Error("Choose an inventory first.");
  const token = await accountToken(scope.accountId);
  assertInventory(scope);
  const response = await fetch(`${apiBase()}/inventories/${encodeURIComponent(scope.inventory_id)}/enrichment/${encodeURIComponent(id)}/image`, {
    headers: { Authorization: `Bearer ${token}` }, signal, cache: "no-store",
  });
  if (!response.ok) throw new Error("This photo is unavailable. Refresh the suggestions.");
  const blob = await response.blob();
  await accountToken(scope.accountId);
  assertInventory(scope);
  return blob;
}
export function configuredLowStock(item: { quantity: number; reorder_enabled?: boolean; reorder_threshold?: number | null }) {
  return item.reorder_enabled === true && Number.isFinite(item.quantity) && item.quantity >= 0 &&
    typeof item.reorder_threshold === "number" && Number.isFinite(item.reorder_threshold) && item.quantity <= item.reorder_threshold;
}
