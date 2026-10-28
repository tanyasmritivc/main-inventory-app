"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import Image from "next/image";

export function Header() {
 const root = useRef<HTMLElement>(null);
 const [mobile, setMobile] = useState(false);
 const close = () => { setMobile(false); };
 useEffect(() => {
  const outside = (e: PointerEvent) => { if (!root.current?.contains(e.target as Node)) { setMobile(false); } };
  document.addEventListener("pointerdown", outside);
  return () => document.removeEventListener("pointerdown", outside);
 }, []);
 return <header className="nav" id="nav" ref={root} onKeyDown={e => {
  if (e.key === "Escape") {
   root.current?.querySelector<HTMLButtonElement>(".mobile-nav-toggle")?.focus(); setMobile(false);
  }
 }} onBlur={e => { if (!e.currentTarget.contains(e.relatedTarget as Node)) close(); }}>
  <div className="wrap">
   <Link className="brand" href="/" aria-label="FindEZ home" onClick={close}><Image className="header-wordmark" src="/brand/findez-header-wordmark.svg" alt="FindEZ" width={84} height={18}/></Link>
   <button className="mobile-nav-toggle" type="button" aria-expanded={mobile} aria-controls="public-navigation" onClick={() => { setMobile(!mobile); }}>{mobile ? "Close" : "Menu"}</button>
   <nav className={`menu${mobile ? " mobile-open" : ""}`} id="public-navigation" aria-label="Main">
    <Link href="/product" onClick={close}>Product</Link>
    <Link href="/solutions" onClick={close}>Solutions</Link>
    <Link href="/docs/api" onClick={close}>Developers</Link>
    <Link href="/pricing" onClick={close}>Pricing</Link>
    <Link className="mobile-login" href="/signin" onClick={close}>Log in</Link>
   </nav>
   <nav className="links" aria-label="Account"><Link className="lg" href="/signin">Log in</Link><Link className="go" href="/signup">Get started</Link></nav>
  </div>
 </header>;
}
