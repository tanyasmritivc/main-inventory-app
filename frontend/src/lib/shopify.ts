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
  edit_products?: boolean;
  edit_inventory?: boolean;
  edit_access?: "owner" | "editors";
  permission_revision?: number;
  granted_scopes?: string[];
  can_edit_products?: boolean;
  can_edit_inventory?: boolean;
};
export type ShopifyStatus = {
  enabled: boolean;
  can_manage: boolean;
  pilot_shop: string | null;
  connections: ShopifyConnection[];
  edits_enabled?: boolean;
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

export type ShopifyPermissions = {
  edit_products: boolean; edit_inventory: boolean; edit_access: "owner" | "editors"; expected_revision: number;
};
export type ShopifyAccessResult = {
  saved?: boolean; revision?: number; needs_authorization: boolean | null; revocation_pending: boolean; granted_scopes?: string[];
};
export type ShopifyEdit = {
  operation_id: string; kind: "product" | "inventory";
  state: "prepared" | "sending" | "succeeded" | "failed" | "unknown";
  intent: {product_gid?: string; changes?: Record<string,string|string[]>; inventory_item_gid?: string; location_gid?: string; delta?: number};
  snapshot: { title?: string; vendor?: string; productType?: string; tags?: string[]; available?: number; location_name?: string; checked_at: string; variant_title: string };
  receipt?: { message?: string; product?: Record<string,unknown>; adjustment?: Record<string,unknown> } | null;
  created_at?: string; dispatched_at?: string | null; reviewed_at?: string | null;
};
function storeBase(team:string,id:string) {return `${base(team)}/${encodeURIComponent(id)}`;}
export function saveShopifyPermissions(team:string,id:string,token:string,body:ShopifyPermissions) {
  return apiRequest<ShopifyAccessResult>(`${storeBase(team,id)}/permissions`,{...options(token),method:"PATCH",body:JSON.stringify(body)});
}
export function refreshShopifyPermissions(team:string,id:string,token:string) {
  return apiRequest<ShopifyAccessResult>(`${storeBase(team,id)}/permissions/refresh`,{...options(token),method:"POST"});
}
export function prepareShopifyEdit(team:string,id:string,token:string,body: {kind:"product"|"inventory";variant_gid:string;changes?:Record<string,string|string[]>;location_gid?:string;delta?:number}) {
  return apiRequest<ShopifyEdit>(`${storeBase(team,id)}/edits/prepare`,{...options(token),method:"POST",body:JSON.stringify(body)});
}
export function executeShopifyEdit(team:string,id:string,token:string,operation:string) {
  return apiRequest<ShopifyEdit>(`${storeBase(team,id)}/edits/${encodeURIComponent(operation)}/execute`,{...options(token),method:"POST",body:JSON.stringify({confirmed:true})});
}
export function getShopifyEdit(team:string,id:string,token:string,operation:string) {
  return apiRequest<ShopifyEdit>(`${storeBase(team,id)}/edits/${encodeURIComponent(operation)}`,options(token));
}
export function getShopifyEdits(team:string,id:string,token:string) {
  return apiRequest<{operations:ShopifyEdit[]}>(`${storeBase(team,id)}/edits`,options(token));
}
export function reviewUnknownShopifyEdit(team:string,id:string,token:string,operation:string) {
  return apiRequest<{reviewed:boolean;state:"unknown"}>(`${storeBase(team,id)}/edits/${encodeURIComponent(operation)}/review-unknown`,{...options(token),method:"POST",body:JSON.stringify({checked_in_shopify:true})});
}
