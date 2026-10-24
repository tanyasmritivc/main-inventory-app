/** @jest-environment jsdom */
import { act, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
import { OrganizationSwitcher } from "@/components/site/organization-switcher";
import { accountRequest } from "@/lib/account-request";
import { organizationNavigation, workspaceNavigation } from "@/lib/context-navigation";
mockBrowserTopLayer();
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
const organizations = [
  { organization_id: "team-b", name: "Workshop", role: "member" },
  { organization_id: "team-a", name: "Acme robotics", role: "owner" },
];
beforeEach(() => { jest.clearAllMocks(); jest.mocked(accountRequest).mockResolvedValue({ organizations }); });

test("dropdown shows authorized organizations, current selection and existing destinations", async () => {
  render(<OrganizationSwitcher accountId="alice" organization={{ id: "team-a", name: "Acme robotics" }} />);
  expect(accountRequest).not.toHaveBeenCalled();
  await userEvent.click(screen.getByRole("button", { name: /Switch organization/ }));
  const acme = await screen.findByRole("menuitem", { name: /Acme robotics/ });
  expect(acme.getAttribute("href")).toBe("/organizations/team-a");
  expect(acme.getAttribute("aria-current")).toBe("true");
  const names = screen.getAllByRole("menuitem").map(el => el.textContent);
  expect(names[0]).toContain("Acme robotics");
  expect(names[1]).toContain("Workshop");
  expect(accountRequest).toHaveBeenCalledWith("alice", "/organizations");
  for (const [name, href] of Object.entries({ Personal: "/workspaces/personal", "All workspaces": "/workspaces", "Manage organizations": "/organizations", "New organization": "/organizations?new=1", "Review invitation": "/join/access" })) {
    expect(screen.getByRole("menuitem", { name }).getAttribute("href")).toBe(href);
  }
  expect(screen.queryByText(/credits|upgrade/i)).toBeNull();
});

test("keyboard Escape restores focus and reopening refreshes memberships", async () => {
  render(<OrganizationSwitcher accountId="alice" personal />);
  const trigger = screen.getByRole("button", { name: /Current: Personal/ });
  trigger.focus();
  await userEvent.keyboard("{Enter}");
  await screen.findByRole("menuitem", { name: /Workshop/ });
  expect(screen.getByRole("menuitem", { name: /Personal/ }).querySelector('[aria-label="Selected"]')).toBeTruthy();
  const drawerEscape = jest.fn();
  document.addEventListener("keydown", drawerEscape);
  await userEvent.keyboard("{Escape}");
  document.removeEventListener("keydown", drawerEscape);
  expect(drawerEscape).not.toHaveBeenCalled();
  await waitFor(() => expect(screen.queryByRole("menu")).toBeNull());
  expect(document.activeElement).toBe(trigger);
  jest.mocked(accountRequest).mockResolvedValue({ organizations: [] });
  await userEvent.click(trigger);
  await screen.findByText("Your organizations will appear here.");
  expect(screen.queryByRole("menuitem", { name: /Workshop/ })).toBeNull();
});

test("failure is actionable and retry keeps the menu open", async () => {
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error("Unable to load"));
  render(<OrganizationSwitcher accountId="alice" />);
  await userEvent.click(screen.getByRole("button"));
  await screen.findByRole("alert");
  await userEvent.click(screen.getByRole("menuitem", { name: "Try again" }));
  await screen.findByRole("menuitem", { name: /Workshop/ });
  expect(screen.queryByRole("alert")).toBeNull();
});

test("late responses cannot expose another account's organizations", async () => {
  let resolve!: (value: unknown) => void;
  jest.mocked(accountRequest).mockImplementationOnce(() => new Promise(done => { resolve = done; }));
  const view = render(<OrganizationSwitcher accountId="alice" />);
  await userEvent.click(screen.getByRole("button"));
  expect(screen.getByRole("status")).toBeTruthy();
  view.rerender(<OrganizationSwitcher accountId="bob" />);
  await act(async () => resolve({ organizations }));
  expect(screen.queryByRole("menu")).toBeNull();
  jest.mocked(accountRequest).mockResolvedValue({ organizations: [] });
  await userEvent.click(screen.getByRole("button"));
  await screen.findByText("Your organizations will appear here.");
  expect(within(screen.getByRole("menu")).queryByText("Acme robotics")).toBeNull();
  view.rerender(<OrganizationSwitcher accountId={null} />);
  expect(screen.queryByRole("menu")).toBeNull();
  expect(screen.getByRole("button")).toHaveProperty("disabled", true);
});

test("context identifies organizations through workspaces and personal stays separate", () => {
  expect(organizationNavigation("org", "Robotics", "people").organization).toEqual({ id: "org", name: "Robotics" });
  expect(workspaceNavigation({workspace_id:"ws", name:"Workshop", organization_id:"org", organization_name:"Robotics", kind:"team", team_id:"ws", role:"viewer"}, "inventories").organization).toEqual({id:"org",name:"Robotics"});
  expect(workspaceNavigation({workspace_id:"personal", name:"Personal", kind:"personal", team_id:null, role:"owner"}, "inventories").personal).toBe(true);
});
