import { normalizeAuthNext } from "@/lib/auth-callback";

describe("OAuth callback", () => {
  it("preserves safe local destinations", () => {
    expect(normalizeAuthNext("/inventory?space=Shelf%20B")).toBe("/inventory?space=Shelf%20B");
  });

  it("defaults missing and external destinations to inventory", () => {
    expect(normalizeAuthNext(null)).toBe("/inventory");
    expect(normalizeAuthNext("https://attacker.example")).toBe("/inventory");
    expect(normalizeAuthNext("//attacker.example")).toBe("/inventory");
  });
});
