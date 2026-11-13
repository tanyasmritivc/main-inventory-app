"use client";

import { useEffect, useRef, useState } from "react";
import { activeInventory } from "@/lib/inventory-selection";
import { compareCad, previewBom, type CadComparison, type BomPreview, type BomMapping, type BomField } from "@/lib/cad";
import styles from "./cad.module.css";
import { CadResults } from "./cad-results";
import { FusionInstallSteps } from "./cad-help";
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
  const inventory = activeInventory();
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

  return <section className={styles.page}>
    <header className={styles.hero}>
      <div className={styles.topline}><a className={styles.guideLink} href="/docs/cad" target="_blank" rel="noreferrer"><BookOpen size={16} /> Setup guide <ArrowUpRight size={14} /></a></div>
      <h1>Know what you can build.</h1>
      <p>Bring a parts list. Find out what you have and what you still need.</p>
    </header>
    <div className={styles.inventoryStrip}><span><Box size={18} /><span>Comparing with <strong>{inventory?.name || "your selected inventory"}</strong></span></span><a href="/cad">Change inventory ↗</a></div>
    <p className={styles.muted}><a href={`/cad/onshape?inventory=${encodeURIComponent(inventory?.inventory_id || "")}`}>Check an Onshape assembly</a> or upload its flattened BOM CSV below.</p>
    <div className={styles.workspace}>
    <div className={styles.flow}>
      <div className={styles.sourceChoices} role="group" aria-label="Parts list source">
        <button aria-pressed={source === "fusion"} onClick={() => setSource("fusion")}><Box size={22} /><span><strong>Autodesk Fusion</strong><small>Export your assembly</small></span>{source === "fusion" && <Check size={16} />}</button>
        <button aria-pressed={source === "spreadsheet"} onClick={() => setSource("spreadsheet")}><FileSpreadsheet size={22} /><span><strong>CSV or Excel</strong><small>Use an existing parts list</small></span>{source === "spreadsheet" && <Check size={16} />}</button>
      </div>
      {source === "fusion" ? <div className={styles.preparation}>
        <div className={styles.stepHeading}><span className={styles.stepNumber}>1</span><div><h2>Get your parts out of Fusion</h2><p>Already exported? Go straight to the upload below.</p></div></div>
        <div className={styles.prepColumns}>
          <div><h3>First time here?</h3><p>Install the free FindEZ add-in on the computer where you use Fusion.</p><a className={styles.downloadLink} href="/downloads/findez-fusion-preview.zip" download><Download size={16} /> Download add-in</a><span className={styles.caption}>Windows and Mac · ZIP download</span></div>
          <div><h3>Add-in already running?</h3><p>Open your assembly. Choose <b>Utilities → Add-Ins → Export FindEZ BOM</b> and save the JSON file.</p><a href="/docs/cad#export" target="_blank" rel="noreferrer">Show export instructions ↗</a></div>
        </div>
        <details className={styles.installDetails}><summary>Show installation steps</summary><FusionInstallSteps /></details>
      </div> : <div className={styles.preparation}>
        <div className={styles.stepHeading}><span className={styles.stepNumber}>1</span><div><h2>Prepare your parts list</h2><p>Use one row per part, with its name and total quantity.</p></div></div>
        <p>Add manufacturer and part number, or a barcode, for accurate matching. Remove subtotals and duplicate summary rows.</p><a className={styles.downloadLink} href="/downloads/findez-bom-template.csv" download><Download size={16} /> Download CSV template</a>
      </div>}
    <div className={styles.card}>
      <div className={styles.stepHeading}><span className={styles.stepNumber}>{file ? <Check size={16} /> : '2'}</span><div><h2>{file ? 'Your parts list is ready' : 'Upload your parts list'}</h2><p>{file ? 'Check the file, then compare it with your inventory.' : source === 'fusion' ? 'Choose the JSON file saved by Export FindEZ BOM.' : 'Choose your CSV or Excel file. You will review its columns next.'}</p></div></div>
      <label className={`${styles.uploadZone} ${file ? styles.hasFile : ''}`}>
        <Upload size={26} aria-hidden="true" /><strong>{file ? file.name : 'Choose a parts list'}</strong>
        <span>{file ? `${(file.size / 1024).toFixed(1)} KB · Click to choose a different file` : 'JSON, CSV or XLSX · Up to 5 MiB'}</span>
        <input aria-label="BOM file" type="file" accept=".json,.csv,.xlsx,application/json,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" disabled={working} onChange={(event) => { const chosen = event.target.files?.[0] ?? null; setFile(chosen); if (chosen) setSource(/\.(csv|xlsx)$/i.test(chosen.name) ? "spreadsheet" : "fusion"); setResult(null); setError(""); setPreview(null); setMapping({}); setConfirmed(false); setSheetIndex(0); }} />
      </label>
      {spreadsheet && !preview && <button disabled={working} onClick={() => void reviewColumns()}>{working ? "Reading columns..." : "Review columns"}</button>}
      {spreadsheet && sheet && <fieldset className={styles.mapping} disabled={working}>
        <legend>Review spreadsheet columns</legend>
        <label>Worksheet<select aria-label="Worksheet" value={sheetIndex} onChange={event => { const index = Number(event.target.value); setSheetIndex(index); setMapping(preview!.sheets[index].suggested_mapping); setConfirmed(false); setResult(null); setError(""); }}>
          {preview!.sheets.map((item, index) => <option key={item.name} value={index}>{item.name} ({item.row_count} rows)</option>)}
        </select></label>
        <div className={styles.mappingGrid}>{([['name', 'Component name *'], ['quantity', 'Required quantity *'], ['part_number', 'Manufacturer part number'], ['manufacturer', 'Manufacturer / brand'], ['barcode', 'Barcode'], ['unit', 'Unit']] as [BomField, string][]).map(([field, label]) => <label key={field}>{label}
          <select aria-label={label} value={mapping[field] ?? ""} onChange={event => { setMapping(current => { const next = { ...current }; if (event.target.value === "") delete next[field]; else next[field] = Number(event.target.value); return next; }); setConfirmed(false); setResult(null); setError(""); }}>
            <option value="">{field === "name" || field === "quantity" ? "Choose column" : "Not included"}</option>
            {sheet.headers.map((header, index) => <option key={index} value={index}>{index + 1}. {header}</option>)}
          </select></label>)}</div>
        <div className={styles.tableWrap} role="region" aria-label="Spreadsheet sample" tabIndex={0}><table><caption>First {sheet.sample.length} rows · {sheet.row_count} total rows in this worksheet</caption>
          <thead><tr>{sheet.headers.map((header, index) => <th key={index} scope="col">{index + 1}. {header}</th>)}</tr></thead>
          <tbody>{sheet.sample.map((row, index) => <tr key={index}>{sheet.headers.map((_, col) => <td key={col}>{row[col] || "Not provided"}</td>)}</tr>)}</tbody></table></div>
        <p className={styles.muted}>Names alone do not confirm a match. Include manufacturer + part number, or a barcode, for exact matching. Only this worksheet is compared.</p>
        <label className={styles.confirm}><input type="checkbox" checked={confirmed} onChange={event => setConfirmed(event.target.checked)} />This is a flat parts list: quantities are total individual units, without assembly, subtotal or duplicate summary rows.</label>
      </fieldset>}
      <p className={styles.muted}>{spreadsheet ? 'Review columns uploads your spreadsheet to read its headers and sample rows. ' : ''}Compare sends your parts metadata to FindEZ. Your design stays in your CAD application and your inventory is not changed. <a href="/docs/cad#privacy" target="_blank" rel="noreferrer">What gets shared?</a></p>
      {!file && <p className={styles.nextHint}>Choose a file above to enable comparison.</p>}
      {spreadsheet && file && !ready && <p className={styles.nextHint}>Before comparing: review columns, map name and quantity, and confirm the parts list.</p>}
      <button className={styles.primary} disabled={!file || working || !ready} onClick={() => void analyze()}>{working ? "Comparing assembly..." : "Compare with inventory"}</button>
      {working && <p role="status">{spreadsheet && !preview ? "Reading spreadsheet columns." : "Checking identifiers and available recorded quantities."}</p>}
      {error && <p role="alert" className={styles.error}>{error}</p>}
    </div>
    </div>
    <aside className={styles.helpRail}>
      <p className={styles.eyebrow}>HERE TO HELP</p><h2>A clear next step,<br />all the way through.</h2>
      <a className={styles.helpItem} href="/docs/cad#install" target="_blank" rel="noreferrer"><span>Install the Fusion add-in<small>Folder picker, Run toggle and setup</small></span><ArrowUpRight size={16} /></a>
      <a className={styles.helpItem} href="/docs/cad#sample" target="_blank" rel="noreferrer"><span>No design to test?<small>Open a free sample in Fusion</small></span><ArrowUpRight size={16} /></a>
      <a className={styles.helpItem} href="/docs/cad#troubleshooting" target="_blank" rel="noreferrer"><span>Something not working?<small>Fix common setup and upload issues</small></span><ArrowUpRight size={16} /></a>
      <div className={styles.supportNote}><p>Still stuck?</p><a href="mailto:info@findez.ai?subject=FindEZ%20CAD%20setup%20help">Email support ↗</a><small>Include the step and a screenshot. No design file needed.</small></div>
    </aside>
    </div>
    {result && <CadResults result={result} onRefresh={() => void analyze()} />}
  </section>;
}
