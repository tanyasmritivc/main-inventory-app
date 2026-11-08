"use client";
import { useEffect, useRef, useState } from "react";
import { userFacingError } from "@/lib/user-facing-error";

export type ImportRequest = (path: string, body: FormData | Record<string, unknown>) => Promise<unknown>;
class ImportNotice extends Error {}
type Receipt = { id: string; status: string; counts: { imported: number; failed: number; skipped: number; pending: number; total: number } };
function receipt(value: unknown): Receipt {
  const r = value as Receipt;
  if (!r || typeof r.id !== "string" || !["review", "complete", "importing"].includes(r.status) ||
      !r.counts || !["imported", "failed", "skipped", "pending", "total"].every(k =>
        Number.isInteger(r.counts[k as keyof Receipt["counts"]]) && r.counts[k as keyof Receipt["counts"]] >= 0))
    throw new ImportNotice("The import result could not be verified. Resume this import to check saved results.");
  return r;
}
export function DirectSpreadsheetImport({spaceName, spaceId, request, onSuccess, initialFile}: {
  spaceName: string; spaceId?: string; request: ImportRequest; onSuccess: (count: number) => void; initialFile?: File;
}) {
  const [file, setFile] = useState(initialFile);
  const [result, setResult] = useState<Receipt>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const lock = useRef(false), session = useRef<string | undefined>(undefined);
  async function save(selected = file) {
    if (!selected || lock.current) return;
    lock.current = true; setBusy(true); setError(""); setFile(selected);
    try {
      if (!/\.(xlsx|csv|json)$/i.test(selected.name) || !selected.size || selected.size > 10 * 1024 * 1024)
        throw new ImportNotice("Choose a nonempty Excel (.xlsx), CSV, or JSON file up to 10 MB.");
      if (!session.current) {
        const form = new FormData();
        form.append("file", selected); form.append("location", spaceName); form.append("direct", "true");
        if (spaceId) form.append("space_id", spaceId);
        session.current = receipt(await request("/connectors/imports", form)).id;
      }
      let current: Receipt, batches = 0;
      do {
        current = receipt(await request(`/connectors/imports/${session.current}/import`, {}));
        setResult(current);
        if (++batches > 30) throw new ImportNotice("Import is still pending. Resume to check saved results.");
      } while (current.status === "importing");
      if (current.counts.failed || current.counts.pending || current.counts.skipped)
        throw new ImportNotice(`${current.counts.imported} items saved; ${current.counts.failed} could not be saved. Resume to retry unfinished rows.`);
      onSuccess(current.counts.imported);
    } catch (e) { setError(e instanceof ImportNotice ? e.message : userFacingError(e, "Could not finish importing. Retry safely.")); }
    finally { lock.current = false; setBusy(false); }
  }
  useEffect(() => {
    if (initialFile) void save(initialFile);
    // Start once for the selected destination; save serializes Strict Mode replay.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialFile]);
  return <div className="space-y-4">
    <p>Save directly to <strong>{spaceName}</strong>.</p>
    <p className="text-sm text-muted-foreground">Excel (.xlsx), CSV, or JSON, up to 10 MB. Every worksheet is included, with original columns retained in item details.</p>
    {!file && <input aria-label="Choose spreadsheet" type="file" accept=".csv,.xlsx,.json" disabled={busy} onChange={e => { const selected = e.target.files?.[0]; if (selected) void save(selected); }}/>} 
    {file && <p>{file.name}</p>}
    {file && <button className="button-primary" disabled={busy || result?.status === "complete" && !result.counts.failed} onClick={() => void save()}>{busy ? "Importing..." : session.current ? "Resume import" : "Import to this Space"}</button>}
    {result && <p role="status">{result.counts.imported} of {result.counts.total} items saved.</p>}
    {error && <p role="alert">{error}</p>}
  </div>;
}
