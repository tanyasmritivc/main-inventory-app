"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { FindEZWordmark } from "@/components/site/findez-brand";

const menus = {
 Product: [
  ["Overview", "Your inventory, from first photo to everyday use.", "/product"],
  ["Capture & organize", "Photos, imports and a place for everything.", "/product#capture"],
  ["Ask your inventory", "Find things using your own words.", "/product#ask"],
  ["Share & manage", "Keep your team working from the same records.", "/product#share"],
 ],
 Solutions: [
  ["Home", "Know what you have and where it belongs.", "/solutions#home"],
  ["Workshops & robotics", "Keep parts, tools and projects organized.", "/solutions#workshops"],
  ["Teams", "Share equipment without losing track of it.", "/solutions#teams"],
 ],
} as const;

export function Header() {
 const root = useRef<HTMLElement>(null);
 const [open, setOpen] = useState<keyof typeof menus | null>(null);
 const [mobile, setMobile] = useState(false);
 const close = () => { setOpen(null); setMobile(false); };
 useEffect(() => {
  const outside = (e: PointerEvent) => { if (!root.current?.contains(e.target as Node)) { setOpen(null); setMobile(false); } };
  document.addEventListener("pointerdown", outside);
  return () => document.removeEventListener("pointerdown", outside);
 }, []);
 return <header className="nav" id="nav" ref={root} onKeyDown={e => {
  if (e.key === "Escape") {
   if (open) { root.current?.querySelector<HTMLButtonElement>(`[data-trigger="${open}"]`)?.focus(); setOpen(null); }
   else { root.current?.querySelector<HTMLButtonElement>(".mobile-nav-toggle")?.focus(); setMobile(false); }
  }
 }} onBlur={e => { if (!e.currentTarget.contains(e.relatedTarget as Node)) close(); }}>
  <div className="wrap">
   <Link className="brand" href="/" aria-label="FindEZ home" onClick={close}><FindEZWordmark width={96} height={27}/></Link>
   <button className="mobile-nav-toggle" type="button" aria-expanded={mobile} aria-controls="public-navigation" onClick={() => { setMobile(!mobile); setOpen(null); }}>{mobile ? "Close" : "Menu"}</button>
   <nav className={`menu${mobile ? " mobile-open" : ""}`} id="public-navigation" aria-label="Main">
    {(Object.keys(menus) as (keyof typeof menus)[]).map(name => <div className="nav-group" key={name}>
     <button type="button" className="nav-trigger" data-trigger={name} aria-expanded={open === name} aria-controls={`nav-${name}`} onClick={() => setOpen(open === name ? null : name)}>{name}<span aria-hidden="true">⌄</span></button>
     {open === name && <div className="nav-panel" id={`nav-${name}`}>
      <p className="nav-panel-label">{name === "Product" ? "Meet FindEZ" : "FindEZ for your world"}</p>
      {menus[name].map(([title, detail, href]) => <Link key={href} href={href} onClick={close}><strong>{title}</strong><span>{detail}</span></Link>)}
     </div>}
    </div>)}
    <Link href="/docs/api" onClick={close}>Developers</Link>
    <Link href="/pricing" onClick={close}>Pricing</Link>
    <Link className="mobile-login" href="/signin" onClick={close}>Log in</Link>
   </nav>
   <nav className="links" aria-label="Account"><Link className="lg" href="/signin">Log in</Link><Link className="go" href="/signup">Get started</Link></nav>
  </div>
 </header>;
}
