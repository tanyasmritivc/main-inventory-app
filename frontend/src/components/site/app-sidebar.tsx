"use client";

import { usePathname, useRouter } from "next/navigation";
import LineSidebar from "@/components/ui/LineSidebar";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

interface AppSidebarProps {
  onToggle: () => void;
  sidebarOpen: boolean;
}

const navItems = ['Home', 'My Spaces', 'Documents', 'Shopping List', 'Check-Out Tracker', 'Settings'];

const routeMap: Record<number, string> = {
  0: '/home',
  1: '/inventory',
  2: '/documents',
  3: '/shopping-list',
  4: '/checkout-tracker',
  5: '/settings',
};

const pathnameToIndex: Record<string, number> = {
  '/home': 0,
  '/dashboard': 0,
  '/inventory': 1,
  '/documents': 2,
  '/shopping-list': 3,
  '/checkout-tracker': 4,
  '/settings': 5,
};

export function AppSidebar({ onToggle, sidebarOpen }: AppSidebarProps) {
  const pathname = usePathname();
  const router = useRouter();

  const defaultActive = pathnameToIndex[pathname] ?? 0;

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
        borderRight: "1px solid #1c1c1e",
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
      {/* Toggle button row */}
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
      <div style={{ flex: 1, overflowY: 'auto' }}>
        <LineSidebar
          items={navItems}
          accentColor="#14b8a6"
          textColor="rgba(255,255,255,0.45)"
          markerColor="rgba(255,255,255,0.15)"
          showIndex={false}
          showMarker={true}
          proximityRadius={100}
          maxShift={12}
          falloff="smooth"
          markerLength={24}
          markerGap={12}
          fontSize={0.875}
          itemGap={6}
          defaultActive={defaultActive}
          onItemClick={(index) => router.push(routeMap[index])}
        />
      </div>

      {/* Bottom section */}
      <div style={{ padding: '16px', borderTop: '1px solid rgba(255,255,255,0.06)' }}>
        <button
          type="button"
          onClick={() => void signOut()}
          style={{
            width: '100%',
            background: 'none',
            border: 'none',
            color: 'rgba(255,255,255,0.35)',
            fontSize: '13px',
            cursor: 'pointer',
            textAlign: 'left',
            padding: '8px 4px',
          }}
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}
