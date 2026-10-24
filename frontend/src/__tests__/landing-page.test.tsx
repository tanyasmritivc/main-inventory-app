/** @jest-environment jsdom */
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import LandingPage, { metadata } from "@/app/page";
import { SiteNav } from "@/components/site/nav";
const push = jest.fn();
const unsubscribe = jest.fn();
let authChanged: (event: string, session: object | null) => void;
jest.mock("next/font/google", () => ({
  Plus_Jakarta_Sans: () => ({ variable: "landing-jakarta" }),
  Geist_Mono: () => ({ variable: "landing-mono" }),
}));
jest.mock("next/dynamic", () => ({ __esModule: true, default: () => () => null }));
jest.mock("@/components/landing-v3/useScrollProgress", () => ({ useScrollProgress: () => ({ motion: {current: {}}, registerTools: jest.fn() }) }));
jest.mock("@/lib/supabase/browser", () => ({ createSupabaseBrowserClient: () => ({ auth: {
  onAuthStateChange: (listener: typeof authChanged) => { authChanged = listener; return { data: { subscription: { unsubscribe } } }; },
} }) }));
jest.mock("next/navigation", () => ({ usePathname: () => "/pricing", useRouter: () => ({ push }) }));
beforeEach(() => jest.clearAllMocks());

test("homepage preserves the requested copy, sections, metadata and destinations", async () => {
  render(await LandingPage());
  expect(screen.getByRole("heading", {level: 1}).textContent).toBe("Describe your world.");
  expect(screen.getByText("Snap a shelf or type a list to build an inventory.")).toBeTruthy();
  for (const id of ["storyA", "who", "biz", "app", "sync", "end"]) expect(document.getElementById(id)).toBeTruthy();
  expect(document.querySelectorAll("[data-drawer]")).toHaveLength(48);
  const header = within(screen.getByRole("navigation", { name: "Main navigation" }));
  expect(header.getByRole("link", {name: "Get started ↗"}).getAttribute("href")).toBe("/signup");
  const footer = within(screen.getByRole("navigation", {name: "Footer navigation"}));
  const destinations = { Plans: "/pricing", Developers: "/docs/api", "iOS App": "https://apps.apple.com/us/app/findez-ai/id6760401697", Privacy: "/privacy", Terms: "/terms", Contact: "mailto:info@findez.ai" };
  for (const [name, href] of Object.entries(destinations)) expect(footer.getByRole("link", {name}).getAttribute("href")).toBe(href);
  expect(screen.getByRole("link", {name: "Business inquiries ↗"}).getAttribute("href")).toBe("mailto:info@findez.ai?subject=FindEZ%20business%20inquiry");
  expect(metadata.title).toEqual({absolute: "FindEZ AI | AI memory for the physical world"});
  expect(metadata.alternates).toEqual({canonical: "/"});
  expect(metadata.openGraph).toMatchObject({url: "https://findez.ai/"});
});

test("the composer forwards encoded text and its attachment controls open signup", async () => {
  render(await LandingPage());
  fireEvent.change(screen.getByRole("textbox"), {target: {value: "  M3 screws & tools / 20  "}});
  fireEvent.submit(document.getElementById("cform")!);
  expect(push).toHaveBeenLastCalledWith("/signup?prompt=M3%20screws%20%26%20tools%20%2F%2020");
  fireEvent.change(screen.getByRole("textbox"), {target: {value: "   "}});
  fireEvent.submit(document.getElementById("cform")!);
  expect(push).toHaveBeenLastCalledWith("/signup");
  for (const name of ["Attach", "Take a photo", "Speak"]) {
    fireEvent.click(screen.getByRole("button", {name}));
    expect(push).toHaveBeenLastCalledWith("/signup");
  }
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
