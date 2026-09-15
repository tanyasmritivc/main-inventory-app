"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";

const PRODUCT_ITEMS = [
  { label: "Product Overview", description: "One living inventory of what you have, how many, and where everything is.", href: "/product" },
  { label: "Capture Items", description: "Turn photos, barcodes, and spreadsheets into organized inventory.", href: "/product/capture" },
  { label: "Ask FindEZ", description: "Find items and make inventory changes using everyday language.", href: "/product/ask" },
  { label: "Spaces & Sharing", description: "Organize inventory by real-world location and share it with your team.", href: "/product/spaces-and-sharing" },
];

export function SiteNav(props: { variant: "marketing" | "app" }) {
  const pathname = usePathname();
  const [productOpen, setProductOpen] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const navRef = useRef<HTMLElement>(null);

  useEffect(() => {
    function closeOnOutsideClick(event: MouseEvent) {
      if (navRef.current && !navRef.current.contains(event.target as Node)) setProductOpen(false);
    }
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === "Escape") setProductOpen(false);
    }
    document.addEventListener("mousedown", closeOnOutsideClick);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("mousedown", closeOnOutsideClick);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, []);

  if (props.variant === "app") return null;
  const productActive = pathname === "/product" || pathname.startsWith("/product/");
  const closeMenus = () => {
    setProductOpen(false);
    setMobileOpen(false);
  };

  return (
    <header ref={navRef} className="marketing-site-nav">
      <div className="marketing-site-nav__inner">
        <Link href="/" className="marketing-site-nav__brand" aria-label="FindEZ home" onClick={closeMenus}>FindEZ</Link>

        <nav className="marketing-site-nav__desktop" aria-label="Marketing navigation">
          <div className="marketing-product-menu" onMouseEnter={() => setProductOpen(true)} onMouseLeave={() => setProductOpen(false)}>
            <div className="marketing-product-menu__trigger">
              <Link href="/product" className={productActive ? "is-active" : undefined} onFocus={() => setProductOpen(true)} onClick={closeMenus}>Product</Link>
              <button type="button" aria-label="Open Product menu" aria-expanded={productOpen} onClick={() => setProductOpen((open) => !open)}>
                <span aria-hidden="true">⌄</span>
              </button>
            </div>

            {productOpen ? (
              <div className="marketing-product-menu__panel">
                <div className="marketing-product-menu__eyebrow">FindEZ product</div>
                <div className="marketing-product-menu__grid">
                  {PRODUCT_ITEMS.map((item, index) => (
                    <Link key={item.href} href={item.href} className={index === 0 ? "is-featured" : undefined} onClick={closeMenus}>
                      <span className="marketing-product-menu__label">{item.label}</span>
                      <span className="marketing-product-menu__description">{item.description}</span>
                    </Link>
                  ))}
                </div>
                <Link href="/product" className="marketing-product-menu__footer" onClick={closeMenus}>Explore FindEZ <span aria-hidden="true">→</span></Link>
              </div>
            ) : null}
          </div>

          <Link href="/robotics" className={pathname === "/robotics" ? "is-active" : undefined} onClick={closeMenus}>For Robotics Teams</Link>
          <Link href="/pricing" className={pathname === "/pricing" ? "is-active" : undefined} onClick={closeMenus}>Pricing</Link>
        </nav>

        <div className="marketing-site-nav__actions">
          <Link href="/signin" className="marketing-site-nav__signin" onClick={closeMenus}>Sign in</Link>
          <Link href="/signup" className="marketing-site-nav__cta" onClick={closeMenus}>Get started free</Link>
          <button type="button" className="marketing-site-nav__mobile-toggle" aria-label="Toggle navigation" aria-expanded={mobileOpen} onClick={() => setMobileOpen((open) => !open)}>
            {mobileOpen ? "×" : "☰"}
          </button>
        </div>
      </div>

      {mobileOpen ? (
        <nav className="marketing-site-nav__mobile" aria-label="Mobile marketing navigation">
          <details open={productActive}>
            <summary>Product</summary>
            <div>
              {PRODUCT_ITEMS.map((item) => (
                <Link key={item.href} href={item.href} onClick={closeMenus}>
                  <span>{item.label}</span>
                  <small>{item.description}</small>
                </Link>
              ))}
            </div>
          </details>
          <Link href="/robotics" onClick={closeMenus}>For Robotics Teams</Link>
          <Link href="/pricing" onClick={closeMenus}>Pricing</Link>
          <Link href="/signin" onClick={closeMenus}>Sign in</Link>
          <Link href="/signup" className="mobile-cta" onClick={closeMenus}>Get started free</Link>
        </nav>
      ) : null}

      <style jsx>{`
        .marketing-site-nav { position:relative; width:100%; color:#f5f5f7; background:rgba(8,9,12,.94); border-bottom:1px solid rgba(255,255,255,.08); backdrop-filter:blur(20px); -webkit-backdrop-filter:blur(20px); z-index:100; }
        .marketing-site-nav__inner { max-width:1200px; height:64px; margin:0 auto; padding:0 28px; display:flex; align-items:center; gap:34px; }
        .marketing-site-nav__brand { color:#fff; font-family:var(--font-syne,sans-serif); font-size:19px; font-weight:700; letter-spacing:-.04em; text-decoration:none; }
        .marketing-site-nav__desktop { display:flex; align-items:center; gap:28px; flex:1; }
        .marketing-site-nav__desktop>a,.marketing-product-menu__trigger a { color:rgba(255,255,255,.62); font-size:13px; font-weight:500; text-decoration:none; transition:color 150ms ease; }
        .marketing-site-nav__desktop>a:hover,.marketing-site-nav__desktop>a.is-active,.marketing-product-menu__trigger a:hover,.marketing-product-menu__trigger a.is-active { color:#fff; }
        .marketing-product-menu { position:relative; padding:20px 0; }
        .marketing-product-menu__trigger { display:flex; align-items:center; gap:2px; }
        .marketing-product-menu__trigger button { width:22px; height:22px; padding:0; border:0; color:rgba(255,255,255,.52); background:transparent; cursor:pointer; }
        .marketing-product-menu__trigger button span { position:relative; top:-1px; }
        .marketing-product-menu__panel { position:absolute; top:56px; left:-110px; width:680px; padding:20px; border:1px solid rgba(255,255,255,.11); border-radius:16px; background:rgba(17,18,23,.99); box-shadow:0 24px 70px rgba(0,0,0,.48); }
        .marketing-product-menu__eyebrow { margin:0 4px 12px; color:rgba(255,255,255,.34); font-size:10px; font-weight:700; letter-spacing:.11em; text-transform:uppercase; }
        .marketing-product-menu__grid { display:grid; grid-template-columns:repeat(3,1fr); gap:8px; }
        .marketing-product-menu__grid a { display:flex; flex-direction:column; min-height:112px; padding:15px; border:1px solid transparent; border-radius:11px; text-decoration:none; background:rgba(255,255,255,.025); transition:background 150ms ease,border-color 150ms ease; }
        .marketing-product-menu__grid a:hover,.marketing-product-menu__grid a:focus-visible { background:rgba(255,255,255,.065); border-color:rgba(255,255,255,.09); outline:none; }
        .marketing-product-menu__grid a.is-featured { grid-column:1/-1; min-height:96px; background:rgba(20,184,166,.1); border-color:rgba(20,184,166,.2); }
        .marketing-product-menu__grid a.is-featured .marketing-product-menu__label { font-size:17px; }
        .marketing-product-menu__label { color:#fff; font-size:14px; font-weight:650; letter-spacing:-.015em; }
        .marketing-product-menu__description { margin-top:7px; color:rgba(255,255,255,.43); font-size:12px; line-height:1.45; }
        .marketing-product-menu__footer { display:inline-flex; gap:7px; margin:16px 4px 1px; color:#5eead4; font-size:12px; font-weight:650; text-decoration:none; }
        .marketing-site-nav__actions { display:flex; align-items:center; gap:10px; }
        .marketing-site-nav__signin { padding:8px 10px; color:rgba(255,255,255,.62); font-size:13px; font-weight:500; text-decoration:none; }
        .marketing-site-nav__cta { padding:9px 16px; border-radius:999px; color:#07110f; background:#fff; font-size:13px; font-weight:700; text-decoration:none; }
        .marketing-site-nav__mobile-toggle,.marketing-site-nav__mobile { display:none; }
        @media (max-width:820px) {
          .marketing-site-nav__inner { height:58px; padding:0 18px; }
          .marketing-site-nav__desktop,.marketing-site-nav__signin,.marketing-site-nav__cta { display:none; }
          .marketing-site-nav__actions { margin-left:auto; }
          .marketing-site-nav__mobile-toggle { display:block; width:36px; height:36px; border:0; color:#fff; background:transparent; font-size:21px; cursor:pointer; }
          .marketing-site-nav__mobile { display:flex; flex-direction:column; gap:4px; padding:10px 18px 20px; border-top:1px solid rgba(255,255,255,.07); }
          .marketing-site-nav__mobile>a,.marketing-site-nav__mobile summary { padding:11px 4px; color:rgba(255,255,255,.75); font-size:14px; font-weight:600; text-decoration:none; cursor:pointer; }
          .marketing-site-nav__mobile summary { list-style:none; }
          .marketing-site-nav__mobile summary::-webkit-details-marker { display:none; }
          .marketing-site-nav__mobile details>div { display:grid; gap:6px; padding:3px 0 8px; }
          .marketing-site-nav__mobile details a { display:flex; flex-direction:column; padding:11px 13px; border-radius:9px; color:#fff; background:rgba(255,255,255,.04); font-size:13px; font-weight:600; text-decoration:none; }
          .marketing-site-nav__mobile details small { margin-top:4px; color:rgba(255,255,255,.38); font-size:11px; font-weight:400; line-height:1.4; }
          .marketing-site-nav__mobile>a.mobile-cta { margin-top:4px; border-radius:999px; color:#07110f; background:#fff; text-align:center; }
        }
      `}</style>
    </header>
  );
}
