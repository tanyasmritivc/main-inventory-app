export const APP_THEME_STORAGE_KEY = "findez-app-theme";

// Product routes across the workspace, world and organization layouts. Kept as a flat prefix list, not derived
// from the router at runtime, because the inline theme script in
// layout.tsx runs before React and cannot import route metadata.
export const INTERIOR_PATH_PREFIXES = [
  "/join/access",
  "/organizations",
  "/worlds",
  "/inventory-access",
  "/inventory-access-request",
  "/agent-approvals",
  "/workspaces",
  "/home",
  "/spaces",
  "/restock",
  "/activity",
  "/inventory",
  "/documents",
  "/settings",
  "/collections",
  "/checkout",
  "/project-kits",
  "/review",
  "/teams",
  "/notifications",
  "/assist",
  "/labels",
  "/scan",
  "/sharing",
];

export function isInteriorPath(pathname: string): boolean {
  return INTERIOR_PATH_PREFIXES.some(prefix => pathname === prefix || pathname.startsWith(`${prefix}/`));
}
