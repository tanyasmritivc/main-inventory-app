"use client";

/* FindEZ landing page — the markup half.
 *
 * Everything that moves lives in landing-morph-engine.ts; this file is the
 * static DOM it drives, plus the copy. Class names and ids are the contract
 * between the two, so rename them in both places or not at all.
 */

import { useEffect, useRef, type CSSProperties } from "react";
import Image from "next/image";
import Link from "next/link";

import { initLanding } from "./landing-morph-engine";
import "./landing-morph.css";

const PHOTO = "/images/findez-parts-bin-clean.jpg";
const PHOTO_ALT =
  "A green parts bin holding bearings, bolts, washers, nuts, wire and an XT60 connector";

/** Stagger a reveal. The engine reads --d off each line. */
const d = (ms: number) => ({ "--d": `${ms}ms` }) as CSSProperties;

/** A detection box painted over the photo, positioned in percentages. */
const box = (left: string, top: string, width: string, height: string) =>
  ({ left, top, width, height }) as CSSProperties;

const arrow = <em className="arw" style={{ fontStyle: "normal" }}>&#8599;</em>;

export function LandingMorph() {
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    return initLanding(root);
  }, []);

  return (
    <div className="fzL" ref={rootRef}>
      <div id="grain" aria-hidden="true" />
      <div id="retic" aria-hidden="true"><i /></div>
      <div className="rail" aria-hidden="true"><span id="railFill" /></div>

      <header id="hdr">
        <Link className="mark" href="/"><Image src="/images/findez-logo.png" alt="" width={28} height={28} priority />FindEZ</Link>
        <nav className="top-links" aria-label="Main navigation">
          <Link href="/docs/api">Developers</Link>
          <a href="https://apps.apple.com/us/app/findez-ai/id6760401697" target="_blank" rel="noopener noreferrer">iOS App</a>
        </nav>
        <Link className="cta sm" href="/signup"><span>Get started</span>{arrow}</Link>
      </header>

      <main id="top">
        {/* ============ ACT ONE — hero morphs into the statements ============ */}
        <div className="act1" id="act1">
          <div className="act1-stage" id="a1Stage">
            <canvas id="cloud" aria-hidden="true" />
            <canvas id="weave" aria-hidden="true" />

            <div className="a1-layer" id="a1Hero">
              <h1 className="huge">
                <span className="ln heroline"><i style={d(80)}>FindEZ understands</i></span>
                <span className="ln heroline"><i className="g" style={d(240)}>your environment.</i></span>
              </h1>
              <div className="hero-foot">
                <p className="kicker ln heroline">
                  <i style={d(560)}>The physical world, understood as information.</i>
                </p>
              </div>
            </div>

            <div className="a1-layer" id="a1Statements">
              <h2 className="big st">Every object has <span className="g-lite">context.</span></h2>
              <h2 className="big st st-b">Every space has <span className="g-lite">structure.</span></h2>
              <h2 className="big st st-c">Every possession has <span className="g-lite">purpose.</span></h2>
            </div>
          </div>
        </div>

        <div className="ticker" aria-hidden="true"><div className="ticker-in" id="tick" /></div>

        {/* ============ ACT TWO — object becomes record, row, result ============ */}
        <section className="morph-head" data-reveal>
          <h2 className="big">
            <span className="ln"><i style={d(0)}>From physical objects</i></span>
            <span className="ln"><i style={d(120)}>to usable knowledge.</i></span>
          </h2>
        </section>

        <div className="morph-wrap" id="morphWrap">
          <div className="morph-stage">
            <div className="rig" id="rig">
              <div className="phases" id="phases">
                <span className="ph on"><b>01</b><i />Capture</span>
                <span className="ph"><b>02</b><i />Understand</span>
                <span className="ph"><b>03</b><i />Index</span>
                <span className="ph"><b>04</b><i />Recall</span>
              </div>
              <div className="pbar"><u id="pbarFill" /></div>
              <p className="caption" id="caption">
                <span className="on">One photo of one bin.</span>
                <span>Every object identified, counted and placed.</span>
                <span>One row per object, across every space.</span>
                <span>Ask for it later in your own words.</span>
              </p>

              <figure className="actor" id="mPhoto" style={{ margin: 0 }}>
                <Image
                  src={PHOTO}
                  alt={PHOTO_ALT}
                  fill
                  priority
                  sizes="(max-width: 900px) 100vw, 70vw"
                />
                <div className="mscan" id="mScan" />
                <div className="veil" id="mVeil" />
              </figure>

              <div className="actor" id="mGhosts" style={{ pointerEvents: "none" }}>
                <div className="ghostbox" style={box("7.7%", "16.7%", "30.9%", "43.8%")}>
                  <u>motor mount</u>
                </div>
                <div className="ghostbox" style={box("77.7%", "40.9%", "4.6%", "21.9%")}>
                  <u>hex bolt</u>
                </div>
                <div className="ghostbox" style={box("86.4%", "45.0%", "11.4%", "14.9%")}>
                  <u>XT60</u>
                </div>
              </div>

              {/* the one surface that becomes all four states */}
              <div className="actor" id="mFrame">
                <div className="layer" id="lChip" style={{ padding: 0 }}>
                  <span className="chiplabel">608 bearing</span>
                </div>

                <div className="layer pad" id="lRecord">
                  <p className="r-eyebrow">Example</p>
                  <p className="r-title">608 bearing</p>
                  <dl>
                    <div className="r-row"><dt>Quantity</dt><dd>34 in stock</dd></div>
                    <div className="r-row"><dt>Location</dt><dd>Machine shop &middot; Drawer A04</dd></div>
                    <div className="r-row"><dt>Context</dt><dd>Wheel and roller assemblies</dd></div>
                  </dl>
                </div>

                <div className="layer" id="lRow">
                  <div className="irow" style={{ position: "absolute", inset: 0 }}>
                    <span className="th" aria-hidden="true" />
                    <span className="nm">608 bearing</span>
                    <span className="qt">34</span>
                    <span className="lc">Machine shop &middot; Drawer A04</span>
                  </div>
                </div>

                <div className="layer" id="lSearch">
                  <span className="pr">&#9906;</span>
                  <span id="mQuery" />
                  <span className="cur" id="mCur" />
                </div>
              </div>

              <div className="actor" id="mRows" />

              <div className="actor" id="mResult">
                <p className="rk">1 result</p>
                <p className="rt">608 bearing</p>
                <p className="rq">34 in stock</p>
                <p className="rl">Machine shop &middot; Drawer A04</p>
              </div>
            </div>

            {/* shown instead of the rig when the visitor asks for reduced motion */}
            <div className="morph-fallback">
              <Image src={PHOTO} alt={PHOTO_ALT} width={1285} height={1014} />
              <div>
                <p className="eyebrow g">Example</p>
                <p className="big fb-title">608 bearing</p>
                <div className="fb-row"><span>Quantity</span><span>34 in stock</span></div>
                <div className="fb-row"><span>Location</span><span>Machine shop &middot; Drawer A04</span></div>
                <div className="fb-row"><span>Context</span><span>Used in wheel and roller assemblies</span></div>
              </div>
            </div>
          </div>
        </div>

        <div className="divider" />

        {/* ============ THESIS ============ */}
        <section className="thesis" data-reveal id="thesis">
          <svg className="nest" viewBox="0 0 400 400" aria-hidden="true">
            <rect x="10" y="10" width="380" height="380" style={{ "--len": 1520, ...d(0) } as CSSProperties} />
            <rect x="66" y="66" width="268" height="268" style={{ "--len": 1072, ...d(180) } as CSSProperties} />
            <rect x="122" y="122" width="156" height="156" style={{ "--len": 624, ...d(360) } as CSSProperties} />
            <circle cx="200" cy="200" r="40" style={{ "--len": 252, ...d(540) } as CSSProperties} />
            <circle cx="200" cy="200" r="13" style={{ "--len": 82, ...d(720) } as CSSProperties} />
          </svg>
          <h2 className="big thesis-copy">
            <span className="ln"><i style={d(0)}>Building a <span className="g">persistent</span></i></span>
            <span className="ln"><i style={d(120)}><span className="g">understanding</span> of what</i></span>
            <span className="ln"><i style={d(240)}>you own, how you use it,</i></span>
            <span className="ln"><i style={d(360)}>and why it matters.</i></span>
          </h2>
        </section>

        {/* ============ ASK ============ */}
        <section className="ask dark" data-reveal data-dark id="ask">
          <div className="ask-grid">
            <h2 className="big">
              <span className="ln"><i style={d(0)}>Ask your</i></span>
              <span className="ln"><i style={d(110)}>environment</i></span>
              <span className="ln"><i className="g-lite" style={d(220)}>anything.</i></span>
            </h2>
            <div className="console fade" style={d(280)}>
              <p className="qline">
                <span className="pr">&rsaquo;</span>
                <span id="qtext" />
                <span className="caret" id="caret" />
              </p>
              <div className="answer">
                <div className="who">FindEZ</div>
                <div className="abody" id="abody" />
              </div>
              <div className="chips" id="chips" />
            </div>
          </div>
        </section>

        {/* ============ CLOSE ============ */}
        <section className="close" data-reveal id="start">
          <canvas id="cloud2" aria-hidden="true" />
          <h2 className="huge">
            <span className="ln"><i style={d(0)}>Give your physical world</i></span>
            <span className="ln"><i className="g" style={d(130)}>a memory.</i></span>
          </h2>
          <div className="close-foot fade" style={d(260)}>
            <span className="mark">FindEZ</span>
          </div>
        </section>
      </main>
    </div>
  );
}

export default LandingMorph;
