"use client";

import { useEffect, useMemo, useState } from "react";

import type { InventoryItem } from "@/lib/api";
import { searchItems } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

type SmartKind = "home" | "before_i_buy" | "restock_essentials";

type BeforeIBuySnapshot = {
  exactCount: number;
  similarCount: number;
  usedAtMs: number;
  query: string;
};

type RestockSnapshot = {
  lowOrEmptyCount: number;
  forgottenCount: number;
  usedAtMs: number;
};

type RestockDismissedStore = Record<string, { dismissed_at_ms: number; qty: number | null }>;

type RestockHistoryStore = Record<
  string,
  {
    first_seen_at_ms: number;
    last_seen_at_ms: number;
    seen_count: number;
    first_seen_day: number;
    last_seen_day: number;
    last_qty: number | null;
  }
>;

type BeforeIBuyMatch = {
  item: InventoryItem;
  reasons: string[];
  kind: "exact" | "similar";
};

function formatRelativeOrDateMs(ms: number | null): string {
  if (!ms) return "—";
  const d = new Date(ms);
  const delta = Date.now() - ms;
  const minutes = Math.floor(delta / (60 * 1000));
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 14) return `${days}d ago`;
  return d.toLocaleDateString();
}

function safeLocalStorageGet<T>(key: string): T | null {
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return null;
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

function safeLocalStorageSet(key: string, value: unknown) {
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // ignore
  }
}

function tokenize(s: string): string[] {
  return (s || "")
    .toLowerCase()
    .split(/[^a-z0-9]+/g)
    .map((t) => t.trim())
    .filter(Boolean);
}

function normalizeToken(t: string): string {
  const s = (t || "").trim().toLowerCase();
  if (!s) return "";
  if (s.length > 4 && s.endsWith("ies")) return `${s.slice(0, -3)}y`;
  if (s.length > 4 && s.endsWith("es")) return s.slice(0, -2);
  if (s.length > 3 && s.endsWith("s")) return s.slice(0, -1);
  return s;
}

function tokenSet(s: string): Set<string> {
  const stop = new Set([
    "a",
    "an",
    "the",
    "to",
    "for",
    "of",
    "and",
    "or",
    "in",
    "on",
    "with",
    "my",
    "your",
    "buy",
    "before",
    "i",
    "me",
  ]);
  const out = new Set<string>();
  for (const raw of tokenize(s)) {
    const t = normalizeToken(raw);
    if (!t) continue;
    if (t.length < 3) continue;
    if (stop.has(t)) continue;
    out.add(t);
  }
  return out;
}

function intersectionCount(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let n = 0;
  for (const t of a) {
    if (b.has(t)) n += 1;
  }
  return n;
}

const CATEGORY_DOMAINS: Record<string, string[]> = {
  food: ["food", "grocery", "snack", "pantry", "cereal", "pasta", "rice", "spice", "coffee", "tea"],
  drink: ["drink", "beverage", "soda", "juice", "water"],
  cleaning: ["clean", "cleaner", "soap", "detergent", "bleach", "disinfect", "wipe", "paper", "towel", "trash"],
  bathroom: ["bath", "toilet", "shower", "tissue", "deodorant", "shampoo", "conditioner", "tooth", "dental"],
  personal_care: ["skincare", "lotion", "cream", "razor", "makeup", "cosmetic", "sunscreen"],
  health: ["health", "medical", "medicine", "vitamin", "first", "aid", "bandage"],
  tools: ["tool", "hardware", "hammer", "screw", "driver", "wrench", "drill", "tape", "measure"],
  home_improvement: ["paint", "roller", "brush", "caulk", "glue", "adhesive"],
  office: ["office", "paper", "pen", "pencil", "marker", "notebook", "staple", "tape"],
  electronics: ["electronic", "cable", "charger", "battery", "usb", "adapter", "hdmi"],
  baby: ["baby", "diaper", "wipe", "formula"],
  pet: ["pet", "dog", "cat", "litter", "treat"],
  kitchen: ["kitchen", "cook", "bake", "utensil", "knife", "pan", "pot", "dish"],
  laundry: ["laundry", "dryer", "washer", "softener"],
  clothing: ["clothing", "shirt", "pant", "sock", "shoe", "jacket"],
};

const LOCATION_DOMAINS: Record<string, string[]> = {
  kitchen: ["kitchen", "counter", "cabinet", "drawer"],
  pantry: ["pantry"],
  fridge: ["fridge", "refrigerator"],
  freezer: ["freezer"],
  bathroom: ["bath", "bathroom"],
  bedroom: ["bed", "bedroom"],
  closet: ["closet"],
  laundry: ["laundry"],
  garage: ["garage"],
  storage: ["storage", "shed", "basement", "attic", "bin", "box"],
  office: ["office", "desk"],
};

function domainsForTokens(tokens: Set<string>, domains: Record<string, string[]>): Set<string> {
  const out = new Set<string>();
  for (const [domain, keys] of Object.entries(domains)) {
    for (const k of keys) {
      if (tokens.has(normalizeToken(k))) {
        out.add(domain);
        break;
      }
    }
  }
  return out;
}

function setIntersects(a: Set<string>, b: Set<string>): boolean {
  if (a.size === 0 || b.size === 0) return false;
  for (const v of a) {
    if (b.has(v)) return true;
  }
  return false;
}

function normalize(s: string): string {
  return (s || "").trim().toLowerCase();
}

function dayBucket(ms: number): number {
  return Math.floor(ms / (24 * 60 * 60 * 1000));
}

function loadDismissedRestock(): RestockDismissedStore {
  const raw = safeLocalStorageGet<RestockDismissedStore>("findez.restock.dismissed");
  if (!raw || typeof raw !== "object") return {};
  return raw;
}

function saveDismissedRestock(store: RestockDismissedStore) {
  safeLocalStorageSet("findez.restock.dismissed", store);
}

function loadRestockHistory(): RestockHistoryStore {
  const raw = safeLocalStorageGet<RestockHistoryStore>("findez.restock.history");
  if (!raw || typeof raw !== "object") return {};
  return raw;
}

function saveRestockHistory(store: RestockHistoryStore) {
  safeLocalStorageSet("findez.restock.history", store);
}

function isDismissedActive(
  entry: { dismissed_at_ms: number; qty: number | null } | undefined,
  qty: number | null,
  nowMs: number
): boolean {
  if (!entry) return false;
  const ttlMs = 24 * 60 * 60 * 1000;
  if (nowMs - entry.dismissed_at_ms >= ttlMs) return false;
  if (entry.qty != null && qty != null && entry.qty !== qty) return false;
  return true;
}

export function CollectionsClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [view, setView] = useState<SmartKind>("home");

  const beforeKey = "findez.smart_collections.before_i_buy";
  const restockKey = "findez.smart_collections.restock_essentials";

  const [beforeSnapshot, setBeforeSnapshot] = useState<BeforeIBuySnapshot | null>(null);
  const [restockSnapshot, setRestockSnapshot] = useState<RestockSnapshot | null>(null);

  const [beforeQuery, setBeforeQuery] = useState("");
  const [beforeResults, setBeforeResults] = useState<BeforeIBuyMatch[] | null>(null);

  const [restockUrgent, setRestockUrgent] = useState<InventoryItem[] | null>(null);
  const [restockSoon, setRestockSoon] = useState<InventoryItem[] | null>(null);
  const [restockForgotten, setRestockForgotten] = useState<InventoryItem[] | null>(null);

  const [dismissalsEnabled, setDismissalsEnabled] = useState(true);
  const [restockRemoving, setRestockRemoving] = useState<Record<string, boolean>>({});
  const [restockMenuOpen, setRestockMenuOpen] = useState<Record<string, boolean>>({});

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return fallback;
  }

  async function refreshToken(): Promise<string> {
    try {
      const supabase = createSupabaseBrowserClient()
      const { data: { session } } = await supabase.auth.getSession()
      return session?.access_token ?? ''
    } catch {
      return ''
    }
  }

  async function loadSnapshots() {
    const before = safeLocalStorageGet<BeforeIBuySnapshot>(beforeKey);
    const restock = safeLocalStorageGet<RestockSnapshot>(restockKey);
    setBeforeSnapshot(before);
    setRestockSnapshot(restock);

    try {
      const probeKey = "findez.restock._probe";
      window.localStorage.setItem(probeKey, JSON.stringify({ t: Date.now() }));
      window.localStorage.removeItem(probeKey);
      setDismissalsEnabled(true);
    } catch {
      setDismissalsEnabled(false);
    }
  }

  function dismissRestockItem(item: InventoryItem) {
    if (!dismissalsEnabled) return;
    const nowMs = Date.now();
    const qty = item.quantity ?? null;

    setRestockRemoving((prev) => ({ ...prev, [item.item_id]: true }));

    window.setTimeout(() => {
      saveDismissedRestock({
        ...loadDismissedRestock(),
        [item.item_id]: { dismissed_at_ms: nowMs, qty },
      });

      setRestockUrgent((prev) => (prev ? prev.filter((i) => i.item_id !== item.item_id) : prev));
      setRestockSoon((prev) => (prev ? prev.filter((i) => i.item_id !== item.item_id) : prev));
      setRestockForgotten((prev) => (prev ? prev.filter((i) => i.item_id !== item.item_id) : prev));

      setRestockRemoving((prev) => {
        const next = { ...prev };
        delete next[item.item_id];
        return next;
      });
      setRestockMenuOpen((prev) => ({ ...prev, [item.item_id]: false }));
    }, 220);
  }

  async function runBeforeIBuy(currentToken: string, query: string) {
    const q = query.trim();
    if (!q) return;
    setError(null);
    setLoading(true);
    try {
      const intentRes = await searchItems({ token: currentToken, query: q });
      const allRes = await searchItems({ token: currentToken, query: "" });

      const queryTokens = tokenSet(q);
      const parsed = (intentRes as unknown as { parsed?: Record<string, unknown> }).parsed;
      const parsedStrings: string[] = [];
      if (parsed && typeof parsed === "object") {
        for (const v of Object.values(parsed)) {
          if (typeof v === "string") parsedStrings.push(v);
        }
      }
      const parsedTokens = tokenSet(parsedStrings.join(" "));
      const intentTokens = new Set<string>([...queryTokens, ...parsedTokens]);

      const intentCategoryDomains = domainsForTokens(intentTokens, CATEGORY_DOMAINS);
      const intentLocationDomains = domainsForTokens(intentTokens, LOCATION_DOMAINS);

      const matches: BeforeIBuyMatch[] = [];
      for (const it of (allRes.items ?? [])) {
        const nameNorm = normalize(it.name);
        const categoryNorm = normalize(it.category);
        const locationNorm = normalize(it.location);
        const reasons: string[] = [];

        const exact = nameNorm === normalize(q);
        if (exact) reasons.push("Exact name match");

        const nameTokens = tokenSet(it.name);
        const categoryTokens = tokenSet(it.category || "");
        const locationTokens = tokenSet(it.location || "");

        const nameOverlap = intersectionCount(nameTokens, intentTokens);
        if (nameOverlap > 0) reasons.push("Name overlaps your intent");

        const categoryOverlap = intersectionCount(categoryTokens, intentTokens);
        if (categoryOverlap > 0) reasons.push("Category overlaps your intent");

        const locationOverlap = intersectionCount(locationTokens, intentTokens);
        if (locationOverlap > 0) reasons.push("Location overlaps your intent");

        const categoryDomains = domainsForTokens(categoryTokens, CATEGORY_DOMAINS);
        if (setIntersects(categoryDomains, intentCategoryDomains)) reasons.push("Category overlaps your intent");

        const locationDomains = domainsForTokens(locationTokens, LOCATION_DOMAINS);
        if (setIntersects(locationDomains, intentLocationDomains)) reasons.push("Location overlaps your intent");

        const parsedCategoryHit =
          parsedTokens.size > 0 &&
          (intersectionCount(categoryTokens, parsedTokens) > 0 ||
            (categoryNorm && [...parsedTokens].some((t) => categoryNorm.includes(t))));
        if (parsedCategoryHit) reasons.push("Related by search");

        const parsedLocationHit =
          parsedTokens.size > 0 &&
          (intersectionCount(locationTokens, parsedTokens) > 0 ||
            (locationNorm && [...parsedTokens].some((t) => locationNorm.includes(t))));
        if (parsedLocationHit) reasons.push("Related by search");

        const shouldInclude = exact || reasons.length > 0;
        if (!shouldInclude) continue;

        if (!exact && reasons.length === 0) reasons.push("Related by search");

        const kind: "exact" | "similar" = exact ? "exact" : "similar";
        matches.push({ item: it, reasons, kind });
      }

      matches.sort((a, b) => {
        if (a.kind !== b.kind) return a.kind === "exact" ? -1 : 1;
        return (a.item.name || "").localeCompare(b.item.name || "");
      });

      const exactCount = matches.filter((m) => m.kind === "exact").length;
      const similarCount = matches.filter((m) => m.kind === "similar").length;
      const snap: BeforeIBuySnapshot = { exactCount, similarCount, usedAtMs: Date.now(), query: q };
      safeLocalStorageSet(beforeKey, snap);
      setBeforeSnapshot(snap);
      setBeforeResults(matches);
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to analyze"));
    } finally {
      setLoading(false);
    }
  }

  async function runRestock(currentToken: string) {
    setError(null);
    setLoading(true);
    try {
      const res = await searchItems({ token: currentToken, query: "" });
      const nowMs = Date.now();
      const dismissed = loadDismissedRestock();

      const lowOrEmptyRaw = (res.items ?? []).filter((i) => (i.quantity ?? 0) <= 1);
      const visibleLowOrEmpty = lowOrEmptyRaw.filter((i) => !isDismissedActive(dismissed[i.item_id], i.quantity ?? null, nowMs));
      const urgent = visibleLowOrEmpty.filter((i) => (i.quantity ?? 0) <= 0);
      const soon = visibleLowOrEmpty.filter((i) => (i.quantity ?? 0) === 1);

      const history = loadRestockHistory();
      const nowDay = dayBucket(nowMs);
      for (const it of visibleLowOrEmpty) {
        const prev = history[it.item_id];
        if (!prev) {
          history[it.item_id] = {
            first_seen_at_ms: nowMs,
            last_seen_at_ms: nowMs,
            seen_count: 1,
            first_seen_day: nowDay,
            last_seen_day: nowDay,
            last_qty: it.quantity ?? null,
          };
        } else {
          history[it.item_id] = {
            ...prev,
            last_seen_at_ms: nowMs,
            last_seen_day: nowDay,
            seen_count: prev.last_seen_day === nowDay ? prev.seen_count : prev.seen_count + 1,
            last_qty: it.quantity ?? null,
          };
        }
      }
      saveRestockHistory(history);

      const forgotten = visibleLowOrEmpty
        .filter((it) => {
          const h = history[it.item_id];
          if (!h) return false;
          if (h.seen_count < 2) return false;
          return h.last_seen_day > h.first_seen_day || nowMs - h.first_seen_at_ms >= 24 * 60 * 60 * 1000;
        })
        .slice(0, 12);

      setRestockUrgent(urgent);
      setRestockSoon(soon);
      setRestockForgotten(forgotten);

      const snap: RestockSnapshot = {
        lowOrEmptyCount: urgent.length + soon.length,
        forgottenCount: forgotten.length,
        usedAtMs: Date.now(),
      };
      safeLocalStorageSet(restockKey, snap);
      setRestockSnapshot(snap);
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to analyze"));
    } finally {
      setLoading(false);
    }
  }

  async function load(currentToken?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      await loadSnapshots();
      return t;
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to load collections"));
      return null;
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refreshToken().then((t) => load(t)).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (error) {
    return <p className="text-sm text-destructive">{error}</p>;
  }

  if (loading && !beforeSnapshot && !restockSnapshot && view === "home") {
    return <p className="text-sm text-muted-foreground">Loading collections…</p>;
  }

  const FONT = "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif";

  if (view === "before_i_buy") {
    const lastUsed = beforeSnapshot?.usedAtMs ?? null;

    return (
      <div style={{ padding: '36px 40px', maxWidth: '700px', fontFamily: FONT, WebkitFontSmoothing: 'antialiased' as any }}>

        {/* Top row */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
          <button
            type="button"
            onClick={() => setView("home")}
            style={{ fontSize: 12, color: '#6e6e73', background: 'transparent', border: '1px solid #1c1c1e', borderRadius: 6, padding: '6px 12px', cursor: 'pointer', fontFamily: 'inherit' }}
          >
            ← Back
          </button>
          <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: '-0.03em', color: '#f5f5f7' }}>Before I Buy</div>
          <div style={{ width: 60 }} />
        </div>

        {/* Input card */}
        <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '24px 24px', marginBottom: 16 }}>
          <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as any, color: '#6e6e73', marginBottom: 10 }}>
            What are you planning to buy?
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <input
              value={beforeQuery}
              onChange={(e) => setBeforeQuery(e.target.value)}
              placeholder="e.g. AA batteries, hammer, dish soap"
              style={{ flex: 1, background: '#111113', border: '1px solid #1c1c1e', borderRadius: 8, padding: '10px 14px', fontSize: 13, color: '#f5f5f7', outline: 'none', fontFamily: 'inherit', letterSpacing: '-0.01em' }}
            />
            <button
              type="button"
              disabled={loading || !beforeQuery.trim()}
              onClick={async () => {
                const t = token || (await refreshToken());
                if (!t) return;
                await runBeforeIBuy(t, beforeQuery);
              }}
              style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 8, padding: '10px 20px', fontSize: 13, fontWeight: 510, cursor: loading || !beforeQuery.trim() ? 'not-allowed' : 'pointer', fontFamily: 'inherit', whiteSpace: 'nowrap' as any, opacity: loading || !beforeQuery.trim() ? 0.5 : 1 }}
            >
              Analyze →
            </button>
          </div>
          <div style={{ fontSize: 11, color: '#3a3a3c', marginTop: 8 }}>
            Last used: {formatRelativeOrDateMs(lastUsed)}
          </div>
        </div>

        {/* Results card */}
        {beforeResults ? (
          <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '20px 24px' }}>
            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as any, color: '#6e6e73', marginBottom: 14 }}>
              Results
            </div>
            {beforeResults.length === 0 ? (
              <div style={{ fontSize: 12, color: '#3a3a3c', padding: '16px 0', textAlign: 'center' as any }}>No matches found.</div>
            ) : (
              beforeResults.map((r) => (
                <div key={r.item.item_id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em' }}>{r.item.name}</div>
                    <div style={{ fontSize: 11, color: '#6e6e73' }}>Qty {r.item.quantity} · {r.item.location}</div>
                  </div>
                  <span style={{ fontSize: 11, padding: '2px 8px', background: '#1c1c1e', borderRadius: 99, color: '#a1a1a6' }}>
                    {r.kind === 'exact' ? 'exact' : r.item.category}
                  </span>
                </div>
              ))
            )}
            <div style={{ fontSize: 11, color: '#3a3a3c', marginTop: 12 }}>
              {beforeResults.filter((r) => r.kind === "exact").length} exact · {beforeResults.filter((r) => r.kind === "similar").length} similar
            </div>
          </div>
        ) : null}
      </div>
    );
  }

  if (view === "restock_essentials") {
    const lastUsed = restockSnapshot?.usedAtMs ?? null;

    const restockItemRow = (it: InventoryItem, removing: boolean, menuOpen: boolean) => (
      <div
        key={it.item_id}
        style={{ overflow: 'hidden', maxHeight: removing ? 0 : 80, opacity: removing ? 0 : 1, transition: 'max-height 0.2s ease-out, opacity 0.2s ease-out' }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: removing ? '0' : '8px 0', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
          <div>
            <div style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em' }}>{it.name}</div>
            <div style={{ fontSize: 11, color: '#6e6e73' }}>{it.location}</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
            {dismissalsEnabled ? (
              <button
                type="button"
                disabled={removing}
                onClick={() => dismissRestockItem(it)}
                style={{ fontSize: 11, color: '#6e6e73', background: 'transparent', border: '1px solid #1c1c1e', borderRadius: 4, padding: '2px 8px', cursor: 'pointer', fontFamily: 'inherit' }}
              >
                +1
              </button>
            ) : null}
            {dismissalsEnabled ? (
              <div style={{ position: 'relative' }}>
                <button
                  type="button"
                  style={{ fontSize: 11, color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: '2px 4px' }}
                  aria-label="More"
                  onClick={() => setRestockMenuOpen((prev) => ({ ...prev, [it.item_id]: !prev[it.item_id] }))}
                >
                  ⋯
                </button>
                {menuOpen ? (
                  <div style={{ position: 'absolute', right: 0, top: 24, zIndex: 50, width: 160, background: '#111113', border: '1px solid #2c2c2e', borderRadius: 8, padding: 4, boxShadow: '0 8px 24px rgba(0,0,0,0.4)' }}>
                    <button
                      type="button"
                      style={{ width: '100%', textAlign: 'left' as any, background: 'none', border: 'none', padding: '8px 10px', fontSize: 12, color: '#f5f5f7', cursor: 'pointer', borderRadius: 4 }}
                      onClick={() => dismissRestockItem(it)}
                      onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = '#1c1c1e'; }}
                      onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'none'; }}
                    >
                      Remove from this list
                    </button>
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
        </div>
      </div>
    );

    return (
      <div style={{ padding: '36px 40px', maxWidth: '900px', fontFamily: FONT, WebkitFontSmoothing: 'antialiased' as any }}>

        {/* Top row */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
          <button
            type="button"
            onClick={() => setView("home")}
            style={{ fontSize: 12, color: '#6e6e73', background: 'transparent', border: '1px solid #1c1c1e', borderRadius: 6, padding: '6px 12px', cursor: 'pointer', fontFamily: 'inherit' }}
          >
            ← Back
          </button>
          <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: '-0.03em', color: '#f5f5f7' }}>Restock Essentials</div>
          <button
            type="button"
            disabled={loading}
            onClick={async () => {
              const t = token || (await refreshToken());
              if (!t) return;
              await runRestock(t);
            }}
            style={{ fontSize: 12, color: '#a1a1a6', background: 'transparent', border: '1px solid #1c1c1e', borderRadius: 6, padding: '6px 14px', cursor: loading ? 'not-allowed' : 'pointer', fontFamily: 'inherit', opacity: loading ? 0.5 : 1 }}
          >
            Refresh
          </button>
        </div>

        <div style={{ fontSize: 13, color: '#6e6e73', marginBottom: 24, letterSpacing: '-0.01em' }}>
          A quick checklist of what’s low or empty. · Last used: {formatRelativeOrDateMs(lastUsed)}
        </div>

        {/* Two column grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
          <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '20px 22px' }}>
            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as any, color: '#ff453a', marginBottom: 4 }}>Urgent</div>
            <div style={{ fontSize: 11, color: '#6e6e73', marginBottom: 16 }}>Quantity is 0</div>
            {(restockUrgent ?? []).length === 0 ? (
              <div style={{ fontSize: 12, color: '#3a3a3c', padding: '16px 0', textAlign: 'center' as any }}>Nothing urgent right now.</div>
            ) : null}
            {(restockUrgent ?? []).map((it) => {
              const removing = !!restockRemoving[it.item_id];
              const menuOpen = !!restockMenuOpen[it.item_id];
              return restockItemRow(it, removing, menuOpen);
            })}
          </div>
          <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '20px 22px' }}>
            <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as any, color: '#ffd60a', marginBottom: 4 }}>Running Low</div>
            <div style={{ fontSize: 11, color: '#6e6e73', marginBottom: 16 }}>Quantity is 1</div>
            {(restockSoon ?? []).length === 0 ? (
              <div style={{ fontSize: 12, color: '#3a3a3c', padding: '16px 0', textAlign: 'center' as any }}>Nothing low right now.</div>
            ) : null}
            {(restockSoon ?? []).map((it) => {
              const removing = !!restockRemoving[it.item_id];
              const menuOpen = !!restockMenuOpen[it.item_id];
              return restockItemRow(it, removing, menuOpen);
            })}
          </div>
        </div>

        {/* Frequently Forgotten */}
        <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '20px 22px' }}>
          <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as any, color: '#6e6e73', marginBottom: 4 }}>Frequently Forgotten</div>
          <div style={{ fontSize: 11, color: '#6e6e73', marginBottom: 14 }}>Low or empty items sitting in your inventory for a while.</div>
          {(restockForgotten ?? []).length === 0 ? (
            <div style={{ fontSize: 12, color: '#3a3a3c', textAlign: 'center' as any, padding: '16px 0' }}>None flagged.</div>
          ) : null}
          {(restockForgotten ?? []).slice(0, 12).map((it) => {
            const removing = !!restockRemoving[it.item_id];
            const menuOpen = !!restockMenuOpen[it.item_id];
            return restockItemRow(it, removing, menuOpen);
          })}
        </div>
      </div>
    );
  }


  return (
    <div style={{ padding: '36px 40px', maxWidth: '1100px', fontFamily: FONT, WebkitFontSmoothing: 'antialiased' as any }}>
      {error ? <p style={{ fontSize: 13, color: '#ff453a', marginBottom: 16 }}>{error}</p> : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 12 }}>

        {/* Before I Buy */}
        <div
          style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '24px 24px', display: 'flex', flexDirection: 'column', minHeight: 200, cursor: 'pointer', transition: 'border-color 0.16s' }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#2c2c2e'; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#1c1c1e'; }}
        >
          <div style={{ fontSize: 20, marginBottom: 14, color: '#3a3a3c' }}>🛒</div>
          <div style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: '#fff', marginBottom: 6 }}>Before I Buy</div>
          <div style={{ fontSize: 13, color: '#6e6e73', lineHeight: 1.55, letterSpacing: '-0.01em', flex: 1 }}>Check if you already own something before purchasing.</div>
          <div style={{ fontSize: 11, color: '#3a3a3c', marginTop: 10, letterSpacing: '-0.005em' }}>
            Last used: {formatRelativeOrDateMs(beforeSnapshot?.usedAtMs ?? null)}
            {beforeSnapshot
              ? ` · ${beforeSnapshot.similarCount + beforeSnapshot.exactCount} related · ${beforeSnapshot.exactCount} exact`
              : ' · Saves money. Avoids duplicates.'}
          </div>
          <div style={{ marginTop: 'auto', paddingTop: 18 }}>
            <button
              type="button"
              style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 6, padding: '8px 18px', fontSize: 12, fontWeight: 510, cursor: 'pointer', letterSpacing: '-0.015em', fontFamily: 'inherit' }}
              onClick={() => {
                setBeforeResults(null);
                setBeforeQuery(beforeSnapshot?.query || "");
                setView("before_i_buy");
              }}
            >
              Explore →
            </button>
          </div>
        </div>

        {/* Restock Essentials */}
        <div
          style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 12, padding: '24px 24px', display: 'flex', flexDirection: 'column', minHeight: 200, cursor: 'pointer', transition: 'border-color 0.16s' }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#2c2c2e'; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.borderColor = '#1c1c1e'; }}
        >
          <div style={{ fontSize: 20, marginBottom: 14, color: '#3a3a3c' }}>⚠️</div>
          <div style={{ fontSize: 16, fontWeight: 590, letterSpacing: '-0.025em', color: '#fff', marginBottom: 6 }}>Restock Essentials</div>
          <div style={{ fontSize: 13, color: '#6e6e73', lineHeight: 1.55, letterSpacing: '-0.01em', flex: 1 }}>What do you need right now?</div>
          <div style={{ fontSize: 11, color: '#3a3a3c', marginTop: 10, letterSpacing: '-0.005em' }}>
            Last used: {formatRelativeOrDateMs(restockSnapshot?.usedAtMs ?? null)}
            {restockSnapshot
              ? ` · ${restockSnapshot.lowOrEmptyCount} low/empty · ${restockSnapshot.forgottenCount} forgotten`
              : ' · See low and empty items as a checklist.'}
          </div>
          <div style={{ marginTop: 'auto', paddingTop: 18 }}>
            <button
              type="button"
              style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 6, padding: '8px 18px', fontSize: 12, fontWeight: 510, cursor: 'pointer', letterSpacing: '-0.015em', fontFamily: 'inherit' }}
              onClick={async () => {
                setView("restock_essentials");
                const t = token || (await refreshToken());
                await runRestock(t);
              }}
            >
              Explore →
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}
