import { itemNeedsCleanup } from "@/lib/inventory-quality";

describe("inventory cleanup classification", () => {
  test.each([
    "unknown",
    "Unknown object",
    "Unidentified item",
    "scan button",
    "white foam padding",
    "unknown metal object",
  ])("flags known junk label %s", (name) => {
    expect(itemNeedsCleanup({ name })).toBe(true);
  });

  test.each([
    "M4 x 30 socket screw",
    "EL-001 USB-C to USB-A Cable 6ft",
    "608ZZ bearing",
  ])("keeps useful inventory label %s", (name) => {
    expect(itemNeedsCleanup({ name })).toBe(false);
  });
});
