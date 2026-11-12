"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { accountRequest } from "@/lib/account-request";
import { scopeQuery, type ConnectionScope } from "@/lib/commerce";
import styles from "./purchase-library.module.css";

type Order = { order_id: string; ordered_at: string | null; quantity: number; source_status: string; connection_status: string };
type Product = { key: string; title: string; asin: string | null; ordered_units: number; excluded_units: number; order_count: number; last_ordered_at: string; orders: Order[]; history_truncated: boolean; category?: string; inventory_match?: boolean; active_order_count?: number };
type Library = { summary: { products: number; orders: number; records: number; repeat_products?: number; not_matched_products?: number }; categories?: { name: string; products: number }[]; inventory_complete?: boolean; page_size?: number; offset?: number; products: Product[]; matched_products: number; next_offset: number | null; complete: boolean };
type Check = { query: string; result: string; purchase_matches: Product[]; purchase_match_basis: string; inventory_matches: { name: string; quantity: number | null; location: string | null; inventory_name: string; workspace_name: string }[]; suggestions: string[]; purchases_complete: boolean; inventory_match_count: number; purchase_match_count: number };
type Filters = { query: string; status: string; category: string; date_from: string; date_to: string; sort: string; inventory: string; repeated: boolean };
const defaultFilters: Filters = { query: "", status: "all", category: "all", date_from: "", date_to: "", sort: "newest", inventory: "all", repeated: false };
const PAGE_SIZE = 25;
type Request = <T>(path: string, options?: Parameters<typeof accountRequest>[2]) => Promise<T>;
const date = (value: string | null) => value ? new Date(value).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric", timeZone: "UTC" }) : "Date unknown";
const errorText = (reason: unknown) => reason instanceof Error ? reason.message : "Could not load these records. Try again.";

function ProductDetails({ product, onCheck }: { product: Product; onCheck?: (query: string) => void }) {
  return <article className={styles.product}>
    <div className={styles.productTop}><div><h3>{product.title}</h3><p>{product.asin ? `ASIN ${product.asin} · ` : ""}Last ordered {date(product.last_ordered_at)}</p></div>
      <div className={styles.badges}><span className={styles.badge}>Ownership unconfirmed</span>{product.inventory_match && <span className={styles.badge}>Possible inventory match</span>}</div></div>
    {product.category && <p className={styles.category}>{product.category}</p>}
    <div className={styles.productStats}><span><strong>{product.ordered_units}</strong> ordered units</span><span><strong>{product.order_count}</strong> {product.order_count === 1 ? "order" : "orders"}</span>{product.excluded_units > 0 && <span>{product.excluded_units} cancelled or returned units excluded</span>}</div>
    <details><summary>View order history</summary><div className={styles.orders}>{product.orders.map((order, index) => <div key={`${order.order_id}:${index}`}>
      <span>{date(order.ordered_at)}<small>Order {order.order_id}</small></span><span>{order.quantity} units<small>{order.source_status}{order.connection_status === "disconnected" ? " · Disconnected source" : ""}</small></span>
    </div>)}</div>{product.history_truncated && <p>Showing the latest 20 matching order lines for this product.</p>}</details>
    {onCheck && <button type="button" className={styles.textButton} onClick={() => onCheck(product.asin || product.title)}>Check against my inventory →</button>}
  </article>;
}

export function PurchaseLibrary({ scope, request }: { scope: ConnectionScope; request: Request }) {
  const [library, setLibrary] = useState<Library | null>(null);
  const [filters, setFilters] = useState<Filters>(defaultFilters);
  const [applied, setApplied] = useState<Filters>(defaultFilters);
  const [offset, setOffset] = useState(0);
  const historyPanel = useRef<HTMLElement>(null);
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
    setFilters(defaultFilters); setApplied(defaultFilters); setOffset(0); setBuyQuery(""); setChecking(false); setCheckError("");
    request<Library>(`/commerce/purchases?${destination}`).then(value => { if (active) setLibrary(value); })
      .catch(reason => { if (active) setError(errorText(reason)); }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; alive.current = false; };
  }, [request, destination]);

  async function load(nextOffset = 0, selected: Filters = filters) {
    const version = ++readVersion.current;
    if (selected.date_from && selected.date_to && selected.date_from > selected.date_to) {
      setError("Start date must be on or before end date."); return;
    }
    setLoading(true); setError("");
    try {
      const params = new URLSearchParams({ query: selected.query, status: selected.status, category: selected.category,
        sort: selected.sort, inventory: selected.inventory, repeated: String(selected.repeated), offset: String(nextOffset) });
      if (selected.date_from) params.set("date_from", selected.date_from);
      if (selected.date_to) params.set("date_to", selected.date_to);
      const result = await request<Library>(`/commerce/purchases?${destination}&${params}`);
      if (alive.current && version === readVersion.current) {
        setLibrary(result); setOffset(nextOffset); setApplied(selected);
        historyPanel.current?.scrollIntoView({ block: "start" });
      }
    } catch (reason) { if (alive.current && version === readVersion.current) setError(errorText(reason)); }
    finally { if (alive.current && version === readVersion.current) setLoading(false); }
  }
  function changeFilter<K extends keyof Filters>(key: K, value: Filters[K]) { setFilters(previous => ({ ...previous, [key]: value })); }
  function quickFilter(next: Filters) { setFilters(next); void load(0, next); }
  function pagination() {
    if (!library || !library.matched_products) return null;
    const pageSize = library.page_size ?? PAGE_SIZE;
    return <nav className={styles.pagination} aria-label="Purchase pages">
      <button type="button" disabled={loading || offset === 0} onClick={() => void load(Math.max(0, offset - pageSize), applied)}>Previous</button>
      <span aria-live="polite">Page {Math.floor(offset / pageSize) + 1} of {Math.max(1, Math.ceil(library.matched_products / pageSize))}</span>
      <button type="button" disabled={loading || library.next_offset === null} onClick={() => library.next_offset !== null && void load(library.next_offset, applied)}>Next</button>
    </nav>;
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

    <section ref={historyPanel} className={styles.history} aria-labelledby="purchase-library-heading"><p className={styles.eyebrow}>Your purchase library</p><h2 id="purchase-library-heading">Past purchases, organized</h2>
      <p>Products are grouped across orders. Open any product to see when and how much you ordered.</p>
      {library && <div className={styles.stats}><div><strong>{library.summary.products}</strong><span>products</span></div><div><strong>{library.summary.orders}</strong><span>orders</span></div><div><strong>{library.summary.records}</strong><span>imported order lines</span></div></div>}
      {library && <div className={styles.quickFilters}>
        <button type="button" disabled={loading} onClick={() => quickFilter({ ...defaultFilters, repeated: true, sort: "frequent" })}>Frequently purchased ({library.summary.repeat_products ?? 0})</button>
        <button type="button" disabled={loading} onClick={() => quickFilter({ ...defaultFilters, inventory: "unmatched" })}>Not matched to inventory ({library.summary.not_matched_products ?? library.summary.products})</button>
      </div>}
      <form onSubmit={event => { event.preventDefault(); void load(); }}>
        <div className={styles.filters}>
          <div><label htmlFor="purchase-search">Search all purchases</label><input id="purchase-search" value={filters.query} onChange={event => changeFilter("query", event.target.value)} placeholder="Product, ASIN or order number" maxLength={200} disabled={loading} /></div>
          <div><label htmlFor="purchase-sort">Sort by</label><select id="purchase-sort" value={filters.sort} onChange={event => changeFilter("sort", event.target.value)} disabled={loading}><option value="newest">Newest first</option><option value="oldest">Oldest first</option><option value="frequent">Most often purchased</option><option value="name">Product name</option></select></div>
          <button disabled={loading}>Search</button>
        </div>
        <details className={styles.moreFilters}><summary>Filters</summary><div className={styles.filterGrid}>
          <div><label htmlFor="purchase-category">Suggested category</label><select id="purchase-category" value={filters.category} onChange={event => changeFilter("category", event.target.value)} disabled={loading}><option value="all">All categories</option>{library?.categories?.map(category => <option key={category.name} value={category.name}>{category.name} ({category.products})</option>)}</select></div>
          <div><label htmlFor="purchase-status">Order status</label><select id="purchase-status" value={filters.status} onChange={event => changeFilter("status", event.target.value)} disabled={loading}><option value="all">All statuses</option><option value="active">Ordered units</option><option value="purchased">Purchased</option><option value="shipped">Shipped</option><option value="delivered">Delivered</option><option value="cancelled">Cancelled</option><option value="returned">Returned</option><option value="unknown">Unknown</option></select></div>
          <div><label htmlFor="purchase-date-from">Ordered from</label><input id="purchase-date-from" type="date" value={filters.date_from} onChange={event => changeFilter("date_from", event.target.value)} disabled={loading} /></div>
          <div><label htmlFor="purchase-date-to">Ordered through</label><input id="purchase-date-to" type="date" value={filters.date_to} onChange={event => changeFilter("date_to", event.target.value)} disabled={loading} /></div>
          <div><label htmlFor="purchase-inventory">Inventory evidence</label><select id="purchase-inventory" value={filters.inventory} onChange={event => changeFilter("inventory", event.target.value)} disabled={loading}><option value="all">All products</option><option value="matched">Possible inventory match</option><option value="unmatched">Not matched yet</option></select></div>
          <div><label htmlFor="purchase-repeat">Purchase frequency</label><select id="purchase-repeat" value={String(filters.repeated)} onChange={event => changeFilter("repeated", event.target.value === "true")} disabled={loading}><option value="false">Any frequency</option><option value="true">More than one active order</option></select></div>
        </div><p className={styles.note}>Categories are suggested from product names. Inventory matches use exact names or identifiers and still need ownership verification.</p>
        <div className={styles.filterActions}><button disabled={loading}>Apply filters</button><button type="button" disabled={loading} onClick={() => quickFilter(defaultFilters)}>Clear filters</button></div></details>
      </form>
      <p className={styles.note}>Ordered units exclude cancelled, returned and zero-quantity lines. They are not a count of what you currently own.</p>
      {loading && <p role="status">Loading purchase history...</p>}{error && <p className={styles.error} role="alert">{error}</p>}
      {library && <>{library.inventory_complete === false && <p role="status">Inventory matching is limited. Some unmatched purchases may already be recorded in your inventory.</p>}{!library.complete && <p role="status">Showing a limited set of imported records. Totals and search results may be incomplete.</p>}
        {!library.products.length ? <p className={styles.empty}>{library.summary.records ? "No purchases match these filters. Try another name or clear the filters." : "No saved purchases yet. Import your Amazon export below, preview it, then save it to start your library."}</p> : <><p role="status">Showing {offset + 1} to {offset + library.products.length} of {library.matched_products} matching products</p>{pagination()}{library.products.map(product => <ProductDetails key={product.key} product={product} onCheck={checking ? undefined : value => void runCheck(value)} />)}</>}
        {pagination()}</>}
    </section>
  </div>;
}
