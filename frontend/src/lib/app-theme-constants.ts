export const APP_THEME_STORAGE_KEY = "findez-app-theme";

// Product routes across the workspace, world and organization layouts. Kept as a flat prefix list, not derived
// from the router at runtime, because the inline theme script in
// layout.tsx runs before React and cannot import route metadata.
export const INTERIOR_PATH_PREFIXES = [
  "/cad",
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

// Public API docs share Appearance without becoming an authenticated product route.
export const THEMED_PATH_PREFIXES = [...INTERIOR_PATH_PREFIXES, "/docs/api"];

export function isThemedPath(pathname: string): boolean {
  return THEMED_PATH_PREFIXES.some(prefix => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

// Shared with the root document so saved appearance applies before first paint.
export const APP_THEME_INIT_SCRIPT = `(function(){try{var p=["${THEMED_PATH_PREFIXES.join('","')}"];var path=window.location.pathname;var isThemed=false;for(var i=0;i<p.length;i++){if(path===p[i]||path.indexOf(p[i]+"/")===0){isThemed=true;break;}}if(!isThemed)return;var stored;try{stored=window.localStorage.getItem(${JSON.stringify(APP_THEME_STORAGE_KEY)});}catch(e){}var dark=stored==="dark"||(stored==="system"&&window.matchMedia("(prefers-color-scheme: dark)").matches);document.documentElement.dataset.appTheme=dark?"dark":"light";if(dark)document.documentElement.classList.add("dark");var meta=document.querySelector('meta[name="theme-color"]');if(meta)meta.setAttribute("content",dark?"#0d0d0f":"#ffffff");}catch(e){}})();`;
