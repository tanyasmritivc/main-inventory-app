"use client";

/* The supplied 4:3 image and its unmodified pixels define the detection geometry. */
/* eslint-disable @next/next/no-img-element */
import { useEffect, useRef } from "react";
import { DETECTIONS, init } from "./hero-morph-engine";
import "./hero-morph.css";

export function HeroMorph() {
  const root = useRef<HTMLElement>(null);
  useEffect(() => {
    if (root.current) return init(root.current);
  }, []);

  return <section id="hero" className="fzh" ref={root} aria-label="FindEZ">
    <div className="fzh-stage">
      <div className="fzh-inner">
        <div className="fzh-abs fzh-text">
          <h1 className="fzh-h1">FindEZ gives the physical world <span className="fzh-orange">a memory.</span></h1>
          <p className="fzh-sub">You don&apos;t organize your physical world for FindEZ. FindEZ organizes it for you.</p>
          <div className="fzh-ctas">
            <a className="fzh-btn dark" href="/signup">Try FindEZ on the web</a>
            <a className="fzh-btn line" href="https://apps.apple.com/us/app/findez-ai/id6760401697">
              <svg width="11" height="16" viewBox="0 0 11 16" fill="none" stroke="#111112" strokeWidth="1.5" aria-hidden="true"><rect x=".75" y=".75" width="9.5" height="14.5" rx="2.4" /><path d="M4.2 12.8h2.6" strokeLinecap="round" /></svg>
              Get the iPhone app
            </a>
          </div>
        </div>

        <div className="fzh-abs fzh-s2">
          <div className="fzh-eyebrow fzh-mono">Capture</div>
          <h2 className="fzh-h2">Take a picture.<br /><span className="fzh-orange">That is it.</span></h2>
          <p className="fzh-body">No forms, no categories, no typing. FIND separates every object in the photo, counts it, and tells you how sure it is.</p>
          <div className="fzh-stats">
            <div><div className="fzh-num fzh-found">0</div><div className="fzh-statlabel fzh-mono">Objects found</div></div>
            <div><div className="fzh-num fzh-orange fzh-needs">0</div><div className="fzh-statlabel fzh-mono">Needs a look</div></div>
          </div>
        </div>

        <div className="fzh-abs fzh-photo">
          <img className="fzh-base" src="/images/landing/hero-workbench.jpg" alt="A workbench with an 18V battery charger, parts bins and a labelled parts cabinet" width="1600" height="1200" fetchPriority="high" />
          <img className="fzh-lit" src="/images/landing/hero-workbench.jpg" alt="" aria-hidden="true" width="1600" height="1200" />
          <div className="fzh-dets">
            {DETECTIONS.map(([x, y, w, h, label, confidence]) => <div key={label} className={`fzh-det${Number(confidence) < 0.80 ? " low" : ""}`} style={{ left: `${x - w / 2}%`, top: `${y - h / 2}%`, width: `${w}%`, height: `${h}%`, opacity: 0 }}>
              <span className="fzh-mono">{label} {confidence}</span>
            </div>)}
          </div>
          <div className="fzh-lens" aria-hidden="true" />
          <span className="fzh-corner fzh-mono fzh-hint">Move your cursor to scan</span>
          <span className="fzh-corner fzh-mono fzh-count">0 objects in view</span>
        </div>

        <div className="fzh-abs fzh-card">
          <header><span className="fzh-card-title">Workshop › Workbench</span><span className="fzh-mono fzh-today">Today</span></header>
          <ul>
            <li><span className="fzh-item">Battery charger, 18V</span><span className="qty fzh-mono">x1</span><span className="conf fzh-mono">0.97</span></li>
            <li><span className="fzh-item">Duct tape</span><span className="qty fzh-mono">x1</span><span className="conf fzh-mono">0.93</span></li>
            <li><span className="fzh-item">Socket head screws</span><span className="qty fzh-mono">x40</span><span className="conf fzh-mono">0.91</span></li>
            <li><span className="fzh-item">Gearbox housing</span><span className="qty fzh-mono">x2</span><span className="conf fzh-mono low">0.79</span></li>
          </ul>
          <div className="fzh-ask" aria-live="polite" aria-atomic="true">
            <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="#6B6B6B" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true"><circle cx="7" cy="7" r="5.2" /><path d="m11 11 3.5 3.5" /></svg>
            <span className="q fzh-q">Where’s the duct tape</span><span className="caret" aria-hidden="true" />
            <span className="a fzh-a">Workbench › Middle</span>
          </div>
        </div>

        <div className="fzh-abs fzh-chip">
          <span className="vf" aria-hidden="true"><svg width="20" height="20" viewBox="0 0 22 22" fill="none" stroke="#111112" strokeWidth="1.9" strokeLinecap="round"><path d="M1.5 7V4a2.5 2.5 0 0 1 2.5-2.5h3M15 1.5h3A2.5 2.5 0 0 1 20.5 4v3M20.5 15v3a2.5 2.5 0 0 1-2.5 2.5h-3M7 20.5H4A2.5 2.5 0 0 1 1.5 18v-3" /></svg><i /></span>
          Remembering 6 objects
        </div>
      </div>
    </div>
  </section>;
}
