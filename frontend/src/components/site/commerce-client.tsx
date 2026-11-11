"use client";

import { FormEvent, useCallback, useEffect, useRef, useState } from "react";
import { accountRequest, accountToken } from "@/lib/account-request";
import { activeInventory, assertInventory, type InventorySelection } from "@/lib/inventory-selection";
import { useApiSession } from "@/lib/use-api-session";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { ApiError } from "@/lib/api";
import { prepareCommerceRedirect, providerLabel, type CommerceCapabilities, type CommerceConnection, type CommerceRecords, type ConnectResult, type OAuthProvider } from "@/lib/commerce";
import styles from "./commerce-client.module.css";
import { PurchaseEmailClient } from "./purchase-email-client";

const marketplaces = [
  ["na", "ATVPDKIKX0DER", "United States"], ["na", "A2EUQ1WTGCTBG2", "Canada"], ["na", "A1AM78C64UM0Y8", "Mexico"],
  ["eu", "A1F83G8C2ARO7P", "United Kingdom"], ["eu", "A1PA6795UKMFR9", "Germany"], ["eu", "A13V1IB3VIYZZH", "France"],
  ["eu", "APJ6JRA9NG5V4", "Italy"], ["eu", "A1RKKUPIHCS9HS", "Spain"],
  ["fe", "A1VC38T7YXB528", "Japan"], ["fe", "A39IBJ37TRP1C6", "Australia"], ["fe", "A19VAU5U5O7RUS", "Singapore"],
];
const kindLabels = { catalog_variant: "Catalog product", merchant_stock: "Store stock", sale_line: "Sale", purchase_line: "Purchase record" };
const date = (value: string | null) => value ? new Date(value).toLocaleString() : "Not synced yet";
function errorMessage(reason: unknown) {
  if (reason instanceof ApiError && [404, 503].includes(reason.status)) return "Connections are not available right now. Your existing inventory is unchanged.";
  return reason instanceof Error ? reason.message : "The request could not be completed. Refresh Connections to check its status.";
}

export function CommerceClient() {
  const { accountId, loading, error } = useApiSession();
  const inventory = activeInventory();
  if (loading) return <p role="status">Loading Connections...</p>;
  if (error || !accountId || !inventory || inventory.accountId !== accountId) return <p role="alert">Choose an inventory in your current FindEZ account to manage connections.</p>;
  if (!inventory.can_edit) return <p>You need editing access to manage connections for this inventory.</p>;
  return <InventoryCommerce key={`${accountId}:${inventory.inventory_id}`} inventory={inventory} />;
}

function InventoryCommerce({ inventory }: { inventory: InventorySelection }) {
  const { confirmAction } = useAppDialog();
  const [capabilities, setCapabilities] = useState<CommerceCapabilities | null>(null);
  const [connections, setConnections] = useState<CommerceConnection[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [shop, setShop] = useState("");
  const [seller, setSeller] = useState("");
  const [marketplace, setMarketplace] = useState(marketplaces[0][1]);
  const [records, setRecords] = useState<CommerceRecords | null>(null);
  const lock = useRef(false), live = useRef(false), generation = useRef(0);
  const current = useCallback(() => {
    if (!live.current) throw new Error("This page is no longer active.");
    assertInventory(inventory);
  }, [inventory]);
  const request = useCallback(async <T,>(path: string, options: Parameters<typeof accountRequest>[2] = {}) => {
    current();
    const value = await accountRequest<T>(inventory.accountId, path, options);
    current();
    return value;
  }, [inventory, current]);
  const reload = useCallback(async () => {
    const version = ++generation.current;
    setLoading(true);
    try {
      const caps = await request<CommerceCapabilities>("/commerce/capabilities");
      const result = caps.providers.some((p) => p.configured)
        ? await request<{ connections: CommerceConnection[] }>(`/commerce/connections?inventory_id=${encodeURIComponent(inventory.inventory_id)}`)
        : { connections: [] };
      if (version === generation.current) { setCapabilities(caps); setConnections(result.connections); }
    } finally { if (live.current && version === generation.current) setLoading(false); }
  }, [request, inventory.inventory_id]);
  useEffect(() => {
    let active = true;
    live.current = true;
    void reload().catch((reason) => { if (active) setError(errorMessage(reason)); });
    return () => { active = false; live.current = false; };
  }, [reload]);

  async function perform(action: () => Promise<void>) {
    if (lock.current) return;
    lock.current = true; setBusy(true); setError(""); setNotice("");
    try { current(); await action(); }
    catch (reason) { if (live.current && activeInventory() === inventory) setError(errorMessage(reason)); }
    finally { lock.current = false; if (live.current) setBusy(false); }
  }
  function connect(event: FormEvent, provider: OAuthProvider) {
    event.preventDefault();
    void perform(async () => {
      // Confirm storage works before creating a durable pending connection.
      sessionStorage.setItem("findez.commerce.check", "1"); sessionStorage.removeItem("findez.commerce.check");
      const market = marketplaces.find((entry) => entry[1] === marketplace)!;
      const result = await request<ConnectResult>("/commerce/connections", { method: "POST", body: {
        inventory_id: inventory.inventory_id, provider, external_account: provider === "shopify" ? shop.trim().toLowerCase() : seller.trim(),
        ...(provider === "amazon_seller" ? { region: market[0], marketplace: market[1] } : {}),
      } });
      // Retain the pending row on this page if navigation preparation fails.
      setConnections((values) => [...values, result.connection]);
      await accountToken(inventory.accountId); current();
      const url = prepareCommerceRedirect(result, inventory.accountId, inventory.inventory_id, window.location.origin, sessionStorage);
      window.location.assign(url);
    });
  }
  async function readRecords(connection: CommerceConnection, offset = 0) {
    const result = await request<CommerceRecords>(`/commerce/connections/${connection.id}/records?offset=${offset}&limit=100`);
    setRecords((previous) => offset && previous?.connection.id === connection.id
      ? { ...result, records: [...previous.records, ...result.records] } : result);
  }
  function sync(connection: CommerceConnection, resource: "catalog" | "stock" | "orders") {
    void perform(async () => {
      const result = await request<{ record_count: number }>(`/commerce/connections/${connection.id}/sync`, { method: "POST", body: { resource } });
      setNotice(`Synced ${result.record_count} source records. Physical inventory quantities are unchanged.`);
      setRecords(null);
      await reload();
    });
  }
  function disconnect(connection: CommerceConnection, purge: boolean) {
    void perform(async () => {
      const accepted = await confirmAction({ title: purge ? "Delete imported records?" : "Disconnect account?",
        message: purge ? "This removes this connection and its imported records from FindEZ permanently. Physical inventory is unchanged." : "FindEZ will stop using this connection. Imported records remain as historical evidence. You can also revoke access in Shopify or Amazon.",
        confirmLabel: purge ? "Delete imported records" : "Disconnect", danger: true });
      if (!accepted) return;
      await request(`/commerce/connections/${connection.id}?purge=${purge}`, { method: "DELETE" });
      setRecords(null); await reload();
      setNotice(purge ? "Connection and imported records deleted." : "Disconnected. Provider access can also be revoked in Shopify or Amazon.");
    });
  }
  const configured = (provider: OAuthProvider) => capabilities?.providers.some((entry) => entry.provider === provider && entry.configured) ?? false;
  return <div className={styles.page}>
    <header><p className={styles.eyebrow}>FindEZ Connect</p><h1>Connections</h1>
      <p>Bring purchases and store information into <strong>{inventory.name}</strong>. Connected data is private to your FindEZ account.</p>
      <p>Store stock and purchase records are separate from physically verified inventory.</p>
    </header>
    {error && <p className={styles.error} role="alert">{error}</p>}
    {notice && <p className={styles.notice} role="status">{notice}</p>}
    {loading && <p role="status">Loading connections...</p>}
    <PurchaseEmailClient accountId={inventory.accountId} inventoryId={inventory.inventory_id} configured={capabilities?.amazon_gmail?.configured ?? false}
      available={!!capabilities?.amazon_gmail} request={request} />
    <div className={styles.grid}>
      <section className={styles.card}><h2>Shopify store</h2><p>Read your store&apos;s product catalog, available stock, and recent sales.</p>
        {!loading && !configured("shopify") && <p className={styles.hint}>Shopify connections are not enabled yet.</p>}
        <form onSubmit={(event) => connect(event, "shopify")}><label htmlFor="commerce-shop">Store domain</label>
          <input id="commerce-shop" value={shop} onChange={(event) => setShop(event.target.value)} placeholder="your-store.myshopify.com" required pattern="[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com" maxLength={200} disabled={busy || loading || !configured("shopify")} autoCapitalize="none" spellCheck={false} />
          <button className={styles.primary} disabled={busy || loading || !configured("shopify")}>Connect Shopify</button>
        </form></section>
      <section className={styles.card}><h2>Amazon seller</h2><p>Read recent seller orders and stock fulfilled by Amazon. Personal shopping accounts are separate.</p>
        {!loading && !configured("amazon_seller") && <p className={styles.hint}>Amazon seller connections are not enabled yet.</p>}
        <form onSubmit={(event) => connect(event, "amazon_seller")}><label htmlFor="commerce-seller">Seller ID</label>
          <input id="commerce-seller" value={seller} onChange={(event) => setSeller(event.target.value)} required pattern="[A-Z0-9]{5,32}" maxLength={32} disabled={busy || loading || !configured("amazon_seller")} autoCapitalize="characters" spellCheck={false} />
          <label htmlFor="commerce-market">Marketplace</label><select id="commerce-market" value={marketplace} onChange={(event) => setMarketplace(event.target.value)} disabled={busy || loading || !configured("amazon_seller")}>{marketplaces.map((entry) => <option key={entry[1]} value={entry[1]}>{entry[2]}</option>)}</select>
          <button className={styles.primary} disabled={busy || loading || !configured("amazon_seller")}>Connect Amazon seller</button>
        </form></section>
    </div>
    <section className={styles.card}><div className={styles.heading}><h2>Your connections</h2><button disabled={busy || loading} onClick={() => void perform(reload)}>Refresh</button></div>
      {!loading && !connections.length && <p>No connections for this inventory yet.</p>}
      {connections.map((connection) => <article key={connection.id} className={styles.connection}>
        <h3>{providerLabel(connection.provider)}</h3><p className={styles.account}>{connection.provider === "amazon_consumer" ? "Personal purchase import" : connection.external_account}</p>
        <p><strong>{connection.status === "pending" ? "Awaiting authorization" : connection.status === "authorizing" ? "Checking authorization" : connection.status === "connected" ? "Connected" : "Disconnected"}</strong> / {date(connection.last_sync_at)}</p>
        {connection.status === "disconnected" && <p>Saved records are historical. They do not show current availability.</p>}
        {(connection.status === "pending" || connection.status === "authorizing") && <p>If authorization was interrupted, refresh to check its status. Disconnect this entry before starting again.</p>}
        <div className={styles.actions}>
          {connection.status === "connected" && connection.provider !== "amazon_consumer" && <>
            <button disabled={busy || loading || !configured(connection.provider)} onClick={() => sync(connection, connection.provider === "shopify" ? "catalog" : "stock")}>{connection.provider === "shopify" ? "Sync products and stock" : "Sync FBA stock"}</button>
            <button disabled={busy || loading || !configured(connection.provider)} onClick={() => sync(connection, "orders")}>Sync orders / last 30 days</button>
          </>}
          <button disabled={busy || loading} onClick={() => void perform(() => readRecords(connection))}>View records</button>
          {connection.status !== "disconnected" && <button disabled={busy || loading} onClick={() => disconnect(connection, false)}>Disconnect</button>}
          <button className={styles.danger} disabled={busy || loading} onClick={() => disconnect(connection, true)}>Delete imported records</button>
        </div>
      </article>)}
    </section>
    {busy && <p role="status">Working on your connection...</p>}
    {records && <section className={styles.card} aria-label="Imported records"><h2>{providerLabel(records.connection.provider)} records</h2>
      <p>Source observations, not a physical stock count. Orders cover only the periods you have synced.</p>
      {records.connection.status === "disconnected" && <p>Disconnected: these records are historical.</p>}
      {!records.records.length ? <p>No records yet. Run a sync to bring them into FindEZ.</p> : <div className={styles.tableWrap}><table>
        <thead><tr><th>Item</th><th>Source</th><th>Quantity</th><th>Status</th><th>Observed</th></tr></thead>
        <tbody>{records.records.map((record) => <tr key={`${record.kind}:${record.external_id}`}>
          <td>{record.data.title}<small>{record.data.sku}</small></td><td>{kindLabels[record.kind]}</td>
          <td>{record.kind === "merchant_stock" ? (record.data.available_quantity ?? "Unknown") : (record.data.quantity ?? "Not a stock count")}{record.kind === "merchant_stock" && <small>Available at source</small>}</td>
          <td>{record.data.source_status}</td><td>{date(record.observed_at)}</td>
        </tr>)}</tbody>
      </table></div>}
      {records.next_offset !== null && <button disabled={busy} onClick={() => void perform(() => readRecords(records.connection, records.next_offset!))}>Load more records</button>}
    </section>}
  </div>;
}
