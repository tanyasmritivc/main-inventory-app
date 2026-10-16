/** @jest-environment jsdom */

import { act, render, screen, within } from "@testing-library/react";

import LandingPage, { metadata } from "@/app/page";
import { SiteNav } from "@/components/site/nav";

const getUser = jest.fn();
const unsubscribe = jest.fn();
let authChanged: (event: string, session: object | null) => void;

jest.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: async () => ({ auth: { getUser } }),
}));
jest.mock("next/font/google", () => ({
  Geist: () => ({ variable: "lab-geist" }),
  Geist_Mono: () => ({ variable: "lab-mono" }),
}));
jest.mock("@/components/site/landing-lab-engine", () => ({
  ...jest.requireActual("@/components/site/landing-lab-engine"),
  initLandingLab: () => () => {},
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

test("the homepage publishes the approved Lab design with its original destinations", async () => {
  render(await LandingPage());
  expect(screen.getByRole("heading", { level: 1 }).textContent).toBe(
    "FindEZ gives the physical world a memory.",
  );
  expect(document.querySelectorAll(".fzLab")).toHaveLength(1);
  expect(document.querySelector(".fzLab.lab-geist.lab-mono")).toBeTruthy();
  for (const id of ["hero", "stmt", "see", "graph", "zoom", "ask", "own", "who", "find", "vision", "app", "waitlist", "end"]) {
    expect(document.getElementById(id)).toBeTruthy();
  }
  const header = within(screen.getByRole("navigation", { name: "Main navigation" }));
  expect(header.getAllByRole("link").map(link => link.textContent)).toEqual(["Developers", "iOS App", "Get started↗"]);
  expect(header.getByRole("link", { name: "Developers" }).getAttribute("href")).toBe("/docs/api");
  expect(header.getByRole("link", { name: "iOS App" }).getAttribute("href")).toBe("https://apps.apple.com/us/app/findez-ai/id6760401697");
  const footer = within(screen.getByRole("navigation", { name: "Footer navigation" }));
  const destinations = { Plans: "/pricing", Developers: "/docs/api", "iOS App": "https://apps.apple.com/us/app/findez-ai/id6760401697", Privacy: "/privacy", Terms: "/terms", Contact: "mailto:info@findez.ai" };
  for (const [name, href] of Object.entries(destinations)) expect(footer.getByRole("link", { name }).getAttribute("href")).toBe(href);
  expect(screen.getByRole("navigation", { name: "Footer navigation" }).closest("footer")?.id).toBe("end");
  expect(screen.getAllByText("© 2026 AI Robots Inc.")).toHaveLength(1);
  for (const link of screen.getAllByRole("link", { name: "Get started" })) {
    expect(link.getAttribute("href")).toBe("/signup");
  }
  expect(screen.getByRole("link", { name: "Try FindEZ on the web" }).getAttribute("href")).toBe("/signup");
  for (const link of screen.getAllByRole("link", { name: "Join the iPhone waitlist" })) expect(link.getAttribute("href")).toBe("#waitlist");
});

test("the homepage preserves the signed-in Dashboard and follows session changes", async () => {
  getUser.mockResolvedValue({ data: { user: { id: "returning-user" } }, error: null });
  const { unmount } = render(await LandingPage());
  const header = within(screen.getByRole("navigation", { name: "Main navigation" }));
  expect(header.getByRole("link", { name: "Dashboard" }).getAttribute("href")).toBe("/home");
  act(() => authChanged("SIGNED_OUT", null));
  expect(header.getByRole("link", { name: "Get started" }).getAttribute("href")).toBe("/signup");
  act(() => authChanged("SIGNED_IN", { user: { id: "new-user" } }));
  expect(header.getByRole("link", { name: "Dashboard" }).getAttribute("href")).toBe("/home");
  unmount();
  expect(unsubscribe).toHaveBeenCalledTimes(1);
});

test("an unavailable auth response leaves the public homepage available", async () => {
  getUser.mockResolvedValue({ data: { user: null }, error: { message: "Auth unavailable" } });
  render(await LandingPage());
  expect(screen.getByRole("heading", { level: 1 })).toBeTruthy();
  expect(within(screen.getByRole("navigation", { name: "Main navigation" })).getByRole("link", { name: "Get started" }).getAttribute("href")).toBe("/signup");
});

test("the published homepage keeps its public search metadata", () => {
  expect(metadata.alternates).toEqual({ canonical: "/" });
  expect(metadata.robots).toBeUndefined();
  expect(metadata.openGraph).toMatchObject({ url: "https://findez.ai/" });
});

test("simple public navigation follows session changes and unsubscribes", () => {
  const { unmount } = render(<SiteNav variant="marketing" />);
  expect(screen.getByRole("link", { name: "Sign in" })).toBeTruthy();
  act(() => authChanged("INITIAL_SESSION", { user: { id: "returning-user" } }));
  expect(screen.queryByRole("link", { name: "Sign in" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Start free" })).toBeNull();
  expect(screen.getByRole("link", { name: "Dashboard" }).getAttribute("href")).toBe("/home");
  expect(screen.queryByRole("button", { name: "Toggle navigation" })).toBeNull();
  act(() => authChanged("SIGNED_OUT", null));
  expect(screen.getByRole("link", { name: "Sign in" }).getAttribute("href")).toBe("/signin");
  unmount();
  expect(unsubscribe).toHaveBeenCalledTimes(1);
});
