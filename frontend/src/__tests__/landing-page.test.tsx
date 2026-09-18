/** @jest-environment jsdom */

import { render, screen } from "@testing-library/react";

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

  // every call to action points at signup
  const ctas = screen.getAllByRole("link", { name: /Get started/ });
  expect(ctas.length).toBe(3);
  for (const cta of ctas) expect(cta.getAttribute("href")).toBe("/signup");

  // the shared footer still carries the legal and developer links
  expect(screen.getByRole("link", { name: "Developers" }).getAttribute("href")).toBe("/docs/api");
  expect(screen.getByRole("link", { name: "Privacy" })).toBeTruthy();
  expect(screen.queryByRole("link", { name: "Pricing" })).toBeNull();
});
