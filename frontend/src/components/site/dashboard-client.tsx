"use client";

import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import Link from "next/link";

import type { ExtractedInventoryItem, InventoryItem } from "@/lib/api";
import {
  addItem,
  aiCommand,
  bulkCreate,
  checkUsage,
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
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

import { BarcodeScanner } from "@/components/site/zxing-scanner";
import { UpgradeModal } from "@/components/site/upgrade-modal";
import { UpgradeGate } from "@/components/site/upgrade-gate";

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
  const supabase = createSupabaseBrowserClient();

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

  const [upgradeModal, setUpgradeModal] = useState<{ open: boolean; reason: 'item_limit' | 'scan_limit' }>({ open: false, reason: 'item_limit' });
  const [usage, setUsage] = useState<Record<string, any> | null>(null);
  const [upgradeGate, setUpgradeGate] = useState<{ open: boolean; feature: string; current: number; limit: number; message: string }>({ open: false, feature: '', current: 0, limit: 0, message: '' });

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
      if (!t) return;
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
    const allowed = await checkAndGate('ai_chat')
    if (!allowed) return
    setError(null);
    setAiSending(true);
    setAiStatus("Thinking…");
    setAiMessages((prev) => [...prev, { role: "user", text }]);
    setAiInput("");
    try {
      setAiStatus("Checking your inventory…");
      const t = token || (await refreshToken());
      if (!t) return;
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
      if (!t) return;
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
    } catch (err: any) {
      if (!handleApiError(err)) {
        setError(friendlyAiError(err, "Failed to extract items from image"));
      }
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
      if (!t) return;
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
    } catch (err: any) {
      if (!handleApiError(err)) {
        setError(errorMessage(err, "Failed to add items"));
      }
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

  async function refreshToken(): Promise<string> {
    const supabase = createSupabaseBrowserClient()
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (session?.access_token) return session.access_token
    } catch (_) {}
    return ''
  }

  async function loadUsageType() {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const email = user.email ?? "";
      setUserFirstName(email ? email.split("@")[0] : "");
      setUsageType(null);
    } catch {
      setUsageType(null);
    }
  }

  async function loadItems(currentToken?: string, queryOverride?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      if (!t) return;
      const q = (queryOverride ?? query).trim();

      if (!q) {
        const res = await searchItems({ token: t, query: q });
        setItems(res.items ?? []);
        setAllItems(res.items ?? []);
      } else {
        const base = allItems.length
          ? allItems
          : (await (async () => {
              const res = await searchItems({ token: t, query: "" });
              setAllItems(res.items ?? []);
              return res.items ?? [];
            })());
        setItems((base ?? []).filter((it) => itemMatchesQuery(it, q)));
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
        // session not ready yet — silent
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    refreshToken().then((t) => {
      if (!t) return;
      fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000"}/usage/status`, {
        headers: { Authorization: `Bearer ${t}` },
      })
        .then((r) => (r.ok ? r.json() : null))
        .then((d: unknown) => { if (d) setUsage(d as Record<string, any>); })
        .catch(() => {});
    }).catch(() => {});
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
      if (!t) return;

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
    } catch (err: any) {
      if (!handleApiError(err)) {
        setError(errorMessage(err, "Failed to add item"));
      }
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
      if (!t) return;
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
    } catch (err: any) {
      if (!handleApiError(err)) {
        setError(friendlyAiError(err, "Failed to extract from image"));
      }
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
      if (!t) return;
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

  const categories: string[] = Array.from(new Set((allItems ?? []).map((i) => i.category).filter(Boolean))).sort((a, b) =>
    a.localeCompare(b)
  );
  const persona = useMemo(() => personaDefaults(usageType), [usageType]);
  const visibleItems: InventoryItem[] = categoryFilter
    ? (items ?? []).filter((i) => (i.category || "").toLowerCase() === categoryFilter.toLowerCase())
    : (items ?? []);

  const totalSpaces = useMemo(() => {
    const set = new Set<string>();
    (allItems ?? []).forEach((item) => {
      set.add((item.location ?? "").trim() || "Unsorted");
    });
    return set.size;
  }, [allItems]);

  const lowStockCount = useMemo(() => (allItems ?? []).filter((it) => it.quantity <= 1).length, [allItems]);

  function renderMarkdown(text: string) {
    const lines = text.split('\n')
    const elements: ReactNode[] = []
    let key = 0

    function parseLine(raw: string): ReactNode {
      const parts = raw.split(/(\*\*[^*]+\*\*)/g)
      return parts.map((part, idx) => {
        if (part.startsWith('**') && part.endsWith('**')) {
          return <strong key={idx} style={{ color: '#f5f5f7', fontWeight: 600 }}>{part.slice(2, -2)}</strong>
        }
        return <span key={idx}>{part}</span>
      })
    }

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]

      if (line.trim() === '') {
        elements.push(<div key={key++} style={{ height: '6px' }} />)
        continue
      }

      if (/^[-•]\s/.test(line.trim())) {
        const content = line.trim().replace(/^[-•]\s/, '')
        elements.push(
          <div key={key++} style={{ display: 'flex', gap: '8px', marginBottom: '3px', paddingLeft: '4px' }}>
            <span style={{ color: '#6e6e73', flexShrink: 0, marginTop: '1px' }}>·</span>
            <span style={{ fontSize: '13px', color: '#a1a1a6', lineHeight: 1.55, letterSpacing: '-0.01em' }}>{parseLine(content)}</span>
          </div>
        )
        continue
      }

      if (/^\d+\.\s/.test(line.trim())) {
        const match = line.trim().match(/^(\d+)\.\s(.*)/)
        if (match) {
          elements.push(
            <div key={key++} style={{ display: 'flex', gap: '8px', marginBottom: '3px', paddingLeft: '4px' }}>
              <span style={{ color: '#6e6e73', flexShrink: 0, minWidth: '16px', fontSize: '12px' }}>{match[1]}.</span>
              <span style={{ fontSize: '13px', color: '#a1a1a6', lineHeight: 1.55, letterSpacing: '-0.01em' }}>{parseLine(match[2])}</span>
            </div>
          )
          continue
        }
      }

      elements.push(
        <div key={key++} style={{ fontSize: '13px', color: '#a1a1a6', lineHeight: 1.6, letterSpacing: '-0.01em', marginBottom: '2px' }}>
          {parseLine(line)}
        </div>
      )
    }

    return <div>{elements}</div>
  }

  return (
    <>
    <div style={{ padding: '36px 40px', maxWidth: '1100px', fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif", WebkitFontSmoothing: 'antialiased' as any }}>

      {/* GREETING */}
      <div style={{ marginBottom: '28px' }}>
        <h1 style={{ fontSize: '26px', fontWeight: 700, letterSpacing: '-0.035em', color: '#f5f5f7', margin: 0, lineHeight: 1.2 }}>
          {getGreeting()}, {userFirstName || "there"}
        </h1>
        <p style={{ fontSize: '13px', color: '#6e6e73', margin: '4px 0 0', letterSpacing: '-0.01em' }}>
          Here&apos;s what&apos;s happening with your inventory.
        </p>
        {success ? <p style={{ fontSize: 12, color: '#32d74b', marginTop: 6, fontWeight: 500 }}>{success}</p> : null}
      </div>

      {/* STATS \u2014 3 glass cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px', marginBottom: '28px' }}>
        <Link href="/inventory" style={{ textDecoration: 'none' }}>
          <div style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '12px', padding: '18px 20px', backdropFilter: 'blur(12px)' }}>
            <div style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.04em', color: '#f5f5f7', lineHeight: 1 }}>{allItems.length}</div>
            <div style={{ fontSize: '10px', fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73', marginTop: '6px' }}>Items</div>
          </div>
        </Link>
        <Link href="/inventory" style={{ textDecoration: 'none' }}>
          <div style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '12px', padding: '18px 20px', backdropFilter: 'blur(12px)' }}>
            <div style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.04em', color: '#f5f5f7', lineHeight: 1 }}>{totalSpaces}</div>
            <div style={{ fontSize: '10px', fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73', marginTop: '6px' }}>Spaces</div>
          </div>
        </Link>
        <Link href="/inventory" style={{ textDecoration: 'none' }}>
          <div style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '12px', padding: '18px 20px', backdropFilter: 'blur(12px)' }}>
            <div style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.04em', color: lowStockCount > 0 ? '#ffd60a' : '#f5f5f7', lineHeight: 1 }}>{lowStockCount}</div>
            <div style={{ fontSize: '10px', fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73', marginTop: '6px' }}>Need Attention</div>
          </div>
        </Link>
      </div>

      {/* USAGE BARS — free users only */}
      {usage && !usage.is_pro && (
        <div style={{ display: 'flex', gap: 16, marginTop: 8, marginBottom: 24, flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: 200 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.40)', fontFamily: 'var(--font-dm-sans)' }}>Items</span>
              <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.40)', fontFamily: 'var(--font-dm-sans)' }}>{usage.items.current} / {usage.items.limit}</span>
            </div>
            <div style={{ height: 4, background: 'rgba(255,255,255,0.08)', borderRadius: 99, overflow: 'hidden' }}>
              <div style={{ height: '100%', borderRadius: 99, background: usage.items.current >= usage.items.limit ? '#ef4444' : '#f59e0b', width: `${Math.min(100, (usage.items.current / usage.items.limit) * 100)}%`, transition: 'width 0.3s ease' }} />
            </div>
          </div>
          <div style={{ flex: 1, minWidth: 200 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.40)', fontFamily: 'var(--font-dm-sans)' }}>Photo scans this month</span>
              <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.40)', fontFamily: 'var(--font-dm-sans)' }}>{usage.photo_scans.current} / {usage.photo_scans.limit}</span>
            </div>
            <div style={{ height: 4, background: 'rgba(255,255,255,0.08)', borderRadius: 99, overflow: 'hidden' }}>
              <div style={{ height: '100%', borderRadius: 99, background: usage.photo_scans.current >= usage.photo_scans.limit ? '#ef4444' : '#f59e0b', width: `${Math.min(100, (usage.photo_scans.current / usage.photo_scans.limit) * 100)}%`, transition: 'width 0.3s ease' }} />
            </div>
          </div>
        </div>
      )}

      {/* TWO COLUMN: AI Chat + Activity */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: '16px', marginBottom: '28px' }}>

        {/* LEFT: Ask FindEZ + Quick Actions */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>

          {/* Ask FindEZ card */}
          <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.07)', borderRadius: '12px', padding: '20px 22px', backdropFilter: 'blur(12px)' }}>
            <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span style={{ width: '5px', height: '5px', borderRadius: '50%', background: '#32d74b', display: 'inline-block' }} />
              Ask FindEZ
            </div>
            {aiStatus ? <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)', marginBottom: 8 }}>{aiStatus}</p> : null}
            <div style={{ minHeight: 60, maxHeight: 300, overflowY: 'auto' as const, marginBottom: 12, fontSize: 13, color: '#a1a1a6', letterSpacing: '-0.01em', display: aiMessages.length ? 'block' : 'flex', alignItems: aiMessages.length ? 'stretch' : 'center', justifyContent: aiMessages.length ? 'flex-start' : 'center', textAlign: aiMessages.length ? 'left' : 'center' as const }}>
              {aiMessages.length === 0 ? (
                <div style={{ width: '100%', fontSize: 13, color: '#3a3a3c' }}>
                  Ask me anything about your inventory...
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                  {aiMessages.map((m, idx) => (
                    <div
                      key={idx}
                      style={m.role === 'user' ? {
                        background: 'rgba(255,255,255,0.05)',
                        border: '1px solid rgba(255,255,255,0.08)',
                        borderRadius: '10px 10px 2px 10px',
                        padding: '10px 14px',
                        marginBottom: 8,
                        alignSelf: 'flex-end' as const,
                        maxWidth: '80%',
                      } : {
                        padding: '4px 0',
                        marginBottom: 8,
                        maxWidth: '100%',
                      }}
                    >
                      {m.role === 'assistant'
                        ? renderMarkdown(m.text)
                        : <div style={{ fontSize: '13px', color: '#f5f5f7', letterSpacing: '-0.01em' }}>{m.text}</div>
                      }
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <input
                value={aiInput}
                onChange={(e) => setAiInput(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') void onSendAiMessage(); }}
                placeholder={dashboardAiInputPlaceholder(usageType)}
                style={{ flex: 1, minWidth: 0, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: 8, padding: '10px 14px', fontSize: 13, color: '#f5f5f7', outline: 'none', letterSpacing: '-0.01em', fontFamily: 'inherit' }}
              />
              <button
                type="button"
                onClick={() => void onSendAiMessage()}
                disabled={aiSending || !aiInput.trim()}
                style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 8, padding: '10px 18px', fontSize: 13, fontWeight: 510, cursor: aiSending || !aiInput.trim() ? 'not-allowed' : 'pointer', opacity: aiSending || !aiInput.trim() ? 0.4 : 1, fontFamily: 'inherit', whiteSpace: 'nowrap' as const }}
              >
                Send
              </button>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap' as const, gap: 6, marginTop: 10 }}>
              {dashboardSuggestedPrompts(usageType).map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setAiInput(p)}
                  style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 99, padding: '4px 12px', fontSize: 11, color: '#6e6e73', cursor: 'pointer', fontFamily: 'inherit' }}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          {/* Quick Actions */}
          <div>
            <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: '10px' }}>
              Quick Actions
            </div>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' as const }}>
              <button
                type="button"
                onClick={async () => {
                const allowed = await checkAndGate('photo_scan')
                if (!allowed) return
                setMultiOpen(true)
              }}
                style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '8px 16px', fontSize: 13, fontWeight: 500, color: '#a1a1a6', cursor: 'pointer', fontFamily: 'inherit' }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.08)'; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}
              >
                {extractingMultiImage ? 'Analyzing\u2026' : 'Upload Image \u2192 Auto-fill'}
              </button>
              <button
                type="button"
                onClick={async () => { const allowed = await checkAndGate('barcode_scan'); if (!allowed) return; setScannerOpen(true); }}
                style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '8px 16px', fontSize: 13, fontWeight: 500, color: '#a1a1a6', cursor: 'pointer', fontFamily: 'inherit' }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.08)'; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}
              >
                Scan Barcode
              </button>
              <button
                type="button"
                onClick={() => { setCreateOpen(true); }}
                style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '8px 16px', fontSize: 13, fontWeight: 500, color: '#a1a1a6', cursor: 'pointer', fontFamily: 'inherit' }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.08)'; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'; }}
              >
                Add Item
              </button>
            </div>
          </div>

        </div>

        {/* RIGHT: Recent Activity */}
        <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.07)', borderRadius: '12px', padding: '20px 22px', backdropFilter: 'blur(12px)', overflow: 'hidden' }}>
          <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: '14px' }}>
            Recent Activity
          </div>
          <div style={{ fontSize: 12, color: '#3a3a3c', textAlign: 'center' as const, paddingTop: 20 }}>No recent activity.</div>
        </div>

      </div>

      {/* YOUR INVENTORY */}
      <div>
        <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: '12px' }}>
          Your Inventory
        </div>

        <div style={{ display: 'flex', gap: '8px', marginBottom: '16px', flexWrap: 'wrap' as const }}>
          <input
            placeholder={dashboardInventorySearchPlaceholder(usageType)}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') void loadItems(); }}
            style={{ flex: 1, minWidth: 180, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '9px 14px', fontSize: 13, color: '#f5f5f7', letterSpacing: '-0.01em', outline: 'none' }}
          />
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '9px 14px', color: '#f5f5f7', fontSize: 13, outline: 'none', letterSpacing: '-0.01em' }}
          >
            <option value="">All categories</option>
            {categories.map((c: string) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
          <button type="button" onClick={() => void loadItems()} disabled={loading} style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 8, padding: '8px 16px', fontSize: 13, fontWeight: 510, cursor: 'pointer', opacity: loading ? 0.4 : 1, fontFamily: 'inherit' }}>Search</button>
          <button type="button" onClick={() => { setQuery(''); setCategoryFilter(''); setItems(allItems); void loadItems(token || undefined, ''); }} disabled={loading} style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '8px 14px', fontSize: 13, color: '#a1a1a6', cursor: 'pointer', opacity: loading ? 0.4 : 1, fontFamily: 'inherit' }}>Clear</button>
        </div>

        {error ? <p style={{ fontSize: 13, color: '#ff453a', marginBottom: 12 }}>{error}</p> : null}

        {allItems.length === 0 && !loading ? (
          <div style={{ textAlign: 'center' as const, padding: '48px 24px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px dashed rgba(255,255,255,0.08)', marginTop: '8px' }}>
            <div style={{ fontSize: '13px', fontWeight: 590, color: '#f5f5f7', marginBottom: '6px' }}>Your inventory is empty</div>
            <div style={{ fontSize: '13px', color: '#6e6e73', marginBottom: '20px' }}>Add your first item using the quick actions above.</div>
          </div>
        ) : null}

        {visibleItems.length > 0 && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 56px 1fr 130px', gap: '12px', paddingBottom: '10px', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
              {['Name', 'Category', 'Qty', 'Location', 'Actions'].map((h) => (
                <div key={h} style={{ fontSize: '10px', fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73' }}>{h}</div>
              ))}
            </div>

            {(visibleItems ?? []).map((it) => (
              <div key={it.item_id} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 56px 1fr 130px', gap: '12px', padding: '11px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
                <div style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>{it.name}</div>
                <div><span style={{ fontSize: 11, padding: '2px 8px', background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 99, color: '#a1a1a6', display: 'inline-block' }}>{it.category}</span></div>
                <div style={{ fontSize: 13, fontWeight: 590, color: it.quantity <= 1 ? '#ffd60a' : '#f5f5f7' }}>{it.quantity}</div>
                <div style={{ fontSize: 12, color: '#6e6e73', letterSpacing: '-0.01em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>{it.location}</div>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' as const }}>
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

        {visibleItems.length === 0 && (allItems.length > 0 || loading) ? (
          <div style={{ fontSize: 13, color: '#3a3a3c', textAlign: 'center' as const, padding: '40px 0' }}>
            {loading ? 'Loading\u2026' : 'No items match your search.'}
          </div>
        ) : null}
      </div>

    </div>


    {/* ── ALL DIALOGS (outside the padding div) ── */}

    {/* Upload Image / Multi-item dialog */}
    <Dialog open={multiOpen} onOpenChange={setMultiOpen}>
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

    {/* Barcode scanner dialog */}
    <Dialog open={scannerOpen} onOpenChange={setScannerOpen}>
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

    {/* Add Item dialog */}
    <Dialog open={createOpen} onOpenChange={setCreateOpen}>
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

    {/* Edit Item dialog */}
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

    </>
  );
}
