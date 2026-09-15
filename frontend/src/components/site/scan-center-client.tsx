"use client";

import Link from "next/link";
import { ChangeEvent, useEffect, useRef, useState } from "react";
import { Barcode, Camera, FileSpreadsheet, FolderKanban, Plus, UploadCloud } from "lucide-react";
import { ExtractedInventoryItem, bulkCreate, createSpace, extractFromImageMulti, getSpaces, processBarcode } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { BarcodeScanner } from "@/components/site/zxing-scanner";
import { SpreadsheetImportModal } from "@/components/site/spreadsheet-import-modal";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { userFacingError } from "@/lib/user-facing-error";

type ScanMode = "barcode" | "photo" | "spreadsheet" | "bom";

function formatFieldName(value: string) {
  return value.replaceAll("_", " ").replace(/\b\w/g, (character) => character.toUpperCase());
}

export function ScanCenterClient() {
  const { token } = useApiSession();
  const { promptValue } = useAppDialog();
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

  async function addDestinationSpace() {
    const name = (await promptValue({ title: "Create a Space", message: "Choose where imported items should be saved.", label: "Space name", placeholder: "Build room", confirmLabel: "Create Space" }))?.trim();
    if (!token || !name) return;
    setWorking(true); setError(null);
    try {
      await createSpace({ token, name });
      const rows = await getSpaces({ token });
      setSpaces(rows.map((row) => row.name));
      setSpace(name);
      setSaved(`${name} is ready as a destination.`);
    } catch (reason) {
      setError(userFacingError(reason, "The Space could not be created."));
    } finally { setWorking(false); }
  }

  async function lookup(value = barcode) {
    if (!token || !value.trim()) return;
    setWorking(true); setError(null); setSaved(null);
    try { const result = await processBarcode({ token, barcode: value.trim() }); setBarcodeResult(result.result ?? result); }
    catch (reason) { setError(userFacingError(reason, "The barcode could not be looked up.")); }
    finally { setWorking(false); }
  }

  async function scanPhoto(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]; if (!token || !file) return;
    setWorking(true); setError(null); setItems([]); setSaved(null);
    try { const result = await extractFromImageMulti({ token, file }); setItems((result.items ?? []).map((item) => ({ ...item, location: item.location || space }))); }
    catch (reason) { setError(userFacingError(reason, "The photo could not be analyzed.")); }
    finally { setWorking(false); event.target.value = ""; }
  }

  async function saveDetected() {
    if (!token || items.length === 0) return;
    setWorking(true); setError(null);
    try { const result = await bulkCreate({ token, items: items.map((item) => ({ ...item, location: item.location || space })) }); setSaved(`${result.inserted.length} item${result.inserted.length === 1 ? "" : "s"} added to ${space}.`); setItems([]); }
    catch (reason) { setError(userFacingError(reason, "The detected items could not be saved.")); }
    finally { setWorking(false); }
  }

  const modes: Array<{ id: ScanMode; label: string; icon: typeof Barcode }> = [
    { id: "barcode", label: "Barcode", icon: Barcode },
    { id: "photo", label: "Photo", icon: Camera },
    { id: "spreadsheet", label: "Spreadsheet", icon: FileSpreadsheet },
    { id: "bom", label: "BOM", icon: FolderKanban },
  ];

  const barcodeFields = Object.entries(barcodeResult ?? {}).filter(([, value]) => value == null || ["string", "number", "boolean"].includes(typeof value)).slice(0, 8);

  return (
    <section className="product-page scan-page">
      <header className="product-page-header">
        <h1>Add items</h1>
        <div className="scan-destination">
          <span>to</span>
          <select id="scan-destination" className="product-select" value={space} onChange={(event) => setSpace(event.target.value)}>{["Unsorted", ...spaces.filter((name) => name !== "Unsorted")].map((name) => <option key={name}>{name}</option>)}</select>
          <button className="app-icon-button" type="button" onClick={() => void addDestinationSpace()} disabled={working} aria-label="New Space"><Plus size={16} /></button>
        </div>
      </header>
      {error && <div className="notice-error">{error}</div>}
      {saved && <div className="notice-success">{saved}</div>}

      <nav className="source-tabs" aria-label="Import method">
        {modes.map(({ id, label, icon: Icon }) => (
          <button className={mode === id ? "is-active" : ""} key={id} onClick={() => setMode(id)}><Icon size={16} /><span>{label}</span></button>
        ))}
      </nav>

      <div className="scan-stage">
        {mode === "barcode" && (
          <div className="barcode-layout">
            <div className="barcode-camera"><BarcodeScanner onDetected={(value) => { setBarcode(value); void lookup(value); }} /></div>
            <div className="barcode-entry">
              <h2>Barcode</h2>
              <div className="scan-input-action"><input id="barcode-value" className="product-input" value={barcode} onChange={(event) => setBarcode(event.target.value)} placeholder="UPC, EAN, or manufacturer code" /><button className="product-button primary" disabled={!barcode.trim() || working} onClick={() => void lookup()}>{working ? "Looking up…" : "Look up"}</button></div>
              {barcodeResult && <div className="scan-result"><strong>Found</strong>{barcodeFields.map(([key, value]) => <div key={key}><span>{formatFieldName(key)}</span><b>{value == null || value === "" ? "—" : String(value)}</b></div>)}</div>}
            </div>
          </div>
        )}

        {mode === "photo" && (
          <div className="photo-stage">
            <button className="capture-dropzone" onClick={() => photoRef.current?.click()} disabled={working}><UploadCloud size={22} /><strong>{working ? "Analyzing…" : "Choose photo"}</strong><span>JPG, PNG or HEIC</span></button>
            <input ref={photoRef} type="file" accept="image/*" hidden onChange={(event) => void scanPhoto(event)} />
            {items.length > 0 && <div className="detected-items"><div className="detected-header"><strong>{items.length} items</strong><button className="product-button primary" onClick={() => void saveDetected()} disabled={working}>Save to {space}</button></div><div className="detected-table-head"><span>Item</span><span>Category</span><span>Qty</span><span /></div>{items.map((item, index) => <div className="detected-row" key={`${item.name}-${index}`}><input aria-label={`Item ${index + 1} name`} className="product-input" value={item.name} onChange={(event) => setItems((current) => current.map((row, rowIndex) => rowIndex === index ? { ...row, name: event.target.value } : row))} /><input aria-label={`Item ${index + 1} category`} className="product-input" value={item.category} onChange={(event) => setItems((current) => current.map((row, rowIndex) => rowIndex === index ? { ...row, category: event.target.value } : row))} /><input aria-label={`Item ${index + 1} quantity`} className="product-input" type="number" min={0} value={item.quantity} onChange={(event) => setItems((current) => current.map((row, rowIndex) => rowIndex === index ? { ...row, quantity: Number(event.target.value) } : row))} /><button onClick={() => setItems((current) => current.filter((_, rowIndex) => rowIndex !== index))}>Remove</button></div>)}</div>}
          </div>
        )}

        {mode === "spreadsheet" && <div className="scan-choice"><FileSpreadsheet size={24} /><h2>Spreadsheet</h2><button className="product-button primary" onClick={() => setSpreadsheetOpen(true)}>Choose file</button></div>}
        {mode === "bom" && <div className="scan-choice"><FolderKanban size={24} /><h2>Project BOM</h2><Link className="product-button primary" href="/project-kits">Open kits</Link></div>}
      </div>
      {token && <Dialog open={spreadsheetOpen} onOpenChange={setSpreadsheetOpen}><DialogContent><SpreadsheetImportModal spaceName={space} token={token} onSuccess={(count) => { setSaved(`${count} item${count === 1 ? "" : "s"} imported into ${space}.`); }} /></DialogContent></Dialog>}
    </section>
  );
}
