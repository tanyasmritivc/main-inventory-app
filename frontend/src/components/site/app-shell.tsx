"use client";
import { accountRequest } from "@/lib/account-request";

import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Bell, Menu, Search, UserRound } from "lucide-react";
import {
  APP_NAV_ITEMS,
  AppSidebar,
  activeNavItem,
} from "@/components/site/app-sidebar";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { AppThemeProvider } from "@/components/site/use-app-theme";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

const PENDING_SIGNUP_PROFILE_KEY = "findez_pending_signup_profile";

export function AppShell({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const toggleSidebar = useCallback(
    () => setSidebarOpen((value) => !value),
    [],
  );
  const [commandOpen, setCommandOpen] = useState(false);
  const [commandQuery, setCommandQuery] = useState("");
  const [userInitial, setUserInitial] = useState("");
  const [userName, setUserName] = useState("Your account");
  const [avatarUrl, setAvatarUrl] = useState<string>();
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    let active = true,
      generation = 0;
    async function loadIdentity() {
      const ticket = ++generation;
      const current = () => active && ticket === generation;
      const { data } = await supabase.auth.getSession();
      if (!current()) return;
      const user = data.session?.user;
      const name = String(
        user?.user_metadata?.display_name ?? user?.email ?? "",
      );
      setUserInitial(name.slice(0, 1).toUpperCase());
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
        const notificationsRequest = accountRequest<{ unread_count: number }>(
          user.id,
          "/notifications",
        )
          .then((result) => {
            if (current()) setUnread(result.unread_count ?? 0);
          })
          .catch(() => {});
        await Promise.allSettled([profileRequest, notificationsRequest]);
      }
      if (!current()) return;
      // Legacy signup completion must not delay the current account's identity.
      const pendingValue = window.localStorage.getItem(
        PENDING_SIGNUP_PROFILE_KEY,
      );
      if (user && pendingValue) {
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
      setUserName("Your account");
      setUserInitial("");
      setAvatarUrl(undefined);
      setUnread(0);
      if (event !== "SIGNED_OUT") void Promise.resolve().then(loadIdentity);
    });
    const onProfileChange = () => {
      void loadIdentity();
    };
    window.addEventListener("findez-profile-changed", onProfileChange);
    const timer = window.setInterval(loadIdentity, 60_000);
    return () => {
      active = false;
      generation++;
      authListener.subscription.unsubscribe();
      window.clearInterval(timer);
      window.removeEventListener("findez-profile-changed", onProfileChange);
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

  const commandItems = APP_NAV_ITEMS.filter((item) =>
    [item.label, item.section, ...(item.keywords ?? [])]
      .join(" ")
      .toLowerCase()
      .includes(commandQuery.trim().toLowerCase()),
  );
  const activeItem = activeNavItem(pathname);
  const pageLabel = pathname.startsWith("/settings/api-keys")
    ? "API keys"
    : pathname.startsWith("/settings")
      ? "Settings"
      : pathname.startsWith("/notifications")
        ? "Notifications"
        : pathname.startsWith("/docs/api")
          ? "API documentation"
          : (activeItem?.label ?? "Workspace");

  return (
    <AppThemeProvider>
      <div
        className={`app-frame ${pathname.startsWith("/teams") ? "is-team-workspace" : ""} ${sidebarOpen ? "sidebar-open" : ""}`}
      >
        <a className="app-skip-link" href="#app-main">
          Skip to content
        </a>
        <AppSidebar
          onToggle={toggleSidebar}
          sidebarOpen={sidebarOpen}
          userName={userName}
          userInitial={userInitial}
          avatarUrl={avatarUrl}
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
          <div className="app-breadcrumbs" aria-label="Current location">
            <span>{pageLabel}</span>
          </div>
          <div className="app-topbar-spacer" />
          <button
            className="app-command-trigger"
            aria-label="Go to a page"
            onClick={() => setCommandOpen(true)}
          >
            <Search size={15} />
            <span>Go to…</span>
            <kbd>⌘K</kbd>
          </button>
          <button
            className="app-icon-button app-notification-button"
            onClick={() => router.push("/notifications")}
            aria-label={`${unread} unread notifications`}
          >
            <Bell size={18} />
            {unread > 0 && <span>{unread > 99 ? "99+" : unread}</span>}
          </button>
          <button
            className="app-avatar"
            onClick={() => router.push("/settings")}
            aria-label="Open profile"
            style={
              avatarUrl
                ? {
                    backgroundImage: `url(${avatarUrl})`,
                    backgroundSize: "cover",
                    backgroundPosition: "center",
                  }
                : undefined
            }
          >
            {!avatarUrl && (userInitial || <UserRound size={16} />)}
          </button>
        </header>
        <main id="app-main" className="app-main" tabIndex={-1}>
          <div className="app-content">{children}</div>
        </main>
        <Dialog open={commandOpen} onOpenChange={setCommandOpen}>
          <DialogContent className="command-panel">
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
              <kbd>esc</kbd>
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
                      <small>{item.section}</small>
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
