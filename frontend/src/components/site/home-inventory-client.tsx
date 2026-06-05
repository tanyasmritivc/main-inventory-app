"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { MoreHorizontal, Share2, UploadCloud } from "lucide-react";
import type { InventoryItem } from "@/lib/api";
import { addItem, deleteItem, extractFromImage, processBarcode, searchItems, updateItem } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogClose, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { SpreadsheetImportModal } from "@/components/site/spreadsheet-import-modal";
import { ShareSpaceModal } from "@/components/site/share-space-modal";
import { BarcodeScanner } from "@/components/site/zxing-scanner";

export function HomeInventoryClient(props: { locationFilter?: string }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const [token, setToken] = useState<string | null>(null);
  const [allItems, setAllItems] = useState<InventoryItem[]>([]);
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [query, setQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [selectedSpace, setSelectedSpace] = useState<string | null>(null);
  const [localSpaces, setLocalSpaces] = useState<string[]>([]);
  const [createSpaceOpen, setCreateSpaceOpen] = useState(false);
  const [newSpaceName, setNewSpaceName] = useState("");
  const [spreadsheetSpace, setSpreadsheetSpace] = useState<string | null>(null);
  const [spreadsheetOpen, setSpreadsheetOpen] = useState(false);
  const [shareSpace, setShareSpace] = useState<string | null>(null);
  const [shareOpen, setShareOpen] = useState(false);
  const [scanOpen, setScanOpen] = useState(false);

  const [draft, setDraft] = useState<InventoryItem>({
    item_id: "",
    name: "",
    category: "",
    quantity: 1,
    location: "",
    image_url: null,
    barcode: null,
    purchase_source: null,
    notes: null,
    created_at: "",
  });
  const [createOpen, setCreateOpen] = useState(false);
  const [extractingImage, setExtractingImage] = useState(false);
  const [imageProgressStep, setImageProgressStep] = useState(0);
  const [barcodeProgressStep, setBarcodeProgressStep] = useState(0);
  const [editOpen, setEditOpen] = useState(false);
  const [editItemId, setEditItemId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState<InventoryItem>({
    item_id: "",
    name: "",
    category: "",
    quantity: 1,
    location: "",
    image_url: null,
    barcode: null,
    purchase_source: null,
    notes: null,
    created_at: "",
  });

  function normalizeLocation(value?: string | null) {
    const location = (value ?? "").trim();
    if (!location || location.toLowerCase() === "unsorted") return "Unsorted";
    return location;
  }

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return fallback;
  }

  async function refreshToken() {
    const { data, error: sessionErr } = await supabase.auth.getSession();
    if (sessionErr) throw sessionErr;
    const accessToken = data.session?.access_token;
    if (!accessToken) throw new Error("Missing session");
    setToken(accessToken);
    return accessToken;
  }

  async function onUpdateItem(itemId: string, updates: Partial<Omit<InventoryItem, "item_id" | "created_at">>) {
    setError(null);
    setLoading(true);
    try {
      const t = token || (await refreshToken());
      const res = await updateItem({ token: t, item_id: itemId, updates });
      setAllItems((prev) => prev.map((item) => (item.item_id === itemId ? res.item : item)));
      setItems((prev) => prev.map((item) => (item.item_id === itemId ? res.item : item)));
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to update item"));
    } finally {
      setLoading(false);
    }
  }

  async function onDelete(itemId: string) {
    setError(null);
    setLoading(true);
    try {
      const t = token || (await refreshToken());
      await deleteItem({ token: t, item_id: itemId });
      setAllItems((prev) => prev.filter((i) => i.item_id !== itemId));
      setItems((prev) => prev.filter((i) => i.item_id !== itemId));
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to delete item"));
    } finally {
      setLoading(false);
    }
  }

  function openEdit(it: InventoryItem) {
    setEditItemId(it.item_id);
    setEditDraft({ ...it });
    setEditOpen(true);
  }

  async function onSaveEdit(e: React.FormEvent) {
    e.preventDefault();
    if (!editItemId) return;
    await onUpdateItem(editItemId, {
      name: editDraft.name,
      category: editDraft.category,
      quantity: editDraft.quantity,
      location: editDraft.location,
      barcode: editDraft.barcode ?? null,
      purchase_source: editDraft.purchase_source ?? null,
      notes: editDraft.notes ?? null,
    });
    setEditOpen(false);
  }

  async function load(currentToken?: string, queryOverride?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      const q = (queryOverride ?? query).trim();
      const res = await searchItems({ token: t, query: q });
      setItems(res.items);
      if (!q) setAllItems(res.items);
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to load inventory"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refreshToken()
      .then((t) => load(t, ""))
      .catch(() => {
        setError("Authentication error. Please sign in again.");
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!query.trim()) return;
    const timeout = window.setTimeout(() => {
      void load(undefined, query);
    }, 400);
    return () => window.clearTimeout(timeout);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  useEffect(() => {
    if (!props.locationFilter?.trim()) return;
    setSelectedSpace(normalizeLocation(props.locationFilter));
  }, [props.locationFilter]);

  const spaces = useMemo(() =>
    Array.from(new Set(
      allItems.map(i => (i.location?.trim() || 'Unsorted'))
    )).sort(),
  [allItems]);

  const itemsBySpace = useMemo(() => {
    return allItems.reduce<Record<string, InventoryItem[]>>((acc, item) => {
      const spaceName = normalizeLocation(item.location);
      if (!acc[spaceName]) acc[spaceName] = [];
      acc[spaceName].push(item);
      return acc;
    }, {});
  }, [allItems]);

  const visibleItems = useMemo(() => {
    const base = selectedSpace
      ? items.filter((item) => normalizeLocation(item.location) === selectedSpace)
      : items;
    if (!categoryFilter) return base;
    return base.filter((item) => (item.category ?? "").toLowerCase() === categoryFilter.toLowerCase());
  }, [items, selectedSpace, categoryFilter]);

  const searchActive = query.trim().length > 0 && !selectedSpace;

  function openSpace(spaceName: string) {
    setSelectedSpace(spaceName);
    setCategoryFilter("");
    setQuery("");
  }

  function clearFilters() {
    setQuery("");
    setCategoryFilter("");
    setItems(allItems);
  }

  function onCreateSpace() {
    const normalized = normalizeLocation(newSpaceName);
    if (!normalized) return;
    setLocalSpaces((prev) => (prev.includes(normalized) ? prev : [...prev, normalized]));
    setSelectedSpace(normalized);
    setNewSpaceName("");
    setCreateSpaceOpen(false);
  }

  function onRenameSpace(spaceName: string) {
    const name = window.prompt("Rename space", spaceName)?.trim();
    if (!name) return;
    const normalized = normalizeLocation(name);
    if (normalized === spaceName) return;
    setLocalSpaces((prev) => prev.map((space) => (space === spaceName ? normalized : space)));
    setSelectedSpace((current) => (current === spaceName ? normalized : current));
    setAllItems((prev) =>
      prev.map((item) =>
        normalizeLocation(item.location) === spaceName ? { ...item, location: normalized } : item
      )
    );
    setItems((prev) =>
      prev.map((item) =>
        normalizeLocation(item.location) === spaceName ? { ...item, location: normalized } : item
      )
    );
  }

  function onDeleteSpace(spaceName: string) {
    if (!window.confirm(`Delete the space "${spaceName}"?`)) return;
    setLocalSpaces((prev) => prev.filter((space) => space !== spaceName));
    if (selectedSpace === spaceName) {
      setSelectedSpace(null);
      setCategoryFilter("");
      setQuery("");
    }
  }

  function openSpreadsheet(spaceName: string) {
    setSpreadsheetSpace(spaceName);
    setSpreadsheetOpen(true);
  }

  function openShare(spaceName: string) {
    setShareSpace(spaceName);
    setShareOpen(true);
  }

  async function onExtractImage(file: File) {
    if (extractingImage) return;
    setError(null);
    setExtractingImage(true);
    setImageProgressStep(0);
    const step1 = window.setTimeout(() => setImageProgressStep(1), 700);
    const step2 = window.setTimeout(() => setImageProgressStep(2), 2500);
    try {
      const t = token || (await refreshToken());
      const res = await extractFromImage({ token: t, file });
      const extracted = res.extracted as Record<string, unknown>;
      setDraft((d) => ({
        ...d,
        name: (extracted.name as string) ?? d.name,
        category: (extracted.category as string) ?? d.category,
        quantity: typeof extracted.quantity === "number" ? extracted.quantity : d.quantity,
        location: (extracted.location as string) ?? d.location,
        barcode: (extracted.barcode as string) ?? d.barcode,
        purchase_source: (extracted.purchase_source as string) ?? d.purchase_source,
        notes: (extracted.notes as string) ?? d.notes,
        image_url: res.image_url,
      }));
      setCreateOpen(true);
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to extract from image"));
    } finally {
      window.clearTimeout(step1);
      window.clearTimeout(step2);
      setExtractingImage(false);
    }
  }

  async function onBarcode(barcode: string) {
    setError(null);
    setBarcodeProgressStep(0);
    const step1 = window.setTimeout(() => setBarcodeProgressStep(1), 700);
    const step2 = window.setTimeout(() => setBarcodeProgressStep(2), 2500);
    setDraft((d) => ({ ...d, barcode }));
    try {
      const t = token || (await refreshToken());
      const res = await processBarcode({ token: t, barcode });
      const guess = res.result as Record<string, unknown>;
      setDraft((d) => ({
        ...d,
        name: d.name || ((guess.name as string) ?? ""),
        category: d.category || ((guess.category as string) ?? ""),
        notes: d.notes || ((guess.notes as string) ?? null),
      }));
      setCreateOpen(true);
    } catch {
      // Non-fatal
    } finally {
      window.clearTimeout(step1);
      window.clearTimeout(step2);
    }
  }

  const uploadImageRef = useRef<HTMLInputElement>(null);

  async function onExtractMultiImage(file: File) {
    if (!token) return;
    setLoading(true);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_BASE_URL}/inventory/extract_from_image`,
        { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: formData }
      );
      const data = await res.json() as { items?: Record<string, unknown>[]; extracted?: Record<string, unknown> };
      const extracted: Record<string, unknown>[] = data.items ?? ([data.extracted].filter(Boolean) as Record<string, unknown>[]);
      if (extracted.length > 0) {
        await fetch(
          `${process.env.NEXT_PUBLIC_API_BASE_URL}/inventory/bulk_create`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
            body: JSON.stringify({
              items: extracted.map((it) => ({ ...it, location: selectedSpace ?? "Unsorted" })),
            }),
          }
        );
        await load(token, "");
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }

  const categories: string[] = useMemo(() => {
    const spaceItems = selectedSpace
      ? allItems.filter((i) => normalizeLocation(i.location) === selectedSpace)
      : allItems;
    return Array.from(new Set(spaceItems.map((i) => i.category).filter(Boolean))).sort((a, b) => a.localeCompare(b));
  }, [allItems, selectedSpace]);

  const actionBtnStyle: React.CSSProperties = {
    background: "transparent",
    border: "1px solid #1c1c1e",
    borderRadius: 8,
    padding: "7px 14px",
    fontSize: 12,
    fontWeight: 500,
    color: "#a1a1a6",
    letterSpacing: "-0.012em",
    cursor: "pointer",
  };

  const thStyle: React.CSSProperties = {
    fontSize: 10,
    fontWeight: 500,
    color: "#6e6e73",
    textTransform: "uppercase",
    letterSpacing: "0.07em",
    textAlign: "left",
    padding: "0 0 10px",
  };

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "#fff", margin: 0, letterSpacing: "-0.035em" }}>My Inventory</h1>
        <button
          type="button"
          onClick={() => setCreateSpaceOpen(true)}
          style={{ background: "transparent", border: "1px solid #1c1c1e", borderRadius: 6, padding: "6px 14px", fontSize: 12, fontWeight: 510, color: "#a1a1a6", cursor: "pointer" }}
        >
          + New Space
        </button>
      </div>
      <input
        placeholder="Search across all spaces..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        style={{ width: "100%", boxSizing: "border-box", background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 8, outline: "none", fontSize: 13, color: "#f5f5f7", padding: "9px 14px", marginBottom: 20 }}
      />
      {error ? <p style={{ fontSize: 13, color: "#ff453a", marginBottom: 12 }}>{error}</p> : null}

      {searchActive ? (
        <div>
          <p style={{ fontSize: 13, color: "#6e6e73", marginBottom: 16 }}>Showing {visibleItems.length} matching items</p>
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse" }}>
              <thead>
                <tr style={{ borderBottom: "1px solid #1c1c1e" }}>
                  {["Name","Category","Qty","Location"].map((h) => (
                    <th key={h} style={thStyle}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {visibleItems.map((item) => (
                  <tr key={item.item_id} style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
                    <td style={{ fontSize: 13, color: "#f5f5f7", fontWeight: 510, padding: "12px 0", letterSpacing: "-0.015em" }}>{item.name}</td>
                    <td style={{ padding: "12px 12px 12px 0" }}><span style={{ fontSize: 11, padding: "2px 8px", background: "#1c1c1e", borderRadius: 99, color: "#a1a1a6" }}>{item.category}</span></td>
                    <td style={{ fontSize: 13, color: "#fff", fontWeight: 590, padding: "12px 12px 12px 0" }}>{item.quantity}</td>
                    <td style={{ fontSize: 12, color: "#6e6e73", padding: "12px 12px 12px 0" }}>{normalizeLocation(item.location)}</td>
                  </tr>
                ))}
                {visibleItems.length === 0 ? (
                  <tr>
                    <td colSpan={4} style={{ fontSize: 13, color: "#3a3a3c", textAlign: "center", padding: "40px 0" }}>No matching items found.</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      ) : selectedSpace ? (
        <div>
          <button
            type="button"
            onClick={() => setSelectedSpace(null)}
            style={{ fontSize: 13, color: "#6e6e73", background: "transparent", border: "none", cursor: "pointer", letterSpacing: "-0.01em", marginBottom: 16, padding: 0 }}
          >
            ← My Inventory
          </button>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: "#fff", margin: 0, letterSpacing: "-0.03em" }}>{selectedSpace}</h2>
          <p style={{ fontSize: 12, color: "#6e6e73", marginTop: 4, marginBottom: 0 }}>{(itemsBySpace[selectedSpace] ?? []).length} items</p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 20, marginBottom: 24 }}>
            <button type="button" onClick={() => uploadImageRef.current?.click()} style={actionBtnStyle}>Upload Image → Auto-fill</button>
            <button type="button" onClick={() => selectedSpace && openSpreadsheet(selectedSpace)} style={actionBtnStyle}>Import Spreadsheet</button>
            <button type="button" onClick={() => setScanOpen(true)} style={actionBtnStyle}>Scan Barcode</button>
            <button type="button" onClick={() => setCreateOpen(true)} style={actionBtnStyle}>+ Add Item</button>
            <button type="button" onClick={() => setShareOpen(true)} style={actionBtnStyle}>Share Space</button>
          </div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 10, marginBottom: 16 }}>
            <input
              placeholder="Search items..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              style={{ flex: 1, minWidth: 200, background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 8, padding: "9px 14px", color: "#f5f5f7", fontSize: 13, outline: "none" }}
            />
          </div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 18 }}>
            <button
              type="button"
              onClick={() => setCategoryFilter("")}
              style={{ background: categoryFilter === "" ? "#1c1c1e" : "#0a0a0a", color: categoryFilter === "" ? "#fff" : "#6e6e73", border: categoryFilter === "" ? "1px solid #2c2c2e" : "1px solid #1c1c1e", borderRadius: 99, padding: "4px 12px", fontSize: 11, cursor: "pointer" }}
            >All</button>
            {categories.map((category) => (
              <button
                key={category}
                type="button"
                onClick={() => setCategoryFilter(category)}
                style={{
                  background: categoryFilter === category ? "#1c1c1e" : "#0a0a0a",
                  color: categoryFilter === category ? "#fff" : "#6e6e73",
                  border: categoryFilter === category ? "1px solid #2c2c2e" : "1px solid #1c1c1e",
                  borderRadius: 99,
                  padding: "4px 12px",
                  fontSize: 11,
                  cursor: "pointer",
                }}
              >
                {category}
              </button>
            ))}
          </div>
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse" }}>
              <thead>
                <tr style={{ borderBottom: "1px solid #1c1c1e" }}>
                  <th style={thStyle}>Name</th>
                  <th style={thStyle}>Category</th>
                  <th style={thStyle}>Qty</th>
                  <th style={thStyle}>Location</th>
                  <th style={{ ...thStyle, textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleItems.map((it) => (
                  <tr key={it.item_id} style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }} className="hover:bg-white/[0.015] transition-colors">
                    <td style={{ fontSize: 13, color: "#f5f5f7", fontWeight: 510, padding: "12px 0", letterSpacing: "-0.015em" }}>{it.name}</td>
                    <td style={{ padding: "12px 12px 12px 0" }}><span style={{ fontSize: 11, padding: "2px 8px", background: "#1c1c1e", borderRadius: 99, color: "#a1a1a6" }}>{it.category}</span></td>
                    <td style={{ fontSize: 13, color: "#fff", fontWeight: 590, padding: "12px 12px 12px 0" }}>{it.quantity}</td>
                    <td style={{ fontSize: 12, color: "#6e6e73", padding: "12px 12px 12px 0" }}>{normalizeLocation(it.location)}</td>
                    <td style={{ padding: "12px 0", textAlign: "right" }}>
                      <div style={{ display: "flex", justifyContent: "flex-end", gap: 4 }}>
                        <button type="button" onClick={() => openEdit(it)} disabled={loading} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px" }}>Edit</button>
                        <button type="button" onClick={() => onUpdateItem(it.item_id, { quantity: it.quantity + 1 })} disabled={loading} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px" }}>+1</button>
                        <button type="button" onClick={() => onUpdateItem(it.item_id, { quantity: Math.max(0, it.quantity - 1) })} disabled={loading || it.quantity === 0} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px", opacity: it.quantity === 0 ? 0.3 : 1 }}>-1</button>
                        <button type="button" onClick={() => onUpdateItem(it.item_id, { quantity: 0 })} disabled={loading || it.quantity === 0} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px", opacity: it.quantity === 0 ? 0.3 : 1 }}>Out of Stock</button>
                        <button type="button" onClick={() => void onDelete(it.item_id)} disabled={loading} style={{ fontSize: 11, color: "#ff453a", background: "none", border: "none", cursor: "pointer", padding: "0 4px" }}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
                {visibleItems.length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ textAlign: "center", padding: "48px 0" }}>
                      <p style={{ fontSize: 13, color: "#3a3a3c", marginBottom: 20 }}>This space is empty. Add your first item or import a spreadsheet to get started.</p>
                      <div style={{ display: "flex", justifyContent: "center", gap: 8 }}>
                        <button type="button" style={actionBtnStyle} onClick={() => setCreateOpen(true)}>+ Add Item</button>
                        <button type="button" style={actionBtnStyle} onClick={() => selectedSpace && openSpreadsheet(selectedSpace)}>Import Spreadsheet</button>
                      </div>
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
          <input
            ref={uploadImageRef}
            type="file"
            accept="image/*"
            style={{ display: "none" }}
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void onExtractMultiImage(f);
            }}
          />
          <ShareSpaceModal
            open={shareOpen}
            onOpenChange={setShareOpen}
            spaceName={selectedSpace ?? ""}
            token={token ?? ""}
          />
        </div>
      ) : (
        <>
          {loading ? (
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 12, marginTop: 20 }}>
              {[1,2,3,4].map(i => <div key={i} className="skeleton" style={{ height: 110, borderRadius: 12 }} />)}
            </div>
          ) : (
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 12 }}>
              {spaces.map((space) => {
                const itemsInSpace = itemsBySpace[space] ?? [];
                const lowStock = itemsInSpace.filter((item) => item.quantity <= 1).length;
                return (
                  <div
                    key={space}
                    style={{ background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 12, padding: "18px 20px", cursor: "pointer", transition: "all 0.16s" }}
                    onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.borderColor = "#2c2c2e"; (e.currentTarget as HTMLElement).style.transform = "translateY(-1px)"; }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.borderColor = "#1c1c1e"; (e.currentTarget as HTMLElement).style.transform = "translateY(0)"; }}
                    onClick={() => openSpace(space)}
                  >
                    <p style={{ fontSize: 14, fontWeight: 590, color: "#fff", margin: 0, letterSpacing: "-0.02em" }}>{space}</p>
                    <p style={{ fontSize: 12, color: "#6e6e73", marginTop: 4, fontWeight: 400, letterSpacing: "-0.01em" }}>{itemsInSpace.length} items</p>
                    {lowStock > 0 ? (
                      <span style={{ fontSize: 10, padding: "2px 8px", borderRadius: 99, background: "rgba(255,214,10,0.10)", color: "#ffd60a", border: "1px solid rgba(255,214,10,0.20)", marginTop: 8, display: "inline-block" }}>
                        {lowStock} low stock
                      </span>
                    ) : null}
                    <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 12 }}>
                      <button
                        type="button"
                        onClick={(e) => { e.stopPropagation(); openSpreadsheet(space); }}
                        style={{ width: 24, height: 24, borderRadius: "50%", background: "transparent", border: "none", color: "#3a3a3c", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", transition: "color 120ms" }}
                        onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "#a1a1a6"; }}
                        onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "#3a3a3c"; }}
                      >
                        <UploadCloud size={14} />
                      </button>
                      <button
                        type="button"
                        onClick={(e) => { e.stopPropagation(); openShare(space); }}
                        style={{ width: 24, height: 24, borderRadius: "50%", background: "transparent", border: "none", color: "#3a3a3c", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", transition: "color 120ms" }}
                        onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "#a1a1a6"; }}
                        onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "#3a3a3c"; }}
                      >
                        <Share2 size={14} />
                      </button>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <button
                            type="button"
                            onClick={(e) => e.stopPropagation()}
                            style={{ width: 24, height: 24, borderRadius: "50%", background: "transparent", border: "none", color: "#3a3a3c", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", transition: "color 120ms" }}
                            onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "#a1a1a6"; }}
                            onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "#3a3a3c"; }}
                          >
                            <MoreHorizontal size={14} />
                          </button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent>
                          <DropdownMenuItem onSelect={() => onRenameSpace(space)}>Rename</DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem onSelect={() => onDeleteSpace(space)}>Delete</DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </div>
                );
              })}
              <div
                style={{ background: "transparent", border: "1px dashed #2c2c2e", borderRadius: 12, minHeight: 110, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4, cursor: "pointer", transition: "border-color 0.16s" }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.borderColor = "#3a3a3c"; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.borderColor = "#2c2c2e"; }}
                onClick={() => setCreateSpaceOpen(true)}
              >
                <div style={{ fontSize: 18, color: "#3a3a3c" }}>+</div>
                <div style={{ fontSize: 12, color: "#3a3a3c" }}>New Space</div>
              </div>
            </div>
          )}
        </>
      )}

      <Dialog open={createSpaceOpen} onOpenChange={setCreateSpaceOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Create Space</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <Label htmlFor="space-name">Space name</Label>
            <Input
              id="space-name"
              value={newSpaceName}
              onChange={(e) => setNewSpaceName(e.target.value)}
              placeholder="e.g. Kitchen, Garage, Robot Parts"
            />
            <div className="flex justify-end gap-2">
              <DialogClose asChild>
                <Button variant="outline">Cancel</Button>
              </DialogClose>
              <Button onClick={onCreateSpace}>Create</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      <Dialog open={spreadsheetOpen} onOpenChange={(open) => {
        setSpreadsheetOpen(open);
        if (!open) setSpreadsheetSpace(null);
      }}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Import Spreadsheet</DialogTitle>
          </DialogHeader>
          {spreadsheetSpace ? (
            <SpreadsheetImportModal
              spaceName={spreadsheetSpace}
              token={token || ""}
              onSuccess={() => void load(token || undefined, query)}
            />
          ) : null}
        </DialogContent>
      </Dialog>

      <Dialog open={scanOpen} onOpenChange={setScanOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader>
            <DialogTitle>Scan a barcode</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <p className="text-sm text-muted-foreground">Reading barcode…</p>
            <p className="text-xs text-muted-foreground">This usually takes 10–20 seconds depending on lighting.</p>
            <div className="text-xs text-muted-foreground">
              <div>{barcodeProgressStep >= 0 ? "✓ Camera ready" : "Camera ready"}</div>
              <div>{barcodeProgressStep >= 1 ? "✓ Scanning" : "Scanning"}</div>
              <div>{barcodeProgressStep >= 2 ? "✓ Looking up details" : "Looking up details"}</div>
            </div>
          </div>
          <BarcodeScanner
            onDetected={(code: string) => {
              void onBarcode(code);
              setScanOpen(false);
              setCreateOpen(true);
            }}
          />
        </DialogContent>
      </Dialog>

      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Edit item</DialogTitle>
          </DialogHeader>
          <form className="grid gap-4" onSubmit={onSaveEdit}>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="grid gap-2">
                <Label htmlFor="inv-edit-name">Name</Label>
                <Input id="inv-edit-name" value={editDraft.name} onChange={(e) => setEditDraft((d) => ({ ...d, name: e.target.value }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-edit-category">Category</Label>
                <Input id="inv-edit-category" value={editDraft.category} onChange={(e) => setEditDraft((d) => ({ ...d, category: e.target.value }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-edit-qty">Quantity</Label>
                <Input id="inv-edit-qty" type="number" min={0} value={editDraft.quantity} onChange={(e) => setEditDraft((d) => ({ ...d, quantity: Number.parseInt(e.target.value || "0", 10) }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-edit-location">Location</Label>
                <Input id="inv-edit-location" value={editDraft.location} onChange={(e) => setEditDraft((d) => ({ ...d, location: e.target.value }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-edit-barcode">Barcode</Label>
                <Input id="inv-edit-barcode" value={editDraft.barcode ?? ""} onChange={(e) => setEditDraft((d) => ({ ...d, barcode: e.target.value }))} />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-edit-source">Purchase source</Label>
                <Input id="inv-edit-source" value={editDraft.purchase_source ?? ""} onChange={(e) => setEditDraft((d) => ({ ...d, purchase_source: e.target.value }))} />
              </div>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="inv-edit-notes">Notes</Label>
              <Textarea id="inv-edit-notes" value={editDraft.notes ?? ""} onChange={(e) => setEditDraft((d) => ({ ...d, notes: e.target.value }))} />
            </div>
            <div className="flex items-center justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setEditOpen(false)}>Cancel</Button>
              <Button type="submit" disabled={loading}>Save</Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Add item</DialogTitle>
          </DialogHeader>
          <form className="grid gap-4" onSubmit={async (e) => {
            e.preventDefault();
            setError(null);
            setLoading(true);
            try {
              const t = token || (await refreshToken());
              if (!draft.name || !draft.category || !draft.location) throw new Error("Name, category, and location are required");
              const res = await addItem({ token: t, item: { name: draft.name, category: draft.category, quantity: draft.quantity, location: draft.location, image_url: draft.image_url ?? null, barcode: draft.barcode ?? null, purchase_source: draft.purchase_source ?? null, notes: draft.notes ?? null } });
              setAllItems((prev) => [res.item, ...prev]);
              setItems((prev) => [res.item, ...prev]);
              setDraft({ item_id: "", name: "", category: "", quantity: 1, location: selectedSpace || "", image_url: null, barcode: null, purchase_source: null, notes: null, created_at: "" });
              setCreateOpen(false);
            } catch (err: unknown) {
              setError(errorMessage(err, "Failed to add item"));
            } finally {
              setLoading(false);
            }
          }}>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="grid gap-2">
                <Label htmlFor="inv-name">Name</Label>
                <Input id="inv-name" value={draft.name} onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-category">Category</Label>
                <Input id="inv-category" value={draft.category} onChange={(e) => setDraft((d) => ({ ...d, category: e.target.value }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-qty">Quantity</Label>
                <Input id="inv-qty" type="number" min={0} value={draft.quantity} onChange={(e) => setDraft((d) => ({ ...d, quantity: Number.parseInt(e.target.value || "0", 10) }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-location">Location</Label>
                <Input id="inv-location" value={draft.location} onChange={(e) => setDraft((d) => ({ ...d, location: e.target.value }))} required />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-barcode">Barcode</Label>
                <Input id="inv-barcode" value={draft.barcode ?? ""} onChange={(e) => setDraft((d) => ({ ...d, barcode: e.target.value }))} />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="inv-source">Purchase source</Label>
                <Input id="inv-source" value={draft.purchase_source ?? ""} onChange={(e) => setDraft((d) => ({ ...d, purchase_source: e.target.value }))} />
              </div>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="inv-notes">Notes</Label>
              <Textarea id="inv-notes" value={draft.notes ?? ""} onChange={(e) => setDraft((d) => ({ ...d, notes: e.target.value }))} />
            </div>
            {extractingImage ? (
              <div className="space-y-1">
                <p className="text-sm text-muted-foreground">Analyzing image…</p>
                <div className="text-xs text-muted-foreground">
                  <div>{imageProgressStep >= 0 ? "✓ Image uploaded" : "Image uploaded"}</div>
                  <div>{imageProgressStep >= 1 ? "✓ Detecting items" : "Detecting items"}</div>
                  <div>{imageProgressStep >= 2 ? "✓ Extracting details" : "Extracting details"}</div>
                </div>
              </div>
            ) : null}
            <div className="flex items-center justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setCreateOpen(false)}>Cancel</Button>
              <Button type="submit" disabled={loading}>Save Item</Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
