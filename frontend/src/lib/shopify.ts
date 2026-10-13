import { apiRequest } from "./api";

export type ShopifyConnection = {
  connection_id: string;
  shop_domain: string;
  shop_name: string | null;
  status: "pending" | "connected" | "reconnect_required" | "disconnected" | "uninstalled";
  sync_status: "idle" | "queued" | "syncing" | "failed";
  last_attempt_at: string | null;
  last_success_at: string | null;
  error_code: string | null;
};
export type ShopifyStatus = {
  enabled: boolean;
  can_manage: boolean;
  pilot_shop: string | null;
  connections: ShopifyConnection[];
};
export type ShopifyVariant = {
  variant_gid: string;
  product_title: string;
  variant_title: string;
  product_status: string;
  options: { name: string; value: string }[];
  sku: string | null;
  barcodes: { value: string; type: string | null }[];
  image_url: string | null;
  tracked: boolean;
  synced_at: string;
  shopify_inventory: {
    location_gid: string;
    location_name: string;
    location_active: boolean;
    quantities: Record<string, number>;
    synced_at: string;
  }[];
};
export type ShopifyCatalog = { variants: ShopifyVariant[]; next_cursor: string | null };

function base(team: string) { return `/teams/${encodeURIComponent(team)}/shopify`; }
function options(token: string) { return { token, bindToToken: true }; }
export function getShopifyStatus(team: string, token: string) {
  return apiRequest<ShopifyStatus>(base(team), options(token));
}
export function authorizeShopify(team: string, token: string) {
  return apiRequest<{ authorization_url: string }>(`${base(team)}/authorize`, { ...options(token), method: "POST", credentials: "include" });
}
export function requestShopifySync(team: string, id: string, token: string) {
  return apiRequest<{ queued: boolean }>(`${base(team)}/${encodeURIComponent(id)}/sync`, { ...options(token), method: "POST" });
}
export function disconnectShopify(team: string, id: string, token: string) {
  return apiRequest<{ disconnected: boolean }>(`${base(team)}/${encodeURIComponent(id)}`, { ...options(token), method: "DELETE" });
}
export function getShopifyCatalog(team: string, id: string, token: string, after?: string) {
  return apiRequest<ShopifyCatalog>(`${base(team)}/${encodeURIComponent(id)}/catalog${after ? `?after=${encodeURIComponent(after)}` : ""}`, options(token));
}
export function trustedAuthorizationUrl(value: string, shop: string | null): string {
  const url = new URL(value);
  if (!shop || url.protocol !== "https:" || url.hostname !== shop || url.port || url.username || url.password || url.pathname !== "/admin/oauth/authorize") {
    throw new Error("Could not verify the Shopify authorization link.");
  }
  return url.href;
}
export function catalogImage(value: string | null) {
  try {
    const url = new URL(value ?? "");
    if (url.protocol === "https:" && !url.username && !url.password && !url.port &&
      (url.hostname === "cdn.shopify.com" || url.hostname.endsWith(".shopifycdn.com"))) return url.href;
  } catch { /* Unsupported URLs render the catalog placeholder. */ }
  return null;
}
