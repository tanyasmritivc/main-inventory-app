import {
  MessageSquarePlus,
  MapPin,
  Wrench,
  Boxes,
  Plug,
  FolderKanban,
  Users,
  Settings,
} from "lucide-react";
import type { NavigationContext } from "./context-navigation";
export function worldHref(world: string, view = "chat") {
  return `/worlds/${encodeURIComponent(world)}${view === "chat" ? "" : `?view=${encodeURIComponent(view)}`}`;
}
export function worldNavigation(
  world: string,
  name: string,
  view = "chat",
): NavigationContext {
  const home = worldHref(world);
  return {
    organization: world === "personal" ? undefined : { id: world, name },
    personal: world === "personal",
    homeHref: home,
    activeRoute: view === "cad" ? `/cad?world=${encodeURIComponent(world)}` : worldHref(world, view),
    breadcrumbs: [{ label: name, href: home }],
    items: [
      {
        label: "New chat",
        route: home,
        icon: MessageSquarePlus,
        section: "Organization",
      },
      {
        label: "Spaces",
        route: worldHref(world, "spaces"),
        icon: MapPin,
        section: "Organization",
      },
      {
        label: "Tools",
        route: worldHref(world, "tools"),
        icon: Wrench,
        section: "Organization",
      },
      {
        label: "CAD Intelligence",
        route: `/cad?world=${encodeURIComponent(world)}`,
        icon: Boxes,
        section: "Organization",
      },
      {
        label: "Connections",
        route: world === "personal" ? "/settings/connections" : `/settings/connections?organization=${encodeURIComponent(world)}`,
        icon: Plug,
        section: "Organization",
      },
      {
        label: "Workspaces",
        route: worldHref(world, "workspaces"),
        icon: FolderKanban,
        section: "Manage",
      },
      ...(world === "personal"
        ? []
        : [
            {
              label: "People",
              route: `/organizations/${encodeURIComponent(world)}?view=people`,
              icon: Users,
              section: "Manage",
            },
            {
              label: "Organization settings",
              route: `/organizations/${encodeURIComponent(world)}?view=settings`,
              icon: Settings,
              section: "Manage",
            },
          ]),
    ],
  };
}
