/** @jest-environment jsdom */
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Header } from "@/components/landing-v5/Header";
import ProductPage from "@/app/product/page";
import SolutionsPage from "@/app/solutions/page";
import sitemap from "@/app/sitemap";
jest.mock("next/font/google", () => ({ Inter: () => ({variable:"inter"}), Plus_Jakarta_Sans: () => ({variable:"jakarta"}), Geist_Mono: () => ({variable:"mono"}) }));

test("public navigation links directly to dedicated pages", () => {
 render(<Header/>);
 for (const [name, href] of [["Product", "/product"], ["Solutions", "/solutions"], ["Developers", "/docs/api"], ["Pricing", "/pricing"]]) {
  expect(screen.getByRole("link", {name}).getAttribute("href")).toBe(href);
  expect(screen.queryByRole("button", {name})).toBeNull();
 }
 expect(screen.queryByText("Research")).toBeNull();
});

test("mobile navigation closes after selection, Escape, outside click and focus leave", async () => {
 render(<><Header/><button>After header</button></>);
 const open = async () => userEvent.click(screen.getByRole("button", {name:"Menu"}));
 const closed = () => expect(screen.getByRole("button", {name:"Menu"}).getAttribute("aria-expanded")).toBe("false");
 await open();
 await userEvent.click(screen.getByRole("link", {name:"Solutions"}));
 closed();
 await open();
 fireEvent.keyDown(screen.getByRole("link", {name:"Product"}), {key:"Escape"});
 closed();
 expect(document.activeElement).toBe(screen.getByRole("button", {name:"Menu"}));
 await open();
 fireEvent.pointerDown(document.body);
 closed();
 await open();
 act(() => screen.getByRole("button",{name:"After header"}).focus());
 closed();
});

test("public pages have reachable sections, examples and independent metadata routes", () => {
 const product=render(<ProductPage/>);
 expect(screen.getByRole("heading",{level:1}).textContent).toContain("A place for your things.");
 for(const id of ["capture","ask","share"]) expect(document.getElementById(id)).toBeTruthy();
 expect(screen.getByText("Illustrative conversation")).toBeTruthy();
 product.unmount();
 render(<SolutionsPage/>);
 for(const id of ["home","workshops","teams"]) expect(document.getElementById(id)).toBeTruthy();
 const footer=within(screen.getByRole("navigation",{name:"Footer navigation"}));
 expect(footer.getByRole("link",{name:"Research"}).getAttribute("href")).toBe("/research");
 const routes=sitemap().map(item=>item.url);
 expect(routes).toContain("https://findez.ai/product");
 expect(routes).toContain("https://findez.ai/solutions");
});
