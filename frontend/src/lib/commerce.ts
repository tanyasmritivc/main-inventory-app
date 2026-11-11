import { accountRequest } from "@/lib/account-request";
import { getAccessSession } from "@/lib/session";

export type CommerceProvider = "shopify" | "amazon_seller" | "amazon_consumer";
export type OAuthProvider = Exclude<CommerceProvider, "amazon_consumer">;
export type CommerceConnection = {
  id: string; inventory_id: string; provider: CommerceProvider; external_account: string;
  region: string; marketplace: string; status: string; scopes: string[];
  last_sync_at: string | null;
};
export type CommerceCapabilities = { providers: { provider: CommerceProvider; configured: boolean }[];
  amazon_gmail?: { configured: boolean; mode: "gmail_oauth" } };
export type CommerceRecord = {
  kind: "catalog_variant" | "merchant_stock" | "sale_line" | "purchase_line";
  external_id: string; observed_at: string;
  data: { order_id?: string | null; ordered_at?: string | null; title: string; sku?: string | null; quantity?: number | null;
    available_quantity?: number | null; source_status: string; physically_verified: false };
};
export type CommerceRecords = { connection: CommerceConnection; records: CommerceRecord[]; next_offset: number | null };
export type ConnectResult = { connection: CommerceConnection; authorization_url: string | null; expires_in: number | null };
export type PendingCommerce = {
  accountId: string; inventoryId: string; connectionId: string; provider: OAuthProvider;
  state: string; expiresAt: number;
};
export const commercePath = (inventoryId: string) => `/inventory/connect?inventory=${encodeURIComponent(inventoryId)}`;
const pendingKey = (provider: OAuthProvider) => `findez.commerce.${provider}.pending`;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const providerLabel = (provider: CommerceProvider) => ({ shopify: "Shopify", amazon_seller: "Amazon seller", amazon_consumer: "Amazon purchases" })[provider];

/** Store only the short-lived handoff identity. Never persist OAuth codes or tokens. */
export function prepareCommerceRedirect(result: ConnectResult, accountId: string, inventoryId: string, origin: string, storage: Storage): string {
  const c = result.connection;
  if (c.provider === "amazon_consumer" || c.inventory_id !== inventoryId || !uuid.test(c.id) || !result.authorization_url) throw new Error("Could not prepare authorization. Refresh your connections and try again.");
  const url = new URL(result.authorization_url);
  const hosts: Record<string, string> = { na: "sellercentral.amazon.com", eu: "sellercentral-europe.amazon.com", fe: "sellercentral.amazon.co.jp" };
  const host = c.provider === "shopify" ? c.external_account : hosts[c.region];
  const path = c.provider === "shopify" ? "/admin/oauth/authorize" : "/apps/authorize/consent";
  if (url.protocol !== "https:" || url.host !== host || url.username || url.password || url.hash || url.pathname !== path ||
      (c.provider === "shopify" && !/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(host))) throw new Error("The provider authorization address is invalid.");
  const state = url.searchParams.get("state");
  if (!state || url.searchParams.getAll("state").length !== 1 || url.searchParams.getAll("redirect_uri").length !== 1) throw new Error("The authorization request is incomplete.");
  const callback = new URL(url.searchParams.get("redirect_uri")!);
  const segment = c.provider === "shopify" ? "shopify" : "amazon";
  if (callback.origin !== origin || callback.pathname !== `/connect/${segment}/callback` || callback.search || callback.hash) throw new Error("Authorization must return to this FindEZ website. Check the configured callback address before trying again.");
  if (!result.expires_in || result.expires_in > 600 || result.expires_in < 1) throw new Error("The authorization expiry is invalid.");
  const pending: PendingCommerce = { accountId, inventoryId, connectionId: c.id, provider: c.provider, state, expiresAt: Date.now() + result.expires_in * 1000 };
  storage.setItem(pendingKey(c.provider), JSON.stringify(pending));
  return url.href;
}

export function callbackParameters(search: string): Record<string, string> {
  if (search.length > 16000) throw new Error("The authorization response is invalid. Start again from Connections.");
  const result: Record<string, string> = Object.create(null);
  for (const [key, value] of new URLSearchParams(search)) {
    if (Object.hasOwn(result, key) || key.length > 100 || value.length > 4096) throw new Error("The authorization response is invalid. Start again from Connections.");
    result[key] = value;
  }
  if (Object.keys(result).length > 20 || !result.state) throw new Error("The authorization response is incomplete. Start again from Connections.");
  return result;
}

export function readPendingCommerce(provider: OAuthProvider, state: string, storage: Storage): PendingCommerce {
  let pending: PendingCommerce;
  try { pending = JSON.parse(storage.getItem(pendingKey(provider)) || "null"); }
  catch { throw new Error("This connection could not be restored. Start again from Connections."); }
  if (!pending || pending.provider !== provider || pending.state !== state || !uuid.test(pending.inventoryId) ||
      !uuid.test(pending.connectionId) || typeof pending.accountId !== "string" || !pending.accountId ||
      !Number.isFinite(pending.expiresAt) || pending.expiresAt <= Date.now() || pending.expiresAt > Date.now() + 600000) {
    throw new Error("This authorization expired or was started in another tab. Start again from Connections.");
  }
  return pending;
}

/** Called once per callback mount; strip credentials before any async work. */
export async function completeCommerceCallback(provider: OAuthProvider, browser: Pick<Window, "location" | "history" | "sessionStorage">): Promise<string> {
  const search = browser.location.search;
  browser.history.replaceState(null, "", browser.location.pathname);
  const parameters = callbackParameters(search);
  const pending = readPendingCommerce(provider, parameters.state, browser.sessionStorage);
  // A failed exchange is not safe to replay. The connections screen is the
  // recovery surface for both consumed state and a lost successful response.
  browser.sessionStorage.removeItem(pendingKey(provider));
  if (parameters.error || !(provider === "shopify" ? parameters.code : parameters.spapi_oauth_code)) throw new Error("Authorization was not completed. Return to Connections and try again.");
  const session = await getAccessSession();
  if (!session || session.accountId !== pending.accountId) throw new Error("Sign in to the FindEZ account that started this connection, then start again from Connections.");
  const result = await accountRequest<{ connection: CommerceConnection }>(pending.accountId, `/commerce/connections/${pending.connectionId}/complete`, { method: "POST", body: { parameters } });
  if (result.connection.status !== "connected" || result.connection.id !== pending.connectionId || result.connection.inventory_id !== pending.inventoryId || result.connection.provider !== provider) throw new Error("Connection was not confirmed. Check its status in Connections before trying again.");
  return commercePath(pending.inventoryId);
}
