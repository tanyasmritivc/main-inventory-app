"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { LayoutDashboard, Package, Compass, FileText, Settings as SettingsIcon } from "lucide-react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

type NavItem = {
  label: string;
  href: string;
  icon: React.ComponentType<{ size?: number; strokeWidth?: number }>;
};

const navItems: NavItem[] = [
  { label: "Home",       href: "/dashboard",   icon: LayoutDashboard },
  { label: "My Spaces",  href: "/inventory",   icon: Package },
  { label: "Collections",href: "/collections", icon: Compass },
  { label: "Documents",  href: "/documents",   icon: FileText },
  { label: "Settings",   href: "/settings",    icon: SettingsIcon },
];

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

export function AppSidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [userInitial, setUserInitial] = useState("?");
  const [isPro, setIsPro] = useState<boolean | null>(null);

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
        {isPro === false && (
          <a
            href="/upgrade"
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              margin: "0 0 8px",
              padding: "10px 14px",
              background: "rgba(245,158,11,0.08)",
              border: "1px solid rgba(245,158,11,0.25)",
              borderRadius: "10px",
              color: "#f59e0b",
              fontSize: "13px",
              fontWeight: 600,
              textDecoration: "none",
            }}
          >
            ⭐ Upgrade to Pro
          </a>
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
