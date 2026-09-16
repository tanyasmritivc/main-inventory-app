/** @jest-environment jsdom */

import { render, screen } from "@testing-library/react";

import LandingPage from "@/app/page";

jest.mock("next/navigation", () => ({
  usePathname: () => "/",
}));

test("keeps the landing page concise and demonstrates the FindEZ workflow", () => {
  render(<LandingPage />);

  expect(screen.getByRole("heading", { level: 1 }).textContent).toBe(
    "Know what you have.Find it.",
  );
  expect(screen.getByText("Where are the 608 bearings?")).toBeTruthy();
  expect(screen.getByText("Drawer A04")).toBeTruthy();
  expect(screen.getAllByRole("link", { name: "Developers" }).map((link) => link.getAttribute("href"))).toEqual([
    "/docs/api",
    "/docs/api",
  ]);
  expect(screen.queryByRole("link", { name: "Pricing" })).toBeNull();
});
