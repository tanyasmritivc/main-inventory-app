"use client";

import { useEffect, useMemo, useState } from "react";

import type { InventoryItem } from "@/lib/api";
import { searchItems } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";

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

  async function refreshToken() {
    const { data, error: sessionErr } = await supabase.auth.getSession();
    if (sessionErr) throw sessionErr;
    const accessToken = data.session?.access_token;
    if (!accessToken) throw new Error("Missing session");
    setToken(accessToken);
    return accessToken;
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
      for (const it of allRes.items) {
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

      const lowOrEmptyRaw = res.items.filter((i) => (i.quantity ?? 0) <= 1);
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
    refreshToken().then((t) => load(t)).catch(() => {
      setError("Authentication error. Please sign in again.");
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (error) {
    return <p className="text-sm text-destructive">{error}</p>;
  }

  if (loading && !beforeSnapshot && !restockSnapshot && view === "home") {
    return <p className="text-sm text-muted-foreground">Loading collections…</p>;
  }

  if (view === "before_i_buy") {
    const lastUsed = beforeSnapshot?.usedAtMs ?? null;

    return (
      <div className="space-y-4">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="text-lg font-semibold tracking-tight">Before I Buy</div>
            <div className="text-sm text-muted-foreground">Type what you’re about to buy. We’ll surface what you already have.</div>
          </div>
          <Button type="button" variant="outline" onClick={() => setView("home")}>Back</Button>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">What are you planning to buy?</CardTitle>
            <CardDescription>Example: “AA batteries”, “hammer”, “dish soap”, “paint roller”.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex flex-col gap-2 sm:flex-row">
              <Input value={beforeQuery} onChange={(e) => setBeforeQuery(e.target.value)} placeholder="Type an item or intent…" />
              <Button
                type="button"
                disabled={loading || !beforeQuery.trim()}
                onClick={async () => {
                  const t = token || (await refreshToken());
                  await runBeforeIBuy(t, beforeQuery);
                }}
              >
                Analyze
              </Button>
            </div>

            <div className="text-xs text-muted-foreground">Last used: {formatRelativeOrDateMs(lastUsed)}</div>
          </CardContent>
        </Card>

        {beforeResults ? (
          <div className="grid gap-4 lg:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle className="text-base">You already have this</CardTitle>
                <CardDescription>Exact name matches.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-2 text-sm">
                {beforeResults.filter((r) => r.kind === "exact").length === 0 ? (
                  <div className="text-muted-foreground">No exact matches found.</div>
                ) : (
                  beforeResults
                    .filter((r) => r.kind === "exact")
                    .map((r) => (
                      <div key={r.item.item_id} className="rounded-md border p-3">
                        <div className="font-medium">{r.item.name}</div>
                        <div className="text-muted-foreground">Qty {r.item.quantity} • {r.item.location}</div>
                      </div>
                    ))
                )}
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-base">You have something similar</CardTitle>
                <CardDescription>Related items and functional overlaps.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-2 text-sm">
                {beforeResults.filter((r) => r.kind === "similar").length === 0 ? (
                  <div className="text-muted-foreground">No similar items found.</div>
                ) : (
                  beforeResults
                    .filter((r) => r.kind === "similar")
                    .map((r) => (
                      <div key={r.item.item_id} className="rounded-md border p-3">
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="font-medium">{r.item.name}</div>
                            <div className="text-muted-foreground">Qty {r.item.quantity} • {r.item.location}</div>
                          </div>
                          <div className="text-xs text-muted-foreground">{r.item.category}</div>
                        </div>
                        <div className="mt-2 text-xs text-muted-foreground">Why: {r.reasons.join(" • ")}</div>
                      </div>
                    ))
                )}
              </CardContent>
            </Card>
          </div>
        ) : null}
      </div>
    );
  }

  if (view === "restock_essentials") {
    const lastUsed = restockSnapshot?.usedAtMs ?? null;

    return (
      <div className="space-y-4">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="text-lg font-semibold tracking-tight">Restock Essentials</div>
            <div className="text-sm text-muted-foreground">A quick checklist of what’s low or empty.</div>
          </div>
          <div className="flex gap-2">
            <Button type="button" variant="outline" onClick={() => setView("home")}>Back</Button>
            <Button
              type="button"
              disabled={loading}
              onClick={async () => {
                const t = token || (await refreshToken());
                await runRestock(t);
              }}
            >
              Refresh
            </Button>
          </div>
        </div>

        <div className="text-xs text-muted-foreground">Last used: {formatRelativeOrDateMs(lastUsed)}</div>

        <div className="grid gap-4 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Urgent (empty)</CardTitle>
              <CardDescription>Quantity is 0.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              {(restockUrgent ?? []).length === 0 ? <div className="text-muted-foreground">Nothing urgent right now.</div> : null}
              {(restockUrgent ?? []).map((it) => {
                const removing = !!restockRemoving[it.item_id];
                const menuOpen = !!restockMenuOpen[it.item_id];

                return (
                  <div
                    key={it.item_id}
                    className={
                      "overflow-hidden rounded-md border transition-all duration-200 ease-out " +
                      (removing ? "max-h-0 opacity-0" : "max-h-24 opacity-100")
                    }
                  >
                    <div className={"flex items-center gap-2 p-3 " + (removing ? "py-0" : "")}
                      >
                      {dismissalsEnabled ? (
                        <input
                          type="checkbox"
                          className="h-4 w-4"
                          checked={false}
                          disabled={removing}
                          onChange={() => dismissRestockItem(it)}
                        />
                      ) : null}

                      <span className="flex-1">
                        <span className="font-medium">{it.name}</span>
                        <span className="ml-2 text-muted-foreground">({it.location})</span>
                      </span>

                      {dismissalsEnabled ? (
                        <div className="relative">
                          <button
                            type="button"
                            className="h-8 w-8 rounded-md border text-muted-foreground"
                            aria-label="More"
                            onClick={() =>
                              setRestockMenuOpen((prev) => ({
                                ...prev,
                                [it.item_id]: !prev[it.item_id],
                              }))
                            }
                          >
                            ⋯
                          </button>
                          {menuOpen ? (
                            <div className="absolute right-0 top-9 z-10 w-48 rounded-md border bg-background p-1 text-sm shadow">
                              <button
                                type="button"
                                className="w-full rounded-sm px-2 py-2 text-left hover:bg-muted"
                                onClick={() => dismissRestockItem(it)}
                              >
                                Remove from this list
                              </button>
                            </div>
                          ) : null}
                        </div>
                      ) : null}
                    </div>
                  </div>
                );
              })}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Soon (low)</CardTitle>
              <CardDescription>Quantity is 1.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              {(restockSoon ?? []).length === 0 ? <div className="text-muted-foreground">Nothing low right now.</div> : null}
              {(restockSoon ?? []).map((it) => {
                const removing = !!restockRemoving[it.item_id];
                const menuOpen = !!restockMenuOpen[it.item_id];

                return (
                  <div
                    key={it.item_id}
                    className={
                      "overflow-hidden rounded-md border transition-all duration-200 ease-out " +
                      (removing ? "max-h-0 opacity-0" : "max-h-24 opacity-100")
                    }
                  >
                    <div className={"flex items-center gap-2 p-3 " + (removing ? "py-0" : "")}
                      >
                      {dismissalsEnabled ? (
                        <input
                          type="checkbox"
                          className="h-4 w-4"
                          checked={false}
                          disabled={removing}
                          onChange={() => dismissRestockItem(it)}
                        />
                      ) : null}

                      <span className="flex-1">
                        <span className="font-medium">{it.name}</span>
                        <span className="ml-2 text-muted-foreground">({it.location})</span>
                      </span>

                      {dismissalsEnabled ? (
                        <div className="relative">
                          <button
                            type="button"
                            className="h-8 w-8 rounded-md border text-muted-foreground"
                            aria-label="More"
                            onClick={() =>
                              setRestockMenuOpen((prev) => ({
                                ...prev,
                                [it.item_id]: !prev[it.item_id],
                              }))
                            }
                          >
                            ⋯
                          </button>
                          {menuOpen ? (
                            <div className="absolute right-0 top-9 z-10 w-48 rounded-md border bg-background p-1 text-sm shadow">
                              <button
                                type="button"
                                className="w-full rounded-sm px-2 py-2 text-left hover:bg-muted"
                                onClick={() => dismissRestockItem(it)}
                              >
                                Remove from this list
                              </button>
                            </div>
                          ) : null}
                        </div>
                      ) : null}
                    </div>
                  </div>
                );
              })}
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Frequently forgotten</CardTitle>
            <CardDescription>Low or empty items that have been in your inventory for a while.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2 text-sm">
            {(restockForgotten ?? []).length === 0 ? <div className="text-muted-foreground">None flagged.</div> : null}
            {(restockForgotten ?? []).slice(0, 12).map((it) => {
              const removing = !!restockRemoving[it.item_id];
              const menuOpen = !!restockMenuOpen[it.item_id];

              return (
                <div
                  key={it.item_id}
                  className={
                    "overflow-hidden rounded-md border transition-all duration-200 ease-out " +
                    (removing ? "max-h-0 opacity-0" : "max-h-24 opacity-100")
                  }
                >
                  <div className={"flex items-center gap-2 p-3 " + (removing ? "py-0" : "")}
                    >
                    {dismissalsEnabled ? (
                      <input
                        type="checkbox"
                        className="h-4 w-4"
                        checked={false}
                        disabled={removing}
                        onChange={() => dismissRestockItem(it)}
                      />
                    ) : null}

                    <span className="flex-1">
                      <span className="font-medium">{it.name}</span>
                      <span className="ml-2 text-muted-foreground">(Qty {it.quantity} • {it.location})</span>
                    </span>

                    {dismissalsEnabled ? (
                      <div className="relative">
                        <button
                          type="button"
                          className="h-8 w-8 rounded-md border text-muted-foreground"
                          aria-label="More"
                          onClick={() =>
                            setRestockMenuOpen((prev) => ({
                              ...prev,
                              [it.item_id]: !prev[it.item_id],
                            }))
                          }
                        >
                          ⋯
                        </button>
                        {menuOpen ? (
                          <div className="absolute right-0 top-9 z-10 w-48 rounded-md border bg-background p-1 text-sm shadow">
                            <button
                              type="button"
                              className="w-full rounded-sm px-2 py-2 text-left hover:bg-muted"
                              onClick={() => dismissRestockItem(it)}
                            >
                              Remove from this list
                            </button>
                          </div>
                        ) : null}
                      </div>
                    ) : null}
                  </div>
                </div>
              );
            })}
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {error ? <p className="text-sm text-destructive">{error}</p> : null}

      <div className="grid gap-4 sm:grid-cols-2">
        <Card className="h-full">
          <CardHeader>
            <CardTitle className="text-base">Before I Buy</CardTitle>
            <CardDescription>Check for duplicates and overlaps before you purchase.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <div>
              Last used: {formatRelativeOrDateMs(beforeSnapshot?.usedAtMs ?? null)}
            </div>
            <div>
              {beforeSnapshot ? (
                <span>
                  {beforeSnapshot.similarCount + beforeSnapshot.exactCount} related • {beforeSnapshot.exactCount} exact
                </span>
              ) : (
                <span>Run a quick check before your next buy.</span>
              )}
            </div>
            <div>
              <Button
                type="button"
                onClick={() => {
                  setBeforeResults(null);
                  setBeforeQuery(beforeSnapshot?.query || "");
                  setView("before_i_buy");
                }}
              >
                Open
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card className="h-full">
          <CardHeader>
            <CardTitle className="text-base">Restock Essentials</CardTitle>
            <CardDescription>What do you need right now?</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <div>Last used: {formatRelativeOrDateMs(restockSnapshot?.usedAtMs ?? null)}</div>
            <div>
              {restockSnapshot ? (
                <span>
                  {restockSnapshot.lowOrEmptyCount} low/empty • {restockSnapshot.forgottenCount} forgotten
                </span>
              ) : (
                <span>See low and empty items as a checklist.</span>
              )}
            </div>
            <div>
              <Button
                type="button"
                onClick={async () => {
                  setView("restock_essentials");
                  const t = token || (await refreshToken());
                  await runRestock(t);
                }}
              >
                Open
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
