"use client";

import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import Link from "next/link";

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
import {
  asUsageType,
  dashboardAiInputPlaceholder,
  dashboardInventorySearchPlaceholder,
  dashboardSuggestedPrompts,
  personaDefaults,
  type UsageType,
} from "@/lib/personalization";
import { Button } from "@/components/ui/button";
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

function isBulletLine(s: string): boolean {
  const t = (s || "").trim();
  if (!t) return false;
  return /^([-*•]\s+|\d+\.\s+|\([a-zA-Z0-9]+\)\s+)/.test(t);
}

function renderAssistantSemanticText(text: string): Array<string | ReactNode> {
  const lines = (text || "").split("\n");
  const out: Array<string | ReactNode> = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? "";
    const trimmed = line.trim();

    if (!trimmed) {
      out.push(line);
    } else if (isBulletLine(trimmed)) {
      out.push(line);
    } else {
      const isQuestionHeading = trimmed.endsWith("?") && !trimmed.includes(":");
      const isStandaloneTitle =
        !trimmed.includes(":") &&
        !trimmed.endsWith(".") &&
        !trimmed.endsWith("!") &&
        trimmed.length <= 80 &&
        trimmed.split(/\s+/).length <= 10;

      if (isQuestionHeading || isStandaloneTitle) {
        out.push(<strong key={`h-${i}`}>{line}</strong>);
      } else {
        const colonIdx = line.indexOf(":");
        const hasLikelyLabel =
          colonIdx > 0 &&
          colonIdx <= 50 &&
          !line.slice(0, colonIdx).includes("//") &&
          /[A-Za-z]/.test(line.slice(0, colonIdx));

        const lower = trimmed.toLowerCase();
        const isInstruction =
          lower.startsWith("please ") ||
          lower.startsWith("next ") ||
          lower.startsWith("try ") ||
          lower.startsWith("you can ") ||
          lower.startsWith("you should ") ||
          lower.startsWith("to ") ||
          lower.startsWith("if you ") ||
          lower.startsWith("choose ") ||
          lower.startsWith("select ");

        if (hasLikelyLabel) {
          const label = line.slice(0, colonIdx + 1);
          const rest = line.slice(colonIdx + 1);
          out.push(
            <span key={`l-${i}`}>
              <strong>{label}</strong>
              {rest}
            </span>
          );
        } else if (isInstruction) {
          out.push(<em key={`i-${i}`}>{line}</em>);
        } else {
          out.push(line);
        }
      }
    }

    if (i !== lines.length - 1) out.push("\n");
  }

  return out;
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

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

export function DashboardClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const [aiStatus, setAiStatus] = useState<string | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [usageType, setUsageType] = useState<UsageType | null>(null);
  const [userFirstName, setUserFirstName] = useState("");
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

  async function loadUsageType() {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const email = user.email ?? "";
      setUserFirstName(email ? email.split("@")[0] : "");
      const { data } = await supabase.from("profiles").select("usage_type").eq("id", user.id).maybeSingle();
      setUsageType(asUsageType((data as Record<string, unknown> | null)?.usage_type));
    } catch {
      setUsageType(null);
    }
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
    refreshToken()
      .then((t) => {
        void loadUsageType();
        return loadItems(t, "");
      })
      .catch(() => {
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
  const persona = useMemo(() => personaDefaults(usageType), [usageType]);
  const visibleItems: InventoryItem[] = categoryFilter
    ? items.filter((i) => (i.category || "").toLowerCase() === categoryFilter.toLowerCase())
    : items;

  const totalSpaces = useMemo(() => {
    const set = new Set<string>();
    allItems.forEach((item) => {
      set.add((item.location ?? "").trim() || "Unsorted");
    });
    return set.size;
  }, [allItems]);

  const lowStockCount = useMemo(() => allItems.filter((it) => it.quantity <= 1).length, [allItems]);

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "#fff", margin: 0, letterSpacing: "-0.035em" }}>
          {getGreeting()}, {userFirstName || "there"}
        </h1>
        <p style={{ fontSize: 13, color: "#6e6e73", marginTop: 4, fontWeight: 400, letterSpacing: "-0.01em" }}>
          Here&apos;s what&apos;s happening with your inventory.
        </p>
        {success ? <p style={{ fontSize: 12, color: "#32d74b", marginTop: 6, fontWeight: 500 }}>{success}</p> : null}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10, margin: "24px 0" }}>
        <Link href="/inventory" style={{ textDecoration: "none" }}>
          <div style={{ padding: "18px 20px", borderRadius: 12, background: "#0a0a0a", border: "1px solid #1c1c1e" }}>
            <div style={{ fontSize: 28, fontWeight: 700, color: "#fff", lineHeight: 1, letterSpacing: "-0.04em" }}>{allItems.length}</div>
            <div style={{ fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.07em', fontWeight: 500, color: '#6e6e73', marginTop: 6 }}>Items</div>
          </div>
        </Link>
        <Link href="/inventory" style={{ textDecoration: "none" }}>
          <div style={{ padding: "18px 20px", borderRadius: 12, background: "#0a0a0a", border: "1px solid #1c1c1e" }}>
            <div style={{ fontSize: 28, fontWeight: 700, color: "#fff", lineHeight: 1, letterSpacing: "-0.04em" }}>{totalSpaces}</div>
            <div style={{ fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.07em', fontWeight: 500, color: '#6e6e73', marginTop: 6 }}>Spaces</div>
          </div>
        </Link>
        <Link href="/inventory" style={{ textDecoration: "none" }}>
          <div style={{ padding: "18px 20px", borderRadius: 12, background: "#0a0a0a", border: "1px solid #1c1c1e" }}>
            <div style={{ fontSize: 28, fontWeight: 700, color: lowStockCount > 0 ? "#ffd60a" : "#fff", lineHeight: 1, letterSpacing: "-0.04em" }}>{lowStockCount}</div>
            <div style={{ fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.07em', fontWeight: 500, color: '#6e6e73', marginTop: 6 }}>Attention</div>
          </div>
        </Link>
      </div>

      <div style={{ marginBottom: 28, borderLeft: '2px solid #1c1c1e', paddingLeft: 20 }}>
        <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 10 }}>Ask FindEZ</p>
        {aiStatus ? <p style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", marginBottom: 8 }}>{aiStatus}</p> : null}
        <div style={{ minHeight: 64, maxHeight: 300, overflowY: "auto", marginBottom: 10, background: "#0a0a0a", borderRadius: 8, padding: "12px 14px", fontSize: 13, color: "#a1a1a6", letterSpacing: "-0.01em", display: aiMessages.length ? "block" : "flex", alignItems: aiMessages.length ? "stretch" : "center", justifyContent: aiMessages.length ? "flex-start" : "center", textAlign: aiMessages.length ? "left" : "center" }}>
          {aiMessages.length === 0 ? (
            <div style={{ width: "100%", fontSize: 14, letterSpacing: "0.01em" }}>
              Ask me anything about your inventory...
            </div>
          ) : (
            aiMessages.map((m, idx) => (
              <div key={idx} style={{ display: "flex", justifyContent: m.role === "user" ? "flex-end" : "flex-start", marginBottom: 10 }}>
                <div style={{ maxWidth: "70ch", fontSize: 14, lineHeight: 1.6, whiteSpace: "pre-wrap", color: m.role === "user" ? "rgba(255,255,255,0.85)" : "rgba(255,255,255,0.6)", textAlign: m.role === "user" ? "right" : "left" }}>
                  {m.role === "assistant" ? renderAssistantSemanticText(m.text) : renderEmphasisText(m.text)}
                </div>
              </div>
            ))
          )}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "8px 0" }}>
          <input
            value={aiInput}
            onChange={(e) => setAiInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") void onSendAiMessage(); }}
            placeholder="Ask anything about your inventory..."
            style={{
              flex: 1,
              minWidth: 0,
              background: "#0a0a0a",
              border: "1px solid #1c1c1e",
              borderRadius: 8,
              padding: "10px 14px",
              color: "#f5f5f7",
              fontSize: 13,
              outline: "none",
              letterSpacing: "-0.01em",
            }}
          />
          <button
            type="button"
            onClick={onSendAiMessage}
            disabled={aiSending || !aiInput.trim()}
            style={{
              background: "#fff",
              color: "#000",
              border: "none",
              borderRadius: 6,
              padding: "8px 16px",
              fontSize: 13,
              fontWeight: 510,
              letterSpacing: "-0.015em",
              cursor: aiSending || !aiInput.trim() ? "not-allowed" : "pointer",
              opacity: aiSending || !aiInput.trim() ? 0.4 : 1,
            }}
          >
            Send
          </button>
        </div>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
          {dashboardSuggestedPrompts(usageType).map((p) => (
            <button
              key={p}
              type="button"
              onClick={() => setAiInput(p)}
              style={{ background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 99, fontSize: 11, color: "#6e6e73", padding: "4px 12px", cursor: "pointer" }}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      <div style={{ marginBottom: 48 }}>
        <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 10 }}>Quick Actions</p>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        <Dialog open={multiOpen} onOpenChange={setMultiOpen}>
          <DialogTrigger asChild>
            <Button style={{ background: "transparent", border: "1px solid #1c1c1e", borderRadius: 8, padding: "7px 14px", fontSize: 12, fontWeight: 500, color: "#a1a1a6", letterSpacing: "-0.012em", cursor: "pointer" }}>
              Upload Image → Auto-fill
            </Button>
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
            <Button style={{ background: "transparent", border: "1px solid #1c1c1e", borderRadius: 8, padding: "7px 14px", fontSize: 12, fontWeight: 500, color: "#a1a1a6", letterSpacing: "-0.012em", cursor: "pointer" }}>
              Scan Barcode
            </Button>
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
            <Button style={{ background: "transparent", border: "1px solid #1c1c1e", borderRadius: 8, padding: "7px 14px", fontSize: 12, fontWeight: 500, color: "#a1a1a6", letterSpacing: "-0.012em", cursor: "pointer" }}>
              Add Item
            </Button>
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
                    <Button type="button" variant="ghost" size="sm" className="w-fit px-0">
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
                    list={usageType ? "persona-category-suggestions" : undefined}
                    placeholder={usageType ? persona.categories[0] || "" : undefined}
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
                    list={usageType ? "persona-location-suggestions" : undefined}
                    placeholder={usageType ? persona.locations[0] || "" : undefined}
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

            {usageType ? (
              <>
                <datalist id="persona-category-suggestions">
                  {persona.categories.map((c) => (
                    <option key={c} value={c} />
                  ))}
                </datalist>
                <datalist id="persona-location-suggestions">
                  {persona.locations.map((l) => (
                    <option key={l} value={l} />
                  ))}
                </datalist>
              </>
            ) : null}
          </DialogContent>
        </Dialog>
        </div>
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

      <div>
        {allItems.length === 0 && !loading ? (
          <div style={{ textAlign: 'center', padding: '56px 24px', background: '#0a0a0a', borderRadius: 12, border: '1px dashed #2c2c2e', marginTop: 16 }}>
            <div style={{ fontSize: 13, fontWeight: 590, color: '#f5f5f7', marginBottom: 6, letterSpacing: '-0.015em' }}>Your inventory is empty</div>
            <div style={{ fontSize: 13, color: '#6e6e73', marginBottom: 22, letterSpacing: '-0.01em', lineHeight: 1.5 }}>Add your first item by scanning a barcode, uploading a photo, or typing manually.</div>
            <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
              <button type="button" onClick={() => setCreateOpen(true)} style={{ padding: '8px 16px', borderRadius: 8, background: '#fff', color: '#000', border: 'none', fontSize: 13, fontWeight: 510, letterSpacing: "-0.012em", cursor: 'pointer' }}>Add item</button>
              <label style={{ padding: '8px 16px', borderRadius: 8, background: 'transparent', border: '1px solid #1c1c1e', color: '#f5f5f7', cursor: 'pointer', fontSize: 13, fontWeight: 510, letterSpacing: "-0.012em" }}>
                Upload image
                <input type="file" accept="image/*" onChange={(e) => { const f = e.target.files?.[0]; if (f) void onExtractImage(f); }} style={{ display: 'none' }} />
              </label>
            </div>
          </div>
        ) : null}

        <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 10 }}>Your Inventory</p>
        <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: 12, marginBottom: 20 }}>
          <input
            placeholder={dashboardInventorySearchPlaceholder(usageType)}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") void loadItems(); }}
            style={{
              flex: 1,
              minWidth: 180,
              background: "#0a0a0a",
              border: "1px solid #1c1c1e",
              borderRadius: 8,
              padding: "9px 14px",
              color: "#f5f5f7",
              fontSize: 13,
              outline: "none",
              letterSpacing: "-0.01em",
            }}
          />
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            style={{
              background: "#0a0a0a",
              border: "1px solid #1c1c1e",
              borderRadius: 8,
              padding: "9px 14px",
              color: "#f5f5f7",
              fontSize: 13,
              outline: "none",
              letterSpacing: "-0.01em",
            }}
          >
            <option value="">All categories</option>
            {categories.map((c: string) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
          <button type="button" onClick={() => void loadItems()} disabled={loading} style={{ background: "#fff", color: "#000", border: "none", borderRadius: 6, padding: "7px 14px", fontSize: 12, fontWeight: 510, cursor: "pointer", opacity: loading ? 0.4 : 1 }}>Search</button>
          <button type="button" onClick={() => { setQuery(""); setCategoryFilter(""); setItems(allItems); void loadItems(token || undefined, ""); }} disabled={loading} style={{ background: "transparent", border: "1px solid #2c2c2e", color: "#f5f5f7", borderRadius: 6, padding: "7px 14px", fontSize: 12, cursor: "pointer", opacity: loading ? 0.4 : 1 }}>Clear</button>
        </div>

        {error ? <p style={{ fontSize: 13, color: "#ff453a", marginBottom: 12 }}>{error}</p> : null}

        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ borderBottom: "1px solid #1c1c1e" }}>
                <th style={{ fontSize: 10, fontWeight: 500, color: "#6e6e73", textTransform: "uppercase", letterSpacing: "0.07em", textAlign: "left", padding: "0 0 10px" }}>Name</th>
                <th style={{ fontSize: 10, fontWeight: 500, color: "#6e6e73", textTransform: "uppercase", letterSpacing: "0.07em", textAlign: "left", padding: "0 0 10px" }}>Category</th>
                <th style={{ fontSize: 10, fontWeight: 500, color: "#6e6e73", textTransform: "uppercase", letterSpacing: "0.07em", textAlign: "left", padding: "0 0 10px" }}>Qty</th>
                <th style={{ fontSize: 10, fontWeight: 500, color: "#6e6e73", textTransform: "uppercase", letterSpacing: "0.07em", textAlign: "left", padding: "0 0 10px" }}>Location</th>
                <th style={{ fontSize: 10, fontWeight: 500, color: "#6e6e73", textTransform: "uppercase", letterSpacing: "0.07em", textAlign: "left", padding: "0 0 10px" }}>Image</th>
                <th style={{ fontSize: 10, fontWeight: 500, color: "#6e6e73", textTransform: "uppercase", letterSpacing: "0.07em", textAlign: "right", padding: "0 0 10px" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {visibleItems.map((it) => (
                <tr key={it.item_id} style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }} className="hover:bg-white/[0.02] transition-colors">
                  <td style={{ fontSize: 13, color: "#f5f5f7", fontWeight: 510, padding: "12px 0", letterSpacing: "-0.015em" }}>{it.name}</td>
                  <td style={{ padding: "12px 12px 12px 0" }}><span style={{ fontSize: 11, padding: "2px 8px", background: "#1c1c1e", borderRadius: 99, color: "#a1a1a6" }}>{it.category}</span></td>
                  <td style={{ fontSize: 13, color: "#fff", fontWeight: 590, padding: "12px 12px 12px 0" }}>{it.quantity}</td>
                  <td style={{ fontSize: 12, color: "#6e6e73", padding: "12px 12px 12px 0" }}>{it.location}</td>
                  <td style={{ padding: "14px 12px 14px 0" }}>
                    {it.image_url ? (
                      <a href={it.image_url} target="_blank" rel="noreferrer" style={{ fontSize: 13, color: "rgba(255,255,255,0.5)", textDecoration: "underline" }}>View</a>
                    ) : (
                      <span style={{ color: "rgba(255,255,255,0.2)" }}>—</span>
                    )}
                  </td>
                  <td style={{ padding: "13px 0", textAlign: "right" }}>
                    <div style={{ display: "flex", justifyContent: "flex-end", gap: 8 }}>
                      <button type="button" onClick={() => openEdit(it)} disabled={loading} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px" }}>Edit</button>
                      <button type="button" onClick={() => void onUpdateItem(it.item_id, { quantity: it.quantity + 1 })} disabled={loading} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px" }}>+1</button>
                      <button type="button" onClick={() => void onUpdateItem(it.item_id, { quantity: Math.max(0, it.quantity - 1) })} disabled={loading || it.quantity === 0} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px", opacity: it.quantity === 0 ? 0.3 : 1 }}>-1</button>
                      <button type="button" onClick={() => void onUpdateItem(it.item_id, { quantity: 0 })} disabled={loading || it.quantity === 0} style={{ fontSize: 11, color: "#6e6e73", background: "none", border: "none", cursor: "pointer", padding: "0 4px", opacity: it.quantity === 0 ? 0.3 : 1 }}>Out of Stock</button>
                      <button type="button" onClick={() => void onDelete(it.item_id)} disabled={loading} style={{ fontSize: 11, color: "#ff453a", background: "none", border: "none", cursor: "pointer", padding: "0 4px" }}>Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
              {visibleItems.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ fontSize: 13, color: "#3a3a3c", textAlign: "center", padding: "40px 0" }}>No items match your search.</td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
