/** @jest-environment jsdom */
import { render, screen, waitFor, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AppShell } from "@/components/site/app-shell";
import { SettingsClient } from "@/components/site/settings-client";
import { accountRequest } from "@/lib/account-request";

const session = {
  user: { id: "a", email: "tester@example.test", user_metadata: {} },
  access_token: "test-token",
};
const client = {
  auth: {
    getSession: jest.fn(async () => ({ data: { session } })),
    getUser: jest.fn(() => new Promise(() => {})),
    onAuthStateChange: jest.fn(() => ({
      data: { subscription: { unsubscribe: jest.fn() } },
    })),
  },
};
jest.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: () => client,
}));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/use-api-session", () => ({
  useApiSession: () => ({ accountId: "a" }),
}));
jest.mock("next/navigation", () => ({
  usePathname: () => "/settings",
  useRouter: () => ({
    push: jest.fn(),
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
  localStorage.clear();
  jest.clearAllMocks();
  jest
    .mocked(accountRequest)
    .mockImplementation(async (_id, path) =>
      path === "/notifications" ? { unread_count: 2 } : profile,
    );
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
