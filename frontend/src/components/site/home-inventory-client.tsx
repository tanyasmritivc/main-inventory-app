"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { MoreHorizontal, Share2, UploadCloud } from "lucide-react";
import type { ExtractedInventoryItem, InventoryItem } from "@/lib/api";
import {
  addItem,
  bulkCreate,
  checkUsage,
  deleteItem,
  extractFromImageMulti,
  getJoinedShares,
  getMyShares,
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
import { UpgradeModal } from "@/components/site/upgrade-modal";
import { UpgradeGate } from "@/components/site/upgrade-gate";
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
  background: 'rgba(255,255,255,0.04)',
  border: '1px solid rgba(255,255,255,0.10)',
  borderRadius: 8,
  padding: '8px 16px',
  fontSize: 12,
  fontWeight: 500,
  letterSpacing: '-0.012em',
  color: '#a1a1a6',
  cursor: 'pointer',
  fontFamily: FONT,
  transition: 'background 0.15s, border-color 0.15s',
  display: 'inline-flex',
  alignItems: 'center',
  gap: '6px',
  whiteSpace: 'nowrap' as const,
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
  const [expandedItemId, setExpandedItemId] = useState<string | null>(null);
  const [myShares, setMyShares] = useState<any[]>([])
  const [joinedShares, setJoinedShares] = useState<any[]>([])
  const [sharedSpacesLoading, setSharedSpacesLoading] = useState(false)
  const [viewingSharedSpace, setViewingSharedSpace] = useState<{
    shareId: string
    spaceName: string
    permission: string
    isOwned: boolean
  } | null>(null)
  const [sharedSpaceItems, setSharedSpaceItems] = useState<any[]>([])
  const [sharedSpaceLoading, setSharedSpaceLoading] = useState(false)
  const [sharedCategoryFilter, setSharedCategoryFilter] = useState('')
  const [editItemId, setEditItemId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState<InventoryItem>({
    item_id: '', name: '', category: '', quantity: 1, location: '',
    image_url: null, barcode: null, brand: null, part_number: null,
    purchase_source: null, notes: null, created_at: '',
  });
  const [sharedSpaceSearch, setSharedSpaceSearch] = useState('')
  const [expandedSharedItemId, setExpandedSharedItemId] = useState<string | null>(null)

  const [upgradeModal, setUpgradeModal] = useState<{ open: boolean; reason: 'item_limit' | 'scan_limit' }>({ open: false, reason: 'item_limit' });
  const [upgradeGate, setUpgradeGate] = useState<{ open: boolean; feature: string; current: number; limit: number; message: string }>({ open: false, feature: '', current: 0, limit: 0, message: '' });

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

  function handleApiError(err: any): boolean {
    if (err?.limitExceeded && err?.limitData) {
      setUpgradeGate({ open: true, feature: err.limitData.feature, current: err.limitData.current, limit: err.limitData.limit, message: err.limitData.message });
      return true;
    }
    if (err?.status === 403 || err?.upgrade_required) {
      const reason: 'item_limit' | 'scan_limit' = err?.error === 'scan_limit_reached' ? 'scan_limit' : 'item_limit';
      setUpgradeModal({ open: true, reason });
      return true;
    }
    return false;
  }

  const checkAndGate = async (feature: string): Promise<boolean> => {
    try {
      const t = token || (await refreshToken())
      if (!t) return true
      const res = await checkUsage({ token: t, feature })
      if (!res || typeof res !== 'object') return true
      if (!res.allowed) {
        setUpgradeGate({
          open: true,
          feature,
          current: res.current ?? 0,
          limit: res.limit ?? 0,
          message: `You've used ${res.current ?? 0} of ${res.limit ?? 0} free ${res.feature_label ?? feature.replace(/_/g, ' ')}s this month.`,
        })
        return false
      }
      return true
    } catch {
      return true
    }
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

  useEffect(() => {
    if (!token) return
    const loadShares = async () => {
      setSharedSpacesLoading(true)
      try {
        const t = token || await refreshToken()
        if (!t) return
        const [mySharesRes, joinedRes] = await Promise.all([
          getMyShares({ token: t }),
          getJoinedShares({ token: t }),
        ])
        setMyShares(mySharesRes?.shares ?? [])
        setJoinedShares(joinedRes?.shares ?? [])
      } catch (err) {
        console.error('Failed to load shares:', err)
      } finally {
        setSharedSpacesLoading(false)
      }
    }
    void loadShares()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token])

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
    if (viewingSharedSpace) {
      await loadSharedSpace(viewingSharedSpace.shareId)
    }
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
    } catch (err: any) {
      if (!handleApiError(err)) {
        setError(errorMessage(err, 'Failed to extract from image'));
      }
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

  async function loadSharedSpace(shareId: string) {
    setSharedSpaceLoading(true)
    try {
      const t = token || await refreshToken()
      if (!t) return
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_BASE_URL}/sharing/${shareId}/inventory`,
        { headers: { Authorization: `Bearer ${t}` } }
      )
      const data = await res.json()
      setSharedSpaceItems(data?.items ?? data ?? [])
    } catch (err) {
      console.error('Failed to load shared space:', err)
      setSharedSpaceItems([])
    } finally {
      setSharedSpaceLoading(false)
    }
  }

  async function handleUpdateItem(itemId: string, updates: Record<string, unknown>) {
    const t = token || await refreshToken()
    if (!t) return
    try {
      await updateItem({ token: t, item_id: itemId, updates })
      if (viewingSharedSpace) await loadSharedSpace(viewingSharedSpace.shareId)
    } catch (err) {
      console.error('Update failed:', err)
    }
  }

  async function handleDeleteSharedItem(itemId: string) {
    if (!confirm('Delete this item?')) return
    const t = token || await refreshToken()
    if (!t) return
    try {
      await deleteItem({ token: t, item_id: itemId })
      setSharedSpaceItems((prev: any[]) => prev.filter((i: any) => i.item_id !== itemId))
    } catch (err) {
      console.error('Delete failed:', err)
    }
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

  const tableColumns = useMemo(() => {
    const spaceItems = visibleItems ?? []
    const cols: { field: string; label: string }[] = [
      { field: 'name', label: 'Name' },
    ]
    const hasField = (field: string) =>
      spaceItems.some(i => {
        const val = (i as unknown as Record<string, unknown>)[field]
        return val !== null && val !== undefined && String(val).trim() !== ''
      })
    if (hasField('part_number')) cols.push({ field: 'part_number', label: 'Part #' })
    if (hasField('subcategory')) cols.push({ field: 'subcategory', label: 'Size / Type' })
    if (hasField('brand')) cols.push({ field: 'brand', label: 'Vendor' })
    if (hasField('purchase_source')) cols.push({ field: 'purchase_source', label: 'Vendor Part #' })
    if (hasField('category')) cols.push({ field: 'category', label: 'Category' })
    cols.push({ field: 'quantity', label: 'Qty' })
    if (hasField('notes')) cols.push({ field: 'notes', label: 'Notes' })
    cols.push({ field: 'actions', label: 'Actions' })
    return cols
  }, [visibleItems])

  const gridTemplate = useMemo(() => {
    return tableColumns.map(col => {
      if (col.field === 'name') return '2fr'
      if (col.field === 'actions') return '120px'
      if (col.field === 'quantity') return '56px'
      if (col.field === 'notes') return '2fr'
      if (col.field === 'part_number') return '1fr'
      if (col.field === 'purchase_source') return '1fr'
      return '1fr'
    }).join(' ')
  }, [tableColumns])

  const sharedCategories = useMemo(() =>
    Array.from(new Set(sharedSpaceItems.map((i: any) => i.category).filter(Boolean))).sort() as string[],
  [sharedSpaceItems])

  const filteredSharedItems = useMemo(() => {
    let items = sharedSpaceItems
    if (sharedCategoryFilter) items = items.filter((i: any) => i.category === sharedCategoryFilter)
    if (sharedSpaceSearch.trim()) {
      const q = sharedSpaceSearch.toLowerCase()
      items = items.filter((i: any) =>
        i.name?.toLowerCase().includes(q) ||
        i.part_number?.toLowerCase().includes(q) ||
        i.brand?.toLowerCase().includes(q) ||
        i.notes?.toLowerCase().includes(q)
      )
    }
    return items
  }, [sharedSpaceItems, sharedCategoryFilter, sharedSpaceSearch])

  const sharedTableColumns = useMemo(() => {
    const items = sharedSpaceItems ?? []
    const cols: { field: string; label: string }[] = [{ field: 'name', label: 'Name' }]
    const hasField = (f: string) => items.some((i: any) => {
      const v = i[f]; return v !== null && v !== undefined && String(v).trim() !== ''
    })
    if (hasField('part_number')) cols.push({ field: 'part_number', label: 'Part #' })
    if (hasField('subcategory')) cols.push({ field: 'subcategory', label: 'Size / Type' })
    if (hasField('brand')) cols.push({ field: 'brand', label: 'Vendor' })
    if (hasField('purchase_source')) cols.push({ field: 'purchase_source', label: 'Vendor Part #' })
    if (hasField('category')) cols.push({ field: 'category', label: 'Category' })
    cols.push({ field: 'quantity', label: 'Qty' })
    if (hasField('notes')) cols.push({ field: 'notes', label: 'Notes' })
    if (viewingSharedSpace?.permission === 'edit') cols.push({ field: 'actions', label: 'Actions' })
    return cols
  }, [sharedSpaceItems, viewingSharedSpace])

  const sharedGridTemplate = useMemo(() =>
    sharedTableColumns.map(col => {
      if (col.field === 'name') return '2fr'
      if (col.field === 'actions') return '130px'
      if (col.field === 'quantity') return '56px'
      if (col.field === 'notes') return '2fr'
      return '1fr'
    }).join(' ')
  , [sharedTableColumns])

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
            onClick={async () => {
              const allowed = await checkAndGate('spaces')
              if (!allowed) return
              setCreateSpaceOpen(true)
            }}
            style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: 8, padding: '7px 14px', fontSize: 12, fontWeight: 510, color: '#a1a1a6', cursor: 'pointer', fontFamily: FONT, transition: 'background 0.15s' }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.08)'; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}
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
      ) : viewingSharedSpace ? (
        <div>
          <button
            onClick={() => { setViewingSharedSpace(null); setSharedSpaceItems([]); setSharedSpaceSearch(''); setExpandedSharedItemId(null) }}
            style={{ fontSize: 12, color: '#6e6e73', background: 'transparent', border: 'none', cursor: 'pointer', padding: 0, marginBottom: 20, fontFamily: FONT, letterSpacing: '-0.01em' }}>
            ← My Spaces
          </button>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 4 }}>
            <h1 style={{ fontSize: 20, fontWeight: 700, letterSpacing: '-0.03em', color: '#f5f5f7', margin: 0 }}>
              {viewingSharedSpace.spaceName}
            </h1>
            <span style={{ fontSize: 10, padding: '3px 10px', borderRadius: 99, background: viewingSharedSpace.isOwned ? 'rgba(50,215,75,0.10)' : 'rgba(100,149,237,0.10)', border: `1px solid ${viewingSharedSpace.isOwned ? 'rgba(50,215,75,0.20)' : 'rgba(100,149,237,0.20)'}`, color: viewingSharedSpace.isOwned ? '#32d74b' : '#6495ed' }}>
              {viewingSharedSpace.isOwned ? 'shared by me' : 'joined space'}
            </span>
          </div>

          <div style={{ fontSize: 12, color: '#6e6e73', marginBottom: 20, display: 'flex', gap: 16, alignItems: 'center' }}>
            <span>{sharedSpaceLoading ? '…' : `${sharedSpaceItems.length} items`}</span>
            <span style={{ color: '#3a3a3c' }}>·</span>
            <span>{viewingSharedSpace.permission === 'edit' ? 'Can edit' : 'View only'}</span>
            <span style={{ color: '#3a3a3c' }}>·</span>
            <span>{viewingSharedSpace.isOwned ? 'Shared by you' : 'Joined space'}</span>
          </div>

          {/* Toolbar */}
          <div style={{ display: 'flex', flexWrap: 'wrap' as const, gap: 8, marginBottom: 20, alignItems: 'center' }}>
            {viewingSharedSpace.permission === 'edit' && (
              <>
                <label style={{ ...toolbarBtnStyle, display: 'inline-flex', alignItems: 'center', userSelect: 'none' as const }}>
                  Upload Image
                  <input
                    type="file"
                    accept="image/*"
                    style={{ display: 'none' }}
                    onChange={async e => {
                      const file = e.target.files?.[0]
                      if (!file) return
                      const t = token || await refreshToken()
                      if (!t) return
                      try {
                        const res = await extractFromImageMulti({ token: t, file })
                        if (res.items?.length) {
                          await bulkCreate({
                            token: t,
                            items: res.items.map((i: any) => ({ ...i, location: viewingSharedSpace.spaceName }))
                          })
                          await loadSharedSpace(viewingSharedSpace.shareId)
                        }
                      } catch (err) {
                        console.error('Upload failed:', err)
                      }
                    }}
                  />
                </label>
                <button type="button" onClick={() => openSpreadsheet(viewingSharedSpace.spaceName)} style={toolbarBtnStyle}>Import Spreadsheet</button>
                <button type="button" onClick={() => setScanOpen(true)} style={toolbarBtnStyle}>Scan Barcode</button>
                <button type="button" onClick={() => { setDraft((d) => ({ ...d, location: viewingSharedSpace.spaceName })); setCreateOpen(true); }} style={toolbarBtnStyle}>+ Add Item</button>
              </>
            )}
            <button type="button" onClick={() => openShare(viewingSharedSpace.spaceName)} style={toolbarBtnStyle}>Share Space</button>
            {viewingSharedSpace.permission === 'view' && (
              <span style={{ fontSize: 11, color: '#3a3a3c', alignSelf: 'center', marginLeft: 4 }}>View only — contact the owner to make changes</span>
            )}
          </div>

          {/* Search bar */}
          <input
            placeholder="Search items…"
            value={sharedSpaceSearch}
            onChange={e => setSharedSpaceSearch(e.target.value)}
            style={{ width: '100%', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: 8, padding: '9px 14px', fontSize: 13, color: '#f5f5f7', outline: 'none', fontFamily: FONT, letterSpacing: '-0.01em', marginBottom: 12, boxSizing: 'border-box' as const }}
          />

          {/* Loading skeleton */}
          {sharedSpaceLoading && (
            <div style={{ display: 'flex', flexDirection: 'column' as const, gap: 8, marginTop: 16 }}>
              {[1,2,3,4].map(i => (
                <div key={i} className="skeleton" style={{ height: 44, borderRadius: 8 }} />
              ))}
            </div>
          )}

          {!sharedSpaceLoading && sharedSpaceItems.length > 0 && (
            <>
              {/* Category filter pills */}
              <div style={{ display: 'flex', flexWrap: 'wrap' as const, gap: 6, marginBottom: 16 }}>
                <button
                  onClick={() => setSharedCategoryFilter('')}
                  style={{ background: sharedCategoryFilter === '' ? '#1c1c1e' : 'rgba(255,255,255,0.03)', color: sharedCategoryFilter === '' ? '#fff' : '#6e6e73', border: sharedCategoryFilter === '' ? '1px solid #2c2c2e' : '1px solid rgba(255,255,255,0.07)', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}>
                  All
                </button>
                {sharedCategories.map(cat => (
                  <button
                    key={cat}
                    onClick={() => setSharedCategoryFilter(cat)}
                    style={{ background: sharedCategoryFilter === cat ? '#1c1c1e' : 'rgba(255,255,255,0.03)', color: sharedCategoryFilter === cat ? '#fff' : '#6e6e73', border: sharedCategoryFilter === cat ? '1px solid #2c2c2e' : '1px solid rgba(255,255,255,0.07)', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}>
                    {cat}
                  </button>
                ))}
              </div>

              {/* Dynamic header row */}
              <div style={{ display: 'grid', gridTemplateColumns: sharedGridTemplate, gap: 12, paddingBottom: 10, borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
                {sharedTableColumns.map(col => (
                  <div key={col.field} style={{ fontSize: 10, fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73' }}>{col.label}</div>
                ))}
              </div>

              {/* Item rows */}
              {filteredSharedItems.map((item: any) => (
                <React.Fragment key={item.item_id}>
                  <div style={{ display: 'grid', gridTemplateColumns: sharedGridTemplate, gap: 12, padding: '11px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
                    {sharedTableColumns.map(col => {
                      if (col.field === 'name') return (
                        <div
                          key="name"
                          onClick={() => setExpandedSharedItemId(expandedSharedItemId === item.item_id ? null : item.item_id)}
                          style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em', cursor: 'pointer', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}
                          title="Click to see all details"
                        >
                          {item.name}
                        </div>
                      )
                      if (col.field === 'actions') return (
                        <div key="actions" style={{ display: 'flex', gap: 4, flexWrap: 'wrap' as const }}>
                          <button onClick={() => { openEdit(item as InventoryItem); setExpandedSharedItemId(null) }} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>Edit</button>
                          <button onClick={() => void handleUpdateItem(item.item_id, { quantity: item.quantity + 1 })} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>+1</button>
                          <button onClick={() => void handleUpdateItem(item.item_id, { quantity: Math.max(0, item.quantity - 1) })} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>-1</button>
                          <button onClick={() => void handleUpdateItem(item.item_id, { quantity: 0 })} style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>Out</button>
                          <button onClick={() => void handleDeleteSharedItem(item.item_id)} style={{ fontSize: 11, color: '#ff453a', background: 'none', border: 'none', cursor: 'pointer', padding: '0 2px' }}>Delete</button>
                        </div>
                      )
                      if (col.field === 'quantity') return (
                        <div key="quantity" style={{ fontSize: 13, fontWeight: 590, color: item.quantity <= 1 ? '#ffd60a' : '#f5f5f7' }}>
                          {item.quantity}
                        </div>
                      )
                      if (col.field === 'category') return (
                        <div key="category">
                          <span style={{ fontSize: 11, padding: '2px 8px', background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 99, color: '#a1a1a6' }}>
                            {item.category}
                          </span>
                        </div>
                      )
                      if (col.field === 'part_number') return (
                        <div key="part_number" style={{ fontSize: 11, color: '#a1a1a6', fontFamily: "'SF Mono', ui-monospace, monospace", overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {item.part_number ?? '—'}
                        </div>
                      )
                      if (col.field === 'notes') return (
                        <div key="notes" style={{ fontSize: 11, color: '#6e6e73', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }} title={item.notes ?? ''}>
                          {item.notes ?? '—'}
                        </div>
                      )
                      const value = item[col.field]
                      return (
                        <div key={col.field} style={{ fontSize: 12, color: '#a1a1a6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {value != null ? String(value) : '—'}
                        </div>
                      )
                    })}
                  </div>

                  {/* Expanded detail panel */}
                  {expandedSharedItemId === item.item_id && (
                    <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 10, padding: '16px 20px', display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px 24px', marginBottom: 4 }}>
                      {([
                        { label: 'Name', value: item.name },
                        { label: 'Part Number', value: item.part_number },
                        { label: 'Size / Type', value: item.subcategory },
                        { label: 'Vendor', value: item.brand },
                        { label: 'Vendor Part #', value: item.purchase_source },
                        { label: 'Category', value: item.category },
                        { label: 'Quantity', value: String(item.quantity) },
                        { label: 'Location', value: item.location },
                        { label: 'Barcode', value: item.barcode },
                        { label: 'Added', value: item.created_at ? new Date(item.created_at).toLocaleDateString() : null },
                        { label: 'Notes', value: item.notes },
                      ] as { label: string; value: string | null | undefined }[])
                        .filter(f => f.value)
                        .map(f => (
                          <div key={f.label}>
                            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 3 }}>
                              {f.label}
                            </div>
                            <div style={{ fontSize: 12, color: '#f5f5f7', lineHeight: 1.5, wordBreak: 'break-word' as const }}>
                              {f.value}
                            </div>
                          </div>
                        ))
                      }
                      <div style={{ gridColumn: '1 / -1', marginTop: 8, paddingTop: 12, borderTop: '1px solid rgba(255,255,255,0.06)', display: 'flex', gap: 8 }}>
                        {viewingSharedSpace?.permission === 'edit' && (
                          <button
                            onClick={() => { openEdit(item as InventoryItem); setExpandedSharedItemId(null) }}
                            style={{ fontSize: 12, color: '#a1a1a6', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 6, padding: '5px 14px', cursor: 'pointer', fontFamily: 'inherit' }}>
                            Edit item
                          </button>
                        )}
                        <button
                          onClick={() => setExpandedSharedItemId(null)}
                          style={{ fontSize: 12, color: '#6e6e73', background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: 'inherit' }}>
                          Close ↑
                        </button>
                      </div>
                    </div>
                  )}
                </React.Fragment>
              ))}
            </>
          )}

          {!sharedSpaceLoading && sharedSpaceItems.length === 0 && (
            <div style={{ textAlign: 'center', padding: '48px 24px', background: 'rgba(255,255,255,0.02)', borderRadius: 12, border: '1px dashed rgba(255,255,255,0.08)' }}>
              <div style={{ fontSize: 13, fontWeight: 590, color: '#f5f5f7', marginBottom: 6 }}>No items in this space yet</div>
              <div style={{ fontSize: 12, color: '#3a3a3c' }}>
                {viewingSharedSpace?.permission === 'edit' ? 'Use the toolbar above to add items.' : "The owner hasn't added any items yet."}
              </div>
            </div>
          )}
        </div>

      ) : selectedSpace ? (
        <div>
          <button
            type="button"
            onClick={() => { setSelectedSpace(null); setViewingSharedSpace(null); setCategoryFilter(''); setQuery(''); }}
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
                onChange={async (e) => { const f = e.target.files?.[0]; if (!f) return; const allowed = await checkAndGate('photo_scan'); if (!allowed) { e.target.value = ''; return; } void onExtractMultiImage(f); }}
              />
            </label>
            <button type="button" onClick={async () => { const allowed = await checkAndGate('spreadsheet_import'); if (!allowed) return; openSpreadsheet(selectedSpace ?? ''); }} style={toolbarBtnStyle}>Import Spreadsheet</button>
            <button type="button" onClick={async () => { const allowed = await checkAndGate('barcode_scan'); if (!allowed) return; setScanOpen(true); }} style={toolbarBtnStyle}>Scan Barcode</button>
            <button type="button" onClick={() => { setDraft((d) => ({ ...d, location: selectedSpace })); setCreateOpen(true); }} style={toolbarBtnStyle}>+ Add Item</button>
            <button type="button" onClick={async () => { const allowed = await checkAndGate('share_space'); if (!allowed) return; openShare(selectedSpace); }} style={toolbarBtnStyle}>Share Space</button>
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
              <div style={{ display: 'grid', gridTemplateColumns: gridTemplate, gap: 12, paddingBottom: 10, borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
                {tableColumns.map(col => (
                  <div key={col.field} style={{ fontSize: 10, fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73' }}>
                    {col.label}
                  </div>
                ))}
              </div>
              {(visibleItems ?? []).map((item) => (
                <React.Fragment key={item.item_id}>
                  <div style={{ display: 'grid', gridTemplateColumns: gridTemplate, gap: 12, padding: '11px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
                    {tableColumns.map(col => {
                      if (col.field === 'actions') return (
                        <div key="actions" style={{ display: 'flex', gap: 3, flexWrap: 'wrap' as const }}>
                          <button type="button" onClick={() => openEdit(item)} disabled={loading} style={{ fontSize: 11, color: '#a1a1a6', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 5, cursor: 'pointer', padding: '2px 7px', transition: 'background 0.12s' }} onMouseEnter={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.09)'; }} onMouseLeave={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}>Edit</button>
                          <button type="button" onClick={() => void onUpdateItem(item.item_id, { quantity: item.quantity + 1 })} disabled={loading} style={{ fontSize: 11, color: '#a1a1a6', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 5, cursor: 'pointer', padding: '2px 7px', transition: 'background 0.12s' }} onMouseEnter={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.09)'; }} onMouseLeave={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}>+1</button>
                          <button type="button" onClick={() => void onUpdateItem(item.item_id, { quantity: Math.max(0, item.quantity - 1) })} disabled={loading || item.quantity === 0} style={{ fontSize: 11, color: '#a1a1a6', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 5, cursor: 'pointer', padding: '2px 7px', transition: 'background 0.12s', opacity: item.quantity === 0 ? 0.3 : 1 }} onMouseEnter={e => { if (item.quantity > 0) (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.09)'; }} onMouseLeave={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}>-1</button>
                          <button type="button" onClick={() => void onUpdateItem(item.item_id, { quantity: 0 })} disabled={loading || item.quantity === 0} style={{ fontSize: 11, color: '#a1a1a6', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 5, cursor: 'pointer', padding: '2px 7px', transition: 'background 0.12s', opacity: item.quantity === 0 ? 0.3 : 1 }} onMouseEnter={e => { if (item.quantity > 0) (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.09)'; }} onMouseLeave={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}>Out</button>
                          <button type="button" onClick={() => void onDelete(item.item_id)} disabled={loading} style={{ fontSize: 11, color: '#ff453a', background: 'rgba(255,69,58,0.06)', border: '1px solid rgba(255,69,58,0.15)', borderRadius: 5, cursor: 'pointer', padding: '2px 7px', transition: 'background 0.12s' }} onMouseEnter={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,69,58,0.12)'; }} onMouseLeave={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,69,58,0.06)'; }}>Del</button>
                        </div>
                      )
                      if (col.field === 'name') return (
                        <div
                          key="name"
                          onClick={() => setExpandedItemId(expandedItemId === item.item_id ? null : item.item_id)}
                          style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em', cursor: 'pointer', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}
                          title="Click to expand"
                        >
                          {item.name}
                        </div>
                      )
                      if (col.field === 'quantity') return (
                        <div key="quantity" style={{ fontSize: 13, fontWeight: 590, color: item.quantity <= 1 ? '#ffd60a' : '#f5f5f7' }}>
                          {item.quantity}
                        </div>
                      )
                      if (col.field === 'category') return (
                        <div key="category">
                          <span style={{ fontSize: 11, padding: '2px 8px', background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 99, color: '#a1a1a6' }}>
                            {item.category}
                          </span>
                        </div>
                      )
                      if (col.field === 'part_number') return (
                        <div key="part_number" style={{ fontSize: 11, color: '#a1a1a6', fontFamily: "'SF Mono', ui-monospace, monospace", overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {item.part_number ?? '—'}
                        </div>
                      )
                      if (col.field === 'notes') return (
                        <div key="notes" style={{ fontSize: 11, color: '#6e6e73', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }} title={item.notes ?? ''}>
                          {item.notes ?? '—'}
                        </div>
                      )
                      const value = (item as unknown as Record<string, unknown>)[col.field]
                      return (
                        <div key={col.field} style={{ fontSize: 12, color: '#a1a1a6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {value != null ? String(value) : '—'}
                        </div>
                      )
                    })}
                  </div>
                  {expandedItemId === item.item_id && (
                    <div style={{
                      background: 'rgba(255,255,255,0.02)',
                      border: '1px solid rgba(255,255,255,0.07)',
                      borderRadius: 10,
                      padding: '16px 20px',
                      display: 'grid',
                      gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
                      gap: '12px 24px',
                      marginBottom: 4,
                    }}>
                      {([
                        { label: 'Name', value: item.name },
                        { label: 'Part Number', value: item.part_number },
                        { label: 'Size / Type', value: item.subcategory },
                        { label: 'Vendor', value: item.brand },
                        { label: 'Vendor Part #', value: item.purchase_source },
                        { label: 'Category', value: item.category },
                        { label: 'Quantity', value: String(item.quantity) },
                        { label: 'Location', value: item.location },
                        { label: 'Barcode', value: item.barcode },
                        { label: 'Added', value: item.created_at ? new Date(item.created_at).toLocaleDateString() : null },
                        { label: 'Notes', value: item.notes },
                      ] as { label: string; value: string | null | undefined }[])
                        .filter(f => f.value)
                        .map(f => (
                          <div key={f.label}>
                            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 3 }}>
                              {f.label}
                            </div>
                            <div style={{ fontSize: 12, color: '#f5f5f7', lineHeight: 1.5, wordBreak: 'break-word' as const }}>
                              {f.value}
                            </div>
                          </div>
                        ))
                      }
                      <div style={{ gridColumn: '1 / -1', marginTop: 8, paddingTop: 12, borderTop: '1px solid rgba(255,255,255,0.06)', display: 'flex', gap: 8 }}>
                        <button
                          onClick={() => setExpandedItemId(null)}
                          style={{ fontSize: 12, color: '#6e6e73', background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: 'inherit' }}>
                          Close ↑
                        </button>
                      </div>
                    </div>
                  )}
                </React.Fragment>
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
        <>
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

        {myShares.length > 0 && (
          <div style={{ marginTop: 32 }}>
            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 12 }}>
              Shared by me
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
              {myShares.map(share => (
                <div
                  key={share.share_id ?? share.id}
                  style={{
                    background: 'rgba(255,255,255,0.02)',
                    border: '1px solid rgba(255,255,255,0.07)',
                    borderRadius: 12,
                    padding: '18px 20px',
                    cursor: 'pointer',
                    transition: 'all 0.16s',
                    position: 'relative',
                  }}
                  onMouseEnter={e => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.14)'; e.currentTarget.style.transform = 'translateY(-1px)' }}
                  onMouseLeave={e => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.07)'; e.currentTarget.style.transform = '' }}
                  onClick={() => {
                    setViewingSharedSpace({
                      shareId: share.share_id ?? share.id,
                      spaceName: share.share_name,
                      permission: share.permission,
                      isOwned: true,
                    })
                    void loadSharedSpace(share.share_id ?? share.id)
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 8 }}>
                    <div style={{ fontSize: 14, fontWeight: 590, color: '#f5f5f7', letterSpacing: '-0.02em' }}>
                      {share.share_name}
                    </div>
                    <span style={{ fontSize: 10, padding: '2px 8px', borderRadius: 99, background: 'rgba(50,215,75,0.10)', border: '1px solid rgba(50,215,75,0.20)', color: '#32d74b', flexShrink: 0, marginLeft: 8 }}>
                      shared
                    </span>
                  </div>
                  <div style={{ fontSize: 11, color: '#6e6e73', letterSpacing: '-0.005em' }}>
                    Code: <span style={{ fontFamily: "'SF Mono', ui-monospace, monospace", letterSpacing: '0.06em', color: '#a1a1a6' }}>{share.share_code ?? share.code}</span>
                  </div>
                  <div style={{ fontSize: 11, color: '#6e6e73', marginTop: 3 }}>
                    {share.permission === 'edit' ? 'Can edit' : 'View only'}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {joinedShares.length > 0 && (
          <div style={{ marginTop: 24 }}>
            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 12 }}>
              Joined spaces
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
              {joinedShares.map(share => (
                <div
                  key={share.share_id ?? share.id ?? share.member_id}
                  style={{
                    background: 'rgba(255,255,255,0.02)',
                    border: '1px solid rgba(255,255,255,0.07)',
                    borderRadius: 12,
                    padding: '18px 20px',
                    cursor: 'pointer',
                    transition: 'all 0.16s',
                  }}
                  onMouseEnter={e => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.14)'; e.currentTarget.style.transform = 'translateY(-1px)' }}
                  onMouseLeave={e => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.07)'; e.currentTarget.style.transform = '' }}
                  onClick={() => {
                    setViewingSharedSpace({
                      shareId: share.share_id ?? share.id,
                      spaceName: share.share_name,
                      permission: share.permission,
                      isOwned: false,
                    })
                    void loadSharedSpace(share.share_id ?? share.id)
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 8 }}>
                    <div style={{ fontSize: 14, fontWeight: 590, color: '#f5f5f7', letterSpacing: '-0.02em' }}>
                      {share.share_name}
                    </div>
                    <span style={{ fontSize: 10, padding: '2px 8px', borderRadius: 99, background: 'rgba(100,149,237,0.10)', border: '1px solid rgba(100,149,237,0.20)', color: '#6495ed', flexShrink: 0, marginLeft: 8 }}>
                      joined
                    </span>
                  </div>
                  <div style={{ fontSize: 11, color: '#6e6e73', marginTop: 2 }}>
                    {share.permission === 'edit' ? '· Can edit' : '· View only'}
                  </div>
                  {share.owner && (
                    <div style={{ fontSize: 11, color: '#3a3a3c', marginTop: 2 }}>
                      by {share.owner}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
        </>
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
        <DialogContent style={{ background: 'rgba(12,12,16,0.97)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: 16, padding: 28, maxWidth: 500, backdropFilter: 'blur(24px)' }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 17, fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7', marginBottom: 4 }}>Scan Barcode</DialogTitle>
          </DialogHeader>
          <div style={{ marginTop: 16 }}>
            <div style={{ marginBottom: 8 }}>
              <label style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 8, display: 'block' }}>Enter barcode manually</label>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  value={barcodeInput}
                  onChange={(e) => setBarcodeInput(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter' && barcodeInput.trim()) void onBarcode(barcodeInput.trim()); }}
                  placeholder="e.g. 012345678901"
                  style={{ flex: 1, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: 8, padding: '10px 14px', fontSize: 13, color: '#f5f5f7', outline: 'none', fontFamily: FONT, letterSpacing: '-0.01em', transition: 'border-color 0.15s' }}
                  onFocus={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(255,255,255,0.25)'; }}
                  onBlur={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(255,255,255,0.10)'; }}
                />
                <button
                  type="button"
                  onClick={() => { if (barcodeInput.trim()) void onBarcode(barcodeInput.trim()); }}
                  style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 8, padding: '10px 18px', fontSize: 13, fontWeight: 510, cursor: 'pointer', fontFamily: FONT, whiteSpace: 'nowrap' as const, transition: 'opacity 0.15s' }}
                  onMouseEnter={e => { (e.currentTarget as HTMLElement).style.opacity = '0.85'; }}
                  onMouseLeave={e => { (e.currentTarget as HTMLElement).style.opacity = '1'; }}
                >
                  Look up
                </button>
              </div>
              {barcodeProgressStep > 0 ? (
                <div style={{ marginTop: 10, fontSize: 12, color: '#6e6e73', display: 'flex', gap: 12 }}>
                  <span style={{ color: barcodeProgressStep >= 1 ? '#32d74b' : '#3a3a3c' }}>✓ Scanning</span>
                  <span style={{ color: barcodeProgressStep >= 2 ? '#32d74b' : '#3a3a3c' }}>✓ Fetching details</span>
                </div>
              ) : null}
            </div>
            <div style={{ height: 1, background: 'rgba(255,255,255,0.06)', margin: '20px 0' }} />
            <div style={{ fontSize: 11, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 12 }}>Camera scan</div>
            <BarcodeScanner
              onDetected={(code: string) => {
                void onBarcode(code);
              }}
            />
            <button
              type="button"
              onClick={() => setScanOpen(false)}
              style={{ marginTop: 16, width: '100%', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '9px', fontSize: 13, color: '#6e6e73', cursor: 'pointer', fontFamily: FONT, transition: 'background 0.15s' }}
              onMouseEnter={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.08)'; }}
              onMouseLeave={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}
            >
              Cancel
            </button>
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
                if (viewingSharedSpace) {
                  await loadSharedSpace(viewingSharedSpace.shareId)
                }
              } catch (err: any) {
                if (!handleApiError(err)) {
                  setError(errorMessage(err, 'Failed to add item'));
                }
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

      <UpgradeModal
        open={upgradeModal.open}
        onClose={() => setUpgradeModal((m) => ({ ...m, open: false }))}
        reason={upgradeModal.reason}
      />

      <UpgradeGate
        open={upgradeGate.open}
        onClose={() => setUpgradeGate((g) => ({ ...g, open: false }))}
        feature={upgradeGate.feature}
        current={upgradeGate.current}
        limit={upgradeGate.limit}
        message={upgradeGate.message}
      />

    </div>
  );
}
