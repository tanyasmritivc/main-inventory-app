export type ChatItemAction = {
  id: string;
  inventoryId: string;
  operation: "add" | "delete" | "edit" | "move" | "reorder";
  status: "pending" | "confirmed" | "cancelled";
  items: { name: string; quantity: number | null; location: string; details?:string[] }[];
};
const uuid = /^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$/i;
export function parseChatItemAction(value: unknown): ChatItemAction | undefined {
  if (!value || typeof value !== "object") return;
  const raw = value as Record<string, unknown>;
  if (typeof raw.id !== "string" || !uuid.test(raw.id) || typeof raw.inventory_id !== "string" || !uuid.test(raw.inventory_id)
    || !["add", "delete", "edit", "move", "reorder"].includes(String(raw.operation)) || !["pending", "confirmed", "cancelled"].includes(String(raw.status))
    || !Array.isArray(raw.items) || !raw.items.length || raw.items.length > 100) return;
  const items = [];
  for (const item of raw.items) {
    if (!item || typeof item !== "object" || typeof item.name !== "string" || !item.name.trim()
      || typeof item.location !== "string" || !item.location.trim()
      || (item.quantity !== null && (!Number.isSafeInteger(item.quantity) || item.quantity < 0))) return;
    items.push({ name: item.name.slice(0, 200), quantity: item.quantity as number | null, location: item.location.slice(0, 200), ...(Array.isArray(item.details) ? {details:item.details.filter((d:unknown):d is string=>typeof d==="string").slice(0,20)} : {}) });
  }
  return { id: raw.id, inventoryId: raw.inventory_id, operation: raw.operation as ChatItemAction["operation"], status: raw.status as ChatItemAction["status"], items };
}
