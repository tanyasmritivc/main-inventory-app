"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Bell, Search } from "lucide-react";
import { AppSidebar } from "@/components/site/app-sidebar";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

const PAGE_TITLES: Record<string, string> = {
  "/dashboard":   "Dashboard",
  "/inventory":   "Inventory",
  "/collections": "Discover",
  "/documents":   "Documents",
  "/settings":    "Settings",
};

function resolveTitle(pathname: string): string {
  for (const [key, val] of Object.entries(PAGE_TITLES)) {
    if (pathname === key || pathname.startsWith(key + "/")) return val;
  }
  return "FindEZ";
}

export function AppShell(props: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [userInitial, setUserInitial] = useState("?");

  useEffect(() => {
    const sb = createSupabaseBrowserClient();
    sb.auth.getUser().then(({ data }) => {
      const email = data.user?.email ?? "";
      setUserInitial(email ? email[0].toUpperCase() : "?");
    }).catch(() => {});
  }, []);

  const title = resolveTitle(pathname);

  return (
    <div style={{ minHeight: "100vh" }}>
      <AppSidebar />

      {/* Top bar */}
      <header
        style={{
          position: "fixed",
          top: 0,
          left: "var(--sidebar-width)",
          right: 0,
          height: "var(--topbar-height)",
          background: "rgba(0,0,0,0.65)",
          backdropFilter: "blur(20px)",
          WebkitBackdropFilter: "blur(20px)",
          borderBottom: "1px solid var(--fz-border)",
          zIndex: 99,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "0 32px",
        }}
      >
        <span
          className="font-display"
          style={{ fontSize: 15, fontWeight: 600, color: "#fff" }}
        >
          {title}
        </span>

        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <button
            type="button"
            aria-label="Search"
            style={{
              width: 36, height: 36, borderRadius: "50%",
              background: "var(--surface)", border: "1px solid var(--fz-border)",
              display: "flex", alignItems: "center", justifyContent: "center",
              cursor: "pointer", color: "var(--text-secondary)", transition: "background 150ms, color 150ms",
            }}
            onMouseEnter={(e) => { const el = e.currentTarget as HTMLButtonElement; el.style.background = "var(--surface-hover)"; el.style.color = "#fff"; }}
            onMouseLeave={(e) => { const el = e.currentTarget as HTMLButtonElement; el.style.background = "var(--surface)"; el.style.color = "var(--text-secondary)"; }}
          >
            <Search size={15} strokeWidth={1.8} />
          </button>
          <button
            type="button"
            aria-label="Notifications"
            style={{
              width: 36, height: 36, borderRadius: "50%",
              background: "var(--surface)", border: "1px solid var(--fz-border)",
              display: "flex", alignItems: "center", justifyContent: "center",
              cursor: "pointer", color: "var(--text-secondary)", transition: "background 150ms, color 150ms",
            }}
            onMouseEnter={(e) => { const el = e.currentTarget as HTMLButtonElement; el.style.background = "var(--surface-hover)"; el.style.color = "#fff"; }}
            onMouseLeave={(e) => { const el = e.currentTarget as HTMLButtonElement; el.style.background = "var(--surface)"; el.style.color = "var(--text-secondary)"; }}
          >
            <Bell size={15} strokeWidth={1.8} />
          </button>
          <button
            type="button"
            onClick={() => router.push("/settings")}
            aria-label="Profile"
            style={{
              width: 32, height: 32, borderRadius: "50%",
              background: "var(--surface-active)", border: "1px solid var(--fz-border)",
              display: "flex", alignItems: "center", justifyContent: "center",
              cursor: "pointer", color: "#fff", fontSize: 13, fontWeight: 600, transition: "background 150ms",
            }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "var(--surface-hover)"; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "var(--surface-active)"; }}
          >
            {userInitial}
          </button>
        </div>
      </header>

      {/* Page content */}
      <main
        style={{
          marginLeft: "var(--sidebar-width)",
          paddingTop: "var(--topbar-height)",
          minHeight: "100vh",
          position: "relative",
          zIndex: 1,
        }}
      >
        <div style={{ maxWidth: 1000, margin: "0 auto", padding: "40px 32px" }}>
          {props.children}
        </div>
      </main>
    </div>
  );
}
