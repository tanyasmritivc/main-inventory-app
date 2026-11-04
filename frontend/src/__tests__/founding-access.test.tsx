/** @jest-environment jsdom */
import React from "react";
import { act, cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { FoundingAccessProvider, FoundingPlanCard, foundingVersion } from "@/components/founding-access/founding-access";

let serial = 0;
const old = "2025-01-01T00:00:00Z";
function fixture(id: string, createdAt = old, pathname = "/settings/plans") {
  return <FoundingAccessProvider accountId={id} createdAt={createdAt} pathname={pathname}>
    <button>Previous focus</button><FoundingPlanCard accountId={id} />
  </FoundingAccessProvider>;
}
async function settled() { await act(async () => { jest.advanceTimersByTime(601); }); }
beforeEach(() => { jest.useFakeTimers(); localStorage.clear(); HTMLElement.prototype.scrollTo = jest.fn(); });
afterEach(() => { cleanup(); jest.useRealTimers(); jest.restoreAllMocks(); });

test("new accounts receive the signup version after settling; focus starts on the container", async () => {
  render(fixture(`fresh-${++serial}`, new Date().toISOString()));
  expect(screen.queryByRole("dialog")).toBeNull();
  await settled();
  const dialog = screen.getByRole("dialog", { name: "You're in early." });
  expect(document.activeElement).toBe(dialog);
  expect(document.body.hasAttribute("data-scroll-locked")).toBe(true);
});

test("older accounts dismiss through Get started, remember across reload, and receive the hint", async () => {
  const id = `older-${++serial}`;
  const { unmount } = render(fixture(id));
  await settled();
  expect(screen.getByRole("dialog", { name: "You're a Founding member." })).toBeTruthy();
  fireEvent.click(screen.getByRole("button", { name: "Get started" }));
  expect(localStorage.getItem(`findez_founding_seen_${id}`)).toBe("true");
  expect(screen.getByRole("status").textContent).toBe("Ask anything, or add your first items with +");
  unmount(); render(fixture(id)); await settled();
  expect(screen.queryByRole("dialog")).toBeNull();
});

test.each(["close", "escape", "outside", "got-it"])("%s dismissal persists and restores focus", async method => {
  const id = `close-${method}-${++serial}`;
  render(fixture(id));
  const previous = screen.getByRole("button", { name: "Previous focus" }); previous.focus();
  await settled();
  if (method === "close") fireEvent.click(screen.getByRole("button", { name: "Close Founding Access" }));
  if (method === "escape") fireEvent.keyDown(document.activeElement!, { key: "Escape" });
  if (method === "outside") {
    // Radix subscribes to pointerdown outside on the next task.
    await act(async () => { jest.advanceTimersByTime(1); });
    fireEvent.pointerDown(document.body, { pointerType: "mouse", button: 0 });
  }
  if (method === "got-it") {
    fireEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "See what's included" }));
    fireEvent.click(screen.getByRole("button", { name: "Got it" }));
  }
  await act(async () => { jest.advanceTimersByTime(1); });
  expect(screen.queryByRole("dialog")).toBeNull();
  expect(localStorage.getItem(`findez_founding_seen_${id}`)).toBe("true");
  expect(document.activeElement).toBe(previous);
});

test("Plans opens Your plan without Back; table keeps accessible inclusion labels", async () => {
  const id = `plan-${++serial}`; localStorage.setItem(`findez_founding_seen_${id}`, "true");
  render(fixture(id)); await settled();
  const button = screen.getByRole("button", { name: "See what's included" }); button.focus(); fireEvent.click(button);
  const dialog = screen.getByRole("dialog", { name: "Your plan" });
  expect(within(dialog).queryByRole("button", { name: "Back" })).toBeNull();
  expect(within(dialog).getAllByRole("row")).toHaveLength(8);
  expect(within(dialog).getAllByText("Included")).toHaveLength(10);
  fireEvent.click(screen.getByRole("button", { name: "Got it" }));
  await act(async () => { jest.advanceTimersByTime(1); }); expect(document.activeElement).toBe(button);
});

test("details and Back keep focus in the dialog; Tab wraps", async () => {
  render(fixture(`details-${++serial}`)); await settled();
  fireEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "See what's included" }));
  expect(document.activeElement).toBe(screen.getByRole("dialog", { name: "What's included" }));
  fireEvent.click(screen.getByRole("button", { name: "Back" }));
  expect(document.activeElement).toBe(screen.getByRole("dialog", { name: "You're a Founding member." }));
  const last = screen.getByRole("button", { name: "Get started" }); last.focus();
  fireEvent.keyDown(last, { key: "Tab" });
  expect(document.activeElement).toBe(screen.getByRole("button", { name: "Close Founding Access" }));
});

test("waits for an existing modal, then starts its 600ms settle delay", async () => {
  const blocker = document.createElement("div"); blocker.setAttribute("role", "dialog"); blocker.setAttribute("aria-modal", "true"); document.body.append(blocker);
  render(fixture(`blocked-${++serial}`)); await settled();
  expect(document.querySelector("[data-founding-dialog]")).toBeNull();
  await act(async () => { blocker.remove(); });
  await act(async () => { jest.advanceTimersByTime(599); });
  expect(screen.queryByRole("dialog")).toBeNull();
  await settled(); expect(screen.getByRole("dialog")).toBeTruthy();
});

test.each(["/", "/signin", "/signup", "/pricing"])("never opens on public %s", async path => {
  render(fixture(`public-${++serial}`, old, path)); await settled();
  fireEvent.click(screen.getByRole("button", { name: "See what's included" }));
  expect(screen.queryByRole("dialog")).toBeNull();
});

test("storage failures cannot block dismissal or repeat within the session", async () => {
  jest.spyOn(Storage.prototype, "getItem").mockImplementation(() => { throw new Error("denied"); });
  jest.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new Error("quota"); });
  const id = `storage-${++serial}`; const { unmount } = render(fixture(id)); await settled();
  fireEvent.click(screen.getByRole("button", { name: "Close Founding Access" }));
  expect(screen.queryByRole("dialog")).toBeNull();
  unmount(); render(fixture(id)); await settled(); expect(screen.queryByRole("dialog")).toBeNull();
});

test("account switch discards the first dialog without marking the second account seen", async () => {
  const a = `account-a-${++serial}`, b = `account-b-${serial}`;
  const { rerender } = render(fixture(a)); await settled();
  rerender(fixture(b, new Date().toISOString()));
  expect(screen.queryByRole("dialog")).toBeNull();
  await settled(); expect(screen.getByRole("dialog", { name: "You're in early." })).toBeTruthy();
  fireEvent.click(screen.getByRole("button", { name: "Close Founding Access" }));
  expect(localStorage.getItem(`findez_founding_seen_${a}`)).toBeNull();
  expect(localStorage.getItem(`findez_founding_seen_${b}`)).toBe("true");
});

test("creation timestamp boundary and malformed/future timestamps use the returning copy", () => {
  const now = Date.parse("2026-11-04T00:00:00Z");
  expect(foundingVersion(new Date(now - 899999).toISOString(), now)).toBe("signup");
  for (const date of [new Date(now - 900000).toISOString(), new Date(now + 1000).toISOString(), "invalid", null]) expect(foundingVersion(date, now)).toBe("signin");
});
