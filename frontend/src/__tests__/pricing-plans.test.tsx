/** @jest-environment jsdom */
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PricingClient } from "@/components/site/pricing-client";
jest.mock("@/components/site/marketing-nav", () => ({ MarketingNav: () => null }));
jest.mock("@/components/site/product-marketing", () => ({ MarketingFooter: () => null }));

test("five plans show correct periods without offering an unconfigured purchase", async () => {
  render(<PricingClient />);
  for (const name of ["Free", "Pro", "Team", "Business", "Enterprise"]) expect(screen.getByRole("heading", { name })).toBeTruthy();
  for (const price of ["$19", "$99", "$299"]) expect(screen.getByText(price)).toBeTruthy();
  await userEvent.click(screen.getByRole("button", { name: "Yearly" }));
  for (const price of ["$149", "$790", "$2,490"]) expect(screen.getByText(price)).toBeTruthy();
  expect(screen.getByText("About $12.42/month, billed yearly")).toBeTruthy();
  expect(screen.getAllByRole("button", { name: /subscriptions coming soon/ }).every(button => (button as HTMLButtonElement).disabled)).toBe(true);
  expect(screen.getByRole("link", { name: "Get started free" }).getAttribute("href")).toBe("/signup");
  expect(screen.queryByRole("link", { name: /buy|checkout/i })).toBeNull();
});
