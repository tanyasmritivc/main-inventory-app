"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeft, MoreHorizontal, Share2, UploadCloud, Plus } from "lucide-react";
import type { InventoryItem } from "@/lib/api";
import { addItem, deleteItem, extractFromImage, extractFromImageMulti, processBarcode, searchItems, updateItem } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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

  const spaces = useMemo(() => {
    const spaceSet = new Set(localSpaces.map(normalizeLocation));
    allItems.forEach((item) => {
      spaceSet.add(normalizeLocation(item.location));
    });
    return Array.from(spaceSet).sort((a, b) => a.localeCompare(b));
  }, [allItems, localSpaces]);

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

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 600, color: "white", fontFamily: "var(--font-syne)", margin: 0, letterSpacing: "-0.01em" }}>My Inventory</h1>
        <button
          type="button"
          onClick={() => setCreateSpaceOpen(true)}
          style={{ fontSize: 13, color: "white", background: "transparent", border: "1px solid rgba(255,255,255,0.15)", borderRadius: 99, padding: "6px 16px", cursor: "pointer" }}
        >
          + New Space
        </button>
      </div>
      <input
        placeholder="Search across all spaces..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        style={{ width: "100%", boxSizing: "border-box", background: "transparent", border: "none", borderBottom: "1px solid rgba(255,255,255,0.10)", outline: "none", fontSize: 14, color: "white", padding: "8px 0", marginBottom: 32 }}
      />
      {error ? <p style={{ fontSize: 13, color: "#f87171", marginBottom: 12 }}>{error}</p> : null}

      {searchActive ? (
        <div>
          <p style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", marginBottom: 16 }}>Showing {visibleItems.length} matching items</p>
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse" }}>
              <thead>
                <tr style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
                  {["Name","Category","Qty","Location"].map((h) => (
                    <th key={h} style={{ fontSize: 10, fontWeight: 500, color: "rgba(255,255,255,0.3)", textTransform: "uppercase", letterSpacing: "0.1em", textAlign: "left", padding: "0 0 12px" }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {visibleItems.map((item) => (
                  <tr key={item.item_id} style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
                    <td style={{ fontSize: 14, color: "white", fontWeight: 500, padding: "14px 0" }}>{item.name}</td>
                    <td style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", padding: "14px 12px 14px 0" }}>{item.category}</td>
                    <td style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", padding: "14px 12px 14px 0" }}>{item.quantity}</td>
                    <td style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", padding: "14px 12px 14px 0" }}>{normalizeLocation(item.location)}</td>
                  </tr>
                ))}
                {visibleItems.length === 0 ? (
                  <tr>
                    <td colSpan={4} style={{ fontSize: 13, color: "rgba(255,255,255,0.3)", textAlign: "center", padding: "40px 0" }}>No matching items found.</td>
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
            style={{ fontSize: 13, color: "rgba(255,255,255,0.5)", background: "none", border: "none", cursor: "pointer", padding: 0, marginBottom: 24 }}
          >
            ← My Inventory
          </button>
          <h2 style={{ fontSize: 28, fontWeight: 600, color: "white", fontFamily: "var(--font-syne)", margin: 0, letterSpacing: "-0.01em" }}>{selectedSpace}</h2>
          <p style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", marginTop: 4, marginBottom: 0 }}>{(itemsBySpace[selectedSpace] ?? []).length} items</p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 24, marginBottom: 32 }}>
            <Button variant="ghost" className="rounded-full border border-white/[0.10] bg-white/[0.04] px-[18px] py-2 text-[13px] text-white hover:bg-white/[0.08]" onClick={() => uploadImageRef.current?.click()}>Upload Image → Auto-fill</Button>
            <Button variant="ghost" className="rounded-full border border-white/[0.10] bg-white/[0.04] px-[18px] py-2 text-[13px] text-white hover:bg-white/[0.08]" onClick={() => selectedSpace && openSpreadsheet(selectedSpace)}>Import Spreadsheet</Button>
            <Button variant="ghost" className="rounded-full border border-white/[0.10] bg-white/[0.04] px-[18px] py-2 text-[13px] text-white hover:bg-white/[0.08]" onClick={() => setScanOpen(true)}>Scan Barcode</Button>
            <Button variant="ghost" className="rounded-full border border-white/[0.10] bg-white/[0.04] px-[18px] py-2 text-[13px] text-white hover:bg-white/[0.08]" onClick={() => setCreateOpen(true)}>+ Add Item</Button>
            <Button variant="ghost" className="rounded-full border border-white/[0.10] bg-white/[0.04] px-[18px] py-2 text-[13px] text-white hover:bg-white/[0.08]" onClick={() => setShareOpen(true)}>Share Space</Button>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
            <input
              placeholder="Search items..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              style={{ flex: 1, background: "transparent", border: "none", borderBottom: "1px solid rgba(255,255,255,0.12)", outline: "none", fontSize: 14, color: "white", padding: "6px 0" }}
            />
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              style={{ background: "transparent", border: "none", borderBottom: "1px solid rgba(255,255,255,0.12)", outline: "none", fontSize: 13, color: "rgba(255,255,255,0.6)", padding: "6px 0" }}
            >
              <option value="">All categories</option>
              {categories.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse" }}>
              <thead>
                <tr style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
                  <th style={{ fontSize: 10, fontWeight: 500, color: "rgba(255,255,255,0.3)", textTransform: "uppercase", letterSpacing: "0.1em", textAlign: "left", padding: "0 0 12px" }}>Name</th>
                  <th style={{ fontSize: 10, fontWeight: 500, color: "rgba(255,255,255,0.3)", textTransform: "uppercase", letterSpacing: "0.1em", textAlign: "left", padding: "0 0 12px" }}>Category</th>
                  <th style={{ fontSize: 10, fontWeight: 500, color: "rgba(255,255,255,0.3)", textTransform: "uppercase", letterSpacing: "0.1em", textAlign: "left", padding: "0 0 12px" }}>Qty</th>
                  <th style={{ fontSize: 10, fontWeight: 500, color: "rgba(255,255,255,0.3)", textTransform: "uppercase", letterSpacing: "0.1em", textAlign: "left", padding: "0 0 12px" }}>Location</th>
                  <th style={{ fontSize: 10, fontWeight: 500, color: "rgba(255,255,255,0.3)", textTransform: "uppercase", letterSpacing: "0.1em", textAlign: "right", padding: "0 0 12px" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleItems.map((it) => (
                  <tr key={it.item_id} style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }} className="hover:bg-white/[0.015] transition-colors">
                    <td style={{ fontSize: 14, color: "white", fontWeight: 500, padding: "14px 0" }}>{it.name}</td>
                    <td style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", padding: "14px 12px 14px 0" }}>{it.category}</td>
                    <td style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", padding: "14px 12px 14px 0" }}>{it.quantity}</td>
                    <td style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", padding: "14px 12px 14px 0" }}>{normalizeLocation(it.location)}</td>
                    <td style={{ padding: "14px 0", textAlign: "right" }}>
                      <div style={{ display: "flex", justifyContent: "flex-end", gap: 4 }}>
                        <button type="button" onClick={() => openEdit(it)} disabled={loading} style={{ fontSize: 12, color: "rgba(255,255,255,0.5)", background: "none", border: "none", cursor: "pointer", padding: "2px 6px" }}>Edit</button>
                        <button type="button" onClick={() => onUpdateItem(it.item_id, { quantity: it.quantity + 1 })} disabled={loading} style={{ fontSize: 12, color: "rgba(255,255,255,0.4)", background: "none", border: "none", cursor: "pointer", padding: "2px 6px" }}>+1</button>
                        <button type="button" onClick={() => onUpdateItem(it.item_id, { quantity: Math.max(0, it.quantity - 1) })} disabled={loading || it.quantity === 0} style={{ fontSize: 12, color: "rgba(255,255,255,0.4)", background: "none", border: "none", cursor: "pointer", padding: "2px 6px", opacity: it.quantity === 0 ? 0.3 : 1 }}>-1</button>
                        <button type="button" onClick={() => onUpdateItem(it.item_id, { quantity: 0 })} disabled={loading || it.quantity === 0} style={{ fontSize: 12, color: "rgba(251,191,36,0.6)", background: "none", border: "none", cursor: "pointer", padding: "2px 6px", opacity: it.quantity === 0 ? 0.3 : 1 }}>Out of Stock</button>
                        <button type="button" onClick={() => onDelete(it.item_id)} disabled={loading} style={{ fontSize: 12, color: "rgba(248,113,113,0.6)", background: "none", border: "none", cursor: "pointer", padding: "2px 6px" }}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
                {visibleItems.length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ textAlign: "center", padding: "48px 0" }}>
                      <p style={{ fontSize: 13, color: "rgba(255,255,255,0.3)", marginBottom: 20 }}>This space is empty. Add your first item or import a spreadsheet to get started.</p>
                      <div style={{ display: "flex", justifyContent: "center", gap: 8 }}>
                        <Button variant="ghost" className="rounded-full border border-white/[0.10] bg-white/[0.04] px-[18px] py-2 text-[13px] text-white hover:bg-white/[0.08]" onClick={() => setCreateOpen(true)}>+ Add Item</Button>
                        <Button variant="ghost" className="rounded-full border border-white/[0.10] bg-white/[0.04] px-[18px] py-2 text-[13px] text-white hover:bg-white/[0.08]" onClick={() => selectedSpace && openSpreadsheet(selectedSpace)}>Import Spreadsheet</Button>
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
        <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 16 }}>
          {spaces.map((space) => {
            const itemsInSpace = itemsBySpace[space] ?? [];
            const lowStock = itemsInSpace.filter((item) => item.quantity <= 1).length;
            return (
              <div
                key={space}
                style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 16, padding: "20px 24px", cursor: "pointer", transition: "all 180ms ease" }}
                className="hover:border-white/[0.15] hover:bg-white/[0.05]"
                onClick={() => openSpace(space)}
              >
                <p style={{ fontSize: 16, fontWeight: 600, color: "white", margin: 0 }}>{space}</p>
                <p style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", marginTop: 4 }}>{itemsInSpace.length} items</p>
                {lowStock > 0 ? <p style={{ fontSize: 12, color: "#fbbf24", marginTop: 4 }}>{lowStock} low stock</p> : null}
                <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 16 }}>
                  <button
                    type="button"
                    onClick={(e) => { e.stopPropagation(); openSpreadsheet(space); }}
                    style={{ width: 28, height: 28, borderRadius: "50%", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.5)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
                  >
                    <UploadCloud size={14} />
                  </button>
                  <button
                    type="button"
                    onClick={(e) => { e.stopPropagation(); openShare(space); }}
                    style={{ width: 28, height: 28, borderRadius: "50%", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.5)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
                  >
                    <Share2 size={14} />
                  </button>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <button
                        type="button"
                        onClick={(e) => e.stopPropagation()}
                        style={{ width: 28, height: 28, borderRadius: "50%", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.5)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
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
            style={{ display: "flex", alignItems: "center", justifyContent: "center", borderRadius: 16, border: "1px dashed rgba(255,255,255,0.12)", background: "transparent", padding: "20px 24px", textAlign: "center", cursor: "pointer", transition: "all 180ms ease", minHeight: 120 }}
            className="hover:border-white/[0.25]"
            onClick={() => setCreateSpaceOpen(true)}
          >
            <div>
              <div style={{ margin: "0 auto 8px", width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center", color: "rgba(255,255,255,0.3)" }}>
                <Plus size={20} />
              </div>
              <div style={{ fontSize: 13, color: "rgba(255,255,255,0.25)" }}>New Space</div>
            </div>
          </div>
        </div>
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
    </div>
  );
}
