"use client";
import { useInventoryRouter } from "@/components/site/inventory-link";
import { accountRequest } from "@/lib/account-request";
import { subscribeNotifications } from "@/lib/notification-state";

import { usePathname } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Bell,
  Menu,
  Search,
  Users,
  UserRound,
  ArrowLeft,
  Palette,
  Sparkles,
  KeyRound,
  BookOpen,
  Settings,
  CreditCard,
} from "lucide-react";
import {
  APP_NAV_ITEMS,
  type AppNavItem,
  AppSidebar,
} from "@/components/site/app-sidebar";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { AppThemeProvider } from "@/components/site/use-app-theme";
import Link from "@/components/site/inventory-link";
import {
  DIRECTORY_NAVIGATION,
  type NavigationContext,
} from "@/lib/context-navigation";
import { worldHref, worldNavigation } from "@/lib/world-navigation";
import type { InventorySelection } from "@/lib/inventory-selection";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

import { AccountMenu } from "./account-menu";
import shellStyles from "./desktop-shell.module.css";
import { AccountVerification } from "./account-verification";
import accountStyles from "./account-layout.module.css";

const PENDING_SIGNUP_PROFILE_KEY = "findez_pending_signup_profile";

export function AppShell({
  children,
  inventory,
  context,
}: {
  children: React.ReactNode;
  inventory?: InventorySelection;
  context?: NavigationContext;
}) {
  const router = useInventoryRouter();
  const pathname = usePathname();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [sidebarPinned, setSidebarPinned] = useState(true);
  useEffect(() => {
    try {
      setSidebarPinned(
        localStorage.getItem("findez-navigation-pinned") !== "false",
      );
    } catch {
      /* Session preference still works. */
    }
  }, []);
  const togglePin = useCallback(() => {
    const next = !sidebarPinned;
    setSidebarPinned(next);
    try {
      localStorage.setItem("findez-navigation-pinned", String(next));
    } catch {
      /* Session preference still works. */
    }
  }, [sidebarPinned]);
  const toggleSidebar = useCallback(
    () => setSidebarOpen((value) => !value),
    [],
  );
  const [commandOpen, setCommandOpen] = useState(false);
  const commandTrigger = useRef<HTMLButtonElement>(null);
  const [commandQuery, setCommandQuery] = useState("");
  const [userId, setUserId] = useState<string | null>(null);
  const [userInitial, setUserInitial] = useState("");
  const [userEmail, setUserEmail] = useState("");
  const accountPage =
    pathname === "/settings" || pathname.startsWith("/settings/");
  const [userName, setUserName] = useState("Your account");
  const [avatarUrl, setAvatarUrl] = useState<string>();
  const [unread, setUnread] = useState<number | null>(null);

  useEffect(() => {
    let active = true,
      generation = 0,
      notificationGeneration = 0;
    let notificationAccount: string | undefined;
    const signupAttempts = new Set<string>();
    async function loadIdentity() {
      const ticket = ++generation;
      const current = () => active && ticket === generation;
      const { data } = await supabase.auth.getSession();
      if (!current()) return;
      const user = data.session?.user;
      setUserId(user?.id || null);
      if (notificationAccount !== user?.id) {
        notificationAccount = user?.id;
        notificationGeneration++;
        setUnread(null);
      }
      const name = String(
        user?.user_metadata?.display_name ?? user?.email ?? "",
      );
      setUserInitial(name.slice(0, 1).toUpperCase());
      setUserEmail(user?.email || "");
      setUserName(name || "Your account");
      setAvatarUrl(undefined);
      const { data: sessionData } = await supabase.auth.getSession();
      if (current() && user && sessionData.session?.user.id === user.id) {
        const profileRequest = accountRequest<{
          display_name?: string;
          avatar_url?: string;
        }>(user.id, "/profile/me")
          .then((profile) => {
            if (current()) {
              setUserName(profile.display_name || name || "Your account");
              setUserInitial(
                (profile.display_name || name).slice(0, 1).toUpperCase(),
              );
              setAvatarUrl(profile.avatar_url || undefined);
            }
          })
          .catch(() => {});
        const notificationTicket = ++notificationGeneration;
        const notificationsRequest = accountRequest<{ unread_count: number }>(
          user.id,
          "/notifications",
        )
          .then((result) => {
            if (current() && notificationTicket === notificationGeneration)
              setUnread(
                Number.isSafeInteger(result.unread_count) &&
                  result.unread_count >= 0
                  ? result.unread_count
                  : null,
              );
          })
          .catch(() => {
            if (current() && notificationTicket === notificationGeneration)
              setUnread(null);
          });
        await Promise.allSettled([profileRequest, notificationsRequest]);
      }
      if (!current()) return;
      // Legacy signup completion must not delay the current account's identity.
      const pendingValue = window.localStorage.getItem(
        PENDING_SIGNUP_PROFILE_KEY,
      );
      if (user && pendingValue && !signupAttempts.has(user.id)) {
        // updateUser emits USER_UPDATED. Do not reenter an unfinished attempt.
        signupAttempts.add(user.id);
        try {
          const pending = JSON.parse(pendingValue) as Record<string, unknown>;
          const displayName = String(pending.displayName ?? "").trim();
          const firstName = String(pending.cleanFirstName ?? "").trim();
          const lastName = String(pending.cleanLastName ?? "").trim();
          const profileRole = String(pending.cleanProfileRole ?? "").trim();
          const organization = String(pending.cleanOrganization ?? "").trim();
          if (displayName) {
            const { error: metadataError } = await supabase.auth.updateUser({
              data: {
                display_name: displayName,
                full_name: displayName,
                given_name: firstName,
                family_name: lastName,
                profile_role: profileRole,
                organization,
                ...(typeof pending.termsVersion === "string" &&
                typeof pending.termsAcceptedAt === "string" &&
                pending.eligibilityAttested === true
                  ? {
                      terms_version: pending.termsVersion,
                      terms_accepted_at: pending.termsAcceptedAt,
                      eligibility_attested: true,
                    }
                  : {}),
              },
            });
            const { error: profileError } = await supabase
              .from("profiles")
              .upsert({
                id: user.id,
                display_name: displayName,
                first_name: firstName,
                last_name: lastName,
                profile_role: profileRole,
                organization,
              });
            if (!metadataError && !profileError)
              window.localStorage.removeItem(PENDING_SIGNUP_PROFILE_KEY);
          }
        } catch {
          window.localStorage.removeItem(PENDING_SIGNUP_PROFILE_KEY);
        }
      }
    }
    void loadIdentity();
    const { data: authListener } = supabase.auth.onAuthStateChange((event) => {
      if (!["SIGNED_IN", "SIGNED_OUT", "USER_UPDATED"].includes(event)) return;
      generation++;
      setUserId(null);
      setUserName("Your account");
      setUserInitial("");
      setAvatarUrl(undefined);
      notificationAccount = undefined;
      notificationGeneration++;
      setUnread(null);
      if (event !== "SIGNED_OUT") void Promise.resolve().then(loadIdentity);
    });
    const onProfileChange = () => {
      void loadIdentity();
    };
    window.addEventListener("findez-profile-changed", onProfileChange);
    const stopNotifications = subscribeNotifications((value) => {
      if (!active || value.accountId !== notificationAccount) return;
      notificationGeneration++;
      setUnread(value.unread);
      if (value.unread === null) void loadIdentity();
    });
    const onFocus = () => {
      if (document.visibilityState === "visible") void loadIdentity();
    };
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onFocus);
    const timer = window.setInterval(onFocus, 60_000);
    return () => {
      active = false;
      generation++;
      authListener.subscription.unsubscribe();
      window.clearInterval(timer);
      window.removeEventListener("findez-profile-changed", onProfileChange);
      stopNotifications();
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onFocus);
    };
  }, [supabase]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setSidebarOpen(false);
        setCommandOpen((value) => !value);
      }
      if (event.key === "Escape") setCommandOpen(false);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  const accountItems: AppNavItem[] = [
    {
      label: "Back to chat",
      route: "/worlds",
      icon: ArrowLeft,
      section: "Account",
    },
    {
      label: "Organizations",
      route: "/settings/organizations",
      icon: Users,
      section: "Account settings",
    },
    {
      label: "Profile",
      route: "/settings/profile",
      icon: UserRound,
      section: "Account settings",
    },
    {
      label: "Appearance",
      route: "/settings/appearance",
      icon: Palette,
      section: "Account settings",
    },
    {
      label: "AI memory",
      route: "/settings/memory",
      icon: Sparkles,
      section: "Account settings",
    },
    {
      label: "Plans",
      route: "/settings/plans",
      icon: CreditCard,
      section: "Account settings",
    },
    {
      label: "Developer",
      route: "/settings/developer",
      icon: KeyRound,
      section: "Account settings",
    },
    {
      label: "Help and information",
      route: "/settings/help",
      icon: BookOpen,
      section: "Account settings",
    },
    {
      label: "Account",
      route: "/settings/account",
      icon: Settings,
      section: "Account settings",
    },
  ];
  const world = inventory
    ? worldNavigation(
        inventory.workspace.organization_id || "personal",
        inventory.workspace.organization_name || "Personal",
        ["/inventory", "/home", "/spaces"].includes(pathname)
          ? "spaces"
          : "tools",
      )
    : undefined;
  const navigationItems = accountPage
    ? accountItems
    : context?.items ||
      (inventory?.can_open === false
        ? [
            {
              label: "Workspace",
              route: `/workspaces/${encodeURIComponent(inventory.workspace.workspace_id)}`,
              icon: ArrowLeft,
              section: "Workspace",
            },
            {
              label: "Inventory settings",
              route: "/inventory-access",
              icon: Users,
              section: "Administration",
            },
          ]
        : world
          ? world.items
          : [
              ...DIRECTORY_NAVIGATION,
              ...APP_NAV_ITEMS.filter((item) =>
                [
                  "/notifications",
                  "/settings",
                  "/settings/api-keys",
                  "/docs/api",
                ].includes(item.route),
              ),
            ]);
  const breadcrumbs = accountPage
    ? [{ label: "Account", href: "/settings" }]
    : context?.breadcrumbs ||
      (inventory
        ? [
            inventory.workspace.organization_id
              ? {
                  label:
                    inventory.workspace.organization_name || "Organization",
                  href: worldHref(inventory.workspace.organization_id),
                }
              : { label: "Workspaces", href: "/workspaces" },
            {
              label: inventory.workspace.name,
              href: `/workspaces/${encodeURIComponent(inventory.workspace.workspace_id)}`,
            },
            {
              label: inventory.name,
              href: `/${inventory.can_open === false ? "inventory-access" : "inventory"}?inventory=${encodeURIComponent(inventory.inventory_id)}`,
            },
          ]
        : []);
  const commandItems = navigationItems.filter((item) =>
    [item.label, item.section, ...(item.keywords ?? [])]
      .join(" ")
      .toLowerCase()
      .includes(commandQuery.trim().toLowerCase()),
  );
  return (
    <AppThemeProvider>
      {!accountPage && <AccountVerification prompt />}
      <div
        className={`app-frame ${shellStyles.shell} ${accountPage ? accountStyles.shell : ""} ${!inventory ? "is-context-management" : ""} ${pathname === "/assist" || (pathname.startsWith("/worlds/") && context?.activeRoute === context?.homeHref) ? "is-ask-workspace" : ""} ${pathname.startsWith("/teams") ? "is-team-workspace" : ""} ${sidebarOpen ? "sidebar-open" : ""} ${accountPage || sidebarPinned ? "sidebar-pinned" : ""}`}
      >
        <a className="app-skip-link" href="#app-main">
          Skip to content
        </a>
        <AppSidebar
          accountId={userId}
          organization={
            context?.organization ||
            (inventory?.workspace.organization_id
              ? {
                  id: inventory.workspace.organization_id,
                  name: inventory.workspace.organization_name || "Organization",
                }
              : undefined)
          }
          personal={
            context?.personal || inventory?.workspace.kind === "personal"
          }
          onToggle={toggleSidebar}
          sidebarOpen={sidebarOpen}
          userName={userName}
          userInitial={userInitial}
          avatarUrl={avatarUrl}
          pinned={accountPage || sidebarPinned}
          onPin={accountPage ? undefined : togglePin}
          items={navigationItems}
          activeRoute={
            accountPage
              ? pathname.startsWith("/settings/api-keys")
                ? "/settings/developer"
                : pathname === "/settings"
                  ? "/settings/profile"
                  : pathname
              : context?.activeRoute || world?.activeRoute
          }
          homeHref={context?.homeHref || world?.homeHref || "/organizations"}
        />
        <header className="app-topbar">
          <button
            className="app-icon-button app-mobile-nav-button"
            onClick={() => setSidebarOpen(true)}
            aria-label="Open navigation"
            aria-controls="app-navigation"
            aria-expanded={sidebarOpen}
          >
            <Menu size={19} />
          </button>
          {breadcrumbs.length > 0 && (
            <nav
              className="app-inventory-switcher"
              aria-label={inventory ? "Current inventory" : "Current workspace"}
            >
              {breadcrumbs.map((crumb, index) => (
                <span className="context-crumb" key={crumb.href}>
                  {index > 0 && <span aria-hidden="true">/</span>}
                  <Link href={crumb.href}>{crumb.label}</Link>
                </span>
              ))}
              {inventory && !inventory.can_edit && (
                <small>
                  {inventory.can_open === false
                    ? "Administration only"
                    : "View only"}
                </small>
              )}
            </nav>
          )}
          <div className="app-topbar-spacer" />
          <button
            className="app-command-trigger"
            aria-label="Go to a page"
            ref={commandTrigger}
            onClick={() => setCommandOpen(true)}
          >
            <Search size={15} />
            <span>Go to…</span>
            <kbd>⌘K</kbd>
          </button>
          <button
            className="app-icon-button app-notification-button"
            onClick={() => router.push("/notifications")}
            aria-label={
              unread === null
                ? "Notifications"
                : `${unread} unread notifications`
            }
            title={
              unread === null
                ? "Open notifications to check for updates"
                : undefined
            }
          >
            <Bell size={18} />
            {unread !== null && unread > 0 && (
              <span>{unread > 99 ? "99+" : unread}</span>
            )}
          </button>
          <AccountMenu
            name={userName}
            email={userEmail}
            initial={userInitial}
            avatarUrl={avatarUrl}
          />
        </header>
        <main id="app-main" className="app-main" tabIndex={-1}>
          <div className="app-content">{children}</div>
        </main>
        <Dialog open={commandOpen} onOpenChange={setCommandOpen}>
          <DialogContent
            className="command-panel"
            onCloseAutoFocus={(event) => {
              event.preventDefault();
              commandTrigger.current?.focus();
            }}
          >
            <DialogTitle className="sr-only">Navigate FindEZ</DialogTitle>
            <DialogDescription className="sr-only">
              Search and open a feature.
            </DialogDescription>
            <div className="command-input-row">
              <Search size={18} />
              <input
                autoFocus
                aria-label="Search features and pages"
                value={commandQuery}
                onChange={(event) => setCommandQuery(event.target.value)}
                placeholder="Search features and pages"
              />
            </div>
            <div className="command-results">
              {commandItems.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.route}
                    onClick={() => {
                      router.push(item.route);
                      setCommandOpen(false);
                      setCommandQuery("");
                    }}
                  >
                    <Icon size={17} />
                    <span>
                      <strong>{item.label}</strong>
                    </span>
                  </button>
                );
              })}
              {commandItems.length === 0 && <p>No matching FindEZ feature.</p>}
            </div>
          </DialogContent>
        </Dialog>
      </div>
    </AppThemeProvider>
  );
}
