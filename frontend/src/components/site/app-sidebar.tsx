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
      <div style={{ padding: "0 8px", marginBottom: 28, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <span
          className="font-display"
          style={{ fontSize: 17, fontWeight: 700, color: "#fff", letterSpacing: "-0.3px" }}
        >
          FindEZ
        </span>
        <button
          type="button"
          onClick={() => router.push("/settings")}
          style={{
            width: 28, height: 28,
            borderRadius: "50%",
            background: "var(--surface-active)",
            border: "1px solid var(--fz-border)",
            color: "#fff",
            fontSize: 12,
            display: "flex", alignItems: "center", justifyContent: "center",
            cursor: "pointer",
          }}
          aria-label="Settings"
        >
          {userInitial}
        </button>
      </div>

      {/* Nav label */}
      <div className="label-section" style={{ padding: "0 8px", marginBottom: 8 }}>
        Navigation
      </div>

      {/* Nav items */}
      <nav style={{ display: "flex", flexDirection: "column", gap: 2, flex: 1 }} aria-label="Sidebar">
        {nav.map(({ label, href, active, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            style={{
              height: 38,
              borderRadius: 10,
              padding: "0 10px",
              display: "flex",
              alignItems: "center",
              gap: 9,
              fontSize: 13,
              fontWeight: 500,
              cursor: "pointer",
              transition: "all 150ms",
              textDecoration: "none",
              background: active ? "var(--surface-active)" : "transparent",
              border: active ? "1px solid var(--fz-border)" : "1px solid transparent",
              color: active ? "#fff" : "var(--text-secondary)",
            }}
            aria-current={active ? "page" : undefined}
            onMouseEnter={(e) => {
              if (!active) {
                (e.currentTarget as HTMLElement).style.background = "var(--surface)";
                (e.currentTarget as HTMLElement).style.color = "#fff";
              }
            }}
            onMouseLeave={(e) => {
              if (!active) {
                (e.currentTarget as HTMLElement).style.background = "transparent";
                (e.currentTarget as HTMLElement).style.color = "var(--text-secondary)";
              }
            }}
          >
            <Icon size={15} strokeWidth={1.8} />
            <span>{label}</span>
          </Link>
        ))}
      </nav>

      {/* Bottom section */}
      <div>
        <div className="divider" />
        {userEmail && (
          <div style={{ padding: "12px 8px 4px", fontSize: 11, color: "var(--text-muted)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            {userEmail}
          </div>
        )}
        <button
          type="button"
          onClick={() => void signOut()}
          style={{ padding: "0 8px 4px", fontSize: 12, color: "var(--text-secondary)", background: "none", border: "none", cursor: "pointer", display: "block", transition: "color 150ms" }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = "#fff"; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = "var(--text-secondary)"; }}
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}
