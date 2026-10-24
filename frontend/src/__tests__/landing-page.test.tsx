/** @jest-environment jsdom */
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import LandingPage, { metadata } from "@/app/page";
import { SiteNav } from "@/components/site/nav";
const push = jest.fn();
const mockRouter = { push, prefetch: jest.fn() };
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
jest.mock("next/navigation", () => ({ usePathname: () => "/pricing", useRouter: () => mockRouter }));
beforeEach(() => {
  jest.clearAllMocks(); sessionStorage.clear();
  Object.defineProperty(window, "matchMedia", { writable: true, value: () => ({ matches: true, addEventListener() {}, removeEventListener() {} }) });
});

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

test.each([false, true])("composer goes directly to auth with reduced motion %s", async reduced => {
  Object.defineProperty(window, "matchMedia", { writable: true, value: () => ({ matches: reduced, addEventListener() {}, removeEventListener() {} }) });
  render(await LandingPage());
  const prompt = "Add 20 M3 screws & 2 cables";
  fireEvent.change(screen.getByRole("textbox"), {target: {value: prompt}});
  fireEvent.submit(document.getElementById("cform")!);
  fireEvent.submit(document.getElementById("cform")!);
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(push).toHaveBeenCalledTimes(1);
  expect(push).toHaveBeenCalledWith(`/signup?prompt=${encodeURIComponent(prompt)}`);
  expect(screen.getByRole("button", {name: "Send"})).toHaveProperty("disabled", true);
  expect(JSON.parse(sessionStorage.getItem("findez_public_preview_draft")!).prompt).toBe(prompt);
});

test("empty prompts focus the composer; attachment controls still open signup", async () => {
  render(await LandingPage());
  fireEvent.submit(document.getElementById("cform")!);
  expect(document.activeElement).toBe(screen.getByRole("textbox"));
  expect(push).not.toHaveBeenCalled();
  expect(screen.queryByRole("dialog")).toBeNull();
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


test("Enter submits directly while Shift Enter and IME composition do not", async () => {
  render(await LandingPage());
  const input = screen.getByRole("textbox");
  fireEvent.change(input, { target: { value: "Add 10 screws" } });
  fireEvent.keyDown(input, { key: "Enter", isComposing: true });
  fireEvent.keyDown(input, { key: "Enter", shiftKey: true });
  expect(push).not.toHaveBeenCalled();
  fireEvent.keyDown(input, { key: "Enter" });
  expect(push).toHaveBeenCalledWith("/signup?prompt=Add%2010%20screws");
  expect(screen.queryByRole("dialog")).toBeNull();
});

test("Back can recover the recent prompt without restoring expired or corrupt drafts", async () => {
  sessionStorage.setItem("findez_public_preview_draft", JSON.stringify({ at: Date.now(), prompt: "Add 4 cables" }));
  const first = render(await LandingPage());
  expect(screen.getByRole("textbox")).toHaveProperty("value", "Add 4 cables");
  first.unmount();
  sessionStorage.setItem("findez_public_preview_draft", JSON.stringify({ at: Date.now() - 31 * 60 * 1000, prompt: "old request" }));
  const second = render(await LandingPage());
  expect(screen.getByRole("textbox")).toHaveProperty("value", "");
  second.unmount();
  sessionStorage.setItem("findez_public_preview_draft", "not json");
  render(await LandingPage());
  expect(screen.getByRole("textbox")).toHaveProperty("value", "");
});
