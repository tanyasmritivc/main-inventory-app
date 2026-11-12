'use client';

import Link from "next/link";
import {useEffect, useRef} from "react";
import "./public-chrome.css";

export function HeaderMarkup({cadHref="/cad-intelligence",currentPage,reserveSpace=false,manageScroll=true}:{cadHref?:string;currentPage?:string;reserveSpace?:boolean;manageScroll?:boolean}={}){
  const nav = useRef<HTMLElement>(null);
  useEffect(() => {
    if (!manageScroll) return;
    const node = nav.current;
    if (!node) return;
    let previous = window.scrollY, accumulated = 0;
    const update = () => {
      const y = window.scrollY, delta = y - previous;
      previous = y;
      node.classList.toggle("sc", y > 10);
      if (y < 80 || node.contains(document.activeElement)) { node.classList.remove("hid"); accumulated = 0; return; }
      accumulated = (Math.sign(delta) === Math.sign(accumulated) ? accumulated : 0) + delta;
      if (accumulated > 24) node.classList.add("hid");
      else if (accumulated < -12) node.classList.remove("hid");
    };
    window.addEventListener("scroll", update, { passive: true });
    update();
    return () => window.removeEventListener("scroll", update);
  }, [manageScroll]);
  return (<>{reserveSpace && <div className="findez-public-header-space" aria-hidden="true"/>}<header ref={nav} className="findez-public-chrome x-nav" id="x-nav" onFocus={() => nav.current?.classList.remove("hid")}><div className={"x-in"}>
<Link className={"x-logo"} href={"/"}><svg data-marketing-brand="true" aria-hidden="true" width={"20"} height={"20"} viewBox={"0 0 100 100"} fill={"#F5F5F6"}><path d={"M12 24A12 12 0 0 1 24 12L40.5 12A5 5 0 0 1 45.5 17L45.5 38.5A4.5 4.5 0 0 0 50 43A4.5 4.5 0 0 0 54.5 38.5L54.5 17A5 5 0 0 1 59.5 12L76 12A12 12 0 0 1 88 24L88 40.5A5 5 0 0 1 83 45.5L61.5 45.5A4.5 4.5 0 0 0 57 50A4.5 4.5 0 0 0 61.5 54.5L83 54.5A5 5 0 0 1 88 59.5L88 76A12 12 0 0 1 76 88L59.5 88A5 5 0 0 1 54.5 83L54.5 61.5A4.5 4.5 0 0 0 50 57A4.5 4.5 0 0 0 45.5 61.5L45.5 83A5 5 0 0 1 40.5 88L24 88A12 12 0 0 1 12 76L12 59.5A5 5 0 0 1 17 54.5L38.5 54.5A4.5 4.5 0 0 0 43 50A4.5 4.5 0 0 0 38.5 45.5L17 45.5A5 5 0 0 1 12 40.5Z"}></path></svg>{"FindEZ AI"}</Link>
<nav className={"x-links"}><Link href={"/solutions"} className={currentPage==="solutions"?"here":undefined} aria-current={currentPage==="solutions"?"page":undefined}>{"Solutions"}</Link><Link href={cadHref}>{"CAD Intelligence"}</Link><Link href={"/founders"}>{"Founders Access"}</Link><Link href={"/docs/api"}>{"Developers"}</Link><div className="x-dd"><button className="x-ddb" type="button" aria-haspopup="true">Community<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><path d="m6 9 6 6 6-6"/></svg></button><div className="x-ddm"><Link href="https://discord.gg/sKRrWA5wbf" target="_blank" rel="noopener">Discord</Link><Link href="https://www.instagram.com/findezai/" target="_blank" rel="noopener">Instagram</Link></div></div></nav>
<div className={"x-act"}><Link className={"si"} href={"/signin"}>{"Sign in"}</Link><Link className={"x-p w"} href={"/desktop"}>{"Download"}</Link></div>
</div></header></>);}
export function FooterMarkup({cadHref="/cad-intelligence"}:{cadHref?:string}={}){return (<footer className="findez-public-chrome x-foot"><div className={"x-in"}>
<div className={"x-fg"}><div ><Link className={"x-logo"} href={"/"}><svg width={"20"} height={"20"} viewBox={"0 0 100 100"} fill={"#F5F5F6"}><path d={"M12 24A12 12 0 0 1 24 12L40.5 12A5 5 0 0 1 45.5 17L45.5 38.5A4.5 4.5 0 0 0 50 43A4.5 4.5 0 0 0 54.5 38.5L54.5 17A5 5 0 0 1 59.5 12L76 12A12 12 0 0 1 88 24L88 40.5A5 5 0 0 1 83 45.5L61.5 45.5A4.5 4.5 0 0 0 57 50A4.5 4.5 0 0 0 61.5 54.5L83 54.5A5 5 0 0 1 88 59.5L88 76A12 12 0 0 1 76 88L59.5 88A5 5 0 0 1 54.5 83L54.5 61.5A4.5 4.5 0 0 0 50 57A4.5 4.5 0 0 0 45.5 61.5L45.5 83A5 5 0 0 1 40.5 88L24 88A12 12 0 0 1 12 76L12 59.5A5 5 0 0 1 17 54.5L38.5 54.5A4.5 4.5 0 0 0 43 50A4.5 4.5 0 0 0 38.5 45.5L17 45.5A5 5 0 0 1 12 40.5Z"}></path></svg>{"FindEZ AI"}</Link><p className={"x-tag"}>{"Know what you have. Find what you need. Instantly."}</p></div>
<div ><h4 >{"Product"}</h4><Link href={"/founders"}>{"Founders Access"}</Link><Link href={cadHref}>{"CAD Intelligence"}</Link><Link href={"/solutions"}>{"Solutions"}</Link><Link href={"/pricing"}>{"Plans & access"}</Link><Link href={"https://apps.apple.com/us/app/findez-ai/id6760401697"}>{"iPhone app"}</Link><Link href={"/docs/api"}>{"Developers"}</Link></div>
<div ><h4 >{"Company"}</h4><Link href={"/research"}>{"Research"}</Link><Link href={"mailto:info@findez.ai"}>{"Contact"}</Link><Link href={"/privacy"}>{"Privacy"}</Link><Link href={"/terms"}>{"Terms"}</Link></div><div><h4>Community</h4><Link href="https://discord.gg/sKRrWA5wbf" target="_blank" rel="noopener">Discord</Link><Link href="https://www.instagram.com/findezai/" target="_blank" rel="noopener">Instagram</Link></div></div>
<div className={"x-fb"}><span >{"© 2026 AI Robots Inc."}</span><span >{"FindEZ AI answers from what’s recorded in your inventory."}</span></div>
</div></footer>);}
