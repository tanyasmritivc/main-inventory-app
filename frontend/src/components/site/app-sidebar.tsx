"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import {
  BookOpen,
  Boxes,
  ClipboardCheck,
  FileStack,
  FolderKanban,
  Home,
  KeyRound,
  Layers3,
  ListChecks,
  LogOut,
  MapPin,
  Printer,
  ScanLine,
  Settings,
  ShoppingCart,
  Sparkles,
  Users,
  X,
  History,
  Bell,
} from "lucide-react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export type AppNavItem = {
  label: string;
  route: string;
  icon: typeof Boxes;
  section: "FindEZ" | "Your world" | "Organize" | "You";
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
    label: "Teams",
    route: "/teams",
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
    section: "Organize",
    keywords: ["uncertain", "confirm", "correct"],
  },
  {
    label: "Restock",
    route: "/restock",
    icon: ShoppingCart,
    section: "Organize",
    keywords: ["to buy", "on order", "shopping", "low stock", "arrival"],
  },
  {
    label: "Lent items",
    route: "/checkout",
    icon: ClipboardCheck,
    section: "Organize",
    keywords: ["check-outs", "borrow", "return"],
  },
  {
    label: "Project kits",
    route: "/project-kits",
    icon: FolderKanban,
    section: "Organize",
    keywords: ["BOM", "readiness", "reservations"],
  },
  {
    label: "Smart collections",
    route: "/collections",
    icon: Layers3,
    section: "Organize",
    keywords: ["before I buy"],
  },
  {
    label: "Labels",
    route: "/labels",
    icon: Printer,
    section: "Organize",
    keywords: ["QR", "print", "bins"],
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

export function AppSidebar({
  onToggle,
  sidebarOpen,
  userName = "Your account",
  userInitial = "",
  avatarUrl,
}: {
  onToggle: () => void;
  sidebarOpen: boolean;
  userName?: string;
  userInitial?: string;
  avatarUrl?: string;
}) {
  const pathname = usePathname(),
    router = useRouter();
  const container = useRef<HTMLElement>(null);
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
  const active = activeNavItem(pathname);
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
        className={`app-sidebar ${sidebarOpen ? "is-open" : ""} ${hovered ? "is-hovered" : ""}`}
        onMouseEnter={() => {
          if (
            window.innerWidth >= 860 &&
            window.matchMedia("(hover: hover) and (pointer: fine)").matches
          ) setHovered(true);
        }}
        onMouseLeave={() => setHovered(false)}
        aria-label="Primary navigation"
      >
        <div className="app-sidebar-brand">
          <Link href="/home" aria-label="FindEZ home" onClick={closeDrawer}>
            <svg
              className="app-sidebar-logo"
              viewBox="0 0 96 96"
              fill="none"
              aria-hidden="true"
            >
              <path
                d="M25.25 40.75H55.25V70.75"
                stroke="currentColor"
                strokeWidth="11"
              />
              <path
                d="M50.25 30.75H65.25V45.75"
                stroke="#E8590C"
                strokeWidth="11"
              />
            </svg>
            <span>
              Find<span className="app-brand-ez">EZ</span>
            </span>
          </Link>
          <button
            onClick={onToggle}
            className="app-icon-button app-mobile-nav-button"
            aria-label="Close navigation"
          >
            <X size={18} />
          </button>
        </div>
        <nav className="app-sidebar-nav">
          {(["FindEZ", "Your world", "Organize", "You"] as const).map(
            (section) => (
              <div className="app-nav-section" key={section}>
                <p>{section}</p>
                {APP_NAV_ITEMS.filter((item) => item.section === section).map(
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
