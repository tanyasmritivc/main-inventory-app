import Link from "next/link";
import type { ReactNode } from "react";

import { MarketingNav } from "@/components/site/marketing-nav";

export const PRODUCT_LINKS = [
  { label: "Product Overview", href: "/product" },
  { label: "Capture Items", href: "/product/capture" },
  { label: "Ask FindEZ", href: "/product/ask" },
  { label: "Spaces & Sharing", href: "/product/spaces-and-sharing" },
];

export function ProductMarketingShell({ children }: { children: ReactNode }) {
  return (
    <div className="product-marketing-shell">
      <MarketingNav />
      <main>{children}</main>
      <MarketingFooter />
    </div>
  );
}

export function MarketingFooter() {
  return (
    <>
      <footer className="product-footer">
        <div className="product-footer__inner">
          <Link href="/" className="product-footer__brand">FindEZ</Link>
          <nav aria-label="Footer navigation">
            <Link href="/product">Product</Link>
            <a href="https://apps.apple.com/app/findez/id6746827458" target="_blank" rel="noopener noreferrer">iOS App</a>
            <Link href="/robotics">Robotics Teams</Link>
            <Link href="/pricing">Pricing</Link>
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
            <a href="mailto:vinodrexfms@ai-robots.co">Contact</a>
          </nav>
          <span>© {new Date().getFullYear()} AI Robots Inc.</span>
        </div>
      </footer>
      <style>{`
        .product-footer { border-top:1px solid rgba(255,255,255,.07); background:#090a0d; }
        .product-footer__inner { width:min(1120px,calc(100% - 48px)); min-height:110px; margin:0 auto; display:flex; align-items:center; gap:28px; color:rgba(255,255,255,.27); font-size:11px; }
        .product-footer__brand { color:#fff; font-family:var(--font-syne,sans-serif); font-size:16px; font-weight:700; text-decoration:none; }
        .product-footer nav { display:flex; flex:1; gap:18px; flex-wrap:wrap; }
        .product-footer nav a { color:rgba(255,255,255,.4); text-decoration:none; }
        @media (max-width:760px) {
          .product-footer__inner { width:min(100% - 32px,1120px); padding:30px 0; align-items:flex-start; flex-direction:column; }
          .product-footer nav { flex:none; }
        }
      `}</style>
    </>
  );
}

export function ProductHero({ eyebrow, title, description, children }: { eyebrow: string; title: ReactNode; description: string; children?: ReactNode }) {
  return (
    <section className="product-hero">
      <div className="product-hero__glow" aria-hidden="true" />
      <div className="product-wrap product-hero__content">
        <div className="product-eyebrow">{eyebrow}</div>
        <h1>{title}</h1>
        <p>{description}</p>
        {children ?? (
          <div className="product-actions">
            <Link href="/signup" className="product-button product-button--primary">Get started free</Link>
            <Link href="/product" className="product-button product-button--secondary">Explore the product</Link>
          </div>
        )}
      </div>
    </section>
  );
}

export function ProductCta() {
  return (
    <section className="product-cta product-wrap">
      <div>
        <span className="product-eyebrow">Your inventory, ready when you need it</span>
        <h2>Know what you have.<br />Find what you need. Instantly.</h2>
      </div>
      <Link href="/signup" className="product-button product-button--primary">Get started free</Link>
    </section>
  );
}

export function ProductPageStyles() {
  return (
    <style>{`
      .product-marketing-shell { min-height:100vh; color:#f5f5f7; background:#090a0d; font-family:var(--font-dm-sans,system-ui,sans-serif); }
      .product-wrap { width:min(1120px,calc(100% - 48px)); margin:0 auto; }
      .product-hero { position:relative; overflow:hidden; border-bottom:1px solid rgba(255,255,255,.07); }
      .product-hero__glow { position:absolute; width:720px; height:520px; left:50%; top:-330px; transform:translateX(-50%); border-radius:50%; background:radial-gradient(circle,rgba(20,184,166,.22),rgba(20,184,166,0) 68%); pointer-events:none; }
      .product-hero__content { position:relative; padding:112px 0 104px; text-align:center; }
      .product-eyebrow { color:#5eead4; font-size:11px; font-weight:700; letter-spacing:.12em; text-transform:uppercase; }
      .product-hero h1 { max-width:900px; margin:18px auto 0; color:#fff; font-family:var(--font-syne,sans-serif); font-size:clamp(42px,7vw,76px); font-weight:650; line-height:1.04; letter-spacing:-.055em; }
      .product-hero p { max-width:650px; margin:24px auto 0; color:rgba(255,255,255,.5); font-size:clamp(16px,2vw,19px); line-height:1.6; }
      .product-actions { display:flex; justify-content:center; gap:10px; margin-top:36px; flex-wrap:wrap; }
      .product-button { display:inline-flex; align-items:center; justify-content:center; min-height:44px; padding:0 21px; border:1px solid transparent; border-radius:999px; font-size:13px; font-weight:700; text-decoration:none; transition:transform 150ms ease,background 150ms ease; }
      .product-button:hover { transform:translateY(-1px); }
      .product-button--primary { color:#07110f; background:#fff; }
      .product-button--secondary { color:#fff; border-color:rgba(255,255,255,.13); background:rgba(255,255,255,.05); }
      .product-section { padding:104px 0; }
      .product-section--bordered { border-top:1px solid rgba(255,255,255,.07); }
      .product-section__intro { max-width:670px; margin-bottom:48px; }
      .product-section__intro h2,.product-cta h2 { margin:14px 0 0; color:#fff; font-family:var(--font-syne,sans-serif); font-size:clamp(30px,4vw,46px); font-weight:650; line-height:1.12; letter-spacing:-.04em; }
      .product-section__intro p { margin:16px 0 0; color:rgba(255,255,255,.46); font-size:16px; line-height:1.65; }
      .product-card-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:14px; }
      .product-card-grid--two { grid-template-columns:repeat(2,1fr); }
      .product-card { min-height:210px; padding:27px; border:1px solid rgba(255,255,255,.08); border-radius:16px; background:rgba(255,255,255,.025); }
      .product-card__number { color:rgba(94,234,212,.58); font-family:var(--font-syne,sans-serif); font-size:12px; font-weight:700; }
      .product-card h3 { margin:30px 0 0; color:#fff; font-size:18px; font-weight:650; letter-spacing:-.025em; }
      .product-card p { margin:9px 0 0; color:rgba(255,255,255,.4); font-size:14px; line-height:1.58; }
      .product-card a { display:inline-block; margin-top:22px; color:#5eead4; font-size:12px; font-weight:650; text-decoration:none; }
      .product-flow { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; counter-reset:flow; }
      .product-flow__step { position:relative; min-height:230px; padding:28px; overflow:hidden; border:1px solid rgba(255,255,255,.08); border-radius:17px; background:rgba(255,255,255,.025); counter-increment:flow; }
      .product-flow__step::after { content:counter(flow,decimal-leading-zero); position:absolute; right:18px; bottom:-16px; color:rgba(255,255,255,.035); font-family:var(--font-syne,sans-serif); font-size:92px; font-weight:800; }
      .product-flow__step h3 { margin:54px 0 0; color:#fff; font-size:18px; font-weight:650; letter-spacing:-.025em; }
      .product-flow__step p { position:relative; z-index:1; margin:10px 0 0; color:rgba(255,255,255,.4); font-size:14px; line-height:1.58; }
      .product-methods { display:grid; grid-template-columns:repeat(5,1fr); gap:10px; }
      .product-method { padding:22px 20px; border:1px solid rgba(255,255,255,.08); border-radius:14px; background:rgba(255,255,255,.025); }
      .product-method strong { display:block; color:#fff; font-size:14px; line-height:1.35; }
      .product-method span { display:block; margin-top:8px; color:rgba(255,255,255,.38); font-size:12px; line-height:1.5; }
      .product-demo { padding:28px; border:1px solid rgba(255,255,255,.09); border-radius:20px; background:linear-gradient(145deg,rgba(20,184,166,.08),rgba(255,255,255,.02)); }
      .product-demo__bar { display:flex; align-items:center; gap:7px; padding-bottom:20px; border-bottom:1px solid rgba(255,255,255,.07); }
      .product-demo__bar span { width:7px; height:7px; border-radius:50%; background:rgba(255,255,255,.18); }
      .product-demo__content { padding:40px 20px 22px; }
      .product-demo__prompt { max-width:640px; margin:0 auto; padding:18px 20px; border:1px solid rgba(255,255,255,.13); border-radius:12px; color:rgba(255,255,255,.82); font-size:15px; }
      .product-demo__prompt + .product-demo__prompt { margin-top:10px; }
      .product-demo__answer { max-width:640px; margin:14px auto 0; padding:18px 20px; color:rgba(255,255,255,.53); font-size:14px; line-height:1.6; }
      .product-facts { display:grid; grid-template-columns:repeat(4,1fr); gap:1px; overflow:hidden; border:1px solid rgba(255,255,255,.07); border-radius:16px; background:rgba(255,255,255,.07); }
      .product-fact { padding:25px; background:#0d0e12; }
      .product-fact strong { display:block; color:#fff; font-size:14px; }
      .product-fact span { display:block; margin-top:7px; color:rgba(255,255,255,.36); font-size:12px; line-height:1.45; }
      .product-cta { margin-top:30px; margin-bottom:100px; padding:52px; display:flex; align-items:center; justify-content:space-between; gap:30px; border:1px solid rgba(94,234,212,.16); border-radius:22px; background:rgba(20,184,166,.06); }
      .product-cta h2 { font-size:clamp(27px,4vw,42px); }
      @media (max-width:760px) {
        .product-wrap,.product-footer__inner { width:min(100% - 32px,1120px); }
        .product-hero__content { padding:80px 0 72px; }
        .product-section { padding:76px 0; }
        .product-card-grid,.product-card-grid--two,.product-facts,.product-flow,.product-methods { grid-template-columns:1fr; }
        .product-card { min-height:0; }
        .product-cta { margin-bottom:70px; padding:34px 25px; align-items:flex-start; flex-direction:column; }
      }
    `}</style>
  );
}
