/** Image paths locate an object; the same-origin proxy verifies the session. */
export function privateImagePath(source: string): string | null {
  try {
    const url = new URL(source, "https://findez.invalid");
    const configured = process.env.NEXT_PUBLIC_SUPABASE_URL;
    if (!configured || url.origin !== new URL(configured).origin) return null;
    const match = url.pathname.match(/^\/+storage\/v1\/object\/(?:public\/|sign\/|authenticated\/)?item-images\/(.+)$/);
    if (!match) return null;
    const path = decodeURIComponent(match[1]);
    if (!/^[0-9a-f-]{36}\//i.test(path) || path.includes("\\") || /%[0-9a-f]{2}/i.test(path) || path.split("/").some(part=>!part || part==="." || part==="..")) return null;
    return path;
  } catch { return null; }
}
export function privateImageSrc(source: string, accountId?: string | null): string;
export function privateImageSrc(source: string | null | undefined, accountId?: string | null): string | undefined;
export function privateImageSrc(source: string | null | undefined, accountId?: string | null): string | undefined {
  if (!source) return undefined;
  const path = privateImagePath(source);
  return path ? `/api/private-image?path=${encodeURIComponent(path)}${accountId ? `&account=${encodeURIComponent(accountId)}` : ""}` : source;
}
