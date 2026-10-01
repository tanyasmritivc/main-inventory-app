"use client";

import { useCallback, useEffect, useState } from "react";
import Image from "next/image";
import { Check, ListChecks, RefreshCw, Trash2 } from "lucide-react";

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
  const { token } = useApiSession();
  const { confirmAction } = useAppDialog();
  const [items, setItems] = useState<ReviewItem[]>([]);
  const [loading, setLoading] = useState(true);
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
      setNotice(`${item.name} was confirmed and added to Find.`);
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
      setNotice("Capture dismissed.");
    } catch (reason) {
      setError(userFacingError(reason, "This capture could not be dismissed."));
    } finally {
      setSavingId(null);
    }
  }

  return (
    <section className="product-page review-page">
      <header className="product-page-header review-queue-header">
        <div><h1>Review</h1><p>Uncertain captures wait here instead of becoming incorrect inventory.</p></div>
        <button type="button" className="product-button" onClick={() => void load()} disabled={loading}><RefreshCw size={15} />Refresh</button>
      </header>
      {error && <div className="notice-error">{error}</div>}
      {notice && <div className="notice-success">{notice}</div>}
      {loading && items.length === 0 ? <div className="review-empty"><span className="loading-spinner" />Loading Review…</div> : null}
      {!loading && items.length === 0 ? (
        <div className="review-empty">
          <ListChecks size={25} />
          <strong>Nothing needs review</strong>
          <p>When a photo is uncertain, it will stay here until you assign it or dismiss it.</p>
        </div>
      ) : null}
      <div className="review-queue-list">
        {items.map((item, index) => {
          const saving = savingId === item.review_id;
          return (
            <article className="review-queue-card" key={item.review_id}>
              <header><div><small>CAPTURE {index + 1}</small><h2>{item.name || "Unidentified item"}</h2></div><span>Not in inventory yet</span></header>
              {item.image_url && <Image unoptimized width={720} height={480} className="review-queue-image" src={item.image_url} alt={`Captured ${item.name || "item"}`} />}
              <Evidence item={item} />
              <div className="review-fields">
                <label><span>Name</span><input className="product-input" value={item.name} onChange={(event) => change(item.review_id, { name: event.target.value })} /></label>
                <label><span>Category</span><input className="product-input" value={item.category} onChange={(event) => change(item.review_id, { category: event.target.value })} /></label>
                <label><span>Location</span><input className="product-input" value={item.location ?? ""} placeholder="Required" onChange={(event) => change(item.review_id, { location: event.target.value })} /></label>
                <label><span>Quantity</span><input className="product-input" type="number" min={0} max={100000} value={item.quantity} onChange={(event) => change(item.review_id, { quantity: Number(event.target.value) })} /></label>
                <label><span>Brand</span><input className="product-input" value={item.brand ?? ""} onChange={(event) => change(item.review_id, { brand: event.target.value || null })} /></label>
                <label><span>Part / model #</span><input className="product-input" value={item.part_number ?? ""} onChange={(event) => change(item.review_id, { part_number: event.target.value || null })} /></label>
              </div>
              <label className="review-notes"><span>Notes</span><textarea className="product-textarea" value={item.notes ?? ""} onChange={(event) => change(item.review_id, { notes: event.target.value || null })} /></label>
              <footer>
                <button type="button" className="product-button danger" disabled={saving} onClick={() => void dismiss(item)}><Trash2 size={15} />Dismiss</button>
                <button type="button" className="product-button primary" disabled={saving} onClick={() => void resolve(item)}><Check size={16} />{saving ? "Saving…" : "Confirm and add to Find"}</button>
              </footer>
            </article>
          );
        })}
      </div>
    </section>
  );
}
