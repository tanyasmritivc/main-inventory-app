/** @jest-environment jsdom */
import { accountRequest } from "@/lib/account-request";
import { getAccessSession } from "@/lib/session";
import { callbackParameters, completeCommerceCallback, prepareCommerceRedirect, readPendingCommerce, type ConnectResult } from "@/lib/commerce";

jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/session", () => ({ getAccessSession: jest.fn() }));
const inventoryId = "00000000-0000-0000-0000-000000000001";
const connectionId = "00000000-0000-0000-0000-000000000002";
const origin = "https://findez.test";
function start(provider: "shopify" | "amazon_seller" = "shopify"): ConnectResult {
  const query = new URLSearchParams({ state: "signed-state", redirect_uri: `${origin}/connect/${provider === "shopify" ? "shopify" : "amazon"}/callback` });
  return { connection: { id: connectionId, inventory_id: inventoryId, provider, external_account: provider === "shopify" ? "test-store.myshopify.com" : "SELLER123", region: "na", marketplace: "ATVPDKIKX0DER", status: "pending", scopes: [], last_sync_at: null },
    authorization_url: provider === "shopify" ? `https://test-store.myshopify.com/admin/oauth/authorize?${query}` : `https://sellercentral.amazon.com/apps/authorize/consent?${query}`, expires_in: 600 };
}
function prepare(provider: "shopify" | "amazon_seller" = "shopify") {
  return prepareCommerceRedirect(start(provider), "actor", inventoryId, origin, sessionStorage);
}
function browser(search = "?code=secret-code&state=signed-state&hmac=signature&shop=test-store.myshopify.com&timestamp=123&host=a%2Bb%252Fc") {
  return { location: { search, pathname: "/connect/shopify/callback" } as Location, history: { replaceState: jest.fn() } as unknown as History, sessionStorage };
}
beforeEach(() => {
  jest.clearAllMocks(); sessionStorage.clear();
  jest.mocked(getAccessSession).mockResolvedValue({ accountId: "actor", token: "findez-token" });
  jest.mocked(accountRequest).mockResolvedValue({ connection: { ...start().connection, status: "connected" } });
});

test("handoff stores account/inventory identity and state, never a code or token", () => {
  expect(prepare()).toContain("test-store.myshopify.com");
  expect(readPendingCommerce("shopify", "signed-state", sessionStorage)).toMatchObject({ accountId: "actor", connectionId, inventoryId });
  const stored = sessionStorage.getItem("findez.commerce.shopify.pending")!;
  expect(stored).not.toMatch(/token|secret-code|authorization_url/);
});

test.each([
  "https://evil.test/admin/oauth/authorize", "https://test-store.myshopify.com.evil.test/admin/oauth/authorize",
  "http://test-store.myshopify.com/admin/oauth/authorize", "https://user@test-store.myshopify.com/admin/oauth/authorize",
  "https://test-store.myshopify.com:444/admin/oauth/authorize", "https://test-store.myshopify.com/other",
])("rejects an unexpected authorization destination %s", (address) => {
  const result = start(); result.authorization_url = `${address}?${new URL(result.authorization_url!).searchParams}`;
  expect(() => prepareCommerceRedirect(result, "actor", inventoryId, origin, sessionStorage)).toThrow();
  expect(sessionStorage.length).toBe(0);
});

test("requires the callback to use the same origin/tab storage and exact provider path", () => {
  for (const callback of ["https://www.findez.test/connect/shopify/callback", `${origin}/connect/amazon/callback`, `${origin}/connect/shopify/callback?extra=1`]) {
    const result = start(), url = new URL(result.authorization_url!);
    url.searchParams.set("redirect_uri", callback); result.authorization_url = url.href;
    expect(() => prepareCommerceRedirect(result, "actor", inventoryId, origin, sessionStorage)).toThrow(/callback|Authorization/);
  }
});

test.each(["code", "state", "hmac", "shop", "host"])('rejects duplicate callback key "%s"', (key) => {
  expect(() => callbackParameters(`?state=one&code=two&${key}=three&${key}=four`)).toThrow(/invalid/);
});
test("decodes exactly once and keeps all signed Shopify fields without prototype mutation", () => {
  const params = callbackParameters("?state=ok&host=a%2Bb%252Fc&__proto__=value");
  expect(params.host).toBe("a+b%2Fc"); expect(params.__proto__).toBe("value"); expect(Object.getPrototypeOf(params)).toBeNull();
});
test("rejects oversized and incomplete responses", () => {
  expect(() => callbackParameters("?code=only")).toThrow(/incomplete/);
  expect(() => callbackParameters(`?state=ok&code=${"x".repeat(4097)}`)).toThrow(/invalid/);
  expect(() => callbackParameters(`?state=ok&${Array.from({ length: 20 }, (_, i) => `k${i}=v`).join("&")}`)).toThrow(/incomplete/);
});
test("strips credentials first, completes with the initiating actor, and consumes pending state", async () => {
  prepare(); const view = browser();
  jest.mocked(getAccessSession).mockImplementation(async () => {
    expect(view.history.replaceState).toHaveBeenCalledWith(null, "", "/connect/shopify/callback");
    return { accountId: "actor", token: "findez-token" };
  });
  await expect(completeCommerceCallback("shopify", view)).resolves.toBe(`/inventory/connect?inventory=${inventoryId}`);
  expect(accountRequest).toHaveBeenCalledWith("actor", `/commerce/connections/${connectionId}/complete`, { method: "POST", body: { parameters: {
    code: "secret-code", state: "signed-state", hmac: "signature", shop: "test-store.myshopify.com", timestamp: "123", host: "a+b%2Fc",
  } } });
  expect(sessionStorage.length).toBe(0);
  await expect(completeCommerceCallback("shopify", view)).rejects.toThrow(/another tab/);
  expect(accountRequest).toHaveBeenCalledTimes(1);
});
test.each([null, { accountId: "other-actor", token: "other-token" }])("never exchanges codes after sign-out/account change", async (session) => {
  prepare(); jest.mocked(getAccessSession).mockResolvedValue(session);
  await expect(completeCommerceCallback("shopify", browser())).rejects.toThrow(/account that started/);
  expect(accountRequest).not.toHaveBeenCalled(); expect(sessionStorage.length).toBe(0);
});
test("rejects wrong state, stale state and provider cancellation without an exchange", async () => {
  prepare(); await expect(completeCommerceCallback("shopify", browser("?state=other&code=code"))).rejects.toThrow(/another tab/);
  const key = "findez.commerce.shopify.pending";
  sessionStorage.setItem(key, JSON.stringify({ ...JSON.parse(sessionStorage.getItem(key)!), expiresAt: Date.now() - 1 }));
  await expect(completeCommerceCallback("shopify", browser())).rejects.toThrow(/expired/);
  prepare(); await expect(completeCommerceCallback("shopify", browser("?state=signed-state&error=access_denied"))).rejects.toThrow(/not completed/);
  expect(accountRequest).not.toHaveBeenCalled();
});
test("scrubs even malformed callbacks and does not retry an uncertain exchange", async () => {
  const malformed = browser("?state=a&state=b&code=secret");
  await expect(completeCommerceCallback("shopify", malformed)).rejects.toThrow();
  expect(malformed.history.replaceState).toHaveBeenCalled();
  prepare(); jest.mocked(accountRequest).mockRejectedValue(new Error("Network failure"));
  await expect(completeCommerceCallback("shopify", browser())).rejects.toThrow("Network failure");
  await expect(completeCommerceCallback("shopify", browser())).rejects.toThrow(/another tab/);
  expect(accountRequest).toHaveBeenCalledTimes(1);
});
test("Amazon uses the seller callback and preserves its provider fields", async () => {
  prepare("amazon_seller");
  jest.mocked(accountRequest).mockResolvedValue({ connection: { ...start("amazon_seller").connection, status: "connected" } });
  await expect(completeCommerceCallback("amazon_seller", browser("?state=signed-state&selling_partner_id=SELLER123&spapi_oauth_code=seller-code"))).resolves.toContain(inventoryId);
  expect(accountRequest).toHaveBeenCalledWith("actor", expect.any(String), { method: "POST", body: { parameters: { state: "signed-state", selling_partner_id: "SELLER123", spapi_oauth_code: "seller-code" } } });
});

test('organization OAuth preserves owner and returns to organization Connections', async () => {
  const scope = {scope_type:'organization' as const,organization_id:inventoryId};
  const result=start(); result.connection={...result.connection,inventory_id:null,...scope};
  prepareCommerceRedirect(result,'actor',scope,origin,sessionStorage);
  expect(readPendingCommerce('shopify','signed-state',sessionStorage).scope).toEqual(scope);
  jest.mocked(accountRequest).mockResolvedValue({connection:{...result.connection,status:'connected'}});
  expect(await completeCommerceCallback('shopify',browser())).toBe(`/settings/connections?organization=${inventoryId}`);
});
test('OAuth completion cannot silently switch a personal connection into an organization', async () => {
  const result=start(); result.connection={...result.connection,inventory_id:null,scope_type:'personal',organization_id:null};
  prepareCommerceRedirect(result,'actor',{scope_type:'personal'},origin,sessionStorage);
  jest.mocked(accountRequest).mockResolvedValue({connection:{...result.connection,status:'connected',scope_type:'organization',organization_id:inventoryId}});
  await expect(completeCommerceCallback('shopify',browser())).rejects.toThrow(/not confirmed/);
});
