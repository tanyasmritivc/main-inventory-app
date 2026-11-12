/** @jest-environment jsdom */
import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { ChatItemActionCard } from "@/components/site/chat-item-action";
import { decideChatItemAction, parseChatItemAction } from "@/lib/chat-item-actions";
import { accountRequest } from "@/lib/account-request";
import { selectInventory, type InventorySelection } from "@/lib/inventory-selection";
import { trustedAskPhotoUrl } from "@/lib/ask-answer";

const confirm = jest.fn();
jest.mock("@/components/site/app-dialog-provider", () => ({ useAppDialog: () => ({ confirmAction: confirm }) }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
const inventoryId = "11111111-1111-4111-8111-111111111111", actionId = "22222222-2222-4222-8222-222222222222";
const raw = (operation = "add", status = "pending") => ({ id: actionId, inventory_id: inventoryId, operation, status,
  items: [{ name: "Bolt", quantity: 3, location: "Garage" }] });
const selected = (editable = true): InventorySelection => ({ accountId: "actor", inventory_id: inventoryId, name: "Tools", owner_user_id: "owner", team_id: "workspace", is_default: false,
  can_edit: editable, workspace: { workspace_id: "workspace", name: "Workshop", kind: "team", team_id: "workspace", role: editable ? "member" : "viewer" } });
beforeEach(() => { jest.clearAllMocks(); selectInventory(selected()); confirm.mockResolvedValue(true); });
afterEach(() => selectInventory(null));

test("pending cards do not call the API until explicitly confirmed; a model reply is delivered once", async () => {
  const reply = jest.fn();
  jest.mocked(accountRequest).mockResolvedValue({ action: raw("add", "confirmed"), assistant_message: "Added 3 bolts in Garage.", reply_id: "reply" });
  render(<ChatItemActionCard action={parseChatItemAction(raw())!} accountId="actor" onReply={reply} />);
  expect(accountRequest).not.toHaveBeenCalled();
  expect(screen.getByText("Qty 3 · Garage")).toBeTruthy();
  fireEvent.click(screen.getByRole("button", { name: "Confirm additions" }));
  expect(await screen.findByText("Change confirmed")).toBeTruthy();
  expect(accountRequest).toHaveBeenCalledTimes(1);
  expect(accountRequest).toHaveBeenCalledWith("actor", `/inventories/${inventoryId}/ai_actions/${actionId}`, expect.objectContaining({ method: "POST", body: { decision: "confirm" } }));
  expect(reply).toHaveBeenCalledWith({ id: "reply", content: "Added 3 bolts in Garage." });
  expect(screen.queryByRole("button", { name: "Confirm additions" })).toBeNull();
});

test("deletion awaits a separate reviewed confirmation; declining makes no request", async () => {
  confirm.mockResolvedValue(false);
  render(<ChatItemActionCard action={parseChatItemAction(raw("delete"))!} accountId="actor" onReply={jest.fn()} />);
  fireEvent.click(screen.getByRole("button", { name: "Review deletion" }));
  await waitFor(() => expect(confirm).toHaveBeenCalledWith(expect.objectContaining({ title: "Delete 1 item?", danger: true })));
  expect(accountRequest).not.toHaveBeenCalled();
});

test("a failed confirmation dialog releases the card for a safe retry", async () => {
  confirm.mockRejectedValueOnce(new Error("Dialog unavailable"));
  render(<ChatItemActionCard action={parseChatItemAction(raw("delete"))!} accountId="actor" onReply={jest.fn()} />);
  fireEvent.click(screen.getByRole("button", { name: "Review deletion" }));
  await screen.findByRole("alert");
  expect((screen.getByRole("button", { name: "Review deletion" }) as HTMLButtonElement).disabled).toBe(false);
  expect(accountRequest).not.toHaveBeenCalled();
});

test("shared-inventory photo history accepts only the selected inventory on its trusted origin", () => {
  const owner = "33333333-3333-4333-8333-333333333333";
  const url = `https://storage.test/storage/v1/object/public/item-images/${owner}/${inventoryId}-${"a".repeat(32)}-ask-${"b".repeat(32)}.jpg`;
  expect(trustedAskPhotoUrl(url, "actor", ["https://storage.test"], inventoryId)).toBe(url);
  expect(trustedAskPhotoUrl(url, "actor", ["https://storage.test"], owner)).toBeUndefined();
  expect(trustedAskPhotoUrl(url.replace("storage.test", "foreign.test"), "actor", ["https://storage.test"], inventoryId)).toBeUndefined();
});

test("an uncertain outcome retries exactly the same action, never a new proposal", async () => {
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error("Response lost")).mockResolvedValueOnce({ action: raw("add", "confirmed"), assistant_message: "Added 3 bolts.", reply_id: "reply" });
  render(<ChatItemActionCard action={parseChatItemAction(raw())!} accountId="actor" onReply={jest.fn()} />);
  fireEvent.click(screen.getByText("Confirm additions"));
  await screen.findByRole("alert");
  fireEvent.click(screen.getByText("Confirm additions"));
  await screen.findByText("Change confirmed");
  expect(jest.mocked(accountRequest).mock.calls.map((call) => call[1])).toEqual([`/inventories/${inventoryId}/ai_actions/${actionId}`, `/inventories/${inventoryId}/ai_actions/${actionId}`]);
});

test("a confirmed receipt with a failed AI reply stays confirmed and can reload only that reply", async () => {
  jest.mocked(accountRequest).mockResolvedValue({ action: raw("add", "confirmed"), answer_error: "Confirmed, but the AI reply could not load." });
  const onReply = jest.fn();
  render(<ChatItemActionCard action={parseChatItemAction(raw())!} accountId="actor" onReply={onReply} />);
  fireEvent.click(screen.getByText("Confirm additions"));
  await screen.findByText("Change confirmed");
  expect(onReply).not.toHaveBeenCalled();
  expect(screen.getByRole("button", { name: "Reload AI reply" })).toBeTruthy();
});

test("Viewer can dismiss a card but cannot confirm an item write", async () => {
  selectInventory(selected(false));
  jest.mocked(accountRequest).mockResolvedValue({ action: raw("add", "cancelled") });
  render(<ChatItemActionCard action={parseChatItemAction(raw())!} accountId="actor" onReply={jest.fn()} />);
  expect((screen.getByRole("button", { name: "Confirm additions" }) as HTMLButtonElement).disabled).toBe(true);
  fireEvent.click(screen.getByText("Cancel"));
  await screen.findByText("Cancelled");
  expect(jest.mocked(accountRequest).mock.calls[0][2]?.body).toEqual({ decision: "cancel" });
});

test("switching inventory during confirmation discards its response", async () => {
  let release!: (value: unknown) => void;
  jest.mocked(accountRequest).mockImplementation(() => new Promise((resolve) => { release = resolve; }) as never);
  const pending = decideChatItemAction("actor", parseChatItemAction(raw())!, "confirm", new AbortController().signal);
  selectInventory({ ...selected(), inventory_id: "33333333-3333-4333-8333-333333333333" });
  release({ action: raw("add", "confirmed") });
  await expect(pending).rejects.toThrow("inventory changed");
});

test("unmount aborts the request and cannot append a reply to another conversation", async () => {
  jest.mocked(accountRequest).mockImplementation(() => new Promise(() => {}) as never);
  const reply = jest.fn();
  const view = render(<ChatItemActionCard action={parseChatItemAction(raw())!} accountId="actor" onReply={reply} />);
  fireEvent.click(screen.getByText("Confirm additions"));
  await act(async () => {});
  const signal = jest.mocked(accountRequest).mock.calls[0][2]?.signal;
  view.unmount();
  expect(signal?.aborted).toBe(true);
  expect(reply).not.toHaveBeenCalled();
});

test.each([null, {}, { ...raw(), id: "wrong" }, { ...raw(), operation: "delete_inventory" }, { ...raw(), items: [{ name: "Bolt", location: "Garage", quantity: -1 }] }])("invalid action payload is ignored: %j", (value) => {
  expect(parseChatItemAction(value)).toBeUndefined();
});
