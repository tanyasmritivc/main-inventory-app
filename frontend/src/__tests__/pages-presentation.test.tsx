/** @jest-environment jsdom */
import fs from "node:fs";
import path from "node:path";
import ts from "typescript";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { fireEvent, render, screen } from "@testing-library/react";
import Product from "@/app/product/page";
import Solutions from "@/app/solutions/page";
import Research from "@/app/research/page";
import { PricingClient } from "@/components/site/pricing-client";
import { PublicPlanCards } from "@/components/pages-ui/PublicPlanCards";
import { BILLING_PLANS } from "@/lib/billing-plans";
jest.mock("next/font/google",()=>({Inter:()=>({variable:"inter"}),Plus_Jakarta_Sans:()=>({variable:"jakarta"}),Geist_Mono:()=>({variable:"mono"})}));
const baseline=JSON.parse(fs.readFileSync(path.resolve(process.cwd(),"../docs/pages-v1/content-baseline.json"),"utf8")) as Record<string,string>;
function oldComponent(file:string,name="default"){
 const compiledModule={exports:{} as Record<string,React.ComponentType>};
 const code=ts.transpileModule(baseline[file],{compilerOptions:{jsx:ts.JsxEmit.React,esModuleInterop:true,module:ts.ModuleKind.CommonJS}}).outputText;
 const load=(id:string)=>jest.requireActual(id.startsWith(".")?path.resolve(process.cwd(),"..",path.dirname(file),id):id);
 new Function("require","module","exports","React",code)(load,compiledModule,compiledModule.exports,React);
 return compiledModule.exports[name];
}
function content(component:React.ReactNode){
 const root=document.createElement("div");root.innerHTML=renderToStaticMarkup(component);const main=root.querySelector("main")||root;
 main.querySelectorAll('script,style,[aria-hidden="true"],svg').forEach(n=>n.remove());
 const walker=document.createTreeWalker(main,NodeFilter.SHOW_TEXT);const words:string[]=[];let node;
 while((node=walker.nextNode()))words.push(...(node.textContent||"").split(/\s+/).filter(Boolean));
 return {words:words.sort(),links:Array.from(main.querySelectorAll("a")).map(a=>[a.textContent,a.getAttribute("href")]).sort()};
}
test.each([
 ["frontend/src/app/product/page.tsx",Product,"default"],
 ["frontend/src/app/solutions/page.tsx",Solutions,"default"],
 ["frontend/src/components/site/pricing-client.tsx",PricingClient,"PricingClient"],
] as const)("preserves all existing content and destinations: %s",(file,Current,name)=>{
 const Previous=oldComponent(file,name);expect(content(<Current/>)).toEqual(content(<Previous/>));
});
test("research contains only the already-public FIND content",()=>{
 const Previous=oldComponent("frontend/src/components/landing-v5/Research.tsx","Research");
 expect(content(<Research/>)).toEqual(content(<Previous/>));
});
test("public plan controls retain the catalog and disabled paid actions",()=>{
 render(<PublicPlanCards/>);
 expect(screen.getAllByRole("button",{name:/subscriptions coming soon/})).toHaveLength(2);
 for(const button of screen.getAllByRole("button",{name:/subscriptions coming soon/}))expect((button as HTMLButtonElement).disabled).toBe(true);
 fireEvent.click(screen.getByRole("button",{name:"Yearly"}));
 for(const plan of BILLING_PLANS){expect(screen.getByText(`$${plan.annual.toLocaleString("en-US")}`,{selector:".pages-sr-only"})).toBeTruthy();for(const feature of plan.features)expect(screen.getAllByText(feature).length).toBeGreaterThan(0);}
 expect(screen.getByText("About $24.92/month, billed yearly")).toBeTruthy();
 expect(screen.getByRole("link",{name:"Get started free"}).getAttribute("href")).toBe("/signup");
});
