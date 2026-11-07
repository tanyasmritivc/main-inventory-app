"use client";
import { useEffect, useRef, useState } from "react";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";
import { photoPath } from "@/lib/item-photos";
import { purchaseSource, purchaseLink } from "@/lib/purchase-source";
import { userFacingError } from "@/lib/user-facing-error";
import { type InventoryItem } from "@/lib/api";
import { type PhotoContext } from "@/lib/item-photos";
import { ItemQrLabel } from "./item-qr-label";
import { ItemCheckout, ItemDocuments, ItemThreshold } from "./item-info-sections";
import { DialogClose } from "@/components/ui/dialog";
import { ItemPhotoGallery } from "@/components/site/item-photo-gallery";
import "./item-details.css";
export function ItemDetails({
  item,
  context,
  canEdit,
  onChanged,
  onEditingChange,
  showTitle = true,
  showClose = false,
}: {
  item: InventoryItem;
  context?: PhotoContext;
  canEdit: boolean;
  onChanged?: (item: InventoryItem) => void;
  onEditingChange?: (editing: boolean) => void;
  showTitle?: boolean;
  showClose?: boolean;
}) {
  const { accountId } = useApiSession();
  const [editing, setEditing] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const owner = useRef(accountId);
  const generation = useRef(0);
  const pending = useRef(false);
  useEffect(() => { const epoch = ++generation.current; pending.current = false; owner.current = accountId; setBusy(false); setEditing(null); setError(""); return () => { generation.current = epoch + 1; owner.current = null; }; }, [accountId, item.item_id]);
  useEffect(() => { onEditingChange?.(editing !== null); return () => onEditingChange?.(false); }, [editing, onEditingChange]);
  const keys: Record<string, string> = {Name: "name", Category: "category", Location: "location", Quantity: "quantity", Brand: "brand", Barcode: "barcode", "Part number": "part_number", Subcategory: "subcategory", Notes: "notes", Tags: "tags", "Where to buy": "purchase_source"};
  if (context?.kind === "shared" || context?.kind === "team") delete keys.Location;
  async function save(field: string) {
    if (!accountId || !canEdit || busy || pending.current) return;
    const account = accountId, ticket = generation.current, value = draft.trim();
    if ((field === "name" || field === "category") && !value) { setError("Enter a value."); return; }
    if (field === "quantity" && (!/^\d+$/.test(value) || Number(value) > 100000)) { setError("Enter a whole number from 0 to 100000."); return; }
    pending.current = true; setBusy(true); setError("");
    try {
      const updates = {[field]: field === "quantity" ? Number(value) : field === "tags" ? value.split(",").map(v => v.trim()).filter(Boolean) : value};
      const path = context && context.kind !== "personal" ? photoPath(item.item_id, context).replace(/\/photos$/, "") : "/update_item";
      const result = await accountRequest<{item: InventoryItem}>(account, path, { method: "PATCH", body: context?.kind === "shared" ? updates : {item_id: item.item_id, ...updates} });
      if (owner.current !== account || generation.current !== ticket) return;
      const savedValue = result?.item?.[field as keyof InventoryItem];
      const confirmedValue = field === "category" || field === "location"
        ? typeof savedValue === "string" && (field === "location" || savedValue.length > 0)
        : JSON.stringify(savedValue) === JSON.stringify(updates[field]);
      if (!result?.item || result.item.item_id !== item.item_id || !confirmedValue) throw new Error("The saved change could not be confirmed. Refresh before retrying.");
      onChanged?.(result.item); setEditing(null);
    } catch (reason) { if (owner.current === account && generation.current === ticket) setError(userFacingError(reason, "Could not save. Your changes are still here.")); }
    finally { if (owner.current === account && generation.current === ticket) { pending.current = false; setBusy(false); } }
  }
  const source = purchaseSource(item);
  const fields = [
    ["Name", item.name], ["Part number", item.part_number], ["Category", item.category],
    ["Location", item.location || "Unsorted"], ["Quantity", String(item.quantity)],
    ["Brand", item.brand], ["Barcode", item.barcode], ["Subcategory", item.subcategory],
    ["Date added", new Date(item.created_at).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })],
    ["Tags", item.tags?.join(", ")],
  ];
  function fieldValue(label: string, value: string | null | undefined, placeholder = "Not set", multiline = false) {
    if (editing === label) return <form className="item-inline-form" onSubmit={event => { event.preventDefault(); void save(keys[label]); }}>
      {multiline ? <textarea autoFocus aria-label={label} value={draft} disabled={busy} maxLength={2000} rows={4} onChange={event => setDraft(event.target.value)} /> : <input autoFocus aria-label={label} value={draft} disabled={busy} type={label === "Quantity" ? "number" : "text"} min={label === "Quantity" ? 0 : undefined} step={label === "Quantity" ? 1 : undefined} maxLength={label === "Tags" ? 1000 : ["Name", "Location", "Where to buy"].includes(label) ? 200 : 100} onChange={event => setDraft(event.target.value)} />}
      {error && <p role="alert">{error}</p>}
      <div className="item-info-actions"><button disabled={busy} type="submit">{busy ? "Saving..." : "Save"}</button><button disabled={busy} type="button" onClick={() => { setEditing(null); setError(""); }}>Cancel</button></div>
    </form>;
    if (canEdit && keys[label]) return <button className="item-field-value" type="button" aria-label={`Edit ${label}`} disabled={editing !== null} onClick={() => { setEditing(label); setDraft(value || ""); setError(""); }}>{value || <span className="item-field-placeholder">{placeholder}</span>}</button>;
    return value || placeholder;
  }
  const personal = !context || context.kind === "personal";
  return <div className="item-details">
    {showTitle && <h2>{item.name}</h2>}
    <p className="item-category">{item.category}</p>
    <ItemPhotoGallery itemId={item.item_id} context={context} canEdit={canEdit} onChanged={onChanged} />
    <dl className="item-details-fields">{fields.map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{fieldValue(label!, value)}</dd></div>)}</dl>
    {item.import_data?.fields?.length ? <section className="item-import-details"><h3>Imported details</h3><p className="workspace-muted">{item.import_data.filename} / {item.import_data.sheet}</p><dl>{item.import_data.fields.map((field, index) => <div key={index}><dt>{field.name.trim() ? field.name : `Column ${index + 1}`}</dt><dd>{field.value === null || field.value === undefined || field.value === "" ? "Empty" : typeof field.value === "object" ? JSON.stringify(field.value) : String(field.value)}</dd></div>)}</dl></section> : null}
    {personal && <ItemCheckout key={`checkout-${item.item_id}`} itemId={item.item_id} canEdit={canEdit} />}
    <section className="item-info-section"><h3>Notes</h3><div className="item-text-card item-notes">{fieldValue("Notes", item.notes, "Tap to add notes...", true)}</div></section>
    {personal && <ItemDocuments key={`documents-${item.item_id}`} itemId={item.item_id} canEdit={canEdit} />}
    <section className="item-info-section"><header><h3>Where to buy</h3><details className="item-store-menu"><summary>Find stores</summary><div>{[["Amazon", "https://www.amazon.com/s?k="], ["Google Shopping", "https://www.google.com/search?tbm=shop&q="], ["eBay", "https://www.ebay.com/sch/i.html?_nkw="], ["Walmart", "https://www.walmart.com/search?q="], ["Target", "https://www.target.com/s?searchTerm="]].map(([name, url]) => <a key={name} href={url + encodeURIComponent(item.name)} target="_blank" rel="noopener noreferrer">{name}</a>)}</div></details></header><div className="item-text-card">{fieldValue("Where to buy", source, "Where to buy this item...")}</div>{source && purchaseLink(source) && <a className="item-source-link" href={purchaseLink(source)!} target="_blank" rel="noopener noreferrer">Open store link</a>}</section>
    <ItemQrLabel item={item} context={context} />
    {personal && <ItemThreshold key={`threshold-${item.item_id}`} itemId={item.item_id} canEdit={canEdit} />}
    {showClose && <DialogClose asChild><button className="item-close-button" type="button" disabled={editing !== null}>Close</button></DialogClose>}
  </div>;
}
