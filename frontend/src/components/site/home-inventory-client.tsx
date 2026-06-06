"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { MoreHorizontal, Share2, UploadCloud } from "lucide-react";
import type { ExtractedInventoryItem, InventoryItem } from "@/lib/api";
import {
  addItem,
  bulkCreate,
  deleteItem,
  extractFromImageMulti,
  processBarcode,
  searchItems,
  updateItem,
} from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
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

// ── Style constants ──────────────────────────────────────────────────────────
const FONT = "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif";

const inputStyle: React.CSSProperties = {
  background: '#0a0a0a',
  border: '1px solid #1c1c1e',
  borderRadius: 8,
  padding: '9px 12px',
  fontSize: 13,
  color: '#f5f5f7',
  width: '100%',
  outline: 'none',
  fontFamily: FONT,
  boxSizing: 'border-box',
};

const labelStyle: React.CSSProperties = {
  fontSize: 12,
  fontWeight: 510,
  color: '#a1a1a6',
  letterSpacing: '-0.01em',
  marginBottom: 4,
  display: 'block',
};

const primaryBtnStyle: React.CSSProperties = {
  background: '#fff',
  color: '#000',
  borderRadius: 6,
  padding: '9px 20px',
  fontSize: 13,
  fontWeight: 510,
  border: 'none',
  cursor: 'pointer',
  fontFamily: FONT,
};

const cancelBtnStyle: React.CSSProperties = {
  background: 'transparent',
  border: '1px solid #1c1c1e',
  borderRadius: 6,
  padding: '9px 16px',
  fontSize: 13,
  color: '#a1a1a6',
  cursor: 'pointer',
  fontFamily: FONT,
};

const toolbarBtnStyle: React.CSSProperties = {
  background: 'transparent',
  border: '1px solid #1c1c1e',
  borderRadius: 8,
  padding: '7px 14px',
  fontSize: 12,
  fontWeight: 500,
  letterSpacing: '-0.012em',
  color: '#a1a1a6',
  cursor: 'pointer',
  fontFamily: FONT,
};

const thStyle: React.CSSProperties = {
  fontSize: 10,
  fontWeight: 500,
  color: '#6e6e73',
  textTransform: 'uppercase',
  letterSpacing: '0.07em',
  textAlign: 'left',
  padding: '0 0 10px',
};

// ── Component ────────────────────────────────────────────────────────────────
export function HomeInventoryClient(props: { locationFilter?: string }) {
  const supabase = createSupabaseBrowserClient();
  const [token, setToken] = useState<string | null>(null);
  const [allItems, setAllItems] = useState<InventoryItem[]>([]);
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [query, setQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [selectedSpace, setSelectedSpace] = useState<string | null>(null);
  const [localSpaces, setLocalSpaces] = useState<string[]>([]);
  const [createSpaceOpen, setCreateSpaceOpen] = useState(false);
  const [newSpaceName, setNewSpaceName] = useState('');
  const [spreadsheetSpace, setSpreadsheetSpace] = useState<string | null>(null);
  const [spreadsheetOpen, setSpreadsheetOpen] = useState(false);
  const [shareSpace, setShareSpace] = useState<string | null>(null);
  const [shareOpen, setShareOpen] = useState(false);
  const [scanOpen, setScanOpen] = useState(false);
  const [barcodeInput, setBarcodeInput] = useState('');
  const [barcodeProgressStep, setBarcodeProgressStep] = useState(0);

  const [draft, setDraft] = useState<InventoryItem>({
    item_id: '', name: '', category: '', quantity: 1, location: '',
    image_url: null, barcode: null, brand: null, part_number: null,
    purchase_source: null, notes: null, created_at: '',
  });
  const [createOpen, setCreateOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [editItemId, setEditItemId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState<InventoryItem>({
    item_id: '', name: '', category: '', quantity: 1, location: '',
    image_url: null, barcode: null, brand: null, part_number: null,
    purchase_source: null, notes: null, created_at: '',
  });

  const uploadImageRef = useRef<HTMLInputElement>(null);

  // ── Helpers ────────────────────────────────────────────────────────────────
  function normalizeLocation(value?: string | null) {
    const loc = (value ?? '').trim();
    if (!loc || loc.toLowerCase() === 'unsorted') return 'Unsorted';
    return loc;
  }

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === 'string') return err;
    return fallback;
  }

  async function refreshToken(): Promise<string> {
    const supabase = createSupabaseBrowserClient()
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (session?.access_token) return session.access_token
    } catch (_) {}
    return ''
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  async function load(currentToken?: string, queryOverride?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      if (!t) return;
      const q = (queryOverride ?? query).trim();
      const res = await searchItems({ token: t, query: q });
      setItems(res?.items ?? []);
      if (!q) setAllItems(res?.items ?? []);
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to load inventory'));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const init = async () => {
      setLoading(true);
      try {
        const { data: { session } } = await supabase.auth.getSession();
        const t = session?.access_token ?? '';
        if (!t) return;
        setToken(t);
        const res = await searchItems({ token: t, query: '' });
        setAllItems(res?.items ?? []);
        setItems(res?.items ?? []);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    void init();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!query.trim() || !token) return;
    const timeout = window.setTimeout(() => { void load(undefined, query); }, 400);
    return () => window.clearTimeout(timeout);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query, token]);

  useEffect(() => {
    if (!props.locationFilter?.trim()) return;
    setSelectedSpace(normalizeLocation(props.locationFilter));
  }, [props.locationFilter]);

  // ── Item mutations ─────────────────────────────────────────────────────────
  async function onUpdateItem(itemId: string, updates: Partial<Omit<InventoryItem, 'item_id' | 'created_at'>>) {
    setError(null);
    setLoading(true);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const res = await updateItem({ token: t, item_id: itemId, updates });
      setAllItems((prev) => prev.map((it) => (it.item_id === itemId ? res.item : it)));
      setItems((prev) => prev.map((it) => (it.item_id === itemId ? res.item : it)));
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to update item'));
    } finally {
      setLoading(false);
    }
  }

  async function onDelete(itemId: string) {
    setError(null);
    setLoading(true);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      await deleteItem({ token: t, item_id: itemId });
      setAllItems((prev) => prev.filter((i) => i.item_id !== itemId));
      setItems((prev) => prev.filter((i) => i.item_id !== itemId));
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to delete item'));
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
      brand: editDraft.brand ?? null,
      part_number: editDraft.part_number ?? null,
      barcode: editDraft.barcode ?? null,
      purchase_source: editDraft.purchase_source ?? null,
      notes: editDraft.notes ?? null,
    });
    setEditOpen(false);
  }

  // ── Image extraction ───────────────────────────────────────────────────────
  async function onExtractMultiImage(file: File, spaceOverride?: string) {
    const targetSpace = spaceOverride ?? selectedSpace ?? 'Unsorted';
    setLoading(true);
    setError(null);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const res = await extractFromImageMulti({ token: t, file });
      if (res.items.length > 0) {
        await bulkCreate({
          token: t,
          items: res.items.map((it: ExtractedInventoryItem) => ({ ...it, location: targetSpace })),
        });
        await load(t, '');
      }
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to extract from image'));
    } finally {
      setLoading(false);
    }
  }

  // ── Barcode ────────────────────────────────────────────────────────────────
  async function onBarcode(barcode: string) {
    setError(null);
    setBarcodeProgressStep(0);
    const step1 = window.setTimeout(() => setBarcodeProgressStep(1), 700);
    const step2 = window.setTimeout(() => setBarcodeProgressStep(2), 2500);
    setDraft((d) => ({ ...d, barcode }));
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const res = await processBarcode({ token: t, barcode });
      const guess = res.result as Record<string, unknown>;
      setDraft((d) => ({
        ...d,
        name: d.name || ((guess.name as string) ?? ''),
        category: d.category || ((guess.category as string) ?? ''),
        brand: d.brand || ((guess.brand as string) ?? null),
        notes: d.notes || ((guess.notes as string) ?? null),
      }));
      setScanOpen(false);
      setCreateOpen(true);
    } catch {
      // non-fatal
    } finally {
      window.clearTimeout(step1);
      window.clearTimeout(step2);
    }
  }

  // ── Space management ───────────────────────────────────────────────────────
  function openSpace(spaceName: string) {
    setSelectedSpace(spaceName);
    setCategoryFilter('');
    setQuery('');
  }

  function onCreateSpace() {
    const normalized = normalizeLocation(newSpaceName);
    if (!normalized || normalized === 'Unsorted') return;
    setLocalSpaces((prev) => (prev.includes(normalized) ? prev : [...prev, normalized]));
    setSelectedSpace(normalized);
    setDraft((d) => ({ ...d, location: normalized }));
    setNewSpaceName('');
    setCreateSpaceOpen(false);
  }

  async function onRenameSpace(spaceName: string) {
    const name = window.prompt('Rename space', spaceName)?.trim();
    if (!name) return;
    const normalized = normalizeLocation(name);
    if (!normalized || normalized === spaceName) return;
    setLoading(true);
    setError(null);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const itemsToRename = (allItems ?? []).filter((i) => normalizeLocation(i.location) === spaceName);
      await Promise.all(
        itemsToRename.map((item) => updateItem({ token: t, item_id: item.item_id, updates: { location: normalized } }))
      );
      setLocalSpaces((prev) => prev.map((s) => (s === spaceName ? normalized : s)));
      setSelectedSpace((curr) => (curr === spaceName ? normalized : curr));
      await load(t, '');
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to rename space'));
    } finally {
      setLoading(false);
    }
  }

  async function onDeleteSpace(spaceName: string) {
    if (!window.confirm(`Delete "${spaceName}" and all its items?`)) return;
    setLoading(true);
    setError(null);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const itemsToDelete = (allItems ?? []).filter((i) => normalizeLocation(i.location) === spaceName);
      await Promise.all(itemsToDelete.map((item) => deleteItem({ token: t, item_id: item.item_id })));
      setLocalSpaces((prev) => prev.filter((s) => s !== spaceName));
      if (selectedSpace === spaceName) {
        setSelectedSpace(null);
        setCategoryFilter('');
        setQuery('');
      }
      setAllItems((prev) => prev.filter((i) => normalizeLocation(i.location) !== spaceName));
      setItems((prev) => prev.filter((i) => normalizeLocation(i.location) !== spaceName));
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to delete space'));
    } finally {
      setLoading(false);
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

  // ── Derived state ──────────────────────────────────────────────────────────
  const spaces = useMemo(() => {
    try {
      const fromItems = Array.from(new Set(
        (allItems ?? []).map((i) => (i.location?.trim() || 'Unsorted'))
      ));
      return Array.from(new Set([...fromItems, ...localSpaces])).sort();
    } catch {
      return [];
    }
  }, [allItems, localSpaces]);

  const itemsBySpace = useMemo(() => {
    return (allItems ?? []).reduce<Record<string, InventoryItem[]>>((acc, item) => {
      const spaceName = normalizeLocation(item.location);
      if (!acc[spaceName]) acc[spaceName] = [];
      acc[spaceName].push(item);
      return acc;
    }, {});
  }, [allItems]);

  const visibleItems = useMemo(() => {
    try {
      const base = selectedSpace
        ? (items ?? []).filter((item) => normalizeLocation(item.location) === selectedSpace)
        : (items ?? []);
      if (!categoryFilter) return base;
      return base.filter((item) => (item.category ?? '').toLowerCase() === categoryFilter.toLowerCase());
    } catch {
      return [];
    }
  }, [items, selectedSpace, categoryFilter]);

  const categories: string[] = useMemo(() => {
    try {
      const spaceItems = selectedSpace
        ? (allItems ?? []).filter((i) => normalizeLocation(i.location) === selectedSpace)
        : (allItems ?? []);
      const cats = spaceItems.map((i) => i.category).filter((c): c is string => Boolean(c));
      return Array.from(new Set(cats)).sort((a, b) => a.localeCompare(b));
    } catch {
      return [];
    }
  }, [allItems, selectedSpace]);

  const searchActive = query.trim().length > 0 && !selectedSpace;

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div style={{ padding: '32px 40px', maxWidth: '1100px', fontFamily: FONT, WebkitFontSmoothing: 'antialiased' as unknown as 'auto' }}>

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, letterSpacing: '-0.035em', color: '#f5f5f7', margin: 0 }}>
          {selectedSpace ? selectedSpace : 'My Spaces'}
        </h1>
        {!selectedSpace && (
          <button
            type="button"
            onClick={() => setCreateSpaceOpen(true)}
            style={{ background: 'transparent', border: '1px solid #1c1c1e', borderRadius: 6, padding: '6px 14px', fontSize: 12, fontWeight: 510, color: '#a1a1a6', cursor: 'pointer', fontFamily: FONT }}
          >
            + New Space
          </button>
        )}
      </div>

      {/* Global search bar */}
      {!selectedSpace && (
        <input
          placeholder="Search across all spaces…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          style={{ ...inputStyle, marginBottom: 20 }}
        />
      )}

      {error ? <p style={{ fontSize: 13, color: '#ff453a', marginBottom: 12 }}>{error}</p> : null}

      {/* ── Search results ──────────────────────────────────────────────── */}
      {searchActive ? (
        <div>
          <p style={{ fontSize: 13, color: '#6e6e73', marginBottom: 16 }}>{visibleItems.length} matching items</p>
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 1fr', gap: 12, padding: '0 0 10px', borderBottom: '1px solid #1c1c1e' }}>
            {['Name', 'Category', 'Qty', 'Location'].map((h) => (
              <div key={h} style={thStyle}>{h}</div>
            ))}
          </div>
          {(visibleItems ?? []).map((item) => (
            <div key={item.item_id} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 1fr', gap: 12, padding: '12px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
              <div style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em' }}>{item.name}</div>
              <div><span style={{ fontSize: 11, padding: '2px 8px', background: '#1c1c1e', borderRadius: 99, color: '#a1a1a6' }}>{item.category}</span></div>
              <div style={{ fontSize: 13, fontWeight: 590, color: item.quantity <= 1 ? '#ffd60a' : '#f5f5f7' }}>{item.quantity}</div>
              <div style={{ fontSize: 12, color: '#6e6e73' }}>{normalizeLocation(item.location)}</div>
            </div>
          ))}
          {visibleItems.length === 0 ? (
            <div style={{ fontSize: 13, color: '#3a3a3c', textAlign: 'center', padding: '40px 0' }}>No matching items found.</div>
          ) : null}
        </div>

      /* ── Space detail view ──────────────────────────────────────────── */
      ) : selectedSpace ? (
        <div>
          <button
            type="button"
            onClick={() => { setSelectedSpace(null); setCategoryFilter(''); setQuery(''); }}
            style={{ fontSize: 13, color: '#6e6e73', background: 'transparent', border: 'none', cursor: 'pointer', letterSpacing: '-0.01em', marginBottom: 20, padding: 0, fontFamily: FONT }}
          >
            ← My Spaces
          </button>

          <div style={{ marginBottom: 4 }}>
            <p style={{ fontSize: 12, color: '#6e6e73', margin: 0 }}>{(itemsBySpace[selectedSpace] ?? []).length} items</p>
          </div>

          {/* Toolbar */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 20, marginBottom: 20 }}>
            <label style={{ ...toolbarBtnStyle, display: 'inline-flex', alignItems: 'center', userSelect: 'none' }}>
              Upload Image
              <input
                ref={uploadImageRef}
                type="file"
                accept="image/*"
                style={{ display: 'none' }}
                onChange={(e) => { const f = e.target.files?.[0]; if (f) void onExtractMultiImage(f); }}
              />
            </label>
            <button type="button" onClick={() => openSpreadsheet(selectedSpace)} style={toolbarBtnStyle}>Import Spreadsheet</button>
            <button type="button" onClick={() => setScanOpen(true)} style={toolbarBtnStyle}>Scan Barcode</button>
            <button type="button" onClick={() => { setDraft((d) => ({ ...d, location: selectedSpace })); setCreateOpen(true); }} style={toolbarBtnStyle}>+ Add Item</button>
            <button type="button" onClick={() => openShare(selectedSpace)} style={toolbarBtnStyle}>Share Space</button>
          </div>

          {/* Space search + category pills */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginBottom: 12 }}>
            <input
              placeholder="Search items…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              style={{ flex: 1, minWidth: 200, background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 8, padding: '9px 14px', color: '#f5f5f7', fontSize: 13, outline: 'none', fontFamily: FONT }}
            />
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 18 }}>
            <button
              type="button"
              onClick={() => setCategoryFilter('')}
              style={{ background: categoryFilter === '' ? '#1c1c1e' : '#0a0a0a', color: categoryFilter === '' ? '#fff' : '#6e6e73', border: categoryFilter === '' ? '1px solid #2c2c2e' : '1px solid #1c1c1e', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}
            >All</button>
            {(categories ?? []).map((cat) => (
              <button
                key={cat}
                type="button"
                onClick={() => setCategoryFilter(cat)}
                style={{ background: categoryFilter === cat ? '#1c1c1e' : '#0a0a0a', color: categoryFilter === cat ? '#fff' : '#6e6e73', border: categoryFilter === cat ? '1px solid #2c2c2e' : '1px solid #1c1c1e', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}
              >{cat}</button>
            ))}
          </div>

          {/* Items table */}
          {visibleItems.length === 0 && !loading ? (
            <div style={{ textAlign: 'center', padding: '48px 24px', background: '#0a0a0a', borderRadius: 12, border: '1px dashed #2c2c2e' }}>
              <p style={{ fontSize: 13, color: '#6e6e73', margin: '0 0 4px' }}>No items in this space yet</p>
              <p style={{ fontSize: 12, color: '#3a3a3c', margin: 0 }}>Use the toolbar above to add items</p>
            </div>
          ) : (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 1fr 60px 120px', gap: 12, padding: '0 0 10px', borderBottom: '1px solid #1c1c1e' }}>
                {['Name', 'Category', 'Qty', 'Location', 'Image', 'Actions'].map((h) => (
                  <div key={h} style={thStyle}>{h}</div>
                ))}
              </div>
              {(visibleItems ?? []).map((it) => (
                <div
                  key={it.item_id}
                  style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 1fr 60px 120px', gap: 12, padding: '12px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}
                >
                  <div style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{it.name}</div>
                  <div><span style={{ fontSize: 11, padding: '2px 8px', background: '#1c1c1e', borderRadius: 99, color: '#a1a1a6', display: 'inline-block' }}>{it.category}</span></div>
                  <div style={{ fontSize: 13, fontWeight: 590, color: it.quantity <= 1 ? '#ffd60a' : '#f5f5f7' }}>{it.quantity}</div>
                  <div style={{ fontSize: 12, color: '#6e6e73', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{normalizeLocation(it.location)}</div>
                  <div>
                    {it.image_url ? (
                      <a href={it.image_url} target="_blank" rel="noreferrer" style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', textDecoration: 'underline' }}>View</a>
                    ) : (
                      <span style={{ color: 'rgba(255,255,255,0.2)', fontSize: 12 }}>—</span>
                    )}
                  </div>
                  <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                    <button type="button" onClick={() => openEdit(it)} disabled={loading} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>Edit</button>
                    <button type="button" onClick={() => void onUpdateItem(it.item_id, { quantity: it.quantity + 1 })} disabled={loading} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>+1</button>
                    <button type="button" onClick={() => void onUpdateItem(it.item_id, { quantity: Math.max(0, it.quantity - 1) })} disabled={loading || it.quantity === 0} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px', opacity: it.quantity === 0 ? 0.3 : 1 }}>-1</button>
                    <button type="button" onClick={() => void onUpdateItem(it.item_id, { quantity: 0 })} disabled={loading || it.quantity === 0} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px', opacity: it.quantity === 0 ? 0.3 : 1 }}>Out</button>
                    <button type="button" onClick={() => void onDelete(it.item_id)} disabled={loading} style={{ fontSize: 11, color: '#ff453a', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>Delete</button>
                  </div>
                </div>
              ))}
            </>
          )}
        </div>

      /* ── Spaces grid ────────────────────────────────────────────────── */
      ) : loading ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12, marginTop: 20 }}>
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="skeleton" style={{ height: 110, borderRadius: 12 }} />
          ))}
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12, marginTop: 20 }}>
          {(spaces ?? []).map((space) => {
            const itemsInSpace = itemsBySpace[space] ?? [];
            const lowStock = itemsInSpace.filter((item) => item.quantity <= 1).length;
            return (
              <div
                key={space}
                style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '18px 20px', cursor: 'pointer', transition: 'all 0.16s' }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#2c2c2e'; (e.currentTarget as HTMLElement).style.transform = 'translateY(-1px)'; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#1c1c1e'; (e.currentTarget as HTMLElement).style.transform = 'translateY(0)'; }}
                onClick={() => openSpace(space)}
              >
                <p style={{ fontSize: 14, fontWeight: 590, color: '#fff', margin: 0, letterSpacing: '-0.02em' }}>{space}</p>
                <p style={{ fontSize: 12, color: '#6e6e73', marginTop: 4, fontWeight: 400 }}>{itemsInSpace.length} items</p>
                {lowStock > 0 ? (
                  <span style={{ fontSize: 10, padding: '2px 8px', borderRadius: 99, background: 'rgba(255,214,10,0.10)', color: '#ffd60a', border: '1px solid rgba(255,214,10,0.20)', marginTop: 8, display: 'inline-block' }}>
                    {lowStock} low stock
                  </span>
                ) : null}
                <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 12 }}>
                  {/* Upload image */}
                  <label
                    style={{ width: 24, height: 24, borderRadius: '50%', background: 'transparent', border: 'none', color: '#3a3a3c', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'color 120ms', flexShrink: 0 }}
                    onClick={(e) => e.stopPropagation()}
                    onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = '#a1a1a6'; }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = '#3a3a3c'; }}
                  >
                    <UploadCloud size={14} />
                    <input
                      type="file"
                      accept="image/*"
                      style={{ display: 'none' }}
                      onChange={(e) => { const f = e.target.files?.[0]; if (f) void onExtractMultiImage(f, space); }}
                    />
                  </label>
                  {/* Share */}
                  <button
                    type="button"
                    onClick={(e) => { e.stopPropagation(); openShare(space); }}
                    style={{ width: 24, height: 24, borderRadius: '50%', background: 'transparent', border: 'none', color: '#3a3a3c', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'color 120ms', flexShrink: 0 }}
                    onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = '#a1a1a6'; }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = '#3a3a3c'; }}
                  >
                    <Share2 size={14} />
                  </button>
                  {/* More */}
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <button
                        type="button"
                        onClick={(e) => e.stopPropagation()}
                        style={{ width: 24, height: 24, borderRadius: '50%', background: 'transparent', border: 'none', color: '#3a3a3c', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'color 120ms', flexShrink: 0 }}
                        onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = '#a1a1a6'; }}
                        onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = '#3a3a3c'; }}
                      >
                        <MoreHorizontal size={14} />
                      </button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent>
                      <DropdownMenuItem onSelect={() => void onRenameSpace(space)}>Rename</DropdownMenuItem>
                      <DropdownMenuSeparator />
                      <DropdownMenuItem onSelect={() => void onDeleteSpace(space)}>Delete</DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </div>
            );
          })}

          {/* New Space dashed card */}
          <div
            style={{ background: 'transparent', border: '1px dashed #2c2c2e', borderRadius: 12, minHeight: 110, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, cursor: 'pointer', transition: 'border-color 0.16s' }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#3a3a3c'; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#2c2c2e'; }}
            onClick={() => setCreateSpaceOpen(true)}
          >
            <div style={{ fontSize: 20, color: '#3a3a3c' }}>+</div>
            <div style={{ fontSize: 12, color: '#3a3a3c' }}>New Space</div>
          </div>
        </div>
      )}

      {/* ── Dialogs ───────────────────────────────────────────────────────── */}

      {/* New Space */}
      <Dialog open={createSpaceOpen} onOpenChange={setCreateSpaceOpen}>
        <DialogContent style={{ background: '#111113', border: '1px solid #2c2c2e', borderRadius: 14, padding: 28, maxWidth: 440 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7' }}>New Space</DialogTitle>
          </DialogHeader>
          <div style={{ marginTop: 20 }}>
            <label style={labelStyle}>Space name</label>
            <input
              value={newSpaceName}
              onChange={(e) => setNewSpaceName(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') onCreateSpace(); }}
              placeholder="e.g. Kitchen, Garage, Robot Parts"
              style={inputStyle}
              autoFocus
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 20 }}>
              <button type="button" onClick={() => setCreateSpaceOpen(false)} style={cancelBtnStyle}>Cancel</button>
              <button type="button" onClick={onCreateSpace} style={primaryBtnStyle}>Create</button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Spreadsheet import */}
      <Dialog open={spreadsheetOpen} onOpenChange={(open) => { setSpreadsheetOpen(open); if (!open) setSpreadsheetSpace(null); }}>
        <DialogContent style={{ background: '#111113', border: '1px solid #2c2c2e', borderRadius: 14, padding: 28, maxWidth: 600 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7' }}>Import Spreadsheet</DialogTitle>
          </DialogHeader>
          {spreadsheetSpace ? (
            <SpreadsheetImportModal
              spaceName={spreadsheetSpace}
              token={token ?? ''}
              onSuccess={() => void load(token ?? undefined, query)}
            />
          ) : null}
        </DialogContent>
      </Dialog>

      {/* Barcode scan */}
      <Dialog open={scanOpen} onOpenChange={setScanOpen}>
        <DialogContent style={{ background: '#111113', border: '1px solid #2c2c2e', borderRadius: 14, padding: 28, maxWidth: 500 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7' }}>Scan Barcode</DialogTitle>
          </DialogHeader>
          <div style={{ marginTop: 16 }}>
            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>Enter barcode manually</label>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  value={barcodeInput}
                  onChange={(e) => setBarcodeInput(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter' && barcodeInput.trim()) void onBarcode(barcodeInput.trim()); }}
                  placeholder="e.g. 012345678901"
                  style={{ ...inputStyle, flex: 1 }}
                />
                <button
                  type="button"
                  onClick={() => { if (barcodeInput.trim()) void onBarcode(barcodeInput.trim()); }}
                  style={primaryBtnStyle}
                >
                  Look up
                </button>
              </div>
              {barcodeProgressStep > 0 ? (
                <div style={{ marginTop: 10, fontSize: 12, color: '#6e6e73' }}>
                  {barcodeProgressStep >= 1 ? '✓ Scanning…' : ''}
                  {barcodeProgressStep >= 2 ? ' ✓ Looking up details…' : ''}
                </div>
              ) : null}
            </div>
            <p style={{ fontSize: 11, color: '#3a3a3c', margin: '16px 0 8px' }}>— or use camera —</p>
            <BarcodeScanner
              onDetected={(code: string) => {
                void onBarcode(code);
              }}
            />
          </div>
        </DialogContent>
      </Dialog>

      {/* Edit item */}
      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent style={{ background: '#111113', border: '1px solid #2c2c2e', borderRadius: 14, padding: 28, maxWidth: 520 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7' }}>Edit Item</DialogTitle>
          </DialogHeader>
          <form onSubmit={(e) => { void onSaveEdit(e); }} style={{ marginTop: 20 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div>
                <label style={labelStyle}>Name *</label>
                <input value={editDraft.name} onChange={(e) => setEditDraft((d) => ({ ...d, name: e.target.value }))} style={inputStyle} required />
              </div>
              <div>
                <label style={labelStyle}>Category *</label>
                <input value={editDraft.category} onChange={(e) => setEditDraft((d) => ({ ...d, category: e.target.value }))} style={inputStyle} required />
              </div>
              <div>
                <label style={labelStyle}>Brand</label>
                <input value={editDraft.brand ?? ''} onChange={(e) => setEditDraft((d) => ({ ...d, brand: e.target.value }))} style={inputStyle} />
              </div>
              <div>
                <label style={labelStyle}>Part number</label>
                <input value={editDraft.part_number ?? ''} onChange={(e) => setEditDraft((d) => ({ ...d, part_number: e.target.value }))} style={inputStyle} />
              </div>
              <div>
                <label style={labelStyle}>Quantity *</label>
                <input type="number" min={0} value={editDraft.quantity} onChange={(e) => setEditDraft((d) => ({ ...d, quantity: Number.parseInt(e.target.value || '0', 10) }))} style={inputStyle} required />
              </div>
              <div>
                <label style={labelStyle}>Location</label>
                <input value={editDraft.location} onChange={(e) => setEditDraft((d) => ({ ...d, location: e.target.value }))} style={inputStyle} />
              </div>
            </div>
            <div style={{ marginTop: 14 }}>
              <label style={labelStyle}>Notes</label>
              <textarea
                value={editDraft.notes ?? ''}
                onChange={(e) => setEditDraft((d) => ({ ...d, notes: e.target.value }))}
                rows={3}
                style={{ ...inputStyle, resize: 'vertical' }}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 20 }}>
              <button type="button" onClick={() => setEditOpen(false)} style={cancelBtnStyle}>Cancel</button>
              <button type="submit" disabled={loading} style={{ ...primaryBtnStyle, opacity: loading ? 0.5 : 1 }}>Save</button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Add item */}
      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent style={{ background: '#111113', border: '1px solid #2c2c2e', borderRadius: 14, padding: 28, maxWidth: 520 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7' }}>Add Item</DialogTitle>
          </DialogHeader>
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              setError(null);
              setLoading(true);
              try {
                const t = token || (await refreshToken());
                if (!t) { setError('Session expired. Please refresh the page.'); return; }
                if (!draft.name?.trim()) throw new Error('Name is required');
                if (!draft.category?.trim()) throw new Error('Category is required');
                const res = await addItem({
                  token: t,
                  item: {
                    name: draft.name.trim(),
                    category: draft.category.trim(),
                    quantity: draft.quantity ?? 1,
                    location: draft.location?.trim() || selectedSpace || 'Unsorted',
                    image_url: draft.image_url ?? null,
                    barcode: draft.barcode ?? null,
                    brand: draft.brand ?? null,
                    part_number: draft.part_number ?? null,
                    purchase_source: draft.purchase_source ?? null,
                    notes: draft.notes ?? null,
                  },
                });
                setAllItems((prev) => [res.item, ...(prev ?? [])]);
                setItems((prev) => [res.item, ...(prev ?? [])]);
                setDraft({ item_id: '', name: '', category: '', quantity: 1, location: selectedSpace ?? '', image_url: null, barcode: null, brand: null, part_number: null, purchase_source: null, notes: null, created_at: '' });
                setCreateOpen(false);
              } catch (err: unknown) {
                setError(errorMessage(err, 'Failed to add item'));
              } finally {
                setLoading(false);
              }
            }}
            style={{ marginTop: 20 }}
          >
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div>
                <label style={labelStyle}>Name *</label>
                <input value={draft.name} onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))} style={inputStyle} required autoFocus />
              </div>
              <div>
                <label style={labelStyle}>Category *</label>
                <input value={draft.category} onChange={(e) => setDraft((d) => ({ ...d, category: e.target.value }))} style={inputStyle} required />
              </div>
              <div>
                <label style={labelStyle}>Brand</label>
                <input value={draft.brand ?? ''} onChange={(e) => setDraft((d) => ({ ...d, brand: e.target.value }))} style={inputStyle} />
              </div>
              <div>
                <label style={labelStyle}>Part number</label>
                <input value={draft.part_number ?? ''} onChange={(e) => setDraft((d) => ({ ...d, part_number: e.target.value }))} style={inputStyle} />
              </div>
              <div>
                <label style={labelStyle}>Quantity</label>
                <input type="number" min={0} value={draft.quantity} onChange={(e) => setDraft((d) => ({ ...d, quantity: Number.parseInt(e.target.value || '0', 10) }))} style={inputStyle} />
              </div>
              <div>
                <label style={labelStyle}>Location</label>
                <input value={draft.location} onChange={(e) => setDraft((d) => ({ ...d, location: e.target.value }))} style={inputStyle} />
              </div>
            </div>
            <div style={{ marginTop: 14 }}>
              <label style={labelStyle}>Notes</label>
              <textarea
                value={draft.notes ?? ''}
                onChange={(e) => setDraft((d) => ({ ...d, notes: e.target.value }))}
                rows={3}
                style={{ ...inputStyle, resize: 'vertical' }}
              />
            </div>
            {error ? <p style={{ fontSize: 12, color: '#ff453a', marginTop: 10 }}>{error}</p> : null}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 20 }}>
              <button type="button" onClick={() => setCreateOpen(false)} style={cancelBtnStyle}>Cancel</button>
              <button type="submit" disabled={loading} style={{ ...primaryBtnStyle, opacity: loading ? 0.5 : 1 }}>Save Item</button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Share space — rendered outside all conditionals so it works from both grid and detail */}
      <ShareSpaceModal
        open={shareOpen}
        onOpenChange={setShareOpen}
        spaceName={shareSpace ?? selectedSpace ?? ''}
        token={token ?? ''}
      />

    </div>
  );
}
