"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { accountRequest } from "@/lib/account-request";
import { scopeQuery, type ConnectionScope } from "@/lib/commerce";
import styles from "./purchase-library.module.css";

type Order = { order_id: string; ordered_at: string | null; quantity: number; source_status: string; connection_status: string };
type Product = { key: string; title: string; asin: string | null; ordered_units: number; excluded_units: number; order_count: number; last_ordered_at: string; orders: Order[]; history_truncated: boolean };
type Library = { summary: { products: number; orders: number; records: number }; products: Product[]; matched_products: number; next_offset: number | null; complete: boolean };
type Check = { query: string; result: string; purchase_matches: Product[]; purchase_match_basis: string; inventory_matches: { name: string; quantity: number | null; location: string | null; inventory_name: string; workspace_name: string }[]; suggestions: string[]; purchases_complete: boolean; inventory_match_count: number; purchase_match_count: number };
type Request = <T>(path: string, options?: Parameters<typeof accountRequest>[2]) => Promise<T>;
const date = (value: string | null) => value ? new Date(value).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric", timeZone: "UTC" }) : "Date unknown";
const errorText = (reason: unknown) => reason instanceof Error ? reason.message : "Could not load these records. Try again.";

function ProductDetails({ product, onCheck }: { product: Product; onCheck?: (query: string) => void }) {
  return <article className={styles.product}>
    <div className={styles.productTop}><div><h3>{product.title}</h3><p>{product.asin ? `ASIN ${product.asin} · ` : ""}Last ordered {date(product.last_ordered_at)}</p></div>
      <span className={styles.badge}>Ownership unconfirmed</span></div>
    <div className={styles.productStats}><span><strong>{product.ordered_units}</strong> ordered units</span><span><strong>{product.order_count}</strong> {product.order_count === 1 ? "order" : "orders"}</span>{product.excluded_units > 0 && <span>{product.excluded_units} cancelled or returned units excluded</span>}</div>
    <details><summary>View order history</summary><div className={styles.orders}>{product.orders.map((order, index) => <div key={`${order.order_id}:${index}`}>
      <span>{date(order.ordered_at)}<small>Order {order.order_id}</small></span><span>{order.quantity} units<small>{order.source_status}{order.connection_status === "disconnected" ? " · Disconnected source" : ""}</small></span>
    </div>)}</div>{product.history_truncated && <p>Showing the latest 20 matching order lines for this product.</p>}</details>
    {onCheck && <button type="button" className={styles.textButton} onClick={() => onCheck(product.asin || product.title)}>Check against my inventory →</button>}
  </article>;
}

export function PurchaseLibrary({ scope, request }: { scope: ConnectionScope; request: Request }) {
  const [library, setLibrary] = useState<Library | null>(null);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("all");
  const [applied, setApplied] = useState({ query: "", status: "all" });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [buyQuery, setBuyQuery] = useState("");
  const [checking, setChecking] = useState(false);
  const [check, setCheck] = useState<Check | null>(null);
  const [checkError, setCheckError] = useState("");
  const alive = useRef(false), readVersion = useRef(0), checkVersion = useRef(0);
  const checkPanel = useRef<HTMLElement>(null);
  const destination = scopeQuery(scope);
  useEffect(() => {
    alive.current = true; readVersion.current++; checkVersion.current++;
    let active = true;
    setLibrary(null); setCheck(null); setLoading(true); setError("");
    request<Library>(`/commerce/purchases?${destination}`).then(value => { if (active) setLibrary(value); })
      .catch(reason => { if (active) setError(errorText(reason)); }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; alive.current = false; };
  }, [request, destination]);

  async function load(offset = 0) {
    const version = ++readVersion.current;
    const filters = offset ? applied : { query, status };
    setLoading(true); setError("");
    if (!offset) { setApplied(filters); setLibrary(null); }
    try {
      const params = new URLSearchParams({ query: filters.query, status: filters.status, offset: String(offset) });
      const result = await request<Library>(`/commerce/purchases?${destination}&${params}`);
      if (alive.current && version === readVersion.current) setLibrary(previous => offset && previous ? { ...result, products: [...previous.products, ...result.products] } : result);
    } catch (reason) { if (alive.current && version === readVersion.current) setError(errorText(reason)); }
    finally { if (alive.current && version === readVersion.current) setLoading(false); }
  }
  async function runCheck(value: string) {
    const version = ++checkVersion.current;
    setBuyQuery(value); setChecking(true); setCheck(null); setCheckError("");
    checkPanel.current?.scrollIntoView({ block: "nearest" });
    try {
      const result = await request<Check>("/commerce/purchase-check", { method: "POST", body: { ...scope, query: value.trim() } });
      if (alive.current && version === checkVersion.current) setCheck(result);
    } catch (reason) { if (alive.current && version === checkVersion.current) setCheckError(errorText(reason)); }
    finally { if (alive.current && version === checkVersion.current) setChecking(false); }
  }
  function submitCheck(event: FormEvent) { event.preventDefault(); if (!checking) void runCheck(buyQuery); }

  return <div className={styles.library}>
    <section ref={checkPanel} className={styles.checkPanel} aria-labelledby="purchase-check-heading">
      <p className={styles.eyebrow}>Before you buy</p><h2 id="purchase-check-heading">Do you already have it?</h2>
      <p>Check a product against your saved purchases and inventory before ordering it again.</p>
      <form onSubmit={submitCheck}><label htmlFor="purchase-check-query">Product name, ASIN or full Amazon product link</label><div className={styles.searchRow}>
        <input id="purchase-check-query" value={buyQuery} onChange={event => setBuyQuery(event.target.value)} placeholder="Try a product name or paste its Amazon link" required minLength={2} maxLength={1000} disabled={checking} />
        <button disabled={checking || buyQuery.trim().length < 2}>{checking ? "Checking..." : "Check before buying"}</button>
      </div></form>
      {checking && <p role="status">Checking saved purchases and recorded inventory...</p>}
      {checkError && <p className={styles.error} role="alert">{checkError}</p>}
      {check && <div className={styles.result} aria-live="polite"><h3>{check.result === "review_before_buying" ? "You may already have this" : check.result === "history_only" ? "Purchase history found, ownership unconfirmed" : check.result === "recorded_zero_stock" ? "Matching inventory has zero recorded stock" : "No match in the checked records"}</h3>
        <p>Results for <strong>{check.query}</strong>. {check.purchase_match_basis === "exact_asin" ? "Purchase records match this ASIN." : "Product names are possible matches; check the exact model."}</p>
        {check.inventory_matches.length > 0 && <><h4>Recorded inventory</h4><ul className={styles.inventory}>{check.inventory_matches.map((item, index) => <li key={index}><strong>{item.name}</strong><span>{item.quantity ?? "Unknown"} recorded · {[item.location, item.inventory_name, item.workspace_name].filter(Boolean).join(" / ")}</span></li>)}</ul><p>Recorded quantities may include items allocated to projects. Confirm what is available.</p></>}
        {check.purchase_matches.length > 0 && <><h4>Previous purchases</h4>{check.purchase_matches.map(product => <ProductDetails key={product.key} product={product} />)}</>}
        <ul className={styles.suggestions}>{check.suggestions.map(suggestion => <li key={suggestion}>{suggestion}</li>)}</ul>
        {!check.purchases_complete && <p>Purchase results are limited. Narrow your search or review the purchase library below.</p>}
        <p className={styles.note}>Checks cover saved records, not your live Amazon account or cart. Inventory search is limited; no match does not mean you do not own it.</p>
        <Link href={scope.scope_type === "organization" ? `/worlds/${scope.organization_id}` : "/worlds/personal"}>Ask FIND what you can reuse →</Link>
      </div>}
    </section>

    <section className={styles.history} aria-labelledby="purchase-library-heading"><p className={styles.eyebrow}>Your purchase library</p><h2 id="purchase-library-heading">Past purchases, organized</h2>
      <p>Products are grouped across orders. Open any product to see when and how much you ordered.</p>
      {library && <div className={styles.stats}><div><strong>{library.summary.products}</strong><span>products</span></div><div><strong>{library.summary.orders}</strong><span>orders</span></div><div><strong>{library.summary.records}</strong><span>imported order lines</span></div></div>}
      <form onSubmit={event => { event.preventDefault(); void load(); }}><div className={styles.filters}><div><label htmlFor="purchase-search">Search purchases</label><input id="purchase-search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Product, ASIN or order number" maxLength={200} disabled={loading} /></div>
        <div><label htmlFor="purchase-status">Order status</label><select id="purchase-status" value={status} onChange={event => setStatus(event.target.value)} disabled={loading}><option value="all">All statuses</option><option value="active">Ordered units</option><option value="cancelled">Cancelled</option><option value="returned">Returned</option><option value="unknown">Unknown</option></select></div><button disabled={loading}>Search</button></div></form>
      <p className={styles.note}>Ordered units exclude cancelled, returned and zero-quantity lines. They are not a count of what you currently own.</p>
      {loading && <p role="status">Loading purchase history...</p>}{error && <p className={styles.error} role="alert">{error}</p>}
      {library && <>{!library.complete && <p role="status">Showing a limited set of imported records. Totals and search results may be incomplete.</p>}
        {!library.products.length ? <p className={styles.empty}>{library.summary.records ? "No purchases match these filters. Try another name or choose All statuses." : "No saved purchases yet. Import your Amazon export below, preview it, then save it to start your library."}</p> : <><p>{library.matched_products} matching {library.matched_products === 1 ? "product" : "products"} · Newest first</p>{library.products.map(product => <ProductDetails key={product.key} product={product} onCheck={checking ? undefined : value => void runCheck(value)} />)}</>}
        {library.next_offset !== null && <button disabled={loading} onClick={() => void load(library.next_offset!)}>Load more products</button>}</>}
    </section>
  </div>;
}
