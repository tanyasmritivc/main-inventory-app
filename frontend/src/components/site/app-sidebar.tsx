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
  { label: "Dashboard",  href: "/dashboard",   icon: LayoutDashboard },
  { label: "Inventory",  href: "/inventory",   icon: Package },
  { label: "Discover",   href: "/collections", icon: Compass },
  { label: "Documents",  href: "/documents",   icon: FileText },
  { label: "Settings",   href: "/settings",    icon: SettingsIcon },
];

export function AppSidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [userInitial, setUserInitial] = useState("?");

  useEffect(() => {
    const sb = createSupabaseBrowserClient();
    sb.auth.getUser().then(({ data }) => {
      const email = data.user?.email ?? null;
      setUserEmail(email);
      setUserInitial(email ? email[0].toUpperCase() : "?");
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
        background: "rgba(0,0,0,0.80)",
        backdropFilter: "blur(24px)",
        WebkitBackdropFilter: "blur(24px)",
        borderRight: "1px solid var(--fz-border)",
        zIndex: 100,
        display: "flex",
        flexDirection: "column",
        padding: "20px 12px",
      }}
      aria-label="Primary navigation"
    >
      {/* Logo row */}
      <div style={{ padding: "20px 16px 28px 20px", display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ color: "#f59e0b", fontSize: 18, lineHeight: 1 }}>●</span>
        <span className="font-display" style={{ fontSize: 18, fontWeight: 600, color: "#fff", letterSpacing: "-0.3px" }}>
          FindEZ
        </span>
      </div>

      {/* Nav items */}
      <nav style={{ display: "flex", flexDirection: "column", gap: 6, flex: 1 }} aria-label="Sidebar">
        {nav.map(({ label, href, active, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            style={{
              padding: "9px 12px",
              borderRadius: 10,
              display: "flex",
              alignItems: "center",
              gap: 10,
              fontSize: 14,
              color: active ? "#fff" : "rgba(255,255,255,0.55)",
              textDecoration: "none",
              background: active ? "rgba(255,255,255,0.08)" : "transparent",
              fontWeight: active ? 500 : 400,
              transition: "background 150ms, color 150ms",
            }}
            aria-current={active ? "page" : undefined}
            onMouseEnter={(e) => {
              if (!active) {
                (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.06)";
                (e.currentTarget as HTMLElement).style.color = "#fff";
              }
            }}
            onMouseLeave={(e) => {
              if (!active) {
                (e.currentTarget as HTMLElement).style.background = "transparent";
                (e.currentTarget as HTMLElement).style.color = "rgba(255,255,255,0.55)";
              }
            }}
          >
            <Icon size={16} strokeWidth={1.8} />
            <span>{label}</span>
          </Link>
        ))}
      </nav>

      {/* Bottom section */}
      <div style={{ marginTop: 16, paddingTop: 14, borderTop: "1px solid rgba(255,255,255,0.08)" }}>
        {userEmail && (
          <div style={{ padding: "0 8px", fontSize: 11, color: "rgba(255,255,255,0.30)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            {userEmail}
          </div>
        )}
        <button
          type="button"
          onClick={() => void signOut()}
          style={{ marginTop: 8, fontSize: 13, color: "rgba(255,255,255,0.40)", background: "none", border: "none", cursor: "pointer", padding: 0, transition: "color 150ms" }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = "#fff"; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = "rgba(255,255,255,0.40)"; }}
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}
