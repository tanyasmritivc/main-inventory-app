import { isProtectedPath } from "./protected-routes";

export const RESUME_COOKIE = "findez-resume";
export const RESUME_MAX_AGE = 400 * 24 * 60 * 60;
const QUERY_KEYS = new Set(["inventory", "space", "view", "workspace", "tab"]);
// Utility screens must not become the default destination on the next sign-in.
// Validate on read too, so cookies saved by older releases stop replaying them.
const NON_RESUMABLE_PATH = /^\/(?:onboarding|inventory-access-request|settings|inventory\/connect)(?:\/|$)/;

/** Only navigation state is retained, never prompts, credentials or action URLs. */
export function resumePath(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 2000 || !value.startsWith("/") || value.startsWith("//") || /[\\\u0000-\u0020]/.test(value)) return null;
  try {
    const url = new URL(value, "https://findez.ai");
    const path = decodeURIComponent(url.pathname);
    if (url.origin !== "https://findez.ai" || /[\\\u0000-\u001f]/.test(path) || !isProtectedPath(path) || path === "/worlds" || NON_RESUMABLE_PATH.test(path)) return null;
    const query = new URLSearchParams();
    for (const [key, entry] of url.searchParams) if (QUERY_KEYS.has(key) && entry.length <= 200) query.set(key, entry);
    return url.pathname + (query.size ? `?${query}` : "");
  } catch { return null; }
}

export function readResume(value: string | undefined, accountId: string): string | null {
  try {
    const saved = JSON.parse(decodeURIComponent(value || ""));
    return saved.accountId === accountId ? resumePath(saved.path) : null;
  } catch { return null; }
}

export function rememberedPage(accountId: string): string | null {
  try {
    const value = document.cookie.split("; ").find(row => row.startsWith(`${RESUME_COOKIE}=`))?.slice(RESUME_COOKIE.length + 1);
    return readResume(value, accountId);
  } catch { return null; }
}

export function rememberPage(accountId: string, value: string) {
  const path = resumePath(value);
  if (!path) return;
  try {
    const encoded = encodeURIComponent(JSON.stringify({ accountId, path }));
    document.cookie = `${RESUME_COOKIE}=${encoded}; Path=/; Max-Age=${RESUME_MAX_AGE}; SameSite=Lax${location.protocol === "https:" ? "; Secure" : ""}`;
  } catch { /* Navigation remains available if storage is disabled. */ }
}

export function conversationResumeKey(accountId: string, scope: string) {
  return `findez-active-chat:${accountId}${scope}`;
}
