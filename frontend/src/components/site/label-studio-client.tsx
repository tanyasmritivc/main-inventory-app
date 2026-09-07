/* eslint-disable @next/next/no-img-element */
"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CheckSquare, MousePointerClick, Printer, QrCode, Square } from "lucide-react";
import QRCode from "qrcode";
import { InventoryItem, Space, getSpaces, itemDisplayDescription, itemDisplayName, searchItems } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

type LabelRecord = {
  id: string;
  title: string;
  subtitle: string;
  data: string;
  details: string[];
};

export function LabelStudioClient() {
  const { token } = useApiSession();
  const [mode, setMode] = useState<"spaces" | "items">("spaces");
  const [spaces, setSpaces] = useState<Space[]>([]);
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [codes, setCodes] = useState<Record<string, string>>({});
  const [query, setQuery] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!token) return;
    Promise.all([getSpaces({ token }), searchItems({ token, query: "" })])
      .then(([spaceRows, inventory]) => {
        setSpaces(spaceRows);
        setItems(inventory.items ?? []);
      })
      .catch(() => setError("Labels could not be loaded. Try refreshing this page."));
  }, [token]);

  const labels = useMemo<LabelRecord[]>(() => {
    if (mode === "spaces") {
      return spaces.map((space) => {
        const rows = items.filter(
          (item) => item.location.trim().toLowerCase() === space.name.trim().toLowerCase(),
        );
        const categoryCounts = new Map<string, number>();
        rows.forEach((item) => {
          const category = item.category || "Other";
          categoryCounts.set(category, (categoryCounts.get(category) ?? 0) + 1);
        });
        return {
          id: space.id,
          title: space.name,
          subtitle: `${rows.length} item${rows.length === 1 ? "" : "s"}`,
          data: `findez://space/${encodeURIComponent(space.name)}`,
          details: [...categoryCounts.entries()]
            .sort((a, b) => b[1] - a[1])
            .slice(0, 6)
            .map(([name, count]) => `${name} · ${count}`),
        };
      });
    }

    return items.map((item) => ({
      id: item.item_id,
      title: itemDisplayName(item),
      subtitle: [itemDisplayDescription(item), item.brand].filter(Boolean).join(" · ") || item.category,
      data: item.item_id,
      details: [
        item.location,
        `Quantity ${item.quantity}`,
        item.barcode ? `Barcode ${item.barcode}` : "",
      ].filter(Boolean),
    }));
  }, [items, mode, spaces]);

  const filtered = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return labels.filter((label) =>
      `${label.title} ${label.subtitle} ${label.details.join(" ")}`
        .toLowerCase()
        .includes(normalizedQuery),
    );
  }, [labels, query]);

  const chosen = useMemo(
    () => labels.filter((label) => selected.has(label.id)),
    [labels, selected],
  );

  const generateCodes = useCallback(async (rows: LabelRecord[]) => {
    const next: Record<string, string> = {};
    await Promise.all(rows.map(async (row) => {
      next[row.id] = await QRCode.toDataURL(row.data, {
        width: 360,
        margin: 1,
        color: { dark: "#050505", light: "#ffffff" },
      });
    }));
    setCodes((current) => ({ ...current, ...next }));
  }, []);

  useEffect(() => {
    const missing = chosen.filter((label) => !codes[label.id]);
    if (missing.length === 0) return;
    const frame = requestAnimationFrame(() => void generateCodes(missing));
    return () => cancelAnimationFrame(frame);
  }, [chosen, codes, generateCodes]);

  function toggle(id: string) {
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function switchMode(value: "spaces" | "items") {
    setMode(value);
    setSelected(new Set());
    setCodes({});
    setQuery("");
  }

  return (
    <section className="product-page label-studio-page">
      <header className="product-page-header">
        <div>
          <h1>Print QR labels</h1>
          <p>Put a scannable label on a Space or item so it can be found quickly.</p>
        </div>
        <div className="product-actions">
          <button
            className="product-button"
            disabled={selected.size === 0}
            onClick={() => setSelected(new Set())}
          >
            Clear selection
          </button>
          <button
            className="product-button primary"
            disabled={chosen.length === 0}
            onClick={() => window.print()}
          >
            <Printer size={14} /> Print{chosen.length > 0 ? ` ${chosen.length}` : ""}
          </button>
        </div>
      </header>

      {error && <div className="product-notice error">{error}</div>}

      <div className="label-guide product-card" aria-label="How label printing works">
        <div><span>1</span><div><strong>Choose a label type</strong><small>Space labels identify a shelf or room. Item labels identify one inventory record.</small></div></div>
        <div><span>2</span><div><strong>Select what to print</strong><small>Click one or several records below. A print preview appears automatically.</small></div></div>
        <div><span>3</span><div><strong>Print and attach</strong><small>Click Print, cut out the labels, and attach them where they belong.</small></div></div>
      </div>

      <div className="label-toolbar product-card">
        <div>
          <div className="product-tabs">
            <button className={mode === "spaces" ? "is-active" : ""} onClick={() => switchMode("spaces")}>
              Spaces
            </button>
            <button className={mode === "items" ? "is-active" : ""} onClick={() => switchMode("items")}>
              Individual items
            </button>
          </div>
          <small>{mode === "spaces" ? "For rooms, shelves, cabinets, and bins." : "For tracking one specific inventory item."}</small>
        </div>
        <input
          className="product-input"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={`Search ${mode}`}
          aria-label={`Search ${mode}`}
        />
      </div>

      <div className="label-selection-heading">
        <div><MousePointerClick size={16} /><strong>Select {mode === "spaces" ? "Spaces" : "items"}</strong><span>{selected.size} selected</span></div>
        <button className="product-button" onClick={() => setSelected(new Set(filtered.map((label) => label.id)))} disabled={filtered.length === 0}><CheckSquare size={14} />Select all shown</button>
      </div>
      <div className="label-picker">
        {filtered.map((label) => (
          <button
            className={selected.has(label.id) ? "is-selected" : ""}
            key={label.id}
            onClick={() => toggle(label.id)}
          >
            {selected.has(label.id) ? <CheckSquare size={17} /> : <Square size={17} />}
            <span>
              <strong>{label.title}</strong>
              <small>{label.subtitle}</small>
            </span>
          </button>
        ))}
        {filtered.length === 0 && <div className="product-card product-empty"><div><strong>No {mode} found</strong><span>{query ? "Try a different search." : `Create ${mode === "spaces" ? "a Space" : "an item"} in Inventory first.`}</span></div></div>}
      </div>

      <div className="label-preview-heading"><strong>Print preview</strong><span>{chosen.length === 0 ? "Selected labels will appear here." : `${chosen.length} label${chosen.length === 1 ? "" : "s"} ready to print.`}</span></div>
      <div className="print-label-sheet">
        {chosen.length === 0 ? (
          <div className="product-card product-empty">
            <div>
              <QrCode size={28} />
              <strong>Nothing selected yet</strong>
              <span>Choose a Space or item above to generate its QR label.</span>
            </div>
          </div>
        ) : chosen.map((label) => (
          <article className="print-label" key={label.id}>
            {codes[label.id]
              ? <img src={codes[label.id]} alt={`QR code for ${label.title}`} />
              : <span className="qr-placeholder" />}
            <div>
              <h2>{label.title}</h2>
              <p>{label.subtitle}</p>
              <ul>{label.details.map((detail) => <li key={detail}>{detail}</li>)}</ul>
              <footer><strong>FindEZ AI</strong><span>Scan to open</span></footer>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
