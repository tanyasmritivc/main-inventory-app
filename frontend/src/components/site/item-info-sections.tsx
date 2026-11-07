"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { CheckCircle2, FileText, Plus } from "lucide-react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { activeInventory } from "@/lib/inventory-selection";
import { apiBase } from "@/lib/api";
import { documentOwner, trustedDocumentUrl, type DocumentEntry } from "@/lib/documents";
import { userFacingError } from "@/lib/user-facing-error";

// An unmounted item or a changed account cannot adopt an earlier request's result.
function useItemRequest(itemId: string) {
  const { accountId } = useApiSession();
  const generation = useRef(0), owner = useRef(accountId), item = useRef(itemId);
  useEffect(() => { const ticket = ++generation.current; owner.current = accountId; item.current = itemId; return () => { generation.current = ticket + 1; }; }, [accountId, itemId]);
  return useCallback(async <T,>(path: string, options?: Parameters<typeof accountRequest>[2]) => {
    if (!accountId) throw new Error("Please sign in again.");
    const ticket = generation.current, inventory = activeInventory();
    const value = await accountRequest<T>(accountId, path, options);
    if (owner.current !== accountId || item.current !== itemId || generation.current !== ticket || activeInventory() !== inventory) throw new Error("The item changed. Reopen it to continue.");
    return value;
  }, [accountId, itemId]);
}
export function ItemDocuments({ itemId, canEdit }: { itemId: string; canEdit: boolean }) {
  const { accountId } = useApiSession(), request = useItemRequest(itemId);
  const [docs, setDocs] = useState<DocumentEntry[]>([]), [loading, setLoading] = useState(true), [busy, setBusy] = useState(false), [error, setError] = useState("");
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => { let active = true; setDocs([]); setLoading(true); setError("");
    request<{ documents: DocumentEntry[] }>(`/documents?${new URLSearchParams({ item_id: itemId, limit: "200" })}`).then(result => { if (active) setDocs(result.documents); }).catch(e => { if (active) setError(userFacingError(e, "Could not load documents.")); }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [itemId, request]);
  async function upload(file: File) {
    if (busy || !canEdit) return; setBusy(true); setError("");
    try { const body = new FormData(); body.append("file", file); body.append("item_id", itemId);
      const result = await request<{ document: DocumentEntry }>("/documents/upload", { method: "POST", body });
      if (!result.document?.storage_path || result.document.item_id !== itemId) throw new Error("The attachment could not be confirmed. Refresh before retrying.");
      setDocs(rows => [result.document, ...rows.filter(d => d.storage_path !== result.document.storage_path)]);
    } catch (e) { setError(userFacingError(e, "Could not add the document.")); } finally { setBusy(false); }
  }
  async function open(doc: DocumentEntry) {
    if (busy || !accountId) return; setBusy(true); setError("");
    // Open synchronously so Safari permits the tab, then validate its destination.
    const tab = window.open("about:blank", "_blank"); if (tab) tab.opener = null;
    try {
      if (!tab) throw new Error("Allow popups to open this document.");
      const result = await request<{ url: string }>(`/documents/open?${new URLSearchParams({ storage_path: doc.storage_path })}`);
      const url = trustedDocumentUrl(result.url, documentOwner(doc, accountId), [process.env.NEXT_PUBLIC_SUPABASE_URL || "", apiBase()]);
      if (!url) throw new Error("This document could not be opened safely."); tab.location.href = url;
    } catch (e) { tab?.close(); setError(userFacingError(e, "Could not open the document.")); } finally { setBusy(false); }
  }
  return <section className="item-info-section"><header><h3>Documents</h3>{canEdit && <button type="button" disabled={busy} onClick={() => input.current?.click()}><Plus size={15} />Add</button>}</header>
    <input hidden type="file" ref={input} onChange={e => { const file = e.target.files?.[0]; e.target.value = ""; if (file) void upload(file); }} />
    {loading ? <p role="status">Loading documents...</p> : error ? <p role="alert">{error}</p> : !docs.length ? <div className="item-empty-card"><FileText size={30} /><strong>No documents yet</strong><span>Add receipts, manuals, or warranties</span></div> : <ul className="item-document-list">{docs.map(doc => <li key={doc.storage_path}><button type="button" disabled={busy} onClick={() => void open(doc)}><FileText size={18} />{doc.display_name || doc.filename}</button></li>)}</ul>}
  </section>;
}
type Checkout = { checkout_id: string; is_active: boolean; checked_out_by: string; checked_out_at?: string; returned_at?: string | null; due_back_at?: string | null };
export function ItemCheckout({ itemId, canEdit }: { itemId: string; canEdit: boolean }) {
  const request = useItemRequest(itemId);
  const [rows, setRows] = useState<Checkout[]>([]), [loading, setLoading] = useState(true), [busy, setBusy] = useState(false), [error, setError] = useState(""), [editing, setEditing] = useState(false), [borrower, setBorrower] = useState(""), [due, setDue] = useState("");
  useEffect(() => { let active = true; setLoading(true); setError(""); setRows([]); setEditing(false);
    request<{ checkouts: Checkout[] }>(`/checkouts/item/${encodeURIComponent(itemId)}`).then(result => { if (active) setRows(result.checkouts); }).catch(e => { if (active) setError(userFacingError(e, "Could not load checkout status.")); }).finally(() => { if (active) setLoading(false); }); return () => { active = false; };
  }, [itemId, request]);
  const current = rows.find(row => row.is_active);
  async function save() {
    if (busy || !canEdit) return; setBusy(true); setError("");
    try {
      if (current) { const result = await request<{ returned: boolean }>("/checkouts/return", { method: "POST", body: { checkout_id: current.checkout_id } }); if (!result.returned) throw new Error("The return could not be confirmed."); }
      else { const result = await request<Checkout>("/checkouts/checkout", { method: "POST", body: { item_id: itemId, checked_out_by: borrower.trim(), due_back_at: due ? new Date(`${due}T23:59:59`).toISOString() : undefined } }); if (!result.checkout_id) throw new Error("The checkout could not be confirmed."); }
      setEditing(false); const result = await request<{ checkouts: Checkout[] }>(`/checkouts/item/${encodeURIComponent(itemId)}`); setRows(result.checkouts);
    } catch (e) { setError(userFacingError(e, "Could not update checkout status.")); } finally { setBusy(false); }
  }
  return <section className="item-info-section"><header><h3>Check out</h3>{canEdit && <button type="button" disabled={loading || busy || !!error} onClick={() => { if (current) void save(); else setEditing(!editing); }}>{current ? "Return item" : "Check Out"}</button>}</header>
    {loading ? <p role="status">Loading checkout status...</p> : <div className="item-checkout-status"><CheckCircle2 size={18} />{error ? <span role="alert">{error}</span> : current ? <span>Checked out to {current.checked_out_by}{current.due_back_at && <small>Due {new Date(current.due_back_at).toLocaleDateString()}</small>}</span> : "Available - not checked out"}</div>}
    {editing && <form className="item-inline-form" onSubmit={e => { e.preventDefault(); void save(); }}><label>Checked out to<input required maxLength={200} value={borrower} onChange={e => setBorrower(e.target.value)} disabled={busy} /></label><label>Due date<input type="date" value={due} onChange={e => setDue(e.target.value)} disabled={busy} /></label><div className="item-info-actions"><button disabled={busy || !borrower.trim()}>Check Out</button><button type="button" disabled={busy} onClick={() => setEditing(false)}>Cancel</button></div></form>}
    {rows.some(row => row.returned_at) && <details className="item-checkout-history"><summary>History</summary>{rows.filter(row => row.returned_at).map(row => <p key={row.checkout_id}>{row.checked_out_by}<small>Returned {new Date(row.returned_at!).toLocaleDateString()}</small></p>)}</details>}
  </section>;
}
export function ItemThreshold({ itemId, canEdit }: { itemId: string; canEdit: boolean }) {
  const request = useItemRequest(itemId);
  const [value, setValue] = useState(""), [saved, setSaved] = useState(""), [loading, setLoading] = useState(true), [busy, setBusy] = useState(false), [error, setError] = useState("");
  useEffect(() => { let active = true; setLoading(true); setError(""); setValue(""); setSaved("");
    request<{ rules: Record<string, number> }>("/notifications/stock-rules", { method: "POST", body: { rules: [{ item_id: itemId, threshold: null }], import_only: true } }).then(result => { if (active) { const v = result.rules[itemId]; setValue(v == null ? "" : String(v)); setSaved(v == null ? "" : String(v)); } }).catch(e => { if (active) setError(userFacingError(e, "Could not load the quantity alert.")); }).finally(() => { if (active) setLoading(false); }); return () => { active = false; };
  }, [itemId, request]);
  async function save() {
    if (busy || !canEdit) return;
    if (value && (!/^\d+$/.test(value) || (!Number.isSafeInteger(Number(value)) || Number(value) > 2147483647))) { setError("Enter a whole number of zero or more."); return; }
    setBusy(true); setError("");
    try { const result = await request<{ rules: Record<string, number> }>("/notifications/stock-rules", { method: "POST", body: { rules: [{ item_id: itemId, threshold: value === "" ? null : Number(value) }], import_only: false } });
      const confirmed = result.rules[itemId] == null ? "" : String(result.rules[itemId]); if (confirmed !== value) throw new Error("The threshold could not be confirmed."); setSaved(value);
    } catch (e) { setError(userFacingError(e, "Could not save the quantity alert.")); } finally { setBusy(false); }
  }
  return <section className="item-info-section"><h3><label htmlFor={`threshold-${itemId}`}>Alert me at or below</label></h3><form onSubmit={e => { e.preventDefault(); void save(); }}><input id={`threshold-${itemId}`} className="item-text-card" type="number" min="0" step="1" placeholder="Quantity threshold" disabled={loading || busy || !canEdit} value={value} onChange={e => setValue(e.target.value)} />{value !== saved && <div className="item-info-actions"><button disabled={busy || !canEdit}>{busy ? "Saving..." : "Save threshold"}</button></div>}</form>{error && <p role="alert">{error}</p>}</section>;
}
