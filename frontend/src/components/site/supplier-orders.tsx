"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { Upload, FileSpreadsheet, PackageOpen } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  spreadsheetAccept,
  spreadsheetFileError,
  spreadsheetFileHint,
} from "@/lib/spreadsheet-file";
import Link from "next/link";
import {
  OrderColumnMapping,
  type Assignment,
  type SourceTable,
} from "./order-column-mapping";
import { apiBase } from "@/lib/api";
import { accountToken, accountRequest } from "@/lib/account-request";
import { PageHeader } from "./app-theme-ui";
import styles from "./supplier-orders.module.css";

export type OrderSpace = {
  space_id?: string;
  inventory_id: string;
  name: string;
  can_edit: boolean;
};
type Draft = {
  status: string;
  order: string;
  line: string;
  sku: string;
  name: string;
  quantity: string;
  pack: string;
  source_file: string;
  source_sheet: string;
  source_row: number;
};
type Match = {
  sku: string;
  name: string;
  item_id: string;
  item_name: string;
  space_name: string;
  location?: string;
  recorded_quantity: number | null;
};
type Preview = {
  space_review?: { duplicate: boolean; matches: Match[] };
  digest: string;
  rows: Draft[];
  documents: string[];
  tables: SourceTable[];
  assignments: Assignment[];
};
type Order = {
  order_space_id?: string;
  order_space_name?: string;
  id: string;
  order_number: string;
  line_key: string;
  supplier: string;
  name: string;
  sku: string;
  ordered: number;
  received: number;
  cancelled: number;
  historical: boolean;
  outstanding: number | null;
  source_file: string;
  source_status: string;
  source_id: string;
  recent_receipts: {
    action: string;
    quantity: number;
    space_name: string | null;
    created_at: string;
  }[];
};
type Stock = {
  item_id: string;
  name: string;
  recorded_quantity: number;
  location: string;
  space_name: string;
  part_number: string | null;
};
type Results = {
  order_lines: Order[];
  recorded_inventory: Stock[];
  has_more: boolean;
  can_manage: boolean;
  space_orders_supported?: boolean;
  order_scope_id?: string;
};
type Props = {
  accountId: string;
  world: string;
  spaces: OrderSpace[];
  initialSpace?: string;
};
const fields = {
  order: "Order number",
  line: "Supplier line ID",
  sku: "SKU",
  name: "Part description",
  quantity: "Quantity purchased",
  pack: "Units per pack",
};
const message = (e: unknown) =>
  e instanceof Error ? e.message : "Please retry.";

function readyOrderLines(rows: Draft[]) {
  return (
    rows.length > 0 &&
    rows.every(
      (r) =>
        r.order.trim() &&
        r.line.trim() &&
        r.name.trim() &&
        [r.quantity, r.pack].every((n) => /^\d+$/.test(n) && Number(n) > 0) &&
        [
          "unknown",
          "ordered",
          "shipped",
          "delivered",
          "cancelled",
          "returned",
        ].includes(r.status),
    )
  );
}

function ImportOrder({
  accountId,
  path,
  saved,
  spaceId,
  onBusy,
}: {
  onBusy: (value: boolean) => void;
  spaceId?: string;
  accountId: string;
  path: string;
  saved: (s: string) => void;
}) {
  const [supplier, setSupplier] = useState(""),
    [file, setFile] = useState<File>(),
    [source, setSource] = useState<Preview>();
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [mapped, setMapped] = useState(false);
  const [historical, setHistorical] = useState(true),
    [rows, setRows] = useState<Draft[]>([]);
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const lock = useRef(false),
    input = useRef<HTMLInputElement>(null);

  function form(selected: File) {
    const body = new FormData();
    body.append("file", selected);
    if (spaceId) body.append("space_id", spaceId);
    return body;
  }
  async function storeOrder(selected: File, preview: Preview, lines: Draft[]) {
    const body = form(selected);
    body.append("supplier", supplier.trim());
    body.append("digest", preview.digest);
    body.append("historical", String(historical));
    body.append("assignments", JSON.stringify(preview.assignments));
    body.append("rows", JSON.stringify(lines));
    const result = await accountRequest<{ created: number }>(
      accountId,
      path + "/import",
      { method: "POST", body },
    );
    saved(
      result.created
        ? `Imported ${result.created} order ${result.created === 1 ? "line" : "lines"}.`
        : "These order lines were already recorded.",
    );
  }
  async function readFile(selected: File, remap = false) {
    if (lock.current) return;
    setError("");
    if (!remap) {
      setSource(undefined);
      setRows([]);
      setAssignments([]);
      setMapped(false);
      setFile(undefined);
    }
    const invalid = spreadsheetFileError(selected);
    if (invalid) {
      setError(invalid);
      return;
    }
    lock.current = true;
    onBusy(true);
    setFile(selected);
    setBusy(true);
    try {
      const body = form(selected);
      if (remap) body.append("assignments", JSON.stringify(assignments));
      const next = await accountRequest<Preview>(accountId, path + "/preview", {
        method: "POST",
        body,
      });
      if (spaceId && !next.space_review)
        throw Error("Space order imports are unavailable on this server.");
      setSource(next);
      setAssignments(next.assignments);
      setRows(next.rows);
      setMapped(true);
      if (
        !remap &&
        supplier.trim() &&
        !next.space_review?.duplicate &&
        readyOrderLines(next.rows)
      ) {
        await storeOrder(selected, next, next.rows);
      }
    } catch (err) {
      setError(message(err));
    } finally {
      lock.current = false;
      setBusy(false);
      onBusy(false);
    }
  }
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!file || lock.current || source?.space_review?.duplicate) return;
    if (!source || !mapped) {
      await readFile(file, !!source);
      return;
    }
    lock.current = true;
    onBusy(true);
    setBusy(true);
    setError("");
    try {
      await storeOrder(file, source, rows);
    } catch (err) {
      setError(message(err));
    } finally {
      lock.current = false;
      setBusy(false);
      onBusy(false);
    }
  }
  return (
    <form onSubmit={submit}>
      <fieldset disabled={busy}>
        <div className={styles.grid}>
          <label>
            Supplier
            <input
              required={!!source && mapped}
              maxLength={120}
              value={supplier}
              onChange={(e) => setSupplier(e.target.value)}
              placeholder="Supplier name"
            />
          </label>
          <label>
            Order status
            <select
              value={historical ? "history" : "open"}
              onChange={(e) => setHistorical(e.target.value === "history")}
            >
              <option value="history">Purchase history only</option>
              <option value="open">Open order to receive</option>
            </select>
          </label>
        </div>
        <label className={styles.filePicker}>
          <FileSpreadsheet aria-hidden="true" size={26} />
          <strong>{file?.name || "Choose spreadsheet"}</strong>
          <small>{spreadsheetFileHint} Up to 500 order lines.</small>
          <input
            ref={input}
            aria-label="Order file"
            type="file"
            accept={spreadsheetAccept}
            onChange={(e) => {
              const selected = e.target.files?.[0];
              e.target.value = "";
              if (selected) void readFile(selected);
            }}
          />
        </label>
        {busy && <p role="status">Importing spreadsheet…</p>}
        {source?.space_review?.duplicate && (
          <p role="status">
            This file is already in organization Orders. Choose a different file
            to import another order.
          </p>
        )}
        {source && !source.space_review?.duplicate && !mapped && (
          <>
            {source.tables.map((t, i) => (
              <OrderColumnMapping
                key={JSON.stringify([t.file, t.sheet])}
                table={t}
                config={assignments[i]}
                update={(c) =>
                  setAssignments((old) => old.map((v, n) => (n === i ? c : v)))
                }
              />
            ))}
          </>
        )}
        {source && mapped && !source.space_review?.duplicate && (
          <>
            {!!source.tables.length && (
              <button type="button" onClick={() => setMapped(false)}>
                Adjust column mapping
              </button>
            )}
            {rows.length > 1 && (
              <details>
                <summary>Fill blank values across reviewed lines</summary>
                {(["order", "pack"] as const).map((k) => (
                  <label key={k}>
                    {fields[k]} for blank lines
                    <input
                      onKeyDown={(e) => {
                        if (e.key === "Enter") e.preventDefault();
                      }}
                      onBlur={(e) => {
                        const value = e.target.value.trim();
                        if (value)
                          setRows((old) =>
                            old.map((r) => (r[k] ? r : { ...r, [k]: value })),
                          );
                        e.target.value = "";
                      }}
                      placeholder="Enter a value, then leave this field"
                    />
                  </label>
                ))}
              </details>
            )}
            {rows.map((row, i) => (
              <div className={styles.panel} key={i}>
                <small>
                  {row.source_file} {row.source_sheet} · Row {row.source_row}
                </small>
                <div className={styles.grid}>
                  {(Object.keys(fields) as (keyof typeof fields)[]).map((k) => (
                    <label key={k}>
                      {fields[k]}
                      <input
                        required={k !== "sku"}
                        type={
                          k === "quantity" || k === "pack" ? "number" : "text"
                        }
                        min={1}
                        step={1}
                        value={row[k]}
                        onChange={(e) =>
                          setRows((old) =>
                            old.map((r, n) =>
                              n === i ? { ...r, [k]: e.target.value } : r,
                            ),
                          )
                        }
                      />
                    </label>
                  ))}
                </div>
                {source.space_review?.matches
                  .filter((m) => m.sku === row.sku && m.name === row.name)
                  .map((m) => (
                    <p key={m.item_id}>
                      Possible inventory match · {m.item_name} ·{" "}
                      {m.recorded_quantity ?? "Unknown quantity"} recorded in{" "}
                      {m.space_name}
                      {m.location && m.location !== m.space_name
                        ? " · " + m.location
                        : ""}
                    </p>
                  ))}
                <label>
                  Supplier status
                  <select
                    value={row.status}
                    onChange={(e) =>
                      setRows((old) =>
                        old.map((r, n) =>
                          n === i ? { ...r, status: e.target.value } : r,
                        ),
                      )
                    }
                  >
                    {Array.from(
                      new Set([
                        row.status,
                        "unknown",
                        "ordered",
                        "shipped",
                        "delivered",
                        "cancelled",
                        "returned",
                      ]),
                    ).map((status) => (
                      <option key={status}>{status}</option>
                    ))}
                  </select>
                </label>
                <button
                  type="button"
                  onClick={() =>
                    setRows((old) => old.filter((_, n) => n !== i))
                  }
                >
                  Exclude line
                </button>
              </div>
            ))}
          </>
        )}
        {file && !source?.space_review?.duplicate && (
          <button
            className="workspace-button primary"
            disabled={busy || (!!source && mapped && !rows.length)}
          >
            {source
              ? mapped
                ? "Import order"
                : "Apply column mapping"
              : "Retry spreadsheet"}
          </button>
        )}
        {error && <p role="alert">{error}</p>}
      </fieldset>
    </form>
  );
}

function OriginalFields({
  accountId,
  path,
  line,
}: {
  accountId: string;
  path: string;
  line: string;
}) {
  type Source = {
    file: string;
    sheet: string;
    row: number;
    original: {
      headers: string[];
      cells: string[];
      mapping: Record<string, number>;
    } | null;
  };
  const [source, setSource] = useState<Source>(),
    [error, setError] = useState("");
  async function load() {
    try {
      setError("");
      setSource(
        await accountRequest<Source>(accountId, path + "/" + line + "/fields"),
      );
    } catch (e) {
      setError(message(e));
    }
  }
  return (
    <div>
      <button onClick={() => void load()}>View original columns</button>
      {error && <p role="alert">{error}</p>}
      {source && (
        <>
          <p>
            {source.file} {source.sheet} · Row {source.row}
          </p>
          {source.original ? (
            <dl>
              {Array.from(
                {
                  length: Math.max(
                    source.original.headers.length,
                    source.original.cells.length,
                  ),
                },
                (_, i) => (
                  <div key={i}>
                    <dt>
                      {i + 1}. {source.original?.headers[i] || "(unnamed)"}
                    </dt>
                    <dd>{source.original?.cells[i] || "Empty"}</dd>
                  </div>
                ),
              )}
            </dl>
          ) : (
            <p>This line was entered manually from the attached file.</p>
          )}
        </>
      )}
    </div>
  );
}

function Receive({
  accountId,
  path,
  line,
  spaces,
  saved,
}: {
  accountId: string;
  path: string;
  line: Order;
  spaces: OrderSpace[];
  saved: (s: string) => void;
}) {
  const [action, setAction] = useState(
      line.historical ? "already_counted" : "receive",
    ),
    [space, setSpace] = useState(line.order_space_id || "");
  const [query, setQuery] = useState(""),
    [item, setItem] = useState(""),
    [qty, setQty] = useState("");
  const [items, setItems] = useState<Stock[]>([]),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const lock = useRef(false);
  const destination = spaces.find(
    (s) => (s.space_id || s.inventory_id) === space,
  );
  const inventoryId = destination?.inventory_id,
    spaceId = destination?.space_id;
  const remaining = line.ordered - line.received - line.cancelled;
  useEffect(() => {
    setItems([]);
    setItem("");
    setError("");
    if (!inventoryId || action === "cancel") return;
    const c = new AbortController();
    const timer = setTimeout(() => {
      accountRequest<{ items: Stock[] }>(
        accountId,
        path +
          "/items?" +
          new URLSearchParams({
            inventory_id: inventoryId,
            ...(spaceId ? { space_id: spaceId } : {}),
            query,
          }),
        { signal: c.signal },
      )
        .then((r) => {
          if (!c.signal.aborted) setItems(r.items);
        })
        .catch((e) => {
          if (!c.signal.aborted) setError(message(e));
        });
    }, 150);
    return () => {
      clearTimeout(timer);
      c.abort();
    };
  }, [accountId, path, query, inventoryId, spaceId, action]);
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (lock.current) return;
    lock.current = true;
    setBusy(true);
    setError("");
    try {
      const data = {
        action,
        quantity: Number(qty),
        inventory_id: action === "cancel" ? null : inventoryId,
        space_id: action === "cancel" ? null : spaceId,
        item_id: action === "cancel" ? null : item,
      };
      const key = [
        "order-receipt",
        accountId,
        path,
        line.id,
        JSON.stringify(data),
      ].join("/");
      const requestId = sessionStorage.getItem(key) || crypto.randomUUID();
      sessionStorage.setItem(key, requestId);
      await accountRequest(accountId, path + "/" + line.id + "/receipts", {
        method: "POST",
        body: { ...data, request_id: requestId },
      });
      sessionStorage.removeItem(key);
      setQty("");
      saved(
        action === "receive"
          ? "Receipt saved and stock updated."
          : "Order updated. Stock quantities are unchanged.",
      );
    } catch (e) {
      setError(message(e));
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  return (
    <form onSubmit={submit}>
      <fieldset disabled={busy}>
        <label>
          Record an action
          <select value={action} onChange={(e) => setAction(e.target.value)}>
            {!line.historical && (
              <option value="receive">Receive and add to stock</option>
            )}
            <option value="already_counted">
              Link units already counted in a Space
            </option>
            <option value="cancel">Cancel outstanding units</option>
          </select>
        </label>
        {action !== "cancel" && (
          <>
            <label>
              Destination Space
              <select
                required
                value={space}
                onChange={(e) => setSpace(e.target.value)}
              >
                <option value="">Choose a Space</option>
                {spaces
                  .filter((s) => s.can_edit)
                  .map((s) => (
                    <option
                      key={s.space_id || s.inventory_id}
                      value={s.space_id || s.inventory_id}
                    >
                      {s.name}
                    </option>
                  ))}
              </select>
            </label>
            {space && (
              <>
                <label>
                  Find the exact inventory part
                  <input
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Name or part number"
                  />
                </label>
                <label>
                  Confirm matching inventory record
                  <select
                    required
                    value={item}
                    onChange={(e) => setItem(e.target.value)}
                  >
                    <option value="">Choose the matching part</option>
                    {items.map((i) => (
                      <option key={i.item_id} value={i.item_id}>
                        {i.name} ·{" "}
                        {[i.part_number, i.location]
                          .filter(Boolean)
                          .join(" · ")}{" "}
                        · {i.recorded_quantity} recorded
                      </option>
                    ))}
                  </select>
                </label>
                {!items.length && (
                  <p>
                    If the part is new,{" "}
                    <Link
                      href={`/inventory?inventory=${encodeURIComponent(inventoryId || "")}`}
                    >
                      create its record in this Space
                    </Link>
                    , then return here. Choose “already counted” if you entered
                    its received quantity there.
                  </p>
                )}
              </>
            )}
          </>
        )}
        <label>
          Units
          <input
            required
            type="number"
            min={1}
            max={remaining}
            step={1}
            value={qty}
            onChange={(e) => setQty(e.target.value)}
          />
        </label>
        <button className="workspace-button" disabled={busy}>
          {busy
            ? "Saving…"
            : "Confirm " +
              (action === "receive"
                ? "receipt"
                : action === "cancel"
                  ? "cancellation"
                  : "already-counted units")}
        </button>
      </fieldset>
      {error && <p role="alert">{error}</p>}
    </form>
  );
}

export function SupplierOrders({
  accountId,
  world,
  spaces,
  initialSpace,
}: Props) {
  const [importBusy, setImportBusy] = useState(false);
  const [importOpen, setImportOpen] = useState(!!initialSpace);
  const [destination, setDestination] = useState(initialSpace || "");
  const [spaceId, setSpaceId] = useState(initialSpace || "");
  const path =
    "/commerce/organizations/" + encodeURIComponent(world) + "/orders";
  const [query, setQuery] = useState(""),
    [offset, setOffset] = useState(0),
    [revision, refresh] = useState(0);
  const [data, setData] = useState<Results>(),
    [error, setError] = useState(""),
    [notice, setNotice] = useState("");
  useEffect(() => {
    const c = new AbortController();
    setError("");
    setData(undefined);
    const timer = setTimeout(() => {
      accountRequest<Results>(
        accountId,
        path +
          "?" +
          new URLSearchParams({
            query,
            offset: String(offset),
            ...(spaceId ? { space_id: spaceId } : {}),
          }),
        { signal: c.signal },
      )
        .then((r) => {
          if (spaceId && r.order_scope_id !== spaceId)
            throw Error("Space Orders are unavailable on this server.");
          if (!c.signal.aborted) setData(r);
        })
        .catch((e) => {
          if (!c.signal.aborted) setError(message(e));
        });
    }, 120);
    return () => {
      clearTimeout(timer);
      c.abort();
    };
  }, [accountId, path, query, offset, revision, spaceId]);
  async function download(line: Order) {
    try {
      const token = await accountToken(accountId);
      const res = await fetch(apiBase() + path + "/sources/" + line.source_id, {
        cache: "no-store",
        headers: { Authorization: "Bearer " + token },
      });
      if (!res.ok)
        throw new Error(
          "The original file is unavailable or your access changed.",
        );
      const blob = await res.blob();
      await accountToken(accountId);
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = line.source_file;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    } catch (e) {
      setError(message(e));
    }
  }
  function saved(s: string) {
    setImportOpen(false);
    setNotice(s);
    refresh((v) => v + 1);
  }
  return (
    <section className={styles.page}>
      <div className={styles.heading}>
        <PageHeader>
          <h1>Orders</h1>
        </PageHeader>
        {data?.can_manage && (
          <button
            type="button"
            className="workspace-button primary"
            onClick={() => {
              setDestination(spaces.some((s) => s.can_edit && s.space_id === spaceId) ? spaceId : "");
              setImportOpen(true);
            }}
          >
            <Upload size={16} /> Import orders
          </button>
        )}
      </div>
      <Dialog
        open={importOpen && !!data?.can_manage && (!destination || spaces.some((space) => space.space_id === destination && space.can_edit))}
        onOpenChange={(v) => {
          if (!importBusy) setImportOpen(v);
        }}
      >
        <DialogContent className={styles.dialog}>
          <DialogTitle>Import orders</DialogTitle>
          <DialogDescription>
            Complete spreadsheets import directly. Missing order details open
            for review.
          </DialogDescription>
          <label>
            Destination Space
            <select
              disabled={importBusy}
              value={destination}
              onChange={(e) => setDestination(e.target.value)}
            >
              <option value="">Choose a Space</option>
              {spaces
                .filter((s) => s.space_id && s.can_edit)
                .map((s) => (
                  <option key={s.space_id} value={s.space_id}>
                    {s.name}
                  </option>
                ))}
            </select>
          </label>
          {destination && (
            <ImportOrder
              key={destination}
              accountId={accountId}
              path={path}
              saved={saved}
              onBusy={setImportBusy}
              spaceId={destination}
            />
          )}
        </DialogContent>
      </Dialog>
      <div className={styles.filters}>
        <label>
          Order Space
          <select
            value={spaceId}
            onChange={(e) => {
              setSpaceId(e.target.value);
              setOffset(0);
              setNotice("");
            }}
          >
            <option value="">All organization orders</option>
            {spaces
              .filter((s) => s.space_id)
              .map((s) => (
                <option key={s.space_id} value={s.space_id}>
                  {s.name}
                </option>
              ))}
          </select>
        </label>
        <label>
          Search orders and recorded inventory
          <input
            placeholder="Part name, SKU or order number"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setOffset(0);
            }}
          />
        </label>
      </div>
      {notice && <p role="status">{notice}</p>}
      {error && (
        <p role="alert">
          {error} <button onClick={() => refresh((v) => v + 1)}>Retry</button>
        </p>
      )}
      {!error && !data && <p>Loading orders…</p>}
      {data && (
        <>
          {query && (
            <div className={styles.panel}>
              <h2>Recorded in Spaces</h2>
              {data.recorded_inventory.map((i) => (
                <p key={i.item_id}>
                  {i.name} · {i.part_number} · {i.recorded_quantity} recorded in{" "}
                  {i.space_name} {i.location}
                </p>
              ))}
              {!data.recorded_inventory.length && (
                <p>No matching inventory records on this page.</p>
              )}
            </div>
          )}
          <h2 className={styles.listTitle}>Order lines</h2>
          {!data.order_lines.length && (
            <div className={styles.empty}>
              <PackageOpen aria-hidden="true" size={26} />
              <strong>
                {query ? "No matching order lines" : "No orders yet"}
              </strong>
              <p>
                {query
                  ? "Try another part, SKU, or order number."
                  : "Imported order lines will appear here."}
              </p>
            </div>
          )}
          {data.order_lines.map((l) => (
            <article key={l.id} className={styles.panel}>
              <h3>{l.name}</h3>
              <p>
                {l.order_space_name && <>{l.order_space_name} · </>}
                {l.supplier} · Order {l.order_number} · {l.sku || l.line_key}
              </p>
              <p>
                {l.ordered} ordered · {l.received} received or reconciled ·{" "}
                {l.cancelled} cancelled ·{" "}
                {l.outstanding === null
                  ? "History only"
                  : l.outstanding + " outstanding"}
              </p>
              <details>
                <summary>Source and receipts</summary>
                <p>
                  Supplier status {l.source_status} · {l.source_file} · Line{" "}
                  {l.line_key}
                </p>
                {data.can_manage && (
                  <>
                    <OriginalFields
                      accountId={accountId}
                      path={path}
                      line={l.id}
                    />
                    <button onClick={() => void download(l)}>
                      Download original file
                    </button>
                  </>
                )}
                {l.recent_receipts.map((r, n) => (
                  <p key={n}>
                    {new Date(r.created_at).toLocaleDateString()} · {r.quantity}{" "}
                    {r.action.replace("_", " ")} {r.space_name}
                  </p>
                ))}
                {data.can_manage &&
                  !["cancelled", "returned"].includes(l.source_status) &&
                  l.ordered > l.cancelled + l.received && (
                    <Receive
                      accountId={accountId}
                      path={path}
                      spaces={spaces}
                      line={l}
                      saved={saved}
                    />
                  )}
              </details>
            </article>
          ))}
          <div>
            {offset > 0 && (
              <button onClick={() => setOffset((v) => v - 50)}>Previous</button>
            )}{" "}
            {data.has_more && (
              <button onClick={() => setOffset((v) => v + 50)}>Next</button>
            )}
          </div>
        </>
      )}
    </section>
  );
}
