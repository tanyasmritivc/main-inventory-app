import type { InventoryItem } from "@/lib/api";

const cleanupNames = new Set([
  "unknown",
  "unknown object",
  "unidentified item",
  "added item",
  "scan button",
  "button",
  "findez",
  "low stock notification label",
  "low stock alert label",
  "aa battery label",
  "banana toast",
  "white plastic part",
  "white foam padding",
  "bubble wrap",
]);

export function itemNeedsCleanup(item: Pick<InventoryItem, "name">): boolean {
  const name = item.name.trim().toLowerCase();
  return cleanupNames.has(name) || name.startsWith("unknown ") || name.startsWith("unidentified ");
}
