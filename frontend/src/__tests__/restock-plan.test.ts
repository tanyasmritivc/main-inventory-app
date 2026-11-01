import {
  changeRestock,
  decodeRestock,
  needsBuying,
  onOrder,
  quantityToBuy,
  recordRestockArrival,
  restockKey,
  type RestockEntry,
} from "@/lib/restock-plan";
function memory() {
  const values = new Map<string, string>();
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => {
      values.set(key, value);
    },
  };
}
test("a single tool is not low stock until a minimum is set", () => {
  expect(needsBuying(undefined, 1)).toBe(false);
  expect(needsBuying({ minimum: 0 }, 1)).toBe(false);
  expect(needsBuying({ minimum: 1 }, 1)).toBe(true);
  expect(quantityToBuy({ minimum: 4 }, 2)).toBe(3);
});
test("orders and pending arrivals leave To buy until stock confirmation", () => {
  expect(needsBuying({ minimum: 9, ordered: true }, 0)).toBe(false);
  expect(onOrder({ receipt_total: 0 })).toBe(true);
  expect(needsBuying({ minimum: 9, receipt_total: 0 }, 0)).toBe(false);
});
test("account plans are isolated and corrupt plans cannot be overwritten", () => {
  const storage = memory();
  changeRestock(storage, "a", "i", () => ({ minimum: 0, buy_quantity: 2 }));
  expect(decodeRestock(storage.getItem(restockKey("b")))).toEqual({});
  storage.setItem(restockKey("a"), "{damaged");
  expect(() => changeRestock(storage, "a", "i", () => ({}))).toThrow();
  expect(storage.getItem(restockKey("a"))).toBe("{damaged");
});
test.each([
  { minimum: -1 },
  { buy_quantity: 0 },
  { receipt_total: 1.5 },
  { ordered: "yes" },
  { order_quantity: Number.MAX_SAFE_INTEGER + 1 },
])("rejects invalid stored counts/status: %p", (entry) =>
  expect(() => decodeRestock(JSON.stringify({ i: entry }))).toThrow(),
);
test("a failed storage write publishes no new plan", () => {
  const storage = {
    getItem: () => JSON.stringify({ i: { minimum: 2 } }),
    setItem: () => {
      throw new Error("quota");
    },
  };
  expect(() =>
    changeRestock(storage, "a", "i", () => ({ buy_quantity: 4 })),
  ).toThrow("quota");
  expect(decodeRestock(storage.getItem()).i).toEqual({ minimum: 2 });
});
test("a lost response retries the persisted absolute stock count and preserves the minimum", async () => {
  let entry: RestockEntry = { minimum: 1, ordered: true, order_quantity: 4 };
  const sequence: string[] = [];
  const change = async (
    _id: string,
    update: (e: RestockEntry) => RestockEntry,
  ) => {
    entry = update(entry);
    sequence.push(`saved:${entry.receipt_total}`);
  };
  const write = jest
    .fn()
    .mockImplementationOnce(async (total: number) => {
      sequence.push(`request:${total}`);
      throw new Error("lost response");
    })
    .mockImplementationOnce(async (total: number) => ({
      item: { item_id: "i", quantity: total },
    }));
  await expect(
    recordRestockArrival({
      id: "i",
      total: 6,
      read: () => entry,
      change,
      write,
    }),
  ).rejects.toThrow("lost response");
  expect(sequence).toEqual(["saved:6", "request:6"]);
  await recordRestockArrival({
    id: "i",
    total: 99,
    read: () => entry,
    change,
    write,
  });
  expect(write.mock.calls.map((call) => call[0])).toEqual([6, 6]);
  expect(entry).toEqual({ minimum: 1 });
});
test.each([
  { item_id: "other", quantity: 8 },
  { item_id: "i", quantity: 7 },
])("unconfirmed stock remains pending: %p", async (item) => {
  let entry: RestockEntry = { ordered: true };
  await expect(
    recordRestockArrival({
      id: "i",
      total: 8,
      read: () => entry,
      change: async (_id, update) => {
        entry = update(entry);
      },
      write: async () => ({ item }),
    }),
  ).rejects.toThrow("not confirmed");
  expect(entry.receipt_total).toBe(8);
  expect(entry.ordered).toBe(true);
});
test("stock is never written when receipt persistence fails", async () => {
  const write = jest.fn();
  await expect(
    recordRestockArrival({
      id: "i",
      total: 5,
      read: () => ({}),
      change: async () => {
        throw new Error("storage failed");
      },
      write,
    }),
  ).rejects.toThrow("storage failed");
  expect(write).not.toHaveBeenCalled();
});

import { joinedRestockScopes, stockWrite } from "@/lib/restock-scope";
test("Shared Space viewers can plan but cannot send a stock write", () => {
  const [scope] = joinedRestockScopes({
    shares: [
      {
        team_shares: {
          share_id: "s",
          share_name: "Garage",
          permission: "view",
        },
      },
    ],
  });
  expect(scope.canEdit).toBe(false);
  expect(() => stockWrite(scope, "i", 7)).toThrow("only an editor");
});
test("shared and team arrivals retain their authorization boundary", () => {
  expect(
    stockWrite(
      { key: "s", label: "Space", kind: "shared", shareId: "s", canEdit: true },
      "i",
      7,
    ),
  ).toEqual({ path: "/sharing/s/items/i", body: { quantity: 7 } });
  expect(
    stockWrite(
      {
        key: "t",
        label: "Team",
        kind: "team",
        teamId: "t",
        spaceId: "s",
        canEdit: true,
      },
      "i",
      7,
    ),
  ).toEqual({ path: "/teams/t/spaces/s/items/i", body: { quantity: 7 } });
});
