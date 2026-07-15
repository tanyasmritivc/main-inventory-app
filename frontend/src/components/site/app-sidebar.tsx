"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { LayoutDashboard, Package, FileText, Settings as SettingsIcon, ShoppingCart, ArrowLeftRight } from "lucide-react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { getUsage } from "@/lib/api";

type NavItem = {
  label: string;
  href: string;
  icon: React.ComponentType<{ size?: number; strokeWidth?: number }>;
};

const navItems: NavItem[] = [
  { label: "Home",             href: "/dashboard",     icon: LayoutDashboard },
  { label: "My Spaces",        href: "/inventory",     icon: Package },
  { label: "Documents",        href: "/documents",     icon: FileText },
  { label: "Shopping List",    href: "/shopping-list", icon: ShoppingCart },
  { label: "Check-Out Tracker",href: "/checkout",      icon: ArrowLeftRight },
  { label: "Settings",         href: "/settings",      icon: SettingsIcon },
];

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

function safeUsageBar(usage: any, key: string, label: string) {
  try {
    const u = usage?.[key]
    if (!u || typeof u.current !== 'number' || typeof u.limit !== 'number') return null
    const pct = Math.min(100, (u.current / u.limit) * 100)
    return (
      <div style={{ marginBottom: '8px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '3px' }}>
          <span style={{ fontSize: '10px', color: '#6e6e73' }}>{label}</span>
          <span style={{ fontSize: '10px', color: pct >= 100 ? '#ff453a' : '#6e6e73' }}>
            {u.current}/{u.limit}
          </span>
        </div>
        <div style={{ height: '2px', background: 'rgba(255,255,255,0.08)', borderRadius: '1px', overflow: 'hidden' }}>
          <div style={{
            height: '100%',
            width: `${pct}%`,
            background: pct >= 100 ? '#ff453a' : pct >= 80 ? '#ffd60a' : '#32d74b',
            borderRadius: '1px',
          }} />
        </div>
      </div>
    )
  } catch {
    return null
  }
}

export function AppSidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [userInitial, setUserInitial] = useState("?");
  const [isPro, setIsPro] = useState<boolean | null>(null);
  const [usage, setUsage] = useState<any>(null);

  useEffect(() => {
    const sb = createSupabaseBrowserClient();
    sb.auth.getUser().then(({ data }) => {
      const email = data.user?.email ?? null;
      setUserEmail(email);
      setUserInitial(email ? email[0].toUpperCase() : "?");
    }).catch(() => {});

    sb.auth.getSession().then(({ data }) => {
      const token = data.session?.access_token;
      if (!token) return;
      getUsage({ token }).then(setUsage).catch(() => {});
      return fetch(`${apiBase()}/stripe/subscription-status`, {
        headers: { Authorization: `Bearer ${token}` },
      })
        .then((r) => (r.ok ? r.json() : null))
        .then((d: { is_pro?: boolean } | null) => {
          if (d && typeof d.is_pro === "boolean") setIsPro(d.is_pro);
        });
    }).catch(() => {});
  }, []);

  async function signOut() {
    const sb = createSupabaseBrowserClient();
    await sb.auth.signOut();
    window.location.href = "/";
  }

  const nav = useMemo(() => {
    return navItems.map((it) => {
      const active =
        pathname === it.href ||
        (it.href !== "/dashboard" && pathname.startsWith(it.href + "/"));
      return { ...it, active };
    });
  }, [pathname]);

  return (
    <aside
      style={{
        width: "var(--sidebar-width)",
        position: "fixed",
        top: 0,
        left: 0,
        bottom: 0,
        background: "#0a0a0a",
        borderRight: "1px solid #1c1c1e",
        zIndex: 100,
        display: "flex",
        flexDirection: "column",
        padding: 0,
      }}
      aria-label="Primary navigation"
    >
      {/* Logo row */}
      <div style={{ padding: "14px 14px 12px", display: "flex", alignItems: "center", gap: 7, borderBottom: "1px solid #1c1c1e", marginBottom: 6 }}>
        <div style={{ width: 20, height: 20, borderRadius: 5, background: "#fff", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
          <svg width="11" height="11" viewBox="0 0 11 11" fill="none">
            <path d="M1.5 9L5.5 2L9.5 9" stroke="#000" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M3 6.8h5" stroke="#000" strokeWidth="1.3" strokeLinecap="round"/>
          </svg>
        </div>
        <span style={{ fontSize: 15, fontWeight: 590, color: "#fff", letterSpacing: "-0.025em" }}>
          FindEZ
        </span>
      </div>

      {/* Nav items */}
      <nav style={{ display: "flex", flexDirection: "column", gap: 4, flex: 1 }} aria-label="Sidebar">
        {nav.map(({ label, href, active, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            style={{
              padding: "8px 11px",
              borderRadius: 8,
              display: "flex",
              alignItems: "center",
              gap: 9,
              fontSize: 13,
              color: active ? "#f5f5f7" : "#6e6e73",
              textDecoration: "none",
              background: active ? "#1c1c1e" : "transparent",
              fontWeight: active ? 510 : 400,
              letterSpacing: "-0.012em",
              transition: "background 150ms, color 150ms",
            }}
            aria-current={active ? "page" : undefined}
            onMouseEnter={(e) => {
              if (!active) {
                (e.currentTarget as HTMLElement).style.background = "#111113";
                (e.currentTarget as HTMLElement).style.color = "#f5f5f7";
              }
            }}
            onMouseLeave={(e) => {
              if (!active) {
                (e.currentTarget as HTMLElement).style.background = "transparent";
                (e.currentTarget as HTMLElement).style.color = "#6e6e73";
              }
            }}
          >
            <Icon size={16} strokeWidth={1.8} />
            <span>{label}</span>
          </Link>
        ))}
      </nav>

      {/* Bottom section */}
      <div style={{ marginTop: 12, paddingTop: 11, borderTop: "1px solid #1c1c1e" }}>
        {isPro !== true && usage && typeof usage === 'object' && usage.plan === 'free' && (
          <div style={{
            margin: '8px 8px 0',
            background: 'rgba(167,139,250,0.06)',
            border: '1px solid rgba(167,139,250,0.15)',
            borderRadius: '10px',
            padding: '12px 14px',
          }}>
            <div style={{ fontSize: '11px', fontWeight: 590, color: '#a78bfa', marginBottom: '8px' }}>
              ⭐ Free Plan
            </div>
            {safeUsageBar(usage, 'ai_chat', 'AI chat')}
            {safeUsageBar(usage, 'photo_scan', 'Photo scans')}
            {safeUsageBar(usage, 'spreadsheet_import', 'Imports')}
            <a href="/upgrade" style={{
              display: 'block',
              background: 'rgba(167,139,250,0.12)',
              border: '1px solid rgba(167,139,250,0.25)',
              borderRadius: '6px',
              padding: '7px 12px',
              fontSize: '11px',
              fontWeight: 510,
              color: '#a78bfa',
              textDecoration: 'none',
              textAlign: 'center',
              marginTop: '10px',
            }}>
              Upgrade to Pro →
            </a>
          </div>
        )}
        {isPro === false && !usage && (
          <div style={{
            margin: '8px 8px 0',
            background: 'rgba(167,139,250,0.06)',
            border: '1px solid rgba(167,139,250,0.15)',
            borderRadius: '10px',
            padding: '12px 14px',
          }}>
            <div style={{ fontSize: '11px', fontWeight: 590, color: '#a78bfa', marginBottom: '4px', letterSpacing: '-0.01em' }}>
              ⭐ FindEZ Pro
            </div>
            <div style={{ fontSize: '11px', color: '#6e6e73', marginBottom: '10px', lineHeight: 1.4 }}>
              Unlimited items, scans, and AI chat.
            </div>
            <a
              href="/upgrade"
              style={{
                display: 'block',
                background: 'rgba(167,139,250,0.12)',
                border: '1px solid rgba(167,139,250,0.25)',
                borderRadius: '6px',
                padding: '6px 12px',
                fontSize: '11px',
                fontWeight: 510,
                color: '#a78bfa',
                textDecoration: 'none',
                textAlign: 'center',
                transition: 'background 0.15s',
              }}
              onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(167,139,250,0.20)'; }}
              onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(167,139,250,0.12)'; }}
            >
              Upgrade →
            </a>
          </div>
        )}
        {isPro === true && (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "6px",
              margin: "0 0 8px",
              padding: "8px 14px",
              background: "rgba(34,197,94,0.06)",
              border: "1px solid rgba(34,197,94,0.2)",
              borderRadius: "10px",
              color: "#22c55e",
              fontSize: "12px",
              fontWeight: 600,
            }}
          >
            ✓ Pro Active
          </div>
        )}
        {userEmail && (
          <div style={{ padding: "0 7px", fontSize: 10, color: "#6e6e73", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", letterSpacing: "-0.005em" }}>
            {userEmail}
          </div>
        )}
        <button
          type="button"
          onClick={() => void signOut()}
          style={{ marginTop: 7, fontSize: 12, fontWeight: 400, letterSpacing: "-0.01em", color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: 0, transition: "color 150ms" }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = "#f5f5f7"; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = "#6e6e73"; }}
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}
