import type { InventoryItem } from "@/lib/api";

// Supplier identifiers belong to imported details, never the purchase destination.
export function purchaseSource(item: Pick<InventoryItem, "purchase_source" | "import_data">): string | null {
  const value = item.purchase_source?.trim();
  if (!value || /^[\d\s.,+#-]+$/.test(value)) return null;
  const identifier = item.import_data?.fields?.some(field =>
    /^(vendor part (number|#)|supplier code)$/i.test(field.name.trim()) && String(field.value ?? "").trim() === value);
  return identifier ? null : value;
}
export function purchaseLink(value: string): string | null {
  try { const url = new URL(value); return ["https:", "http:"].includes(url.protocol) ? url.href : null; }
  catch { return null; }
}
