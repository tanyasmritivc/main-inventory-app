"use client";
import { useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
import type { CadCandidate, CadLine } from "@/lib/cad";

export function CadCorrection({ line, onRefresh }: { line: CadLine; onRefresh: () => void }) {
  const [items, setItems] = useState<CadCandidate[]>(line.candidates || []);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const controller = useRef<AbortController | null>(null);
  useEffect(() => () => controller.current?.abort(), []);
  const inventory = activeInventory();
  if (!inventory?.can_edit) return null;
  const actor = inventory.accountId;
  async function search() {
    if (busy || query.trim().length < 2) return;
    const request = new AbortController(); controller.current = request;
    setBusy(true); setMessage("");
    try {
      const result = await accountRequest<{ items: CadCandidate[] }>(actor, `/cad/candidates?q=${encodeURIComponent(query.trim())}`, { signal: request.signal });
      if (!request.signal.aborted) { setItems(result.items); setSelected(""); if (!result.items.length) setMessage("No items found in this inventory."); }
    } catch (e) { if (!request.signal.aborted) setMessage(e instanceof Error ? e.message : "Search failed."); }
    finally { if (!request.signal.aborted) setBusy(false); }
  }
  async function save(decision: "match" | "no_match" | "reset") {
    if (busy || (decision === "match" && !selected)) return;
    const request = new AbortController(); controller.current = request;
    setBusy(true); setMessage("");
    try {
      await accountRequest(actor, "/cad/corrections", { method: "POST", signal: request.signal,
        body: JSON.stringify({ review_token: line.review_token, decision, item_id: decision === "match" ? selected : null }) });
      if (!request.signal.aborted) { setMessage("Correction saved. Refreshing comparison..."); onRefresh(); }
    } catch (e) { if (!request.signal.aborted) setMessage(e instanceof Error ? e.message : "Correction could not be saved."); }
    finally { if (!request.signal.aborted) setBusy(false); }
  }
  return <details><summary>Correct this match</summary><p>This decision is shared with this inventory. It does not change stock or your design.</p>
    <label>Find an inventory item<input value={query} onChange={e => setQuery(e.target.value)} maxLength={100} /></label>
    <button disabled={busy || query.trim().length < 2} onClick={() => void search()}>Search inventory</button>
    <label>Match to<select value={selected} onChange={e => setSelected(e.target.value)} disabled={busy}><option value="">Choose an item</option>
      {items.map(i => <option key={i.item_id} value={i.item_id}>{i.name} / {i.part_number || "No part number"} / {i.location || "Unsorted"}</option>)}
    </select></label>
    <button disabled={busy || !selected} onClick={() => void save("match")}>Remember this match</button>
    <button disabled={busy} onClick={() => void save("no_match")}>None of these match</button>
    <button disabled={busy} onClick={() => void save("reset")}>Forget saved correction</button>
    {message && <p role="status">{message}</p>}
  </details>;
}
