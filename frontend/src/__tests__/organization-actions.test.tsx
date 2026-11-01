/** @jest-environment jsdom */
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
mockBrowserTopLayer();
import { OrganizationDirectory } from "@/components/site/organization-directory";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";

const router = { push: jest.fn(), replace: jest.fn() };
const org = {
  organization_id: "acme",
  name: "Acme",
  role: "owner",
  owner_user_id: "owner",
};
jest.mock("@/components/site/app-shell", () => ({
  AppShell: ({ children }: { children: React.ReactNode }) => (
    <main>{children}</main>
  ),
}));
jest.mock("next/navigation", () => ({ useRouter: () => router }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: jest.fn() }));
beforeEach(() => {
  jest.clearAllMocks();
  jest
    .mocked(useApiSession)
    .mockReturnValue({
      accountId: "owner",
      loading: false,
      error: null,
    } as ReturnType<typeof useApiSession>);
  jest
    .mocked(accountRequest)
    .mockResolvedValue({ organizations: [org] } as never);
});

test("owner menu replaces the visible rename label and supports keyboard dismissal", async () => {
  render(<OrganizationDirectory />);
  const trigger = await screen.findByRole("button", {
    name: "Organization actions for Acme",
  });
  expect(trigger.textContent).toBe("");
  expect(screen.queryByRole("button", { name: /Rename/ })).toBeNull();
  await userEvent.click(trigger);
  expect(await screen.findByRole("menuitem", { name: "Rename" })).toBeTruthy();
  expect(screen.getByRole("menuitem", { name: "Delete" })).toBeTruthy();
  await userEvent.keyboard("{Escape}");
  await waitFor(() => expect(screen.queryByRole("menu")).toBeNull());
  expect(document.activeElement).toBe(trigger);
  expect(
    jest.mocked(accountRequest).mock.calls.some((call) => call[2]?.method),
  ).toBe(false);
});

test("organization header uses the same menu and rename keeps the current name", async () => {
  jest
    .mocked(accountRequest)
    .mockResolvedValue({
      organization: org,
      workspaces: [],
      members: [],
    } as never);
  render(<OrganizationDirectory organizationId="acme" />);
  await userEvent.click(
    await screen.findByRole("button", {
      name: "Organization actions for Acme",
    }),
  );
  await userEvent.click(
    await screen.findByRole("menuitem", { name: "Rename" }),
  );
  expect(
    (screen.getByRole("textbox", { name: "Name" }) as HTMLInputElement).value,
  ).toBe("Acme");
  await userEvent.click(screen.getByRole("button", { name: "Cancel" }));
  expect(screen.queryByRole("dialog")).toBeNull();
});

test("members can leave, while Personal has no organization actions", async () => {
  jest
    .mocked(accountRequest)
    .mockResolvedValue({
      organizations: [
        { ...org, role: "member", owner_user_id: "someone-else" },
      ],
    } as never);
  render(<OrganizationDirectory />);
  await screen.findByRole("link", { name: /Acme/ });
  expect(screen.getByRole("link", { name: /Personal/ })).toBeTruthy();
  await userEvent.click(
    screen.getByRole("button", { name: "Organization actions for Acme" }),
  );
  expect(
    screen.getByRole("menuitem", { name: "Leave organization" }),
  ).toBeTruthy();
  expect(screen.queryByRole("menuitem", { name: "Rename" })).toBeNull();
  expect(screen.queryByRole("menuitem", { name: "Delete" })).toBeNull();
});

test("organization Admin can rename but cannot delete the organization", async () => {
  jest
    .mocked(accountRequest)
    .mockResolvedValue({
      organizations: [{ ...org, role: "admin", owner_user_id: "another" }],
    } as never);
  render(<OrganizationDirectory />);
  await userEvent.click(
    await screen.findByRole("button", {
      name: "Organization actions for Acme",
    }),
  );
  expect(await screen.findByRole("menuitem", { name: "Rename" })).toBeTruthy();
  expect(screen.queryByRole("menuitem", { name: "Delete" })).toBeNull();
});

for (const role of ["member", "admin"])
  test(`${role} can confirm leaving without deleting organization`, async () => {
    jest
      .mocked(accountRequest)
      .mockImplementation(
        async (_actor, _path, options) =>
          (options?.method
            ? { left: true, organization_id: "acme" }
            : {
                organization: { ...org, role, owner_user_id: "other" },
                workspaces: [],
                members: [],
              }) as never,
      );
    render(<OrganizationDirectory organizationId="acme" />);
    await userEvent.click(
      await screen.findByRole("button", {
        name: "Organization actions for Acme",
      }),
    );
    await userEvent.click(
      screen.getByRole("menuitem", { name: "Leave organization" }),
    );
    expect(screen.getByText(/team's items, photos/)).toBeTruthy();
    await userEvent.click(
      screen.getByRole("button", { name: "Leave organization" }),
    );
    await waitFor(() =>
      expect(router.push).toHaveBeenCalledWith("/settings/organizations"),
    );
    expect(accountRequest).toHaveBeenCalledWith(
      "owner",
      "/organizations/acme/leave",
      { method: "DELETE", body: { name: "Acme" } },
    );
  });
test("owner sees transfer guidance and cannot submit leave", async () => {
  render(<OrganizationDirectory />);
  await userEvent.click(
    await screen.findByRole("button", {
      name: "Organization actions for Acme",
    }),
  );
  await userEvent.click(
    screen.getByRole("menuitem", { name: "Leave organization" }),
  );
  expect(screen.getByText(/Transfer organization ownership/)).toBeTruthy();
  expect(
    screen.queryByRole("button", { name: "Leave organization" }),
  ).toBeNull();
  expect(
    jest.mocked(accountRequest).mock.calls.some((call) => call[2]?.method),
  ).toBe(false);
});

test("owner opens move-or-delete organization choices with affected counts", async () => {
  jest
    .mocked(accountRequest)
    .mockImplementation(
      async (_actor, path) =>
        (path.startsWith("/resource-removal/")
          ? {
              kind: "organization",
              id: "acme",
              name: "Acme",
              items: 12,
              spaces: 2,
              inventories: 1,
              workspaces: 1,
              can_move: true,
              destinations: [],
            }
          : { organization: org, workspaces: [], members: [] }) as never,
    );
  render(<OrganizationDirectory organizationId="acme" />);
  await userEvent.click(
    await screen.findByRole("button", {
      name: "Organization actions for Acme",
    }),
  );
  await userEvent.click(screen.getByRole("menuitem", { name: "Delete" }));
  expect(await screen.findByText(/12 items/)).toBeTruthy();
  expect(
    screen.getByRole("radio", {
      name: "Keep workspaces outside this organization",
    }),
  ).toBeTruthy();
  expect(
    screen.getByRole("radio", {
      name: "Delete organization and all its contents",
    }),
  ).toBeTruthy();
});

test("switcher new-organization destination opens the existing reviewable creation form", async () => {
  const { rerender } = render(<OrganizationDirectory startCreate />);
  expect(
    await screen.findByRole("dialog", { name: "New organization" }),
  ).toBeTruthy();
  expect(
    screen.getByRole("textbox", { name: "Organization name" }),
  ).toHaveProperty("value", "");
  expect(
    jest.mocked(accountRequest).mock.calls.some((call) => call[2]?.method),
  ).toBe(false);
  await userEvent.click(screen.getByRole("button", { name: "Cancel" }));
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(router.replace).toHaveBeenCalledWith("/settings/organizations", {
    scroll: false,
  });
  rerender(<OrganizationDirectory startCreate={false} />);
  rerender(<OrganizationDirectory startCreate />);
  expect(
    await screen.findByRole("dialog", { name: "New organization" }),
  ).toBeTruthy();
});
