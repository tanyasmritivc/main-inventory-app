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

export function AppShell(props: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [userInitial, setUserInitial] = useState("");

  useEffect(() => {
    const sb = createSupabaseBrowserClient();
    sb.auth.getUser().then(({ data }) => {
      const email = data.user?.email ?? "";
      setUserInitial(email ? email[0].toUpperCase() : "");
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
          background: "rgba(0,0,0,0.82)",
          backdropFilter: "blur(20px) saturate(180%)",
          WebkitBackdropFilter: "blur(20px) saturate(180%)",
          borderBottom: "1px solid #1c1c1e",
          zIndex: 99,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "0 28px",
        }}
      >
        <span
          style={{ fontSize: 14, fontWeight: 590, color: "#f5f5f7", letterSpacing: "-0.028em" }}
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
        style={{
          marginLeft: "var(--sidebar-width)",
          paddingTop: "var(--topbar-height)",
          minHeight: "100vh",
          position: "relative",
          zIndex: 1,
        }}
      >
        <div style={{ maxWidth: 1200, margin: "0 auto", padding: "32px 36px" }}>
          {props.children}
        </div>
      </main>
    </div>
  );
}
