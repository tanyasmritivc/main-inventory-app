import { normalizeAuthNext, resolveAuthCallback } from "@/lib/auth-callback";

describe("OAuth callback", () => {
  it("preserves safe local destinations", () => {
    expect(normalizeAuthNext("/inventory?space=Shelf%20B")).toBe(
      "/inventory?space=Shelf%20B",
    );
  });

  it("defaults missing and external destinations to home", () => {
    expect(normalizeAuthNext(null)).toBe("/worlds");
    expect(normalizeAuthNext("https://attacker.example")).toBe("/worlds");
    expect(normalizeAuthNext("//attacker.example")).toBe("/worlds");
    expect(normalizeAuthNext("/\\attacker.example")).toBe("/worlds");
    expect(normalizeAuthNext("/\nattacker.example")).toBe("/worlds");
  });
});

describe("email link completion", () => {
  it("accepts only a confirmed session and normalizes the destination", async () => {
    const auth = {
      exchangeCodeForSession: jest
        .fn()
        .mockResolvedValue({
          data: { session: { user: { id: "synthetic" } } },
          error: null,
        }),
    };
    expect(
      await resolveAuthCallback(auth, "synthetic-code", "/reset-password"),
    ).toEqual({ destination: "/reset-password" });
    expect(
      await resolveAuthCallback(
        auth,
        "synthetic-code",
        "https://attacker.example",
      ),
    ).toEqual({ destination: "/worlds" });
  });
  it("explains a rejected or consumed token without using another existing session", async () => {
    const auth = { exchangeCodeForSession: jest.fn() };
    const result = await resolveAuthCallback(
      auth,
      null,
      "/home",
      "otp_expired",
    );
    expect(result.error).toContain("expired or has already been used");
    expect(result.destination).toBeUndefined();
    expect(auth.exchangeCodeForSession).not.toHaveBeenCalled();
  });
  it("rejects missing codes rather than assuming confirmation", async () => {
    const auth = { exchangeCodeForSession: jest.fn() };
    expect((await resolveAuthCallback(auth, null, "/home")).error).toContain(
      "incomplete",
    );
    expect(auth.exchangeCodeForSession).not.toHaveBeenCalled();
  });
  it("explains missing browser proof and handles network errors without signing in", async () => {
    const auth = {
      exchangeCodeForSession: jest
        .fn()
        .mockResolvedValue({
          data: { session: null },
          error: { code: "flow_state_not_found" },
        }),
    };
    expect(
      (await resolveAuthCallback(auth, "synthetic-code", "/home")).error,
    ).toContain("same browser");
    auth.exchangeCodeForSession.mockRejectedValue(new Error("offline"));
    expect(
      (await resolveAuthCallback(auth, "synthetic-code", "/home")).error,
    ).toContain("connection");
  });
});
