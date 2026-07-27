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

interface AppSidebarProps {
  onToggle: () => void;
  sidebarOpen: boolean;
}

export function AppSidebar({ onToggle, sidebarOpen }: AppSidebarProps) {
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
        width: 220,
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
        overflow: "hidden",
        transition: "width 0.25s ease, transform 0.25s ease",
        transform: sidebarOpen ? "translateX(0)" : "translateX(-220px)",
      }}
      aria-label="Primary navigation"
    >
      {/* Toggle button row */}
      <button
        onClick={() => onToggle()}
        style={{
          background: "none",
          border: "none",
          cursor: "pointer",
          color: "rgba(255,255,255,0.5)",
          padding: "16px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          width: "100%",
        }}
        title="Toggle sidebar"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <line x1="3" y1="6" x2="21" y2="6"/>
          <line x1="3" y1="12" x2="21" y2="12"/>
          <line x1="3" y1="18" x2="21" y2="18"/>
        </svg>
      </button>

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
      <div style={{ padding: '16px', borderTop: '1px solid rgba(255,255,255,0.06)' }}>
        <button
          type="button"
          onClick={() => void signOut()}
          style={{
            width: '100%',
            background: 'none',
            border: 'none',
            color: 'rgba(255,255,255,0.35)',
            fontSize: '13px',
            cursor: 'pointer',
            textAlign: 'left',
            padding: '8px 4px',
          }}
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}
