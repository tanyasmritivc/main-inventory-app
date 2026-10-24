import { worldNavigation, worldHref } from "./world-navigation";
import { Boxes, Building2, FileStack, FolderKanban, History, MapPin, Users, Home, Settings } from "lucide-react";
import type { AppNavItem } from "@/components/site/app-sidebar";
import type { InventoryWorkspace } from "@/lib/inventory-selection";

export type NavigationContext = {
  organization?: { id: string; name: string };
  personal?: boolean;
  breadcrumbs: { label: string; href: string }[];
  items: AppNavItem[];
  activeRoute: string;
  homeHref: string;
};
export type WorkspaceView = "overview" | "settings" | "inventories" | "people" | "locations" | "board" | "files" | "activity";
export type OrganizationView = "workspaces" | "people" | "settings";
export function organizationNavigation(id: string, name: string, view: OrganizationView): NavigationContext {
  const home = `/organizations/${encodeURIComponent(id)}`;
  const navigation = worldNavigation(id, name);
  return {...navigation, activeRoute: view === "workspaces" ? worldHref(id,"workspaces") : `${home}?view=${view}`};

}
export function workspaceNavigation(workspace: InventoryWorkspace, view: WorkspaceView): NavigationContext {
  const home = `/workspaces/${encodeURIComponent(workspace.workspace_id)}`;
  const items: AppNavItem[] = [{ label: "Inventories", route: home, icon: Boxes, section: "Workspace" }];
  if (workspace.kind !== "personal") {
    items.push({label:"Overview",route:`${home}?view=overview`,icon:Home,section:"Workspace"});
    items.push({ label: "People", route: `${home}?view=people`, icon: Users, section: "Workspace" });
    if (["owner", "mentor"].includes(workspace.role)) items.push({ label: "Locations", route: `${home}?view=locations`, icon: MapPin, section: "Workspace" });
    items.push({ label: "Tasks", route: `${home}?view=board`, icon: FolderKanban, section: "Workspace" },
      { label: "Files", route: `${home}?view=files`, icon: FileStack, section: "Workspace" },
      { label: "Activity", route: `${home}?view=activity`, icon: History, section: "Workspace" },
      { label: "Settings", route: `${home}?view=settings`, icon: Settings, section: "Workspace" });
  }
  return { organization: workspace.organization_id ? { id: workspace.organization_id, name: workspace.organization_name || "Organization" } : undefined, personal: workspace.kind === "personal", homeHref: "/organizations", activeRoute: view === "inventories" || workspace.kind === "personal" ? home : `${home}?view=${view}`, items: [...worldNavigation(workspace.organization_id || "personal",workspace.organization_name || "Personal").items, ...items],
    breadcrumbs: [workspace.organization_id ? { label: workspace.organization_name || "Organization", href: worldHref(workspace.organization_id) } : { label: "Workspaces", href: "/workspaces" }, { label: workspace.name, href: home }] };
}
export const DIRECTORY_NAVIGATION: AppNavItem[] = [
  { label: "Organizations", route: "/organizations", icon: Building2, section: "FindEZ" },
  { label: "All workspaces", route: "/workspaces", icon: FolderKanban, section: "FindEZ" },
];
