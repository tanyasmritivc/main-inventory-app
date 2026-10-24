"use client";

/* Native image sizing is part of the approved prototype. */
/* eslint-disable @next/next/no-img-element */
import { Fragment, useEffect, useRef, type CSSProperties } from "react";
import { initLandingLab, landingLabValues } from "./landing-lab-engine";
import { useMarketingSession } from "@/lib/use-marketing-session";
import "./landing-lab.css";

// Convert the prototype's static style declarations for the initial React render.
function css(text: string): CSSProperties {
  return Object.fromEntries(text.split(";").filter(Boolean).map((declaration) => {
    const colon = declaration.indexOf(":");
    const key = declaration.slice(0, colon).trim().replace(/-([a-z])/g, (_, c: string) => c.toUpperCase());
    return [key, declaration.slice(colon + 1).trim()];
  })) as CSSProperties;
}
const v = landingLabValues();
function SiteActions({ initialSignedIn }: { initialSignedIn: boolean }) {
  const signedIn = useMarketingSession(initialSignedIn);
  return <nav className="fzl-site-actions" aria-label="Main navigation">
    <a href="/docs/api">Developers</a>
    <a href="https://apps.apple.com/us/app/findez-ai/id6760401697" target="_blank" rel="noopener noreferrer">iOS App</a>
    <a href={signedIn ? "/home" : "/signup"} className="btn fzl-site-cta"><span>{signedIn ? "Dashboard" : "Get started"}</span><span aria-hidden="true">&#8599;</span></a>
  </nav>;
}
export function LandingLab({ className = "", siteNavigation = false, initialSignedIn = false }: { className?: string; siteNavigation?: boolean; initialSignedIn?: boolean }) {
  const rootRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (rootRef.current) return initLandingLab(rootRef.current);
  }, []);
  return (<><div style={css("background:#FFF;color:#000;font-family:var(--fzl-geist),'Helvetica Neue',Arial,sans-serif;-webkit-font-smoothing:antialiased;overflow-x:clip")} className={`fzLab ${className}`} ref={rootRef}>
{!siteNavigation && <div style={css("background:#000;color:#FFF;font-size:13px;text-align:center;padding:10px 16px")}>{"FindEZ for iPhone is coming soon. "}<a href="#waitlist" style={css("color:#A3A3A3")}>{"Join the waitlist \u203a"}</a></div>}
<div className={siteNavigation ? "fzl-scroll-header" : undefined} style={css(`${siteNavigation ? "position:relative" : "position:sticky;top:0"};z-index:50;background:rgba(255,255,255,.96);box-shadow:0 1px 0 rgba(0,0,0,.06)`)}>
<header className={`wrap${siteNavigation ? " fzl-site-header" : ""}`} style={css("height:64px;display:flex;align-items:center;justify-content:space-between;gap:16px")}>
<a href="#" aria-label="FindEZ home" style={css("display:flex;align-items:center;text-decoration:none;margin-left:-8px")}><svg viewBox="0 0 291.67 96" role="img" aria-label="FindEZ" style={css("height:34px;width:auto;display:block")}><path d="M25.25 40.75H55.25V70.75" stroke="#111112" strokeWidth="11.0" fill="none" strokeLinejoin="miter" strokeLinecap="butt"></path><path d="M50.25 30.75H65.25V45.75" stroke="#E8590C" strokeWidth="11.0" fill="none" strokeLinejoin="miter" strokeLinecap="butt"></path><g transform="translate(124.8,69.12) scale(0.057942) translate(-90,0)"><path d="M579.0 -647.0V-729.0H90.0V0.0H183.0V-332.0H531.0V-414.0H183.0V-647.0Z" fill="#111112"></path><path d="M719.0 0.0V-524.0H636.0V0.0ZM730.0 -603.0V-707.0H626.0V-603.0Z" fill="#111112"></path><path d="M1230.0 0.0V-396.0C1230.0 -483.0 1165.0 -539.0 1064.0 -539.0C986.0 -539.0 936.0 -509.0 890.0 -436.0V-524.0H813.0V0.0H896.0V-289.0C896.0 -396.0 954.0 -466.0 1039.0 -466.0C1105.0 -466.0 1147.0 -426.0 1147.0 -363.0V0.0Z" fill="#111112"></path><path d="M1749.0 0.0V-729.0H1666.0V-458.0C1631.0 -511.0 1575.0 -539.0 1505.0 -539.0C1369.0 -539.0 1280.0 -434.0 1280.0 -267.0C1280.0 -90.0 1367.0 15.0 1508.0 15.0C1580.0 15.0 1630.0 -12.0 1675.0 -77.0V0.0ZM1666.0 -260.0C1666.0 -139.0 1608.0 -63.0 1520.0 -63.0C1428.0 -63.0 1367.0 -140.0 1367.0 -262.0C1367.0 -384.0 1428.0 -461.0 1519.0 -461.0C1609.0 -461.0 1666.0 -381.0 1666.0 -260.0Z" fill="#111112"></path><path d="M2378.0 0.0V-82.0H1948.0V-332.0H2345.0V-414.0H1948.0V-647.0H2360.0V-729.0H1855.0V0.0Z" fill="#E8590C"></path><path d="M2970.0 0.0V-82.0H2532.0L2968.0 -645.0V-729.0H2443.0V-647.0H2853.0L2415.0 -82.0V0.0Z" fill="#E8590C"></path></g></svg></a>
{siteNavigation ? <SiteActions initialSignedIn={initialSignedIn} /> : <div style={css("display:flex;gap:8px;align-items:center")}><a href="/signin" style={css("font-size:14px;color:#8C8C8C;text-decoration:none;padding:8px 14px;border:1px solid #E5E5E5;border-radius:8px")}>{"Log in"}</a><a href="/signup" className="btn" style={css("background:#000;color:#FFF;padding:9px 14px;font-size:14px")}>{"Get started"}</a></div>}
</header>
<div style={css(v.progBar)} data-lab-style="progBar"></div>
</div>

<section id="hero" style={css(v.heroSec)} data-lab-style="heroSec">
<div style={css(v.heroBox)} data-lab-style="heroBox">
<canvas id="fzField" aria-label="A real workbench photo; a scanning lens names the parts it passes over" style={css("position:absolute;inset:0;width:100%;height:100%;display:block;cursor:crosshair")}></canvas>
<div style={css("position:absolute;left:0;right:0;top:0;height:46%;background:linear-gradient(#0B0B0B,rgba(11,11,11,.85) 55%,rgba(11,11,11,0));pointer-events:none")}></div>
<div style={css(v.heroCopy)} data-lab-style="heroCopy">
<h1 style={css("font-weight:400;font-size:clamp(40px,5.4vw,76px);line-height:1.02;letter-spacing:-.03em;margin:18px auto 0;max-width:15ch;color:#FFF")}>{"Find"}<span style={css("color:#E8590C")}>{"EZ"}</span>{" gives the physical world a memory."}</h1>
<div style={css("display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-top:28px;pointer-events:auto")}>
<a href="/signup" className="btn" style={css("background:#FFF;color:#000")}>{"Get started"}</a>
<a href="#waitlist" className="btn" style={css("border:1px solid rgba(255,255,255,.25);color:#FFF")}>{"Join the iPhone waitlist"}</a>
</div>
</div>
<span className="mono hide-s" style={css("position:absolute;left:20px;bottom:20px;color:#6B6B6B")}>{"Move your cursor to scan"}</span>
<span className="mono" style={css("position:absolute;right:20px;bottom:20px;color:#6B6B6B")}><span data-lab-text="scanCount">{v.scanCount}</span></span>
</div>
</section>

<section id="stmt" className="wrap" style={css("padding-top:120px;padding-bottom:120px")}>
<div className="split" style={css("grid-template-columns:minmax(0,1.3fr) minmax(0,.7fr)")}>
<p style={css("font-size:clamp(32px,4.2vw,60px);line-height:1.1;letter-spacing:-.025em;margin:0;max-width:22ch")}>{v.words.map((w, i) => <Fragment key={i}><span style={css(w.style)} data-lab-style={`words.${i}.style`} data-lab-row={`words.${i}`}><span data-lab-text={`words.${i}.t`}>{w.t}</span></span></Fragment>)}</p>
<div style={css("display:flex;justify-content:center;perspective:1400px")}>
<div className="fz-phone" style={css(v.phoneA)} data-lab-style="phoneA"><div className="fz-bezel"><div className="fz-screen"><img src="/images/landing-lab/app-home.jpg" alt="The FindEZ home screen: items that need a decision, recent captures and where things live" /></div></div></div>
</div>
</div>
</section>

<section id="see" style={css(v.seeSec)} data-lab-style="seeSec">
<div className="wrap split">
<div>
<h2 className="h2" style={css("margin-top:16px")}>{"Take a picture. That is it."}</h2>
<p className="lede">{"No forms, no categories, no typing. FIND separates every object in the photo, counts it, and tells you how sure it is."}</p>
<div style={css("display:flex;gap:28px;margin-top:34px")}>
<div><div style={css("font-size:48px;letter-spacing:-.03em;line-height:1")}><span data-lab-text="segCount">{v.segCount}</span></div><div className="mono" style={css("color:#8C8C8C;margin-top:8px")}>{"Objects found"}</div></div>
<div><div style={css("font-size:48px;letter-spacing:-.03em;line-height:1;color:#C2410C")}><span data-lab-text="segReview">{v.segReview}</span></div><div className="mono" style={css("color:#8C8C8C;margin-top:8px")}>{"Need a look"}</div></div>
</div>
</div>
<div style={css("position:relative")}>
<div style={css(v.benchBox)} data-lab-style="benchBox">
<img src="/images/landing-lab/bench.jpg" alt="A real workbench: a labelled parts cabinet, a battery charger, tape, screws, gears and aluminum housings" style={css("display:block;width:100%;aspect-ratio:800/520;object-fit:cover")} />
<svg viewBox="0 0 800 520" aria-hidden="true" style={css("position:absolute;inset:0;width:100%;height:100%")}>
<mask id="fzHoles"><rect width="800" height="520" fill="#FFFFFF"></rect>{v.seg.map((g, i) => <Fragment key={i}><rect x={g.x} data-lab-x={`seg.${i}.x`} y={g.y} data-lab-y={`seg.${i}.y`} width={g.w} data-lab-width={`seg.${i}.w`} height={g.h} data-lab-height={`seg.${i}.h`} rx="6" fill="#000000" style={css(g.hole)} data-lab-style={`seg.${i}.hole`} data-lab-row={`seg.${i}`}></rect></Fragment>)}</mask>
<rect width="800" height="520" fill="#111112" mask="url(#fzHoles)" style={css(v.segDim)} data-lab-style="segDim"></rect>
{v.seg.map((g, i) => <Fragment key={i}>
<rect x={g.x} data-lab-x={`seg.${i}.x`} y={g.y} data-lab-y={`seg.${i}.y`} width={g.w} data-lab-width={`seg.${i}.w`} height={g.h} data-lab-height={`seg.${i}.h`} rx="6" fill="none" pathLength="1" style={css(g.line)} data-lab-style={`seg.${i}.line`} data-lab-row={`seg.${i}`}></rect>
</Fragment>)}
<rect style={css(v.scanBar)} data-lab-style="scanBar" y="0" width="2" height="520" fill="rgba(255,255,255,.8)"></rect>
</svg>
<div style={css("position:absolute;inset:0;container-type:inline-size;pointer-events:none")}>
{v.seg.map((g, i) => <Fragment key={i}><span style={css(g.tag)} data-lab-style={`seg.${i}.tag`} data-lab-row={`seg.${i}`}><span data-lab-text={`seg.${i}.label`}>{g.label}</span></span></Fragment>)}
</div>
</div>
<div className="fz-phone hide-s" style={css(v.phoneB)} data-lab-style="phoneB"><div className="fz-bezel"><div className="fz-screen"><img src="/images/landing-lab/app-capture.jpg" alt="The Capture screen listing each object from the photo as its own row" /></div></div></div>
</div>
</div>
</section>

<section id="graph" style={css(v.graphSec)} data-lab-style="graphSec">
<div style={css(v.pinStyle)} data-lab-style="pinStyle">
<div className="wrap split" style={css("height:100%;grid-template-columns:minmax(0,.75fr) minmax(0,1.5fr);gap:40px")}>
<div>
<h2 className="h2" style={css("margin-top:16px;color:#FFF;font-size:clamp(32px,3.4vw,50px)")}>{"Knowing what it is is useful. Knowing everything around it is memory."}</h2>
<p className="lede hide-s" style={css("color:#A3A3A3")}>{"The charger from your bench photo is not just a label anymore. FindEZ knows where it lives, when you bought it, the manual, which batteries it charges, the project it belongs to and when it was last seen."}</p>
</div>
<div className="float" style={css("position:relative;container-type:inline-size")}>
<svg viewBox="0 0 1000 640" aria-hidden="true" style={css("display:block;width:100%;height:auto")}>
{v.edges.map((e, i) => <Fragment key={i}><path d={e.d} data-lab-d={`edges.${i}.d`} pathLength="1" fill="none" stroke="rgba(255,255,255,.5)" strokeWidth="1.2" style={css(e.style)} data-lab-style={`edges.${i}.style`} data-lab-row={`edges.${i}`}></path></Fragment>)}
<circle cx="500" cy="320" r="90" fill="none" stroke="rgba(232,89,12,.45)"><animate attributeName="r" values="90;210" dur="3s" repeatCount="indefinite"></animate><animate attributeName="opacity" values="1;0" dur="3s" repeatCount="indefinite"></animate></circle>
</svg>
<div role="img" aria-label="The battery charger from the bench photo, connected to where it lives, when it was bought, its manual and receipt, the batteries it charges, its project and when it was last seen" style={css("position:absolute;inset:0")}>
{v.edges.map((e, i) => <Fragment key={i}><span style={css(e.lab)} data-lab-style={`edges.${i}.lab`} data-lab-row={`edges.${i}`}><span data-lab-text={`edges.${i}.rel`}>{e.rel}</span></span></Fragment>)}
{v.nodes.map((n, i) => <Fragment key={i}><div style={css(n.box)} data-lab-style={`nodes.${i}.box`} data-lab-row={`nodes.${i}`}><div style={css(n.ks)} data-lab-style={`nodes.${i}.ks`}><span data-lab-text={`nodes.${i}.k`}>{n.k}</span></div><div style={css("font-size:1.6cqw;color:#FFF;margin-top:.35cqw;white-space:nowrap;letter-spacing:-.01em")}><span data-lab-text={`nodes.${i}.v`}>{n.v}</span></div></div></Fragment>)}
<div style={css("position:absolute;left:33%;top:41%;width:34%;height:18%;box-sizing:border-box;background:#FFF;border-radius:1.4cqw;display:flex;align-items:center;gap:1.4cqw;padding:1.1cqw")}>
<div style={css("position:relative;width:9.4cqw;height:9.4cqw;flex:none;border-radius:.9cqw;overflow:hidden;background:#DDD")}><img src="/images/landing-lab/bench.jpg" alt="" style={css("position:absolute;width:347.8%;max-width:none;left:-164.3%;top:-39.1%")} /></div>
<div style={css("min-width:0")}><div style={css("font-family:var(--fzl-mono),monospace;font-size:.95cqw;letter-spacing:.05em;color:#8C8C8C")}>{"FROM YOUR BENCH PHOTO"}</div><div style={css("font-size:2.1cqw;color:#000;margin-top:.5cqw;letter-spacing:-.015em;line-height:1.1")}>{"Battery charger, 18V"}</div><div style={css("font-family:var(--fzl-mono),monospace;font-size:.95cqw;letter-spacing:.05em;color:#C2410C;margin-top:.6cqw")}>{"CONFIDENCE 0.97"}</div></div>
</div>
</div>
</div>
</div>
</div>
</section>

<section id="zoom" style={css(v.zoomSec)} data-lab-style="zoomSec">
<div style={css(v.pinTop)} data-lab-style="pinTop">
<div className="wrap" style={css("padding-top:84px;text-align:center")}>
<h2 className="h2" style={css("margin-top:14px")}>{"Not just \u201cWorkshop\u201d. Exactly where."}</h2>
</div>
<div style={css(v.zoomBox)} data-lab-style="zoomBox">
<div style={css("position:relative;border-radius:14px;overflow:hidden;background:#1A1A1A;aspect-ratio:1000/560;container-type:inline-size")}>
<img src="/images/landing-lab/bench-zoom.jpg" alt="Zooming into the workshop photo: the workbench, the parts cabinet, row 5, and drawer PN-F40 labelled Set screw size m4" style={css(v.zImg)} data-lab-style="zImg" />
{v.zBoxes.map((b, i) => <Fragment key={i}><div style={css(b.box)} data-lab-style={`zBoxes.${i}.box`} data-lab-row={`zBoxes.${i}`}><span style={css(b.tag)} data-lab-style={`zBoxes.${i}.tag`}><span data-lab-text={`zBoxes.${i}.t`}>{b.t}</span></span></div></Fragment>)}
<div style={css(v.zCard)} data-lab-style="zCard">
<div style={css("font-family:var(--fzl-mono),monospace;font-size:1.05cqw;letter-spacing:.05em;color:#C2410C")}>{"FOUND"}</div>
<div style={css("font-size:2.6cqw;letter-spacing:-.02em;margin-top:.5cqw;color:#111112")}>{"M4 set screws"}</div>
<div style={css("font-family:var(--fzl-mono),monospace;font-size:1.05cqw;letter-spacing:.05em;color:#8C8C8C;margin-top:.7cqw")}>{"DRAWER PN-F40 \u00b7 ROW 5 \u00b7 PARTS CABINET"}</div>
</div>
</div>
<div style={css("display:flex;flex-wrap:wrap;justify-content:center;gap:6px 10px;margin-top:22px;font-size:17px")}>
{v.crumbs.map((b, i) => <Fragment key={i}><span style={css(b.style)} data-lab-style={`crumbs.${i}.style`} data-lab-row={`crumbs.${i}`}><span data-lab-text={`crumbs.${i}.t`}>{b.t}</span></span></Fragment>)}
</div>
</div>
</div>
</section>

<section id="ask" style={css(v.askSec)} data-lab-style="askSec">
<div className="wrap split">
<div>
<h2 className="h2" style={css("margin-top:16px")}>{"Ask the memory, not a chatbot."}</h2>
<p className="lede">{"Every question goes to what FindEZ actually knows about your things. The answer shows what it used."}</p>
<p className="mono" style={css("color:#A3A3A3;margin-top:24px")}>{"Example conversations"}</p>
</div>
<div style={css(v.askCard)} data-lab-style="askCard">
<div style={css("display:flex;gap:6px")}><span style={css("width:10px;height:10px;border-radius:50%;background:#E5E5E5")}></span><span style={css("width:10px;height:10px;border-radius:50%;background:#E5E5E5")}></span><span style={css("width:10px;height:10px;border-radius:50%;background:#E5E5E5")}></span></div>
<div style={css("align-self:flex-end;background:#000;color:#FFF;border-radius:16px 16px 4px 16px;padding:12px 16px;font-size:16px;max-width:80%")}><span data-lab-text="chatQ">{v.chatQ}</span><span className="caret" style={css("background:#FFF")} data-lab-show="typingQ" hidden={!v.typingQ}></span></div>
<div className="mono" style={css("color:#8C8C8C")} data-lab-show="thinking" hidden={!v.thinking}>{"Searching your memory\u2026"}</div>
<div style={css("font-size:20px;line-height:1.45;letter-spacing:-.01em;min-height:90px")}><span data-lab-text="chatA">{v.chatA}</span><span className="caret" data-lab-show="typingA" hidden={!v.typingA}></span></div>
<div style={css("display:flex;gap:6px;flex-wrap:wrap;margin-top:auto")}>
{v.chatCtx.map((x, i) => <Fragment key={i}><span className="mono" style={css(x.style)} data-lab-style={`chatCtx.${i}.style`} data-lab-row={`chatCtx.${i}`}><span data-lab-text={`chatCtx.${i}.t`}>{x.t}</span></span></Fragment>)}
</div>
</div>
</div>
</section>

<section id="own" className="wrap" style={css("padding-top:150px;padding-bottom:140px")}>
<div className="split">
<div style={css("position:relative;border-radius:14px;overflow:hidden;background:linear-gradient(#1C1C1C,#111);aspect-ratio:16/11;container-type:inline-size")}>
<svg viewBox="0 0 800 550" role="img" aria-label="A camera recognizing a USB-C hub and finding two similar ones you already own" style={css("position:absolute;inset:0;width:100%;height:100%")}>
<g stroke="#FFF" strokeWidth="2" fill="none" opacity=".8"><path d="M60 100 V60 H100"></path><path d="M700 60 H740 V100"></path><path d="M740 450 V490 H700"></path><path d="M100 490 H60 V450"></path></g>
<g style={css(v.ownProd)} data-lab-style="ownProd"><rect x="300" y="220" width="200" height="110" rx="16" fill="#3A3A3A"></rect><rect x="320" y="255" width="22" height="12" rx="3" fill="#202020"></rect><rect x="352" y="255" width="22" height="12" rx="3" fill="#202020"></rect><rect x="384" y="255" width="22" height="12" rx="3" fill="#202020"></rect><rect x="416" y="255" width="40" height="12" rx="3" fill="#202020"></rect><rect x="290" y="210" width="220" height="130" rx="20" fill="none" style={css(v.ownBox)} data-lab-style="ownBox"></rect></g>
<circle cx="400" cy="420" r="38" fill="none" stroke="#333" strokeWidth="5"></circle>
<circle cx="400" cy="420" r="38" fill="none" stroke="#E8590C" strokeWidth="5" pathLength="100" transform="rotate(-90 400 420)" style={css(v.ownRing)} data-lab-style="ownRing"></circle>
<text x="400" y="182" textAnchor="middle" fontFamily="Geist Mono, monospace" fontSize="12" fill="#A3A3A3" style={css(v.ownLabel)} data-lab-style="ownLabel">{"USB-C HUB \u00b7 7-PORT"}</text>
</svg>
<div style={css("position:absolute;left:50%;top:76.4%;transform:translate(-50%,-50%);color:#FFF;font-size:2.3cqw")}><span data-lab-text="ownPct">{v.ownPct}</span></div>
</div>
<div>
<h2 className="h2" style={css("margin-top:16px")}>{"Point. Check. Don't buy it twice."}</h2>
<p className="lede">{"Aim the camera at something in a store. FindEZ compares it with everything you own."}</p>
<div style={css(v.ownCard)} data-lab-style="ownCard">
<div style={css("font-size:19px;letter-spacing:-.01em")}>{"You already own 2 similar hubs."}</div>
<div className="mono" style={css("color:#8C8C8C;margin-top:10px")}>{"Workshop \u203a Electronics bin"}</div>
<div className="mono" style={css("color:#8C8C8C;margin-top:4px")}>{"Office \u203a Desk drawer"}</div>
</div>
</div>
</div>
</section>

<section id="who" style={css(v.whoSec)} data-lab-style="whoSec">
<div className="wrap" style={css("text-align:center")}>
<h2 className="h2" style={css("color:#FFF;max-width:18ch;margin:0 auto")}>{"One memory for anyone who owns, shares or manages things."}</h2>
</div>
<div style={css("margin-top:60px;display:flex;flex-direction:column;gap:12px")}>
<div className="marq">
{v.rowA.map((t, i) => <Fragment key={i}><span className="pill" style={css(t.s)} data-lab-style={`rowA.${i}.s`} data-lab-row={`rowA.${i}`}><span data-lab-text={`rowA.${i}.t`}>{t.t}</span></span></Fragment>)}
</div>
<div className="marq r">
{v.rowB.map((t, i) => <Fragment key={i}><span className="pill" style={css(t.s)} data-lab-style={`rowB.${i}.s`} data-lab-row={`rowB.${i}`}><span data-lab-text={`rowB.${i}.t`}>{t.t}</span></span></Fragment>)}
</div>
</div>
</section>

<section id="find" className="wrap" style={css(v.findSec)} data-lab-style="findSec">
<h2 className="h2" style={css("margin-top:16px;max-width:15ch")}>{"Not one giant model. A pipeline."}</h2>
<p className="lede" style={css("max-width:600px")}>{"Precise tools wherever they work, deeper reasoning only for the hard cases, and every correction you make feeding back into FIND."}</p>
<div style={css("margin-top:60px;overflow-x:auto")}>
<div style={css("position:relative;min-width:640px;container-type:inline-size")}>
<svg viewBox="0 0 1100 320" role="img" aria-label="Objects flow through perceive, identify, confidence, context and memory; uncertain ones take a closer look; corrections loop back" style={css("display:block;width:100%;height:auto")}>
<path d="M60 150 H1040" stroke="#E5E5E5" strokeWidth="2" fill="none"></path>
<path d="M520 150 C520 250 710 250 710 150" stroke="#E5E5E5" strokeWidth="2" fill="none" strokeDasharray="4 6"></path>
<path d="M900 150 C900 40 140 40 140 150" stroke="#F3C9B1" strokeWidth="2" fill="none" strokeDasharray="4 6"></path>
<circle cx="140" cy="150" r="9" fill="#FFF" stroke="#111112" strokeWidth="2"></circle>
<circle cx="330" cy="150" r="9" fill="#FFF" stroke="#111112" strokeWidth="2"></circle>
<circle cx="520" cy="150" r="9" fill="#FFF" stroke="#111112" strokeWidth="2"></circle>
<circle cx="710" cy="150" r="9" fill="#FFF" stroke="#111112" strokeWidth="2"></circle>
<circle cx="900" cy="150" r="9" fill="#FFF" stroke="#111112" strokeWidth="2"></circle>
<text x="615" y="262" textAnchor="middle" fontFamily="Geist Mono, monospace" fontSize="10" fill="#79648C">{"UNSURE \u00b7 CLOSER LOOK"}</text>
<text x="520" y="58" textAnchor="middle" fontFamily="Geist Mono, monospace" fontSize="10" fill="#C2410C">{"YOUR CORRECTIONS \u00b7 FIND LEARNS"}</text>
<circle r="5" fill="#111112"><animateMotion dur="6s" begin="-0s" repeatCount="indefinite" path="M60 150 H1040"></animateMotion></circle>
<circle r="5" fill="#111112"><animateMotion dur="6s" begin="-1s" repeatCount="indefinite" path="M60 150 H1040"></animateMotion></circle>
<circle r="5" fill="#111112"><animateMotion dur="6s" begin="-2s" repeatCount="indefinite" path="M60 150 H1040"></animateMotion></circle>
<circle r="5" fill="#111112"><animateMotion dur="6s" begin="-3s" repeatCount="indefinite" path="M60 150 H1040"></animateMotion></circle>
<circle r="5" fill="#111112"><animateMotion dur="6s" begin="-4s" repeatCount="indefinite" path="M60 150 H1040"></animateMotion></circle>
<circle r="5" fill="#111112"><animateMotion dur="6s" begin="-5s" repeatCount="indefinite" path="M60 150 H1040"></animateMotion></circle>
<circle r="5" fill="#79648C"><animateMotion dur="8s" begin="-0s" repeatCount="indefinite" path="M60 150 H520 C520 250 710 250 710 150 H1040"></animateMotion></circle>
<circle r="5" fill="#79648C"><animateMotion dur="8s" begin="-4s" repeatCount="indefinite" path="M60 150 H520 C520 250 710 250 710 150 H1040"></animateMotion></circle>
<circle r="4" fill="#E8590C"><animateMotion dur="7s" begin="-0.0s" repeatCount="indefinite" path="M900 150 C900 40 140 40 140 150"></animateMotion></circle>
<circle r="4" fill="#E8590C"><animateMotion dur="7s" begin="-3.5s" repeatCount="indefinite" path="M900 150 C900 40 140 40 140 150"></animateMotion></circle>
</svg>
{v.pipeNodes.map((n, i) => <Fragment key={i}><div style={css(n.s)} data-lab-style={`pipeNodes.${i}.s`} data-lab-row={`pipeNodes.${i}`}><div style={css("font-size:1.55cqw;color:#000")}><span data-lab-text={`pipeNodes.${i}.t`}>{n.t}</span></div><div style={css("font-family:var(--fzl-mono),monospace;font-size:.92cqw;letter-spacing:.05em;color:#8C8C8C;margin-top:.5cqw")}><span data-lab-text={`pipeNodes.${i}.d`}>{n.d}</span></div></div></Fragment>)}
</div>
</div>
</section>

<section id="vision" style={css(v.visSec)} data-lab-style="visSec">
<div style={css("max-width:1200px;margin:0 auto;padding:0 24px")}>
<div style={css(v.visHead)} data-lab-style="visHead">
<h2 className="h2" style={css("margin-top:16px;max-width:16ch")}>{"From inventory to action."}</h2>
<p className="lede">{"Today FindEZ knows what you have and where it is. Next, it learns what everything is for."}</p>
</div>
<div style={css("position:relative;margin-top:76px")}>
<div className="hide-s" style={css("position:absolute;left:10%;right:10%;top:15px;height:2px;background:#D4D4D4")}><div style={css(v.roadFill)} data-lab-style="roadFill"></div><div style={css(v.roadDot)} data-lab-style="roadDot"></div></div>
<div className="cols5" style={css("display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px")}>
{v.stages.map((g, i) => <Fragment key={i}>
<div style={css(g.wrap)} data-lab-style={`stages.${i}.wrap`} data-lab-row={`stages.${i}`}>
<div style={css(g.node)} data-lab-style={`stages.${i}.node`}></div>
<div style={css("font-size:clamp(22px,2vw,28px);letter-spacing:-.02em;margin-top:26px")}><span data-lab-text={`stages.${i}.t`}>{g.t}</span></div>
<div style={css(g.chip)} data-lab-style={`stages.${i}.chip`}><span data-lab-text={`stages.${i}.st`}>{g.st}</span></div>
<p style={css("color:#6B6B6B;font-size:15px;line-height:1.55;margin:14px auto 0;max-width:24ch")}><span data-lab-text={`stages.${i}.d`}>{g.d}</span></p>
</div>
</Fragment>)}
</div>
</div>
</div>
</section>

<section id="app" style={css("padding:140px 0 120px;overflow:hidden")}>
<div className="wrap" style={css("text-align:center")}>
<h2 className="h2" style={css("margin:16px auto 0;max-width:16ch")}>{"Capture. Ask. Find."}</h2>
<p className="lede" style={css("margin:18px auto 0")}>{"Everything you own, remembered, in one app that stays in sync with the web."}</p>
</div>
<div style={css(v.fanBox)} data-lab-style="fanBox">
{v.fan.map((f, i) => <Fragment key={i}>
<div style={css(f.wrap)} data-lab-style={`fan.${i}.wrap`} data-lab-row={`fan.${i}`}>
<div className="fz-phone" style={css("width:100%")}><div className="fz-bezel"><div className="fz-screen"><img src={f.src} data-lab-src={`fan.${i}.src`} alt={f.alt} data-lab-alt={`fan.${i}.alt`} /></div></div></div>
<div className="mono" style={css(f.lab)} data-lab-style={`fan.${i}.lab`}><span data-lab-text={`fan.${i}.t`}>{f.t}</span></div>
</div>
</Fragment>)}
</div>
</section>
<section id="waitlist" style={css("padding:12px 0")}>
<div style={css(v.wlCard)} data-lab-style="wlCard">
<h2 className="h2" style={css("margin:16px auto 0;max-width:16ch;color:#FFF")}>{"Be first on the iPhone app."}</h2>
<p style={css("color:#A3A3A3;font-size:17px;line-height:1.55;max-width:460px;margin:16px auto 0")}>{"Join the waitlist and we will email you the day FindEZ lands on the App Store."}</p>

<div style={css("display:flex;gap:8px;max-width:440px;margin:30px auto 0;background:#1A1A1A;border:1px solid #2A2A2A;border-radius:10px;padding:6px 6px 6px 16px")} data-lab-show="notJoined" hidden={!v.notJoined}>
<label htmlFor="em" style={css("position:absolute;left:-9999px")}>{"Email address"}</label>
<input id="em" type="email" className="inp" placeholder="you@example.com" style={css("color:#FFF;font-size:16px;padding:10px 0")} defaultValue="" autoComplete="email" />
<button type="button" className="btn" style={css("background:#FFF;color:#000;padding:11px 18px;font-size:14.5px")} data-lab-join="">{"Join waitlist"}</button>
</div>
<p style={css("color:#C9B79C;font-size:14px;margin:10px 0 0")} data-lab-show="emailErr" hidden={!v.emailErr}>{"Enter an email address like you@example.com."}</p>


<div style={css("display:inline-flex;align-items:center;gap:10px;margin-top:30px;background:#1A1A1A;border-radius:10px;padding:14px 20px;font-size:16px;animation:fzl-pop .35s ease")} data-lab-show="joined" hidden={!v.joined}><span style={css("width:8px;height:8px;border-radius:50%;background:#E8590C")}></span>{"You are on the list. We will email "}<span data-lab-text="email">{v.email}</span>{" at launch."}</div>

</div>
</section>
<footer id="end" style={css("padding:110px 24px 28px")}>
<div style={css("max-width:1200px;margin:0 auto")}>
<h2 className="h2" style={css("max-width:16ch")}>{"Take a picture. FindEZ remembers."}</h2>
<div style={css("display:flex;gap:10px;flex-wrap:wrap;margin-top:28px")}><a href="/signup" className="btn" style={css("background:#000;color:#FFF")}>{"Try FindEZ on the web"}</a><a href="#waitlist" className="btn" style={css("border:1px solid #E5E5E5")}>{"Join the iPhone waitlist"}</a></div>
<svg viewBox="123 25 171 46" aria-hidden="true" style={css("display:block;width:100%;height:auto;margin:90px 0 28px;overflow:visible")}>
<g transform="translate(124.8,69.12) scale(0.057942) translate(-90,0)">
{v.letters.map((L, i) => <Fragment key={i}><path d={L.d} data-lab-d={`letters.${i}.d`} fill={L.fill} data-lab-fill={`letters.${i}.fill`} style={css(L.style)} data-lab-style={`letters.${i}.style`} data-lab-row={`letters.${i}`}></path></Fragment>)}
</g>
</svg>
{siteNavigation ? <div className="fzl-site-footer">
  <span>{"\u00a9 2026 AI Robots Inc."}</span>
  <nav aria-label="Footer navigation">
    <a href="/pricing">Plans</a><a href="/docs/api">Developers</a>
    <a href="https://apps.apple.com/us/app/findez-ai/id6760401697" target="_blank" rel="noopener noreferrer">iOS App</a>
    <a href="/privacy">Privacy</a><a href="/terms">Terms</a><a href="mailto:info@findez.ai">Contact</a>
  </nav>
</div> : <div className="mono" style={css("display:flex;justify-content:space-between;flex-wrap:wrap;gap:10px;border-top:1px solid #E5E5E5;padding-top:16px;color:#8C8C8C")}><span>{"\u00a9 2026 AI Robots Inc."}</span><span>{"info@findez.ai"}</span></div>}
</div>
</footer>
</div>
</>);
}
