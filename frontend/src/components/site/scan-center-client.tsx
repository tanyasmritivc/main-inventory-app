"use client";

import Link from "next/link";
import { ChangeEvent, useEffect, useRef, useState } from "react";
import { Barcode, Camera, FileSpreadsheet, FolderKanban, Plus, UploadCloud } from "lucide-react";
import { ExtractedInventoryItem, bulkCreate, extractFromImageMulti, getSpaces, processBarcode } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { BarcodeScanner } from "@/components/site/zxing-scanner";
import { SpreadsheetImportModal } from "@/components/site/spreadsheet-import-modal";
import { Dialog, DialogContent } from "@/components/ui/dialog";

type ScanMode = "barcode" | "photo" | "spreadsheet" | "bom";

export function ScanCenterClient() {
  const { token } = useApiSession();
  const [mode, setMode] = useState<ScanMode>("barcode");
  const [space, setSpace] = useState("Unsorted");
  const [spaces, setSpaces] = useState<string[]>([]);
  const [barcode, setBarcode] = useState("");
  const [barcodeResult, setBarcodeResult] = useState<Record<string, unknown> | null>(null);
  const [items, setItems] = useState<ExtractedInventoryItem[]>([]);
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const [spreadsheetOpen, setSpreadsheetOpen] = useState(false);
  const photoRef = useRef<HTMLInputElement>(null);

  useEffect(() => { if (token) getSpaces({ token }).then((rows) => setSpaces(rows.map((row) => row.name))).catch(() => {}); }, [token]);

  async function lookup(value = barcode) {
    if (!token || !value.trim()) return;
    setWorking(true); setError(null); setSaved(null);
    try { const result = await processBarcode({ token, barcode: value.trim() }); setBarcodeResult(result.result ?? result); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Barcode lookup failed."); }
    finally { setWorking(false); }
  }

  async function scanPhoto(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]; if (!token || !file) return;
    setWorking(true); setError(null); setItems([]); setSaved(null);
    try { const result = await extractFromImageMulti({ token, file }); setItems((result.items ?? []).map((item) => ({ ...item, location: item.location || space }))); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Photo analysis failed."); }
    finally { setWorking(false); event.target.value = ""; }
  }

  async function saveDetected() {
    if (!token || items.length === 0) return;
    setWorking(true); setError(null);
    try { const result = await bulkCreate({ token, items: items.map((item) => ({ ...item, location: item.location || space })) }); setSaved(`${result.inserted.length} item${result.inserted.length === 1 ? "" : "s"} added to ${space}.`); setItems([]); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Detected items could not be saved."); }
    finally { setWorking(false); }
  }

  const modes: Array<{ id: ScanMode; label: string; icon: typeof Barcode }> = [
    { id: "barcode", label: "Barcode", icon: Barcode }, { id: "photo", label: "Photo", icon: Camera },
    { id: "spreadsheet", label: "Spreadsheet", icon: FileSpreadsheet }, { id: "bom", label: "Project BOM", icon: FolderKanban },
  ];

  return (
    <section className="product-page">
      <header className="product-page-header"><div><h1>Scan & import</h1><p>Use the right capture tool for one part, a shelf, or an entire project.</p></div><Link className="product-button" href="/inventory"><Plus size={15} />Add manually</Link></header>
      <div className="capture-mode-grid">{modes.map(({ id, label, icon: Icon }) => <button className={mode === id ? "is-active" : ""} key={id} onClick={() => setMode(id)}><Icon size={19} /><span>{label}</span></button>)}</div>
      {error && <div className="notice-error">{error}</div>}{saved && <div className="notice-success">{saved}</div>}
      <div className="capture-workspace product-card">
        <div className="capture-toolbar"><label>Destination Space<select className="product-select" value={space} onChange={(event) => setSpace(event.target.value)}>{["Unsorted", ...spaces.filter((name) => name !== "Unsorted")].map((name) => <option key={name}>{name}</option>)}</select></label></div>
        {mode === "barcode" && <div className="capture-panel"><div><h2>Scan a product barcode</h2><p>Use your webcam or enter the code printed on the part.</p></div><div className="barcode-layout"><div className="barcode-camera"><BarcodeScanner onDetected={(value) => { setBarcode(value); void lookup(value); }} /></div><div className="barcode-entry"><input className="product-input" value={barcode} onChange={(event) => setBarcode(event.target.value)} placeholder="UPC, EAN, or manufacturer code" /><button className="product-button primary" disabled={!barcode.trim() || working} onClick={() => void lookup()}>{working ? "Looking up…" : "Look up"}</button>{barcodeResult && <pre>{JSON.stringify(barcodeResult, null, 2)}</pre>}</div></div></div>}
        {mode === "photo" && <div className="capture-panel"><div><h2>Extract items from a photo</h2><p>Best for bins, shelves, receipts, and laid-out parts. Review every result before saving.</p></div><button className="capture-dropzone" onClick={() => photoRef.current?.click()} disabled={working}><UploadCloud size={24} /><strong>{working ? "Analyzing photo…" : "Choose or take a photo"}</strong><span>JPG, PNG, or HEIC</span></button><input ref={photoRef} type="file" accept="image/*" hidden onChange={(event) => void scanPhoto(event)} />{items.length > 0 && <div className="detected-items"><div className="detected-header"><strong>{items.length} detected items</strong><button className="product-button primary" onClick={() => void saveDetected()} disabled={working}>Save all</button></div>{items.map((item, index) => <div className="detected-row" key={`${item.name}-${index}`}><input className="product-input" value={item.name} onChange={(event) => setItems((current) => current.map((row, rowIndex) => rowIndex === index ? { ...row, name: event.target.value } : row))} /><input className="product-input" value={item.category} onChange={(event) => setItems((current) => current.map((row, rowIndex) => rowIndex === index ? { ...row, category: event.target.value } : row))} /><input className="product-input" type="number" min={0} value={item.quantity} onChange={(event) => setItems((current) => current.map((row, rowIndex) => rowIndex === index ? { ...row, quantity: Number(event.target.value) } : row))} /><button onClick={() => setItems((current) => current.filter((_, rowIndex) => rowIndex !== index))}>Remove</button></div>)}</div>}</div>}
        {mode === "spreadsheet" && <div className="capture-panel compact"><FileSpreadsheet size={28} /><h2>Import a spreadsheet</h2><p>Map CSV or Excel rows into the selected Space and review failures after import.</p><button className="product-button primary" onClick={() => setSpreadsheetOpen(true)}>Choose spreadsheet</button></div>}
        {mode === "bom" && <div className="capture-panel compact"><FolderKanban size={28} /><h2>Project readiness</h2><p>Upload a bill of materials, compare requirements with live stock, and reserve available parts.</p><Link className="product-button primary" href="/project-kits">Open project kits</Link></div>}
      </div>
      {token && <Dialog open={spreadsheetOpen} onOpenChange={setSpreadsheetOpen}><DialogContent><SpreadsheetImportModal spaceName={space} token={token} onSuccess={(count) => { setSaved(`${count} item${count === 1 ? "" : "s"} imported into ${space}.`); }} /></DialogContent></Dialog>}
    </section>
  );
}
