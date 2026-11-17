"use client";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import { activeInventory } from "@/lib/inventory-selection";
import { purchaseCsv, type PurchasePlan, type PurchaseSummary, type PurchaseLine } from "@/lib/cad-purchasing";
import type { CadCandidate } from "@/lib/cad";
import styles from "./cad.module.css";

type Capabilities = { inventory_id: string; purchasing: boolean; can_edit: boolean; can_approve: boolean };
type Pending = { path: string; body: Record<string, unknown> };

export function CadPurchasing({ versionId }: { versionId?: string }) {
  const inventory = activeInventory();
  return inventory ? <Purchasing key={`${inventory.accountId}:${inventory.inventory_id}`} inventory={inventory} versionId={versionId} /> : null;
}

function Purchasing({ inventory, versionId }: { inventory: NonNullable<ReturnType<typeof activeInventory>>; versionId?: string }) {
  const [capabilities, setCapabilities] = useState<Capabilities | null>(null);
  const [plans, setPlans] = useState<PurchaseSummary[]>([]);
  const [next, setNext] = useState<number | null>(null);
  const [plan, setPlan] = useState<PurchasePlan | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [pending, setPending] = useState<Pending | null>(null);
  const [form, setForm] = useState<{ line: string; kind: "quote" | "receive" } | null>(null);
  const controller = useRef<AbortController | null>(null);
  const locked = useRef(false);
  const pendingKey = `findez.cad.purchase.pending.${inventory.accountId}.${inventory.inventory_id}`;
  useEffect(() => () => controller.current?.abort(), []);
  useEffect(() => {
    try {
      const raw = sessionStorage.getItem(pendingKey);
      if (!raw) return;
      if (raw.length > 100000) throw new Error("Saved request is too large.");
      const value = JSON.parse(raw) as Pending;
      if (!/^\/cad\/purchases(?:\/[a-f0-9-]{36}\/actions)?$/.test(value.path) || !value.body?.request_id) throw new Error("Invalid saved request.");
      // Restore an interrupted, account-bound operation; retry remains explicit.
      setPending(value);
    } catch { setError("An interrupted purchase request could not be restored. Check the plan before making changes."); }
  }, [pendingKey]);
  async function request<T extends { inventory_id: string }>(path: string, options = {}) {
    const result = await accountRequest<T>(inventory.accountId, path, { ...options, signal: controller.current?.signal });
    if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed. Reopen CAD Intelligence.");
    return result;
  }
  async function work(operation: () => Promise<void>) {
    if (locked.current) return;
    locked.current = true; controller.current = new AbortController(); setBusy(true); setError("");
    try { await operation(); }
    catch (e) { if (!controller.current.signal.aborted) setError(e instanceof Error ? e.message : "The purchase operation could not be completed."); }
    finally { locked.current = false; if (!controller.current.signal.aborted) setBusy(false); }
  }
  async function list(offset = 0) {
    const result = await request<{ inventory_id: string; plans: PurchaseSummary[]; next_offset: number | null }>(`/cad/purchases?offset=${offset}`);
    if (!controller.current?.signal.aborted) { setPlans(old => offset ? [...old, ...result.plans] : result.plans); setNext(result.next_offset); }
  }
  function open() { void work(async () => {
    const result = await request<Capabilities>("/cad/capabilities");
    if (controller.current?.signal.aborted) return;
    setCapabilities(result);
    if (result.purchasing) await list();
  }); }
  async function read(id: string) {
    const result = await request<PurchasePlan>(`/cad/purchases/${encodeURIComponent(id)}`);
    if (!controller.current?.signal.aborted) { setPlan(result); setForm(null); }
  }
  async function send(operation: Pending) {
    sessionStorage.setItem(pendingKey, JSON.stringify(operation));
    setPending(operation);
    let saved = false;
    try {
      const result = await request<{ inventory_id: string; id: string; replayed: boolean }>(operation.path, { method: "POST", body: operation.body });
      if (controller.current?.signal.aborted) return;
      saved = true; sessionStorage.removeItem(pendingKey); setPending(null); setMessage(result.replayed ? "The earlier change was already saved. No duplicate was added." : "Purchase plan updated.");
      await read(result.id); await list();
    } catch (e) {
      // Keep the exact idempotency key after an unknown outcome. A confirmed
      // client rejection is safe to correct and submit as a new request.
      if (!saved && e instanceof ApiError && [400, 404, 409, 422, 429].includes(e.status)) { sessionStorage.removeItem(pendingKey); setPending(null); }
      throw e;
    }
  }
  function mutate(action: string, extra: Record<string, unknown> = {}) {
    if (!plan || pending) return;
    const operation = { path: `/cad/purchases/${encodeURIComponent(plan.id)}/actions`,
      body: { request_id: crypto.randomUUID(), expected_revision: plan.revision, action, ...extra } };
    void work(() => send(operation));
  }
  function create() {
    if (!versionId || pending) return;
    const operation = { path: "/cad/purchases", body: { request_id: crypto.randomUUID(), bom_version_id: versionId } };
    void work(() => send(operation));
  }
  function exportPlan() {
    if (!plan) return;
    const url = URL.createObjectURL(new Blob([purchaseCsv(plan)], { type: "text/csv;charset=utf-8" }));
    const link = document.createElement("a"); link.href = url; link.download = "findez-purchase-plan.csv"; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  const disabled = busy || !!pending;
  return <section className={styles.purchaseSection} aria-label="CAD purchase plans">
    <h2>Purchase plans</h2><p>Compare supplier quotes, record an order, and receive deliveries into this inventory.</p>
    <button disabled={busy} onClick={open}>{capabilities ? "Refresh purchase plans" : "Open purchase plans"}</button>
    {error && <p role="alert">{error}</p>}{message && <p role="status">{message}</p>}
    {pending && !busy && <div role="status"><p>The last change has not been confirmed. Retry it to check the result without adding a duplicate. Keep this page open until it is resolved.</p><button onClick={() => void work(() => send(pending))}>Retry the same change</button></div>}
    {capabilities && !capabilities.purchasing && <p>Purchasing is not enabled on this server yet.</p>}
    {capabilities?.purchasing && <>
      {versionId && capabilities.can_edit && <button disabled={disabled} onClick={create}>Create plan from selected BOM</button>}
      {!versionId && <p>Select a saved BOM above to create a plan from its current shortages.</p>}
      <p>Plans are shared with authorized inventory members. An owner or administrator approves and records orders. Creating a plan does not reserve stock or place a vendor order.</p>
      <ul>{plans.map(item => <li key={item.id}><button disabled={busy} onClick={() => void work(() => read(item.id))}>{item.name} / {item.state}</button></li>)}</ul>
      {!plans.length && <p>No purchase plans in this inventory.</p>}
      {next !== null && <button disabled={disabled} onClick={() => void work(() => list(next))}>More purchase plans</button>}
      {plan && <article>
        <h3>{plan.name} / {plan.state}</h3><p>Inventory checked {new Date(plan.inventory_as_of).toLocaleString()}. Counts may have changed since planning.</p>
        <p>{Object.entries(plan.totals).map(([currency, total]) => `${currency} ${total}`).join(" + ") || "No selected quotes yet"}. Subtotals exclude shipping and tax; currencies are not combined.</p>
        <div className={styles.actions}><button disabled={busy} onClick={exportPlan}>Export by vendor</button><button disabled={disabled} onClick={() => void work(() => read(plan.id))}>Reload this plan</button></div>
        {plan.order_reference && <p>Order reference: {plan.order_reference}</p>}
        {plan.lines.map(line => <section className={styles.purchaseLine} key={line.id}>
          <h4>{line.name}</h4><p>{line.manufacturer} {line.part_number}</p><p>Required {line.required} / available when planned {line.available} / shortage {line.quantity}</p>
          {line.selected_quote && <p>Selected: {line.selected_quote.vendor}, {line.selected_quote.currency} {line.selected_quote.estimate.subtotal} for {line.selected_quote.estimate.order_quantity} units ({line.selected_quote.estimate.surplus_quantity} extra).</p>}
          {['ordered', 'completed'].includes(plan.state) && <p>Received {line.received} / still on order {(line.selected_quote?.estimate.order_quantity || 0) - line.received}. On-order units are not on-hand stock.</p>}
          <details><summary>Supplier quotes ({line.quotes.length})</summary>{line.quotes.map(quote => <div className={styles.purchaseQuote} key={quote.id}>
            <p><strong>{quote.vendor}</strong>: {quote.currency} {quote.estimate.subtotal} for {quote.estimate.order_quantity} units. {quote.availability.replaceAll("_", " ")}.</p>
            <p>Quoted {new Date(quote.quoted_at).toLocaleString()}; valid until {new Date(quote.valid_until).toLocaleString()}.</p><p>{quote.source_note}</p>
            <a href={quote.product_url} target="_blank" rel="noreferrer">Vendor product page</a>
            {plan.state === "draft" && capabilities.can_edit && <button disabled={disabled || new Date(quote.valid_until).getTime() <= Date.now() || quote.availability === "out_of_stock"} onClick={() => mutate("select_quote", { line_id: line.id, quote_id: quote.id })}>Select quote from {quote.vendor}</button>}
          </div>)}</details>
          {plan.state === "draft" && capabilities.can_edit && <button disabled={disabled} onClick={() => setForm({ line: line.id, kind: "quote" })}>Add supplier quote for {line.name}</button>}
          {plan.state === "ordered" && capabilities.can_edit && line.received < (line.selected_quote?.estimate.order_quantity || 0) && <button disabled={disabled} onClick={() => setForm({ line: line.id, kind: "receive" })}>Receive {line.name}</button>}
          {form?.line === line.id && (form.kind === "quote" ? <QuoteForm disabled={disabled} submit={quote => mutate("quote", { line_id: line.id, quote })} /> : <ReceiveForm inventory={inventory} line={line} disabled={disabled} submit={data => mutate("receive", { line_id: line.id, ...data })} />)}
        </section>)}
        {capabilities.can_approve && <div className={styles.actions}>
          {plan.state === "draft" && <button disabled={disabled || plan.lines.some(line => !line.selected_quote)} onClick={() => mutate("approve")}>Approve selected quotes and quantities</button>}
          {plan.state === "approved" && <><button disabled={disabled} onClick={() => mutate("reopen")}>Reopen for editing</button><OrderForm disabled={disabled} submit={reference => mutate("order", { order_reference: reference })} /></>}
          {['draft', 'approved'].includes(plan.state) && <button disabled={disabled} onClick={() => mutate("cancel")}>Cancel plan</button>}
        </div>}
      </article>}
    </>}
  </section>;
}

function QuoteForm({ disabled, submit }: { disabled: boolean; submit: (quote: Record<string, unknown>) => void }) {
  const [error, setError] = useState("");
  function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget); setError("");
    const text = (key: string) => String(data.get(key) || "").trim();
    try {
      const tiers = text("tiers") ? text("tiers").split(/\n/).map(row => { const [quantity, price, extra] = row.split(","); if (extra || !quantity || !price) throw new Error("Enter each price break as quantity, unit price."); return { minimum_quantity: Number(quantity), unit_price: price.trim() }; }) : [];
      submit({ vendor: text("vendor"), product_url: text("url"), source_note: text("source"), currency: text("currency").toUpperCase(), unit_price: text("price"), pack_size: Number(text("pack")), minimum_quantity: Number(text("minimum")), tiers,
        quoted_at: new Date(text("quoted")).toISOString(), valid_until: new Date(text("expires")).toISOString(), availability: text("availability"), exact_part_confirmed: data.get("confirmed") === "on" });
    } catch (e) { setError(e instanceof Error ? e.message : "Check the quote fields."); }
  }
  return <form className={styles.purchaseForm} onSubmit={save}><fieldset disabled={disabled}><legend>Record an exact-part supplier quote</legend>
    <label>Vendor<input required name="vendor" maxLength={150} /></label><label>HTTPS product link<input required type="url" name="url" /></label>
    <label>Quote source or reference<input required name="source" maxLength={1000} /></label><label>Currency code<input required name="currency" defaultValue="USD" pattern="[A-Za-z]{3}" maxLength={3} /></label>
    <label>Price per individual unit<input required name="price" type="number" min="0" step="0.000001" /></label><label>Units per pack<input required name="pack" type="number" min="1" step="1" defaultValue="1" /></label>
    <label>Minimum order (individual units)<input required name="minimum" type="number" min="1" step="1" defaultValue="1" /></label>
    <label>Bulk price breaks (optional; one quantity, unit price per line)<textarea name="tiers" placeholder="100, 0.08" /></label>
    <label>Quoted at<input required name="quoted" type="datetime-local" /></label><label>Valid until<input required name="expires" type="datetime-local" /></label>
    <label>Supplier availability<select name="availability"><option value="unknown">Not confirmed</option><option value="in_stock">Listed in stock</option><option value="out_of_stock">Out of stock</option></select></label>
    <label className={styles.permissionOption}><input required type="checkbox" name="confirmed" /> I checked that this quote is for this exact part, including dimensions and material.</label>
    <p>Enter the price for one individual part, even when sold in packs. FindEZ checks pack rounding and bulk breaks. This does not verify engineering compatibility.</p>
    {error && <p role="alert">{error}</p>}<button type="submit">Save quote</button>
  </fieldset></form>;
}

function OrderForm({ disabled, submit }: { disabled: boolean; submit: (reference: string) => void }) {
  return <form className={styles.purchaseForm} onSubmit={event => { event.preventDefault(); submit(String(new FormData(event.currentTarget).get("reference") || "").trim()); }}>
    <label>Order references (include each vendor)<input required name="reference" maxLength={1000} disabled={disabled} /></label>
    <label className={styles.permissionOption}><input required type="checkbox" disabled={disabled} /> I placed the orders with the vendors for all selected quantities.</label>
    <button disabled={disabled}>Record orders placed</button>
  </form>;
}

function ReceiveForm({ inventory, line, disabled, submit }: { inventory: NonNullable<ReturnType<typeof activeInventory>>; line: PurchaseLine; disabled: boolean; submit: (data: Record<string, unknown>) => void }) {
  const [query, setQuery] = useState(line.part_number || line.name);
  const [items, setItems] = useState<CadCandidate[]>([]);
  const [error, setError] = useState("");
  const [searching, setSearching] = useState(false);
  const search = useRef<AbortController | null>(null);
  useEffect(() => () => search.current?.abort(), []);
  async function find() {
    search.current?.abort(); const controller = new AbortController(); search.current = controller; setSearching(true); setError(""); setItems([]);
    try {
      const result = await accountRequest<{ inventory_id: string; items: CadCandidate[] }>(inventory.accountId, `/cad/candidates?q=${encodeURIComponent(query)}`, { signal: controller.signal });
      if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed.");
      if (!controller.signal.aborted) setItems(result.items);
    } catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : "Stock items could not be loaded."); }
    finally { if (!controller.signal.aborted) setSearching(false); }
  }
  return <form className={styles.purchaseForm} onSubmit={event => { event.preventDefault(); const data = new FormData(event.currentTarget); submit({ item_id: data.get("item"), quantity: Number(data.get("quantity")), identity_confirmed: data.get("confirmed") === "on" }); }}>
    <fieldset disabled={disabled || searching}><legend>Receive delivered parts</legend><label>Find an existing stock item<input value={query} maxLength={100} onChange={event => { setQuery(event.target.value); setItems([]); }} /></label>
      <button type="button" onClick={() => void find()} disabled={query.trim().length < 2}>Find stock destination</button>
      {error && <p role="alert">{error}</p>}<label>Destination item and recorded location<select name="item" required defaultValue=""><option value="">Select a stock record</option>{items.map(item => <option key={item.item_id} value={item.item_id}>{item.name} / {item.part_number} / {item.location || "Unsorted"}</option>)}</select></label>
      <label>Quantity delivered now<input required name="quantity" type="number" min="1" max={(line.selected_quote?.estimate.order_quantity || 0) - line.received} step="1" /></label>
      <label className={styles.permissionOption}><input type="checkbox" name="confirmed" required /> I checked the delivered part, quantity, and destination stock record.</label>
      <p>This adds the delivered quantity to the selected existing stock record. Create the stock record in the inventory first if none exists.</p><button disabled={!items.length}>Confirm receipt and update stock</button>
    </fieldset>
  </form>;
}
