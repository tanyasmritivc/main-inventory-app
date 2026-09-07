"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Bell, Menu, Search, UserRound } from "lucide-react";
import { APP_NAV_ITEMS, AppSidebar } from "@/components/site/app-sidebar";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { getNotifications } from "@/lib/api";

const PAGE_TITLES: Record<string, string> = {
  "/dashboard": "Overview", "/inventory": "Inventory", "/scan": "Scan & import",
  "/assist": "Assist", "/teams": "Teams", "/checkout": "Check-outs",
  "/notifications": "Notifications", "/documents": "Documents",
  "/project-kits": "Project kits", "/shopping-list": "Shopping list",
  "/labels": "Label studio", "/activity": "Activity", "/settings": "Settings",
};

function resolveTitle(pathname: string) {
  const key = Object.keys(PAGE_TITLES).find((candidate) => pathname === candidate || pathname.startsWith(`${candidate}/`));
  return key ? PAGE_TITLES[key] : "FindEZ";
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [commandOpen, setCommandOpen] = useState(false);
  const [commandQuery, setCommandQuery] = useState("");
  const [userInitial, setUserInitial] = useState("");
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    const wide = window.matchMedia("(min-width: 860px)");
    const frame = window.requestAnimationFrame(() => setSidebarOpen(wide.matches));
    const onChange = (event: MediaQueryListEvent) => setSidebarOpen(event.matches);
    wide.addEventListener("change", onChange);
    return () => { window.cancelAnimationFrame(frame); wide.removeEventListener("change", onChange); };
  }, []);

  useEffect(() => {
    let active = true;
    async function loadIdentity() {
      const { data } = await supabase.auth.getUser();
      if (!active) return;
      const name = String(data.user?.user_metadata?.display_name ?? data.user?.email ?? "");
      setUserInitial(name.slice(0, 1).toUpperCase());
      const { data: sessionData } = await supabase.auth.getSession();
      if (sessionData.session) {
        getNotifications({ token: sessionData.session.access_token }).then((result) => {
          if (active) setUnread(result.unread_count ?? 0);
        }).catch(() => {});
      }
    }
    void loadIdentity();
    const timer = window.setInterval(loadIdentity, 60_000);
    return () => { active = false; window.clearInterval(timer); };
  }, [supabase]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault(); setCommandOpen((value) => !value);
      }
      if (event.key === "Escape") setCommandOpen(false);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  const commandItems = APP_NAV_ITEMS.filter((item) => [item.label, item.section, ...(item.keywords ?? [])].join(" ").toLowerCase().includes(commandQuery.trim().toLowerCase()));

  return (
    <div className={`app-frame ${sidebarOpen ? "sidebar-open" : ""}`}>
      <AppSidebar onToggle={() => setSidebarOpen((value) => !value)} sidebarOpen={sidebarOpen} />
      <header className="app-topbar">
        <button className="app-icon-button" onClick={() => setSidebarOpen(true)} aria-label="Open navigation"><Menu size={19} /></button>
        <div className="app-topbar-title"><span>{resolveTitle(pathname)}</span><small>FindEZ workspace</small></div>
        <button className="app-command-trigger" onClick={() => setCommandOpen(true)}><Search size={15} /><span>Go to…</span><kbd>⌘K</kbd></button>
        <button className="app-icon-button app-notification-button" onClick={() => router.push("/notifications")} aria-label={`${unread} unread notifications`}>
          <Bell size={18} />{unread > 0 && <span>{unread > 99 ? "99+" : unread}</span>}
        </button>
        <button className="app-avatar" onClick={() => router.push("/settings")} aria-label="Open profile">{userInitial || <UserRound size={16} />}</button>
      </header>
      <main className="app-main"><div className="app-content">{children}</div></main>
      {commandOpen && (
        <div className="command-backdrop" role="presentation" onMouseDown={() => setCommandOpen(false)}>
          <div className="command-panel" role="dialog" aria-modal="true" aria-label="Navigate FindEZ" onMouseDown={(event) => event.stopPropagation()}>
            <div className="command-input-row"><Search size={18} /><input autoFocus value={commandQuery} onChange={(event) => setCommandQuery(event.target.value)} placeholder="Search features and pages" /><kbd>esc</kbd></div>
            <div className="command-results">
              {commandItems.map((item) => { const Icon = item.icon; return <button key={item.route} onClick={() => { router.push(item.route); setCommandOpen(false); setCommandQuery(""); }}><Icon size={17} /><span><strong>{item.label}</strong><small>{item.section}</small></span></button>; })}
              {commandItems.length === 0 && <p>No matching FindEZ feature.</p>}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
