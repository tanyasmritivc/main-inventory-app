"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname, useRouter } from "next/navigation";
import {
  BookOpen, Boxes, ClipboardCheck, FileStack, FolderKanban, KeyRound,
  LogOut, Menu, Printer, ScanLine, Settings, Sparkles, Users, X,
} from "lucide-react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export type AppNavItem = {
  label: string;
  route: string;
  icon: typeof Boxes;
  section: "Workspace" | "Tools" | "API";
  keywords?: string[];
};

export const APP_NAV_ITEMS: AppNavItem[] = [
  { label: "Inventory", route: "/inventory", icon: Boxes, section: "Workspace", keywords: ["spaces", "items"] },
  { label: "Add items", route: "/scan", icon: ScanLine, section: "Workspace", keywords: ["barcode", "photo", "spreadsheet", "BOM"] },
  { label: "Ask FindEZ", route: "/assist", icon: Sparkles, section: "Workspace", keywords: ["AI", "chat"] },
  { label: "Team", route: "/teams", icon: Users, section: "Workspace", keywords: ["board", "members", "team spaces"] },
  { label: "Check-outs", route: "/checkout", icon: ClipboardCheck, section: "Workspace" },
  { label: "Documents", route: "/documents", icon: FileStack, section: "Tools" },
  { label: "Project kits", route: "/project-kits", icon: FolderKanban, section: "Tools", keywords: ["BOM", "readiness", "reservations"] },
  { label: "Labels", route: "/labels", icon: Printer, section: "Tools", keywords: ["QR", "print", "bins"] },
  { label: "API keys", route: "/settings/api-keys", icon: KeyRound, section: "API", keywords: ["developer", "integration", "MCP", "token"] },
  { label: "API documentation", route: "/docs/api", icon: BookOpen, section: "API", keywords: ["developer", "OpenAPI", "Claude", "ChatGPT"] },
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
          <Link href="/inventory" aria-label="FindEZ inventory"><Image className="app-sidebar-logo" src="/images/findez-logo.png" alt="" width={27} height={27} priority /><span>FindEZ</span></Link>
          <button onClick={onToggle} className="app-icon-button" aria-label={sidebarOpen ? "Close navigation" : "Open navigation"}>
            <span className="desktop-menu"><Menu size={18} /></span><span className="mobile-menu"><X size={18} /></span>
          </button>
        </div>
        <nav className="app-sidebar-nav">
          {(["Workspace", "Tools", "API"] as const).map((section) => (
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
