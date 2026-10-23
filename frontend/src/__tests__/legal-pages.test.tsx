/** @jest-environment jsdom */
import { fireEvent, render, screen } from "@testing-library/react";
import PrivacyPage from "@/app/privacy/page";
import TermsPage from "@/app/terms/page";
import { CookieNotice } from "@/components/site/cookie-notice";
import { LEGAL_VERSION } from "@/lib/legal-content";
jest.mock("@/lib/use-marketing-session", () => ({ useMarketingSession: () => false }));

test.each([[PrivacyPage, "October 18, 2026"], [TermsPage, "October 18, 2026"]] as const)("canonical legal pages have meaningful section targets and current verified contact", (Page, effectiveDate) => {
  const { container } = render(<Page />);
  expect(screen.getByText(`Effective ${effectiveDate}`)).toBeTruthy();
  expect(screen.getByText(/887 Poppy Ct, Sunnyvale, CA 94086/)).toBeTruthy();
  const contents = container.querySelector('nav[aria-label$="contents"]')!;
  for (const link of contents.querySelectorAll("a")) {
    expect(container.querySelector(link.getAttribute("href")!)).toBeTruthy();
  }
  expect(screen.queryByText("How it works")).toBeNull();
});
test("the privacy page describes actual storage and photo limitations without claiming optional consent", () => {
  render(<PrivacyPage />);
  expect(screen.getByText(/No optional analytics or advertising cookies/)).toBeTruthy();
  expect(screen.getByText(/photos require authenticated requests/)).toBeTruthy();
  expect(screen.getByText(/display window, not a promise/)).toBeTruthy();
  expect(screen.getByText(/not agreement to Terms/)).toBeTruthy();
});
test("the storage notice can be dismissed without enabling tracking or accepting Terms", () => {
  localStorage.removeItem("findez-cookie-notice");
  render(<CookieNotice />);
  expect(screen.getByRole("link", { name: "Details" }).getAttribute("href")).toBe("/privacy#cookies");
  expect(screen.queryByRole("button", { name: /accept all/i })).toBeNull();
  fireEvent.click(screen.getByRole("button", { name: "Got it" }));
  expect(localStorage.getItem("findez-cookie-notice")).toBe(LEGAL_VERSION);
  expect(screen.queryByLabelText("Cookies and device storage")).toBeNull();
});
