/** @jest-environment jsdom */
import React from "react";
import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { ShopifyPanel } from "@/components/site/shopify-panel";
import { AppDialogProvider } from "@/components/site/app-dialog-provider";
import * as connector from "@/lib/shopify";

jest.mock("@/lib/shopify", () => ({ ...jest.requireActual("@/lib/shopify"), getShopifyStatus: jest.fn(), getShopifyCatalog: jest.fn(), requestShopifySync: jest.fn(), disconnectShopify: jest.fn(), authorizeShopify: jest.fn(), getMerchantProgress: jest.fn() }));
const status = jest.mocked(connector.getShopifyStatus);
const catalog = jest.mocked(connector.getShopifyCatalog);
const sync = jest.mocked(connector.requestShopifySync);
const disconnect = jest.mocked(connector.disconnectShopify);
const authorize = jest.mocked(connector.authorizeShopify);
const store: connector.ShopifyConnection = { connection_id: "store-a", shop_domain: "pilot.myshopify.com", shop_name: "Pilot", status: "connected", sync_status: "idle", last_attempt_at: "2026-10-12T10:00:00Z", last_success_at: "2026-10-12T10:00:00Z", error_code: null };
const connected: connector.ShopifyStatus = { enabled: true, can_manage: true, pilot_shop: store.shop_domain, connections: [store] };
const variant: connector.ShopifyVariant = { variant_gid: "variant-1", product_title: "Hoodie", variant_title: "Black M", product_status: "ACTIVE", sku: "SKU-1", options: [], barcodes: [{ value: "0012", type: null }], image_url: null, tracked: true, synced_at: "2026-10-12T10:00:00Z", shopify_inventory: [{ location_gid: "loc-1", location_name: "Warehouse", location_active: true, quantities: { available: 24, on_hand: 30 }, synced_at: "2026-10-12T10:00:00Z" }] };

function panel(team = "team-a", token = "actor-a") { return <AppDialogProvider><ShopifyPanel key={`${team}:${token}`} teamId={team} token={token}/></AppDialogProvider>; }
beforeEach(() => { jest.resetAllMocks(); status.mockResolvedValue(connected); });

test("disabled connector adds no UI", async () => {
  status.mockResolvedValue({ enabled: false, can_manage: false, pilot_shop: null, connections: [] });
  const view = render(panel());
  await waitFor(() => expect(status).toHaveBeenCalledWith("team-a", "actor-a"));
  expect(view.container.textContent).toBe("");
});

test("catalog labels commerce records, variants, barcodes and separate quantity states", async () => {
  catalog.mockResolvedValue({ variants: [variant, { ...variant, variant_gid: "variant-2", tracked: false, variant_title: "Black L", shopify_inventory: [] }], next_cursor: null });
  render(panel());
  fireEvent.click(await screen.findByText("Preview catalog"));
  await screen.findAllByText("Hoodie");
  expect(screen.getByText(/24 available \/ 30 on hand/)).toBeTruthy();
  expect(screen.getByText(/Storage locations in FindEZ have not been confirmed/)).toBeTruthy();
  expect(screen.getByText("Shopify stock is not tracked.")).toBeTruthy();
  expect(screen.getAllByText("Barcodes: 0012")).toHaveLength(2);
});

test("employee can preview but cannot manage the store", async () => {
  status.mockResolvedValue({ ...connected, can_manage: false });
  render(panel());
  await screen.findByText("Preview catalog");
  expect(screen.queryByText("Disconnect")).toBeNull();
  expect(screen.queryByText("Sync now")).toBeNull();
});

test("sync requests are serialized and failed saves remain visible", async () => {
  let reject!: (reason: Error) => void;
  sync.mockImplementation(() => new Promise((_resolve, fail) => { reject = fail; }));
  render(panel());
  const button = await screen.findByText("Sync now");
  fireEvent.click(button); fireEvent.click(button);
  expect(sync).toHaveBeenCalledTimes(1);
  await act(async () => { reject(new Error("Sync could not be queued.")); });
  expect(await screen.findByRole("alert")).toBeTruthy();
});

test("disconnect requires confirmation and clears preview only after success", async () => {
  catalog.mockResolvedValue({ variants: [variant], next_cursor: null });
  disconnect.mockResolvedValue({ disconnected: true });
  render(panel());
  fireEvent.click(await screen.findByText("Preview catalog")); await screen.findByText("Hoodie");
  fireEvent.click(screen.getByText("Disconnect"));
  await screen.findByRole("dialog");
  expect(disconnect).not.toHaveBeenCalled();
  fireEvent.click(screen.getAllByText("Disconnect").at(-1)!);
  await waitFor(() => expect(disconnect).toHaveBeenCalledWith("team-a", "store-a", "actor-a"));
  await waitFor(() => expect(screen.queryByText("Hoodie")).toBeNull());
});

test("failed disconnect retains preview and shows retryable failure", async () => {
  catalog.mockResolvedValue({ variants: [variant], next_cursor: null });
  disconnect.mockRejectedValue(new Error("Store could not be disconnected."));
  render(panel());
  fireEvent.click(await screen.findByText("Preview catalog")); await screen.findByText("Hoodie");
  fireEvent.click(screen.getByText("Disconnect")); await screen.findByRole("dialog");
  fireEvent.click(screen.getAllByText("Disconnect").at(-1)!);
  await screen.findByRole("alert");
  expect(screen.getByText("Hoodie")).toBeTruthy();
});

test("page cursor is passed without losing already loaded variants", async () => {
  catalog.mockResolvedValueOnce({ variants: [variant], next_cursor: "next-page" }).mockResolvedValueOnce({ variants: [{ ...variant, variant_gid: "variant-2", variant_title: "Black L" }], next_cursor: null });
  render(panel()); fireEvent.click(await screen.findByText("Preview catalog"));
  fireEvent.click(await screen.findByText("Load more variants"));
  await screen.findByText("Black L / active");
  expect(catalog).toHaveBeenLastCalledWith("team-a", "store-a", "actor-a", "next-page");
  expect(screen.getAllByText("Hoodie")).toHaveLength(2);
});

test("Team/account switch rejects old catalog and status responses", async () => {
  let resolve!: (value: connector.ShopifyCatalog) => void;
  catalog.mockImplementation(() => new Promise(done => { resolve = done; }));
  const view = render(panel()); fireEvent.click(await screen.findByText("Preview catalog"));
  status.mockResolvedValue({ ...connected, connections: [], can_manage: false });
  view.rerender(panel("team-b", "actor-b"));
  await screen.findByText("The Team owner can connect this store.");
  await act(async () => { resolve({ variants: [variant], next_cursor: null }); });
  expect(screen.queryByText("Hoodie")).toBeNull();
  expect(status).toHaveBeenLastCalledWith("team-b", "actor-b");
});

test("authorization explains delegation and leaves failed connection visible", async () => {
  status.mockResolvedValue({ ...connected, connections: [] });
  authorize.mockRejectedValue(new Error("Could not connect this store."));
  render(panel()); fireEvent.click(await screen.findByText("Connect store"));
  expect((await screen.findByRole("dialog")).textContent).toContain("Team's members");
  expect(authorize).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText("Continue to Shopify"));
  await screen.findByRole("alert");
  expect(authorize).toHaveBeenCalledWith("team-a", "actor-a");
});

test("untrusted redirects and image URLs are rejected", () => {
  expect(() => connector.trustedAuthorizationUrl("https://evil.test/admin/oauth/authorize", store.shop_domain)).toThrow();
  expect(() => connector.trustedAuthorizationUrl("https://user:password@pilot.myshopify.com/admin/oauth/authorize", store.shop_domain)).toThrow();
  expect(connector.trustedAuthorizationUrl("https://pilot.myshopify.com/admin/oauth/authorize?state=test", store.shop_domain)).toContain("pilot.myshopify.com");
  expect(connector.catalogImage("javascript:alert(1)")).toBeNull();
  expect(connector.catalogImage("https://evil.test/private-image")).toBeNull();
  expect(connector.catalogImage("https://cdn.shopify.com/test.jpg")).toBe("https://cdn.shopify.com/test.jpg");
});

test.each([false,true])("merchant setup only mounts after its server capability is enabled (%s)", async enabled => {
  status.mockResolvedValue({...connected,migration_enabled:enabled});
  jest.mocked(connector.getMerchantProgress).mockResolvedValue({connection_id:"store-a",checked_at:"2026-10-13T10:00:00Z",can_confirm:false,space_count:0,import_complete:false,last_complete_sync:null,total_variants:0,confirmed_variants:0,unconfirmed_variants:0,older_confirmations:0,unconfirmed_sample:[],confirmed_example:null});
  render(<AppDialogProvider><ShopifyPanel teamId="team-a" token="actor-a" onOpenMemory={()=>{}} onOpenSpaces={()=>{}}/></AppDialogProvider>);
  await screen.findByText("Preview catalog");
  if(enabled) {await screen.findByText(/No variants are available yet/);expect(connector.getMerchantProgress).toHaveBeenCalledWith("team-a","store-a","actor-a");}
  else {expect(screen.queryByText("Set up your stockroom")).toBeNull();expect(connector.getMerchantProgress).not.toHaveBeenCalled();}
});
