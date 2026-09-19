/** @jest-environment jsdom */

import { render, screen, within } from "@testing-library/react";

import LandingPage from "@/app/page";

beforeAll(() => {
  Object.defineProperty(HTMLCanvasElement.prototype, "getContext", {
    configurable: true,
    value: jest.fn(() => null),
  });
});

test("the landing page tells the segment, resolve, index, recall story", () => {
  render(<LandingPage />);

  expect(screen.getByRole("heading", { level: 1 }).textContent).toBe(
    "Turn physical objects intosearchable inventory.",
  );
  expect(
    screen.getByText(
      "Not a chatbot on top of a database. A pipeline that understands what is actually in the room.",
    ),
  ).toBeTruthy();

  // the four beats of the scroll morph
  for (const beat of ["Segment", "Resolve", "Index", "Recall"]) {
    expect(screen.getByText(beat)).toBeTruthy();
  }

  // the worked example survives in the markup, not just in the animation
  expect(screen.getAllByText("M4 socket screw").length).toBeGreaterThan(0);
  expect(screen.getAllByText("Fastener cabinet · Drawer 12").length).toBeGreaterThan(0);

  // the one call to action stays in the top-right header
  const ctas = screen.getAllByRole("link", { name: /Get started/ });
  expect(ctas.length).toBe(1);
  for (const cta of ctas) expect(cta.getAttribute("href")).toBe("/signup");

  const header = within(document.querySelector("#hdr") as HTMLElement);
  // the lockup is an inline mark so it inherits colour when the header crosses a dark section
  expect(document.querySelector("#hdr svg.logo")).toBeTruthy();
  expect(document.querySelector("#hdr img")).toBeNull();
  expect(header.getByRole("link", { name: "Developers" }).getAttribute("href")).toBe("/docs/api");
  expect(header.getByRole("link", { name: "iOS App" }).getAttribute("href")).toBe("https://apps.apple.com/us/app/findez-ai/id6760401697");
  expect(header.getByRole("link", { name: /Get started/ })).toBeTruthy();

  // the shared footer still carries the legal and developer links
  expect(screen.getAllByRole("link", { name: "Developers" }).length).toBe(2);
  expect(screen.getByRole("link", { name: "Privacy" })).toBeTruthy();
  expect(screen.getByRole("link", { name: "Contact" }).getAttribute("href")).toBe("mailto:info@findez.ai");
  expect(screen.getByText("© 2026 AI Robots Inc.")).toBeTruthy();
  expect(screen.queryByRole("link", { name: "Robotics Teams" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Product" })).toBeNull();
  expect(screen.queryByRole("link", { name: "Pricing" })).toBeNull();
});
