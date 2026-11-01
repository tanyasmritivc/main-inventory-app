import {
  addChatSource,
  sourcePayload,
  parseCapture,
  type ChatSource,
} from "@/lib/chat-sources";
test("references omit displayed names and cannot substitute stale inventory facts", () => {
  expect(
    sourcePayload({
      kind: "item",
      inventory_id: "inv",
      resource_id: "item",
      name: "old name",
    }),
  ).toEqual({ kind: "item", inventory_id: "inv", resource_id: "item" });
});
test("duplicate references are not added and file budgets are enforced", () => {
  const ref: ChatSource = {
    kind: "item",
    inventory_id: "i",
    resource_id: "x",
    name: "Drill",
  };
  expect(addChatSource([ref], ref)).toEqual([ref]);
  const files: ChatSource[] = Array.from({ length: 4 }, (_, i) => ({
    kind: "file",
    name: String(i),
    text: "x",
    truncated: false,
  }));
  expect(() =>
    addChatSource(files, {
      kind: "file",
      name: "5",
      text: "x",
      truncated: false,
    }),
  ).toThrow("4 files");
  expect(() =>
    addChatSource(
      [
        { kind: "file", name: "a", text: "x".repeat(24000), truncated: false },
        { kind: "file", name: "b", text: "x".repeat(24000), truncated: false },
      ],
      { kind: "file", name: "c", text: "x", truncated: false },
    ),
  ).toThrow("48,000");
});
test("saved captures require a valid receipt and reject negative quantities", () => {
  const draft = {
    id: "11111111-1111-4111-8111-111111111111",
    revision: 1,
    status: "draft",
    items: [
      {
        index: 0,
        selected: true,
        item: { name: "Bolt", category: "Parts", quantity: 1 },
      },
    ],
  };
  expect(parseCapture(draft)).toBeTruthy();
  expect(parseCapture({ ...draft, status: "saved" })).toBeUndefined();
  expect(
    parseCapture({
      ...draft,
      items: [
        { ...draft.items[0], item: { ...draft.items[0].item, quantity: -1 } },
      ],
    }),
  ).toBeUndefined();
  expect(
    parseCapture({
      ...draft,
      status: "saved",
      receipt: { saved_count: 1, review_count: 0, failures: [] },
    }),
  ).toBeTruthy();
});
