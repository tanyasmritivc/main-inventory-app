/** @jest-environment jsdom */
import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { WorldWorkspace } from "@/components/site/world-workspace";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
let actor = "actor";
jest.mock("@/lib/use-api-session", () => ({
  useApiSession: () => ({ accountId: actor }),
}));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/components/site/app-shell", () => ({
  AppShell: ({ children }: { children: React.ReactNode }) => (
    <main>{children}</main>
  ),
}));
jest.mock("@/components/site/assist-client", () => ({
  AssistClient: ({ worldId }: { worldId: string }) => <p>Chat for {worldId}</p>,
}));
const inventory = {
  inventory_id: "inv-a",
  name: "Hardware",
  workspace_id: "ws",
  workspace_name: "Robotics",
  can_edit: true,
};
beforeEach(() => {
  actor = "actor";
  jest.clearAllMocks();
  jest.mocked(accountRequest).mockImplementation(async (_actor, path) => {
    if (path === "/organizations")
      return {
        organizations: [{ organization_id: "org", name: "Robotics" }],
      } as never;
    if (path.endsWith("/directory"))
      return {
        world: "org",
        inventories: [inventory],
        workspaces: [],
      } as never;
    if (path.endsWith("/spaces"))
      return {
        inventories: [
          {
            ...inventory,
            spaces: [{ id: "space-a", name: "Fasteners", item_count: 2 }],
          },
        ],
      } as never;
    throw new Error("Unexpected request");
  });
});
test("Spaces are organization-wide and link directly to the existing editable item view", async () => {
  render(<WorldWorkspace worldId="org" view="spaces" initialQuery="" />);
  expect(
    (await screen.findByRole("link", { name: /Fasteners/ })).getAttribute(
      "href",
    ),
  ).toBe("/inventory?inventory=inv-a&space=Fasteners");
  expect(screen.queryByText("Chat for org")).toBeNull();
  expect(accountRequest).toHaveBeenCalledWith("actor", "/worlds/org/spaces");
});
test("changing accounts immediately removes the previous organization data", async () => {
  const view = render(
    <WorldWorkspace worldId="org" view="spaces" initialQuery="" />,
  );
  await screen.findByRole("link", { name: /Fasteners/ });
  actor = "other";
  jest.mocked(accountRequest).mockReturnValue(new Promise(() => {}));
  view.rerender(<WorldWorkspace worldId="org" view="spaces" initialQuery="" />);
  expect(screen.queryByText("Fasteners")).toBeNull();
  expect(screen.queryByText("Hardware")).toBeNull();
});
test("revoked organization access clears private views on refresh", async () => {
  render(<WorldWorkspace worldId="org" view="spaces" initialQuery="" />);
  await screen.findByText("Fasteners");
  jest
    .mocked(accountRequest)
    .mockRejectedValue(new ApiError("Access removed", 403, null));
  fireEvent.click(screen.getByRole("button", { name: "Refresh" }));
  await waitFor(() => expect(screen.queryByText("Fasteners")).toBeNull());
});
test("one create submission is locked until its saved receipt arrives", async () => {
  render(<WorldWorkspace worldId="org" view="spaces" initialQuery="" />);
  await screen.findByText("Fasteners");
  fireEvent.click(screen.getByRole("button", { name: "New Space" }));
  fireEvent.change(screen.getByRole("textbox", { name: "Name" }), {
    target: { value: "Bench" },
  });
  let finish!: (value: unknown) => void;
  const before = jest.mocked(accountRequest).getMockImplementation()!;
  jest.mocked(accountRequest).mockImplementation((a, p, o) =>
    o?.method === "POST"
      ? new Promise((resolve) => {
          finish = resolve;
        })
      : before(a, p, o),
  );
  fireEvent.click(screen.getByRole("button", { name: "Create Space" }));
  fireEvent.submit(
    screen.getByRole("textbox", { name: "Name" }).closest("form")!,
  );
  expect(
    jest
      .mocked(accountRequest)
      .mock.calls.filter((c) => c[2]?.method === "POST"),
  ).toHaveLength(1);
  await act(async () => finish({ space: { id: "new", name: "Bench" } }));
  expect(screen.queryByRole("dialog")).toBeNull();
});

test("foreground refresh replaces renamed and deleted Spaces from another client", async () => {
  render(<WorldWorkspace worldId="org" view="spaces" initialQuery="" />);
  await screen.findByText("Fasteners");
  jest.mocked(accountRequest).mockImplementation(async (_actor, path) => {
    if (path === "/organizations") return { organizations: [{ organization_id: "org", name: "Robotics" }] } as never;
    if (path.endsWith("/directory")) return { world: "org", inventories: [inventory], workspaces: [] } as never;
    if (path.endsWith("/spaces")) return { inventories: [{ ...inventory, spaces: [{ id: "space-a", name: "Renamed on mobile", item_count: 9 }] }] } as never;
    throw new Error("Unexpected request");
  });
  fireEvent(window, new Event("online"));
  await screen.findByText("Renamed on mobile");
  expect(screen.queryByText("Fasteners")).toBeNull();
  jest.mocked(accountRequest).mockImplementation(async (_actor, path) => {
    if (path === "/organizations") return { organizations: [{ organization_id: "org", name: "Robotics" }] } as never;
    return { world: "org", inventories: [], workspaces: [] } as never;
  });
  fireEvent(window, new Event("focus"));
  await waitFor(() => expect(screen.queryByText("Renamed on mobile")).toBeNull());
  expect(screen.queryByText("Hardware")).toBeNull();
});
