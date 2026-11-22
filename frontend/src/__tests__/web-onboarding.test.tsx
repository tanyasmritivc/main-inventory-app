/** @jest-environment jsdom */
import { act, fireEvent, render, screen } from "@testing-library/react";
import { WebOnboarding } from "@/components/site/onboarding/web-onboarding";
import { accountRequest } from "@/lib/account-request";
const replace = jest.fn();
const router = { replace };
jest.mock("next/navigation", () => ({ useRouter: () => router }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: () => ({ accountId: "actor" }) }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
beforeEach(() => {
  jest.clearAllMocks(); localStorage.clear();
  Object.defineProperty(crypto, "randomUUID", { configurable: true, value: () => "f5ecbf53-1b6f-4c00-8ccd-990cd1b148e4" });
  (accountRequest as jest.Mock).mockImplementation(async (_id, path) => path === "/organizations" ? { organizations: [{ is_personal: true }] } : { organization_id: "org", space: { id: "space" } });
});
async function mount() { await act(async () => { render(<WebOnboarding userId="actor" />); }); }
test("setup asks only for organization and Space and makes no implicit writes", async () => {
  await mount();
  expect(screen.getByLabelText("Organization")).toBeTruthy();
  expect(screen.getByLabelText("First Space")).toBeTruthy();
  expect(screen.queryByText(/workspace|inventory/i)).toBeNull();
  expect((accountRequest as jest.Mock).mock.calls.every(c => !c[2]?.method)).toBe(true);
});
test("personal setup creates one Space with an idempotency key", async () => {
  await mount(); fireEvent.change(screen.getByLabelText("First Space"), { target: { value: "Workshop" } });
  await act(async () => { fireEvent.click(screen.getByRole("button", { name: "Create Space" })); });
  expect(accountRequest).toHaveBeenCalledWith("actor", "/organization-setup", { method: "POST", body: { request_id: expect.any(String), name: "Personal", space: "Workshop", personal: true } });
  expect(replace).toHaveBeenCalledWith("/worlds/personal?view=spaces");
});
test("uncertain setup retries the exact saved request across remounts", async () => {
  (accountRequest as jest.Mock).mockImplementation(async (_id, path) => { if (path === "/organization-setup") throw new Error("offline"); return { organizations: [] }; });
  const view = render(<WebOnboarding userId="actor" />); await act(async () => {});
  fireEvent.change(screen.getByLabelText("First Space"), { target: { value: "Lab" } });
  await act(async () => { fireEvent.click(screen.getByRole("button", { name: "Create Space" })); });
  const first = (accountRequest as jest.Mock).mock.calls.find(c => c[2]?.method === "POST")[2].body;
  view.unmount(); await mount();
  expect((screen.getByLabelText("First Space") as HTMLInputElement).disabled).toBe(true);
  await act(async () => { fireEvent.click(screen.getByRole("button", { name: "Retry setup" })); });
  expect((accountRequest as jest.Mock).mock.calls.filter(c => c[2]?.method === "POST").map(c => c[2].body)).toEqual([first, first]);
});
test("existing organization bypasses setup without enrolling or moving anyone", async () => {
  (accountRequest as jest.Mock).mockResolvedValue({ organizations: [{ is_personal: false }] });
  await mount(); expect(replace).toHaveBeenCalledWith("/worlds");
  expect((accountRequest as jest.Mock).mock.calls.every(c => !c[2]?.method)).toBe(true);
});
test("completed setup stays completed", async () => {
  localStorage.setItem("fz_web_onboarding_done_actor", "1"); await mount(); expect(replace).toHaveBeenCalledWith("/worlds"); expect(accountRequest).not.toHaveBeenCalled();
});
