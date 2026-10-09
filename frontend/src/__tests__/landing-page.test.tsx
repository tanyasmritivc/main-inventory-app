/** @jest-environment jsdom */

import { act, render, screen, within } from "@testing-library/react";

import LandingPage from "@/app/page";
import { SiteNav } from "@/components/site/nav";

const getUser = jest.fn();
const unsubscribe = jest.fn();
let authChanged: (event: string, session: object | null) => void;

jest.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: async () => ({ auth: { getUser } }),
}));
jest.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: () => ({
    auth: {
      onAuthStateChange: (listener: typeof authChanged) => {
        authChanged = listener;
        return { data: { subscription: { unsubscribe } } };
      },
    },
  }),
}));
jest.mock("next/navigation", () => ({ usePathname: () => "/pricing" }));

beforeEach(() => {
  jest.clearAllMocks();
  getUser.mockResolvedValue({ data: { user: null }, error: null });
});

beforeAll(() => {
  Object.defineProperty(HTMLCanvasElement.prototype, "getContext", {
    configurable: true,
    value: jest.fn(() => null),
  });
});

test("the landing page tells the segment, resolve, index, recall story", async () => {
  render(await LandingPage());

  expect(screen.getByRole("heading", { level: 1 }).textContent).toBe(
    "Turn physical objects intosearchable inventory.",
  );
  expect(
    screen.queryByText(/Not a chatbot on top of a database/),
  ).toBeNull();

  // the four beats of the scroll morph
  for (const beat of ["Segment", "Resolve", "Index", "Recall"]) {
    expect(screen.getByText(beat)).toBeTruthy();
  }

  // the worked example survives in the markup, not just in the animation
  expect(screen.getAllByText("M4 socket screw").length).toBeGreaterThan(0);
  expect(screen.getAllByText("Fastener cabinet · Drawer 12").length).toBeGreaterThan(0);

  // the one call to action stays in the top-right header
  const ctas = screen.getAllByRole("link", { name: /Get started/ });
  expect(ctas.length).toBe(1);
  for (const cta of ctas) expect(cta.getAttribute("href")).toBe("/signup");

  const header = within(document.querySelector("#hdr") as HTMLElement);
  // the lockup is an inline mark so it inherits colour when the header crosses a dark section
  expect(document.querySelector("#hdr svg.logo")).toBeTruthy();
  expect(document.querySelector("#hdr img")).toBeNull();
  expect(header.getByRole("link", { name: "Developers" }).getAttribute("href")).toBe("/docs/api");
  expect(header.getByRole("link", { name: "iOS App" }).getAttribute("href")).toBe("https://apps.apple.com/us/app/findez-ai/id6760401697");
  expect(header.getByRole("link", { name: /Get started/ })).toBeTruthy();

  // the shared footer still carries the legal and developer links
  expect(screen.getAllByRole("link", { name: "Developers" }).length).toBe(2);
  expect(screen.getByRole("link", { name: "Privacy" })).toBeTruthy();
  expect(screen.getByRole("link", { name: "Contact" }).getAttribute("href")).toBe("mailto:info@findez.ai");
  expect(screen.getByText("© 2026 AI Robots Inc.")).toBeTruthy();
  expect(screen.queryByRole("link", { name: "Robotics Teams" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Product" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Pricing" })).toBeNull();
});

test("a signed-in landing visitor receives Dashboard on the first render", async () => {
  getUser.mockResolvedValue({ data: { user: { id: "returning-user" } }, error: null });
  render(await LandingPage());

  const header = within(document.querySelector("#hdr") as HTMLElement);
  expect(header.getByRole("link", { name: /Dashboard/ }).getAttribute("href")).toBe("/home");
  expect(header.queryByRole("link", { name: /Get started|Sign in/ })).toBeNull();

  act(() => authChanged("SIGNED_OUT", null));
  expect(header.getByRole("link", { name: /Get started/ }).getAttribute("href")).toBe("/signup");
  act(() => authChanged("SIGNED_IN", { user: { id: "new-user" } }));
  expect(header.getByRole("link", { name: /Dashboard/ }).getAttribute("href")).toBe("/home");
});

test("a failed server user verification leaves the public landing page available", async () => {
  getUser.mockResolvedValue({ data: { user: null }, error: { message: "Auth unavailable" } });
  render(await LandingPage());
  expect(screen.getByRole("heading", { level: 1 })).toBeTruthy();
  expect(screen.getByRole("link", { name: /Get started/ }).getAttribute("href")).toBe("/signup");
});

test("marketing desktop and mobile actions follow session changes and unsubscribe", () => {
  const { unmount } = render(<SiteNav variant="marketing" />);
  expect(screen.getByRole("link", { name: "Sign in" })).toBeTruthy();
  act(() => authChanged("INITIAL_SESSION", { user: { id: "returning-user" } }));
  expect(screen.queryByRole("link", { name: "Sign in" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Start free" })).toBeNull();
  expect(screen.getByRole("link", { name: "Dashboard" }).getAttribute("href")).toBe("/home");
  act(() => screen.getByRole("button", { name: "Toggle navigation" }).click());
  const mobile = within(screen.getByRole("navigation", { name: "Mobile marketing navigation" }));
  expect(mobile.getByRole("link", { name: "Dashboard" }).getAttribute("href")).toBe("/home");
  act(() => mobile.getByRole("link", { name: "Dashboard" }).click());
  expect(screen.queryByRole("navigation", { name: "Mobile marketing navigation" })).toBeNull();
  act(() => authChanged("SIGNED_OUT", null));
  expect(screen.getByRole("link", { name: "Sign in" }).getAttribute("href")).toBe("/signin");
  unmount();
  expect(unsubscribe).toHaveBeenCalledTimes(1);
});
