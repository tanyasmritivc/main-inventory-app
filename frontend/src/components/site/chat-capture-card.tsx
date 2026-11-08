"use client";
import { PhotoScanHint } from "./photo-scan-hint";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
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
import scan from "./chat-capture.module.css";
import { Check, ChevronDown, ImageIcon, Pencil, RefreshCw, ScanLine, X } from "lucide-react";
import { privateImageSrc } from "@/lib/private-image";
import { DropdownMenu, DropdownMenuContent, DropdownMenuTrigger, DropdownMenuItem, DropdownMenuLabel } from "@/components/ui/dropdown-menu";

// Presentation reads optional fields already preserved by parseCapture. It never
// changes the API model, the canonical row index, or the saved item values.
function fields(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? value as Record<string, unknown> : {};
}
export function captureConfidence(row: CaptureRow): number | undefined {
  const value = fields(row.item).confidence;
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1 ? value : undefined;
}
export function captureUnknown(row: CaptureRow): boolean {
  return !row.item.name.trim() || /^(unknown( item| object)?|unidentified( item| object)?|object|item)$/i.test(row.item.name.trim()) || (captureConfidence(row) ?? 1) < .5;
}
export function captureMissing(row: CaptureRow, capture: ChatCapture): boolean {
  return !!(capture.summary?.unknown_quantity_indices?.includes(row.index) || hasUnknownQuantity(row.item.scan_evidence));
}
export function captureDisplayRows(capture: ChatCapture): CaptureRow[] {
  const rank = (row: CaptureRow) => captureUnknown(row) ? 3 : captureMissing(row, capture) || !row.item.category.trim() ? 2 : row.item.scan_evidence?.needs_review ? 1 : 0;
  const scored = capture.items.every(row => captureConfidence(row) !== undefined);
  return [...capture.items].sort((a, b) => {
    if (captureUnknown(a) !== captureUnknown(b)) return Number(captureUnknown(a)) - Number(captureUnknown(b));
    const ac = captureConfidence(a), bc = captureConfidence(b);
    if (scored && ac !== undefined && bc !== undefined) return bc - ac || a.index - b.index;
    return rank(a) - rank(b) || a.index - b.index;
  });
}
export function captureDetails(row: CaptureRow): string {
  const item = fields(row.item);
  return [item.brand || item.maker, item.model, item.colour || item.color, item.material, item.size, item.condition, item.description || item.notes]
    .filter((v): v is string => typeof v === "string" && !!v.trim()).join(" · ");
}
export function mapCaptureBox(box: {x: number; y: number; width: number; height: number}, image: {width: number; height: number}, frame: {width: number; height: number}) {
  if (![image.width, image.height, frame.width, frame.height, box.width, box.height].every(n => Number.isFinite(n) && n > 0) || ![box.x, box.y].every(Number.isFinite)) return null;
  const scale = Math.min(frame.width / image.width, frame.height / image.height);
  return {left: (frame.width - image.width * scale) / 2 + box.x * scale, top: (frame.height - image.height * scale) / 2 + box.y * scale, width: box.width * scale, height: box.height * scale};
}
function photoField(value: unknown, key: string, accountId?: string) {
  const source = fields(value)[key];
  if (typeof source !== "string") return undefined;
  // Use the existing authenticated image proxy; never fetch arbitrary URLs from a result.
  const safe = privateImageSrc(source, accountId);
  return safe?.startsWith("/api/private-image?") ? safe : undefined;
}
function CaptureThumb({row, photo, number, accountId}: {row: CaptureRow; photo?: string; number?: number; accountId: string}) {
  const src = photoField(row.item, "image_url", accountId) || photo;
  return <span className={scan.thumb}>{src ? <Image unoptimized src={src} alt="" width={52} height={52} /> : <ImageIcon size={20} aria-hidden="true" />}{number !== undefined && <span>{number}</span>}</span>;
}
// Fractions represent completed pipeline stages and reported object counts,
// never elapsed time. Unknown phases keep the last confirmed progress.
export function captureProgress(steps: string[]): number {
  let value = 0;
  for (const step of steps) {
    if (/preparing/i.test(step)) value = Math.max(value, 1 / 5);
    if (/extracting|finding objects/i.test(step)) value = Math.max(value, 2 / 5);
    const checked = step.match(/checked\s+(\d+)\s+of\s+(\d+)\s+objects/i);
    if (checked && Number(checked[2]) > 0) value = Math.max(value, 3 / 5 + Math.min(1, Number(checked[1]) / Number(checked[2])) / 5);
  }
  return value;
}
export function CaptureScan({photo, steps, stopped, failed, onClose, onRetry}: {photo: string; steps: string[]; stopped: boolean; failed: boolean; onClose: () => void; onRetry: () => void}) {
  const status = stopped ? "Scan stopped. Nothing was saved." : failed ? "Scan could not finish. Nothing was saved." : (steps.at(-1) || "Reading your photo...").replaceAll("…", "...");
  return <section className={scan.card} aria-label="Review extraction">
    <header className={scan.header}><ScanLine size={18} /><h3>Review extraction</h3><button className={scan.icon} aria-label="Close extraction" onClick={onClose}><X size={15}/></button></header>
    <div className={scan.body}>
      <div className={scan.photo}><Image unoptimized src={photo} alt="Photo being scanned" width={286} height={384} />{!failed && <span className={scan.sweep}/>}</div>
      <div className={scan.side}>
        <div className={scan.live}><span className={!failed ? scan.spinner : undefined}/><span role="status">{status}</span><details className={scan.steps}><summary>Steps <ChevronDown size={14}/></summary><ol>{steps.map((step, i) => <li key={i}>{i < steps.length - 1 ? <Check size={13}/> : <span>···</span>}{step.replaceAll("…", "...")}</li>)}</ol></details></div>
        {!failed && <div className={scan.track} role="progressbar" aria-label="Extraction progress" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(captureProgress(steps) * 100)} aria-valuetext={status}><i style={{transform: `scaleX(${captureProgress(steps)})`}}/></div>}
        {!failed && !stopped && <PhotoScanHint tips={false} />}
        <p className={scan.safe}>Nothing is saved until you choose Save.</p>
        {failed ? <button className={scan.button} onClick={onRetry}><RefreshCw size={15}/> Scan again</button> : <div className={scan.placeholders} aria-hidden="true">{[0,1,2].map(n => <div key={n}><span/><div><i/><i/></div></div>)}</div>}
      </div>
    </div>
  </section>;
}
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
  photo,
  onClose,
  fixedDestination,
}: {
  capture: ChatCapture;
  accountId: string;
  worldId: string;
  conversationId: string;
  onChanged?: (capture: ChatCapture) => void;
  photo?: string;
  onClose?: () => void;
  fixedDestination?: {inventoryId: string; spaceId: string};
}) {
  const [draft, setDraft] = useState(capture),
    [inventories, setInventories] = useState<Inventory[]>([]),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [duplicates, setDuplicates] = useState(false),
    [allowDuplicates, setAllowDuplicates] = useState(false),
    [refreshRequired, setRefreshRequired] = useState(false),
    [page, setPage] = useState(0);
  const [activeRow, setActiveRow] = useState<number>();
  const [editing, setEditing] = useState<number>();
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
      if (method === "POST" && fixedDestination &&
          (draft.inventory_id !== fixedDestination.inventoryId || draft.space_id !== fixedDestination.spaceId))
        throw new Error("The destination changed. Reopen this extraction from its Space.");
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
                        confirm_items: true,
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
  const isPhoto = draft.source_kind === "photo" || !!photo;
  const sourcePhoto = photo || photoField(draft, "source_url", accountId) || photoField(draft.items[0]?.item, "source_frame_url", accountId);
  const displayRows = isPhoto ? captureDisplayRows(draft) : draft.items;
  const unknownCount = displayRows.filter(captureUnknown).length;
  const selected = draft.items.filter(row => row.selected).length;
  const title = isPhoto ? "Review extraction" : draft.source_kind === "spreadsheet" ? "Inventory import" : draft.source_kind === "barcode" ? "Barcode result" : "Inventory draft";
  const rows = <div className={scan.list} role="list" aria-label="Extracted items">
    {displayRows.slice(page * 20, page * 20 + 20).map((row, position) => {
      const number = page * 20 + position + 1;
      const uncertain = captureUnknown(row);
      const firstUnknown = uncertain && !captureUnknown(displayRows[number - 2] || row) || uncertain && number === 1;
      const confidence = captureConfidence(row);
      const name = row.item.name || "Unknown item";
      return <div key={row.index} role="listitem">
        {isPhoto && firstUnknown && <p className={scan.unknown}>{unknownCount === 1 ? "Not sure about this one" : "Not sure about these"}</p>}
        <div className={scan.row} data-active={activeRow === row.index || undefined} style={{animationDelay: `${Math.min(position, 12) * .25}s`}}>
          <input type="checkbox" className={scan.checkbox} aria-label={`Include ${name}`} checked={row.selected} disabled={frozen} onChange={e => void act("PATCH", {items: [{index: row.index, selected: e.target.checked}]})}/>
          <button className={scan.rowDetail} aria-label={`${number}. ${name}. ${captureDetails(row)}. ${row.item.category}. ${captureMissing(row, draft) ? "Quantity needed" : `Qty ${row.item.quantity}`}${confidence !== undefined ? `. ${confidence >= .85 ? "Confident" : confidence >= .6 ? "Likely" : "Not sure"}` : ""}${row.item.scan_evidence?.needs_review ? ". Needs review" : ""}`} onClick={() => setActiveRow(row.index)}>
            <CaptureThumb row={row} photo={sourcePhoto} number={number} accountId={accountId}/>
            <span className={scan.text}><b>{name}</b>{captureDetails(row) && <span className={scan.detail}>{captureDetails(row)}</span>}<small>{row.item.category} · {captureMissing(row, draft) ? "Quantity needed" : `Qty ${row.item.quantity}`}</small>
              <span className={scan.tags}>{confidence !== undefined && <span className={scan.confidence}><i style={{background: confidence >= .85 ? "#34C759" : confidence >= .6 ? "#E3B45C" : "#8E8E93"}}/>{confidence >= .85 ? "Confident" : confidence >= .6 ? "Likely" : "Not sure"}</span>}{row.item.scan_evidence?.needs_review && <span className={scan.warning}>Needs review</span>}</span>
            </span>
          </button>
          <button className={scan.icon} disabled={frozen} aria-label={`Edit ${name}`} aria-expanded={editing === row.index} onClick={() => setEditing(editing === row.index ? undefined : row.index)}><Pencil size={16}/></button>
        </div>
        {editing === row.index && <div className={scan.editor}><CaptureItem key={`${draft.revision}:${row.index}`} row={row} quantityMissing={captureMissing(row, draft)} disabled={frozen} onChange={changes => void act("PATCH", {items: [{index: row.index, ...changes}]})}/></div>}
      </div>;
    })}
  </div>;
  return <section className={scan.card} aria-label="Extraction draft">
    <header className={scan.header}><ScanLine size={18}/><h3>{title}</h3>{onClose && <button className={scan.icon} aria-label="Close extraction" onClick={onClose}><X size={15}/></button>}</header>
    {error && <p className={scan.notice} role="alert">{error}</p>}
    {draft.receipt && <div className={scan.notice} role="status"><p>{draft.receipt.saved_count} saved · {draft.receipt.review_count} need review · {draft.receipt.failures.length} failed</p>{draft.receipt.failures.map((f, i) => <p key={i}>Row {f.index + 1}: {f.reason || f.error || "Could not save. Retry this draft."}</p>)}</div>}
    {draft.status === "saved" ? <div className={scan.saved}><Check size={24}/><p>Saved to {draft.destination_label} / {draft.location}.</p><div className={scan.savedThumbs}>{draft.items.filter(row => row.selected).slice(0,3).map(row => <CaptureThumb key={row.index} row={row} photo={sourcePhoto} accountId={accountId}/>)}</div><Link href={`/inventory?${new URLSearchParams({ inventory: draft.inventory_id || "", space: draft.location || "" })}`}>View items</Link>{!!draft.receipt?.review_count && <Link href={`/review?inventory=${encodeURIComponent(draft.inventory_id || "")}`}>Review uncertain items</Link>}</div> : <>
      <div className={scan.body} data-photo={!!sourcePhoto || undefined}>
        {sourcePhoto && <div className={scan.photo}><Image unoptimized src={sourcePhoto} alt="Source photo for this extraction" width={286} height={384}/></div>}
        <div className={scan.side}><div className={scan.reviewHeader}><span>{selected} of {draft.items.length} selected · Not saved yet</span><button className={scan.icon} aria-label="Refresh status" title="Refresh status" disabled={busy} onClick={() => void act("GET")}><RefreshCw size={16}/></button></div>
          {rows}
          {draft.items.length > 20 && <div className={scan.pagination}><button disabled={busy || page === 0} onClick={() => setPage(v => v-1)}>Previous</button><span>{page+1} / {Math.ceil(draft.items.length / 20)}</span><button disabled={busy || (page+1)*20 >= draft.items.length} onClick={() => setPage(v => v+1)}>Next</button></div>}
        </div>
      </div>
      <div className={scan.footer}>
        <div><p>{draft.items.length} candidates. Save as-is or edit identities and quantities.</p>{!!missing.length && <p role="status">Uncounted items keep 1 as a placeholder. You can edit them after saving.</p>}{!inventories.length && <p>Create an inventory and Space in chat, or ask an owner for edit access, then reopen this draft.</p>}</div>
        <div className={scan.footerActions}>
          <DropdownMenu><DropdownMenuTrigger asChild><button className={draft.space_id ? scan.chip : scan.button} disabled={frozen || !!fixedDestination} aria-label="Choose a Space">{draft.space_id ? draft.location || inventories.flatMap(i => i.spaces).find(space => space.id === draft.space_id)?.name || "Choose a Space" : "Choose a Space"}<ChevronDown size={14}/></button></DropdownMenuTrigger><DropdownMenuContent side="top" align="end" sideOffset={8} className={scan.spaceMenu}>{inventories.map(i => <div key={i.inventory_id}><DropdownMenuLabel>{i.name}</DropdownMenuLabel>{i.spaces.map(space => <DropdownMenuItem key={space.id} onSelect={() => void act("PATCH", {inventory_id: i.inventory_id, space_id: space.id})}>{space.name}{draft.space_id === space.id && <Check size={14}/>}</DropdownMenuItem>)}</div>)}{!inventories.length && <DropdownMenuLabel>No editable Spaces</DropdownMenuLabel>}</DropdownMenuContent></DropdownMenu>
          {draft.space_id && <button className={scan.button} disabled={busy || refreshRequired || !draft.items.some(i => i.selected) || (duplicates && !allowDuplicates)} onClick={() => void act("POST")}>{busy ? "Working..." : draft.status === "saving" ? "Continue saving this draft" : "Confirm and save"}</button>}
        </div>
      </div>
      {duplicates && <label className={scan.notice}><input type="checkbox" checked={allowDuplicates} onChange={e => setAllowDuplicates(e.target.checked)}/> Save these as separate items despite possible matches</label>}
    </>}
  </section>;
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
