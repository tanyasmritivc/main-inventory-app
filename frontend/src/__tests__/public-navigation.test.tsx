/** @jest-environment jsdom */
import { act, fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Header } from "@/components/landing-v5/Header";
import ProductPage from "@/app/product/page";
import SolutionsPage from "@/app/(marketing)/solutions/page";
import { renderToStaticMarkup } from "react-dom/server";
import sitemap from "@/app/sitemap";
jest.mock("next/font/google", () => ({ Inter: () => ({variable:"inter"}), Plus_Jakarta_Sans: () => ({variable:"jakarta"}), Geist_Mono: () => ({variable:"mono"}) }));
test("legacy public navigation links to real pages and dismisses on Escape or outside interaction",async()=>{
 render(<Header/>);
 for(const [name,href] of [['Solutions','/solutions'],['Developers','/docs/api'],['Pricing','/pricing']])expect(screen.getByRole('link',{name}).getAttribute('href')).toBe(href);
 const menu=screen.getByRole('button',{name:'Menu'});await userEvent.click(menu);
 expect(menu.getAttribute('aria-expanded')).toBe('true');
 fireEvent.keyDown(screen.getByRole('link',{name:'Solutions'}),{key:'Escape'});
 expect(document.activeElement).toBe(menu);expect(menu.getAttribute('aria-expanded')).toBe('false');
 await userEvent.click(menu);fireEvent.pointerDown(document.body);expect(menu.getAttribute('aria-expanded')).toBe('false');
});
test("mobile navigation closes after selection and keyboard focus can leave it",async()=>{
 render(<><Header/><button>After header</button></>);
 await userEvent.click(screen.getByRole('button',{name:'Menu'}));
 await userEvent.click(screen.getByRole('link',{name:'Solutions'}));
 expect(screen.getByRole('button',{name:'Menu'}).getAttribute('aria-expanded')).toBe('false');
 await userEvent.click(screen.getByRole('button',{name:'Menu'}));act(()=>screen.getByRole('button',{name:'After header'}).focus());
 expect(screen.getByRole('button',{name:'Menu'}).getAttribute('aria-expanded')).toBe('false');
});
test("public pages expose their sections and sitemap includes current marketing destinations",()=>{
 const product=render(<ProductPage/>);
 expect(screen.getByRole('heading',{level:1}).textContent).toContain('A place for your things.');
 for(const id of ['capture','ask','share'])expect(document.getElementById(id)).toBeTruthy();
 expect(screen.getByText(/Check the source record before acting on an AI answer/)).toBeTruthy();product.unmount();
 document.body.innerHTML=renderToStaticMarkup(<SolutionsPage/>);
 expect(document.querySelector('footer a[href="/research"]')).not.toBeNull();
 for(const route of ['/solutions/robotics','/solutions/workshops','/solutions/makerspaces','/solutions/engineering-labs'])expect(document.querySelector(`a[href="${route}"]`)).not.toBeNull();
 const routes=sitemap().map(item=>item.url);
 for(const route of ['/product','/solutions','/cad-intelligence','/docs/cad','/founders','/desktop'])expect(routes).toContain(`https://findez.ai${route}`);
});
