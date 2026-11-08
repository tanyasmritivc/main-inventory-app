/** @jest-environment jsdom */
import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
mockBrowserTopLayer();
import { OrganizationDirectory } from "@/components/site/organization-directory";
import { OrganizationDeleteDialog } from "@/components/site/organization-delete-dialog";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

const router = { push: jest.fn() };
import {preview,receipt,mutations} from './removal-fixture';
const impact = preview('organization','acme','Acme');
const org = { organization_id: "acme", name: "Acme", role: "owner", owner_user_id: "owner" };
jest.mock("@/components/site/app-shell", () => ({ AppShell: ({ children }: { children: React.ReactNode }) => <main>{children}</main> }));
jest.mock("next/navigation", () => ({ useRouter: () => router }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: jest.fn() }));
beforeEach(() => {
  jest.clearAllMocks();
  jest.mocked(useApiSession).mockReturnValue({ accountId: "owner", loading: false, error: null } as ReturnType<typeof useApiSession>);
  jest.mocked(accountRequest).mockImplementation(async(_actor,path)=>path.startsWith('/resource-removal/') ? impact as never : {organizations:[org]} as never);
});

test("owner menu replaces the visible rename label and supports keyboard dismissal", async () => {
  render(<OrganizationDirectory />);
  const trigger = await screen.findByRole("button", { name: "Organization actions for Acme" });
  expect(trigger.textContent).toBe("");
  expect(screen.queryByRole("button", { name: /Rename/ })).toBeNull();
  await userEvent.click(trigger);
  expect(await screen.findByRole("menuitem", { name: "Rename" })).toBeTruthy();
  expect(screen.getByRole("menuitem", { name: "Delete" })).toBeTruthy();
  await userEvent.keyboard("{Escape}");
  await waitFor(() => expect(screen.queryByRole("menu")).toBeNull());
  expect(document.activeElement).toBe(trigger);
  expect(jest.mocked(accountRequest).mock.calls.some(call => call[2]?.method)).toBe(false);
});

test("organization header uses the same menu and rename keeps the current name", async () => {
  jest.mocked(accountRequest).mockResolvedValue({ organization: org, workspaces: [], members: [] } as never);
  render(<OrganizationDirectory organizationId="acme" />);
  await userEvent.click(await screen.findByRole("button", { name: "Organization actions for Acme" }));
  await userEvent.click(await screen.findByRole("menuitem", { name: "Rename" }));
  expect((screen.getByRole("textbox", { name: "Name" }) as HTMLInputElement).value).toBe("Acme");
  await userEvent.click(screen.getByRole("button", { name: "Cancel" }));
  expect(screen.queryByRole("dialog")).toBeNull();
});

test("members can leave but cannot rename or delete an organization", async () => {
  jest.mocked(accountRequest).mockResolvedValue({ organizations: [{ ...org, role: "member", owner_user_id: "someone-else" }] } as never);
  render(<OrganizationDirectory />);
  await screen.findByRole("link", { name: /Acme/ });
  expect(screen.getByRole("link", { name: /Personal/ })).toBeTruthy();
  await userEvent.click(screen.getByRole("button", { name: /Organization actions/ }));
  expect(screen.getByRole("menuitem",{name:"Leave organization"})).toBeTruthy();
  expect(screen.queryByRole("menuitem",{name:"Delete"})).toBeNull();
  expect(screen.queryByRole("menuitem",{name:"Rename"})).toBeNull();
});

test("Delete requires the exact name and Cancel sends no deletion request", async () => {
  render(<OrganizationDirectory />);
  await userEvent.click(await screen.findByRole("button", { name: "Organization actions for Acme" }));
  await userEvent.click(await screen.findByRole("menuitem", { name: "Delete" }));
  const dialog = within(screen.getByRole("dialog", { name: "Delete organization" }));
  await dialog.findByRole("textbox");
  expect(dialog.getByText(/2 items/)).toBeTruthy();
  const submit = dialog.getByRole("button", { name: "Delete organization" }) as HTMLButtonElement;
  expect(submit.disabled).toBe(true);
  await userEvent.type(dialog.getByRole("textbox"), "acme");
  expect(submit.disabled).toBe(true);
  await userEvent.click(dialog.getByRole("button", { name: "Cancel" }));
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(jest.mocked(accountRequest).mock.calls.some(call => call[2]?.method === "DELETE")).toBe(false);
  expect(screen.getByRole("link", { name: /Acme/ })).toBeTruthy();
});

test("a failed deletion keeps the card and confirmation; only confirmed success removes it", async () => {
  let removed = false, attempts = 0;
  jest.mocked(accountRequest).mockImplementation(async (_actor, _path, options) => {
    if (options?.method === "POST") {
      if (++attempts === 1) throw new ApiError("Request failed.", 409, "Only organizations with no workspaces can be deleted.");
      removed = true; return receipt('organization','acme') as never;
    }
    return _path.startsWith('/resource-removal/') ? impact as never : { organizations: removed ? [] : [org] } as never;
  });
  render(<OrganizationDirectory />);
  await userEvent.click(await screen.findByRole("button", { name: "Organization actions for Acme" }));
  await userEvent.click(await screen.findByRole("menuitem", { name: "Delete" }));
  const input = await screen.findByRole("textbox", { name: "Type Acme to confirm" });
  await userEvent.click(screen.getByRole("radio",{name:"Delete organization and all its contents"}));
  await userEvent.type(input, "Acme");
  await userEvent.click(screen.getByRole("button", { name: "Delete organization" }));
  expect((await screen.findByRole("alert")).textContent).toContain("no workspaces");
  expect((input as HTMLInputElement).value).toBe("Acme");
  expect(document.querySelector('a[href="/organizations/acme"]')).toBeTruthy();
  await userEvent.click(screen.getByRole("button", { name: "Delete organization" }));
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  expect(screen.queryByRole("link", { name: /Acme/ })).toBeNull();
  expect(accountRequest).toHaveBeenCalledWith("owner", "/resource-removal/organization/acme", { method: "POST", body: { name: "Acme", action: "delete" } });
});

test("unconfirmed responses never remove an organization or navigate", async () => {
  jest.mocked(accountRequest).mockImplementation(async (_actor, _path, options) =>
    (options?.method ? receipt('organization','other') : _path.startsWith('/resource-removal/') ? impact : { organization: org, workspaces: [], members: [] }) as never);
  render(<OrganizationDirectory organizationId="acme" />);
  await userEvent.click(await screen.findByRole("button", { name: "Organization actions for Acme" }));
  await userEvent.click(await screen.findByRole("menuitem", { name: "Delete" }));
  await userEvent.click(await screen.findByRole("radio",{name:"Delete organization and all its contents"}));
  await userEvent.type(screen.getByRole("textbox"), "Acme{Enter}");
  expect((await screen.findByRole("alert")).textContent).toContain("could not be confirmed");
  expect(router.push).not.toHaveBeenCalled();
});

test("selected organization returns to the directory after confirmed deletion", async () => {
  jest.mocked(accountRequest).mockImplementation(async (_actor, _path, options) =>
    (options?.method ? receipt('organization','acme') : _path.startsWith('/resource-removal/') ? impact : { organization: org, workspaces: [], members: [] }) as never);
  render(<OrganizationDirectory organizationId="acme" />);
  await userEvent.click(await screen.findByRole("button", { name: "Organization actions for Acme" }));
  await userEvent.click(await screen.findByRole("menuitem", { name: "Delete" }));
  await userEvent.click(await screen.findByRole("radio",{name:"Delete organization and all its contents"}));
  await userEvent.type(screen.getByRole("textbox"), "Acme{Enter}");
  await waitFor(() => expect(router.push).toHaveBeenCalledWith("/settings/organizations"));
});

test("pending deletion cannot duplicate or apply a response after unmount", async () => {
  let resolve!: (value: never) => void;
  jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options) => options?.method ? new Promise(value => { resolve = value; }) : impact as never);
  const onDeleted = jest.fn(), onClose = jest.fn();
  const view = render(<OrganizationDeleteDialog accountId="owner" organization={org} onDeleted={onDeleted} onClose={onClose} />);
  await userEvent.click(await screen.findByRole("radio",{name:"Delete organization and all its contents"}));
  await userEvent.type(screen.getByRole("textbox"), "Acme");
  const form = screen.getByRole("button", { name: "Delete organization" }).closest("form")!;
  fireEvent.submit(form); fireEvent.submit(form);
  expect(mutations()).toHaveLength(1);
  await userEvent.keyboard("{Escape}"); expect(onClose).not.toHaveBeenCalled();
  view.unmount();
  await act(async () => { resolve(receipt("organization","acme") as never); });
  expect(onDeleted).not.toHaveBeenCalled();
});

test("organization Admin can rename but cannot delete the organization", async () => {
 jest.mocked(accountRequest).mockResolvedValue({organizations:[{...org,role:"admin",owner_user_id:"another"}]} as never);
 render(<OrganizationDirectory/>);
 await userEvent.click(await screen.findByRole("button", {name:"Organization actions for Acme"}));
 expect(await screen.findByRole("menuitem",{name:"Rename"})).toBeTruthy();
 expect(screen.queryByRole("menuitem",{name:"Delete"})).toBeNull();
});
