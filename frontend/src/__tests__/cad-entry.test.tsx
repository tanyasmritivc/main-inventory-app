/** @jest-environment jsdom */
import React from "react";
import { act, fireEvent, render, screen } from "@testing-library/react";
import { CadEntry } from "@/components/cad/cad-entry";
import { accountRequest } from "@/lib/account-request";

jest.mock("@/components/site/app-shell", () => ({ AppShell: ({ children }: { children: React.ReactNode }) => <>{children}</> }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: () => ({ accountId: "qa-user", error: null }) }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/inventory-selection", () => ({ requireInventoryContext: jest.fn(), selectInventory: jest.fn() }));
const request = jest.mocked(accountRequest);
const orgs = { organizations: [{ organization_id: "team", name: "Robotics" }] };
const directory = (world: string) => ({ world, inventories: [{ inventory_id: `${world}-inventory`, name: "Parts", workspace_name: world }] });
beforeEach(() => request.mockReset());

test("profile entry chooses an authorized inventory without redirecting to home", async () => {
  request.mockImplementation(async (_actor, path) => path === "/organizations" ? orgs : directory("personal"));
  render(<CadEntry />);
  expect((await screen.findByRole("link", { name: "Parts personal" })).getAttribute("href")).toBe("/cad?inventory=personal-inventory");
});

test("organization shortcut requests only its authorized directory", async () => {
  request.mockImplementation(async (_actor, path) => path === "/organizations" ? orgs : directory("team"));
  render(<CadEntry worldId="team" />);
  expect((await screen.findByRole("link", { name: "Parts team" })).getAttribute("href")).toBe("/cad?inventory=team-inventory");
  expect(request).toHaveBeenCalledWith("qa-user", "/worlds/team/directory");
  expect(request).not.toHaveBeenCalledWith("qa-user", "/worlds/personal/directory");
});

test("unknown organizations do not fetch a directory or fall back to personal", async () => {
  request.mockResolvedValue(orgs);
  render(<CadEntry worldId="foreign-team" />);
  expect((await screen.findByRole("alert")).textContent).toContain("You do not have access");
  expect(request).toHaveBeenCalledTimes(1);
});

test("switching organizations ignores a late response from the previous directory", async () => {
  let finish!: (value: unknown) => void;
  request.mockImplementation(async (_actor, path) => path === "/organizations" ? orgs : path.includes("/personal/") ? new Promise(resolve => { finish = resolve; }) : directory("team"));
  render(<CadEntry />);
  await screen.findByRole("option", { name: "Robotics" });
  fireEvent.change(screen.getByRole("combobox"), { target: { value: "team" } });
  await screen.findByRole("link", { name: "Parts team" });
  await act(async () => finish(directory("personal")));
  expect(screen.queryByRole("link", { name: "Parts personal" })).toBeNull();
});

test("a mismatched directory is rejected", async () => {
  request.mockImplementation(async (_actor, path) => path === "/organizations" ? orgs : directory("other"));
  render(<CadEntry worldId="team" />);
  expect(await screen.findByRole("alert")).toBeTruthy();
  expect(screen.queryByRole("link", { name: "Parts other" })).toBeNull();
});
