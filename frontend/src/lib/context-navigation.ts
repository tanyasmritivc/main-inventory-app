import { Boxes, Building2, FileStack, FolderKanban, History, MapPin, Users } from "lucide-react";
import type { AppNavItem } from "@/components/site/app-sidebar";
import type { InventoryWorkspace } from "@/lib/inventory-selection";

export type NavigationContext = {
  breadcrumbs: { label: string; href: string }[];
  items: AppNavItem[];
  activeRoute: string;
  homeHref: string;
};
export type WorkspaceView = "inventories" | "people" | "locations" | "board" | "files" | "activity";
export type OrganizationView = "workspaces" | "people";
export function organizationNavigation(id: string, name: string, view: OrganizationView): NavigationContext {
  const home = `/organizations/${encodeURIComponent(id)}`;
  return { breadcrumbs: [{ label: "Organizations", href: "/organizations" }, { label: name, href: home }], homeHref: "/organizations",
    activeRoute: view === "people" ? `${home}?view=people` : home,
    items: [{ label: "Workspaces", route: home, icon: FolderKanban, section: "Organization" }, { label: "People", route: `${home}?view=people`, icon: Users, section: "Organization" }] };
}
export function workspaceNavigation(workspace: InventoryWorkspace, view: WorkspaceView): NavigationContext {
  const home = `/workspaces/${encodeURIComponent(workspace.workspace_id)}`;
  const items: AppNavItem[] = [{ label: "Inventories", route: home, icon: Boxes, section: "Workspace" }];
  if (workspace.kind !== "personal") {
    items.push({ label: "People", route: `${home}?view=people`, icon: Users, section: "Workspace" });
    if (["owner", "mentor"].includes(workspace.role)) items.push({ label: "Locations", route: `${home}?view=locations`, icon: MapPin, section: "Workspace" });
    items.push({ label: "Board", route: `${home}?view=board`, icon: FolderKanban, section: "Workspace" },
      { label: "Documents", route: `${home}?view=files`, icon: FileStack, section: "Workspace" },
      { label: "Activity", route: `${home}?view=activity`, icon: History, section: "Workspace" });
  }
  return { homeHref: "/organizations", activeRoute: view === "inventories" ? home : `${home}?view=${view}`, items,
    breadcrumbs: [workspace.organization_id ? { label: workspace.organization_name || "Organization", href: `/organizations/${encodeURIComponent(workspace.organization_id)}` } : { label: "Workspaces", href: "/workspaces" }, { label: workspace.name, href: home }] };
}
export const DIRECTORY_NAVIGATION: AppNavItem[] = [
  { label: "Organizations", route: "/organizations", icon: Building2, section: "FindEZ" },
  { label: "All workspaces", route: "/workspaces", icon: FolderKanban, section: "FindEZ" },
];
