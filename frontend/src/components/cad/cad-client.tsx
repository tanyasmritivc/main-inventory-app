"use client";

import { cadWorldPath } from "@/lib/cad-links";
import { useEffect, useRef, useState } from "react";
import { activeInventory } from "@/lib/inventory-selection";
import { compareCad, previewBom, type CadComparison, type BomPreview, type BomMapping, type BomField } from "@/lib/cad";
import styles from "./cad.module.css";
import { CadHistory } from "./cad-history";
import { CadResults } from "./cad-results";
import { Box, FileSpreadsheet, Upload, BookOpen, ArrowUpRight, Check, Download } from "lucide-react";



export function CadClient() {
  const [source, setSource] = useState<"fusion" | "spreadsheet">("fusion");
  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState<CadComparison | null>(null);
  const [error, setError] = useState("");
  const [preview, setPreview] = useState<BomPreview | null>(null);
  const [sheetIndex, setSheetIndex] = useState(0);
  const [mapping, setMapping] = useState<BomMapping>({});
  const [confirmed, setConfirmed] = useState(false);
  const [working, setWorking] = useState(false);
  const controller = useRef<AbortController | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const inventory = activeInventory();
  const world = inventory?.workspace?.organization_id;
  function selectSource(next: typeof source) {
    if (source === next || working) return;
    if (fileInput.current) fileInput.current.value = "";
    setSource(next);
    setFile(null);
    setPreview(null);
    setMapping({});
    setConfirmed(false);
    setSheetIndex(0);
    setError("");
    setResult(null);
  }
  useEffect(() => () => controller.current?.abort(), []);

  const spreadsheet = !!file && /\.(csv|xlsx)$/i.test(file.name);
  const sheet = preview?.sheets[sheetIndex];
  const ready = !spreadsheet || (!!sheet && mapping.name !== undefined && mapping.quantity !== undefined && confirmed);

  async function reviewColumns() {
    if (!file || working) return;
    const request = new AbortController(); controller.current = request;
    setWorking(true); setError(""); setResult(null); setPreview(null); setConfirmed(false);
    try {
      const data = await previewBom(file, request.signal);
      if (request.signal.aborted) return;
      setPreview(data); setSheetIndex(0); setMapping(data.sheets[0]?.suggested_mapping || {});
    } catch (reason) {
      if (!request.signal.aborted) setError(reason instanceof Error ? reason.message : "The spreadsheet could not be read.");
    } finally { if (!request.signal.aborted) setWorking(false); }
  }

  async function analyze() {
    if (!file || working || !ready) return;
    const request = new AbortController(); controller.current = request;
    setWorking(true); setError(""); setResult(null);
    try {
      const data = await compareCad(file, request.signal, spreadsheet && sheet ? { sheet: sheet.name, mapping, confirmed } : undefined);
      if (!request.signal.aborted) setResult(data);
    }
    catch (reason) {
      if (!request.signal.aborted) setError(reason instanceof Error ? reason.message : "The assembly could not be compared.");
    } finally { if (!request.signal.aborted) setWorking(false); }
  }

  function columnPicker([field, label]: [BomField, string]) {
    return <label key={field}>{label}
          <select aria-label={label} value={mapping[field] ?? ""} onChange={event => { setMapping(current => { const next = { ...current }; if (event.target.value === "") delete next[field]; else next[field] = Number(event.target.value); return next; }); setConfirmed(false); setResult(null); setError(""); }}>
            <option value="">{field === "name" || field === "quantity" ? "Choose column" : "Not included"}</option>
            {sheet?.headers.map((header, index) => <option key={index} value={index}>{index + 1}. {header}</option>)}
          </select></label>;
  }

  return <section className={styles.page}>
    <header className={styles.hero}>
      <div className={styles.topline}><a className={styles.guideLink} href={cadWorldPath("/docs/cad", world)}><BookOpen size={16} /> CAD Intelligence <ArrowUpRight size={14} /></a></div>
      <h1>Compare a parts list.</h1>
      <p>Upload a parts list, review saved BOM versions, and manage purchase plans for this inventory.</p>
    </header>
    <div className={styles.inventoryStrip}><span><Box size={18} /><span>Comparing with <strong>{inventory?.name || "your selected inventory"}</strong></span></span><a href={cadWorldPath("/cad", world)}>Change inventory ↗</a></div>
    <CadHistory />
    <header className={styles.uploadIntro} id="browser-comparison"><h2>Upload a parts list</h2><p>Upload a Fusion BOM or a spreadsheet as an alternative to the connected panel. Choose a source below to get started.</p></header>
    <div className={styles.workspace}>
    <div className={styles.flow}>
      <div className={styles.sourceChoices} role="group" aria-label="Parts list source">
        <button aria-pressed={source === "fusion"} disabled={working} onClick={() => selectSource("fusion")}><Box size={22} /><span><strong>Fusion BOM file</strong><small>Upload an exported JSON</small></span>{source === "fusion" && <Check size={16} />}</button>
        <button aria-pressed={source === "spreadsheet"} disabled={working} onClick={() => selectSource("spreadsheet")}><FileSpreadsheet size={22} /><span><strong>CSV or Excel</strong><small>Use an existing parts list</small></span>{source === "spreadsheet" && <Check size={16} />}</button>
      </div>
      {source === "fusion" ? <div className={styles.preparation}>
        <div className={styles.stepHeading}><span className={styles.stepNumber}>1</span><div><h2>Export a BOM for web comparison</h2><p>Already exported? Go straight to the upload below.</p></div></div>
        <p>Open your assembly in Fusion. Choose <b>Utilities → Add-Ins → Export FindEZ BOM</b> and save the JSON file. You can skip this export when comparing inside the connected FindEZ panel.</p><a href={cadWorldPath("/docs/cad#export", world)} target="_blank" rel="noreferrer">Show export instructions ↗</a>
      </div> : <div className={styles.preparation}>
        <div className={styles.stepHeading}><span className={styles.stepNumber}>1</span><div><h2>Prepare your parts list</h2><p>Use one row per part, with its name and total quantity.</p></div></div>
        <p>Add manufacturer and part number, or a barcode, for accurate matching. Remove subtotals and duplicate summary rows.</p><a className={styles.downloadLink} href="/downloads/findez-bom-template.csv" download><Download size={16} /> Download CSV template</a>
      </div>}
    <div className={styles.card}>
      <div className={styles.stepHeading}><span className={styles.stepNumber}>{file ? <Check size={16} /> : '2'}</span><div><h2>{file ? 'Your parts list is ready' : 'Upload your parts list'}</h2><p>{file ? 'Check the file, then compare it with your inventory.' : source === 'fusion' ? 'Choose the JSON file saved by Export FindEZ BOM.' : 'Choose your CSV or Excel file. You will review its columns next.'}</p></div></div>
      <label className={`${styles.uploadZone} ${file ? styles.hasFile : ''}`}>
        <Upload size={26} aria-hidden="true" /><strong>{file ? file.name : 'Choose a parts list'}</strong>
        <span>{file ? `${(file.size / 1024).toFixed(1)} KB · Click to choose a different file` : 'JSON, CSV or XLSX · Up to 5 MiB'}</span>
        <input ref={fileInput} aria-label="BOM file" type="file" accept=".json,.csv,.xlsx,application/json,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" disabled={working} onChange={(event) => { const chosen = event.target.files?.[0] ?? null; setFile(chosen); if (chosen) setSource(/\.(csv|xlsx)$/i.test(chosen.name) ? "spreadsheet" : "fusion"); setResult(null); setError(""); setPreview(null); setMapping({}); setConfirmed(false); setSheetIndex(0); }} />
      </label>
      {spreadsheet && !preview && <button disabled={working} onClick={() => void reviewColumns()}>{working ? "Reading columns..." : "Review columns"}</button>}
      {spreadsheet && sheet && <fieldset className={styles.mapping} disabled={working}>
        <legend>Review spreadsheet columns</legend>
        <label>Worksheet<select aria-label="Worksheet" value={sheetIndex} onChange={event => { const index = Number(event.target.value); setSheetIndex(index); setMapping(preview!.sheets[index].suggested_mapping); setConfirmed(false); setResult(null); setError(""); }}>
          {preview!.sheets.map((item, index) => <option key={item.name} value={index}>{item.name} ({item.row_count} rows)</option>)}
        </select></label>
        <div className={styles.mappingGrid}>{([['name', 'Component name *'], ['quantity', 'Required quantity *'], ['part_number', 'Manufacturer part number'], ['manufacturer', 'Manufacturer / brand'], ['barcode', 'Barcode'], ['unit', 'Unit']] as [BomField, string][]).map(columnPicker)}</div>
        <details><summary>Engineering specifications</summary>
          <p>Map dimensions, material and other requirements that identify the exact variant. Include units in dimension cells or column headers.</p>
          <div className={styles.mappingGrid}>{([['length_mm', 'Length'], ['diameter_mm', 'Diameter'], ['thread_pitch_mm', 'Thread pitch'], ['inner_diameter_mm', 'Inner diameter'], ['outer_diameter_mm', 'Outer diameter'], ['thickness_mm', 'Thickness'], ['width_mm', 'Width'], ['height_mm', 'Height'], ['material', 'Material'], ['finish', 'Finish'], ['head_type', 'Head type'], ['thread_direction', 'Thread direction'], ['thread_standard', 'Thread standard'], ['strength_grade', 'Strength grade'], ['part_type', 'Part type'], ['thread_fit', 'Thread fit']] as [BomField, string][]).map(columnPicker)}</div>
        </details>
        <div className={styles.tableWrap} role="region" aria-label="Spreadsheet sample" tabIndex={0}><table><caption>First {sheet.sample.length} rows · {sheet.row_count} total rows in this worksheet</caption>
          <thead><tr>{sheet.headers.map((header, index) => <th key={index} scope="col">{index + 1}. {header}</th>)}</tr></thead>
          <tbody>{sheet.sample.map((row, index) => <tr key={index}>{sheet.headers.map((_, col) => <td key={col}>{row[col] || "Not provided"}</td>)}</tr>)}</tbody></table></div>
        <p className={styles.muted}>Names alone do not confirm a match. Include manufacturer + part number, or a barcode, for exact matching. Only this worksheet is compared.</p>
        <label className={styles.confirm}><input type="checkbox" checked={confirmed} onChange={event => setConfirmed(event.target.checked)} />This is a flat parts list: quantities are total individual units, without assembly, subtotal or duplicate summary rows.</label>
      </fieldset>}
      <p className={styles.muted}>{spreadsheet ? 'Review columns uploads your spreadsheet to read its headers and sample rows. ' : ''}Compare sends your parts metadata to FindEZ. Your design stays in your CAD application and your inventory is not changed. <a href={cadWorldPath("/docs/cad#privacy", world)} target="_blank" rel="noreferrer">What gets shared?</a></p>
      {!file && <p className={styles.nextHint}>Choose a file above to enable comparison.</p>}
      {spreadsheet && file && !ready && <p className={styles.nextHint}>Before comparing: review columns, map name and quantity, and confirm the parts list.</p>}
      <button className={styles.primary} disabled={!file || working || !ready} onClick={() => void analyze()}>{working ? "Comparing assembly..." : "Compare with inventory"}</button>
      {working && <p role="status">{spreadsheet && !preview ? "Reading spreadsheet columns." : "Checking identifiers and available recorded quantities."}</p>}
      {error && <p role="alert" className={styles.error}>{error}</p>}
    </div>
    </div>
    <aside className={styles.helpRail}>
      <p className={styles.eyebrow}>HERE TO HELP</p><h2>A clear next step,<br />all the way through.</h2>
      <a className={styles.helpItem} href={cadWorldPath("/docs/cad#install", world)} target="_blank" rel="noreferrer"><span>Install the Fusion add-in<small>Folder picker, Run toggle and setup</small></span><ArrowUpRight size={16} /></a>
      <a className={styles.helpItem} href={inventory?.inventory_id ? `/cad/fusion/connect?inventory=${encodeURIComponent(inventory.inventory_id)}` : cadWorldPath("/cad/fusion/connect", world)}><span>Manage Fusion connections<small>Review or disconnect an inventory session</small></span><ArrowUpRight size={16} /></a>
      <a className={styles.helpItem} href={cadWorldPath("/docs/cad#onshape", world)}><span>Using Onshape?<small>Compare a flattened BOM CSV</small></span><ArrowUpRight size={16} /></a>
      <a className={styles.helpItem} href={cadWorldPath("/docs/cad#sample", world)} target="_blank" rel="noreferrer"><span>No design to test?<small>Open a free sample in Fusion</small></span><ArrowUpRight size={16} /></a>
      <a className={styles.helpItem} href={cadWorldPath("/docs/cad#troubleshooting", world)} target="_blank" rel="noreferrer"><span>Something not working?<small>Fix common setup and upload issues</small></span><ArrowUpRight size={16} /></a>
      <div className={styles.supportNote}><p>Still stuck?</p><a href="mailto:info@findez.ai?subject=FindEZ%20CAD%20setup%20help">Email support ↗</a><small>Include the step and a screenshot. No design file needed.</small></div>
    </aside>
    </div>
    {result && <CadResults result={result} onRefresh={() => void analyze()} />}
  </section>;
}
