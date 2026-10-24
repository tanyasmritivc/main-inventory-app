import { buildLandingPreview, continuePreview, previewAuthDestination, previewPrompt } from "@/lib/landing-preview";

test("explicit item quantities are kept separate from illustrative suggestions", () => {
  const result = buildLandingPreview("Add 10 AA batteries and 2 USB-C cables to my storage");
  expect(result.space).toBe("storage");
  expect(result.items).toEqual([
    { name: "AA batteries", quantity: 10, source: "prompt" },
    { name: "USB-C cables", quantity: 2, source: "prompt" },
  ]);
});
test("broad requests get labeled examples without invented stock counts", () => {
  const result = buildLandingPreview("Create an inventory called My workshop with a space for tools");
  expect(result.title).toBe("My workshop");
  expect(result.items.length).toBeGreaterThan(0);
  expect(result.items.every(item => item.source === "example" && item.quantity === null)).toBe(true);
});
test("search requests cannot imply that private inventory was queried", () => {
  const result = buildLandingPreview("Where are my 10 AA batteries?");
  expect(result.intent).toBe("find");
  expect(result.note).toContain("Sign in to search your actual inventory");
  expect(result.items.every(item => item.source === "example")).toBe(true);
});
test("unknown prompts remain intact without guessed items", () => {
  const result = buildLandingPreview("Please organize my collection of antique maps");
  expect(result.items).toEqual([]);
  expect(result.prompt).toBe("Please organize my collection of antique maps");
});
test("invalid counts and model numbers are not converted to valid stock", () => {
  expect(buildLandingPreview("Add -3 motors and 1.5 boards and 9007199254740992 screws").items.every(item => item.quantity === null)).toBe(true);
  expect(buildLandingPreview("Add M3 screws and 18V batteries").items.every(item => item.source === "example")).toBe(true);
  expect(buildLandingPreview("Add 0 motors").items[0].quantity).toBe(0);
});
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


test("named Spaces and inventories stay distinct and multiline quantities survive", () => {
  const result = buildLandingPreview('Create an inventory called Chat QA with a Storage space and add 10 AA batteries\n2 USB-C cables');
  expect(result.title).toBe("Chat QA");
  expect(result.space).toBe("Storage");
  expect(result.items.map(item => item.quantity)).toEqual([10, 2]);
  const space = buildLandingPreview('Create a space called Travel kit and add a flashlight and an umbrella');
  expect(space.space).toBe("Travel kit");
  expect(space.items.map(item => item.quantity)).toEqual([1, 1]);
});
