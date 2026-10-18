"use client";
import { useEffect, useRef, useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";

export function profileCrop(width: number, height: number, zoom: number, x: number, y: number) {
  const size = Math.min(width, height) / Math.max(1, Math.min(6, zoom));
  return { size, x: Math.max(0, Math.min(width - size, x - size / 2)), y: Math.max(0, Math.min(height - size, y - size / 2)) };
}

export function ProfilePhotoCropper({ file, onCancel, onSave }: { file: File; onCancel: () => void; onSave: (photo: File) => Promise<void> }) {
  const canvas = useRef<HTMLCanvasElement>(null), image = useRef<HTMLImageElement | null>(null);
  const [ready, setReady] = useState(false), [error, setError] = useState("");
  const [view, setView] = useState({ zoom: 1, x: 0, y: 0 }), [busy, setBusy] = useState(false);
  const current = useRef(view); current.current = view;
  const alive = useRef(true);
  const points = useRef(new Map<number, { x: number; y: number }>());
  const gesture = useRef({ zoom: 1, distance: 1, anchorX: 0, anchorY: 0 });
  useEffect(() => {
    alive.current = true;
    if (!file.type.startsWith("image/") || !file.size || file.size > 5 * 1024 * 1024) { setError("Choose an image smaller than 5 MB."); return; }
    const url = URL.createObjectURL(file), img = new Image();
    img.onload = () => { if (alive.current) { image.current = img; setView({ zoom: 1, x: img.naturalWidth / 2, y: img.naturalHeight / 2 }); setReady(true); } };
    img.onerror = () => { if (alive.current) setError("This photo could not be opened. Choose another image."); };
    img.src = url;
    return () => { alive.current = false; URL.revokeObjectURL(url); img.onload = null; img.onerror = null; };
  }, [file]);
  useEffect(() => {
    const img = image.current, element = canvas.current;
    if (!ready || !img || !element) return;
    const crop = profileCrop(img.naturalWidth, img.naturalHeight, view.zoom, view.x, view.y);
    element.getContext("2d")?.drawImage(img, crop.x, crop.y, crop.size, crop.size, 0, 0, 512, 512);
  }, [ready, view]);
  function update(zoom: number, x = current.current.x, y = current.current.y) {
    const img = image.current; if (!img || busy) return;
    const next = Math.max(1, Math.min(6, zoom)), crop = profileCrop(img.naturalWidth, img.naturalHeight, next, x, y);
    setView({ zoom: next, x: crop.x + crop.size / 2, y: crop.y + crop.size / 2 });
  }
  function metrics() {
    const values = [...points.current.values()], a = values[0], b = values[1] || a;
    return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, distance: Math.hypot(a.x - b.x, a.y - b.y) || 1 };
  }
  function start() {
    if (!image.current || !points.current.size || !canvas.current) return;
    const point = metrics(), box = canvas.current.getBoundingClientRect(), v = current.current;
    const size = Math.min(image.current.naturalWidth, image.current.naturalHeight) / v.zoom;
    gesture.current = { zoom: v.zoom, distance: point.distance, anchorX: v.x + (point.x / box.width - .5) * size, anchorY: v.y + (point.y / box.height - .5) * size };
  }
  async function save() {
    if (busy || !image.current) return;
    setBusy(true); setError("");
    try {
      const img = image.current, v = current.current, crop = profileCrop(img.naturalWidth, img.naturalHeight, v.zoom, v.x, v.y);
      const output = document.createElement("canvas"); output.width = output.height = 512;
      const context = output.getContext("2d"); if (!context) throw new Error();
      context.drawImage(img, crop.x, crop.y, crop.size, crop.size, 0, 0, 512, 512);
      const blob = await new Promise<Blob>((resolve, reject) => output.toBlob(value => value ? resolve(value) : reject(new Error()), "image/png"));
      if (alive.current) await onSave(new File([blob], "avatar.png", { type: "image/png" }));
    } catch { if (alive.current) setError("The photo could not be saved. Please try again."); }
    finally { if (alive.current) setBusy(false); }
  }
  return <Dialog open onOpenChange={open => { if (!open && !busy) onCancel(); }}><DialogContent className="workspace-dialog" aria-describedby="profile-crop-help">
    <DialogTitle>Adjust profile photo</DialogTitle><DialogDescription id="profile-crop-help">Pinch to zoom and drag to position your photo.</DialogDescription>
    {!ready && !error && <p role="status">Opening photo...</p>}
    <canvas ref={canvas} width={512} height={512} aria-label="Profile photo preview" style={{ width: "100%", maxWidth: 320, aspectRatio: "1", borderRadius: "50%", touchAction: "none", cursor: "grab", margin: "auto" }}
      onPointerDown={event => { if (!ready || busy) return; const box = event.currentTarget.getBoundingClientRect(); points.current.set(event.pointerId, { x: event.clientX - box.left, y: event.clientY - box.top }); event.currentTarget.setPointerCapture(event.pointerId); start(); }}
      onPointerMove={event => { if (!points.current.has(event.pointerId) || !image.current || busy) return; const box = event.currentTarget.getBoundingClientRect(); points.current.set(event.pointerId, { x: event.clientX - box.left, y: event.clientY - box.top }); const point = metrics(), g = gesture.current;
        const zoom = Math.max(1, Math.min(6, g.zoom * point.distance / g.distance)); const size = Math.min(image.current.naturalWidth, image.current.naturalHeight) / zoom;
        update(zoom, g.anchorX - (point.x / box.width - .5) * size, g.anchorY - (point.y / box.height - .5) * size); }}
      onPointerUp={event => { points.current.delete(event.pointerId); start(); }} onPointerCancel={event => { points.current.delete(event.pointerId); start(); }} />
    {ready && <><label>Zoom<input aria-label="Photo zoom" type="range" min={1} max={6} step={.01} value={view.zoom} disabled={busy} onChange={event => update(Number(event.target.value))} /></label>
      <div className="product-actions"><button className="product-button" disabled={busy || view.zoom <= 1} onClick={() => update(view.zoom - .25)}>Zoom out</button><button className="product-button" disabled={busy || view.zoom >= 6} onClick={() => update(view.zoom + .25)}>Zoom in</button><button className="product-button" disabled={busy} onClick={() => { const img = image.current!; update(1, img.naturalWidth / 2, img.naturalHeight / 2); }}>Reset</button></div></>}
    {error && <p role="alert">{error}</p>}
    <div className="product-actions"><button className="product-button" disabled={busy} onClick={onCancel}>Cancel</button><button className="product-button primary" disabled={!ready || busy} onClick={() => void save()}>{busy ? "Saving..." : "Use photo"}</button></div>
  </DialogContent></Dialog>;
}
