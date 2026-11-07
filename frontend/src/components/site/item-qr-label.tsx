"use client";
/* eslint-disable @next/next/no-img-element */
import { useEffect, useState } from "react";
import { Download, Printer, Share2 } from "lucide-react";
import type { InventoryItem } from "@/lib/api";
import type { PhotoContext } from "@/lib/item-photos";
import { itemLabel, labelDataUrl, labelImage, printLabels, saveLabel } from "@/lib/item-label";
import { userFacingError } from "@/lib/user-facing-error";

export function ItemQrLabel({ item, context }: { item: InventoryItem; context?: PhotoContext }) {
  const label = itemLabel(item, context), key = JSON.stringify(label);
  const [preview, setPreview] = useState(""), [error, setError] = useState(""), [busy, setBusy] = useState(false), [message, setMessage] = useState("");
  useEffect(() => { let active = true; setPreview(""); setError(""); labelImage(JSON.parse(key)).then(svg => { if (active) setPreview(labelDataUrl(svg)); }).catch(() => { if (active) setError("The label could not be prepared."); }); return () => { active = false; }; }, [key]);
  async function run(action: () => Promise<void>) {
    setBusy(true); setError(""); setMessage("");
    try { await action(); } catch (e) { if (!(e instanceof DOMException && e.name === "AbortError")) setError(userFacingError(e, "The label action could not be completed.")); } finally { setBusy(false); }
  }
  return <section className="item-info-section"><h3>Item QR code</h3>
    {preview && <img className="item-qr-card" src={preview} alt={`Item label: ${item.name}, ${item.location}, quantity ${item.quantity}`} />}
    <p className="workspace-muted">Scan this code to quickly find this item in FindEZ</p>
    <div className="item-info-actions">
      <button type="button" disabled={busy || !preview} onClick={() => void run(async () => { if (navigator.share) await navigator.share({ title: item.name, url: label.data }); else { await navigator.clipboard.writeText(label.data); setMessage("Item link copied."); } })}><Share2 size={15} />Share item</button>
      <button type="button" disabled={busy || !preview} onClick={() => void run(() => printLabels([label]))}><Printer size={15} />Print / PDF</button>
      <button type="button" disabled={busy || !preview} onClick={() => void run(() => saveLabel(label))}><Download size={15} />Save label</button>
    </div>{error && <p role="alert">{error}</p>}{message && <p role="status">{message}</p>}
  </section>;
}
