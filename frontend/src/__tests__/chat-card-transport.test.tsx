/** @jest-environment jsdom */
import { fireEvent, render, screen } from "@testing-library/react";
import { WorldActionCard } from "@/components/site/world-chat-cards";
import { parseWorldAction } from "@/lib/world-chat";
import { decideChatItemAction, parseChatItemAction } from "@/lib/chat-item-actions";
import { selectInventory } from "@/lib/inventory-selection";
jest.mock("next/navigation", () => ({ useRouter: () => ({ push: jest.fn() }) }));
jest.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: () => ({ auth: { getSession: async () => ({
    data: { session: { user: { id: "actor" }, access_token: "fixture-token" } }, error: null,
  }) } }),
}));
const id = "11111111-1111-4111-8111-111111111111";
const inventory = "22222222-2222-4222-8222-222222222222";
const raw = { id, status: "pending", workspace_label: "Personal",
  plan: { inventories: [{ name: "Apartment", spaces: ["Kitchen"], items: [{ name: "Mugs", quantity: 8, location: "Kitchen" }] }] } };
const transport = jest.fn();
beforeEach(() => { selectInventory(null); transport.mockReset(); global.fetch = transport; });
function receive(action: unknown) {
  transport.mockImplementation(async (_url: string, init: RequestInit) => {
    expect(new Headers(init.headers).get("Content-Type")).toBe("application/json");
    expect(new Headers(init.headers).get("Authorization")).toBe("Bearer fixture-token");
    return { ok: true, status: 200, text: async () => JSON.stringify({ action }) };
  });
}
test.each(["confirm", "cancel"] as const)("creation %s sends JSON through actual transport", async decision => {
  receive({ ...raw, status: decision === "confirm" ? "confirmed" : "cancelled" });
  render(<WorldActionCard action={parseWorldAction(raw)!} accountId="actor" worldId="personal" />);
  fireEvent.click(screen.getByText(decision === "confirm" ? "Create and complete" : "Cancel"));
  await screen.findByText(decision === "confirm" ? "Created and completed" : "Cancelled");
  expect(transport.mock.calls[0][0]).toContain(`/worlds/personal/structure-actions/${id}`);
  expect(JSON.parse(transport.mock.calls[0][1].body)).toEqual({ decision, supports_task_actions: true });
});
test("item confirmation sends JSON and preserves the original action identity", async () => {
  const action = { id, inventory_id: inventory, operation: "add", status: "pending", items: [{ name: "Mug", quantity: 1, location: "Kitchen" }] };
  receive({ ...action, status: "confirmed" });
  await decideChatItemAction("actor", parseChatItemAction(action)!, "confirm", new AbortController().signal, "personal");
  expect(transport.mock.calls[0][0]).toContain(`/inventories/${inventory}/ai_actions/${id}`);
  expect(JSON.parse(transport.mock.calls[0][1].body)).toEqual({ decision: "confirm" });
});
