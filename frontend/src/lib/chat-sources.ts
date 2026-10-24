export type ChatSource =
  | {
      kind: "space" | "item" | "project" | "document";
      inventory_id: string;
      resource_id: string;
      name: string;
    }
  | { kind: "file"; name: string; text: string; truncated: boolean };
export function sourcePayload(s: ChatSource) {
  return s.kind === "file"
    ? s
    : {
        kind: s.kind,
        inventory_id: s.inventory_id,
        resource_id: s.resource_id,
      };
}
export function sourceKey(s: ChatSource) {
  return s.kind === "file"
    ? `file:${s.name}:${s.text}`
    : `${s.kind}:${s.inventory_id}:${s.resource_id}`;
}
export function addChatSource(
  current: ChatSource[],
  source: ChatSource,
): ChatSource[] {
  if (current.some((s) => sourceKey(s) === sourceKey(source))) return current;
  if (current.length >= 8) throw new Error("Use up to 8 sources per message.");
  const files = [...current, source].filter((s) => s.kind === "file");
  if (files.length > 4 || files.reduce((n, s) => n + s.text.length, 0) > 48000)
    throw new Error(
      "Use up to 4 files and 48,000 characters together. Remove a file first.",
    );
  return [...current, source];
}
export type CaptureRow = {
  index: number;
  selected: boolean;
  item: {
    name: string;
    category: string;
    quantity: number;
    brand?: string;
    part_number?: string;
    notes?: string;
    scan_evidence?: { needs_review?: boolean; review_reasons?: string[] };
  };
};
export type ChatCapture = {
  id: string;
  revision: number;
  status: "draft" | "saving" | "saved";
  items: CaptureRow[];
  inventory_id?: string;
  space_id?: string;
  destination_label?: string;
  location?: string;
  source_kind?: string;
  receipt?: {
    saved_count: number;
    review_count: number;
    failures: { index: number; reason?: string; error?: string }[];
  };
};
export function parseCapture(value: unknown): ChatCapture | undefined {
  if (!value || typeof value !== "object") return;
  const r = value as ChatCapture;
  if (
    typeof r.id !== "string" ||
    !/^[a-f0-9-]{36}$/i.test(r.id) ||
    !Number.isSafeInteger(r.revision) ||
    r.revision < 1 ||
    !["draft", "saving", "saved"].includes(r.status) ||
    !Array.isArray(r.items) ||
    r.items.length > 10000
  )
    return;
  if (
    r.items.some(
      (v, i) =>
        v.index !== i ||
        typeof v.selected !== "boolean" ||
        !v.item ||
        typeof v.item.name !== "string" ||
        typeof v.item.category !== "string" ||
        !Number.isInteger(v.item.quantity) ||
        v.item.quantity < 0,
    )
  )
    return;
  if (
    r.receipt &&
    (!Number.isInteger(r.receipt.saved_count) ||
      r.receipt.saved_count < 0 ||
      !Number.isInteger(r.receipt.review_count) ||
      r.receipt.review_count < 0 ||
      !Array.isArray(r.receipt.failures))
  )
    return;
  if (r.status === "saved" && (!r.receipt || r.receipt.failures.length)) return;
  return r;
}
