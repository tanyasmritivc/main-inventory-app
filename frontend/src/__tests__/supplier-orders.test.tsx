/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { SupplierOrders } from "@/components/site/supplier-orders";
import { worldNavigation } from "@/lib/world-navigation";
import { accountRequest } from "@/lib/account-request";
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
const api = accountRequest as jest.Mock;
const base = "/commerce/organizations/org/orders";
const stock = {
  item_id: "i",
  name: "M4 screws",
  space_name: "Fasteners",
  location: "Bin A",
  recorded_quantity: 65,
  part_number: "SKU",
};
const line = {
  id: "line",
  name: "M4 screws",
  sku: "SKU",
  supplier: "goBILDA",
  order_number: "123",
  line_key: "1",
  ordered: 100,
  received: 25,
  cancelled: 0,
  outstanding: 75,
  historical: false,
  recent_receipts: [],
};
const results = {
  can_manage: true,
  order_lines: [line],
  recorded_inventory: [stock],
  has_more: false,
};
const renderPage = () =>
  render(
    <SupplierOrders
      accountId="actor"
      world="org"
      spaces={[{ inventory_id: "inv", can_edit: true, name: "Fasteners" }]}
    />,
  );
beforeEach(() => api.mockReset());

test("Orders is an organization destination beside Spaces", () => {
  const entries = worldNavigation("org", "Team").items;
  const i = entries.findIndex((x) => x.label === "Spaces");
  expect(entries[i + 1]).toMatchObject({
    label: "Orders",
    route: "/worlds/org?view=orders",
  });
  expect(
    worldNavigation("personal", "Personal").items.some(
      (x) => x.label === "Orders",
    ),
  ).toBe(false);
});

test("the review uses original header positions, requires a separate confirmation, and sends the selected mapping", async () => {
  const table = {
    file: "parts.xlsx",
    sheet: "Parts",
    header: 1,
    suggestions: {},
    records: [
      { number: 1, cells: ["Product", "Qty", "Qty"] },
      { number: 2, cells: ["Screw", "2", "10"] },
    ],
  };
  const draft = {
    order: "O1",
    line: "L1",
    sku: "S12",
    name: "Screw",
    quantity: "2",
    pack: "1",
    status: "unknown",
    source_file: "parts.xlsx",
    source_sheet: "Parts",
    source_row: 2,
  };
  api.mockImplementation(async (_actor, path, options) => {
    if (path.startsWith(base + "?"))
      return {
        ...results,
        order_scope_id: "shelf",
        space_orders_supported: true,
      };
    if (path.endsWith("preview"))
      return {
        space_review: {
          duplicate: false,
          matches: [
            { ...stock, item_name: "M4 screw", name: "Screw", sku: "S12" },
          ],
        },
        digest: "test",
        tables: [table],
        documents: [],
        rows: [draft],
        assignments: JSON.parse(
          options.body.get("assignments") || '[{"header":1,"mapping":{}}]',
        ),
      };
    return { created: 1 };
  });
  render(
    <SupplierOrders
      accountId="actor"
      world="org"
      initialSpace="shelf"
      spaces={[
        {
          inventory_id: "inv",
          space_id: "shelf",
          name: "Fasteners",
          can_edit: true,
        },
      ]}
    />,
  );
  const input = (await screen.findByLabelText(
    "Order file",
  )) as HTMLInputElement;
  expect(input.accept).toBe(".csv,.xlsx,.json");
  fireEvent.change(input, {
    target: { files: [new File(["png"], "screen.png")] },
  });
  expect((await screen.findByRole("alert")).textContent).toMatch(/Excel/);
  expect(api.mock.calls.some((c) => c[1].endsWith("/preview"))).toBe(false);
  fireEvent.change(input, {
    target: { files: [new File(["test"], "parts.xlsx")] },
  });
  const submit = () => fireEvent.submit(input.closest("form")!);
  fireEvent.click(await screen.findByText("Adjust column mapping"));
  const select = await screen.findByLabelText("Quantity purchased column");
  expect((select as HTMLSelectElement).value).toBe("");
  fireEvent.change(select, { target: { value: "1" } });
  submit();
  await screen.findByDisplayValue("Screw");
  expect(api.mock.calls.some((c) => c[1].endsWith("/import"))).toBe(false);
  fireEvent.change(screen.getByLabelText("Supplier", { exact: true }), {
    target: { value: "goBILDA" },
  });
  submit();
  await screen.findByText("Imported 1 order line.");
  const call = api.mock.calls.find((c) => c[1].endsWith("/import"))!;
  expect(call[2].body.get("space_id")).toBe("shelf");
  expect(
    api.mock.calls
      .filter((c) => c[1].endsWith("/preview"))
      .every((c) => c[2].body.get("space_id") === "shelf"),
  ).toBe(true);
  expect(JSON.parse(call[2].body.get("assignments"))[0].mapping.quantity).toBe(
    1,
  );
  expect(JSON.parse(call[2].body.get("rows"))[0].quantity).toBe("2");
});

test("stock and order balances stay distinct and read-only members cannot receive", async () => {
  api.mockResolvedValue({ ...results, can_manage: false });
  renderPage();
  fireEvent.change(
    screen.getByPlaceholderText("Part name, SKU or order number"),
    { target: { value: "M4" } },
  );
  await waitFor(() =>
    expect(screen.getByText(/65 recorded in Fasteners/)).toBeTruthy(),
  );
  expect(
    screen.getByText(
      /100 ordered · 25 received or reconciled · 0 cancelled · 75 outstanding/,
    ),
  ).toBeTruthy();
  expect(screen.queryByRole("button", { name: "Import orders" })).toBeNull();
  expect(screen.queryByLabelText("Record an action")).toBeNull();
});

test("retrying a receipt preserves its request ID and canonical Space", async () => {
  const receipts: Record<string, unknown>[] = [];
  api.mockImplementation(async (_actor, path, options) => {
    if (path.startsWith(base + "?")) return results;
    if (path.includes("/items?")) return { items: [stock] };
    if (path.endsWith("/receipts")) {
      receipts.push(options.body);
      if (receipts.length === 1) throw Error("Connection interrupted");
      return {};
    }
    throw Error("Unexpected request");
  });
  render(
    <SupplierOrders
      accountId="actor"
      world="org"
      spaces={[
        {
          inventory_id: "inv",
          space_id: "shelf",
          name: "Fasteners",
          can_edit: true,
        },
      ]}
    />,
  );
  await screen.findByText("Source and receipts");
  fireEvent.click(screen.getByText("Source and receipts"));
  fireEvent.change(screen.getByLabelText("Destination Space"), {
    target: { value: "shelf" },
  });
  const option = await screen.findByRole("option", { name: /M4 screws/ });
  fireEvent.change(screen.getByLabelText("Confirm matching inventory record"), {
    target: { value: option.getAttribute("value") },
  });
  fireEvent.change(screen.getByLabelText("Units", { exact: true }), {
    target: { value: "25" },
  });
  fireEvent.click(screen.getByText("Confirm receipt"));
  await screen.findByText("Connection interrupted");
  fireEvent.click(screen.getByText("Confirm receipt"));
  await screen.findByText("Receipt saved and stock updated.");
  expect(receipts).toHaveLength(2);
  expect(receipts[0]).toEqual(receipts[1]);
  expect(receipts[0]).toMatchObject({
    inventory_id: "inv",
    space_id: "shelf",
    item_id: "i",
    action: "receive",
    quantity: 25,
    request_id: expect.any(String),
  });
});

test.each([true, false])(
  "a complete CSV chosen from Orders is imported once unless already recorded (duplicate=%s)",
  async (duplicate) => {
    const draft = {
      order: "A",
      line: "1",
      sku: "001",
      name: "Screw",
      quantity: "3",
      pack: "5",
      status: "ordered",
      source_file: "parts.csv",
      source_row: 2,
    };
    api.mockImplementation(async (_actor, path) => {
      if (path.endsWith("/preview"))
        return {
          tables: [],
          rows: [draft],
          assignments: [],
          digest: "csv",
          space_review: { duplicate, matches: [] },
        };
      if (path.endsWith("/import")) return { created: 1 };
      return results;
    });
    render(
      <SupplierOrders
        accountId="actor"
        world="org"
        spaces={[
          {
            inventory_id: "inventory",
            space_id: "shelf",
            name: "Fasteners",
            can_edit: true,
          },
        ]}
      />,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Import orders" }),
    );
    fireEvent.change(screen.getByRole("combobox", { name: "Destination Space" }), {
      target: { value: "shelf" },
    });
    fireEvent.change(screen.getByLabelText("Supplier", { exact: true }), {
      target: { value: "Supplier" },
    });
    const input = screen.getByLabelText("Order file");
    fireEvent.change(input, {
      target: { files: [new File(["z"], "parts.zip")] },
    });
    expect(await screen.findByRole("alert")).toBeTruthy();
    fireEvent.change(input, {
      target: { files: [new File(["Name,Qty\nScrew,3"], "parts.csv")] },
    });
    await screen.findByText(
      duplicate
        ? /This file is already in organization Orders/
        : "Imported 1 order line.",
    );
    expect(
      api.mock.calls.filter((c) => c[1].endsWith("/preview")),
    ).toHaveLength(1);
    expect(api.mock.calls.filter((c) => c[1].endsWith("/import"))).toHaveLength(
      duplicate ? 0 : 1,
    );
  },
);
