/** @jest-environment jsdom */

import { render, screen, within } from "@testing-library/react";

import LandingPage from "@/app/page";

test("the landing page tells the capture → understand → index → recall story", () => {
  render(<LandingPage />);

  expect(screen.getByRole("heading", { level: 1 }).textContent).toBe(
    "FindEZ understandsyour environment.",
  );
  expect(screen.getByText("The physical world, understood as information.")).toBeTruthy();

  // the four beats of the scroll morph
  for (const beat of ["Capture", "Understand", "Index", "Recall"]) {
    expect(screen.getByText(beat)).toBeTruthy();
  }

  // the worked example survives in the markup, not just in the animation
  expect(screen.getAllByText("608 bearing").length).toBeGreaterThan(0);
  expect(screen.getAllByText("Machine shop · Drawer A04").length).toBeGreaterThan(0);

  // the one call to action stays in the top-right header
  const ctas = screen.getAllByRole("link", { name: /Get started/ });
  expect(ctas.length).toBe(1);
  for (const cta of ctas) expect(cta.getAttribute("href")).toBe("/signup");

  const header = within(document.querySelector("#hdr") as HTMLElement);
  expect(document.querySelector("#hdr img")?.getAttribute("src")).toContain("findez-logo.png");
  expect(header.getByRole("link", { name: "Developers" }).getAttribute("href")).toBe("/docs/api");
  expect(header.getByRole("link", { name: "iOS App" }).getAttribute("href")).toContain("apps.apple.com");
  expect(header.getByRole("link", { name: /Get started/ })).toBeTruthy();

  // the shared footer still carries the legal and developer links
  expect(screen.getAllByRole("link", { name: "Developers" }).length).toBe(2);
  expect(screen.getByRole("link", { name: "Privacy" })).toBeTruthy();
  expect(screen.getByRole("link", { name: "Contact" }).getAttribute("href")).toBe("mailto:info@findez.ai");
  expect(screen.queryByRole("link", { name: "Robotics Teams" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Product" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Pricing" })).toBeNull();
});
