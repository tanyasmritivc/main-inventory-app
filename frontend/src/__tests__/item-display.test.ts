import { itemDisplayDescription, itemDisplayName } from "@/lib/api";

describe("inventory item display hierarchy", () => {
  it("uses the part number as the primary label", () => {
    const item = {
      name: "Washer for 14mm Bearing with 8mm REX shaft",
      part_number: "PN-F280",
    };

    expect(itemDisplayName(item)).toBe("PN-F280");
    expect(itemDisplayDescription(item)).toBe(
      "Washer for 14mm Bearing with 8mm REX shaft",
    );
  });

  it("falls back to the item name when no part number exists", () => {
    const item = {
      name: "Unnumbered washer",
      part_number: null,
    };

    expect(itemDisplayName(item)).toBe("Unnumbered washer");
    expect(itemDisplayDescription(item)).toBeNull();
  });
});
