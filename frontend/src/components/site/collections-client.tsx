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

function normalize(s: string): string {
  return (s || "").trim().toLowerCase();
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
  }

  async function runBeforeIBuy(currentToken: string, query: string) {
    const q = query.trim();
    if (!q) return;
    setError(null);
    setLoading(true);
    try {
      const res = await searchItems({ token: currentToken, query: q });
      const tokens = tokenize(q);

      const matches: BeforeIBuyMatch[] = [];
      for (const it of res.items) {
        const name = normalize(it.name);
        const category = normalize(it.category);
        const location = normalize(it.location);
        const reasons: string[] = [];

        const exact = name === normalize(q);
        if (exact) reasons.push("Exact name match");

        const nameHit = tokens.some((t) => t.length >= 3 && name.includes(t));
        if (nameHit) reasons.push("Name overlaps your intent");

        const categoryHit = tokens.some((t) => t.length >= 3 && category.includes(t));
        if (categoryHit) reasons.push("Category overlaps your intent");

        const locationHit = tokens.some((t) => t.length >= 3 && location.includes(t));
        if (locationHit) reasons.push("Location overlaps your intent");

        const kind: "exact" | "similar" = exact ? "exact" : "similar";
        matches.push({ item: it, reasons: reasons.length ? reasons : ["Related by search"], kind });
      }

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
      const urgent = res.items.filter((i) => (i.quantity ?? 0) <= 0);
      const soon = res.items.filter((i) => (i.quantity ?? 0) === 1);

      const cutoffMs = Date.now() - 30 * 24 * 60 * 60 * 1000;
      const forgotten = res.items.filter((i) => {
        const q = i.quantity ?? 0;
        if (q > 1) return false;
        const createdMs = i.created_at ? new Date(i.created_at).getTime() : 0;
        return createdMs > 0 && createdMs < cutoffMs;
      });

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
              {(restockUrgent ?? []).map((it) => (
                <label key={it.item_id} className="flex items-center gap-2 rounded-md border p-3">
                  <input type="checkbox" className="h-4 w-4" />
                  <span className="flex-1">
                    <span className="font-medium">{it.name}</span>
                    <span className="ml-2 text-muted-foreground">({it.location})</span>
                  </span>
                </label>
              ))}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Soon (low)</CardTitle>
              <CardDescription>Quantity is 1.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              {(restockSoon ?? []).length === 0 ? <div className="text-muted-foreground">Nothing low right now.</div> : null}
              {(restockSoon ?? []).map((it) => (
                <label key={it.item_id} className="flex items-center gap-2 rounded-md border p-3">
                  <input type="checkbox" className="h-4 w-4" />
                  <span className="flex-1">
                    <span className="font-medium">{it.name}</span>
                    <span className="ml-2 text-muted-foreground">({it.location})</span>
                  </span>
                </label>
              ))}
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
            {(restockForgotten ?? []).slice(0, 12).map((it) => (
              <div key={it.item_id} className="rounded-md border p-3">
                <div className="font-medium">{it.name}</div>
                <div className="text-muted-foreground">Qty {it.quantity} • {it.location}</div>
              </div>
            ))}
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
