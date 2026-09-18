/** @jest-environment jsdom */

import { render, screen } from "@testing-library/react";

import ProductPage from "@/app/product/page";
import AskPage from "@/app/product/ask/page";
import CapturePage from "@/app/product/capture/page";
import SpacesAndSharingPage from "@/app/product/spaces-and-sharing/page";

jest.mock("next/navigation", () => ({
  usePathname: () => "/product",
}));

test("explains the FindEZ workflow with concrete product information", () => {
  render(<ProductPage />);

  expect(screen.getByRole("heading", { level: 1 }).textContent).toBe(
    "From a photo to a place you can search.",
  );
  expect(screen.getByRole("heading", { name: "Bring in the inventory you already have." })).toBeTruthy();
  expect(screen.getByRole("heading", { name: "Organize it like the real space." })).toBeTruthy();
  expect(screen.getByRole("heading", { name: "Find the answer, not another list." })).toBeTruthy();
  expect(screen.getAllByText("Where are the 608 bearings?").length).toBeGreaterThan(0);
  expect(screen.getByText("Machine shop · Drawer A04")).toBeTruthy();
});

test("offers FindEZ-specific destinations from the public navigation", () => {
  render(<ProductPage />);

  expect(screen.getByRole("link", { name: /Capture inventory/ }).getAttribute("href")).toBe("/product/capture");
  expect(screen.getByRole("link", { name: /Give everything a place/ }).getAttribute("href")).toBe("/product/spaces-and-sharing");
  expect(screen.getByRole("link", { name: /AI assistants/ }).getAttribute("href")).toBe("/docs/api#ai-assistants");
});

test.each([
  [CapturePage, "Add inventory without starting over.", "Review, place, then find."],
  [SpacesAndSharingPage, "A Space is where inventory lives.", "Share access, not duplicate lists."],
  [AskPage, "Ask where it is. Update it there.", "Answers lead back to the record."],
])("gives each product detail page a concrete workflow", (Page, hero, section) => {
  render(<Page />);

  expect(screen.getByRole("heading", { level: 1, name: hero })).toBeTruthy();
  expect(screen.getByRole("heading", { name: section })).toBeTruthy();
});
