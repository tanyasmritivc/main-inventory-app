import { normalizeAuthNext } from "@/lib/auth-callback";

describe("OAuth callback", () => {
  it("preserves safe local destinations", () => {
    expect(normalizeAuthNext("/inventory?space=Shelf%20B")).toBe("/inventory?space=Shelf%20B");
  });

  it("defaults missing and external destinations to home", () => {
    expect(normalizeAuthNext(null)).toBe("/home");
    expect(normalizeAuthNext("https://attacker.example")).toBe("/home");
    expect(normalizeAuthNext("//attacker.example")).toBe("/home");
  });
});
