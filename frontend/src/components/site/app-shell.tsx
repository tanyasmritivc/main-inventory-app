"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AppSidebar } from "@/components/site/app-sidebar";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

const PAGE_TITLES: Record<string, string> = {
  "/dashboard":   "Home",
  "/inventory":   "My Spaces",
  "/sharing":     "Shared Space",
  "/documents":   "Documents",
  "/settings":    "Settings",
};

function resolveTitle(pathname: string): string {
  for (const [key, val] of Object.entries(PAGE_TITLES)) {
    if (pathname === key || pathname.startsWith(key + "/")) return val;
  }
  return "FindEZ";
}

const HamburgerIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <line x1="3" y1="6" x2="21" y2="6"/>
    <line x1="3" y1="12" x2="21" y2="12"/>
    <line x1="3" y1="18" x2="21" y2="18"/>
  </svg>
);

export function AppShell(props: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [userInitial, setUserInitial] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(true);

  useEffect(() => {
    const sb = createSupabaseBrowserClient();
    sb.auth.getUser().then(({ data }) => {
      const email = data.user?.email ?? "";
      setUserInitial(email ? email[0].toUpperCase() : "");
    }).catch(() => {});
  }, []);

  const title = resolveTitle(pathname);
  const isDashboard = pathname === "/dashboard" || pathname === "/home";

  return (
    <div style={{ minHeight: "100vh", background: "#090a12" }}>
      <AppSidebar
        onToggle={() => setSidebarOpen((prev) => !prev)}
        sidebarOpen={sidebarOpen}
      />

      {/* Floating hamburger — visible only when sidebar is closed */}
      {!sidebarOpen && (
        <button
          onClick={() => setSidebarOpen(true)}
          style={{
            position: "fixed",
            top: 12,
            left: 12,
            zIndex: 100,
            background: "none",
            border: "none",
            cursor: "pointer",
            color: "rgba(255,255,255,0.5)",
            padding: "8px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
          title="Open sidebar"
        >
          <HamburgerIcon />
        </button>
      )}

      {/* Top bar — hidden on dashboard */}
      <header
        style={{
          position: "fixed",
          top: 0,
          left: sidebarOpen ? 220 : 0,
          right: 0,
          height: "52px",
          background: "rgba(10, 10, 10, 0.7)",
          backdropFilter: "blur(16px)",
          WebkitBackdropFilter: "blur(16px)",
          borderBottom: "1px solid rgba(255,255,255,0.06)",
          zIndex: 50,
          display: isDashboard ? "none" : "flex",
          alignItems: "center",
          padding: "0 24px",
          transition: "left 0.25s ease",
        }}
      >
        <span
          style={{ fontSize: 14, fontWeight: 590, color: "#f5f5f7", letterSpacing: "-0.028em", flex: 1 }}
        >
          {title}
        </span>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <button
            type="button"
            onClick={() => router.push("/settings")}
            aria-label="Profile"
            style={{
              width: 28, height: 28, borderRadius: "50%",
              background: userInitial ? "#2c2c2e" : "#1c1c1e",
              border: "1px solid #2c2c2e",
              display: "flex", alignItems: "center", justifyContent: "center",
              cursor: "pointer", color: userInitial ? "#f5f5f7" : "#a1a1a6", fontSize: 12, fontWeight: 590, transition: "all 150ms",
            }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "#2c2c2e"; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = userInitial ? "#2c2c2e" : "#1c1c1e"; }}
          >
            {userInitial}
          </button>
        </div>
      </header>

      {/* Page content */}
      <main
        key={pathname}
        style={{
          marginLeft: sidebarOpen ? 220 : 0,
          paddingTop: isDashboard ? 0 : 52,
          minHeight: "100vh",
          position: "relative",
          zIndex: 1,
          transition: "margin-left 0.25s ease",
          animation: "fadeIn 0.3s ease",
        }}
      >
        <div style={{ maxWidth: 1200, margin: "0 auto", padding: "32px 36px" }}>
          {props.children}
        </div>
      </main>
    </div>
  );
}
