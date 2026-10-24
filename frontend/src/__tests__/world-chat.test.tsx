/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  WorldActionCard,
  WorldResourceLinks,
} from "@/components/site/world-chat-cards";
import {
  parseWorldAction,
  parseWorldResource,
  resolvedWorldHref,
} from "@/lib/world-chat";
import { worldNavigation, worldHref } from "@/lib/world-navigation";
import { directoryInventoryHref } from "@/lib/workspace-directory";
import { accountRequest } from "@/lib/account-request";
import {
  decideChatItemAction,
  parseChatItemAction,
} from "@/lib/chat-item-actions";
import { selectInventory } from "@/lib/inventory-selection";
const push = jest.fn();
jest.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
const id = "11111111-1111-4111-8111-111111111111",
  inventory = "22222222-2222-4222-8222-222222222222";
const raw = {
  id,
  status: "pending",
  workspace_label: "Robotics",
  plan: {
    inventories: [
      {
        name: "Hardware",
        spaces: ["Drawer"],
        items: [{ name: "Bolts", quantity: 5, location: "Drawer" }],
        moves: [{ name: "Drill", target_location: "Drawer" }],
      },
    ],
  },
};
const resource = {
  kind: "item",
  id,
  inventory_id: inventory,
  label: "Drill",
  href: `findez://item/${inventory}/${id}`,
};
beforeEach(() => {
  jest.clearAllMocks();
  selectInventory(null);
});
test("organization navigation has a single shared chat, and inventories open directly to editable items", () => {
  const navigation = worldNavigation(id, "Robotics");
  expect(navigation.homeHref).toBe(worldHref(id));
  expect(navigation.items.map((i) => i.label)).toEqual([
    "New chat",
    "Spaces",
    "Search",
    "Tools",
    "Workspaces",
    "People",
    "Organization settings",
  ]);
  expect(navigation.items.some((i) => i.route.startsWith("/assist"))).toBe(
    false,
  );
  expect(
    directoryInventoryHref({
      inventory_id: inventory,
      workspace_id: id,
      name: "Hardware",
    }),
  ).toBe(`/inventory?inventory=${inventory}`);
  expect(
    directoryInventoryHref({
      inventory_id: inventory,
      workspace_id: id,
      name: "Hidden",
      can_open: false,
      can_manage: true,
    }),
  ).toBe(`/inventory-access?inventory=${inventory}`);
});
test("one reviewed creation includes item additions and moves and safely retries a lost receipt", async () => {
  jest
    .mocked(accountRequest)
    .mockRejectedValueOnce(new Error("Response lost"))
    .mockResolvedValueOnce({ action: { ...raw, status: "confirmed" } });
  render(
    <WorldActionCard
      action={parseWorldAction(raw)!}
      accountId="actor"
      worldId="org"
    />,
  );
  expect(screen.getByText("Qty 5 · Drawer")).toBeTruthy();
  expect(screen.getByText("Move Drill to Drawer")).toBeTruthy();
  expect(accountRequest).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText("Create and complete"));
  await screen.findByRole("alert");
  fireEvent.click(screen.getByText("Create and complete"));
  await screen.findByText("Created and completed");
  expect(jest.mocked(accountRequest).mock.calls.map((c) => c[1])).toEqual([
    `/worlds/org/structure-actions/${id}`,
    `/worlds/org/structure-actions/${id}`,
  ]);
  expect(
    JSON.parse(jest.mocked(accountRequest).mock.calls[1][2]!.body as string),
  ).toEqual({ decision: "confirm", supports_task_actions: true });
});
test("unverified creation receipts stay pending and never claim success", async () => {
  jest
    .mocked(accountRequest)
    .mockResolvedValue({
      action: { ...raw, id: inventory, status: "confirmed" },
    });
  render(
    <WorldActionCard
      action={parseWorldAction(raw)!}
      accountId="actor"
      worldId="org"
    />,
  );
  fireEvent.click(screen.getByText("Create and complete"));
  await screen.findByRole("alert");
  expect(screen.queryByText("Created and completed")).toBeNull();
});
test("malformed links and incomplete review plans cannot create actionable cards", () => {
  expect(
    parseWorldResource({ ...resource, href: "https://evil.test" }),
  ).toBeUndefined();
  expect(
    parseWorldAction({
      ...raw,
      plan: {
        inventories: [
          {
            name: "Hardware",
            spaces: [],
            items: [{ name: "Bolt", quantity: -1, location: "Drawer" }],
          },
        ],
      },
    }),
  ).toBeUndefined();
  expect(() =>
    resolvedWorldHref(parseWorldResource(resource)!, {
      kind: "item",
      inventory_id: id,
      resource: { item_id: id },
    }),
  ).toThrow();
});
test("resource opening rechecks current organization access and fails closed", async () => {
  jest
    .mocked(accountRequest)
    .mockRejectedValueOnce(new Error("Access removed"))
    .mockResolvedValueOnce({
      kind: "item",
      inventory_id: inventory,
      resource: { item_id: id },
    });
  render(
    <WorldResourceLinks
      links={[parseWorldResource(resource)!]}
      accountId="actor"
      worldId="org"
    />,
  );
  fireEvent.click(screen.getByText("Open Drill"));
  await screen.findByRole("alert");
  expect(push).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText("Open Drill"));
  await waitFor(() =>
    expect(push).toHaveBeenCalledWith(
      `/inventory?inventory=${inventory}&item=${id}`,
    ),
  );
  expect(accountRequest).toHaveBeenCalledWith(
    "actor",
    `/worlds/org/resources/${inventory}/item/${id}`,
    expect.anything(),
  );
});
test("world item confirmation targets the card inventory without selecting or trusting a local inventory", async () => {
  const action = {
    id,
    inventory_id: inventory,
    operation: "add",
    status: "pending",
    items: [{ name: "Bolt", quantity: 2, location: "Drawer" }],
  };
  jest
    .mocked(accountRequest)
    .mockResolvedValue({ action: { ...action, status: "confirmed" } });
  await decideChatItemAction(
    "actor",
    parseChatItemAction(action)!,
    "confirm",
    new AbortController().signal,
    "org",
  );
  expect(accountRequest).toHaveBeenCalledWith(
    "actor",
    `/worlds/org/inventories/${inventory}/ai_actions/${id}`,
    expect.anything(),
  );
});
