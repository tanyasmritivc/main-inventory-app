import type { ReactNode } from "react";
import { Header } from "./Header";
import { Footer } from "./Footer";
import { publicFonts } from "./fonts";
import "./landing.css";
import "./public-pages.css";

export function PublicShell({children}:{children:ReactNode}) {
 return <div className={`public-site ${publicFonts}`}><div className="landing-v5 public-header"><Header/></div>{children}<div className="landing-v5"><Footer/></div></div>;
}
