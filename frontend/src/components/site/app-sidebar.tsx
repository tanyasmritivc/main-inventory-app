"use client";
import { useInventoryRouter } from "@/components/site/inventory-link";

import Link from "@/components/site/inventory-link";
import { OrganizationSwitcher, type SelectedOrganization } from "./organization-switcher";
import { FindEZMark, FindEZWordmark } from "./findez-brand";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import {
  BookOpen,
  Boxes,
  FileStack,
  Home,
  KeyRound,
  ListChecks,
  LogOut,
  MapPin,
  ScanLine,
  Settings,
  Sparkles,
  Users,
  X,
  History,
  Bell,
  Pin,
  PinOff,
} from "lucide-react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export type AppNavItem = {
  label: string;
  route: string;
  icon: typeof Boxes;
  section: string;
  keywords?: string[];
};
export const APP_NAV_ITEMS: AppNavItem[] = [
  {
    label: "Home",
    route: "/home",
    icon: Home,
    section: "FindEZ",
    keywords: ["recent", "overview"],
  },
  {
    label: "Capture",
    route: "/scan",
    icon: ScanLine,
    section: "FindEZ",
    keywords: ["photo", "barcode", "manual", "spreadsheet", "BOM", "import"],
  },
  {
    label: "Ask FindEZ",
    route: "/assist",
    icon: Sparkles,
    section: "FindEZ",
    keywords: ["chat", "question", "photo"],
  },
  {
    label: "Find",
    route: "/inventory",
    icon: Boxes,
    section: "FindEZ",
    keywords: ["inventory", "all items", "search"],
  },
  {
    label: "Spaces",
    route: "/spaces",
    icon: MapPin,
    section: "Your world",
    keywords: ["places", "locations", "shared"],
  },
  {
    label: "Workspaces",
    route: "/workspaces",
    icon: Users,
    section: "Your world",
    keywords: ["workspace", "board", "members"],
  },
  {
    label: "Documents and notes",
    route: "/documents",
    icon: FileStack,
    section: "Your world",
  },
  {
    label: "Review",
    route: "/review",
    icon: ListChecks,
    section: "Your world",
    keywords: ["uncertain", "confirm", "correct"],
  },
  { label: "Activity", route: "/activity", icon: History, section: "You" },
  {
    label: "Notifications",
    route: "/notifications",
    icon: Bell,
    section: "You",
  },
  {
    label: "Settings",
    route: "/settings",
    icon: Settings,
    section: "You",
    keywords: ["profile", "appearance", "account"],
  },
  {
    label: "API keys",
    route: "/settings/api-keys",
    icon: KeyRound,
    section: "You",
    keywords: ["integration", "developer"],
  },
  {
    label: "API documentation",
    route: "/docs/api",
    icon: BookOpen,
    section: "You",
    keywords: ["developers", "MCP", "ChatGPT", "OpenAPI"],
  },
];

export function activeNavItem(pathname: string) {
  return APP_NAV_ITEMS.filter(
    (item) => pathname === item.route || pathname.startsWith(`${item.route}/`),
  ).sort((a, b) => b.route.length - a.route.length)[0];
}

function subscribeViewport(callback: () => void) {
  window.addEventListener("resize", callback);
  return () => window.removeEventListener("resize", callback);
}

export function AppSidebar({
  onToggle,
  sidebarOpen,
  userName = "Your account",
  userInitial = "",
  avatarUrl,
  pinned = false,
  onPin,
  items = APP_NAV_ITEMS,
  activeRoute,
  homeHref = "/home",
  accountId, organization, personal,
}: {
  onToggle: () => void;
  sidebarOpen: boolean;
  userName?: string;
  userInitial?: string;
  avatarUrl?: string;
  pinned?: boolean;
  onPin?: () => void;
  items?: AppNavItem[];
  activeRoute?: string;
  homeHref?: string;
  accountId?: string | null;
  organization?: SelectedOrganization;
  personal?: boolean;
}) {
  const pathname = usePathname(),
    router = useInventoryRouter();
  const container = useRef<HTMLElement>(null);
  const desktop = useSyncExternalStore(subscribeViewport, () => window.innerWidth >= 860, () => true);
  const [hovered, setHovered] = useState(false);
  useEffect(() => {
    if (!sidebarOpen || window.innerWidth >= 860) return;
    const previous = document.activeElement as HTMLElement | null;
    const background = [
      ...document.querySelectorAll<HTMLElement>(".app-main,.app-topbar"),
    ];
    const previousInert = background.map((el) => el.inert);
    background.forEach((el) => {
      el.inert = true;
    });
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const resize = () => {
      if (window.innerWidth >= 860) {
        window.removeEventListener("resize", resize);
        onToggle();
      }
    };
    window.addEventListener("resize", resize);
    const links = () =>
      [
        ...(container.current?.querySelectorAll<HTMLElement>(
          "a[href],button:not(:disabled)",
        ) || []),
      ].filter((el) => el.getClientRects().length);
    links()[0]?.focus();
    const keydown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onToggle();
      }
      if (event.key === "Tab") {
        const elements = links(),
          first = elements[0],
          last = elements[elements.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }
    };
    document.addEventListener("keydown", keydown);
    return () => {
      document.removeEventListener("keydown", keydown);
      window.removeEventListener("resize", resize);
      background.forEach((el, i) => {
        el.inert = previousInert[i];
      });
      document.body.style.overflow = previousOverflow;
      previous?.focus();
    };
  }, [sidebarOpen, onToggle]);
  const [error, setError] = useState("");
  const active = activeRoute ? items.find((item) => item.route === activeRoute) : items.filter((item) => pathname === item.route || pathname.startsWith(`${item.route}/`)).sort((a,b) => b.route.length - a.route.length)[0];
  function closeDrawer() {
    if (window.innerWidth < 860 && sidebarOpen) onToggle();
  }
  async function signOut() {
    const { error } = await createSupabaseBrowserClient().auth.signOut();
    if (error) {
      setError("Could not sign out. Please try again.");
      return;
    }
    router.replace("/");
    router.refresh();
  }
  return (
    <>
      {sidebarOpen && (
        <button
          className="app-sidebar-scrim"
          onClick={onToggle}
          aria-label="Close navigation"
        />
      )}
      <aside
        ref={container}
        id="app-navigation"
        className={`app-sidebar ${sidebarOpen ? "is-open" : ""} ${hovered ? "is-hovered" : ""} ${pinned ? "is-pinned" : ""}`}
        onMouseEnter={() => {
          if (
            window.innerWidth >= 860 &&
            window.matchMedia("(hover: hover) and (pointer: fine)").matches
          ) setHovered(true);
        }}
        onMouseLeave={() => setHovered(false)}
        onDoubleClick={(event) => {
          if (window.innerWidth >= 860 && !(event.target as Element).closest("a,button,input")) onPin?.();
        }}
        aria-label="Primary navigation"
        aria-hidden={!desktop && !sidebarOpen}
        inert={!desktop && !sidebarOpen}
      >
        <div className="app-sidebar-brand">
          <Link href={homeHref} aria-label="FindEZ home" onClick={closeDrawer}>
            <FindEZMark className="app-sidebar-logo" />
            <span><FindEZWordmark textOnly width={77} height={30}/></span>
          </Link>
          <button
            onClick={onToggle}
            className="app-icon-button app-mobile-nav-button"
            aria-label="Close navigation"
          >
            <X size={18} />
          </button>
          {onPin && <button
            type="button"
            className="app-icon-button app-sidebar-pin"
            onClick={onPin}
            aria-label={pinned ? "Unpin navigation" : "Pin navigation"}
            aria-pressed={pinned}
            title={pinned ? "Unpin navigation" : "Pin navigation (or double-click an empty area)"}
          >
            {pinned ? <PinOff size={16} /> : <Pin size={16} />}
          </button>}
        </div>
        {accountId !== undefined && <OrganizationSwitcher accountId={accountId} organization={organization} personal={personal} onNavigate={closeDrawer} />}
        <nav className="app-sidebar-nav">
          {[...new Set(items.map((item) => item.section))].map(
            (section) => (
              <div className="app-nav-section" key={section}>
                {section !== "FindEZ" && <p>{section}</p>}
                {items.filter((item) => item.section === section).map(
                  (item) => {
                    const Icon = item.icon;
                    return (
                      <Link
                        key={item.route}
                        href={item.route}
                        className={
                          active?.route === item.route ? "is-active" : ""
                        }
                        aria-current={
                          active?.route === item.route ? "page" : undefined
                        }
                        aria-label={item.label}
                        title={item.label}
                        onClick={closeDrawer}
                      >
                        <Icon size={17} strokeWidth={1.7} />
                        <span>{item.label}</span>
                      </Link>
                    );
                  },
                )}
              </div>
            ),
          )}
        </nav>
        <div className="app-sidebar-footer">
          <Link href="/settings" className="app-account-link" aria-label={`${userName} Profile and settings`} title="Profile and settings" onClick={closeDrawer}>
            <span
              className="app-avatar"
              style={
                avatarUrl ? { backgroundImage: `url(${avatarUrl})` } : undefined
              }
            >
              {!avatarUrl && (userInitial || "?")}
            </span>
            <span>
              <strong>{userName}</strong>
              <small>Profile and settings</small>
            </span>
          </Link>
          <button
            type="button"
            onClick={() => void signOut()}
            aria-label="Sign out"
            title="Sign out"
          >
            <LogOut size={16} />
            <span>Sign out</span>
          </button>
          {error && <p role="alert">{error}</p>}
        </div>
      </aside>
    </>
  );
}
