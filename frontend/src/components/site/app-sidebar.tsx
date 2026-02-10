"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { LayoutDashboard, Boxes, FileText, Settings as SettingsIcon, PanelLeftClose, PanelLeftOpen, Layers } from "lucide-react";

import { Button } from "@/components/ui/button";

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

  useEffect(() => {
    try {
      const v = window.localStorage.getItem(storageKey);
      const next = v === "1";
      window.setTimeout(() => setCollapsed(next), 0);
    } catch {
      // ignore
    }
  }, []);

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
        "border-b bg-sidebar text-sidebar-foreground md:border-b-0 md:border-r " +
        (collapsed ? "md:w-[72px]" : "md:w-[240px]")
      }
      aria-label="Primary"
    >
      <div className="flex items-center justify-between gap-2 p-3 md:p-4">
        <div className={"text-sm font-semibold tracking-tight " + (collapsed ? "md:sr-only" : "")}>Navigation</div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={toggle}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          className="hidden md:inline-flex"
        >
          <ToggleIcon className="h-4 w-4" />
        </Button>
      </div>

      <nav className="grid gap-1 px-2 pb-3 md:px-3" aria-label="Sidebar">
        {nav.map(({ label, href, active, Icon }) => (
          <Link
            key={href}
            href={href}
            className={
              "flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring " +
              (active ? "bg-sidebar-accent text-sidebar-accent-foreground" : "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground")
            }
            aria-current={active ? "page" : undefined}
            title={collapsed ? label : undefined}
          >
            <Icon className="h-4 w-4 shrink-0" />
            <span className={collapsed ? "md:sr-only" : ""}>{label}</span>
          </Link>
        ))}
      </nav>
    </aside>
  );
}
