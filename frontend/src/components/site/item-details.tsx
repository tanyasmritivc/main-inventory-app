"use client";
import { type InventoryItem, itemDisplayName } from "@/lib/api";
import { type PhotoContext } from "@/lib/item-photos";
import { ItemPhotoGallery } from "@/components/site/item-photo-gallery";
export function ItemDetails({
  item,
  context,
  canEdit,
  onChanged,
}: {
  item: InventoryItem;
  context?: PhotoContext;
  canEdit: boolean;
  onChanged?: (item: InventoryItem) => void;
}) {
  const fields = [
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
    ["Where to buy", item.purchase_source],
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
          .filter(([, value]) => value)
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
                {value}
              </dd>
            </div>
          ))}
      </dl>
      <ItemPhotoGallery
        itemId={item.item_id}
        context={context}
        canEdit={canEdit}
        onChanged={onChanged}
      />
    </div>
  );
}
