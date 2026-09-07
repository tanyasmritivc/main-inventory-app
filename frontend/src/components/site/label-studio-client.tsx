/* eslint-disable @next/next/no-img-element */
"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CheckSquare, Printer, QrCode, Square } from "lucide-react";
import QRCode from "qrcode";
import { InventoryItem, Space, getSpaces, searchItems } from "@/lib/api";
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
      title: item.name,
      subtitle: [item.brand, item.part_number].filter(Boolean).join(" · ") || item.category,
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
          <h1>Label studio</h1>
          <p>Batch-generate QR labels for Spaces, shelves, and individual parts.</p>
        </div>
        <div className="product-actions">
          <button
            className="product-button"
            onClick={() => setSelected(new Set(filtered.map((label) => label.id)))}
          >
            <CheckSquare size={14} /> Select all
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

      <div className="label-toolbar product-card">
        <div className="product-tabs">
          <button className={mode === "spaces" ? "is-active" : ""} onClick={() => switchMode("spaces")}>
            Space labels
          </button>
          <button className={mode === "items" ? "is-active" : ""} onClick={() => switchMode("items")}>
            Item labels
          </button>
        </div>
        <input
          className="product-input"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={`Search ${mode}`}
          aria-label={`Search ${mode}`}
        />
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
      </div>

      <div className="print-label-sheet">
        {chosen.length === 0 ? (
          <div className="product-card product-empty">
            <div>
              <QrCode size={28} />
              <strong>Select labels to preview</strong>
              <span>Choose one or many records above, then print on paper or label stock.</span>
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
