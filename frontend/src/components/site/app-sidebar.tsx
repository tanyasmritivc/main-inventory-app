"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  Boxes, ClipboardCheck, FileStack, FolderKanban, Home, Layers3,
  ListChecks, LogOut, Menu, Printer, ScanLine, Settings, Sparkles, Users, X,
} from "lucide-react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { FindEZMark } from "@/components/site/findez-brand";

export type AppNavItem = {
  label: string;
  route: string;
  icon: typeof Boxes;
  section: "Workspace" | "Tools";
  keywords?: string[];
};

export const APP_NAV_ITEMS: AppNavItem[] = [
  { label: "Home", route: "/home", icon: Home, section: "Workspace", keywords: ["spaces", "attention", "recent"] },
  { label: "Capture", route: "/scan", icon: ScanLine, section: "Workspace", keywords: ["photo", "barcode", "spreadsheet", "BOM"] },
  { label: "Review", route: "/review", icon: ListChecks, section: "Workspace", keywords: ["unresolved", "confirm", "correct"] },
  { label: "Inventory", route: "/inventory", icon: Boxes, section: "Workspace", keywords: ["spaces", "items", "all items"] },
  { label: "Ask FindEZ", route: "/assist", icon: Sparkles, section: "Workspace", keywords: ["AI", "chat"] },
  { label: "Check-outs", route: "/checkout", icon: ClipboardCheck, section: "Workspace" },
  { label: "Team", route: "/teams", icon: Users, section: "Workspace", keywords: ["board", "members", "team spaces"] },
  { label: "Smart collections", route: "/collections", icon: Layers3, section: "Tools", keywords: ["before I buy", "restock", "low stock"] },
  { label: "Project kits", route: "/project-kits", icon: FolderKanban, section: "Tools", keywords: ["BOM", "readiness", "reservations"] },
  { label: "Documents", route: "/documents", icon: FileStack, section: "Tools" },
  { label: "Labels", route: "/labels", icon: Printer, section: "Tools", keywords: ["QR", "print", "bins"] },
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
      <aside className={`app-sidebar is-hover-expandable ${sidebarOpen ? "is-open" : ""}`} aria-label="Primary navigation">
        <div className="app-sidebar-brand">
          <Link href="/home" aria-label="FindEZ home"><FindEZMark className="app-sidebar-logo" width={27} height={27} /><span>FindEZ</span></Link>
          <button onClick={onToggle} className="app-icon-button" aria-label={sidebarOpen ? "Close navigation" : "Open navigation"}>
            <span className="desktop-menu"><Menu size={18} /></span><span className="mobile-menu"><X size={18} /></span>
          </button>
        </div>
        <nav className="app-sidebar-nav">
          {(["Workspace", "Tools"] as const).map((section) => (
            <div className="app-nav-section" key={section}>
              <p>{section}</p>
              {APP_NAV_ITEMS.filter((item) => item.section === section).map((item) => {
                const active = pathname === item.route || pathname.startsWith(`${item.route}/`);
                const Icon = item.icon;
                return <Link className={active ? "is-active" : ""} key={item.route} href={item.route} title={!sidebarOpen ? item.label : undefined} aria-label={item.label} onClick={() => { if (window.innerWidth < 860) onToggle(); }}><Icon size={17} strokeWidth={1.8} /><span>{item.label}</span></Link>;
              })}
            </div>
          ))}
        </nav>
        <div className="app-sidebar-footer">
          <Link className={pathname === "/settings" ? "is-active" : ""} href="/settings" title={!sidebarOpen ? "Settings" : undefined} aria-label="Settings"><Settings size={17} strokeWidth={1.8} /><span>Settings</span></Link>
          <button type="button" onClick={() => void signOut()} title={!sidebarOpen ? "Sign out" : undefined} aria-label="Sign out"><LogOut size={17} strokeWidth={1.8} /><span>Sign out</span></button>
        </div>
      </aside>
    </>
  );
}
