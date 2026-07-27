"use client";

import { useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

interface AppSidebarProps {
  onToggle: () => void;
  sidebarOpen: boolean;
}

const NAV_ITEMS: { label: string; route: string }[] = [
  { label: "Home",      route: "/dashboard" },
  { label: "My Spaces", route: "/inventory" },
  { label: "Documents", route: "/documents" },
  { label: "Settings",  route: "/settings" },
];

export function AppSidebar({ onToggle, sidebarOpen }: AppSidebarProps) {
  const pathname = usePathname();
  const router = useRouter();
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);

  async function signOut() {
    const sb = createSupabaseBrowserClient();
    await sb.auth.signOut();
    window.location.href = "/";
  }

  return (
    <aside
      style={{
        width: 220,
        position: "fixed",
        top: 0,
        left: 0,
        bottom: 0,
        background: "#0a0a0a",
        borderRight: "1px solid rgba(255,255,255,0.06)",
        zIndex: 100,
        display: "flex",
        flexDirection: "column",
        padding: 0,
        overflow: "hidden",
        transition: "width 0.25s ease, transform 0.25s ease",
        transform: sidebarOpen ? "translateX(0)" : "translateX(-220px)",
      }}
      aria-label="Primary navigation"
    >
      {/* Toggle button */}
      <button
        onClick={() => onToggle()}
        style={{
          background: "none",
          border: "none",
          cursor: "pointer",
          color: "rgba(255,255,255,0.5)",
          padding: "16px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          width: "100%",
        }}
        title="Toggle sidebar"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <line x1="3" y1="6" x2="21" y2="6"/>
          <line x1="3" y1="12" x2="21" y2="12"/>
          <line x1="3" y1="18" x2="21" y2="18"/>
        </svg>
      </button>

      {/* Nav items */}
      <nav style={{ flex: 1, overflowY: "auto", padding: "8px 8px 0" }}>
        {NAV_ITEMS.map(({ label, route }, index) => {
          const isActive = pathname === route || pathname.startsWith(route + "/");
          const isHovered = hoveredIndex === index;
          return (
            <div
              key={route}
              onClick={() => router.push(route)}
              onMouseEnter={() => setHoveredIndex(index)}
              onMouseLeave={() => setHoveredIndex(null)}
              style={isActive ? {
                background: "rgba(255,255,255,0.08)",
                border: "1px solid rgba(255,255,255,0.08)",
                borderRadius: "8px",
                padding: "9px 16px",
                cursor: "pointer",
                color: "#ffffff",
                fontSize: "14px",
                fontWeight: 500,
                transition: "all 0.15s ease",
                marginBottom: "2px",
              } : isHovered ? {
                background: "rgba(255,255,255,0.06)",
                backdropFilter: "blur(8px)",
                WebkitBackdropFilter: "blur(8px)",
                border: "1px solid rgba(255,255,255,0.08)",
                borderRadius: "8px",
                padding: "9px 16px",
                cursor: "pointer",
                color: "rgba(255,255,255,0.8)",
                fontSize: "14px",
                fontWeight: 500,
                transition: "all 0.15s ease",
                marginBottom: "2px",
              } : {
                background: "transparent",
                border: "1px solid transparent",
                borderRadius: "8px",
                padding: "9px 16px",
                cursor: "pointer",
                color: "rgba(255,255,255,0.5)",
                fontSize: "14px",
                fontWeight: 500,
                transition: "all 0.15s ease",
                marginBottom: "2px",
              }}
            >
              {label}
            </div>
          );
        })}
      </nav>

      {/* Bottom section */}
      <div style={{ padding: "16px", borderTop: "1px solid rgba(255,255,255,0.06)" }}>
        <button
          type="button"
          onClick={() => void signOut()}
          style={{
            width: "100%",
            background: "none",
            border: "none",
            color: "rgba(255,255,255,0.35)",
            fontSize: "13px",
            cursor: "pointer",
            textAlign: "left",
            padding: "8px 4px",
          }}
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}
