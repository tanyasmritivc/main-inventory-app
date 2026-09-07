"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  Bell, Boxes, Bot, ClipboardCheck, FileStack, FolderKanban, Gauge, QrCode,
  History, LogOut, Menu, ScanLine, Settings, ShoppingCart, Users, X,
} from "lucide-react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export type AppNavItem = {
  label: string;
  route: string;
  icon: typeof Gauge;
  section: "Workspace" | "Collaborate" | "Manage";
  keywords?: string[];
};

export const APP_NAV_ITEMS: AppNavItem[] = [
  { label: "Overview", route: "/dashboard", icon: Gauge, section: "Workspace" },
  { label: "Inventory", route: "/inventory", icon: Boxes, section: "Workspace", keywords: ["spaces", "items"] },
  { label: "Scan & import", route: "/scan", icon: ScanLine, section: "Workspace", keywords: ["barcode", "photo", "spreadsheet", "BOM"] },
  { label: "Assist", route: "/assist", icon: Bot, section: "Workspace", keywords: ["AI", "chat"] },
  { label: "Teams", route: "/teams", icon: Users, section: "Collaborate", keywords: ["board", "members", "team spaces"] },
  { label: "Check-outs", route: "/checkout", icon: ClipboardCheck, section: "Collaborate" },
  { label: "Notifications", route: "/notifications", icon: Bell, section: "Collaborate" },
  { label: "Documents", route: "/documents", icon: FileStack, section: "Manage" },
  { label: "Project kits", route: "/project-kits", icon: FolderKanban, section: "Manage", keywords: ["BOM", "readiness", "reservations"] },
  { label: "Label studio", route: "/labels", icon: QrCode, section: "Manage", keywords: ["QR", "print", "bins"] },
  { label: "Shopping list", route: "/shopping-list", icon: ShoppingCart, section: "Manage" },
  { label: "Activity", route: "/activity", icon: History, section: "Manage" },
];

export function AppSidebar({ onToggle, sidebarOpen }: { onToggle: () => void; sidebarOpen: boolean }) {
  const pathname = usePathname();
  const router = useRouter();

  async function signOut() {
    await createSupabaseBrowserClient().auth.signOut();
    router.replace("/");
    router.refresh();
  }

  return (
    <>
      {sidebarOpen && <button className="app-sidebar-scrim" onClick={onToggle} aria-label="Close navigation" />}
      <aside className={`app-sidebar ${sidebarOpen ? "is-open" : ""}`} aria-label="Primary navigation">
        <div className="app-sidebar-brand">
          <Link href="/dashboard" aria-label="FindEZ overview"><span className="app-sidebar-mark">F</span><span>FindEZ</span></Link>
          <button onClick={onToggle} className="app-icon-button" aria-label={sidebarOpen ? "Close navigation" : "Open navigation"}>
            <span className="desktop-menu"><Menu size={18} /></span><span className="mobile-menu"><X size={18} /></span>
          </button>
        </div>
        <nav className="app-sidebar-nav">
          {(["Workspace", "Collaborate", "Manage"] as const).map((section) => (
            <div className="app-nav-section" key={section}>
              <p>{section}</p>
              {APP_NAV_ITEMS.filter((item) => item.section === section).map((item) => {
                const active = pathname === item.route || pathname.startsWith(`${item.route}/`);
                const Icon = item.icon;
                return <Link className={active ? "is-active" : ""} key={item.route} href={item.route} onClick={() => { if (window.innerWidth < 860) onToggle(); }}><Icon size={17} strokeWidth={1.8} /><span>{item.label}</span></Link>;
              })}
            </div>
          ))}
        </nav>
        <div className="app-sidebar-footer">
          <Link className={pathname === "/settings" ? "is-active" : ""} href="/settings"><Settings size={17} strokeWidth={1.8} /><span>Settings</span></Link>
          <button type="button" onClick={() => void signOut()}><LogOut size={17} strokeWidth={1.8} /><span>Sign out</span></button>
        </div>
      </aside>
    </>
  );
}
