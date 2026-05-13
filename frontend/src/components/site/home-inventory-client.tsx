"use client";

import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, MoreHorizontal, Share2, UploadCloud, Plus } from "lucide-react";
import type { InventoryItem } from "@/lib/api";
import { addItem, deleteItem, extractFromImage, extractFromImageMulti, processBarcode, searchItems, updateItem } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
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

  const categories: string[] = useMemo(
    () => Array.from(new Set(allItems.map((item) => item.category).filter(Boolean))).sort((a, b) => a.localeCompare(b)),
    [allItems]
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-[26px] font-semibold tracking-[-0.01em] text-white font-display">My Inventory</h1>
        </div>
        <Button onClick={() => setCreateSpaceOpen(true)}>+ New Space</Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-[1fr_auto]">
        <Input
          placeholder="Search across all spaces"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <Button variant="ghost" className="border border-white/[0.08]" onClick={clearFilters}>
          Clear
        </Button>
      </div>
      {error ? <p className="text-sm text-destructive">{error}</p> : null}

      {searchActive ? (
        <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-5 backdrop-blur-md">
          <div className="mb-4 text-sm text-white/55">Showing {visibleItems.length} matching items</div>
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Category</TableHead>
                  <TableHead>Qty</TableHead>
                  <TableHead>Location</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {visibleItems.map((item) => (
                  <TableRow key={item.item_id}>
                    <TableCell className="font-medium">{item.name}</TableCell>
                    <TableCell>{item.category}</TableCell>
                    <TableCell>{item.quantity}</TableCell>
                    <TableCell>{normalizeLocation(item.location)}</TableCell>
                  </TableRow>
                ))}
                {visibleItems.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={4} className="py-10 text-center text-sm text-muted-foreground">
                      No matching items found.
                    </TableCell>
                  </TableRow>
                ) : null}
              </TableBody>
            </Table>
          </div>
        </div>
      ) : selectedSpace ? (
        <div className="space-y-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-3">
              <Button
                variant="ghost"
                className="border border-white/[0.08]"
                onClick={() => setSelectedSpace(null)}
              >
                <ArrowLeft size={16} />
              </Button>
              <div>
                <p className="text-[10px] font-medium tracking-[1.4px] uppercase text-white/30 mb-3">My Inventory</p>
                <h2 className="text-[26px] font-semibold tracking-[-0.01em] text-white font-display">{selectedSpace}</h2>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Button variant="ghost" className="border border-white/[0.08]" onClick={() => setCreateOpen(true)}>
                Upload Image → Auto-fill
              </Button>
              <Button
                variant="ghost"
                className="border border-white/[0.08]"
                onClick={() => selectedSpace && openSpreadsheet(selectedSpace)}
              >
                Import Spreadsheet
              </Button>
              <Button variant="ghost" className="border border-white/[0.08]" onClick={() => setScanOpen(true)}>
                Scan Barcode
              </Button>
              <Button variant="ghost" className="border border-white/[0.08]" onClick={() => setCreateOpen(true)}>
                + Add Item
              </Button>
              <Button
                variant="ghost"
                className="border border-white/[0.08]"
                onClick={() => selectedSpace && openShare(selectedSpace)}
              >
                Share Space
              </Button>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-[1fr_auto]">
            <Input
              placeholder="Search items in this space"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
            <select
              className="glass-select h-10 rounded-[12px] border border-white/[0.10] bg-white/[0.04] px-3 text-sm text-white"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="">All categories</option>
              {categories.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>

          <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-5 backdrop-blur-md">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Category</TableHead>
                    <TableHead>Qty</TableHead>
                    <TableHead>Location</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {visibleItems.map((it) => (
                    <TableRow key={it.item_id}>
                      <TableCell className="font-medium">{it.name}</TableCell>
                      <TableCell>{it.category}</TableCell>
                      <TableCell>{it.quantity}</TableCell>
                      <TableCell>{normalizeLocation(it.location)}</TableCell>
                      <TableCell className="text-right">
                        <div className="flex flex-wrap justify-end gap-2">
                          <Button variant="outline" size="sm" onClick={() => openEdit(it)} disabled={loading}>
                            Edit
                          </Button>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => onUpdateItem(it.item_id, { quantity: it.quantity + 1 })}
                            disabled={loading}
                          >
                            +1
                          </Button>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => onUpdateItem(it.item_id, { quantity: Math.max(0, it.quantity - 1) })}
                            disabled={loading || it.quantity === 0}
                          >
                            -1
                          </Button>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => onUpdateItem(it.item_id, { quantity: 0 })}
                            disabled={loading || it.quantity === 0}
                          >
                            Out of Stock
                          </Button>
                          <Button
                            variant="destructive"
                            size="sm"
                            onClick={() => onDelete(it.item_id)}
                            disabled={loading}
                          >
                            Delete
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                  {visibleItems.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={5} className="py-10 text-center text-sm text-muted-foreground">
                        No items found in this space.
                      </TableCell>
                    </TableRow>
                  ) : null}
                </TableBody>
              </Table>
            </div>
          </div>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {spaces.map((space) => {
            const itemsInSpace = itemsBySpace[space] ?? [];
            const lowStock = itemsInSpace.filter((item) => item.quantity <= 1).length;
            return (
              <div
                key={space}
                className="group cursor-pointer rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-5 transition-all duration-200 hover:border-white/[0.18] hover:-translate-y-0.5"
                onClick={() => openSpace(space)}
              >
                <div className="mb-4">
                  <p className="text-[16px] font-semibold text-white">{space}</p>
                  <p className="text-[13px] text-white/45">{itemsInSpace.length} items</p>
                  {lowStock > 0 ? <p className="text-[13px] text-amber-400">{lowStock} low stock</p> : null}
                </div>
                <div className="mt-4 flex items-center gap-2">
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    className="border border-white/[0.08] p-2"
                    onClick={(e) => {
                      e.stopPropagation();
                      openSpreadsheet(space);
                    }}
                  >
                    <UploadCloud size={16} />
                  </Button>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    className="border border-white/[0.08] p-2"
                    onClick={(e) => {
                      e.stopPropagation();
                      openShare(space);
                    }}
                  >
                    <Share2 size={16} />
                  </Button>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="border border-white/[0.08] p-2"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <MoreHorizontal size={16} />
                      </Button>
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
            className="flex items-center justify-center rounded-[16px] border border-dashed border-white/[0.20] bg-white/[0.04] p-5 text-center text-white/60 transition-all duration-200 hover:border-white/[0.18] hover:-translate-y-0.5"
            onClick={() => setCreateSpaceOpen(true)}
          >
            <div className="space-y-3">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full border border-white/[0.10] text-white/80">
                <Plus size={20} />
              </div>
              <div className="text-[16px] font-semibold text-white">New Space</div>
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

      <Dialog open={shareOpen} onOpenChange={(open) => {
        setShareOpen(open);
        if (!open) setShareSpace(null);
      }}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Share Space</DialogTitle>
          </DialogHeader>
          {shareSpace ? <ShareSpaceModal spaceName={shareSpace} token={token || ""} /> : null}
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
