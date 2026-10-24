import { askQuestion } from "@/lib/ask-stream";
import { accountToken } from "@/lib/account-request";
import {
  selectInventory,
  requireInventoryContext,
} from "@/lib/inventory-selection";
jest.mock("@/lib/account-request", () => ({ accountToken: jest.fn() }));
const fetched = jest.fn();
beforeEach(() => {
  jest.clearAllMocks();
  selectInventory(null);
  requireInventoryContext(false);
  global.fetch = fetched;
  jest.mocked(accountToken).mockResolvedValue("actor-token");
});
const result = () =>
  new Response(
    'data: {"type":"done","conversation_id":"saved","assistant_message":"Found it"}\n\n',
    { status: 200 },
  );
test("organization text uses the authenticated world endpoint and durable capabilities", async () => {
  fetched.mockResolvedValue(result());
  const done = jest.fn();
  await askQuestion({
    accountId: "actor",
    worldId: "org",
    requestId: "request",
    message: "Find bolts",
    signal: new AbortController().signal,
    onDelta: jest.fn(),
    onStatus: jest.fn(),
    onDone: done,
  });
  const [url, options] = fetched.mock.calls[0];
  expect(url).toMatch(/\/worlds\/org\/ai_command$/);
  expect(options.headers.Authorization).toBe("Bearer actor-token");
  expect(JSON.parse(options.body)).toMatchObject({
    supports_item_management: true,
    supports_task_actions: true,
    request_id: "request",
  });
  expect(done).toHaveBeenCalledWith(
    expect.objectContaining({ conversationId: "saved" }),
  );
});
test("ordinary organization photos remain chat photos and do not request extraction", async () => {
  fetched.mockResolvedValue(result());
  await askQuestion({
    accountId: "actor",
    worldId: "org",
    requestId: "request",
    message: "Read the label",
    photo: new File(["image"], "photo.jpg", { type: "image/jpeg" }),
    signal: new AbortController().signal,
    onDelta: jest.fn(),
    onStatus: jest.fn(),
    onDone: jest.fn(),
  });
  const [url, options] = fetched.mock.calls[0];
  expect(url).toMatch(/\/worlds\/org\/ai_photo_question$/);
  expect(options.body.get("auto_extract")).toBeNull();
  expect(options.body.get("request_id")).toBe("request");
});
test("an account change before sending prevents all network calls", async () => {
  jest.mocked(accountToken).mockRejectedValue(new Error("Account changed"));
  await expect(
    askQuestion({
      accountId: "old",
      worldId: "org",
      message: "Add bolts",
      signal: new AbortController().signal,
      onDelta: jest.fn(),
      onStatus: jest.fn(),
      onDone: jest.fn(),
    }),
  ).rejects.toThrow("Account changed");
  expect(fetched).not.toHaveBeenCalled();
});
