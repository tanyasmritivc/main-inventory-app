import { apiRequest } from "@/lib/api";
import { activeInventory, assertInventory } from "@/lib/inventory-selection";

export type CadLine = {
  key: string; name: string; part_number: string; manufacturer: string;
  required: number; assigned: number; missing: number; unit: string;
  status: "covered" | "short" | "missing" | "needs_review";
  match_type: "exact" | "probable" | "none";
  procurement_policy: string; possible_matches: number;
  matches: { item_id: string; name: string; location: string; assigned: number; evidence: string }[];
};
export type CadComparison = {
  inventory_id: string; extraction_id: string;
  document: { name: string; external_id: string };
  revision: { kind: string; id: string; dirty: boolean; configuration: string };
  inventory_as_of: string; completeness: "complete" | "partial"; warnings: string[];
  summary: { required_units: number; covered_units: number; coverage_percent: number | null; shortage_lines: number; review_lines: number };
  items: CadLine[];
};

export type BomField = "name" | "quantity" | "part_number" | "manufacturer" | "barcode" | "unit";
export type BomMapping = Partial<Record<BomField, number>>;
export type BomSheet = { name: string; headers: string[]; row_count: number; sample: string[][]; suggested_mapping: BomMapping };
export type BomPreview = { inventory_id: string; file_sha256: string; sheets: BomSheet[] };
export type BomOptions = { sheet: string; mapping: BomMapping; confirmed: boolean };

async function uploadBom<T extends { inventory_id: string }>(path: string, file: File, signal: AbortSignal, options?: BomOptions): Promise<T> {
  const inventory = activeInventory();
  if (!inventory) throw new Error("Choose an inventory first.");
  if (!/\.(json|csv|xlsx)$/i.test(file.name) || !file.size || file.size > 5 * 1024 * 1024)
    throw new Error("Choose a Fusion JSON, CSV or Excel (.xlsx) BOM smaller than 5 MiB.");
  const body = new FormData(); body.append("file", file);
  if (options) {
    body.append("sheet", options.sheet); body.append("mapping", JSON.stringify(options.mapping));
    body.append("flat_bom_confirmed", String(options.confirmed));
  }
  const result = await apiRequest<T>(path, { method: "POST", body, signal });
  assertInventory(inventory);
  if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed. Compare again.");
  return result;
}

export function previewBom(file: File, signal: AbortSignal): Promise<BomPreview> {
  return uploadBom<BomPreview>("/cad/preview", file, signal);
}

export function compareCad(file: File, signal: AbortSignal, options?: BomOptions): Promise<CadComparison> {
  return uploadBom<CadComparison>("/cad/compare", file, signal, options);
}

export function shortageCsv(result: CadComparison): string {
  function cell(value: string | number) {
    const text = String(value);
    const safe = /^[\s]*[=+\-@\t\r]/.test(text) ? "'" + text : text;
    return '"' + safe.replaceAll('"', '""') + '"';
  }
  const rows: (string | number)[][] = [["Component", "Manufacturer", "Part number", "Required", "Covered", "Missing", "Unit", "Status", "Revision", "Inventory checked at"]];
  for (const line of result.items.filter((line) => line.missing > 0))
    rows.push([line.name, line.manufacturer, line.part_number, line.required, line.assigned, line.missing, line.unit,
      line.status, result.revision.id, result.inventory_as_of]);
  return rows.map((row) => row.map(cell).join(",")).join("\r\n") + "\r\n";
}
