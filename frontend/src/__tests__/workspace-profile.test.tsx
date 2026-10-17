/** @jest-environment jsdom */
import { render, screen, waitFor, act, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { selectInventory } from "@/lib/inventory-selection";
import { organizationNavigation, workspaceNavigation } from "@/lib/context-navigation";
import { AppShell } from "@/components/site/app-shell";
import { SettingsClient } from "@/components/site/settings-client";
import { accountRequest } from "@/lib/account-request";
import { publishNotificationSnapshot } from "@/lib/notification-state";

afterEach(()=>selectInventory(null));
const session = {
  user: { id: "a", email: "tester@example.test", user_metadata: {} },
  access_token: "test-token",
};
const client = {
  auth: {
    getSession: jest.fn(async () => ({ data: { session } })),
    getUser: jest.fn(() => new Promise(() => {})),
    updateUser: jest.fn(() => new Promise(() => {})),
    onAuthStateChange: jest.fn((listener: (event: string) => void) => {
      void listener;
      return { data: { subscription: { unsubscribe: jest.fn() } } };
    }),
  },
};
const mockNavigate = jest.fn();
let mockPathname="/settings";
jest.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: () => client,
}));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/use-api-session", () => ({
  useApiSession: () => ({ accountId: "a" }),
}));
jest.mock("next/navigation", () => ({
  usePathname: () => mockPathname,
  useRouter: () => ({
    push: mockNavigate,
    replace: jest.fn(),
    refresh: jest.fn(),
  }),
}));
jest.mock("@/components/site/use-app-theme", () => ({
  AppThemeProvider: ({ children }: { children: React.ReactNode }) => children,
  useAppTheme: () => ({ theme: "system", setTheme: jest.fn() }),
}));
jest.mock("@/components/site/app-dialog-provider", () => ({
  useAppDialog: () => ({ promptValue: jest.fn(), showNotice: jest.fn() }),
}));
const profile = {
  display_name: "Local tester",
  contact_email: "contact@example.test",
  profile_role: "Builder",
  organization: "Workshop",
  avatar_url: "https://store.example/avatar.jpg",
  avatar_color: "#3A1230",
};
beforeEach(() => {
  mockPathname="/settings";
  localStorage.clear();
  selectInventory(null);
  window.matchMedia = jest.fn(() => ({ matches: true } as MediaQueryList));
  jest.clearAllMocks();
  jest
    .mocked(accountRequest)
    .mockImplementation(async (_id, path) =>
      path === "/notifications" ? { unread_count: 2 } : profile,
    );
});
test("page search opens with its input focused, filters destinations and closes after navigation or Escape", async () => {
  mockPathname="/home";
  const user = userEvent.setup();
  const inventory = {accountId:"a",inventory_id:"tools",name:"Tools",owner_user_id:"a",team_id:null,is_default:true,can_edit:true,workspace:{workspace_id:"personal",name:"Personal",kind:"personal" as const,team_id:null,role:"owner" as const}};
  selectInventory(inventory);
  render(<AppShell inventory={inventory}><p>Workspace</p></AppShell>);
  const trigger = screen.getByRole("button", { name: "Go to a page" });
  await user.click(trigger);
  const dialog = screen.getByRole("dialog", { name: "Navigate FindEZ" });
  const input = within(dialog).getByRole("textbox", { name: "Search features and pages" });
  expect(document.activeElement).toBe(input);
  await user.type(input, "documents");
  await user.click(within(dialog).getByRole("button", { name: "Documents" }));
  expect(mockNavigate).toHaveBeenCalledWith("/documents?inventory=tools");
  expect(screen.queryByRole("dialog")).toBeNull();
  await user.click(trigger);
  expect(screen.getByRole("textbox", { name: "Search features and pages" })).toHaveProperty("value", "");
  await user.keyboard("{Escape}");
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(document.activeElement).toBe(trigger);
});
test("loads identity and the saved avatar without waiting on a network getUser request", async () => {
  render(
    <AppShell>
      <p>Workspace</p>
    </AppShell>,
  );
  await screen.findByRole("link", {
    name: /Local tester.*Profile and settings/,
  });
  expect(client.auth.getUser).not.toHaveBeenCalled();
  expect(
    screen.getByRole("button", { name: "Open profile" }).style.backgroundImage,
  ).toContain(profile.avatar_url);
  expect(
    screen.getByRole("button", { name: "2 unread notifications" }),
  ).toBeTruthy();
});

test("navigation pin preference persists and moves the frame into its pinned layout", async () => {
  mockPathname="/workspaces";
  localStorage.setItem("findez-navigation-pinned", "true");
  const view = render(<AppShell><p>Workspace</p></AppShell>);
  const unpin = await screen.findByRole("button", { name: "Unpin navigation" });
  expect(view.container.querySelector(".app-frame")?.classList.contains("sidebar-pinned")).toBe(true);
  await userEvent.click(unpin);
  expect(localStorage.getItem("findez-navigation-pinned")).toBe("false");
  expect(view.container.querySelector(".app-frame")?.classList.contains("sidebar-pinned")).toBe(false);
  await userEvent.click(screen.getByRole("button", { name: "Pin navigation" }));
  expect(localStorage.getItem("findez-navigation-pinned")).toBe("true");
});
test("a confirmed inbox snapshot updates the bell immediately and an older read cannot restore its badge", async () => {
  let resolve!: (value: { unread_count: number }) => void;
  jest.mocked(accountRequest).mockImplementation(async (_account, path) => path === "/notifications" ? new Promise((done) => { resolve = done; }) : profile);
  render(<AppShell><p>Workspace</p></AppShell>);
  await waitFor(() => expect(resolve).toBeDefined());
  await act(async () => publishNotificationSnapshot("a", 0));
  expect(screen.getByRole("button", { name: "0 unread notifications" })).toBeTruthy();
  await act(async () => resolve({ unread_count: 3 }));
  expect(screen.getByRole("button", { name: "0 unread notifications" })).toBeTruthy();
  await act(async () => publishNotificationSnapshot("b", 8));
  expect(screen.queryByRole("button", { name: "8 unread notifications" })).toBeNull();
});
test("keeps profile save disabled until confirmed profile fields arrive", async () => {
  let resolve!: (value: typeof profile) => void;
  jest.mocked(accountRequest).mockImplementation(
    () =>
      new Promise((done) => {
        resolve = done;
      }),
  );
  render(<SettingsClient email="tester@example.test" />);
  expect(screen.getByRole("button", { name: "Save changes" })).toHaveProperty(
    "disabled",
    true,
  );
  expect(screen.getByRole("status").textContent).toContain("Loading profile");
  await act(async () => resolve(profile));
  expect(screen.getByLabelText("Display name")).toHaveProperty(
    "value",
    profile.display_name,
  );
  expect(screen.getByLabelText("Contact email")).toHaveProperty(
    "value",
    profile.contact_email,
  );
  expect(screen.getByRole("button", { name: "Save changes" })).toHaveProperty(
    "disabled",
    false,
  );
});
test("shows the current profile while legacy signup completion is still pending", async () => {
  let resolve!: (value: typeof profile) => void;
  jest.mocked(accountRequest).mockImplementation((_id, path) =>
    path === "/notifications"
      ? Promise.resolve({ unread_count: 2 })
      : new Promise((done) => {
          resolve = done;
        }),
  );
  localStorage.setItem(
    "findez_pending_signup_profile",
    JSON.stringify({ displayName: "Pending tester" }),
  );
  render(
    <AppShell>
      <p>Workspace</p>
    </AppShell>,
  );
  await waitFor(() => expect(accountRequest).toHaveBeenCalled());
  expect(client.auth.updateUser).not.toHaveBeenCalled();
  await act(async () => resolve(profile));
  await screen.findByRole("link", {
    name: /Local tester.*Profile and settings/,
  });
  expect(client.auth.updateUser).toHaveBeenCalled();
  jest.mocked(accountRequest).mockImplementation(async (_id, path) =>
    path === "/notifications" ? { unread_count: 2 } : profile,
  );
  await act(async () => {
    client.auth.onAuthStateChange.mock.calls[0][0]("USER_UPDATED");
  });
  await screen.findByRole("link", {
    name: /Local tester.*Profile and settings/,
  });
  expect(client.auth.updateUser).toHaveBeenCalledTimes(1);
  expect(
    screen.getByRole("button", { name: "2 unread notifications" }),
  ).toBeTruthy();
});
test("uploads the photo under the field required by the current backend", async () => {
  render(<SettingsClient email="tester@example.test" />);
  await waitFor(() =>
    expect(screen.getByLabelText("Display name")).toHaveProperty(
      "value",
      profile.display_name,
    ),
  );
  const photo = new File(["image"], "avatar.png", { type: "image/png" });
  await userEvent.upload(screen.getByLabelText("Profile photo file"), photo);
  await waitFor(() => {
    const call = jest
      .mocked(accountRequest)
      .mock.calls.find(([, path]) => path === "/profile/photo");
    expect(call?.[2]?.body).toBeInstanceOf(FormData);
    expect((call?.[2]?.body as FormData).get("photo")).toBe(photo);
    expect((call?.[2]?.body as FormData).has("file")).toBe(false);
  });
});

test("organization navigation contains only its management destinations",async()=>{
 mockPathname="/organizations/acme";
 render(<AppShell context={organizationNavigation("acme","Acme","people")}><h1>People</h1></AppShell>);
 await screen.findByRole("link",{name:/Local tester.*Profile and settings/});
 expect(screen.getByRole("link",{name:"People"}).getAttribute("aria-current")).toBe("page");
 expect(screen.queryByRole("link",{name:"Capture"})).toBeNull();
 expect(screen.queryByRole("link",{name:"Find"})).toBeNull();
 expect(screen.getByRole("link",{name:"Workspaces"}).getAttribute("href")).toBe("/organizations/acme");
});
test("workspace navigation selects only the current section and retains its parent organization",async()=>{
 const workspace={workspace_id:"ftc",name:"Robotics",kind:"team" as const,team_id:"ftc",role:"owner" as const,organization_id:"acme",organization_name:"Acme"};
 mockPathname="/workspaces/team";
 render(<AppShell context={workspaceNavigation(workspace,"locations")}><h1>Locations</h1></AppShell>);
 await screen.findByRole("link",{name:/Local tester.*Profile and settings/});
 expect(screen.getByRole("link",{name:"Locations"}).getAttribute("aria-current")).toBe("page");
 expect(screen.getByRole("link",{name:"Acme"}).getAttribute("href")).toBe("/organizations/acme");
 expect(screen.getByRole("link",{name:"Inventories"}).getAttribute("href")).toBe("/workspaces/ftc");
 expect(screen.queryByRole("link",{name:"Capture"})).toBeNull();
});
test("account navigation requires a context before offering inventory actions",async()=>{
 render(<AppShell><h1>Account</h1></AppShell>);
 await screen.findByRole("link",{name:/Local tester.*Profile and settings/});
 expect(screen.getByRole("link",{name:"Profile"}).getAttribute("href")).toBe("/settings/profile");
 expect(screen.queryByRole("link",{name:"Capture"})).toBeNull();
 expect(screen.queryByRole("link",{name:"Find"})).toBeNull();
});

test.each(["appearance", "developer", "help", "account"] as const)("settings %s page contains only its category", async section => {
 render(<SettingsClient email="tester@example.test" section={section} />);
 expect(screen.queryByLabelText("Display name")).toBeNull();
 expect(screen.queryByRole("button", { name: "Save changes" })).toBeNull();
 expect(screen.queryByRole("button", { name: "Refresh memory" })).toBeNull();
 expect(screen.queryByRole("button", { name: "Delete…" }) !== null).toBe(section === "account");
 expect(screen.queryByRole("button", { name: "Dark" }) !== null).toBe(section === "appearance");
 expect(screen.queryByRole("link", { name: "API keys" }) !== null).toBe(section === "developer");
 expect(accountRequest).not.toHaveBeenCalled();
});
test("settings categories use distinct page routes and keep their labels visible", async () => {
 mockPathname="/settings/appearance";
 const view=render(<AppShell><p>Appearance page</p></AppShell>);
 await screen.findByRole("link", { name: /Local tester.*Profile and settings/ });
 expect(screen.getByRole("link", { name: "Appearance" }).getAttribute("href")).toBe("/settings/appearance");
 expect(screen.getByRole("link", { name: "Appearance" }).getAttribute("aria-current")).toBe("page");
 expect(within(screen.getByLabelText("Primary navigation")).getByRole("link", { name: "Account" }).getAttribute("href")).toBe("/settings/account");
 expect(view.container.querySelector(".app-frame")?.classList.contains("sidebar-pinned")).toBe(true);
 expect(screen.queryByRole("button", { name: "Unpin navigation" })).toBeNull();
});
