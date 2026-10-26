"use client";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import { hasUnknownQuantity } from "@/lib/quantity-evidence";
import { userFacingError } from "@/lib/user-facing-error";
import {
  parseCapture,
  type ChatCapture,
  type CaptureRow,
} from "@/lib/chat-sources";
import styles from "./chat-sources.module.css";
type Inventory = {
  inventory_id: string;
  name: string;
  can_edit: boolean;
  spaces: { id: string; name: string }[];
};
export function ChatCaptureCard({
  capture,
  accountId,
  worldId,
  conversationId,
  onChanged,
}: {
  capture: ChatCapture;
  accountId: string;
  worldId: string;
  conversationId: string;
  onChanged?: (capture: ChatCapture) => void;
}) {
  const [draft, setDraft] = useState(capture),
    [inventories, setInventories] = useState<Inventory[]>([]),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [duplicates, setDuplicates] = useState(false),
    [allowDuplicates, setAllowDuplicates] = useState(false),
    [refreshRequired, setRefreshRequired] = useState(false),
    [page, setPage] = useState(0);
  const live = useRef(true),
    lock = useRef(false);
  const prefix = `/worlds/${encodeURIComponent(worldId)}`,
    url = `${prefix}/conversations/${encodeURIComponent(conversationId)}/captures/${capture.id}`;
  useEffect(() => {
    live.current = true;
    return () => {
      live.current = false;
    };
  }, []);
  useEffect(() => {
    setDraft(capture);
  }, [capture]);
  useEffect(() => {
    let active = true;
    void accountRequest<{ inventories: Inventory[] }>(
      accountId,
      `${prefix}/spaces`,
    )
      .then((r) => {
        if (active) setInventories(r.inventories.filter((i) => i.can_edit));
      })
      .catch((e) => {
        if (active)
          setError(userFacingError(e, "Could not load destinations."));
      });
    return () => {
      active = false;
    };
  }, [accountId, prefix]);
  async function act(method: "GET" | "PATCH" | "POST", changes?: unknown) {
    if (lock.current) return;
    lock.current = true;
    setBusy(true);
    setError("");
    try {
      const r = await accountRequest<{ capture: unknown }>(
        accountId,
        url + (method === "POST" ? "/save" : ""),
        {
          method,
          ...(method !== "GET"
            ? {
                body:
                  method === "POST"
                    ? {
                        revision: draft.revision,
                        allow_duplicates: allowDuplicates,
                      }
                    : { revision: draft.revision, changes },
              }
            : {}),
        },
      );
      const verified = parseCapture(r.capture);
      if (!verified || verified.id !== draft.id)
        throw new Error(
          "The draft result could not be verified. Refresh its status.",
        );
      if (live.current) {
        setDraft(verified);
        onChanged?.(verified);
        setRefreshRequired(false);
        setDuplicates(false);
        setAllowDuplicates(false);
      }
    } catch (e) {
      if (live.current) {
        setError(
          userFacingError(
            e,
            "This draft could not be updated. Refresh its status before retrying.",
          ),
        );
        const detail = e instanceof ApiError ? e.limitData : null;
        const duplicate =
          !!detail &&
          typeof detail === "object" &&
          "code" in detail &&
          detail.code === "capture_duplicates";
        setDuplicates(duplicate);
        setRefreshRequired(!duplicate);
      }
    } finally {
      lock.current = false;
      if (live.current) setBusy(false);
    }
  }
  const frozen = busy || refreshRequired || draft.status !== "draft",
    missing = draft.items.filter((row) => row.selected && (draft.summary?.unknown_quantity_indices?.includes(row.index) || hasUnknownQuantity(row.item.scan_evidence)));
  return (
    <section className={styles.card} aria-label="Extraction draft">
      <header>
        <h3>
          {draft.source_kind === "spreadsheet"
            ? "Inventory import"
            : draft.source_kind === "barcode"
              ? "Barcode result"
              : draft.source_kind === "text" ? "Inventory draft" : "Auto Extract"}
        </h3>
        <p className={styles.muted}>
          {draft.items.length} candidates. Review identities and quantities
          before saving.
        </p>
      </header>
      {error && <p role="alert">{error}</p>}
      {draft.receipt && (
        <div role="status">
          <p>
            {draft.receipt.saved_count} saved · {draft.receipt.review_count}{" "}
            need review · {draft.receipt.failures.length} failed
          </p>
          {draft.receipt.failures.map((f, i) => (
            <p key={i}>
              Row {f.index + 1}:{" "}
              {f.reason || f.error || "Could not save. Retry this draft."}
            </p>
          ))}
        </div>
      )}
      {draft.status === "saved" ? (
        <>
          <p>
            Saved to {draft.destination_label} / {draft.location}.
          </p>
          <Link
            href={`/inventory?${new URLSearchParams({ inventory: draft.inventory_id || "", space: draft.location || "" })}`}
          >
            View items
          </Link>
          {!!draft.receipt?.review_count && (
            <Link
              href={`/review?inventory=${encodeURIComponent(draft.inventory_id || "")}`}
            >
              Review uncertain items
            </Link>
          )}
        </>
      ) : (
        <>
          <div className={styles.rows}>
            {draft.items.slice(page * 20, page * 20 + 20).map((row) => (
              <CaptureItem
                key={`${draft.revision}:${row.index}`}
                row={row}
                quantityMissing={!!(draft.summary?.unknown_quantity_indices?.includes(row.index) || hasUnknownQuantity(row.item.scan_evidence))}
                disabled={frozen}
                onChange={(changes) =>
                  void act("PATCH", {
                    items: [{ index: row.index, ...changes }],
                  })
                }
              />
            ))}
          </div>
          {draft.items.length > 20 && (
            <div className={styles.actions}>
              <button
                className="workspace-button"
                disabled={busy || page === 0}
                onClick={() => setPage((v) => v - 1)}
              >
                Previous
              </button>
              <span>
                {page + 1} / {Math.ceil(draft.items.length / 20)}
              </span>
              <button
                className="workspace-button"
                disabled={busy || (page + 1) * 20 >= draft.items.length}
                onClick={() => setPage((v) => v + 1)}
              >
                Next
              </button>
            </div>
          )}
          <div className={styles.stack}>
            <label>
              Save to
              <select
                value={draft.space_id ? `${draft.inventory_id}:${draft.space_id}` : ""}
                disabled={frozen}
                onChange={(e) => {
                  const [inventory_id, space_id] = e.target.value.split(":");
                  void act("PATCH", { inventory_id, space_id });
                }}
              >
                <option value="" disabled>Choose a Space</option>
                {inventories.map((i) => (
                  <optgroup key={i.inventory_id} label={i.name}>
                    {i.spaces.map((s) => <option key={s.id} value={`${i.inventory_id}:${s.id}`}>{s.name}</option>)}
                  </optgroup>
                ))}
              </select>
            </label>
          </div>
          {!!missing.length && <p role="status">Add a quantity for {missing.map((r) => r.item.name).join(", ")}, or uncheck those items to save the rest.</p>}
          {!inventories.length && (
            <p className={styles.muted}>
              Create an inventory and Space in chat, or ask an owner for edit
              access, then reopen this draft.
            </p>
          )}
          {duplicates && (
            <label>
              <input
                type="checkbox"
                checked={allowDuplicates}
                onChange={(e) => setAllowDuplicates(e.target.checked)}
              />{" "}
              Save these as separate items despite possible matches
            </label>
          )}
          <div className={styles.actions}>
            <button
              className="workspace-button"
              disabled={busy}
              onClick={() => void act("GET")}
            >
              Refresh status
            </button>
            <button
              className="workspace-button primary"
              disabled={
                busy ||
                refreshRequired ||
                !draft.space_id ||
                missing.length > 0 ||
                !draft.items.some((i) => i.selected) ||
                (duplicates && !allowDuplicates)
              }
              onClick={() => void act("POST")}
            >
              {busy
                ? "Working..."
                : draft.status === "saving"
                  ? "Continue saving this draft"
                  : "Confirm and save"}
            </button>
          </div>
        </>
      )}
    </section>
  );
}
function CaptureItem({
  row,
  quantityMissing,
  disabled,
  onChange,
}: {
  row: CaptureRow;
  quantityMissing: boolean;
  disabled: boolean;
  onChange: (value: Record<string, unknown>) => void;
}) {
  const [name, setName] = useState(row.item.name),
    [quantity, setQuantity] = useState(quantityMissing ? "" : String(row.item.quantity));
  const [details, setDetails] = useState({
    category: row.item.category,
    brand: row.item.brand || "",
    part_number: row.item.part_number || "",
    notes: row.item.notes || "",
  });
  return (
    <div className={styles.row}>
      <input
        type="checkbox"
        aria-label={`Include ${row.item.name}`}
        checked={row.selected}
        disabled={disabled}
        onChange={(e) => onChange({ selected: e.target.checked })}
      />
      <input
        aria-label={`Name for row ${row.index + 1}`}
        value={name}
        maxLength={200}
        disabled={disabled}
        onChange={(e) => setName(e.target.value)}
        onBlur={() => {
          if (name.trim() && name !== row.item.name)
            onChange({ name: name.trim() });
          else if (!name.trim()) setName(row.item.name);
        }}
      />
      <input
        aria-label={`Quantity for ${row.item.name}`}
        placeholder="Quantity needed"
        aria-invalid={quantityMissing && row.selected}
        type="number"
        min={0}
        max={100000}
        step={1}
        value={quantity}
        disabled={disabled}
        onChange={(e) => setQuantity(e.target.value)}
        onBlur={() => {
          const n = Number(quantity);
          if (
            quantity !== "" &&
            Number.isInteger(n) &&
            n >= 0 &&
            n <= 100000 &&
            (quantityMissing || n !== row.item.quantity)
          )
            onChange({ quantity: n });
          else setQuantity(quantityMissing ? "" : String(row.item.quantity));
        }}
      />
      {row.item.scan_evidence?.needs_review && (
        <small>
          Uncertain identification or count.{" "}
          {(row.item.scan_evidence.review_reasons || []).join(" ")}
        </small>
      )}
      <details>
        <summary>Item details</summary>
        {(Object.keys(details) as (keyof typeof details)[]).map((field) => (
          <label key={field}>
            {field.replaceAll("_", " ")}
            <input
              value={details[field]}
              maxLength={field === "notes" ? 2000 : 100}
              disabled={disabled}
              onChange={(e) =>
                setDetails((v) => ({ ...v, [field]: e.target.value }))
              }
              onBlur={() => {
                if (
                  details[field] !== String(row.item[field] || "") &&
                  (field !== "category" || details[field].trim())
                )
                  onChange({ [field]: details[field] });
              }}
            />
          </label>
        ))}
      </details>
    </div>
  );
}
