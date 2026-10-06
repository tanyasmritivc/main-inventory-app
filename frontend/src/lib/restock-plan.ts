export type RestockEntry = {
  minimum?: number;
  buy_quantity?: number;
  ordered?: boolean;
  order_quantity?: number;
  receipt_total?: number;
};
export type RestockPlan = Record<string, RestockEntry>;
export const restockKey = (account: string) => `findez-restock-v1:${account}`;
export const RESTOCK_EVENT = "findez-restock-changed";
export function decodeRestock(raw: string | null): RestockPlan {
  if (raw === null) return {};
  const decoded: unknown = JSON.parse(raw);
  if (!decoded || typeof decoded !== "object" || Array.isArray(decoded))
    throw new Error(
      "Your saved restock plan could not be read. It has been preserved.",
    );
  const result: RestockPlan = {};
  for (const [id, value] of Object.entries(decoded)) {
    if (!id || !value || typeof value !== "object" || Array.isArray(value))
      throw new Error(
        "Your saved restock plan could not be read. It has been preserved.",
      );
    const entry: RestockEntry = {};
    for (const field of [
      "minimum",
      "buy_quantity",
      "order_quantity",
      "receipt_total",
    ] as const) {
      const n = (value as RestockEntry)[field];
      if (n === undefined) continue;
      if (
        !Number.isSafeInteger(n) ||
        n < (field === "buy_quantity" || field === "order_quantity" ? 1 : 0)
      )
        throw new Error(
          "Your saved restock plan contains an invalid count. It has been preserved.",
        );
      entry[field] = n;
    }
    const ordered = (value as RestockEntry).ordered;
    if (ordered !== undefined && typeof ordered !== "boolean")
      throw new Error(
        "Your saved restock plan contains an invalid order. It has been preserved.",
      );
    if (ordered) entry.ordered = true;
    result[id] = entry;
  }
  return result;
}
export function needsBuying(entry: RestockEntry | undefined, quantity: number) {
  return (
    !!entry &&
    !entry.ordered &&
    entry.receipt_total === undefined &&
    (entry.buy_quantity !== undefined ||
      (entry.minimum !== undefined && quantity <= entry.minimum))
  );
}
export function onOrder(entry: RestockEntry | undefined) {
  return (
    !!entry && (entry.ordered === true || entry.receipt_total !== undefined)
  );
}
export function quantityToBuy(entry: RestockEntry, quantity: number) {
  return (
    entry.buy_quantity ??
    Math.min(100000, Math.max(1, (entry.minimum ?? 0) + 1 - quantity))
  );
}
export function changeRestock(
  storage: Pick<Storage, "getItem" | "setItem">,
  account: string,
  id: string,
  update: (entry: RestockEntry) => RestockEntry,
): RestockPlan {
  const key = restockKey(account),
    plan = decodeRestock(storage.getItem(key));
  const entry = update(plan[id] ?? {}),
    next = { ...plan };
  if (Object.values(entry).some((v) => v !== undefined && v !== false))
    next[id] = entry;
  else delete next[id];
  const encoded = JSON.stringify(next);
  decodeRestock(encoded); // Never persist a count the planner cannot read back.
  storage.setItem(key, encoded); // Only publish after storage succeeds.
  return next;
}
export function confirmedReceipt(
  item: { item_id: string; quantity: number } | undefined,
  id: string,
  total: number,
) {
  return item?.item_id === id && item.quantity === total;
}

// Persist an absolute total before writing stock. A lost response retries the
// same count rather than adding the delivery twice.
export async function recordRestockArrival({
  id,
  total,
  read,
  change,
  write,
}: {
  id: string;
  total: number;
  read: () => RestockEntry;
  change: (
    id: string,
    update: (entry: RestockEntry) => RestockEntry,
  ) => Promise<void>;
  write: (
    quantity: number,
  ) => Promise<{ item: { item_id: string; quantity: number } }>;
}) {
  if (!Number.isSafeInteger(total) || total < 0)
    throw new Error("Enter a whole stock count.");
  const receipt = read().receipt_total ?? total;
  await change(id, (entry) => ({ ...entry, receipt_total: receipt }));
  const result = await write(receipt);
  if (!confirmedReceipt(result.item, id, receipt))
    throw new Error(
      "The stock count was not confirmed. Retry this arrival to confirm the same total.",
    );
  await change(id, (entry) => ({ minimum: entry.minimum }));
  return result;
}
