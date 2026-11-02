import type { ReactNode } from "react";
import { Header } from "@/components/landing-v5/Header";
import { Footer } from "@/components/landing-v5/Footer";
import { publicFonts } from "@/components/landing-v5/fonts";
import { PagesMotion } from "./motion";
import "@/components/landing-v5/landing.css";
import "./pages.css";

export function PagesShell({ children, page }: { children: ReactNode; page: "product" | "solutions" | "research" | "pricing" }) {
 return <PagesMotion className={`pages-ui ${publicFonts}`} page={page}>
  <div className="landing-v5 pages-header"><Header/></div>
  {children}
  <div className="landing-v5 pages-footer"><Footer/></div>
 </PagesMotion>;
}
