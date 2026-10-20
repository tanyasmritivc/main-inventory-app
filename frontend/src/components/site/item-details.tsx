"use client";
import { useEffect, useRef, useState } from "react";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";
import { photoPath } from "@/lib/item-photos";
import { purchaseSource, purchaseLink } from "@/lib/purchase-source";
import { userFacingError } from "@/lib/user-facing-error";
import { type InventoryItem, itemDisplayName } from "@/lib/api";
import { type PhotoContext } from "@/lib/item-photos";
import { ItemPhotoGallery } from "@/components/site/item-photo-gallery";
export function ItemDetails({
  item,
  context,
  canEdit,
  onChanged,
  onEditingChange,
}: {
  item: InventoryItem;
  context?: PhotoContext;
  canEdit: boolean;
  onChanged?: (item: InventoryItem) => void;
  onEditingChange?: (editing: boolean) => void;
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
    ["Name", item.name],
    ["Category", item.category],
    ["Location", item.location || "Unsorted"],
    ["Quantity", String(item.quantity)],
    ["Brand", item.brand],
    ["Barcode", item.barcode],
    ["Part number", item.part_number],
    ["Subcategory", item.subcategory],
    ["Date added", new Date(item.created_at).toLocaleDateString()],
    [
      "AI confidence",
      typeof item.confidence === "number"
        ? `${Math.round(item.confidence * 100)}%`
        : undefined,
    ],
    ["Notes", item.notes],
    ["Tags", item.tags?.join(", ")],
    ["Where to buy", source],
  ];
  return (
    <div>
      <h2>{itemDisplayName(item)}</h2>
      <dl
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit,minmax(150px,1fr))",
          gap: 18,
          marginTop: 20,
        }}
      >
        {fields
          .filter(([label, value]) => value || (canEdit && label && keys[label]))
          .map(([label, value]) => (
            <div key={label}>
              <dt className="workspace-muted" style={{ fontSize: 11 }}>
                {label}
              </dt>
              <dd
                style={{
                  margin: "5px 0",
                  fontSize: 13,
                  overflowWrap: "anywhere",
                  whiteSpace: "pre-wrap",
                }}
              >
                {editing === label ? <form onSubmit={event => { event.preventDefault(); void save(keys[label!]); }}>
                  <input autoFocus aria-label={label!} className="workspace-input" value={draft} disabled={busy} type={label === "Quantity" ? "number" : "text"} min={label === "Quantity" ? 0 : undefined} step={label === "Quantity" ? 1 : undefined} maxLength={label === "Notes" ? 2000 : label === "Tags" ? 1000 : label === "Name" || label === "Location" || label === "Where to buy" ? 200 : 100} onChange={event => setDraft(event.target.value)} />
                  {error && <p role="alert">{error}</p>}
                  <div className="workspace-actions"><button className="workspace-button" disabled={busy} type="submit">{busy ? "Saving..." : "Save"}</button><button className="workspace-button" disabled={busy} type="button" onClick={() => { setEditing(null); setError(""); }}>Cancel</button></div>
                </form> : canEdit && label && keys[label] ? <button type="button" aria-label={`Edit ${label}`} disabled={editing !== null} style={{border: 0, padding: 0, background: "none", color: "inherit", textAlign: "left", font: "inherit", cursor: "text", whiteSpace: "pre-wrap"}} onClick={() => { setEditing(label); setDraft(value || ""); setError(""); }}>{value || "Not set"}</button> : label === "Where to buy" && value && purchaseLink(value) ? <a href={purchaseLink(value)!} target="_blank" rel="noopener noreferrer">{value}</a> : value}
              </dd>
            </div>
          ))}
      </dl>
      {item.import_data?.fields?.length ? (
        <section style={{ marginTop: 28, paddingTop: 20, borderTop: "1px solid var(--app-border)" }}>
          <h3 style={{ fontSize: 14, fontWeight: 500 }}>Imported details</h3>
          <p className="workspace-muted" style={{ fontSize: 12, overflowWrap: "anywhere" }}>
            {item.import_data.filename} / {item.import_data.sheet}
          </p>
          <dl style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(min(100%,180px),1fr))", gap: 18, marginTop: 18 }}>
            {item.import_data.fields.map((field, index) => (
              <div key={index}>
                <dt className="workspace-muted" style={{ fontSize: 11, overflowWrap: "anywhere", whiteSpace: "pre-wrap" }}>
                  {field.name.trim() ? field.name : `Column ${index + 1}`}
                </dt>
                <dd style={{ margin: "5px 0", fontSize: 13, overflowWrap: "anywhere", whiteSpace: "pre-wrap" }}>
                  {field.value === null || field.value === undefined || field.value === ""
                    ? "Empty"
                    : typeof field.value === "object" ? JSON.stringify(field.value) : String(field.value)}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      ) : null}
      <ItemPhotoGallery
        itemId={item.item_id}
        context={context}
        canEdit={canEdit}
        onChanged={onChanged}
      />
    </div>
  );
}
