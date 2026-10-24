import { continuePreview, previewAuthDestination, previewPrompt } from "@/lib/landing-preview";

test("prompt data is bounded and never becomes a navigation target", () => {
  expect(previewPrompt(["x"])).toBe("");
  expect(previewPrompt("x".repeat(5000))).toHaveLength(2000);
  const prompt = '<script>alert(1)</script> & /?q=redirect';
  const url = new URL(continuePreview("/home?inventory=owned-id", prompt), "https://findez.ai");
  expect(url.pathname).toBe("/assist");
  expect(url.searchParams.get("q")).toBe(prompt);
  expect(url.searchParams.get("inventory")).toBe("owned-id");
});
test("signup keeps prompt through onboarding; signin skips setup; consent keeps precedence", () => {
  expect(previewAuthDestination("/onboarding", "Add 10 screws", true)).toBe("/onboarding?prompt=Add+10+screws");
  expect(previewAuthDestination("/home", "Add 10 screws", false)).toBe("/assist?q=Add+10+screws");
  for (const next of ["/join?token=invitation", "/reset-password", "/auth/callback"]) {
    expect(previewAuthDestination(next, "Add 10 screws", true)).toBe(next);
  }
  expect(continuePreview("/home", "")).toBe("/home");
});
