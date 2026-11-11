/** @jest-environment jsdom */
import { StrictMode } from "react";
import { render, screen, fireEvent, waitFor, cleanup } from "@testing-library/react";
import { CommerceClient, InventoryCommerce } from "@/components/site/commerce-client";
import { CommerceCallbackClient } from "@/components/site/commerce-callback-client";
import { accountRequest } from "@/lib/account-request";
import { completeCommerceCallback } from "@/lib/commerce";
import { selectInventory, type InventorySelection } from "@/lib/inventory-selection";
import { useApiSession } from "@/lib/use-api-session";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn(), accountToken: jest.fn().mockResolvedValue("token") }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: jest.fn() }));
jest.mock("@/lib/commerce", () => ({ ...jest.requireActual("@/lib/commerce"), completeCommerceCallback: jest.fn() }));
jest.mock("@/components/site/commerce-client.module.css", () => Object.fromEntries(["page", "callback", "eyebrow", "grid", "card", "heading", "connection", "account", "actions", "primary", "danger", "error", "notice", "hint", "tableWrap"].map((key) => [key, key])));
const confirm = jest.fn();
jest.mock("@/components/site/app-dialog-provider", () => ({ useAppDialog: () => ({ confirmAction: confirm }) }));
const inventory = { inventory_id: "inventory", accountId: "actor", can_edit: true, name: "Workshop" } as InventorySelection;
const connection = { id: "connection", provider: "shopify", status: "connected", external_account: "example.myshopify.com", last_sync_at: null };
const capability = { providers: [{ provider: "shopify", configured: true }, { provider: "amazon_seller", configured: false }] };
beforeEach(() => {
  jest.clearAllMocks(); selectInventory(inventory); confirm.mockResolvedValue(true);
  jest.mocked(useApiSession).mockReturnValue({ accountId: "actor", loading: false, error: null } as ReturnType<typeof useApiSession>);
  jest.mocked(accountRequest).mockImplementation(async (_actor, path) => {
    if (path === "/commerce/capabilities") return capability;
    if (path.includes("/records")) return { connection, records: [], next_offset: null };
    if (path.endsWith("/sync")) return { record_count: 7 };
    return { connections: [connection] };
  });
});
afterEach(() => { cleanup(); selectInventory(null); });

test("settings-bound connections preserve the empty global context and report operation failures", async () => {
  selectInventory(null);
  render(<InventoryCommerce inventory={inventory} inventoryBinding={null} embedded />);
  await screen.findByText("example.myshopify.com");
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error("Sync unavailable"));
  fireEvent.click(screen.getByRole("button", { name: "Sync products and stock" }));
  expect((await screen.findByRole("alert")).textContent).toContain("Sync unavailable");
});

test("shows readiness honestly and only enables configured provider", async () => {
  render(<CommerceClient />);
  await screen.findByText("example.myshopify.com");
  expect((screen.getByRole("button", { name: "Connect Shopify" }) as HTMLButtonElement).disabled).toBe(false);
  expect((screen.getByRole("button", { name: "Connect Amazon seller" }) as HTMLButtonElement).disabled).toBe(true);
  expect(screen.getByText("Amazon seller connections are not enabled yet.")).toBeTruthy();
  expect(accountRequest).toHaveBeenCalledWith("actor", "/commerce/connections?inventory_id=inventory", {});
});
test("viewers and mismatched accounts cannot fetch commerce data", () => {
  selectInventory({ ...inventory, can_edit: false }); const view = render(<CommerceClient />);
  expect(screen.getByText(/editing access/)).toBeTruthy(); expect(accountRequest).not.toHaveBeenCalled();
  selectInventory({ ...inventory, accountId: "other" }); view.rerender(<CommerceClient />);
  expect(screen.getByRole("alert").textContent).toContain("current FindEZ account"); expect(accountRequest).not.toHaveBeenCalled();
});
test("sync sends only an explicit commerce resource and reports no stock mutation", async () => {
  render(<CommerceClient />); await screen.findByText("example.myshopify.com");
  fireEvent.click(screen.getByRole("button", { name: "Sync products and stock" }));
  await screen.findByText("Synced 7 source records. Physical inventory quantities are unchanged.");
  expect(accountRequest).toHaveBeenCalledWith("actor", "/commerce/connections/connection/sync", { method: "POST", body: { resource: "catalog" } });
  expect(jest.mocked(accountRequest).mock.calls.every((call) => call[1].startsWith("/commerce/"))).toBe(true);
});
test("cancelled delete makes no destructive request; disconnect retains records", async () => {
  render(<CommerceClient />); await screen.findByText("example.myshopify.com");
  confirm.mockResolvedValueOnce(false);
  fireEvent.click(screen.getByRole("button", { name: "Delete imported records" }));
  await waitFor(() => expect(confirm).toHaveBeenCalled());
  await waitFor(() => expect((screen.getByRole("button", { name: "Disconnect" }) as HTMLButtonElement).disabled).toBe(false));
  expect(jest.mocked(accountRequest).mock.calls.some((call) => call[2]?.method === "DELETE")).toBe(false);
  fireEvent.click(screen.getByRole("button", { name: "Disconnect" }));
  await waitFor(() => expect(accountRequest).toHaveBeenCalledWith("actor", "/commerce/connections/connection?purge=false", { method: "DELETE" }));
});
test("late results are discarded when the inventory changes", async () => {
  let finish!: (value: unknown) => void;
  jest.mocked(accountRequest).mockImplementation(() => new Promise((resolve) => { finish = resolve; }));
  const view = render(<CommerceClient />);
  selectInventory({ ...inventory, accountId: "other" }); view.rerender(<CommerceClient />);
  finish(capability);
  await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("current FindEZ account"));
  expect(accountRequest).toHaveBeenCalledTimes(1);
  expect(screen.queryByText("example.myshopify.com")).toBeNull();
});
test("callback Strict Mode replay exchanges once and exposes only the clean destination", async () => {
  jest.mocked(completeCommerceCallback).mockResolvedValue("/inventory/connect?inventory=inventory");
  render(<StrictMode><CommerceCallbackClient provider="shopify" /></StrictMode>);
  const link = await screen.findByRole("link", { name: "Open Connections" });
  expect(link.getAttribute("href")).toBe("/inventory/connect?inventory=inventory");
  expect(completeCommerceCallback).toHaveBeenCalledTimes(1);
});

test("records retain source status, unknown stock and pagination without becoming owned inventory", async () => {
  jest.mocked(accountRequest).mockImplementation(async (_actor, url) => {
    if (url === "/commerce/capabilities") return capability;
    if (url.includes("/records")) return { connection, next_offset: url.includes("offset=100") ? null : 100, records: [{
      kind: "merchant_stock", external_id: url.includes("offset=100") ? "second" : "first", observed_at: "2026-11-10T12:00:00Z",
      data: { title: url.includes("offset=100") ? "608 bearing" : "NEMA 17 motor", sku: "TEST-001", available_quantity: null, source_status: "untracked", physically_verified: false },
    }] };
    return { connections: [connection] };
  });
  const { container } = render(<CommerceClient />); await screen.findByText("example.myshopify.com");
  fireEvent.click(screen.getByRole("button", { name: "View records" }));
  await screen.findByText("NEMA 17 motor"); expect(screen.getByText("Unknown")).toBeTruthy(); expect(screen.getByText("Store stock")).toBeTruthy();
  fireEvent.click(screen.getByRole("button", { name: "Load more records" }));
  await screen.findByText("608 bearing"); expect(screen.getByText("NEMA 17 motor")).toBeTruthy();
  expect(screen.queryByRole("button", { name: "Load more records" })).toBeNull();
  // Optional, reproducible visual fixture from the real rendered component.
  // This writes only synthetic test content and cannot be used as live proof.
  if (process.env.FINDEZ_COMMERCE_PREVIEW) {
    const css = readFileSync(path.join(process.cwd(), "src/components/site/commerce-client.module.css"), "utf8");
    const theme = readFileSync(path.join(process.cwd(), "src/app/app-theme.css"), "utf8");
    for (const mode of ["light", "dark"]) {
      writeFileSync(`${process.env.FINDEZ_COMMERCE_PREVIEW}-${mode}.html`, `<!doctype html><html class="${mode}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FindEZ Connect UI fixture</title><style>${theme}\n${css}\n:root{--ink:#000;--text-secondary:#575757}.dark{--ink:#f4f4f2;--text-secondary:#a6a6ae}*{box-sizing:border-box}body{font:16px system-ui;margin:0;padding:32px}h1,h2,h3{margin:0}button,input,select{font:inherit}.page{margin:auto}body>p{font-size:12px;color:var(--text-secondary)}@media(max-width:650px){body{padding:20px}}</style></head><body><p>UI fixture / synthetic data / not a live connection</p>${container.innerHTML}</body></html>`);
    }
  }
});
