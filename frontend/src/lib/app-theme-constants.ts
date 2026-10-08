export const APP_THEME_STORAGE_KEY = "findez-app-theme";

// Every route inside the persistent src/app/(workspace)/layout.tsx shell. Kept as a flat prefix list, not derived
// from the router at runtime, because the inline theme script in
// layout.tsx runs before React and cannot import route metadata.
export const INTERIOR_PATH_PREFIXES = [
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
