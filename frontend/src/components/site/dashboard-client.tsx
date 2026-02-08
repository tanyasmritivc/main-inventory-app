"use client";

import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";

import type { ExtractedInventoryItem, InventoryItem } from "@/lib/api";
import {
  addItem,
  aiCommand,
  bulkCreate,
  deleteItem,
  extractFromImage,
  extractFromImageMulti,
  processBarcode,
  searchItems,
  updateItem,
} from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";

import { BarcodeScanner } from "@/components/site/zxing-scanner";

type DraftItem = {
  name: string;
  category: string;
  quantity: number;
  location: string;
  image_url?: string | null;
  barcode?: string | null;
  purchase_source?: string | null;
  notes?: string | null;
};

const emptyDraft: DraftItem = {
  name: "",
  category: "",
  quantity: 1,
  location: "",
  image_url: null,
  barcode: null,
  purchase_source: null,
  notes: null,
};

function tokenizeQuery(s: string): string[] {
  return (s || "")
    .toLowerCase()
    .split(/[^a-z0-9]+/g)
    .map((t) => t.trim())
    .filter(Boolean);
}

function itemMatchesQuery(it: InventoryItem, q: string): boolean {
  const query = (q || "").trim().toLowerCase();
  if (!query) return true;

  const name = (it.name || "").trim().toLowerCase();
  const category = (it.category || "").trim().toLowerCase();
  const location = (it.location || "").trim().toLowerCase();

  if (name === query) return true;

  const tokens = tokenizeQuery(query);
  if (tokens.length === 0) return true;

  return tokens.some((t) => {
    if (!t) return false;
    return name.includes(t) || category.includes(t) || location.includes(t);
  });
}

function renderEmphasisText(text: string): Array<string | ReactNode> {
  const out: Array<string | ReactNode> = [];
  let i = 0;
  let key = 0;

  while (i < text.length) {
    if (text.startsWith("**", i)) {
      const end = text.indexOf("**", i + 2);
      if (end !== -1) {
        const inner = text.slice(i + 2, end);
        out.push(<strong key={`b-${key++}`}>{inner}</strong>);
        i = end + 2;
        continue;
      }
    }

    if (text[i] === "*" && text[i + 1] !== "*") {
      const end = text.indexOf("*", i + 1);
      if (end !== -1 && text[end + 1] !== "*") {
        const inner = text.slice(i + 1, end);
        out.push(<em key={`i-${key++}`}>{inner}</em>);
        i = end + 1;
        continue;
      }
    }

    const nextBold = text.indexOf("**", i);
    const nextItalic = text.indexOf("*", i);
    const next = [nextBold === -1 ? Number.POSITIVE_INFINITY : nextBold, nextItalic === -1 ? Number.POSITIVE_INFINITY : nextItalic].reduce(
      (a, b) => Math.min(a, b),
      Number.POSITIVE_INFINITY
    );
    const end = Number.isFinite(next) ? next : text.length;
    out.push(text.slice(i, end));
    i = end;
  }

  return out;
}

export function DashboardClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const [aiStatus, setAiStatus] = useState<string | null>(null);

  const [token, setToken] = useState<string | null>(null);
  const [allItems, setAllItems] = useState<InventoryItem[]>([]);
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [query, setQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [aiSending, setAiSending] = useState(false);
  const [aiInput, setAiInput] = useState("");
  const [aiMessages, setAiMessages] = useState<Array<{ role: "user" | "assistant"; text: string }>>([]);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [extractingImage, setExtractingImage] = useState(false);
  const [extractingMultiImage, setExtractingMultiImage] = useState(false);

  const [multiProgressStep, setMultiProgressStep] = useState<number>(0);
  const [imageProgressStep, setImageProgressStep] = useState<number>(0);
  const [barcodeProgressStep, setBarcodeProgressStep] = useState<number>(0);

  const [draft, setDraft] = useState<DraftItem>(emptyDraft);
  const [createOpen, setCreateOpen] = useState(false);
  const [scannerOpen, setScannerOpen] = useState(false);

  const [editOpen, setEditOpen] = useState(false);
  const [editItemId, setEditItemId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState<DraftItem>(emptyDraft);

  const [multiOpen, setMultiOpen] = useState(false);
  const [multiItems, setMultiItems] = useState<ExtractedInventoryItem[]>([]);
  const [multiSummary, setMultiSummary] = useState<{ total_detected: number; categories: Record<string, number> } | null>(
    null
  );

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return fallback;
  }

  function friendlyAiError(err: unknown, fallback: string): string {
    const msg = errorMessage(err, fallback);
    if (msg.includes("502") || msg.includes("503")) {
      return "AI is temporarily unavailable. Please try again.";
    }
    if (msg.toLowerCase().includes("ai extraction temporarily unavailable")) {
      return "AI is temporarily unavailable. Please try again.";
    }
    return msg;
  }

  useEffect(() => {
    if (!query.trim()) return;
    const t = window.setTimeout(() => {
      void loadItems(undefined, query);
    }, 400);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  function applyUpdatedItem(updated: InventoryItem) {
    setAllItems((prev) => prev.map((i) => (i.item_id === updated.item_id ? updated : i)));
    setItems((prev) => prev.map((i) => (i.item_id === updated.item_id ? updated : i)));
  }

  async function onUpdateItem(itemId: string, updates: Partial<Omit<InventoryItem, "item_id" | "created_at">>) {
    setError(null);
    setSuccess(null);
    setLoading(true);
    try {
      const t = token || (await refreshToken());
      const res = await updateItem({ token: t, item_id: itemId, updates });
      applyUpdatedItem(res.item);
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to update item"));
    } finally {
      setLoading(false);
    }
  }

  async function onSendAiMessage() {
    const text = aiInput.trim();
    if (!text || aiSending) return;
    setError(null);
    setAiSending(true);
    setAiStatus("Thinking…");
    setAiMessages((prev) => [...prev, { role: "user", text }]);
    setAiInput("");
    try {
      setAiStatus("Checking your inventory…");
      const t = token || (await refreshToken());
      const res = await aiCommand({ token: t, message: text });
      setAiMessages((prev) => [
        ...prev,
        { role: "assistant", text: (res.assistant_message || "").trim() || "Done." },
      ]);
      await loadItems(t, query.trim());
    } catch (err: unknown) {
      setError(errorMessage(err, "AI request failed"));
    } finally {
      setAiSending(false);
      setAiStatus(null);
    }
  }

  async function onExtractMultiImage(file: File) {
    if (extractingMultiImage) return;
    setError(null);
    setSuccess(null);
    setExtractingMultiImage(true);
    setMultiProgressStep(0);
    const step1 = window.setTimeout(() => setMultiProgressStep(1), 700);
    const step2 = window.setTimeout(() => setMultiProgressStep(2), 2500);
    try {
      const t = token || (await refreshToken());
      const res = await extractFromImageMulti({ token: t, file });

      setMultiItems(
        (res.items || []).map((it) => ({
          ...it,
          quantity: typeof it.quantity === "number" ? it.quantity : 1,
          location: (it.location ?? "").trim() || "Unsorted",
        }))
      );
      setMultiSummary(res.summary || null);
      setMultiOpen(true);
    } catch (err: unknown) {
      setError(friendlyAiError(err, "Failed to extract items from image"));
    } finally {
      window.clearTimeout(step1);
      window.clearTimeout(step2);
      setExtractingMultiImage(false);
    }
  }

  async function onAddAllExtracted() {
    setError(null);
    setSuccess(null);
    setLoading(true);
    try {
      const t = token || (await refreshToken());
      const res = await bulkCreate({
        token: t,
        items: multiItems.map((it) => ({ ...it, location: (it.location ?? "").trim() || "Unsorted" })),
      });
      const inserted = res.inserted || [];
      const failures = res.failures || [];

      if (inserted.length) {
        setAllItems((prev) => [...inserted, ...prev]);
        setItems((prev) => [...inserted, ...prev]);
        setSuccess(`${inserted.length} items added from photo.`);
        setMultiOpen(false);
      } else {
        setError(failures.length ? "Some items could not be saved. Please review and try again." : "Nothing was saved.");
      }
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to add items"));
    } finally {
      setLoading(false);
    }
  }

  function openEdit(it: InventoryItem) {
    setEditItemId(it.item_id);
    setEditDraft({
      name: it.name,
      category: it.category,
      quantity: it.quantity,
      location: it.location,
      image_url: it.image_url ?? null,
      barcode: it.barcode ?? null,
      purchase_source: it.purchase_source ?? null,
      notes: it.notes ?? null,
    });
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

  function asString(v: unknown): string | undefined {
    return typeof v === "string" ? v : undefined;
  }

  function asNumber(v: unknown): number | undefined {
    return typeof v === "number" && Number.isFinite(v) ? v : undefined;
  }

  async function refreshToken() {
    const { data, error: sessionErr } = await supabase.auth.getSession();
    if (sessionErr) throw sessionErr;
    const accessToken = data.session?.access_token;
    if (!accessToken) throw new Error("Missing session");
    setToken(accessToken);
    return accessToken;
  }

  async function loadItems(currentToken?: string, queryOverride?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      const q = (queryOverride ?? query).trim();

      if (!q) {
        const res = await searchItems({ token: t, query: q });
        setItems(res.items);
        setAllItems(res.items);
      } else {
        const base = allItems.length
          ? allItems
          : (await (async () => {
              const res = await searchItems({ token: t, query: "" });
              setAllItems(res.items);
              return res.items;
            })());
        setItems(base.filter((it) => itemMatchesQuery(it, q)));
      }
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to load items"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refreshToken().then((t) => loadItems(t, "")).catch(() => {
      setError("Authentication error. Please sign in again.");
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onSignOut() {
    await supabase.auth.signOut();
    window.location.href = "/";
  }

  async function onSubmitNewItem(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const t = token || (await refreshToken());

      if (!draft.name || !draft.category || !draft.location) {
        throw new Error("Name, category, and location are required");
      }

      const res = await addItem({
        token: t,
        item: {
          name: draft.name,
          category: draft.category,
          quantity: draft.quantity,
          location: draft.location,
          image_url: draft.image_url ?? null,
          barcode: draft.barcode ?? null,
          purchase_source: draft.purchase_source ?? null,
          notes: draft.notes ?? null,
        },
      });

      setAllItems((prev) => [res.item, ...prev]);
      setItems((prev) => [res.item, ...prev]);
      setDraft(emptyDraft);
      setCreateOpen(false);
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to add item"));
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

  async function onExtractImage(file: File) {
    if (extractingImage) return;
    setError(null);
    setSuccess(null);
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
        name: asString(extracted.name) ?? d.name,
        category: asString(extracted.category) ?? d.category,
        quantity: asNumber(extracted.quantity) ?? d.quantity,
        location: asString(extracted.location) ?? d.location,
        barcode: asString(extracted.barcode) ?? d.barcode,
        purchase_source: asString(extracted.purchase_source) ?? d.purchase_source,
        notes: asString(extracted.notes) ?? d.notes,
        image_url: res.image_url,
      }));

      setCreateOpen(true);
    } catch (err: unknown) {
      setError(friendlyAiError(err, "Failed to extract from image"));
    } finally {
      window.clearTimeout(step1);
      window.clearTimeout(step2);
      setExtractingImage(false);
    }
  }

  async function onBarcode(barcode: string) {
    setError(null);
    setSuccess(null);
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
        name: d.name || asString(guess.name) || "",
        category: d.category || asString(guess.category) || "",
        notes: d.notes || asString(guess.notes) || null,
      }));
    } catch {
      // Non-fatal
    } finally {
      window.clearTimeout(step1);
      window.clearTimeout(step2);
    }
  }

  const categories: string[] = Array.from(new Set(allItems.map((i) => i.category).filter(Boolean))).sort((a, b) =>
    a.localeCompare(b)
  );
  const visibleItems: InventoryItem[] = categoryFilter
    ? items.filter((i) => (i.category || "").toLowerCase() === categoryFilter.toLowerCase())
    : items;

  return (
    <div className="space-y-10">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight">Dashboard</h2>
          <p className="text-sm text-muted-foreground">Search, add, and manage your inventory.</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="ghost" onClick={onSignOut} className="text-base">
            Sign out
          </Button>
        </div>
      </div>

      {success ? <p className="text-sm text-muted-foreground">{success}</p> : null}

      <Card>
        <CardHeader>
          <CardTitle id="ask-findez">Ask FindEZ</CardTitle>
          <CardDescription>Ask to add, delete, move, or update items.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {aiStatus ? <p className="text-sm text-muted-foreground">{aiStatus}</p> : null}

          <div className="rounded-md border p-4 max-h-[55vh] overflow-y-auto scroll-smooth">
            <div className="grid gap-4">
              {aiMessages.map((m, idx) => (
                <div key={idx} className={m.role === "user" ? "flex justify-end" : "flex justify-start"}>
                  <div className="max-w-[70ch]">
                    <div className={m.role === "user" ? "text-right" : "text-left"}>
                      <div className="text-sm leading-relaxed whitespace-pre-wrap">
                        {renderEmphasisText(m.text)}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Input value={aiInput} onChange={(e) => setAiInput(e.target.value)} placeholder="Type a command…" />
            <Button type="button" onClick={onSendAiMessage} disabled={aiSending || !aiInput.trim()}>
              Send
            </Button>
          </div>

          <div className="rounded-md border bg-background/40 p-3">
            <p className="text-xs text-muted-foreground">Try one of these:</p>
            <div className="mt-2 flex flex-wrap gap-2">
              {[
                "What do I have in storage?",
                "Add groceries from my receipt",
                "Summarize a document I uploaded",
              ].map((p) => (
                <Button
                  key={p}
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setAiInput(p)}
                >
                  {p}
                </Button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="flex flex-wrap items-center gap-2">
        <Dialog open={multiOpen} onOpenChange={setMultiOpen}>
          <DialogTrigger asChild>
            <Button variant="outline">Upload Image → Auto-fill</Button>
          </DialogTrigger>
          <DialogContent className="flex flex-col w-[90vw] max-w-[1200px] h-[80vh] overflow-hidden">
            <DialogHeader>
              <DialogTitle>Auto-fill inventory from image</DialogTitle>
            </DialogHeader>

            <div className="flex flex-col gap-3 h-full">
              {extractingMultiImage ? (
                <div className="space-y-1">
                  <p className="text-sm text-muted-foreground">Analyzing image…</p>
                  <p className="text-xs text-muted-foreground">This usually takes 10–20 seconds depending on the photo.</p>
                  <div className="text-xs text-muted-foreground">
                    <div>{multiProgressStep >= 0 ? "✓ Image uploaded" : "Image uploaded"}</div>
                    <div>{multiProgressStep >= 1 ? "✓ Detecting items" : "Detecting items"}</div>
                    <div>{multiProgressStep >= 2 ? "✓ Extracting details" : "Extracting details"}</div>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="w-fit px-0"
                    onClick={() => {
                      setMultiOpen(false);
                      setCreateOpen(true);
                    }}
                  >
                    Taking too long? Add items manually.
                  </Button>
                </div>
              ) : null}
              <Input
                type="file"
                accept="image/*"
                disabled={extractingMultiImage}
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) onExtractMultiImage(f);
                }}
              />

              {multiSummary ? (
                <p className="text-sm text-muted-foreground">Detected: {multiSummary.total_detected}</p>
              ) : null}

              <div className="rounded-md border flex-1 min-h-0 overflow-auto max-h-[60vh]">
                <Table className="min-w-max">
                  <TableHeader>
                    <TableRow>
                      <TableHead>Name</TableHead>
                      <TableHead>Category</TableHead>
                      <TableHead>Subcategory</TableHead>
                      <TableHead>Qty</TableHead>
                      <TableHead>Location</TableHead>
                      <TableHead>Barcode</TableHead>
                      <TableHead>Part #</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {multiItems.map((it, idx) => (
                      <TableRow key={idx}>
                        <TableCell>
                          <Input
                            value={it.name}
                            onChange={(e) =>
                              setMultiItems((prev) =>
                                prev.map((p, i) => (i === idx ? { ...p, name: e.target.value } : p))
                              )
                            }
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            value={it.category}
                            onChange={(e) =>
                              setMultiItems((prev) =>
                                prev.map((p, i) => (i === idx ? { ...p, category: e.target.value } : p))
                              )
                            }
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            value={it.subcategory ?? ""}
                            onChange={(e) =>
                              setMultiItems((prev) =>
                                prev.map((p, i) => (i === idx ? { ...p, subcategory: e.target.value } : p))
                              )
                            }
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            type="number"
                            min={0}
                            value={it.quantity}
                            onChange={(e) =>
                              setMultiItems((prev) =>
                                prev.map((p, i) =>
                                  i === idx
                                    ? { ...p, quantity: Number.parseInt(e.target.value || "0", 10) }
                                    : p
                                )
                              )
                            }
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            value={it.location ?? ""}
                            onChange={(e) =>
                              setMultiItems((prev) =>
                                prev.map((p, i) => (i === idx ? { ...p, location: e.target.value } : p))
                              )
                            }
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            value={it.barcode ?? ""}
                            onChange={(e) =>
                              setMultiItems((prev) =>
                                prev.map((p, i) => (i === idx ? { ...p, barcode: e.target.value } : p))
                              )
                            }
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            value={it.part_number ?? ""}
                            onChange={(e) =>
                              setMultiItems((prev) =>
                                prev.map((p, i) => (i === idx ? { ...p, part_number: e.target.value } : p))
                              )
                            }
                          />
                        </TableCell>
                      </TableRow>
                    ))}

                    {multiItems.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={7} className="py-10 text-center text-sm text-muted-foreground">
                          Upload an image to extract items.
                        </TableCell>
                      </TableRow>
                    ) : null}
                  </TableBody>
                </Table>
              </div>

              <div className="flex items-center justify-end gap-2">
                <Button type="button" variant="outline" onClick={() => setMultiOpen(false)}>
                  Close
                </Button>
                <Button type="button" onClick={onAddAllExtracted} disabled={loading || multiItems.length === 0}>
                  Add All to Inventory
                </Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>

        <Dialog open={scannerOpen} onOpenChange={setScannerOpen}>
          <DialogTrigger asChild>
            <Button variant="outline">Scan Barcode</Button>
          </DialogTrigger>
          <DialogContent className="max-w-xl">
            <DialogHeader>
              <DialogTitle>Scan a barcode</DialogTitle>
            </DialogHeader>
            <div className="space-y-1">
              <p className="text-sm text-muted-foreground">Reading barcode…</p>
              <p className="text-xs text-muted-foreground">This usually takes 10–20 seconds depending on lighting.</p>
              <div className="text-xs text-muted-foreground">
                <div>{barcodeProgressStep >= 0 ? "✓ Camera ready" : "Camera ready"}</div>
                <div>{barcodeProgressStep >= 1 ? "✓ Scanning" : "Scanning"}</div>
                <div>{barcodeProgressStep >= 2 ? "✓ Looking up details" : "Looking up details"}</div>
              </div>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="w-fit px-0"
                onClick={() => {
                  setScannerOpen(false);
                  setCreateOpen(true);
                }}
              >
                Taking too long? Add items manually.
              </Button>
            </div>
            <BarcodeScanner
              onDetected={(code: string) => {
                onBarcode(code);
                setScannerOpen(false);
                setCreateOpen(true);
              }}
            />
          </DialogContent>
        </Dialog>

        <Dialog open={createOpen} onOpenChange={setCreateOpen}>
          <DialogTrigger asChild>
            <Button>Add Item</Button>
          </DialogTrigger>
          <DialogContent className="max-w-2xl">
            <DialogHeader>
              <DialogTitle>Add inventory item</DialogTitle>
            </DialogHeader>

            <form className="grid gap-4" onSubmit={onSubmitNewItem}>
              <div className="grid gap-2">
                <Label htmlFor="img">Extract from image (optional)</Label>
                <Input
                  id="img"
                  type="file"
                  accept="image/*"
                  disabled={extractingImage}
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) onExtractImage(f);
                  }}
                />
                {extractingImage ? (
                  <div className="space-y-1">
                    <p className="text-sm text-muted-foreground">Analyzing image…</p>
                    <p className="text-xs text-muted-foreground">This usually takes 10–20 seconds depending on the photo.</p>
                    <div className="text-xs text-muted-foreground">
                      <div>{imageProgressStep >= 0 ? "✓ Image uploaded" : "Image uploaded"}</div>
                      <div>{imageProgressStep >= 1 ? "✓ Detecting items" : "Detecting items"}</div>
                      <div>{imageProgressStep >= 2 ? "✓ Extracting details" : "Extracting details"}</div>
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="w-fit px-0"
                    >
                      Taking too long? Add items manually.
                    </Button>
                  </div>
                ) : null}
                {draft.image_url ? (
                  <a className="text-sm underline" href={draft.image_url} target="_blank" rel="noreferrer">
                    View uploaded image
                  </a>
                ) : null}
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                <div className="grid gap-2">
                  <Label htmlFor="name">Name</Label>
                  <Input
                    id="name"
                    value={draft.name}
                    onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))}
                    required
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="category">Category</Label>
                  <Input
                    id="category"
                    value={draft.category}
                    onChange={(e) => setDraft((d) => ({ ...d, category: e.target.value }))}
                    required
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="qty">Quantity</Label>
                  <Input
                    id="qty"
                    type="number"
                    min={0}
                    value={draft.quantity}
                    onChange={(e) => setDraft((d) => ({ ...d, quantity: Number.parseInt(e.target.value || "0", 10) }))}
                    required
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="location">Location</Label>
                  <Input
                    id="location"
                    value={draft.location}
                    onChange={(e) => setDraft((d) => ({ ...d, location: e.target.value }))}
                    required
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="barcode">Barcode</Label>
                  <Input
                    id="barcode"
                    value={draft.barcode ?? ""}
                    onChange={(e) => setDraft((d) => ({ ...d, barcode: e.target.value }))}
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="source">Purchase source</Label>
                  <Input
                    id="source"
                    value={draft.purchase_source ?? ""}
                    onChange={(e) => setDraft((d) => ({ ...d, purchase_source: e.target.value }))}
                  />
                </div>
              </div>

              <div className="grid gap-2">
                <Label htmlFor="notes">Notes</Label>
                <Textarea
                  id="notes"
                  value={draft.notes ?? ""}
                  onChange={(e) => setDraft((d) => ({ ...d, notes: e.target.value }))}
                />
              </div>

              <div className="flex items-center justify-end gap-2">
                <Button type="button" variant="outline" onClick={() => setCreateOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={loading}>
                  Save Item
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Edit inventory item</DialogTitle>
          </DialogHeader>
          <form className="grid gap-4" onSubmit={onSaveEdit}>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="grid gap-2">
                <Label htmlFor="edit-name">Name</Label>
                <Input
                  id="edit-name"
                  value={editDraft.name}
                  onChange={(e) => setEditDraft((d) => ({ ...d, name: e.target.value }))}
                  required
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="edit-category">Category</Label>
                <Input
                  id="edit-category"
                  value={editDraft.category}
                  onChange={(e) => setEditDraft((d) => ({ ...d, category: e.target.value }))}
                  required
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="edit-qty">Quantity</Label>
                <Input
                  id="edit-qty"
                  type="number"
                  min={0}
                  value={editDraft.quantity}
                  onChange={(e) =>
                    setEditDraft((d) => ({ ...d, quantity: Number.parseInt(e.target.value || "0", 10) }))
                  }
                  required
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="edit-location">Location</Label>
                <Input
                  id="edit-location"
                  value={editDraft.location}
                  onChange={(e) => setEditDraft((d) => ({ ...d, location: e.target.value }))}
                  required
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="edit-barcode">Barcode</Label>
                <Input
                  id="edit-barcode"
                  value={editDraft.barcode ?? ""}
                  onChange={(e) => setEditDraft((d) => ({ ...d, barcode: e.target.value }))}
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="edit-source">Purchase source</Label>
                <Input
                  id="edit-source"
                  value={editDraft.purchase_source ?? ""}
                  onChange={(e) => setEditDraft((d) => ({ ...d, purchase_source: e.target.value }))}
                />
              </div>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="edit-notes">Notes</Label>
              <Textarea
                id="edit-notes"
                value={editDraft.notes ?? ""}
                onChange={(e) => setEditDraft((d) => ({ ...d, notes: e.target.value }))}
              />
            </div>

            <div className="flex items-center justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setEditOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" disabled={loading}>
                Save
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      <Card>
        <CardHeader>
          <CardTitle>Inventory</CardTitle>
          <CardDescription>Use natural language to find items fast.</CardDescription>
        </CardHeader>
        <CardContent className="flex max-h-[70dvh] flex-col gap-4">
          <div className="flex flex-col gap-2 sm:flex-row">
            <Input
              placeholder='Try: "snacks in pantry"'
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") loadItems();
              }}
            />

            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="">All categories</option>
              {categories.map((c: string) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
            <Button variant="outline" onClick={() => loadItems()} disabled={loading}>
              Search
            </Button>
            <Button
              variant="ghost"
              onClick={() => {
                setQuery("");
                setCategoryFilter("");
                setItems(allItems);
                void loadItems(token || undefined, "");
              }}
              disabled={loading}
            >
              Clear
            </Button>
          </div>

          {error ? <p className="text-sm text-destructive">{error}</p> : null}

          <div className="min-h-0 flex-1 overflow-y-auto rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Category</TableHead>
                  <TableHead>Qty</TableHead>
                  <TableHead>Location</TableHead>
                  <TableHead>Image</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {visibleItems.map((it) => (
                  <TableRow key={it.item_id}>
                    <TableCell className="font-medium">{it.name}</TableCell>
                    <TableCell>{it.category}</TableCell>
                    <TableCell>{it.quantity}</TableCell>
                    <TableCell>{it.location}</TableCell>
                    <TableCell>
                      {it.image_url ? (
                        <a href={it.image_url} target="_blank" rel="noreferrer" className="underline">
                          View
                        </a>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
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
                    <TableCell colSpan={6} className="py-10 text-center text-sm text-muted-foreground">
                      No items yet. Add one or upload a receipt.
                    </TableCell>
                  </TableRow>
                ) : null}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
