import type { ReactNode } from "react";
import {HeaderMarkup, FooterMarkup} from "@/components/marketing-dark/public-chrome";
import { publicFonts } from "@/components/landing-v5/fonts";
import { PagesMotion } from "./motion";
import "@/components/landing-v5/landing.css";
import "./pages.css";

export function PagesShell({ children, page }: { children: ReactNode; page: "product" | "solutions" | "research" | "pricing" }) {
 return <PagesMotion className={`pages-ui ${publicFonts}`} page={page}>
  <HeaderMarkup/>
  {children}
  <FooterMarkup/>
 </PagesMotion>;
}
