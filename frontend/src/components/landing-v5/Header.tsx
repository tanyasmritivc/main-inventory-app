"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import Image from "next/image";

export function Header({ workbench = false, prefetch }: { workbench?: boolean; prefetch?: false }) {
 const root = useRef<HTMLElement>(null);
 const [mobile, setMobile] = useState(false);
 const [collapsed, setCollapsed] = useState(false);
 const [overHero, setOverHero] = useState(true);
 useEffect(() => {
  if (!workbench) return;
  const update = () => { setCollapsed(window.scrollY > 10); setOverHero((document.getElementById("hero")?.getBoundingClientRect().bottom ?? 0) > 64); };
  const firstFrame = requestAnimationFrame(update); window.addEventListener("scroll", update, {passive:true}); window.addEventListener("resize", update);
  return () => { cancelAnimationFrame(firstFrame); window.removeEventListener("scroll", update); window.removeEventListener("resize", update); };
 }, [workbench]);
 const close = () => { setMobile(false); };
 useEffect(() => {
  const outside = (e: PointerEvent) => { if (!root.current?.contains(e.target as Node)) { setMobile(false); } };
  document.addEventListener("pointerdown", outside);
  return () => document.removeEventListener("pointerdown", outside);
 }, []);
 const navigation = (
  <div className="wrap">
   <Link prefetch={prefetch} className="brand" href="/" aria-label="FindEZ home" onClick={close}>{workbench ? <><svg aria-hidden="true" width="22" height="22" viewBox="10 10 80 80"><path d="M12 24A12 12 0 0 1 24 12L40.5 12A5 5 0 0 1 45.5 17L45.5 38.5A4.5 4.5 0 0 0 50 43L50 43A4.5 4.5 0 0 0 54.5 38.5L54.5 17A5 5 0 0 1 59.5 12L76 12A12 12 0 0 1 88 24L88 40.5A5 5 0 0 1 83 45.5L61.5 45.5A4.5 4.5 0 0 0 57 50L57 50A4.5 4.5 0 0 0 61.5 54.5L83 54.5A5 5 0 0 1 88 59.5L88 76A12 12 0 0 1 76 88L59.5 88A5 5 0 0 1 54.5 83L54.5 61.5A4.5 4.5 0 0 0 50 57L50 57A4.5 4.5 0 0 0 45.5 61.5L45.5 83A5 5 0 0 1 40.5 88L24 88A12 12 0 0 1 12 76L12 59.5A5 5 0 0 1 17 54.5L38.5 54.5A4.5 4.5 0 0 0 43 50L43 50A4.5 4.5 0 0 0 38.5 45.5L17 45.5A5 5 0 0 1 12 40.5Z" fill="currentColor"/></svg><span>FindEZ</span></> : <Image className="header-wordmark" src="/brand/findez-header-wordmark.svg" alt="FindEZ" width={84} height={18}/>}</Link>
   <button className="mobile-nav-toggle" type="button" aria-expanded={mobile} aria-controls="public-navigation" onClick={() => { setMobile(!mobile); }}>{mobile ? "Close" : "Menu"}</button>
   <nav className={`menu${mobile ? " mobile-open" : ""}`} id="public-navigation" aria-label="Main">
    <Link prefetch={prefetch} href="/solutions" onClick={close}>Solutions</Link>
    <Link prefetch={prefetch} href="/docs/api" onClick={close}>Developers</Link>
    <Link prefetch={prefetch} href="/pricing" onClick={close}>Pricing</Link>
    <Link prefetch={prefetch} className="mobile-login" href="/signin" onClick={close}>Log in</Link>
   </nav>
   <nav className="links" aria-label="Account"><Link prefetch={prefetch} className="lg" href="/signin">Log in</Link><Link prefetch={prefetch} className="go" href="/signup">Get started</Link></nav>
  </div>
 );
 return <header className={`nav${workbench ? " wb-header" : ""}${workbench && overHero ? " wb-over-hero" : ""}${collapsed ? " wb-collapsed" : ""}`} id="nav" ref={root} onKeyDown={e => {
  if (e.key === "Escape") {
   root.current?.querySelector<HTMLButtonElement>(".mobile-nav-toggle")?.focus(); setMobile(false);
  }
 }} onBlur={e => { if (!e.currentTarget.contains(e.relatedTarget as Node)) close(); }}>
  {workbench && <a className="wb-band" href="https://apps.apple.com/us/app/findez-ai/id6760401697" aria-hidden={collapsed || undefined} tabIndex={collapsed ? -1 : undefined}><span className="wb-new">New</span><span>FindEZ AI is now on iPhone</span><span className="wb-arrow" aria-hidden="true">→</span></a>}
  {workbench ? <div className="wb-nav">{navigation}</div> : navigation}
 </header>;
}
