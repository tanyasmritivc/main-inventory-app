"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { LayoutDashboard, Boxes, FileText, Settings as SettingsIcon, PanelLeftClose, PanelLeftOpen, Layers } from "lucide-react";

import { Button } from "@/components/ui/button";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

type NavItem = {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
};

const navItems: NavItem[] = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { label: "Collections", href: "/collections", icon: Layers },
  { label: "Inventory", href: "/inventory", icon: Boxes },
  { label: "Manuals & Receipts", href: "/documents", icon: FileText },
  { label: "Settings", href: "/settings", icon: SettingsIcon },
];

export function AppSidebar() {
  const pathname = usePathname();
  const storageKey = "findez.sidebar.collapsed";

  const [collapsed, setCollapsed] = useState(false);
  const [userEmail, setUserEmail] = useState<string | null>(null);

  useEffect(() => {
    try {
      const v = window.localStorage.getItem(storageKey);
      const next = v === "1";
      window.setTimeout(() => setCollapsed(next), 0);
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    const sb = createSupabaseBrowserClient();
    sb.auth.getUser().then(({ data }) => {
      setUserEmail(data.user?.email ?? null);
    }).catch(() => {});
  }, []);

  async function signOut() {
    const sb = createSupabaseBrowserClient();
    await sb.auth.signOut();
    window.location.href = "/";
  }

  const ToggleIcon = collapsed ? PanelLeftOpen : PanelLeftClose;

  const nav = useMemo(() => {
    return navItems.map((it) => {
      const active = pathname === it.href || (it.href !== "/dashboard" && pathname.startsWith(it.href + "/"));
      const Icon = it.icon;
      return { ...it, active, Icon };
    });
  }, [pathname]);

  function toggle() {
    setCollapsed((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(storageKey, next ? "1" : "0");
      } catch {
        // ignore
      }
      return next;
    });
  }

  return (
    <aside
      className={
        "flex flex-col border-b border-white/[0.07] bg-black/60 backdrop-blur-xl text-white md:border-b-0 md:border-r md:border-r-white/[0.07] shrink-0 " +
        (collapsed ? "md:w-[72px]" : "md:w-[220px]")
      }
      aria-label="Primary"
    >
      {/* Wordmark */}
      <div className={"px-5 pt-6 pb-1 " + (collapsed ? "md:hidden" : "")}>
        <div className="text-[17px] font-bold text-white tracking-tight">FindEZ</div>
      </div>

      {/* NAVIGATION label */}
      <div className={"text-[10px] font-medium uppercase tracking-[1.2px] text-white/30 px-5 mt-8 mb-1 " + (collapsed ? "md:sr-only" : "")}>
        Navigation
      </div>

      <nav className="flex flex-col gap-0.5 px-2 flex-1 pb-2" aria-label="Sidebar">
        {nav.map(({ label, href, active, Icon }) => (
          <Link
            key={href}
            href={href}
            className={
              "flex items-center gap-2.5 rounded-[10px] px-3 h-10 text-[14px] font-[500] transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/15 " +
              (active
                ? "bg-white/[0.09] border border-white/10 text-white"
                : "text-white/40 hover:bg-white/[0.08] hover:text-white border border-transparent")
            }
            aria-current={active ? "page" : undefined}
            title={collapsed ? label : undefined}
          >
            <Icon className="h-4 w-4 shrink-0" />
            <span className={collapsed ? "md:sr-only" : ""}>{label}</span>
          </Link>
        ))}
      </nav>

      {/* User section */}
      {userEmail ? (
        <div className={"border-t border-white/[0.07] px-4 py-4 " + (collapsed ? "md:hidden" : "")}>
          <div className="text-[12px] text-white/40 truncate mb-2">{userEmail}</div>
          <button
            type="button"
            onClick={() => void signOut()}
            className="text-[13px] text-white/50 hover:text-white transition-colors"
          >
            Sign out
          </button>
        </div>
      ) : null}

      {/* Collapse toggle */}
      <div className="hidden md:flex px-2 py-2 border-t border-white/[0.07]">
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={toggle}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          className="w-full justify-start text-white/30 hover:text-white hover:bg-white/[0.06]"
        >
          <ToggleIcon className="h-4 w-4" />
          {!collapsed && <span className="ml-1 text-xs">Collapse</span>}
        </Button>
      </div>
    </aside>
  );
}
