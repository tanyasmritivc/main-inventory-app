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

test("composer opens an explorable demo before signup and preserves the request", async () => {
  jest.useFakeTimers();
  render(await LandingPage());
  fireEvent.change(screen.getByRole("textbox"), {target: {value: "Add 10 AA batteries and 2 cables"}});
  fireEvent.submit(document.getElementById("cform")!);
  act(() => jest.runOnlyPendingTimers());
  expect(push).not.toHaveBeenCalled();
  const dialog = within(screen.getByRole("dialog"));
  expect(dialog.getByText("AA batteries")).toBeTruthy();
  expect(dialog.getByText("Qty 10")).toBeTruthy();
  fireEvent.change(dialog.getByRole("textbox", {name: "Filter preview items"}), {target: {value: "batter"}});
  expect(dialog.queryByText("cables")).toBeNull();
  fireEvent.click(dialog.getByRole("button", {name: /AA batteries/}));
  expect(dialog.getByText(/Confirm the quantity when you save/)).toBeTruthy();
  fireEvent.click(dialog.getByRole("button", {name: "Sign up to save"}));
  fireEvent.click(dialog.getByRole("button", {name: "Open full app"}));
  act(() => jest.runOnlyPendingTimers());
  expect(push).toHaveBeenCalledTimes(1);
  expect(push).toHaveBeenCalledWith("/signup?prompt=Add%2010%20AA%20batteries%20and%202%20cables");
  jest.useRealTimers();
});

test("empty prompts stay in the composer; edit restores focus and cancel never navigates", async () => {
  jest.useFakeTimers();
  render(await LandingPage());
  const input = screen.getByRole("textbox");
  fireEvent.submit(document.getElementById("cform")!);
  expect(screen.queryByRole("dialog")).toBeNull();
  fireEvent.change(input, {target: {value: "Organize my garage"}});
  fireEvent.submit(document.getElementById("cform")!);
  fireEvent.click(screen.getByRole("button", {name: "Edit prompt"}));
  act(() => jest.runOnlyPendingTimers());
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(input).toHaveProperty("value", "Organize my garage");
  expect(document.activeElement).toBe(input);
  expect(push).not.toHaveBeenCalled();
  for (const name of ["Attach", "Take a photo", "Speak"]) {
    fireEvent.click(screen.getByRole("button", {name}));
    expect(push).toHaveBeenLastCalledWith("/signup");
  }
  jest.useRealTimers();
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


test("animated preview stages cancel safely and IME Enter does not submit", async () => {
  jest.useFakeTimers();
  Object.defineProperty(window, "matchMedia", { writable: true, value: () => ({ matches: false, addEventListener() {}, removeEventListener() {} }) });
  const cancel = jest.fn();
  const animate = jest.fn(() => ({ cancel }));
  Object.defineProperty(HTMLElement.prototype, "animate", { configurable: true, value: animate });
  const { unmount } = render(await LandingPage());
  const input = screen.getByRole("textbox");
  fireEvent.change(input, { target: { value: "Add 10 screws" } });
  fireEvent.keyDown(input, { key: "Enter", isComposing: true });
  expect(screen.queryByRole("dialog")).toBeNull();
  fireEvent.submit(document.getElementById("cform")!);
  expect(screen.getByText("Your words, taking shape.")).toBeTruthy();
  expect(animate).toHaveBeenCalledWith(expect.any(Array), expect.objectContaining({ duration: 650 }));
  fireEvent.click(screen.getByRole("button", { name: "Close preview" }));
  act(() => jest.advanceTimersByTime(2000));
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(cancel).toHaveBeenCalled();
  expect(push).not.toHaveBeenCalled();
  unmount();
  delete (HTMLElement.prototype as unknown as { animate?: unknown }).animate;
  jest.useRealTimers();
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
