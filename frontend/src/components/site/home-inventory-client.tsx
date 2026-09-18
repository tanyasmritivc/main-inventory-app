"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Boxes, ChevronRight, Download, MoreHorizontal, Search, Share2, UploadCloud } from "lucide-react";
import type { ExtractedInventoryItem, InventoryItem, Space } from "@/lib/api";
import {
  addItem,
  bulkCreate,
  checkoutItem,
  createSpace,
  deleteItem,
  deleteShare,
  deleteSpace,
  extractFromImageMulti,
  getJoinedShares,
  getItemCheckouts,
  getMyShares,
  getSpaces,
  itemDisplayDescription,
  itemDisplayName,
  joinShare,
  processBarcode,
  renameSpace,
  searchItems,
  updateItem,
} from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { resolveDisplaySpaces } from "@/lib/spaces";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
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
import { useAppDialog } from "@/components/site/app-dialog-provider";

// ── Style constants ──────────────────────────────────────────────────────────
const FONT = "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif";

const inputStyle: React.CSSProperties = {
  background: 'var(--light-panel)',
  border: '1px solid var(--light-line)',
  borderRadius: 8,
  padding: '9px 12px',
  fontSize: 13,
  color: 'var(--text-primary)',
  width: '100%',
  outline: 'none',
  fontFamily: FONT,
  boxSizing: 'border-box',
};

const labelStyle: React.CSSProperties = {
  fontSize: 12,
  fontWeight: 510,
  color: 'var(--text-secondary)',
  letterSpacing: '-0.01em',
  marginBottom: 4,
  display: 'block',
};

const primaryBtnStyle: React.CSSProperties = {
  background: 'var(--sunset-button)',
  color: '#2b1a21',
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
  border: '1px solid var(--light-line)',
  borderRadius: 6,
  padding: '9px 16px',
  fontSize: 13,
  color: 'var(--text-secondary)',
  cursor: 'pointer',
  fontFamily: FONT,
};

const toolbarBtnStyle: React.CSSProperties = {
  background: 'linear-gradient(145deg, rgba(58,18,48,0.12), rgba(58,18,48,0.035))',
  border: '1px solid rgba(58,18,48,0.16)',
  borderRadius: 12,
  padding: '9px 15px',
  fontSize: 12,
  fontWeight: 500,
  letterSpacing: '-0.012em',
  color: 'var(--text-secondary)',
  cursor: 'pointer',
  fontFamily: FONT,
  transition: 'transform 160ms ease, background 160ms ease, border-color 160ms ease',
  display: 'inline-flex',
  alignItems: 'center',
  gap: '6px',
  whiteSpace: 'nowrap' as const,
  boxShadow: 'inset 0 1px 0 rgba(58,18,48,0.11), 0 8px 22px rgba(0,0,0,0.12)',
  backdropFilter: 'blur(18px) saturate(140%)',
  WebkitBackdropFilter: 'blur(18px) saturate(140%)',
};

const itemActionsTriggerStyle: React.CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  width: 30,
  height: 30,
  padding: 0,
  color: 'var(--text-secondary)',
  background: 'linear-gradient(145deg, rgba(58,18,48,0.16), rgba(58,18,48,0.05))',
  border: '1px solid rgba(58,18,48,0.18)',
  borderRadius: 10,
  cursor: 'pointer',
  boxShadow: 'inset 0 1px 0 rgba(58,18,48,0.14), 0 6px 16px rgba(0,0,0,0.16)',
  backdropFilter: 'blur(18px)',
  WebkitBackdropFilter: 'blur(18px)',
};

const thStyle: React.CSSProperties = {
  fontSize: 10,
  fontWeight: 500,
  color: 'var(--text-secondary)',
  textTransform: 'uppercase',
  letterSpacing: '0.07em',
  textAlign: 'left',
  padding: '0 0 10px',
};

// ── Item detail fields ───────────────────────────────────────────────────────
// Field set, order and labels mirror the mobile item detail sheet
// (mobile/lib/features/inventory/item_detail_sheet.dart). Mobile is the source
// of truth for how an item is presented — if you change anything here, change it
// because mobile changed, not the other way round.
//
// Mobile order: Category, Location, Quantity, Brand, Barcode, Part number,
// Subcategory, Date added, AI confidence — then Notes, Tags, Where to buy.
// Category, Location and Quantity always render on mobile even when thin, so
// they are given a placeholder rather than being filtered out.

type DetailField = { label: string; value: string | null | undefined };

type DetailItemShape = {
  category?: string | null;
  location?: string | null;
  quantity?: number | null;
  brand?: string | null;
  barcode?: string | null;
  part_number?: string | null;
  subcategory?: string | null;
  created_at?: string | null;
  confidence?: number | null;
  notes?: string | null;
  tags?: string[] | null;
  purchase_source?: string | null;
};

function itemDetailFields(item: DetailItemShape): DetailField[] {
  const tags = Array.isArray(item.tags) ? item.tags.filter(Boolean) : [];
  return [
    { label: 'Category', value: item.category?.trim() || '—' },
    { label: 'Location', value: item.location?.trim() || '—' },
    { label: 'Quantity', value: String(item.quantity ?? 0) },
    { label: 'Brand', value: item.brand },
    { label: 'Barcode', value: item.barcode },
    { label: 'Part number', value: item.part_number },
    { label: 'Subcategory', value: item.subcategory },
    {
      label: 'Date added',
      value: item.created_at ? new Date(item.created_at).toLocaleDateString() : null,
    },
    {
      label: 'AI confidence',
      value:
        typeof item.confidence === 'number'
          ? `${Math.round(item.confidence * 100)}%`
          : null,
    },
    { label: 'Notes', value: item.notes },
    { label: 'Tags', value: tags.length ? tags.join(', ') : null },
    { label: 'Where to buy', value: item.purchase_source },
  ];
}

function InventoryStats({
  items,
  spaces,
}: {
  items: InventoryItem[];
  spaces: string[];
}) {
  const totalUnits = items.reduce((sum, item) => sum + Math.max(0, item.quantity ?? 0), 0);
  const lowStock = items.filter((item) => (item.quantity ?? 0) <= 1).length;

  return (
    <section className="inventory-stats" aria-label="Inventory totals">
      <span><strong>{items.length.toLocaleString()}</strong> items</span>
      <span><strong>{totalUnits.toLocaleString()}</strong> units</span>
      <span><strong>{spaces.length.toLocaleString()}</strong> Spaces</span>
      <span className={lowStock > 0 ? "has-alert" : ""}><strong>{lowStock.toLocaleString()}</strong> low stock</span>
    </section>
  );
}

// ── Component ────────────────────────────────────────────────────────────────
export function HomeInventoryClient(props: { locationFilter?: string; itemFilter?: string }) {
  const router = useRouter();
  const supabase = createSupabaseBrowserClient();
  const { confirmAction, promptValue } = useAppDialog();
  const [token, setToken] = useState<string | null>(null);
  const [allItems, setAllItems] = useState<InventoryItem[]>([]);
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [query, setQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [selectedSpace, setSelectedSpace] = useState<string | null>(null);
  const [serverSpaces, setServerSpaces] = useState<Space[]>([]);
  const [spacesLoadError, setSpacesLoadError] = useState<string | null>(null);
  const [initSettled, setInitSettled] = useState(false);
  const [createSpaceOpen, setCreateSpaceOpen] = useState(false);
  const [createSpaceError, setCreateSpaceError] = useState<string | null>(null);
  const [createSpaceLoading, setCreateSpaceLoading] = useState(false);
  const [newSpaceName, setNewSpaceName] = useState('');
  const [joinSpaceOpen, setJoinSpaceOpen] = useState(false);
  const [joinCode, setJoinCode] = useState('');
  const [joinSpaceError, setJoinSpaceError] = useState<string | null>(null);
  const [joinSpaceLoading, setJoinSpaceLoading] = useState(false);
  const [spreadsheetSpace, setSpreadsheetSpace] = useState<string | null>(null);
  const [spreadsheetOpen, setSpreadsheetOpen] = useState(false);
  const [shareSpace, setShareSpace] = useState<string | null>(null);
  const [shareOpen, setShareOpen] = useState(false);
  const [scanOpen, setScanOpen] = useState(false);
  const [barcodeInput, setBarcodeInput] = useState('');
  const [barcodeProgressStep, setBarcodeProgressStep] = useState(0);
  const [historyItem, setHistoryItem] = useState<InventoryItem | null>(null);
  const [checkoutHistory, setCheckoutHistory] = useState<Record<string, unknown>[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);

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

  const uploadImageRef = useRef<HTMLInputElement>(null);

  const activeOwnedShares = useMemo(() => {
    const activeNames = new Set(serverSpaces.map((space) => normalizeLocation(space.name).toLowerCase()));
    return myShares.filter((share) => activeNames.has(normalizeLocation(share.share_name).toLowerCase()));
  }, [myShares, serverSpaces]);

  // ── Helpers ────────────────────────────────────────────────────────────────
  function normalizeLocation(value?: string | null) {
    const loc = (value ?? '').trim();
    if (!loc || loc.toLowerCase() === 'unsorted') return 'Unsorted';
    return loc;
  }

  function errorMessage(err: unknown, fallback: string): string {
    const message = err instanceof Error ? err.message : typeof err === 'string' ? err : '';
    const normalized = message.toLowerCase();
    if (normalized.includes('share not found') || normalized.includes('revoked')) {
      return "We couldn't find an active space with that code. Ask the owner for a current code and try again.";
    }
    if (normalized.includes('already a member')) return 'You already have access to this space.';
    if (normalized.includes('cannot join your own') || normalized.includes('already own this space')) {
      return 'You already own this space. Send this code to a teammate signed in with a different FindEZ account.';
    }
    if (normalized.includes('session') || normalized.includes('not signed in')) return 'Your session has expired. Please sign in again.';
    if (normalized.includes('network') || normalized.includes('failed to fetch')) return "We couldn't connect to FindEZ. Check your connection and try again.";
    return fallback;
  }

  function handleApiError(err: any): boolean {
    if (err?.limitExceeded || err?.status === 403 || err?.upgrade_required) {
      setError("This action is temporarily unavailable. Your existing inventory was not changed.");
      return true;
    }
    return false;
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
        const [itemsResult, spacesResult] = await Promise.allSettled([
          searchItems({ token: t, query: '' }),
          getSpaces({ token: t }),
        ]);

        if (itemsResult.status === 'fulfilled') {
          setAllItems(itemsResult.value?.items ?? []);
          setItems(itemsResult.value?.items ?? []);
        } else {
          console.error('[init] searchItems failed:', itemsResult.reason);
          setError(errorMessage(itemsResult.reason, 'Failed to load inventory'));
        }

        if (spacesResult.status === 'fulfilled') {
          setServerSpaces(spacesResult.value);
        } else {
          const reason = spacesResult.reason;
          console.error('[init] getSpaces failed — status:', (reason as any)?.status, 'body:', reason instanceof Error ? reason.message : reason);
          setSpacesLoadError("Couldn't load your spaces — showing spaces from your items");
        }
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
        setInitSettled(true);
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
    if (!props.itemFilter || !initSettled || spacesLoadError) return;
    const item = allItems.find((row) => row.item_id === props.itemFilter);
    if (!item) return;
    const location = normalizeLocation(item.location);
    const exists = serverSpaces.some((row) => row.name.trim().toLowerCase() === location.toLowerCase());
    setSelectedSpace(exists ? location : 'Unsorted');
    setExpandedItemId(item.item_id);
  }, [allItems, initSettled, props.itemFilter, serverSpaces, spacesLoadError]);

  useEffect(() => {
    if (!expandedItemId || expandedItemId !== props.itemFilter) return;
    const frame = requestAnimationFrame(() => document.getElementById(`inventory-item-${expandedItemId}`)?.scrollIntoView({ block: 'center' }));
    return () => cancelAnimationFrame(frame);
  }, [expandedItemId, props.itemFilter, selectedSpace]);

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

  // Refetch spaces and items when the tab regains focus (cross-device sync)
  useEffect(() => {
    const onFocus = () => void refreshAll();
    const onVisibility = () => { if (!document.hidden) void refreshAll(); };
    window.addEventListener('focus', onFocus);
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      window.removeEventListener('focus', onFocus);
      document.removeEventListener('visibilitychange', onVisibility);
    };
    // refreshAll reads token via refreshToken() internally — no dependency needed
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
    const targetSpace = spaceOverride ?? selectedSpace;
    if (!targetSpace) { setError('Choose a Space before uploading a photo.'); return; }
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
  async function refreshAll(t?: string) {
    const tok = t || token || (await refreshToken());
    if (!tok) return;
    const [itemsResult, spacesResult] = await Promise.allSettled([
      searchItems({ token: tok, query: '' }),
      getSpaces({ token: tok }),
    ]);
    if (itemsResult.status === 'fulfilled') {
      setAllItems(itemsResult.value?.items ?? []);
      setItems(itemsResult.value?.items ?? []);
    }
    if (spacesResult.status === 'fulfilled') {
      setServerSpaces(spacesResult.value);
      setSpacesLoadError(null);
    } else {
      const reason = spacesResult.reason;
      console.error('[refreshAll] getSpaces failed:', reason instanceof Error ? reason.message : reason);
      setSpacesLoadError("Couldn't load your spaces — showing spaces from your items");
    }
  }

  async function retryLoadSpaces() {
    const t = token || (await refreshToken());
    if (!t) return;
    await refreshAll(t);
  }

  function openSpace(spaceName: string) {
    setSelectedSpace(spaceName);
    setCategoryFilter('');
    setQuery('');
  }

  async function onCreateSpace() {
    const normalized = normalizeLocation(newSpaceName);
    if (!normalized || normalized === 'Unsorted') return;
    setCreateSpaceLoading(true);
    setCreateSpaceError(null);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const res = await createSpace({ token: t, name: normalized });
      setSelectedSpace(res.space.name);
      setDraft((d) => ({ ...d, location: res.space.name }));
      setNewSpaceName('');
      setCreateSpaceOpen(false);
      await refreshAll(t);
    } catch (err: unknown) {
      const e = err as any;
      if (e?.status === 403) {
        setCreateSpaceError("This Space could not be created right now. Your existing inventory was not changed.");
      } else {
        setCreateSpaceError(errorMessage(err, 'Failed to create space'));
      }
    } finally {
      setCreateSpaceLoading(false);
    }
  }

  async function onJoinSpace() {
    const shareCode = joinCode.trim().toUpperCase();
    if (shareCode.length !== 6) {
      setJoinSpaceError('Enter the 6-character code from the space owner.');
      return;
    }

    setJoinSpaceLoading(true);
    setJoinSpaceError(null);
    try {
      const t = token || (await refreshToken());
      if (!t) throw new Error('Please sign in again to join this space.');
      await joinShare({ token: t, share_code: shareCode });
      const joined = await getJoinedShares({ token: t });
      setJoinedShares(joined.shares ?? []);
      setJoinCode('');
      setJoinSpaceOpen(false);
    } catch (err: unknown) {
      setJoinSpaceError(errorMessage(err, 'Unable to join this space. Check the code and try again.'));
    } finally {
      setJoinSpaceLoading(false);
    }
  }

  async function onRenameSpace(space: Space) {
    const name = (await promptValue({ title: 'Rename Space', label: 'Space name', initialValue: space.name, confirmLabel: 'Rename' }))?.trim();
    if (!name) return;
    const normalized = normalizeLocation(name);
    if (!normalized || normalized === space.name) return;
    setLoading(true);
    setError(null);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      await renameSpace({ token: t, spaceId: space.id, name: normalized });
      setSelectedSpace((curr) => (curr === space.name ? normalized : curr));
      await refreshAll(t);
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to rename space'));
    } finally {
      setLoading(false);
    }
  }

  async function onDeleteSpace(space: Space) {
    if (!await confirmAction({ title: `Delete “${space.name}”?`, message: "Items will remain in Inventory but will no longer be linked to this Space.", confirmLabel: 'Delete Space', danger: true })) return;
    setLoading(true);
    setError(null);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const matchingShares = myShares.filter(
        (share) => normalizeLocation(share.share_name).toLowerCase() === normalizeLocation(space.name).toLowerCase(),
      );
      await Promise.all(matchingShares.map((share) => deleteShare({ token: t, share_id: share.share_id ?? share.id })));
      await deleteSpace({ token: t, spaceId: space.id });
      setMyShares((current) => current.filter((share) => !matchingShares.includes(share)));
      if (selectedSpace === space.name) {
        setSelectedSpace(null);
        setCategoryFilter('');
        setQuery('');
      }
      await refreshAll(t);
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
    if (!await confirmAction({ title: 'Delete this item?', message: 'This action cannot be undone.', confirmLabel: 'Delete', danger: true })) return
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
  // When GET /spaces succeeded, render only canonical server spaces.
  // Items in deleted spaces are routed to 'Unsorted' so they remain reachable.
  const spaces = useMemo(
    () => resolveDisplaySpaces(serverSpaces, allItems, !!spacesLoadError),
    [serverSpaces, allItems, spacesLoadError],
  );

  const itemsBySpace = useMemo(() => {
    // When server spaces are available, remap items from deleted/missing spaces to 'Unsorted'
    const serverNames = spacesLoadError
      ? null
      : new Set(serverSpaces.map((s) => s.name.trim().toLowerCase()));
    return (allItems ?? []).reduce<Record<string, InventoryItem[]>>((acc, item) => {
      const locNorm = normalizeLocation(item.location);
      const bucket =
        serverNames && locNorm !== 'Unsorted' && !serverNames.has(locNorm.toLowerCase())
          ? 'Unsorted'
          : locNorm;
      if (!acc[bucket]) acc[bucket] = [];
      acc[bucket].push(item);
      return acc;
    }, {});
  }, [allItems, serverSpaces, spacesLoadError]);

  const visibleItems = useMemo(() => {
    try {
      const serverNames = spacesLoadError
        ? null
        : new Set(serverSpaces.map((s) => s.name.trim().toLowerCase()));
      const base = selectedSpace
        ? (items ?? []).filter((item) => {
            const locNorm = normalizeLocation(item.location);
            if (selectedSpace === 'Unsorted') {
              // Include items with no space AND items whose space was deleted
              return locNorm === 'Unsorted' ||
                (serverNames !== null && !serverNames.has(locNorm.toLowerCase()));
            }
            return locNorm === selectedSpace;
          })
        : (items ?? []);
      if (!categoryFilter) return base;
      return base.filter((item) => (item.category ?? '').toLowerCase() === categoryFilter.toLowerCase());
    } catch {
      return [];
    }
  }, [items, selectedSpace, categoryFilter, serverSpaces, spacesLoadError]);

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
      { field: 'name', label: 'Part # / Item' },
    ]
    const hasField = (field: string) =>
      spaceItems.some(i => {
        const val = (i as unknown as Record<string, unknown>)[field]
        return val !== null && val !== undefined && String(val).trim() !== ''
      })
    // Labels use the same vocabulary as the mobile item detail sheet, so the two
    // apps never call the same field different things. Abbreviations are fine
    // (Part # / Qty); different words are not — "Vendor" for brand was.
    if (hasField('part_number')) cols.push({ field: 'part_number', label: 'Description' })
    if (hasField('subcategory')) cols.push({ field: 'subcategory', label: 'Subcategory' })
    if (hasField('brand')) cols.push({ field: 'brand', label: 'Brand' })
    if (hasField('purchase_source')) cols.push({ field: 'purchase_source', label: 'Where to buy' })
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

  function exportCsv(rows: InventoryItem[], filename: string) {
    const fields: Array<keyof InventoryItem> = ['name', 'category', 'subcategory', 'quantity', 'location', 'brand', 'part_number', 'barcode', 'purchase_source', 'notes', 'created_at'];
    const escape = (value: unknown) => `"${String(value ?? '').replaceAll('"', '""')}"`;
    const csv = [fields.join(','), ...rows.map((row) => fields.map((field) => escape(row[field])).join(','))].join('\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url; link.download = `${filename.replace(/[^a-z0-9-_]+/gi, '-').toLowerCase() || 'findez-inventory'}.csv`; link.click();
    URL.revokeObjectURL(url);
  }

  async function checkOut(item: InventoryItem) {
    const borrower = await promptValue({ title: `Check out “${itemDisplayName(item)}”`, label: 'Checked out to', placeholder: 'Person or team', confirmLabel: 'Continue' });
    if (!borrower?.trim()) return;
    const due = await promptValue({ title: 'When is it due back?', message: 'Choose a date, or cancel to leave the due date blank.', label: 'Due date', inputType: 'date', confirmLabel: 'Set due date' });
    const t = token || (await refreshToken());
    if (!t) return;
    try {
      await checkoutItem({ token: t, itemId: item.item_id, checkedOutBy: borrower.trim(), dueBackAt: due?.trim() ? new Date(`${due.trim()}T23:59:59`).toISOString() : undefined });
      setSuccess(`${item.name} checked out to ${borrower.trim()}.`);
    } catch (reason) { setError(errorMessage(reason, 'The item could not be checked out.')); }
  }

  async function showCheckoutHistory(item: InventoryItem) {
    const t = token || (await refreshToken());
    if (!t) return;
    setHistoryItem(item); setCheckoutHistory([]); setHistoryLoading(true);
    try { const result = await getItemCheckouts({ token: t, itemId: item.item_id }); setCheckoutHistory(result.checkouts ?? []); }
    catch (reason) { setError(errorMessage(reason, 'Could not load item history.')); }
    finally { setHistoryLoading(false); }
  }

  const sharedTableColumns = useMemo(() => {
    const items = sharedSpaceItems ?? []
    const cols: { field: string; label: string }[] = [{ field: 'name', label: 'Part # / Item' }]
    const hasField = (f: string) => items.some((i: any) => {
      const v = i[f]; return v !== null && v !== undefined && String(v).trim() !== ''
    })
    // Labels use the same vocabulary as the mobile item detail sheet, so the two
    // apps never call the same field different things. Abbreviations are fine
    // (Part # / Qty); different words are not — "Vendor" for brand was.
    if (hasField('part_number')) cols.push({ field: 'part_number', label: 'Description' })
    if (hasField('subcategory')) cols.push({ field: 'subcategory', label: 'Subcategory' })
    if (hasField('brand')) cols.push({ field: 'brand', label: 'Brand' })
    if (hasField('purchase_source')) cols.push({ field: 'purchase_source', label: 'Where to buy' })
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
    <div className="inventory-workspace">

      {/* Header */}
      <div className="inventory-page-header">
        <div>
          <h1>{selectedSpace ? selectedSpace : 'Inventory'}</h1>
          {selectedSpace && <p>{(itemsBySpace[selectedSpace] ?? []).length} items</p>}
        </div>
        {!selectedSpace && (
          <div className="product-actions">
            <button
              type="button"
              onClick={() => { setJoinSpaceError(null); setJoinSpaceOpen(true); }}
              className="product-button"
            >
              Join
            </button>
            <button
              type="button"
              onClick={() => setCreateSpaceOpen(true)}
              className="product-button primary"
            >
              + New Space
            </button>
          </div>
        )}
      </div>

      {/* Global search bar */}
      {!selectedSpace && (
        <div className="inventory-search-control">
          <Search size={15} />
          <input
            placeholder="Search inventory"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="spaces-search"
          />
        </div>
      )}

      {error ? <p style={{ fontSize: 13, color: 'var(--danger-ink)', marginBottom: 12 }}>{error}</p> : null}
      {success ? <p role="status" style={{ fontSize: 13, color: 'var(--success-ink)', marginBottom: 12 }}>{success}</p> : null}

      {!selectedSpace && !searchActive && initSettled && !loading && (
        <InventoryStats items={allItems} spaces={spaces} />
      )}

      {/* ── Search results ──────────────────────────────────────────────── */}
      {searchActive ? (
        <div>
          <p style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>{visibleItems.length} matching items</p>
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 1fr', gap: 12, padding: '0 0 10px', borderBottom: '1px solid var(--light-line)' }}>
            {['Part # / Item', 'Category', 'Qty', 'Location'].map((h) => (
              <div key={h} style={thStyle}>{h}</div>
            ))}
          </div>
          {(visibleItems ?? []).map((item) => (
            <div key={item.item_id} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 1fr', gap: 12, padding: '12px 0', borderBottom: '1px solid rgba(58,18,48,0.04)', alignItems: 'center' }}>
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 590, color: 'var(--text-primary)', letterSpacing: '-0.015em', fontFamily: item.part_number?.trim() ? "'SF Mono', ui-monospace, monospace" : FONT }}>{itemDisplayName(item)}</div>
                {itemDisplayDescription(item) && <div style={{ marginTop: 3, fontSize: 11, color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{itemDisplayDescription(item)}</div>}
              </div>
              <div><span style={{ fontSize: 11, padding: '2px 8px', background: 'var(--light-raised)', borderRadius: 99, color: 'var(--text-secondary)' }}>{item.category}</span></div>
              <div style={{ fontSize: 13, fontWeight: 590, color: item.quantity <= 1 ? 'var(--warning-ink)' : 'var(--text-primary)' }}>{item.quantity}</div>
              <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{normalizeLocation(item.location)}</div>
            </div>
          ))}
          {visibleItems.length === 0 ? (
            <div style={{ fontSize: 13, color: 'var(--text-muted)', textAlign: 'center', padding: '40px 0' }}>No matching items found.</div>
          ) : null}
        </div>

      /* ── Space detail view ──────────────────────────────────────────── */
      ) : viewingSharedSpace ? (
        <div>
          <button
            onClick={() => { setViewingSharedSpace(null); setSharedSpaceItems([]); setSharedSpaceSearch(''); setExpandedSharedItemId(null) }}
            style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'transparent', border: 'none', cursor: 'pointer', padding: 0, marginBottom: 20, fontFamily: FONT, letterSpacing: '-0.01em' }}>
            ← My Spaces
          </button>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 4 }}>
            <h1 style={{ fontSize: 20, fontWeight: 700, letterSpacing: '-0.03em', color: 'var(--text-primary)', margin: 0 }}>
              {viewingSharedSpace.spaceName}
            </h1>
            <span style={{ fontSize: 10, padding: '3px 10px', borderRadius: 99, background: viewingSharedSpace.isOwned ? 'rgba(185,138,114,0.13)' : 'rgba(217,82,122,0.11)', border: `1px solid ${viewingSharedSpace.isOwned ? 'rgba(185,138,114,0.26)' : 'rgba(217,82,122,0.25)'}`, color: viewingSharedSpace.isOwned ? 'var(--light-muted)' : 'var(--copper)' }}>
              {viewingSharedSpace.isOwned ? 'shared by me' : 'joined space'}
            </span>
          </div>

          <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginBottom: 20, display: 'flex', gap: 16, alignItems: 'center' }}>
            <span>{sharedSpaceLoading ? '…' : `${sharedSpaceItems.length} items`}</span>
            <span style={{ color: 'var(--text-muted)' }}>·</span>
            <span>{viewingSharedSpace.permission === 'edit' ? 'Can edit' : 'View only'}</span>
            <span style={{ color: 'var(--text-muted)' }}>·</span>
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
              <span style={{ fontSize: 11, color: 'var(--text-muted)', alignSelf: 'center', marginLeft: 4 }}>View only — contact the owner to make changes</span>
            )}
          </div>

          {/* Search bar */}
          <input
            placeholder="Search items…"
            value={sharedSpaceSearch}
            onChange={e => setSharedSpaceSearch(e.target.value)}
            style={{ width: '100%', background: 'rgba(58,18,48,0.04)', border: '1px solid rgba(58,18,48,0.10)', borderRadius: 8, padding: '9px 14px', fontSize: 13, color: 'var(--text-primary)', outline: 'none', fontFamily: FONT, letterSpacing: '-0.01em', marginBottom: 12, boxSizing: 'border-box' as const }}
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
                  style={{ background: sharedCategoryFilter === '' ? 'var(--light-raised)' : 'rgba(58,18,48,0.03)', color: sharedCategoryFilter === '' ? 'var(--text-primary)' : 'var(--text-secondary)', border: sharedCategoryFilter === '' ? '1px solid var(--light-line)' : '1px solid rgba(58,18,48,0.07)', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}>
                  All
                </button>
                {sharedCategories.map(cat => (
                  <button
                    key={cat}
                    onClick={() => setSharedCategoryFilter(cat)}
                    style={{ background: sharedCategoryFilter === cat ? 'var(--light-raised)' : 'rgba(58,18,48,0.03)', color: sharedCategoryFilter === cat ? 'var(--text-primary)' : 'var(--text-secondary)', border: sharedCategoryFilter === cat ? '1px solid var(--light-line)' : '1px solid rgba(58,18,48,0.07)', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}>
                    {cat}
                  </button>
                ))}
              </div>

              {/* Dynamic header row */}
              <div style={{ display: 'grid', gridTemplateColumns: sharedGridTemplate, gap: 12, paddingBottom: 10, borderBottom: '1px solid rgba(58,18,48,0.08)' }}>
                {sharedTableColumns.map(col => (
                  <div key={col.field} style={{ fontSize: 10, fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)' }}>{col.label}</div>
                ))}
              </div>

              {/* Item rows */}
              {filteredSharedItems.map((item: any) => (
                <React.Fragment key={item.item_id}>
                  <div className="inventory-row" style={{ display: 'grid', gridTemplateColumns: sharedGridTemplate, gap: 12, padding: '11px 12px', borderBottom: '1px solid rgba(58,18,48,0.04)', alignItems: 'center' }}>
                    {sharedTableColumns.map(col => {
                      if (col.field === 'name') return (
                        <div
                          key="name"
                          onClick={() => setExpandedSharedItemId(expandedSharedItemId === item.item_id ? null : item.item_id)}
                          style={{ fontSize: 13, fontWeight: 510, color: 'var(--text-primary)', letterSpacing: '-0.015em', cursor: 'pointer', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}
                          title="Click to see all details"
                        >
                          {itemDisplayName(item)}
                        </div>
                      )
                      if (col.field === 'actions') return (
                        <div key="actions" style={{ display: 'flex', justifyContent: 'flex-end' }}>
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <button type="button" aria-label={`Actions for ${item.name}`} style={itemActionsTriggerStyle}>
                                <MoreHorizontal size={17} aria-hidden="true" />
                              </button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem onSelect={() => { openEdit(item as InventoryItem); setExpandedSharedItemId(null); }}>Edit item</DropdownMenuItem>
                              <DropdownMenuItem onSelect={() => void handleUpdateItem(item.item_id, { quantity: item.quantity + 1 })}>Add one</DropdownMenuItem>
                              <DropdownMenuItem disabled={item.quantity === 0} onSelect={() => void handleUpdateItem(item.item_id, { quantity: Math.max(0, item.quantity - 1) })}>Remove one</DropdownMenuItem>
                              <DropdownMenuItem disabled={item.quantity === 0} onSelect={() => void handleUpdateItem(item.item_id, { quantity: 0 })}>Mark out of stock</DropdownMenuItem>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem variant="destructive" onSelect={() => void handleDeleteSharedItem(item.item_id)}>Delete item</DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </div>
                      )
                      if (col.field === 'quantity') return (
                        <div key="quantity" style={{ fontSize: 13, fontWeight: 590, color: item.quantity <= 1 ? 'var(--warning-ink)' : 'var(--text-primary)' }}>
                          {item.quantity}
                        </div>
                      )
                      if (col.field === 'category') return (
                        <div key="category">
                          <span style={{ fontSize: 11, padding: '2px 8px', background: 'rgba(58,18,48,0.06)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 99, color: 'var(--text-secondary)' }}>
                            {item.category}
                          </span>
                        </div>
                      )
                      if (col.field === 'part_number') return (
                        <div key="part_number" style={{ fontSize: 11, color: 'var(--text-secondary)', fontFamily: "'SF Mono', ui-monospace, monospace", overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {itemDisplayDescription(item) ?? '—'}
                        </div>
                      )
                      if (col.field === 'notes') return (
                        <div key="notes" style={{ fontSize: 11, color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }} title={item.notes ?? ''}>
                          {item.notes ?? '—'}
                        </div>
                      )
                      const value = item[col.field]
                      return (
                        <div key={col.field} style={{ fontSize: 12, color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {value != null ? String(value) : '—'}
                        </div>
                      )
                    })}
                  </div>

                  {/* Expanded detail panel */}
                  {expandedSharedItemId === item.item_id && (
                    <div style={{ background: 'rgba(58,18,48,0.02)', border: '1px solid rgba(58,18,48,0.07)', borderRadius: 10, padding: '16px 20px', display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px 24px', marginBottom: 4 }}>
                      <div style={{ gridColumn: '1 / -1', fontSize: 13, fontWeight: 590, color: 'var(--text-primary)', letterSpacing: '-0.015em', lineHeight: 1.4, marginBottom: 4 }}>
                        {itemDisplayName(item)}
                      </div>
                      {itemDetailFields(item)
                        .filter(f => f.value)
                        .map(f => (
                          <div key={f.label}>
                            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)', marginBottom: 3 }}>
                              {f.label}
                            </div>
                            <div style={{ fontSize: 12, color: 'var(--text-primary)', lineHeight: 1.5, wordBreak: 'break-word' as const }}>
                              {f.value}
                            </div>
                          </div>
                        ))
                      }
                      <div style={{ gridColumn: '1 / -1', marginTop: 8, paddingTop: 12, borderTop: '1px solid rgba(58,18,48,0.06)', display: 'flex', gap: 8 }}>
                        {viewingSharedSpace?.permission === 'edit' && (
                          <button
                            onClick={() => { openEdit(item as InventoryItem); setExpandedSharedItemId(null) }}
                            style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'rgba(58,18,48,0.05)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 6, padding: '5px 14px', cursor: 'pointer', fontFamily: 'inherit' }}>
                            Edit item
                          </button>
                        )}
                        <button onClick={() => void checkOut(item as InventoryItem)} style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'rgba(58,18,48,0.05)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 6, padding: '5px 14px', cursor: 'pointer', fontFamily: 'inherit' }}>Check out</button>
                        <button onClick={() => void showCheckoutHistory(item as InventoryItem)} style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'rgba(58,18,48,0.05)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 6, padding: '5px 14px', cursor: 'pointer', fontFamily: 'inherit' }}>History</button>
                        <button
                          onClick={() => setExpandedSharedItemId(null)}
                          style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: 'inherit' }}>
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
            <div style={{ textAlign: 'center', padding: '48px 24px', background: 'rgba(58,18,48,0.02)', borderRadius: 12, border: '1px dashed rgba(58,18,48,0.08)' }}>
              <div style={{ fontSize: 13, fontWeight: 590, color: 'var(--text-primary)', marginBottom: 6 }}>No items in this space yet</div>
              <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
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
            style={{ fontSize: 13, color: 'var(--text-secondary)', background: 'transparent', border: 'none', cursor: 'pointer', letterSpacing: '-0.01em', marginBottom: 20, padding: 0, fontFamily: FONT }}
          >
            ← My Spaces
          </button>

          <div style={{ marginBottom: 4 }}>
            <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: 0 }}>{(itemsBySpace[selectedSpace] ?? []).length} items</p>
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
            <button type="button" onClick={() => openSpreadsheet(selectedSpace ?? '')} style={toolbarBtnStyle}>Import Spreadsheet</button>
            <button type="button" onClick={() => { setScanOpen(true); }} style={toolbarBtnStyle}>Scan Barcode</button>
            <button type="button" onClick={() => { setDraft((d) => ({ ...d, location: selectedSpace })); setCreateOpen(true); }} style={toolbarBtnStyle}>+ Add Item</button>
            <button type="button" onClick={() => { openShare(selectedSpace); }} style={toolbarBtnStyle}>Share Space</button>
            <button type="button" onClick={() => exportCsv(visibleItems, selectedSpace || 'findez-inventory')} style={toolbarBtnStyle}><Download size={14} />Export CSV</button>
          </div>

          {/* Space search + category pills */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginBottom: 12 }}>
            <input
              placeholder="Search items…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              style={{ flex: 1, minWidth: 200, background: 'var(--light-panel)', border: '1px solid var(--light-line)', borderRadius: 8, padding: '9px 14px', color: 'var(--text-primary)', fontSize: 13, outline: 'none', fontFamily: FONT }}
            />
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 18 }}>
            <button
              type="button"
              onClick={() => setCategoryFilter('')}
              style={{ background: categoryFilter === '' ? 'var(--light-raised)' : 'var(--light-panel)', color: categoryFilter === '' ? 'var(--text-primary)' : 'var(--text-secondary)', border: categoryFilter === '' ? '1px solid var(--light-line)' : '1px solid var(--light-line)', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}
            >All</button>
            {(categories ?? []).map((cat) => (
              <button
                key={cat}
                type="button"
                onClick={() => setCategoryFilter(cat)}
                style={{ background: categoryFilter === cat ? 'var(--light-raised)' : 'var(--light-panel)', color: categoryFilter === cat ? 'var(--text-primary)' : 'var(--text-secondary)', border: categoryFilter === cat ? '1px solid var(--light-line)' : '1px solid var(--light-line)', borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}
              >{cat}</button>
            ))}
          </div>

          {/* Items table */}
          {visibleItems.length === 0 && !loading ? (
            <div style={{ textAlign: 'center', padding: '48px 24px', background: 'var(--light-panel)', borderRadius: 12, border: '1px dashed var(--light-line-strong)' }}>
              <p style={{ fontSize: 13, color: 'var(--text-secondary)', margin: '0 0 4px' }}>No items in this space yet</p>
              <p style={{ fontSize: 12, color: 'var(--text-muted)', margin: 0 }}>Use the toolbar above to add items</p>
            </div>
          ) : (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: gridTemplate, gap: 12, paddingBottom: 10, borderBottom: '1px solid rgba(58,18,48,0.08)' }}>
                {tableColumns.map(col => (
                  <div key={col.field} style={{ fontSize: 10, fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)' }}>
                    {col.label}
                  </div>
                ))}
              </div>
              {(visibleItems ?? []).map((item) => (
                <React.Fragment key={item.item_id}>
                  <div id={`inventory-item-${item.item_id}`} className="inventory-row" style={{ display: 'grid', gridTemplateColumns: gridTemplate, gap: 12, padding: '11px 12px', borderBottom: '1px solid rgba(58,18,48,0.04)', alignItems: 'center' }}>
                    {tableColumns.map(col => {
                      if (col.field === 'actions') return (
                        <div key="actions" style={{ display: 'flex', justifyContent: 'flex-end' }}>
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <button type="button" aria-label={`Actions for ${item.name}`} disabled={loading} style={itemActionsTriggerStyle}>
                                <MoreHorizontal size={17} aria-hidden="true" />
                              </button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem onSelect={() => openEdit(item)}>Edit item</DropdownMenuItem>
                              <DropdownMenuItem onSelect={() => router.push(`/labels?item=${encodeURIComponent(item.item_id)}`)}>Print part label</DropdownMenuItem>
                              <DropdownMenuItem onSelect={() => void onUpdateItem(item.item_id, { quantity: item.quantity + 1 })}>Add one</DropdownMenuItem>
                              <DropdownMenuItem disabled={item.quantity === 0} onSelect={() => void onUpdateItem(item.item_id, { quantity: Math.max(0, item.quantity - 1) })}>Remove one</DropdownMenuItem>
                              <DropdownMenuItem disabled={item.quantity === 0} onSelect={() => void onUpdateItem(item.item_id, { quantity: 0 })}>Mark out of stock</DropdownMenuItem>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem variant="destructive" onSelect={() => void onDelete(item.item_id)}>Delete item</DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </div>
                      )
                      if (col.field === 'name') return (
                        <div
                          key="name"
                          onClick={() => setExpandedItemId(expandedItemId === item.item_id ? null : item.item_id)}
                          style={{ fontSize: 13, fontWeight: 510, color: 'var(--text-primary)', letterSpacing: '-0.015em', cursor: 'pointer', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}
                          title="Click to expand"
                        >
                          {itemDisplayName(item)}
                        </div>
                      )
                      if (col.field === 'quantity') return (
                        <div key="quantity" style={{ fontSize: 13, fontWeight: 590, color: item.quantity <= 1 ? 'var(--warning-ink)' : 'var(--text-primary)' }}>
                          {item.quantity}
                        </div>
                      )
                      if (col.field === 'category') return (
                        <div key="category">
                          <span style={{ fontSize: 11, padding: '2px 8px', background: 'rgba(58,18,48,0.06)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 99, color: 'var(--text-secondary)' }}>
                            {item.category}
                          </span>
                        </div>
                      )
                      if (col.field === 'part_number') return (
                        <div key="part_number" style={{ fontSize: 11, color: 'var(--text-secondary)', fontFamily: "'SF Mono', ui-monospace, monospace", overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {itemDisplayDescription(item) ?? '—'}
                        </div>
                      )
                      if (col.field === 'notes') return (
                        <div key="notes" style={{ fontSize: 11, color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }} title={item.notes ?? ''}>
                          {item.notes ?? '—'}
                        </div>
                      )
                      const value = (item as unknown as Record<string, unknown>)[col.field]
                      return (
                        <div key={col.field} style={{ fontSize: 12, color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                          {value != null ? String(value) : '—'}
                        </div>
                      )
                    })}
                  </div>
                  {expandedItemId === item.item_id && (
                    <div style={{
                      background: 'rgba(58,18,48,0.02)',
                      border: '1px solid rgba(58,18,48,0.07)',
                      borderRadius: 10,
                      padding: '16px 20px',
                      display: 'grid',
                      gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
                      gap: '12px 24px',
                      marginBottom: 4,
                    }}>
                      <div style={{ gridColumn: '1 / -1', fontSize: 13, fontWeight: 590, color: 'var(--text-primary)', letterSpacing: '-0.015em', lineHeight: 1.4, marginBottom: 4 }}>
                        {itemDisplayName(item)}
                      </div>
                      {itemDetailFields(item)
                        .filter(f => f.value)
                        .map(f => (
                          <div key={f.label}>
                            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)', marginBottom: 3 }}>
                              {f.label}
                            </div>
                            <div style={{ fontSize: 12, color: 'var(--text-primary)', lineHeight: 1.5, wordBreak: 'break-word' as const }}>
                              {f.value}
                            </div>
                          </div>
                        ))
                      }
                      <div style={{ gridColumn: '1 / -1', marginTop: 8, paddingTop: 12, borderTop: '1px solid rgba(58,18,48,0.06)', display: 'flex', gap: 8 }}>
                        <button onClick={() => void checkOut(item)} style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'rgba(58,18,48,0.05)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 6, padding: '5px 14px', cursor: 'pointer', fontFamily: 'inherit' }}>Check out</button>
                        <button onClick={() => void showCheckoutHistory(item)} style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'rgba(58,18,48,0.05)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 6, padding: '5px 14px', cursor: 'pointer', fontFamily: 'inherit' }}>History</button>
                        <button
                          onClick={() => setExpandedItemId(null)}
                          style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: 'inherit' }}>
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
      ) : !initSettled || loading ? (
        <div className="inventory-space-grid">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="skeleton" style={{ height: 110, borderRadius: 12 }} />
          ))}
        </div>
      ) : (
        <>
        {spacesLoadError && (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(255,159,10,0.08)', border: '1px solid rgba(255,159,10,0.20)', borderRadius: 10, padding: '10px 16px', marginBottom: 12, marginTop: 8 }}>
            <span style={{ fontSize: 13, color: 'var(--warning-ink)' }}>{spacesLoadError}</span>
            <button
              type="button"
              onClick={() => void retryLoadSpaces()}
              style={{ fontSize: 12, color: 'var(--warning-ink)', background: 'rgba(201,162,39,0.14)', border: '1px solid rgba(201,162,39,0.3)', borderRadius: 7, padding: '4px 12px', cursor: 'pointer', flexShrink: 0, marginLeft: 12 }}
            >
              Retry
            </button>
          </div>
        )}
        <div className="inventory-section-heading"><div><h2>Spaces</h2></div><span>{spaces.length}</span></div>
        <div className="inventory-space-list">
          {(spaces ?? []).map((space) => {
            const spaceObj = serverSpaces.find((s) => s.name === space) ?? null;
            const itemsInSpace = itemsBySpace[space] ?? [];
            const lowStock = itemsInSpace.filter((item) => item.quantity <= 1).length;
            return (
              <div
                key={space}
                className="inventory-space-card"
                onClick={() => openSpace(space)}
              >
                <span className="space-card-icon"><Boxes size={17} /></span>
                <div className="space-card-copy">
                  <strong>{space}</strong>
                  <span>{itemsInSpace.length} items{lowStock > 0 ? ` · ${lowStock} low stock` : ''}</span>
                </div>
                <div className="space-card-actions">
                  {/* Upload image */}
                  <label
                    style={{ width: 24, height: 24, borderRadius: '50%', background: 'transparent', border: 'none', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'color 120ms', flexShrink: 0 }}
                    onClick={(e) => e.stopPropagation()}
                    onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = 'var(--text-secondary)'; }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = 'var(--text-muted)'; }}
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
                    style={{ width: 24, height: 24, borderRadius: '50%', background: 'transparent', border: 'none', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'color 120ms', flexShrink: 0 }}
                    onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = 'var(--text-secondary)'; }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = 'var(--text-muted)'; }}
                  >
                    <Share2 size={14} />
                  </button>
                  {/* Rename/Delete only for canonical spaces that have a server record */}
                  {spaceObj && (
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <button
                          type="button"
                          aria-label={`Actions for ${space}`}
                          onClick={(e) => e.stopPropagation()}
                          style={{ width: 24, height: 24, borderRadius: '50%', background: 'transparent', border: 'none', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'color 120ms', flexShrink: 0 }}
                          onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = 'var(--text-secondary)'; }}
                          onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = 'var(--text-muted)'; }}
                        >
                          <MoreHorizontal size={14} aria-hidden="true" />
                        </button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end" side="top">
                        <DropdownMenuItem onSelect={() => void onRenameSpace(spaceObj)}>Rename space</DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem variant="destructive" onSelect={() => void onDeleteSpace(spaceObj)}>Delete space</DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  )}
                </div>
                <ChevronRight className="space-card-chevron" size={16} />
              </div>
            );
          })}
        </div>

        {activeOwnedShares.length > 0 && (
          <div style={{ marginTop: 32 }}>
            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)', marginBottom: 12 }}>
              Shared by me
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
              {activeOwnedShares.map(share => (
                <Link
                  key={share.share_id ?? share.id}
                  href={`/sharing/${share.share_id ?? share.id}`}
                  style={{
                    display: 'block',
                    textDecoration: 'none',
                    background: 'rgba(58,18,48,0.02)',
                    border: '1px solid rgba(58,18,48,0.07)',
                    borderRadius: 12,
                    padding: '18px 20px',
                    transition: 'all 0.16s',
                    position: 'relative',
                  }}
                  onMouseEnter={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(58,18,48,0.14)'; (e.currentTarget as HTMLElement).style.transform = 'translateY(-1px)'; }}
                  onMouseLeave={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(58,18,48,0.07)'; (e.currentTarget as HTMLElement).style.transform = ''; }}
                >
                  <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 8 }}>
                    <div style={{ fontSize: 14, fontWeight: 590, color: 'var(--text-primary)', letterSpacing: '-0.02em' }}>
                      {share.share_name}
                    </div>
                    <span style={{ fontSize: 10, padding: '2px 8px', borderRadius: 99, background: 'rgba(50,215,75,0.10)', border: '1px solid rgba(50,215,75,0.20)', color: 'var(--success-ink)', flexShrink: 0, marginLeft: 8 }}>
                      shared
                    </span>
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--text-secondary)', letterSpacing: '-0.005em' }}>
                    Code: <span style={{ fontFamily: "'SF Mono', ui-monospace, monospace", letterSpacing: '0.06em', color: 'var(--text-secondary)' }}>{share.share_code ?? share.code}</span>
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--text-secondary)', marginTop: 3 }}>
                    {share.permission === 'edit' ? 'Can edit' : 'View only'}
                  </div>
                </Link>
              ))}
            </div>
          </div>
        )}

        {joinedShares.length > 0 && (
          <div style={{ marginTop: 24 }}>
            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)', marginBottom: 12 }}>
              Joined spaces
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
              {joinedShares.map(share => (
                <Link
                  key={share.share_id ?? share.id ?? share.member_id}
                  href={`/sharing/${share.share_id ?? share.id}`}
                  style={{
                    display: 'block',
                    textDecoration: 'none',
                    background: 'rgba(58,18,48,0.02)',
                    border: '1px solid rgba(58,18,48,0.07)',
                    borderRadius: 12,
                    padding: '18px 20px',
                    transition: 'all 0.16s',
                  }}
                  onMouseEnter={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(58,18,48,0.14)'; (e.currentTarget as HTMLElement).style.transform = 'translateY(-1px)'; }}
                  onMouseLeave={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(58,18,48,0.07)'; (e.currentTarget as HTMLElement).style.transform = ''; }}
                >
                  <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 8 }}>
                    <div style={{ fontSize: 14, fontWeight: 590, color: 'var(--text-primary)', letterSpacing: '-0.02em' }}>
                      {share.share_name}
                    </div>
                    <span style={{ fontSize: 10, padding: '2px 8px', borderRadius: 99, background: 'rgba(217,82,122,0.11)', border: '1px solid rgba(217,82,122,0.25)', color: 'var(--copper)', flexShrink: 0, marginLeft: 8 }}>
                      joined
                    </span>
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--text-secondary)', marginTop: 2 }}>
                    {share.permission === 'edit' ? '· Can edit' : '· View only'}
                  </div>
                  {share.owner && (
                    <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>
                      by {share.owner}
                    </div>
                  )}
                </Link>
              ))}
            </div>
          </div>
        )}
        </>
      )}

      {/* ── Dialogs ───────────────────────────────────────────────────────── */}

      {/* New Space */}
      <Dialog open={createSpaceOpen} onOpenChange={(open) => { setCreateSpaceOpen(open); if (!open) { setCreateSpaceError(null); setNewSpaceName(''); } }}>
        <DialogContent className="findez-form-dialog" style={{ maxWidth: 560 }}>
          <DialogHeader>
            <DialogTitle>Create a Space</DialogTitle>
            <DialogDescription>A Space is a real location—like a room, cabinet, shelf, or parts bin.</DialogDescription>
          </DialogHeader>
          <div className="findez-form-body">
            <div className="findez-form-row">
              <label htmlFor="new-space-name">Name</label>
              <div><input id="new-space-name" value={newSpaceName} onChange={(e) => setNewSpaceName(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') void onCreateSpace(); }} placeholder="Fastener cabinet" autoFocus disabled={createSpaceLoading} /><small>Use the name people already use for this location.</small></div>
            </div>
            {createSpaceError && (
              <p className="findez-form-error">{createSpaceError}</p>
            )}
            <div className="findez-form-actions">
              <button className="product-button" type="button" onClick={() => { setCreateSpaceOpen(false); setCreateSpaceError(null); setNewSpaceName(''); }} disabled={createSpaceLoading}>Cancel</button>
              <button className="product-button primary" type="button" onClick={() => void onCreateSpace()} disabled={createSpaceLoading || !newSpaceName.trim()}>{createSpaceLoading ? 'Creating…' : 'Create Space'}</button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Join a shared space */}
      <Dialog open={joinSpaceOpen} onOpenChange={(open) => { setJoinSpaceOpen(open); if (!open) { setJoinSpaceError(null); setJoinCode(''); } }}>
        <DialogContent style={{ background: 'linear-gradient(145deg, #ffffff, #fff7f1)', border: '1px solid rgba(58,18,48,0.16)', borderRadius: 16, padding: 28, maxWidth: 440, backdropFilter: 'blur(28px)' }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 17, fontWeight: 620, letterSpacing: '-0.025em', color: 'var(--text-primary)' }}>Join a space</DialogTitle>
          </DialogHeader>
          <div style={{ marginTop: 16 }}>
            <p style={{ fontSize: 13, color: 'var(--text-secondary)', lineHeight: 1.5, margin: '0 0 16px' }}>Enter the 6-character code shared by the space owner.</p>
            <label style={labelStyle}>Join code</label>
            <input
              value={joinCode}
              onChange={(e) => { setJoinCode(e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6)); setJoinSpaceError(null); }}
              onKeyDown={(e) => { if (e.key === 'Enter') void onJoinSpace(); }}
              placeholder="ABC123"
              autoComplete="one-time-code"
              autoFocus
              disabled={joinSpaceLoading}
              style={{ ...inputStyle, letterSpacing: '0.16em', textTransform: 'uppercase', fontFamily: "'SF Mono', ui-monospace, monospace" }}
            />
            {joinSpaceError && <p role="alert" style={{ fontSize: 12, color: 'var(--danger-ink)', marginTop: 8, lineHeight: 1.4 }}>{joinSpaceError}</p>}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 20 }}>
              <button type="button" onClick={() => setJoinSpaceOpen(false)} style={cancelBtnStyle} disabled={joinSpaceLoading}>Cancel</button>
              <button type="button" onClick={() => void onJoinSpace()} style={{ ...primaryBtnStyle, opacity: joinSpaceLoading ? 0.6 : 1, cursor: joinSpaceLoading ? 'not-allowed' : 'pointer' }} disabled={joinSpaceLoading}>{joinSpaceLoading ? 'Joining…' : 'Join space'}</button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Spreadsheet import */}
      <Dialog open={spreadsheetOpen} onOpenChange={(open) => { setSpreadsheetOpen(open); if (!open) setSpreadsheetSpace(null); }}>
        <DialogContent style={{ background: 'var(--light-panel)', border: '1px solid var(--light-line)', borderRadius: 14, padding: 28, maxWidth: 600 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: 'var(--text-primary)' }}>Import Spreadsheet</DialogTitle>
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
        <DialogContent style={{ background: 'var(--light-panel)', border: '1px solid rgba(58,18,48,0.10)', borderRadius: 16, padding: 28, maxWidth: 500, backdropFilter: 'blur(24px)' }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 17, fontWeight: 590, letterSpacing: '-0.025em', color: 'var(--text-primary)', marginBottom: 4 }}>Scan Barcode</DialogTitle>
          </DialogHeader>
          <div style={{ marginTop: 16 }}>
            <div style={{ marginBottom: 8 }}>
              <label style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)', marginBottom: 8, display: 'block' }}>Enter barcode manually</label>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  value={barcodeInput}
                  onChange={(e) => setBarcodeInput(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter' && barcodeInput.trim()) void onBarcode(barcodeInput.trim()); }}
                  placeholder="e.g. 012345678901"
                  style={{ flex: 1, background: 'rgba(58,18,48,0.04)', border: '1px solid rgba(58,18,48,0.10)', borderRadius: 8, padding: '10px 14px', fontSize: 13, color: 'var(--text-primary)', outline: 'none', fontFamily: FONT, letterSpacing: '-0.01em', transition: 'border-color 0.15s' }}
                  onFocus={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(58,18,48,0.25)'; }}
                  onBlur={e => { (e.currentTarget as HTMLElement).style.borderColor = 'rgba(58,18,48,0.10)'; }}
                />
                <button
                  type="button"
                  onClick={() => { if (barcodeInput.trim()) void onBarcode(barcodeInput.trim()); }}
                  style={{ background: 'var(--sunset-button)', color: '#2b1a21', border: 'none', borderRadius: 8, padding: '10px 18px', fontSize: 13, fontWeight: 510, cursor: 'pointer', fontFamily: FONT, whiteSpace: 'nowrap' as const, transition: 'opacity 0.15s' }}
                  onMouseEnter={e => { (e.currentTarget as HTMLElement).style.opacity = '0.85'; }}
                  onMouseLeave={e => { (e.currentTarget as HTMLElement).style.opacity = '1'; }}
                >
                  Look up
                </button>
              </div>
              {barcodeProgressStep > 0 ? (
                <div style={{ marginTop: 10, fontSize: 12, color: 'var(--text-secondary)', display: 'flex', gap: 12 }}>
                  <span style={{ color: barcodeProgressStep >= 1 ? 'var(--success-ink)' : 'var(--text-muted)' }}>✓ Scanning</span>
                  <span style={{ color: barcodeProgressStep >= 2 ? 'var(--success-ink)' : 'var(--text-muted)' }}>✓ Fetching details</span>
                </div>
              ) : null}
            </div>
            <div style={{ height: 1, background: 'rgba(58,18,48,0.06)', margin: '20px 0' }} />
            <div style={{ fontSize: 11, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: 'var(--text-secondary)', marginBottom: 12 }}>Camera scan</div>
            <BarcodeScanner
              onDetected={(code: string) => {
                void onBarcode(code);
              }}
            />
            <button
              type="button"
              onClick={() => setScanOpen(false)}
              style={{ marginTop: 16, width: '100%', background: 'rgba(58,18,48,0.04)', border: '1px solid rgba(58,18,48,0.08)', borderRadius: 8, padding: '9px', fontSize: 13, color: 'var(--text-secondary)', cursor: 'pointer', fontFamily: FONT, transition: 'background 0.15s' }}
              onMouseEnter={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(58,18,48,0.08)'; }}
              onMouseLeave={e => { (e.currentTarget as HTMLElement).style.background = 'rgba(58,18,48,0.04)'; }}
            >
              Cancel
            </button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Edit item */}
      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent style={{ background: 'var(--light-panel)', border: '1px solid var(--light-line)', borderRadius: 14, padding: 28, maxWidth: 520 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: 'var(--text-primary)' }}>Edit Item</DialogTitle>
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
        <DialogContent style={{ background: 'var(--light-panel)', border: '1px solid var(--light-line)', borderRadius: 14, padding: 28, maxWidth: 520 }}>
          <DialogHeader>
            <DialogTitle style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: 'var(--text-primary)' }}>Add Item</DialogTitle>
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
                const destination = draft.location?.trim() || selectedSpace;
                if (!destination) throw new Error('Choose a Space for this item.');
                const res = await addItem({
                  token: t,
                  item: {
                    name: draft.name.trim(),
                    category: draft.category.trim(),
                    quantity: draft.quantity ?? 1,
                    location: destination,
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
                <label style={labelStyle}>Space *</label>
                <select value={draft.location || selectedSpace || ''} onChange={(e) => setDraft((d) => ({ ...d, location: e.target.value }))} style={inputStyle} required>
                  <option value="">Choose a Space</option>
                  {serverSpaces.filter((row) => row.name !== 'Unsorted').map((row) => <option key={row.id} value={row.name}>{row.name}</option>)}
                  <option value="Unsorted">Unsorted (only if chosen)</option>
                </select>
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
            {error ? <p style={{ fontSize: 12, color: 'var(--danger-ink)', marginTop: 10 }}>{error}</p> : null}
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

      <Dialog open={Boolean(historyItem)} onOpenChange={(open) => { if (!open) setHistoryItem(null); }}>
        <DialogContent>
          <DialogHeader><DialogTitle>{historyItem?.name} history</DialogTitle></DialogHeader>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 420, overflowY: 'auto' }}>
            {historyLoading && <div style={{ color: 'var(--text-secondary)', padding: 20 }}>Loading history…</div>}
            {!historyLoading && checkoutHistory.length === 0 && <div style={{ color: 'var(--text-secondary)', padding: 20 }}>No check-out history yet.</div>}
            {checkoutHistory.map((entry, index) => <div key={String(entry.checkout_id ?? index)} style={{ padding: 12, border: '1px solid rgba(58,18,48,.08)', borderRadius: 10 }}><div style={{ color: 'var(--text-primary)', fontSize: 13 }}>{String(entry.checked_out_by ?? 'Team member')}</div><div style={{ marginTop: 4, color: 'var(--text-secondary)', fontSize: 11 }}>{entry.is_active ? 'Currently checked out' : 'Returned'} · {entry.checked_out_at ? new Date(String(entry.checked_out_at)).toLocaleString() : ''}</div></div>)}
          </div>
        </DialogContent>
      </Dialog>

    </div>
  );
}
