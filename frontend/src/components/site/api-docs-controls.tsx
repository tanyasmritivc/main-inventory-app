"use client";

import { useState } from "react";
import { endpoints } from "@/lib/api-reference";
import styles from "./api-docs.module.css";

export const guideSections = [
  ["quickstart", "Start here"], ["ai-assistants", "Connect Claude or ChatGPT"], ["authentication", "Authentication & permissions"],
  ["workspaces", "Teams, Spaces & visibility"], ["requests", "Requests & responses"],
  ["recipes", "Integration recipes"], ["sync", "Reliable writes & sync"],
  ["limits", "Limits & retries"], ["errors", "Errors & troubleshooting"],
  ["support", "Support & API coverage"],
] as const;

export function DocsNavigation() {
  const [query, setQuery] = useState("");
  const needle = query.trim().toLowerCase();
  const matches = endpoints.filter((entry) => `${entry.method} ${entry.path} ${entry.summary} ${entry.description} ${entry["x-required-scope"] ?? ""}`.toLowerCase().includes(needle));
  return <nav className={styles.navigation} aria-label="API documentation">
    <label htmlFor="api-docs-search">Find an endpoint</label>
    <input id="api-docs-search" type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Try quantity or bulk" />
    {needle && <p role="status">{matches.length} {matches.length === 1 ? "endpoint" : "endpoints"} found</p>}
    {!needle && <div className={styles.navGroup}><span>Guide</span>{guideSections.map(([id, title]) => <a key={id} href={`#${id}`}>{title}</a>)}</div>}
    <div className={styles.navGroup}><span>Endpoint reference</span>{matches.map((entry) => <a key={entry.operationId} href={`#${entry.operationId}`}><small>{entry.method}</small>{entry.path.replace("/api/v1", "")}</a>)}</div>
    {needle && <button type="button" onClick={() => setQuery("")}>Clear search</button>}
  </nav>;
}

export function CodeExample({ examples, label }: { examples: Record<string, string>; label: string }) {
  const [selected, setSelected] = useState(Object.keys(examples)[0]);
  const [message, setMessage] = useState("");
  const code = examples[selected];
  async function copy() {
    try { await navigator.clipboard.writeText(code); setMessage("Copied"); }
    catch { setMessage("Copy unavailable. Select and copy the code below."); }
  }
  return <div className={styles.codeExample}>
    <div className={styles.codeToolbar}>
      <label>{label}{Object.keys(examples).length > 1 && <select aria-label={`${label} language`} value={selected} onChange={(event) => { setSelected(event.target.value); setMessage(""); }}>{Object.keys(examples).map((language) => <option key={language}>{language}</option>)}</select>}</label>
      <button type="button" aria-label={`Copy ${label}`} onClick={() => void copy()}>Copy</button>
    </div>
    {message && <p role="status" className={styles.copyStatus}>{message}</p>}
    <pre tabIndex={0} aria-label={label}><code>{code}</code></pre>
  </div>;
}
