"use client";
import { privateImageSrc } from "@/lib/private-image";
import styles from "./review-queue.module.css";

import { canEditInventory } from "@/lib/inventory-selection";

import { useCallback, useEffect, useState } from "react";
import Image from "next/image";
import { Check, ChevronDown, ImageIcon, ListChecks, RefreshCw, Trash2 } from "lucide-react";

import { useAppDialog } from "@/components/site/app-dialog-provider";
import {
  dismissReviewItem,
  getReviewItems,
  resolveReviewItem,
  type ReviewItem,
} from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";

function percent(value?: number | null) {
  return typeof value === "number" ? `${Math.round(value * 100)}%` : "Not available";
}

function Evidence({ item }: { item: ReviewItem }) {
  const evidence = item.scan_evidence;
  if (!evidence) return null;
  const dimensions = evidence.length_mm != null || evidence.width_mm != null
    ? `${evidence.length_mm?.toFixed(1) ?? "—"} × ${evidence.width_mm?.toFixed(1) ?? "—"} mm`
    : null;
  return (
    <section className="review-evidence" aria-label="Capture information">
      <h3>How this was read</h3>
      {(evidence.review_reasons ?? []).map((reason) => (
        <p className="review-reason" key={reason}><strong>Needs review</strong>{reason}</p>
      ))}
      {evidence.identification_reasoning && <p><strong>Why this identification</strong>{evidence.identification_reasoning}</p>}
      <div className="review-evidence-facts">
        <span><small>Identification</small>{percent(evidence.identity_confidence ?? item.confidence)}</span>
        <span><small>Detection</small>{percent(evidence.detection_confidence)}</span>
        {evidence.ocr_text && <span><small>Visible text · {percent(evidence.ocr_confidence)}</small>{evidence.ocr_text}</span>}
        {item.barcode && <span><small>Barcode value</small>{item.barcode}</span>}
        {evidence.barcode_symbology && <span><small>Barcode format · {percent(evidence.barcode_confidence)}</small>{evidence.barcode_symbology}</span>}
        {dimensions && <span><small>Measured size · {evidence.measurement_confidence ?? "confidence unavailable"}</small>{dimensions}</span>}
        {evidence.measurement_method && <span><small>Measurement method</small>{evidence.measurement_method}</span>}
      </div>
      {evidence.measurement_assumption && <p><strong>Measurement note</strong>{evidence.measurement_assumption}</p>}
      {(evidence.warnings ?? []).map((warning) => <p key={warning}><strong>Analysis note</strong>{warning}</p>)}
    </section>
  );
}

export function ReviewQueueClient() {
  const { token, accountId } = useApiSession();
  const { confirmAction } = useAppDialog();
  const [items, setItems] = useState<ReviewItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pendingCount, setPendingCount] = useState(0);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const result = await getReviewItems({ token });
      setItems(result.items);
      setPendingCount(result.pending_count);
      setExpandedId(null);
      setPage(0);
    } catch (reason) {
      setError(userFacingError(reason, "Review could not be loaded."));
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => { void load(); }, [load]);

  function change(reviewId: string, changes: Partial<ReviewItem>) {
    setItems((current) => current.map((item) => item.review_id === reviewId ? { ...item, ...changes } : item));
  }

  async function resolve(item: ReviewItem) {
    if (!token) return;
    if (!item.name.trim() || !item.category.trim() || !item.location?.trim()) {
      setError("Name, category, and location are required before this can become inventory.");
      return;
    }
    setSavingId(item.review_id);
    setError(null);
    setNotice(null);
    try {
      await resolveReviewItem({ token, reviewId: item.review_id, item });
      setItems((current) => current.filter((entry) => entry.review_id !== item.review_id));
      setPendingCount((count) => Math.max(0, count - 1));
      setExpandedId(null);
      setNotice(`${item.name} was saved to your inventory.`);
    } catch (reason) {
      setError(userFacingError(reason, "This item could not be confirmed."));
    } finally {
      setSavingId(null);
    }
  }

  async function dismiss(item: ReviewItem) {
    if (!token || !await confirmAction({
      title: "Dismiss this capture?",
      message: "It will leave Review and will not be added to inventory.",
      confirmLabel: "Dismiss capture",
      danger: true,
    })) return;
    setSavingId(item.review_id);
    setError(null);
    try {
      await dismissReviewItem({ token, reviewId: item.review_id });
      setItems((current) => current.filter((entry) => entry.review_id !== item.review_id));
      setPendingCount((count) => Math.max(0, count - 1));
      setExpandedId(null);
      setNotice("Capture dismissed.");
    } catch (reason) {
      setError(userFacingError(reason, "This capture could not be dismissed."));
    } finally {
      setSavingId(null);
    }
  }

  const pageSize = 25;
  const pageCount = Math.max(1, Math.ceil(items.length / pageSize));
  const currentPage = Math.min(page, pageCount - 1);
  const visibleItems = items.slice(currentPage * pageSize, (currentPage + 1) * pageSize);

  return (
    <section className="product-page review-page">
      <header className="product-page-header review-queue-header">
        <div><h1>Review</h1><p>Check uncertain captures before adding them to your inventory.</p></div>
        <button type="button" className="product-button" onClick={() => void load()} disabled={loading}><RefreshCw size={15} />Refresh</button>
      </header>
      {error && <div className="notice-error">{error}</div>}
      {notice && <div className="notice-success">{notice}</div>}
      {loading && items.length === 0 ? <div className="review-empty"><span className="loading-spinner" />Loading Review…</div> : null}
      {!loading && items.length === 0 && pendingCount === 0 ? (
        <div className="review-empty">
          <ListChecks size={25} />
          <strong>Nothing needs review</strong>
          <p>When a photo is uncertain, it will stay here until you assign it or dismiss it.</p>
        </div>
      ) : null}
      {items.length > 0 && <p className={styles.count}>{pendingCount.toLocaleString()} pending · {currentPage * pageSize + 1}–{Math.min((currentPage + 1) * pageSize, items.length)} shown</p>}
      {pendingCount > items.length && <p className={styles.count}>{items.length > 0 ? `Showing the latest ${items.length} captures. Refresh after reviewing these to load more.` : "More captures are waiting. Refresh to load the next batch."}</p>}
      <div className={styles.list}>
        {visibleItems.map((item) => {
          const saving = savingId === item.review_id;
          const expanded = expandedId === item.review_id;
          return (
            <article className={styles.card} key={item.review_id}>
              <button type="button" className={styles.summary} aria-label={`Review ${item.name || "Unidentified item"}`} aria-expanded={expanded} aria-controls={`review-${item.review_id}`} onClick={() => setExpandedId(expanded ? null : item.review_id)}>
                {item.image_url ? <Image unoptimized width={56} height={56} className={styles.thumbnail} src={privateImageSrc(item.image_url, accountId)} alt="" /> : <span className={styles.thumbnail}><ImageIcon size={22} /></span>}
                <span className={styles.identity}><strong>{item.name || "Unidentified item"}</strong><span>{item.category || "Uncategorized"} · Qty {item.quantity} · {item.location || "No Space assigned"}</span><small>{item.scan_evidence?.review_reasons?.[0] || "Check the details before saving."}</small></span>
                <span className={styles.openLabel}>{expanded ? "Close" : "Review"}<ChevronDown size={16} className={expanded ? styles.expanded : undefined} /></span>
              </button>
              {expanded && <div id={`review-${item.review_id}`} className={styles.details}>
                <div className={styles.preview}>
                  {item.image_url && <Image unoptimized width={360} height={280} className={styles.photo} src={privateImageSrc(item.image_url, accountId)} alt={`Captured ${item.name || "item"}`} />}
                  {item.scan_evidence && <details className={styles.evidence}><summary>Capture information</summary><Evidence item={item} /></details>}
                </div>
                <div className={styles.editor}>
              <div className={`review-fields ${styles.fields}`}>
                <label><span>Name</span><input disabled={!canEditInventory()} className="product-input" value={item.name} onChange={(event) => change(item.review_id, { name: event.target.value })} /></label>
                <label><span>Category</span><input disabled={!canEditInventory()} className="product-input" value={item.category} onChange={(event) => change(item.review_id, { category: event.target.value })} /></label>
                <label><span>Location</span><input disabled={!canEditInventory()} className="product-input" value={item.location ?? ""} placeholder="Required" onChange={(event) => change(item.review_id, { location: event.target.value })} /></label>
                <label><span>Quantity</span><input disabled={!canEditInventory()} className="product-input" type="number" min={0} max={100000} value={item.quantity} onChange={(event) => change(item.review_id, { quantity: Number(event.target.value) })} /></label>
                <label><span>Brand</span><input disabled={!canEditInventory()} className="product-input" value={item.brand ?? ""} onChange={(event) => change(item.review_id, { brand: event.target.value || null })} /></label>
                <label><span>Part / model #</span><input disabled={!canEditInventory()} className="product-input" value={item.part_number ?? ""} onChange={(event) => change(item.review_id, { part_number: event.target.value || null })} /></label>
              </div>
              <label className="review-notes"><span>Notes</span><textarea disabled={!canEditInventory()} className="product-textarea" value={item.notes ?? ""} onChange={(event) => change(item.review_id, { notes: event.target.value || null })} /></label>
              <footer className={styles.actions}>
                <button type="button" className="product-button danger" disabled={savingId !== null || !canEditInventory()} onClick={() => void dismiss(item)}><Trash2 size={15} />Dismiss</button>
                <button type="button" className="product-button primary" disabled={savingId !== null || !canEditInventory()} onClick={() => void resolve(item)}><Check size={16} />{saving ? "Saving…" : "Confirm and save"}</button>
              </footer>
                </div>
              </div>}
            </article>
          );
        })}
      </div>
      {pageCount > 1 && <nav className={styles.pagination} aria-label="Review pages">
        <button type="button" className="product-button" disabled={currentPage === 0} onClick={() => { setPage(currentPage - 1); setExpandedId(null); }}>Previous</button>
        <span>Page {currentPage + 1} of {pageCount}</span>
        <button type="button" className="product-button" disabled={currentPage === pageCount - 1} onClick={() => { setPage(currentPage + 1); setExpandedId(null); }}>Next</button>
      </nav>}
    </section>
  );
}
