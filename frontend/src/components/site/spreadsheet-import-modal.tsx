"use client";
import { useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { DialogClose } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { useInventoryRouter } from "@/components/site/inventory-link";
import { apiRequest } from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";
type Row = {
  index: number;
  source_row: number;
  item: Record<string, string | number>;
  errors: string[];
  duplicates: { name: string; location: string }[];
  duplicate_rows: number[];
  excluded: boolean;
};
type Source = {
  id: string;
  filename: string;
  revision: number;
  status: string;
  mapping?: { sheet: number; columns: Record<string, number> };
  fields: string[];
  sheets: {
    name: string;
    headers: string[];
    sample: string[][];
    suggested_mapping: Record<string, number>;
    warnings: string[];
  }[];
  rows: Row[];
  decisions: Record<string, string> | null;
  receipts: Record<string, { status: string; message?: string }>;
  counts: {
    imported: number;
    skipped: number;
    failed: number;
    pending: number;
  };
};
type Bom = {
  invalid_rows: number;
  excluded_rows: number;
  items: {
    name: string;
    required_quantity: number;
    available_quantity: number;
    missing_quantity: number;
    match_status: string;
  }[];
  purchasing_csv: string;
};
type Props = {
  spaceName: string;
  token: string;
  onSuccess: (count: number) => void;
  kind?: "inventory" | "bom";
};
export function SpreadsheetImportModal({
  spaceName,
  token,
  onSuccess,
  kind = "inventory",
}: Props) {
  const router = useInventoryRouter();
  const [mappingDirty, setMappingDirty] = useState(false);
  const [source, setSource] = useState<Source | null>(null),
    [sheet, setSheet] = useState(0),
    [columns, setColumns] = useState<Record<string, number>>({}),
    [decisions, setDecisions] = useState<Record<string, string>>({}),
    [busy, setBusy] = useState(false),
    [error, setError] = useState<string | null>(null),
    [page, setPage] = useState(0),
    [bom, setBom] = useState<Bom | null>(null);
  const inFlight = useRef(false),
    notified = useRef(0);
  async function run(operation: () => Promise<void>) {
    if (inFlight.current) return;
    inFlight.current = true;
    setBusy(true);
    setError(null);
    try {
      await operation();
    } catch (e) {
      setError(
        userFacingError(e, "The request could not be completed. Retry safely."),
      );
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  }
  function choose(data: Source) {
    setSource(data);
    setDecisions(
      data.decisions ??
        Object.fromEntries(
          data.rows.map((r) => [
            String(r.index),
            r.errors.length || r.duplicates.length || r.duplicate_rows.length
              ? "skip"
              : "create",
          ]),
        ),
    );
  }
  async function upload(file: File) {
    await run(async () => {
      if (
        !/\.(csv|xlsx)$/i.test(file.name) ||
        file.size > 10 * 1024 * 1024 ||
        !file.size
      )
        throw new Error("Choose a nonempty CSV or XLSX file up to 10 MB.");
      const form = new FormData();
      form.append("file", file);
      form.append("location", spaceName);
      form.append("kind", kind);
      const data = await apiRequest<Source>("/connectors/imports", {
        method: "POST",
        token,
        body: form,
      });
      choose(data);
      setSheet(data.mapping?.sheet ?? 0);
      setColumns(data.mapping?.columns ?? data.sheets[0].suggested_mapping);
      setMappingDirty(false);
      setBom(null);
      setPage(0);
    });
  }
  async function preview() {
    if (!source) return;
    await run(async () => {
      choose(
        await apiRequest<Source>(`/connectors/imports/${source.id}/preview`, {
          method: "POST",
          token,
          body: { revision: source.revision, sheet, columns },
        }),
      );
      setPage(0);
      setBom(null);
      setMappingDirty(false);
    });
  }
  async function commit(retry = false) {
    if (!source) return;
    await run(async () => {
      let current = source;
      const frozen = { ...decisions };
      setSource({ ...current, decisions: frozen, status: "importing" });
      do {
        const result = await apiRequest<Source>(
          `/connectors/imports/${current.id}/commit`,
          {
            method: "POST",
            token,
            body: {
              revision: current.revision,
              decisions: frozen,
              retry_failed: retry,
            },
          },
        );
        if (
          result.id !== current.id ||
          !["complete", "importing"].includes(result.status) ||
          !result.counts ||
          ![
            result.counts.imported,
            result.counts.skipped,
            result.counts.failed,
            result.counts.pending,
          ].every((n) => Number.isInteger(n) && n >= 0)
        )
          throw new Error(
            "The import result could not be verified. Resume safely to check saved results.",
          );
        current = { ...current, ...result };
        setSource(current);
        retry = false;
        if (current.counts.imported > notified.current) {
          onSuccess(current.counts.imported);
          notified.current = current.counts.imported;
        }
      } while (current.status === "importing");
    });
  }
  async function analyze() {
    if (!source) return;
    await run(async () =>
      setBom(
        await apiRequest<Bom>(`/connectors/imports/${source.id}/bom`, {
          token,
        }),
      ),
    );
  }
  function exportBom() {
    if (!bom) return;
    const url = URL.createObjectURL(
      new Blob([bom.purchasing_csv], { type: "text/csv;charset=utf-8" }),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = "findez-shortages.csv";
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  const started = source?.decisions != null,
    panel = {
      border: "1px solid var(--light-line)",
      borderRadius: 14,
      padding: 14,
      marginBottom: 10,
    },
    selectStyle = {
      width: "100%",
      background: "var(--light-panel)",
      color: "var(--ink)",
      border: "1px solid var(--light-line)",
      borderRadius: 8,
      padding: 10,
    };
  return (
    <div
      style={{
        color: "var(--ink)",
        maxHeight: "75dvh",
        overflowY: "auto",
        padding: 4,
      }}
      aria-busy={busy}
    >
      <h2 style={{ fontSize: 20, marginBottom: 4 }}>
        {kind === "bom" ? "Review parts list" : "Import inventory"}
      </h2>
      <p style={{ color: "var(--light-muted)", marginBottom: 16 }}>
        {spaceName}
        {source ? ` · ${source.filename}` : ""}
      </p>
      {!source && (
        <label style={{ ...panel, display: "block" }}>
          Choose CSV or Excel (.xlsx)
          <Input
            aria-label="Import file"
            type="file"
            accept=".csv,.xlsx"
            disabled={busy}
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void upload(f);
            }}
          />
          <small>Up to 10 MB and 5,000 rows. Review before saving.</small>
        </label>
      )}
      {source && !started && (
        <details open={!source.rows.length} style={panel}>
          <summary>Column mapping</summary>
          <label>
            Worksheet
            <select
              style={selectStyle}
              aria-label="Worksheet"
              value={sheet}
              disabled={busy}
              onChange={(e) => {
                const i = Number(e.target.value);
                setSheet(i);
                setColumns(source.sheets[i].suggested_mapping);
                setMappingDirty(true);
                setBom(null);
              }}
            >
              {source.sheets.map((s, i) => (
                <option key={i} value={i}>
                  {s.name}
                </option>
              ))}
            </select>
          </label>
          {source.sheets[sheet].warnings.map((w) => (
            <p key={w}>{w}</p>
          ))}
          <p style={{ fontSize: 12 }}>
            Unmapped category: Supplies. Unmapped quantity: 1. Location defaults
            to {spaceName}.
          </p>
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit,minmax(180px,1fr))",
              gap: 12,
              margin: "12px 0",
            }}
          >
            {source.fields.map((field) => (
              <label key={field}>
                {field.replaceAll("_", " ")}
                <select
                  style={selectStyle}
                  aria-label={`Map ${field}`}
                  disabled={busy}
                  value={columns[field] ?? -1}
                  onChange={(e) => {
                    setMappingDirty(true);
                    setBom(null);
                    setColumns((old) => {
                      const next = { ...old },
                        i = Number(e.target.value);
                      if (i < 0) delete next[field];
                      else next[field] = i;
                      return next;
                    });
                  }}
                >
                  <option value={-1}>Not mapped</option>
                  {source.sheets[sheet].headers.map((h, i) => (
                    <option key={i} value={i}>
                      {i + 1}. {h}
                    </option>
                  ))}
                </select>
              </label>
            ))}
          </div>
          <div style={{ overflowX: "auto", marginBottom: 12 }}>
            <table>
              <caption>First five source rows</caption>
              <thead>
                <tr>
                  {source.sheets[sheet].headers.map((h, i) => (
                    <th key={i}>
                      {i + 1}. {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {source.sheets[sheet].sample.map((r, i) => (
                  <tr key={i}>
                    {r.map((v, j) => (
                      <td key={j} style={{ padding: 6 }}>
                        {v}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Button disabled={busy} onClick={() => void preview()}>
            Preview rows
          </Button>
        </details>
      )}
      {mappingDirty && source?.rows.length ? (
        <p role="status">
          Mapping changed. Preview rows again before continuing.
        </p>
      ) : null}
      {source && started && (
        <div style={panel} role="status">
          <strong>
            {source.status === "complete"
              ? "Import results"
              : "Import in progress"}
          </strong>
          <p>
            {source.counts.imported} imported · {source.counts.skipped} skipped
            · {source.counts.failed} failed · {source.counts.pending} pending
          </p>
        </div>
      )}
      {!!source?.rows.length && !started && kind === "inventory" && (
        <p>
          Invalid rows and likely duplicates start as Skip. Review your choices.
          Existing stock is never overwritten.
        </p>
      )}
      {source?.rows.slice(page * 50, (page + 1) * 50).map((row) => (
        <div key={row.index} style={panel}>
          <strong>{row.item.name || "Missing name"}</strong>
          <p style={{ fontSize: 12, color: "var(--light-muted)" }}>
            Row {row.source_row} · Qty {row.item.quantity} · {row.item.location}
          </p>
          {row.errors.map((e) => (
            <p key={e} style={{ color: "var(--danger-ink)" }}>
              {e}
            </p>
          ))}
          {(row.duplicates.length > 0 || row.duplicate_rows.length > 0) && (
            <p>
              Possible duplicate
              {row.duplicates.length
                ? `: ${row.duplicates.map((i) => `${i.name} (${i.location})`).join(", ")}`
                : " in this file"}
            </p>
          )}
          {row.excluded && <p>Excluded: do not populate</p>}
          {source.receipts[String(row.index)] && (
            <p>
              {source.receipts[String(row.index)].status}:{" "}
              {source.receipts[String(row.index)].message}
            </p>
          )}
          {!started && kind === "inventory" && (
            <select
              style={selectStyle}
              aria-label={`Action for row ${row.source_row}`}
              disabled={busy}
              value={decisions[String(row.index)]}
              onChange={(e) =>
                setDecisions({
                  ...decisions,
                  [String(row.index)]: e.target.value,
                })
              }
            >
              <option value="skip">Skip row</option>
              {!row.errors.length && (
                <option
                  value={
                    row.duplicates.length || row.duplicate_rows.length
                      ? "create_duplicate"
                      : "create"
                  }
                >
                  {row.duplicates.length || row.duplicate_rows.length
                    ? "Create a separate item"
                    : "Create item"}
                </option>
              )}
            </select>
          )}
        </div>
      ))}
      {source && source.rows.length > 50 && (
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <Button disabled={page === 0} onClick={() => setPage(page - 1)}>
            Previous
          </Button>
          <span>
            {page + 1} / {Math.ceil(source.rows.length / 50)}
          </span>
          <Button
            disabled={(page + 1) * 50 >= source.rows.length}
            onClick={() => setPage(page + 1)}
          >
            Next
          </Button>
        </div>
      )}
      {bom && (bom.invalid_rows > 0 || bom.excluded_rows > 0) && (
        <p role="status">
          {bom.invalid_rows} invalid rows omitted · {bom.excluded_rows}{" "}
          do-not-populate rows excluded.{" "}
          {bom.invalid_rows > 0
            ? "Correct invalid rows before exporting the purchasing list."
            : ""}
        </p>
      )}
      {bom?.items.map((row, i) => (
        <div key={i} style={panel}>
          <strong>{row.name}</strong>
          <p>
            Required {row.required_quantity} · Available{" "}
            {row.available_quantity} · Short {row.missing_quantity}
          </p>
          <p>Match: {row.match_status}</p>
        </div>
      ))}
      {error && (
        <p role="alert" style={{ color: "var(--danger-ink)" }}>
          {error}
        </p>
      )}
      {busy && (
        <p role="status">
          {started ? "Saving reviewed rows..." : "Preparing your preview..."}
        </p>
      )}
      {!!source?.rows.length && (
        <div
          style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 16 }}
        >
          {kind === "bom" ? (
            <Button
              disabled={busy || mappingDirty}
              onClick={() => void analyze()}
            >
              Check available stock
            </Button>
          ) : (
            (!started || source.status !== "complete") && (
              <Button
                disabled={busy || mappingDirty}
                onClick={() => void commit()}
              >
                {started ? "Resume import" : "Confirm import"}
              </Button>
            )
          )}
          {started && source.counts.failed > 0 && (
            <Button disabled={busy} onClick={() => void commit(true)}>
              Retry failed rows
            </Button>
          )}
          {bom && bom.invalid_rows === 0 && (
            <Button onClick={exportBom}>Export shortage CSV</Button>
          )}
          {started && (
            <DialogClose asChild>
              <Button
                disabled={busy}
                onClick={() =>
                  router.push(
                    `/inventory?space=${encodeURIComponent(spaceName)}`,
                  )
                }
              >
                View inventory
              </Button>
            </DialogClose>
          )}
        </div>
      )}
    </div>
  );
}
