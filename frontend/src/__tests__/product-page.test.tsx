/** @jest-environment jsdom */
import { render, screen } from "@testing-library/react";
import { redirect } from "next/navigation";
import ProductPage from "@/app/product/page";
import AskPage from "@/app/product/ask/page";
import CapturePage from "@/app/product/capture/page";
import SpacesPage from "@/app/product/spaces-and-sharing/page";
import RoboticsPage from "@/app/robotics/page";
import { SiteNav } from "@/components/site/nav";
import { useMarketingSession } from "@/lib/use-marketing-session";
jest.mock("next/navigation", () => ({ redirect: jest.fn() }));
jest.mock("@/lib/use-marketing-session", () => ({ useMarketingSession: jest.fn(() => false) }));
beforeEach(() => jest.clearAllMocks());

test.each([[ProductPage, "/home"], [AskPage, "/assist"], [CapturePage, "/scan"], [SpacesPage, "/spaces"], [RoboticsPage, "/teams"]])("legacy feature links open the actual function instead of repeating the landing page", (Page, target) => {
  Page();
  expect(redirect).toHaveBeenCalledWith(target);
});
test("public navigation retains API docs and sign in without redundant menus", () => {
  render(<SiteNav variant="marketing" />);
  expect(screen.getByRole("link", { name: "API docs" }).getAttribute("href")).toBe("/docs/api");
  expect(screen.getByRole("link", { name: "Sign in" }).getAttribute("href")).toBe("/signin");
  for (const label of ["Product", "How it works", "Developers"]) expect(screen.queryByText(label)).toBeNull();
  expect(screen.queryByRole("button", { name: "Toggle navigation" })).toBeNull();
});
test("signed-in public visitors retain their Dashboard destination", () => {
  jest.mocked(useMarketingSession).mockReturnValue(true);
  render(<SiteNav variant="marketing" />);
  expect(screen.getByRole("link", { name: "Dashboard" }).getAttribute("href")).toBe("/home");
  expect(screen.queryByRole("link", { name: "Sign in" })).toBeNull();
});
