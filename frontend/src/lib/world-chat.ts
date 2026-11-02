export type WorldResource = {
  kind: "item" | "space" | "inventory" | "project";
  id: string;
  inventory_id: string;
  label: string;
  href: string;
};
export type WorldAction = {
  id: string;
  status: "pending" | "confirmed" | "cancelled";
  workspace_label: string;
  inventories: {
    name: string;
    spaces: string[];
    items: { name: string; quantity: number; location: string }[];
    moves: { name: string; target_location: string }[];
  }[];
};
const uuid = /^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$/i;
const record = (v: unknown): Record<string, unknown> | undefined =>
  v !== null && typeof v === "object" && !Array.isArray(v)
    ? (v as Record<string, unknown>)
    : undefined;
export function parseWorldResource(value: unknown): WorldResource | undefined {
  const v = record(value);
  if (
    !v ||
    !["item", "space", "inventory", "project"].includes(String(v.kind)) ||
    typeof v.id !== "string" ||
    !uuid.test(v.id) ||
    typeof v.inventory_id !== "string" ||
    !uuid.test(v.inventory_id) ||
    typeof v.label !== "string" ||
    !v.label.trim() ||
    v.href !== `findez://${v.kind}/${v.inventory_id}/${v.id}`
  )
    return;
  return { ...v, label: v.label.slice(0, 200) } as WorldResource;
}
export function parseWorldAction(value: unknown): WorldAction | undefined {
  const v = record(value),
    plan = record(v?.plan);
  if (
    !v ||
    typeof v.id !== "string" ||
    !uuid.test(v.id) ||
    !["pending", "confirmed", "cancelled"].includes(String(v.status)) ||
    !plan ||
    !Array.isArray(plan.inventories) ||
    !plan.inventories.length ||
    plan.inventories.length > 30
  )
    return;
  const inventories: WorldAction["inventories"] = [];
  for (const entry of plan.inventories) {
    const i = record(entry);
    if (
      !i ||
      typeof i.name !== "string" ||
      !i.name.trim() ||
      !Array.isArray(i.spaces) ||
      i.spaces.some((s) => typeof s !== "string")
    )
      return;
    const items: WorldAction["inventories"][number]["items"] = [],
      moves: WorldAction["inventories"][number]["moves"] = [];
    if (
      (i.items !== undefined && !Array.isArray(i.items)) ||
      (i.moves !== undefined && !Array.isArray(i.moves))
    )
      return;
    for (const raw of (i.items || []) as unknown[]) {
      const item = record(raw);
      if (
        !item ||
        typeof item.name !== "string" ||
        typeof item.location !== "string" ||
        typeof item.quantity !== "number" ||
        !Number.isSafeInteger(item.quantity) ||
        item.quantity < 0
      )
        return;
      items.push({
        name: item.name,
        quantity: item.quantity,
        location: item.location,
      });
    }
    for (const raw of (i.moves || []) as unknown[]) {
      const move = record(raw);
      if (
        !move ||
        typeof move.name !== "string" ||
        typeof move.target_location !== "string"
      )
        return;
      moves.push({ name: move.name, target_location: move.target_location });
    }
    inventories.push({
      name: i.name,
      spaces: i.spaces as string[],
      items,
      moves,
    });
  }
  return {
    id: v.id,
    status: v.status as WorldAction["status"],
    workspace_label:
      typeof v.workspace_label === "string"
        ? v.workspace_label
        : typeof plan.workspace_name === "string"
          ? plan.workspace_name
          : "Workspace",
    inventories,
  };
}
export function resolvedWorldHref(link: WorldResource, value: unknown): string {
  const v = record(value),
    resource = record(v?.resource);
  if (
    !v ||
    v.kind !== link.kind ||
    v.inventory_id !== link.inventory_id ||
    !resource
  )
    throw new Error("This destination could not be verified.");
  const query = new URLSearchParams({ inventory: link.inventory_id });
  if (link.kind === "item") {
    if (resource.item_id !== link.id)
      throw new Error("This item could not be verified.");
    query.set("item", link.id);
  }
  if (link.kind === "space") {
    if (resource.id !== link.id || typeof resource.name !== "string")
      throw new Error("This Space could not be verified.");
    query.set("space", resource.name);
  }
  if (link.kind === "inventory" && resource.inventory_id !== link.id)
    throw new Error("This inventory could not be verified.");
  if (link.kind === "project") {
    if (resource.id !== link.id)
      throw new Error("This project could not be verified.");
    query.set("kit", link.id);
  }
  return `${link.kind === "project" ? "/project-kits" : "/inventory"}?${query}`;
}
