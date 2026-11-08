/** @jest-environment jsdom */
import { act, fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Header } from "@/components/landing-v5/Header";
import ProductPage from "@/app/product/page";
import SolutionsPage from "@/app/(marketing)/solutions/page";
import { renderToStaticMarkup } from "react-dom/server";
import sitemap from "@/app/sitemap";
jest.mock("next/font/google", () => ({ Inter: () => ({variable:"inter"}), Plus_Jakarta_Sans: () => ({variable:"jakarta"}), Geist_Mono: () => ({variable:"mono"}) }));

test("public navigation links to real pages and restores focus on Escape", async () => {
 render(<Header/>);
 for (const [name, href] of [["Solutions", "/solutions"], ["Developers", "/docs/api"], ["Pricing", "/pricing"]]) {
  expect(screen.getByRole("link", {name}).getAttribute("href")).toBe(href);
 }
 const menu = screen.getByRole("button", {name: "Menu"});
 await userEvent.click(menu);
 expect(menu.getAttribute("aria-expanded")).toBe("true");
 const solutions=screen.getByRole("link",{name:"Solutions"});
 solutions.focus();
 fireEvent.keyDown(solutions,{key:"Escape"});
 expect(document.activeElement).toBe(menu);
 expect(menu.getAttribute("aria-expanded")).toBe("false");
 await userEvent.click(menu);
 fireEvent.pointerDown(document.body);
 expect(menu.getAttribute("aria-expanded")).toBe("false");
});

test("mobile navigation closes after selection and keyboard focus can leave it", async () => {
 render(<><Header/><button>After header</button></>);
 const menu=screen.getByRole("button",{name:"Menu"});
 await userEvent.click(menu);
 await userEvent.click(screen.getByRole("link",{name:"Solutions"}));
 expect(menu.getAttribute("aria-expanded")).toBe("false");
 await userEvent.click(menu);
 act(() => screen.getByRole("button",{name:"After header"}).focus());
 expect(menu.getAttribute("aria-expanded")).toBe("false");
});

test("public pages have reachable sections, examples and independent metadata routes", () => {
 const product=render(<ProductPage/>);
 expect(screen.getByRole("heading",{level:1}).textContent).toContain("A place for your things.");
 for(const id of ["capture","ask","share"]) expect(document.getElementById(id)).toBeTruthy();
 expect(screen.getByRole("img", {name:"Example source photo from the workshop inventory"})).toBeTruthy();
 product.unmount();
 document.body.innerHTML=renderToStaticMarkup(<SolutionsPage/>);
 expect(screen.getByRole("heading", {level:1}).textContent).toBe("A better way to find what you already have.");
 expect(document.getElementById("how")).toBeTruthy();
 expect(document.querySelector('a[href="/signup"]')).toBeTruthy();
 expect(document.querySelector('footer a[href="/research"]')).not.toBeNull();
 const routes=sitemap().map(item=>item.url);
 expect(routes).toContain("https://findez.ai/product");
 expect(routes).toContain("https://findez.ai/solutions");
});
