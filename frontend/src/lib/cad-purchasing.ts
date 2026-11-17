export type PurchaseQuote = {
  id: string; vendor: string; product_url: string; source_note: string; currency: string;
  quoted_at: string; valid_until: string; availability: string;
  estimate: { order_quantity: number; surplus_quantity: number; subtotal: string; unit_price: string };
};
export type PurchaseLine = {
  id: string; name: string; manufacturer: string; part_number: string; required: number;
  available: number; quantity: number; received: number; quotes: PurchaseQuote[];
  selected_quote: PurchaseQuote | null;
};
export type PurchaseSummary = { id: string; name: string; state: string; revision: number };
export type PurchasePlan = PurchaseSummary & {
  inventory_id: string; inventory_as_of: string; lines: PurchaseLine[];
  order_reference: string | null; totals: Record<string, string>;
};
export function purchaseCsv(plan: PurchasePlan) {
  const rows: (string | number)[][] = [["Vendor", "Component", "Manufacturer", "Part number", "Shortage", "Order quantity", "Received", "Currency", "Subtotal (excluding tax and shipping)", "Product link", "Order reference"]];
  const sorted = [...plan.lines].sort((a, b) => (a.selected_quote?.vendor || "").localeCompare(b.selected_quote?.vendor || ""));
  for (const line of sorted) {
    const quote = line.selected_quote;
    rows.push([quote?.vendor || "Unquoted", line.name, line.manufacturer, line.part_number, line.quantity,
      quote?.estimate.order_quantity || "", line.received, quote?.currency || "", quote?.estimate.subtotal || "",
      quote?.product_url || "", plan.order_reference || ""]);
  }
  return rows.map(row => row.map(value => {
    const text = String(value);
    return '"' + (/^\s*[=+\-@\t\r]/.test(text) ? "'" + text : text).replaceAll('"', '""') + '"';
  }).join(",")).join("\r\n") + "\r\n";
}
