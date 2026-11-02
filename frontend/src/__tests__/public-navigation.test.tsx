/** @jest-environment jsdom */
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Header } from "@/components/landing-v5/Header";
import ProductPage from "@/app/product/page";
import SolutionsPage from "@/app/solutions/page";
import sitemap from "@/app/sitemap";
jest.mock("next/font/google", () => ({ Inter: () => ({variable:"inter"}), Plus_Jakarta_Sans: () => ({variable:"jakarta"}), Geist_Mono: () => ({variable:"mono"}) }));

test("public disclosures link to real pages, switch panels, and restore focus on Escape", async () => {
 render(<Header/>);
 const product=screen.getByRole("button",{name:"Product"});
 const solutions=screen.getByRole("button",{name:"Solutions"});
 expect(screen.queryByText("Research")).toBeNull();
 expect(screen.queryByRole("link",{name:"Teams"})).toBeNull();
 expect(screen.getByRole("link",{name:"Developers"}).getAttribute("href")).toBe("/docs/api");
 expect(screen.getByRole("link",{name:"Pricing"}).getAttribute("href")).toBe("/pricing");
 await userEvent.click(product);
 expect(product.getAttribute("aria-expanded")).toBe("true");
 expect(screen.getByRole("link",{name:/Overview/}).getAttribute("href")).toBe("/product");
 const capture=screen.getByRole("link",{name:/Capture & organize/});
 expect(capture.getAttribute("href")).toBe("/product#capture");
 capture.focus();
 fireEvent.keyDown(capture,{key:"Escape"});
 expect(document.activeElement).toBe(product);
 expect(screen.queryByRole("link",{name:/Overview/})).toBeNull();
 await userEvent.click(product);
 await userEvent.click(solutions);
 expect(screen.queryByRole("link",{name:/Overview/})).toBeNull();
 expect(screen.getByRole("link",{name:/Workshops & robotics/}).getAttribute("href")).toBe("/solutions#workshops");
 fireEvent.pointerDown(document.body);
 expect(solutions.getAttribute("aria-expanded")).toBe("false");
});

test("mobile navigation closes after selection and keyboard focus can leave it", async () => {
 render(<><Header/><button>After header</button></>);
 await userEvent.click(screen.getByRole("button",{name:"Menu"}));
 await userEvent.click(screen.getByRole("button",{name:"Solutions"}));
 await userEvent.click(screen.getByRole("link",{name:/^Home Know/}));
 expect(screen.getByRole("button",{name:"Menu"}).getAttribute("aria-expanded")).toBe("false");
 await userEvent.click(screen.getByRole("button",{name:"Product"}));
 act(() => screen.getByRole("button",{name:"After header"}).focus());
 expect(screen.getByRole("button",{name:"Product"}).getAttribute("aria-expanded")).toBe("false");
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
 expect(footer.getByRole("link",{name:"Research"}).getAttribute("href")).toBe("/#s6r");
 const routes=sitemap().map(item=>item.url);
 expect(routes).toContain("https://findez.ai/product");
 expect(routes).toContain("https://findez.ai/solutions");
});
