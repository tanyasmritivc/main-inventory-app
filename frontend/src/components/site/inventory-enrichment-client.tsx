"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { ArrowLeft, Check, ChevronDown, Clock3, RefreshCw, SlidersHorizontal } from "lucide-react";
import Link from "@/components/site/inventory-link";
import { ApiError } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import { intelligenceRequest, inventoryRoles, suggestionPhoto, type EnrichmentReview } from "@/lib/inventory-intelligence";
import styles from "./inventory-enrichment.module.css";

function Photo({ id, name }: { id: string; name: string }) {
  const [photo, setPhoto] = useState("");
  const [error, setError] = useState("");
  useEffect(() => {
    const controller = new AbortController(); let url = "";
    void suggestionPhoto(id, controller.signal).then(blob => {
      if (controller.signal.aborted) return;
      url = URL.createObjectURL(blob); setPhoto(url);
    }).catch(() => { if (!controller.signal.aborted) setError("Photo unavailable. Refresh to try again."); });
    return () => { controller.abort(); if (url) URL.revokeObjectURL(url); };
  }, [id]);
  return <div className={styles.photo}>{photo
    // Private, normalized blob returned only after an authenticated inventory check.
    // eslint-disable-next-line @next/next/no-img-element
    ? <img src={photo} alt={`Suggested product photo for ${name}`} />
    : <span role="status">{error || "Loading photo..."}</span>}</div>;
}

export function InventoryEnrichmentClient() {
  const { accountId, loading: sessionLoading, error: sessionError } = useApiSession();
  const [data, setData] = useState<EnrichmentReview | null>(null);
  const [offset, setOffset] = useState(0);
  const [kind, setKind] = useState("all");
  const [selected, setSelected] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const generation = useRef(0);
  const load = useCallback(async () => {
    if (!accountId) return;
    const current = ++generation.current;
    setLoading(true); setError("");
    try {
      const next = await intelligenceRequest<EnrichmentReview>(`?offset=${offset}&kind=${kind}`);
      if (generation.current === current) { setData(next); setSelected([]); }
    } catch (reason) {
      if (generation.current === current) setError(reason instanceof ApiError && reason.status === 503
        ? "AI Inventory Enrichment is not enabled yet. Your existing inventory is unchanged."
        : userFacingError(reason, "Suggestions could not be loaded."));
    } finally { if (generation.current === current) setLoading(false); }
  }, [accountId, offset, kind]);
  useEffect(() => {
    void load();
    return () => {
      // Invalidate pending requests; this ref is a generation counter, not a DOM node.
      // eslint-disable-next-line react-hooks/exhaustive-deps
      generation.current++;
    };
  }, [load]);
  async function decide(ids: string[], decision: "approve" | "reject" | "retry") {
    if (busy || !data?.can_edit || !ids.length) return;
    setBusy(true); setError(""); setNotice("");
    const current = generation.current;
    try {
      const receipt = await intelligenceRequest<{ results: { status: string }[] }>("/decisions", { method: "POST", body: { ids, decision } });
      if (generation.current !== current) return;
      const wanted = decision === "approve" ? "approved" : decision === "reject" ? "rejected" : "queued";
      const changed = receipt.results.filter(row => row.status === wanted).length;
      setNotice(`${changed} suggestion${changed === 1 ? "" : "s"} ${wanted}.${changed < ids.length ? " Changed items were skipped. Review their latest details." : ""}`);
      if (offset) setOffset(0); else await load();
    } catch (reason) { if (generation.current === current) setError(userFacingError(reason, "Your selection could not be saved. Refresh and try again.")); }
    finally { if (generation.current === current || generation.current === current + 1) setBusy(false); }
  }
  async function saveSettings(images: boolean, zone: string) {
    setBusy(true); setError("");
    try {
      await intelligenceRequest("/settings", { method: "PUT", body: { images_enabled: images, timezone: zone } });
      await load(); setNotice("Schedule saved. Existing item photos are unchanged.");
    } catch (reason) { setError(userFacingError(reason, "The schedule could not be saved.")); }
    finally { setBusy(false); }
  }
  const ready = data?.items.filter(row => row.status === "ready") ?? [];
  const hasItems = !!data?.items.length;
  const hasPages = offset > 0 || data?.next_offset != null;
  return <section className={styles.page} aria-label="AI Inventory Enrichment">
    <Link href="/inventory" className={styles.back}><ArrowLeft size={14} aria-hidden="true" /> Back to inventory</Link>
    <header className={styles.header}>
      <div><h1>AI Inventory Enrichment</h1><p>Review suggested photos and classifications before they’re saved.</p></div>
      <button className={styles.button} onClick={() => void load()} disabled={loading || busy || !accountId}><RefreshCw size={14} aria-hidden="true" /> Refresh</button>
    </header>
    {(error || sessionError) && <div className={styles.message} role="alert">{error || sessionError}</div>}
    {notice && <div className={styles.message} role="status">{notice}</div>}
    {data && <details className={styles.settings}>
      <summary><Clock3 size={16} aria-hidden="true" /><span>Overnight photos</span><span className={styles.schedule}>{data.settings.images_enabled ? `2:00 AM · ${data.settings.timezone.replaceAll("_", " ")}` : "Paused"}</span><span className={styles.settingsLabel}><SlidersHorizontal size={14} aria-hidden="true" /> Settings<ChevronDown size={14} className={styles.chevron} aria-hidden="true" /></span></summary>
      <div className={styles.settingsBody}>
        <div><label><input type="checkbox" checked={data.settings.images_enabled} disabled={busy || !data.can_edit} onChange={e => void saveSettings(e.target.checked, data.settings.timezone)} /> Suggest photos for new imports</label><p>Real product photos only. Large imports may take longer.</p></div>
        <div><p>Time zone: {data.settings.timezone.replaceAll("_", " ")}</p>{data.can_edit && <button className={styles.button} disabled={busy} onClick={() => void saveSettings(data.settings.images_enabled, Intl.DateTimeFormat().resolvedOptions().timeZone)}>Use my time zone</button>}</div>
        <p className={styles.privacy}>Only product identifiers are sent to the photo provider. Existing photos and stock alert settings stay unchanged.</p>
      </div>
    </details>}
    <div className={styles.review} aria-busy={loading || sessionLoading}>
      <div className={styles.reviewHeader}><h2>Suggestions</h2>
        {data && <label className={styles.filter}><span className={styles.srOnly}>Show suggestions</span><select aria-label="Show suggestions" value={kind} disabled={busy || loading} onChange={e => { setKind(e.target.value); setOffset(0); }}><option value="all">All suggestions</option><option value="image">Product photos</option><option value="classification">Classifications</option></select></label>}
      </div>
      {data?.can_edit && ready.length > 0 && !error && <div className={styles.bulk}>
        <label><input type="checkbox" aria-label="Select ready on this page" checked={ready.every(row => selected.includes(row.id))} disabled={busy || loading} onChange={e => setSelected(e.target.checked ? ready.map(row => row.id) : [])} /> Select ready ({ready.length})</label>
        {selected.length > 0 && <div className={styles.actions}><button className={`${styles.button} ${styles.primary}`} disabled={busy || loading} onClick={() => void decide(selected, "approve")}>Approve selected ({selected.length})</button><button className={styles.button} disabled={busy || loading} onClick={() => void decide(selected, "reject")}>Reject selected</button></div>}
      </div>}
      {data && !data.can_edit && <p className={styles.viewer}>View only. An inventory editor can approve suggestions.</p>}
      {loading || sessionLoading ? <div className={styles.empty} role="status"><p>Loading suggestions…</p></div> : error || sessionError ? <div className={styles.empty}><h3>Suggestions unavailable</h3><p>Refresh to try again. Your saved items haven’t changed.</p></div> : data && <>
        {!hasItems && <div className={styles.empty}>
          <span className={styles.emptyIcon}><Check size={20} aria-hidden="true" /></span>
          <h3>{offset > 0 ? "No more suggestions" : kind === "all" ? "No suggestions yet" : kind === "image" ? "No photo suggestions" : "No classification suggestions"}</h3>
          <p>{offset > 0 ? "Go to the previous page to review earlier suggestions." : "Suggestions from new items appear here. Photos from new spreadsheet imports are checked overnight."}</p>
          {offset === 0 && <Link className={styles.button} href="/inventory">Open inventory</Link>}
        </div>}
        {hasItems && <div className={styles.grid}>{data.items.map(row => <article className={styles.card} key={row.id}>
          {row.kind === "image" && row.status === "ready" && row.has_preview && <Photo id={row.id} name={row.name} />}
          <div className={styles.body}>
            <div className={styles.cardHeader}><span>{row.kind === "image" ? "Product photo" : "Classification"}</span><span className={styles.badge}>{({ ready: "Ready to review", queued: "Scheduled", processing: "Processing", no_match: "No match", failed: "Try again" } as Record<string, string>)[row.status] ?? row.status.replaceAll("_", " ")}</span></div>
            <h3>{row.name || "Unnamed item"}</h3>
            {row.kind === "classification" && row.result.role && <p className={styles.role}>{inventoryRoles[row.result.role]}</p>}
            {row.result.product_name && <p>{row.result.product_name}</p>}
            {row.result.confidence && <p className={styles.muted}>{row.result.confidence} confidence{row.result.match_basis ? ` · ${row.result.match_basis.replaceAll("_", " ")}` : ""}</p>}
            {row.status === "queued" && <p className={styles.muted}>Scheduled {new Date(row.due_at).toLocaleString()}</p>}
            {row.status === "processing" && <p role="status">Preparing suggestion…</p>}
            {row.result.reason && <p className={styles.muted}>{row.result.reason}</p>}
            {row.result.source_url?.startsWith("https://") && <a className={styles.source} href={row.result.source_url} target="_blank" rel="noopener noreferrer">View product source ↗</a>}
            <div className={styles.actions}>
              {data.can_edit && row.status === "ready" && <><label className={styles.selection}><input type="checkbox" aria-label={`Select ${row.name} ${row.kind}`} checked={selected.includes(row.id)} disabled={busy} onChange={e => setSelected(current => e.target.checked ? [...current, row.id] : current.filter(id => id !== row.id))} /><span className={styles.srOnly}>Select suggestion</span></label><button className={`${styles.button} ${styles.primary}`} disabled={busy} onClick={() => void decide([row.id], "approve")}>Approve</button><button className={styles.button} disabled={busy} onClick={() => void decide([row.id], "reject")}>Reject</button></>}
              {data.can_edit && ["no_match", "failed"].includes(row.status) && <button className={styles.button} disabled={busy} onClick={() => void decide([row.id], "retry")}>Retry</button>}
              <Link className={styles.textLink} href={`/inventory?item=${encodeURIComponent(row.item_id)}`}>{data.can_edit ? row.kind === "image" ? "Upload my photo" : "Change classification" : "View item"}</Link>
            </div>
          </div>
        </article>)}</div>}
        {hasPages && <nav className={styles.pagination} aria-label="Suggestion pages"><button className={styles.button} disabled={offset === 0 || busy || loading} onClick={() => setOffset(Math.max(0, offset - 20))}>Previous</button><span>Page {Math.floor(offset / 20) + 1}</span><button className={styles.button} disabled={data.next_offset === null || busy || loading} onClick={() => setOffset(data.next_offset ?? offset)}>Next</button></nav>}
      </>}
    </div>
    <p className={styles.footer}>Only approved suggestions are saved. Classification does not enable alerts.</p>
  </section>;
}
