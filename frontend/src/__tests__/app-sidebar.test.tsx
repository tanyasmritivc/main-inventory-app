/** @jest-environment jsdom */
import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { usePathname } from "next/navigation";
import { APP_NAV_ITEMS, AppSidebar } from "@/components/site/app-sidebar";
jest.mock("next/navigation", () => ({
  usePathname: jest.fn(),
  useRouter: () => ({ replace: jest.fn(), refresh: jest.fn() }),
}));
jest.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: jest.fn(),
}));
beforeEach(() => {
  jest.mocked(usePathname).mockReturnValue("/inventory");
  window.innerWidth = 1024;
});
test("makes every current mobile capability and developer entry point directly reachable", () => {
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen={false} />);
  for (const { label, route } of APP_NAV_ITEMS)
    expect(screen.getByRole("link", { name: label }).getAttribute("href")).toBe(
      route,
    );
  for (const route of [
    "/scan",
    "/inventory",
    "/assist",
    "/spaces",
    "/teams",
    "/documents",
    "/review",
    "/restock",
    "/checkout",
    "/project-kits",
    "/collections",
    "/labels",
    "/activity",
    "/notifications",
    "/settings/api-keys",
    "/docs/api",
  ])
    expect(APP_NAV_ITEMS.some((item) => item.route === route)).toBe(true);
  expect(
    screen.getByRole("complementary").classList.contains("is-hover-expandable"),
  ).toBe(false);
});
test("uses the mobile mark without changing the public mark", () => {
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);
  expect(
    container.querySelector(".app-sidebar-logo path")?.getAttribute("d"),
  ).toBe("M25.25 40.75H55.25V70.75");
});
test.each(APP_NAV_ITEMS.filter((i) => i.route !== "/docs/api"))(
  "selects only $label on its route",
  ({ label, route }) => {
    jest.mocked(usePathname).mockReturnValue(route);
    const { container } = render(
      <AppSidebar onToggle={jest.fn()} sidebarOpen />,
    );
    expect([...container.querySelectorAll('a[aria-current="page"]')]).toEqual([
      screen.getByRole("link", { name: label }),
    ]);
  },
);
test("API key child route selects API keys and leaves Settings inactive", () => {
  jest.mocked(usePathname).mockReturnValue("/settings/api-keys/new");
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);
  expect(
    screen.getByRole("link", { name: "API keys" }).getAttribute("aria-current"),
  ).toBe("page");
  expect(
    screen.getByRole("link", { name: "Settings" }).getAttribute("aria-current"),
  ).toBeNull();
});
test.each([390, 1024])(
  "navigation closes the drawer only on a narrow viewport (%i)",
  async (width) => {
    window.innerWidth = width;
    const onToggle = jest.fn();
    render(<AppSidebar onToggle={onToggle} sidebarOpen />);
    const link = screen.getByRole("link", { name: "Spaces" });
    link.addEventListener("click", (e) => e.preventDefault());
    await userEvent.click(link);
    expect(onToggle).toHaveBeenCalledTimes(width < 860 ? 1 : 0);
  },
);

test("the narrow drawer isolates background controls and restores focus on close", async () => {
  window.innerWidth = 390;
  const outside = document.createElement("button");
  outside.className = "app-main";
  outside.inert = false;
  document.body.append(outside);
  outside.focus();
  const initialOverflow = document.body.style.overflow;
  const rects = jest
    .spyOn(HTMLElement.prototype, "getClientRects")
    .mockReturnValue([new DOMRect()] as unknown as DOMRectList);
  const onToggle = jest.fn();
  const view = render(<AppSidebar onToggle={onToggle} sidebarOpen />);
  try {
    expect(outside.inert).toBe(true);
    expect(document.body.style.overflow).toBe("hidden");
    expect(document.activeElement).toBe(
      screen.getByRole("link", { name: "FindEZ home" }),
    );
    await userEvent.tab({ shift: true });
    expect(document.activeElement).toBe(
      screen.getByRole("button", { name: "Sign out" }),
    );
    await userEvent.keyboard("{Escape}");
    expect(onToggle).toHaveBeenCalledTimes(1);
    view.rerender(<AppSidebar onToggle={onToggle} sidebarOpen={false} />);
    expect(outside.inert).toBe(false);
    expect(document.body.style.overflow).toBe(initialOverflow);
    expect(document.activeElement).toBe(outside);
  } finally {
    view.unmount();
    rects.mockRestore();
    outside.remove();
  }
});

test("crossing the desktop breakpoint closes an open drawer once", () => {
  window.innerWidth = 390;
  const onToggle = jest.fn();
  render(<AppSidebar onToggle={onToggle} sidebarOpen />);
  window.innerWidth = 1024;
  fireEvent(window, new Event("resize"));
  fireEvent(window, new Event("resize"));
  expect(onToggle).toHaveBeenCalledTimes(1);
});
