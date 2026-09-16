"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

const NAV_ITEMS = [
  { label: "Product", href: "/product", match: "/product" },
  { label: "How it works", href: "/#how-it-works", match: "/#how-it-works" },
  { label: "For robotics", href: "/robotics", match: "/robotics" },
  { label: "Developers", href: "/docs/api", match: "/docs/api" },
];

export function SiteNav(props: { variant: "marketing" | "app" }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  if (props.variant === "app") return null;
  const closeMenu = () => setMobileOpen(false);

  return (
    <header className="marketing-site-nav">
      <div className="marketing-site-nav__inner">
        <Link href="/" className="marketing-site-nav__brand" aria-label="FindEZ home" onClick={closeMenu}>
          <span aria-hidden="true"><i /></span>
          FindEZ
        </Link>

        <nav className="marketing-site-nav__desktop" aria-label="Marketing navigation">
          {NAV_ITEMS.map((item) => {
            const active = item.match !== "/#how-it-works" && (pathname === item.match || pathname.startsWith(`${item.match}/`));
            return <Link key={item.href} href={item.href} className={active ? "is-active" : undefined}>{item.label}</Link>;
          })}
        </nav>

        <div className="marketing-site-nav__actions">
          <Link href="/signin" className="marketing-site-nav__signin" onClick={closeMenu}>Sign in</Link>
          <Link href="/signup" className="marketing-site-nav__cta" onClick={closeMenu}>Start free</Link>
          <button
            type="button"
            className="marketing-site-nav__mobile-toggle"
            aria-label="Toggle navigation"
            aria-expanded={mobileOpen}
            onClick={() => setMobileOpen((open) => !open)}
          >
            <span /><span />
          </button>
        </div>
      </div>

      {mobileOpen ? (
        <nav className="marketing-site-nav__mobile" aria-label="Mobile marketing navigation">
          {NAV_ITEMS.map((item) => <Link key={item.href} href={item.href} onClick={closeMenu}>{item.label}</Link>)}
          <Link href="/signin" onClick={closeMenu}>Sign in</Link>
          <Link href="/signup" className="mobile-cta" onClick={closeMenu}>Start free</Link>
        </nav>
      ) : null}

      <style jsx>{`
        .marketing-site-nav { width:100%; color:#f2f4f2; background:rgba(12,15,13,.94); border-bottom:1px solid rgba(233,240,235,.09); backdrop-filter:blur(18px); -webkit-backdrop-filter:blur(18px); }
        .marketing-site-nav__inner { width:min(1180px,calc(100% - 40px)); height:64px; margin:0 auto; display:grid; grid-template-columns:1fr auto 1fr; align-items:center; gap:26px; }
        .marketing-site-nav__brand { width:max-content; display:inline-flex; align-items:center; gap:9px; color:#f4f6f4; font-family:var(--font-syne,sans-serif); font-size:18px; font-weight:700; letter-spacing:-.045em; text-decoration:none; }
        .marketing-site-nav__brand>span { position:relative; width:25px; height:25px; display:block; border:1px solid rgba(136,198,159,.35); border-radius:6px; background:#153d2c; }
        .marketing-site-nav__brand>span::before,.marketing-site-nav__brand>span::after,.marketing-site-nav__brand i { content:""; position:absolute; display:block; background:#8fc3a2; }
        .marketing-site-nav__brand>span::before { left:6px; top:6px; width:2px; height:13px; border-radius:2px; }
        .marketing-site-nav__brand>span::after { left:10px; top:11px; width:8px; height:2px; border-radius:2px; }
        .marketing-site-nav__brand i { left:10px; top:6px; width:6px; height:2px; border-radius:2px; opacity:.55; }
        .marketing-site-nav__desktop { display:flex; align-items:center; justify-content:center; gap:26px; white-space:nowrap; }
        .marketing-site-nav__desktop a { color:#939b95; font-size:12px; font-weight:500; text-decoration:none; transition:color 140ms ease; }
        .marketing-site-nav__desktop a:hover,.marketing-site-nav__desktop a.is-active { color:#f1f4f2; }
        .marketing-site-nav__actions { justify-self:end; display:flex; align-items:center; gap:8px; white-space:nowrap; }
        .marketing-site-nav__signin { padding:8px 10px; color:#969e98; font-size:12px; font-weight:500; text-decoration:none; }
        .marketing-site-nav__signin:hover { color:#fff; }
        .marketing-site-nav__cta { min-height:34px; padding:0 13px; display:inline-flex; align-items:center; border:1px solid rgba(242,246,243,.92); border-radius:6px; color:#102219; background:#eef3ef; font-size:12px; font-weight:650; text-decoration:none; }
        .marketing-site-nav__cta:hover { background:#fff; }
        .marketing-site-nav__mobile-toggle,.marketing-site-nav__mobile { display:none; }
        @media (max-width:900px) {
          .marketing-site-nav__inner { grid-template-columns:1fr auto; }
          .marketing-site-nav__desktop,.marketing-site-nav__signin,.marketing-site-nav__cta { display:none; }
          .marketing-site-nav__mobile-toggle { position:relative; width:38px; height:38px; display:block; border:0; background:transparent; cursor:pointer; }
          .marketing-site-nav__mobile-toggle span { position:absolute; left:9px; width:20px; height:1px; background:#dce3de; transition:transform 140ms ease,top 140ms ease; }
          .marketing-site-nav__mobile-toggle span:first-child { top:15px; transform:${mobileOpen ? "translateY(4px) rotate(45deg)" : "none"}; }
          .marketing-site-nav__mobile-toggle span:last-child { top:${mobileOpen ? "19px" : "22px"}; transform:${mobileOpen ? "rotate(-45deg)" : "none"}; }
          .marketing-site-nav__mobile { padding:10px 20px 20px; display:grid; gap:2px; border-top:1px solid rgba(233,240,235,.08); background:#0c0f0d; }
          .marketing-site-nav__mobile a { padding:12px 3px; color:#b3bbb5; font-size:14px; font-weight:550; text-decoration:none; }
          .marketing-site-nav__mobile a:hover { color:#fff; }
          .marketing-site-nav__mobile a.mobile-cta { margin-top:8px; border-radius:6px; color:#102219; background:#eef3ef; text-align:center; }
        }
        @media (max-width:500px) {
          .marketing-site-nav__inner { width:calc(100% - 28px); height:60px; }
        }
      `}</style>
    </header>
  );
}
