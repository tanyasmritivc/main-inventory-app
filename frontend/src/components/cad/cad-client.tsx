"use client";

import { useEffect, useRef, useState } from "react";
import { activeInventory } from "@/lib/inventory-selection";
import { compareCad, shortageCsv, type CadComparison } from "@/lib/cad";
import styles from "./cad.module.css";

const labels = { covered: "Covered", short: "Short", missing: "Missing", needs_review: "Needs review" };

export function CadClient() {
  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState<CadComparison | null>(null);
  const [error, setError] = useState("");
  const [working, setWorking] = useState(false);
  const [filter, setFilter] = useState("all");
  const [page, setPage] = useState(0);
  const controller = useRef<AbortController | null>(null);
  const inventory = activeInventory();
  useEffect(() => () => controller.current?.abort(), []);

  async function analyze() {
    if (!file || working) return;
    const request = new AbortController(); controller.current = request;
    setWorking(true); setError(""); setResult(null); setPage(0);
    try { setResult(await compareCad(file, request.signal)); }
    catch (reason) {
      if (!request.signal.aborted) setError(reason instanceof Error ? reason.message : "The assembly could not be compared.");
    } finally { if (!request.signal.aborted) setWorking(false); }
  }

  function download() {
    if (!result) return;
    const url = URL.createObjectURL(new Blob([shortageCsv(result)], { type: "text/csv;charset=utf-8" }));
    const link = document.createElement("a"); link.href = url; link.download = "findez-cad-shortages.csv";
    link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  const rows = result?.items.filter((line) => filter === "all" || (filter === "shortages" ? line.missing > 0 : line.status === "needs_review")) ?? [];
  const visibleRows = rows.slice(page * 100, (page + 1) * 100);
  return <section className={styles.page}>
    <header><p className={styles.eyebrow}>FUSION PREVIEW</p><h1>Can you build it?</h1>
      <p>Compare your assembly with {inventory?.name || "your selected inventory"}.</p></header>
    <div className={styles.card}>
      <h2>Bring your design to FindEZ</h2>
      <ol><li><a href="/downloads/findez-fusion-preview.zip" download>Download the Fusion add-in</a> and follow the included installation guide.</li>
        <li>Open your assembly and choose <strong>Export FindEZ BOM</strong> from Fusion&apos;s Utilities panel.</li>
        <li>Choose that JSON export below. Your assembly file and geometry stay on your computer.</li></ol>
      <label className={styles.file}>Fusion BOM export<input type="file" accept=".json,application/json" disabled={working} onChange={(event) => { setFile(event.target.files?.[0] ?? null); setResult(null); setError(""); }} /></label>
      <p className={styles.muted}>Compare sends component names, identifiers and assembly structure to FindEZ for this inventory. This preview does not save the BOM, reserve stock or change your design.</p>
      <button className={styles.primary} disabled={!file || working} onClick={() => void analyze()}>{working ? "Comparing assembly..." : "Compare with inventory"}</button>
      {working && <p role="status">Checking identifiers and available recorded quantities.</p>}
      {error && <p role="alert" className={styles.error}>{error}</p>}
    </div>
    {result && <>
      <header><h2>{result.document.name}</h2><p>{result.revision.kind === "unsaved_session" ? "Unsaved design snapshot" : "Saved design version"}{result.revision.configuration && ` / ${result.revision.configuration}`}</p></header>
      <div className={styles.metrics} aria-label="Assembly comparison summary">
        <div className={styles.card}><strong>{result.summary.coverage_percent === null ? "--" : `${result.summary.coverage_percent}%`}</strong><span>Recorded inventory coverage</span></div>
        <div className={styles.card}><strong>{result.summary.shortage_lines}</strong><span>Lines with uncovered units</span></div>
        <div className={styles.card}><strong>{result.summary.review_lines}</strong><span>Lines to review</span></div>
      </div>
      <p className={styles.muted}>Recorded counts may need physical verification. Existing reservations and active checkouts are deducted. This is a read-only preview, not a stock reservation or confirmation that the design is buildable.</p>
      {result.completeness === "partial" && <div className={styles.card} role="status"><h3>Incomplete assembly information</h3><p>Coverage applies only to the counted requirements. Review these warnings before relying on the result.</p><ul>{result.warnings.map((warning, i) => <li key={i}>{warning}</li>)}</ul></div>}
      <div className={styles.actions}><label>Show <select value={filter} onChange={(event) => { setFilter(event.target.value); setPage(0); }}><option value="all">All components</option><option value="shortages">Uncovered units</option><option value="review">Needs review</option></select></label>
        <button onClick={download}>Export shortages</button></div>
      <div className={styles.tableWrap} role="region" aria-label="Component comparison, scroll horizontally for more columns" tabIndex={0}><table><caption>Component requirements and inventory matches</caption><thead><tr><th scope="col">Component</th><th scope="col">Required</th><th scope="col">Covered</th><th scope="col">Missing</th><th scope="col">Status</th></tr></thead>
        <tbody>{visibleRows.map((line) => <tr key={line.key}><th scope="row"><strong>{line.name}</strong><small>{[line.manufacturer, line.part_number].filter(Boolean).join(" / ") || "No supplier identifier"}</small>
          <details><summary>Match evidence</summary>{line.matches.length ? <ul>{line.matches.map((match) => <li key={match.item_id}>{match.evidence}: {match.name} / {match.location || "Unsorted"} / {match.assigned} assigned in preview</li>)}</ul> : <p>{line.possible_matches ? "Potential matches require identity review and do not count toward coverage." : "No exact inventory identity found."}</p>}<p>Procurement policy: {line.procurement_policy}</p></details></th>
          <td>{line.required}</td><td>{line.assigned}</td><td>{line.missing}</td><td>{labels[line.status]}</td></tr>)}</tbody></table>
        {!rows.length && <p className={styles.empty}>No components in this view.</p>}</div>
      {rows.length > 100 && <nav className={styles.actions} aria-label="Component pages">
        <button disabled={page === 0} onClick={() => setPage(page - 1)}>Previous</button>
        <span>Page {page + 1} of {Math.ceil(rows.length / 100)}</span>
        <button disabled={(page + 1) * 100 >= rows.length} onClick={() => setPage(page + 1)}>Next</button>
      </nav>}
      <p className={styles.muted}>Inventory checked {new Date(result.inventory_as_of).toLocaleString()}. Compare again after inventory changes.</p>
    </>}
  </section>;
}
