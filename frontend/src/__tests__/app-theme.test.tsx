/** @jest-environment jsdom */
import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AppThemeDocument, AppThemeProvider, useAppTheme } from "@/components/site/use-app-theme";
import { ResourceArt, resourcePalette } from "@/components/site/app-theme-ui";
import { APP_THEME_STORAGE_KEY, isInteriorPath } from "@/lib/app-theme-constants";
let mockPathname = "/settings/appearance";
jest.mock("next/navigation", () => ({ usePathname: () => mockPathname }));
function Choices() { const { setTheme } = useAppTheme(); return <><button onClick={() => setTheme("light")}>Light</button><button onClick={() => setTheme("dark")}>Dark</button><button onClick={() => setTheme("system")}>System</button></>; }
beforeEach(() => {
  mockPathname = "/settings/appearance";
  localStorage.clear(); document.documentElement.className = "";
  delete document.documentElement.dataset.appTheme;
  window.matchMedia = jest.fn(() => ({ matches:true, addEventListener:jest.fn(), removeEventListener:jest.fn() }) as unknown as MediaQueryList);
});
test("saved Appearance controls all interiors and is removed on public navigation without losing the preference", async () => {
  localStorage.setItem(APP_THEME_STORAGE_KEY,"dark");
  const tree = <><AppThemeDocument /><AppThemeProvider><Choices /></AppThemeProvider></>;
  const view = render(tree);
  expect(document.documentElement.dataset.appTheme).toBe("dark");
  await userEvent.click(screen.getByRole("button",{name:"Light"}));
  expect(document.documentElement.dataset.appTheme).toBe("light");
  expect(document.documentElement.classList.contains("dark")).toBe(false);
  mockPathname="/worlds/personal"; view.rerender(<div>{tree}</div>);
  expect(document.documentElement.dataset.appTheme).toBe("light");
  mockPathname="/"; view.rerender(tree);
  expect(document.documentElement.dataset.appTheme).toBeUndefined();
  expect(localStorage.getItem(APP_THEME_STORAGE_KEY)).toBe("light");
  mockPathname="/inventory"; view.rerender(<div>{tree}</div>);
  expect(document.documentElement.dataset.appTheme).toBe("light");
  await userEvent.click(screen.getByRole("button",{name:"System"}));
  expect(document.documentElement.dataset.appTheme).toBe("dark");
  expect(localStorage.getItem(APP_THEME_STORAGE_KEY)).toBe("system");
  act(() => window.dispatchEvent(new Event("findez-theme-change")));
});
test.each(["/", "/signin", "/signup", "/privacy", "/terms", "/docs/api", "/research", "/pricing", "/product", "/spaceship"])("public route %s never receives the signed-in theme", path => { expect(isInteriorPath(path)).toBe(false); });
test("resource artwork is stable when reordered or re-rendered and preserves the live count", () => {
 const ids=["space-a","space-b","inventory-a","workspace-a"];
 const initial = Object.fromEntries(ids.map(id=>[id,resourcePalette(id)]));
 for(const id of ids.reverse()) expect(resourcePalette(id)).toBe(initial[id]);
 const view=render(<ResourceArt id="space-a">298 items</ResourceArt>);
 const palette=screen.getByText("298 items").parentElement!.className;
 document.documentElement.dataset.appTheme="dark";
 view.rerender(<ResourceArt id="space-a">299 items</ResourceArt>);
 expect(screen.getByText("299 items").parentElement!.className).toBe(palette);
 expect(screen.queryByText("298 items")).toBeNull();
});
