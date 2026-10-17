/** @jest-environment jsdom */
import { render, screen, within } from "@testing-library/react";
import { ItemDetails } from "@/components/site/item-details";
import { type InventoryItem } from "@/lib/api";
jest.mock("@/components/site/item-photo-gallery", () => ({ ItemPhotoGallery: () => null }));

test("saved import details retain exact labels, duplicate fields and structured values separately from live stock", () => {
  const item: InventoryItem = {
    item_id: "test", name: "Bolt", category: "Hardware", quantity: 7,
    location: "Cabinet", created_at: "2026-10-14",
    import_data: { filename: "parts.xlsx", sheet: "Sheet1", fields: [
      { name: "Screw Length", value: 12 }, { name: "Vendor Part #", value: "0012" },
      { name: "Size", value: "M2" }, { name: "Size", value: "12mm" },
      { name: "", value: false }, { name: "Quantity", value: 0 },
      { name: "Specs", value: { ports: ["A", "B"] } }, { name: "Empty column", value: null },
      { name: "HTML", value: "<script>bad()</script>" },
    ] },
  };
  const { container } = render(<ItemDetails item={item} canEdit={false} />);
  const imported = screen.getByRole("heading", { name: "Imported details" }).parentElement!;
  expect(within(imported).getByText("Screw Length")).toBeTruthy();
  expect(within(imported).getByText("Vendor Part #")).toBeTruthy();
  expect(within(imported).getByText("0012")).toBeTruthy();
  expect(within(imported).getAllByText("Size")).toHaveLength(2);
  expect(within(imported).getByText("Column 5")).toBeTruthy();
  expect(within(imported).getByText("false")).toBeTruthy();
  expect(within(imported).getByText("0")).toBeTruthy();
  expect(within(imported).getByText('{"ports":["A","B"]}')).toBeTruthy();
  expect(within(imported).getByText("Empty")).toBeTruthy();
  expect(container.querySelector("script")).toBeNull();
  expect(screen.getByText("7")).toBeTruthy();
});
