"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Package, RefreshCw, ShoppingBag } from "lucide-react";
import { useAppDialog } from "./app-dialog-provider";
import { userFacingError } from "@/lib/user-facing-error";
import {
  ShopifyCatalog, ShopifyConnection, ShopifyStatus, authorizeShopify, catalogImage,
  disconnectShopify, getShopifyCatalog, getShopifyStatus, requestShopifySync, trustedAuthorizationUrl,
} from "@/lib/shopify";
import styles from "./shopify-panel.module.css";

function date(value: string | null) { return value ? new Date(value).toLocaleString() : "Not yet"; }
const labels = { pending: "Authorization incomplete", connected: "Connected", reconnect_required: "Reconnect required", disconnected: "Disconnected", uninstalled: "Uninstalled" };

// Parent keys this by account token + Team so neither cached results nor pending
// actions survive a scope switch. Every late response also checks this mount.
export function ShopifyPanel({ teamId, token }: { teamId: string; token: string }) {
  const [status, setStatus] = useState<ShopifyStatus | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [catalog, setCatalog] = useState<(ShopifyCatalog & { connectionId: string }) | null>(null);
  const alive = useRef(true);
  const pending = useRef(false);
  const revision = useRef(0);
  const { confirmAction } = useAppDialog();

  const refresh = useCallback(async () => {
    const request = ++revision.current;
    try {
      const next = await getShopifyStatus(teamId, token);
      if (!alive.current || request !== revision.current) return;
      setStatus(next);
      setError(null);
      if (next.connections.every(c => c.status === "disconnected" || c.status === "uninstalled")) setCatalog(null);
    } catch (reason) {
      if (alive.current && request === revision.current) { setStatus(null); setCatalog(null); setError(userFacingError(reason, "Could not load the Shopify connection.")); }
    }
  }, [teamId, token]);

  useEffect(() => {
    alive.current = true;
    void refresh();
    const timer = window.setInterval(() => { if (!document.hidden && !pending.current) void refresh(); }, 5000);
    return () => { alive.current = false; window.clearInterval(timer); };
  }, [refresh]);

  async function action(run: () => Promise<void>) {
    if (pending.current) return;
    revision.current++;
    pending.current = true; setBusy(true); setError(null);
    try { await run(); }
    catch (reason) { if (alive.current) setError(userFacingError(reason, "Could not complete this Shopify action.")); }
    finally { pending.current = false; if (alive.current) setBusy(false); }
  }

  function connect() {
    void action(async () => {
      const approved = await confirmAction({ title: "Connect Shopify?", message: "This Team's members will be able to view the store's product catalog and Shopify stock records. FindEZ receives read-only access to products and inventory.", confirmLabel: "Continue to Shopify" });
      if (!approved || !alive.current) return;
      const response = await authorizeShopify(teamId, token);
      if (alive.current) window.location.assign(trustedAuthorizationUrl(response.authorization_url, status?.pilot_shop ?? null));
    });
  }

  function preview(store: ShopifyConnection, more = false) {
    void action(async () => {
      const next = await getShopifyCatalog(teamId, store.connection_id, token, more ? catalog?.next_cursor ?? undefined : undefined);
      if (alive.current) setCatalog({ ...next, connectionId: store.connection_id,
        variants: more && catalog?.connectionId === store.connection_id ? [...catalog.variants, ...next.variants] : next.variants });
    });
  }

  if (status && !status.enabled) return null;
  if (!status) return error ? <div className="notice-error" role="alert">{error}<button className="product-button" onClick={() => { setError(null); void refresh(); }}>Retry connection</button></div> : null;

  return <section className={`product-card ${styles.panel}`} aria-label="Shopify connection">
    <div className={styles.heading}><span className={styles.mark}><ShoppingBag size={21}/></span><div><h3>Shopify</h3><p>Bring your existing catalog into FindEZ.</p></div><span className="status-pill">Read-only</span></div>
    {error && <div className="notice-error" role="alert">{error}</div>}
    {status.connections.length === 0 && <div className={styles.setup}><p>Connect {status.pilot_shop}. Your catalog and commerce stock stay separate from your physical inventory.</p>{status.can_manage ? <button className="product-button primary" disabled={busy} onClick={connect}>Connect store</button> : <p>The Team owner can connect this store.</p>}</div>}
    {status.connections.map(store => <div key={store.connection_id} className={styles.store}>
      <div className={styles.storeTitle}><strong>{store.shop_name || store.shop_domain}</strong><span>{labels[store.status]}</span></div>
      <dl className={styles.times}><div><dt>Last complete sync</dt><dd>{date(store.last_success_at)}</dd></div><div><dt>Last attempt</dt><dd>{date(store.last_attempt_at)}</dd></div></dl>
      {(store.sync_status === "queued" || store.sync_status === "syncing") && <p role="status">Catalog sync {store.sync_status === "queued" ? "queued" : "in progress"}. Preview may be incomplete.</p>}
      {store.error_code && <p role="alert">{store.status === "reconnect_required" ? "Shopify access needs to be renewed." : store.sync_status === "failed" ? "Sync stopped after repeated failures. Retry to sync again." : "Sync has not completed. FindEZ will retry."} Saved records may be out of date.</p>}
      <div className="product-actions">
        {(store.status === "connected" || store.status === "reconnect_required" || store.status === "pending") && <button className="product-button" disabled={busy} onClick={() => preview(store)}>Preview catalog</button>}
        {status.can_manage && store.status === "connected" && <button className="product-button" disabled={busy} onClick={() => void action(async () => { const result = await requestShopifySync(teamId, store.connection_id, token); if (!result.queued) throw new Error("Sync was not queued."); if (alive.current) await refresh(); })}><RefreshCw size={14}/>Sync now</button>}
        {status.can_manage && store.status !== "connected" && <button className="product-button primary" disabled={busy} onClick={connect}>Reconnect</button>}
        {status.can_manage && store.status !== "disconnected" && store.status !== "uninstalled" && <button className="product-button" disabled={busy} onClick={() => void action(async () => {
          const approved = await confirmAction({ title: "Disconnect Shopify?", message: "FindEZ will stop syncing and remove its imported catalog and credentials. Your saved physical items and Spaces stay in FindEZ.", confirmLabel: "Disconnect", danger: true });
          if (!approved || !alive.current) return;
          const result = await disconnectShopify(teamId, store.connection_id, token);
          if (!result.disconnected) throw new Error("Disconnection was not confirmed.");
          if (alive.current) { setCatalog(null); await refresh(); }
        })}>Disconnect</button>}
      </div>
      {catalog?.connectionId === store.connection_id && <div className={styles.catalog}>
        <div><h4>Catalog preview</h4><p>Shopify records. Storage locations in FindEZ have not been confirmed here.</p></div>
        {catalog.variants.length === 0 && <p>{store.last_success_at ? "No current variants in this catalog." : "No variants imported yet."}</p>}
        {catalog.variants.map(variant => <article className={styles.variant} key={variant.variant_gid}>
          <span className={styles.image}>{catalogImage(variant.image_url) ?
            // Catalog evidence only; restrict remote hosts and send no referrer.
            // eslint-disable-next-line @next/next/no-img-element
            <img alt="" src={catalogImage(variant.image_url)!} referrerPolicy="no-referrer" loading="lazy"/> : <Package size={22}/>}</span>
          <div><strong>{variant.product_title}</strong><p>{variant.variant_title === "Default Title" ? "Standard variant" : variant.variant_title} / {variant.product_status.toLowerCase()}</p>
            <p>SKU: {variant.sku || "Not supplied"}</p>{variant.barcodes.length > 0 && <p>Barcodes: {variant.barcodes.map(b => b.value).join(", ")}</p>}
            {!variant.tracked ? <p>Shopify stock is not tracked.</p> : variant.shopify_inventory.length === 0 ? <p>No Shopify quantity snapshot available.</p> : variant.shopify_inventory.map(level => <p key={level.location_gid}>{level.location_name}{level.location_active ? "" : " (inactive)"}: {level.quantities.available ?? "Unknown"} available / {level.quantities.on_hand ?? "Unknown"} on hand. Synced {date(level.synced_at)}.</p>)}
          </div>
        </article>)}
        {catalog.next_cursor && <button className="product-button" disabled={busy} onClick={() => preview(store, true)}>Load more variants</button>}
      </div>}
    </div>)}
  </section>;
}
