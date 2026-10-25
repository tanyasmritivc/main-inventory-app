/** @jest-environment jsdom */
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { UpgradeCheckoutLink } from "@/components/site/upgrade-checkout-link";
import { UpgradeGate } from "@/components/site/upgrade-gate";
import { PricingClient } from "@/components/site/pricing-client";
jest.mock("@/lib/use-upgrade-permission", () => ({ useUpgradePermission: () => true }));
jest.mock("@/components/site/marketing-nav", () => ({ MarketingNav: () => null }));
jest.mock("@/components/site/product-marketing", () => ({ MarketingFooter: () => null }));

test("three plans show correct periods without offering an unconfigured purchase", async () => {
  render(<PricingClient />);
  for (const name of ["Free", "Plus", "Team"]) expect(screen.getByRole("heading", { name })).toBeTruthy();
  for (const price of ["$0", "$9.99", "$29"]) expect(screen.getByText(price)).toBeTruthy();
  for (const name of ["Pro", "Business", "Enterprise"]) expect(screen.queryByRole("heading", { name })).toBeNull();
  expect(screen.getByText("100 saved item records")).toBeTruthy();
  expect(screen.getByText("5 people included")).toBeTruthy();
  expect(screen.getByText("200 photo extractions per month, shared")).toBeTruthy();
  expect(screen.getAllByText("Unlimited Spaces")).toHaveLength(3);
  await userEvent.click(screen.getByRole("button", { name: "Yearly" }));
  for (const price of ["$99", "$299"]) expect(screen.getByText(price)).toBeTruthy();
  expect(screen.getByText("About $8.25/month, billed yearly")).toBeTruthy();
  expect(screen.getAllByRole("button", { name: /subscriptions coming soon/ }).every(button => (button as HTMLButtonElement).disabled)).toBe(true);
  expect(screen.getByRole("link", { name: "Get started free" }).getAttribute("href")).toBe("/signup");
  expect(screen.queryByRole("link", { name: /buy|checkout/i })).toBeNull();
  expect(screen.getByText(/You will not be charged automatically/)).toBeTruthy();
  expect(screen.queryByText(/November 2/)).toBeNull();
  expect(screen.getByText(/quantity of 500 count as one/)).toBeTruthy();
  await userEvent.click(screen.getByRole("button", { name: "Monthly" }));
  expect(screen.getByText("$9.99")).toBeTruthy();
});

test("legacy checkout is informational and limit counts remain server supplied", () => {
  render(<><UpgradeCheckoutLink /><UpgradeGate open onClose={() => {}} feature="photo_scan" current={5} limit={5} /></>);
  expect(screen.getByRole("link", { name: "Compare plans" }).getAttribute("href")).toBe("/pricing");
  expect(screen.getByText("Current usage: 5 of 5 (photo scan).")).toBeTruthy();
  expect(screen.getByText("50 photo extractions per month")).toBeTruthy();
  expect(screen.queryByText(/Unlimited photo|Upgrade to Pro/)).toBeNull();
  expect(screen.getByText(/You will not be charged automatically/)).toBeTruthy();
});
