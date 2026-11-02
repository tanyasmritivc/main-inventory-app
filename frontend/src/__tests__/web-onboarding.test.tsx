/** @jest-environment jsdom */
import { act, fireEvent, render, screen } from "@testing-library/react";
import { WebOnboarding } from "@/components/site/onboarding/web-onboarding";
import { accountRequest, accountToken } from "@/lib/account-request";
import { doneSetupKey, newSetup, pendingSetupKey, saveSetup, type SetupDraft } from "@/lib/web-onboarding";
const replace = jest.fn();
const mockRouter = { replace };
jest.mock("next/navigation", () => ({ useRouter: () => mockRouter }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: () => ({ accountId: "actor", loading: false }) }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn(), accountToken: jest.fn() }));
jest.mock("@/components/site/onboarding/world-model", () => ({ miniModel: () => "", WorldModel: class { update() {} dispose() {} } }));
beforeEach(() => {
  jest.clearAllMocks(); jest.useFakeTimers(); localStorage.clear(); global.structuredClone = value => JSON.parse(JSON.stringify(value));
  Object.defineProperty(window, "matchMedia", { writable: true, value: () => ({ matches: false, addEventListener() {}, removeEventListener() {} }) });
  Object.defineProperty(navigator, "locks", { configurable: true, value: { request: (_key: string, action: () => Promise<unknown>) => action() } });
  (accountToken as jest.Mock).mockResolvedValue("fixture-token");
  (accountRequest as jest.Mock).mockImplementation(async (_id: string, path: string) => path === "/organizations" ? { organizations: [] } : path === "/inventory-workspaces" ? { workspaces: [{ workspace_id: "personal", kind: "personal" }] } : { inventories: [{ inventory_id: "default", is_default: true }] });
});
afterEach(() => { jest.useRealTimers(); });
async function mount(draft?: SetupDraft) { if (draft) saveSetup(localStorage, "actor", draft); await act(async () => { render(<WebOnboarding userId="actor" />); }); }
async function advance(ms: number) { await act(async () => { jest.advanceTimersByTime(ms); }); }
function click(name: string) { fireEvent.click(screen.getByRole("button", { name })); }

test("choosing personal advances at 900ms without writes", async () => {
  await mount(); click("Get started"); fireEvent.click(screen.getByRole("radio", { name: /Just me/ }));
  await advance(899); expect(screen.getByRole("heading").textContent).toBe("Who's FindEZ for?");
  await advance(1); expect(screen.getByRole("heading").textContent).toBe("What's this workspace for?");
  expect((accountRequest as jest.Mock).mock.calls.every(c => !c[2]?.method)).toBe(true);
});
test("changing path restarts timer and Back cancels it; revisit does not rearm", async () => {
  await mount({ ...newSetup(), step: "choose" }); fireEvent.click(screen.getByRole("radio", { name: /Just me/ })); await advance(800);
  fireEvent.click(screen.getByRole("radio", { name: /My team/ })); await advance(100); expect(screen.getByRole("heading").textContent).toBe("Who's FindEZ for?");
  click("Back"); await advance(2000); expect(screen.getByRole("heading").textContent).toBe("Let's set up your first inventory.");
  click("Get started"); await advance(2000); expect(screen.getByRole("heading").textContent).toBe("Who's FindEZ for?");
});
test("organization typed name needs tick or Enter and never a timer", async () => {
  await mount({ ...newSetup(), path: "team", step: "org" }); expect(screen.getByRole("button", { name: "Continue" })).toHaveProperty("disabled", true);
  fireEvent.change(screen.getByLabelText("Organization name"), { target: { value: " Kestrel Labs " } }); await advance(5000);
  expect(screen.getByRole("heading").textContent).toBe("Name your organization"); fireEvent.submit(screen.getByLabelText("Organization name").closest("form")!);
  expect(screen.getByRole("heading").textContent).toBe("What's this workspace for?");
});
test("purpose advances at 1100ms and inventory at 1900ms; changes restart", async () => {
  await mount({ ...newSetup(), path: "personal", step: "purpose" }); click("Home"); await advance(1000); click("Workshop"); await advance(100);
  expect(screen.getByRole("heading").textContent).toBe("What's this workspace for?"); await advance(1000);
  expect(screen.getByRole("heading").textContent).toBe("Create your first inventory"); click("Tools"); await advance(1899);
  expect(screen.getByRole("heading").textContent).toBe("Create your first inventory"); await advance(1); expect(screen.getByRole("heading").textContent).toBe("This is your world.");
});
test("Back cancels chip timer and answered revisit does not rearm", async () => {
  await mount({ ...newSetup(), path: "personal", step: "purpose" }); click("Home"); await advance(1100); click("Tools"); click("Back"); await advance(5000);
  expect(screen.getByRole("heading").textContent).toBe("What's this workspace for?"); expect(screen.getByRole("button", { name: "Home" }).getAttribute("aria-pressed")).toBe("true");
});
test("Custom cancels timer, focuses field and only confirms explicitly", async () => {
  await mount({ ...newSetup(), path: "personal", step: "purpose" }); click("Home"); click("+ Custom");
  const input = screen.getByLabelText("Your own purpose"); expect(document.activeElement).toBe(input); fireEvent.change(input, { target: { value: "Field service" } }); await advance(5000);
  expect(screen.getByRole("heading").textContent).toBe("What's this workspace for?"); click("Continue"); expect(screen.getByRole("heading").textContent).toBe("Create your first inventory");
  click("+ Custom"); fireEvent.change(screen.getByLabelText("Your own inventory"), { target: { value: "Lab supplies" } }); fireEvent.submit(screen.getByLabelText("Your own inventory").closest("form")!);
  expect(screen.getByRole("heading").textContent).toBe("This is your world.");
});
test("reload restores exact step and answer without a timer", async () => {
  await mount({ ...newSetup(), path: "personal", purpose: "Workshop", inventory: "Tools", step: "inventory" }); expect(screen.getByRole("button", { name: "Tools" }).getAttribute("aria-pressed")).toBe("true");
  await advance(5000); expect(screen.getByRole("heading").textContent).toBe("Create your first inventory"); expect(JSON.parse(localStorage.getItem(pendingSetupKey("actor"))!).purpose).toBe("Workshop");
});
test("skip marks only current user and opens Personal without writes", async () => {
  await mount(); await act(async () => { click("Skip for now"); }); expect(replace).toHaveBeenCalledWith("/home?inventory=default");
  expect(localStorage.getItem(doneSetupKey("actor"))).toBe("1"); expect(localStorage.getItem(doneSetupKey("other"))).toBeNull(); expect((accountRequest as jest.Mock).mock.calls.every(c => !c[2]?.method)).toBe(true);
});
test("existing workspace redirects before setup is displayed", async () => {
  (accountRequest as jest.Mock).mockImplementation(async (_id: string, path: string) => path === "/organizations" ? { organizations: [] } : { workspaces: [{ workspace_id: "personal", kind: "personal" }, { workspace_id: "iphone" }] });
  await mount(); expect(replace).toHaveBeenCalledWith("/organizations"); expect(screen.queryByText("Get started")).toBeNull();
});
test("directory failure shows retry and never exposes questions", async () => {
  (accountRequest as jest.Mock).mockRejectedValue(new Error("offline")); await mount(); expect(screen.getByRole("alert").textContent).toMatch(/could not be loaded/); expect(screen.queryByText("Get started")).toBeNull(); expect(replace).not.toHaveBeenCalled();
});
test("finished user cannot see onboarding again", async () => {
  localStorage.setItem(doneSetupKey("actor"), "1"); await mount(); expect(replace).toHaveBeenCalledWith("/home?inventory=default"); expect(screen.queryByText("Get started")).toBeNull();
});
