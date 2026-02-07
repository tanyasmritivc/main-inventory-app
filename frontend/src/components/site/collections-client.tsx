"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import type { InventoryItem } from "@/lib/api";
import { searchItems } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

type CollectionSummary = {
  name: string;
  itemCount: number;
  lowStockCount: number;
  lastUpdated: Date | null;
};

function formatRelativeOrDate(d: Date | null): string {
  if (!d) return "—";
  const ms = Date.now() - d.getTime();
  const minutes = Math.floor(ms / (60 * 1000));
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 14) return `${days}d ago`;
  return d.toLocaleDateString();
}

export function CollectionsClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [collections, setCollections] = useState<CollectionSummary[]>([]);

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

  function deriveCollections(items: InventoryItem[]): CollectionSummary[] {
    const byLocation = new Map<string, InventoryItem[]>();

    for (const it of items) {
      const raw = (it.location ?? "").trim();
      const key = raw || "Unsorted";
      const list = byLocation.get(key) ?? [];
      list.push(it);
      byLocation.set(key, list);
    }

    const out: CollectionSummary[] = Array.from(byLocation.entries()).map(([name, list]) => {
      let lowStockCount = 0;
      let lastUpdated: Date | null = null;

      for (const it of list) {
        if ((it.quantity ?? 0) <= 1) lowStockCount += 1;
        const created = it.created_at ? new Date(it.created_at) : null;
        if (created && (!lastUpdated || created.getTime() > lastUpdated.getTime())) {
          lastUpdated = created;
        }
      }

      return {
        name,
        itemCount: list.length,
        lowStockCount,
        lastUpdated,
      };
    });

    out.sort((a, b) => b.itemCount - a.itemCount || a.name.localeCompare(b.name));
    return out;
  }

  async function load(currentToken?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      const res = await searchItems({ token: t, query: "" });
      setCollections(deriveCollections(res.items));
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to load collections"));
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

  if (loading && collections.length === 0) {
    return <p className="text-sm text-muted-foreground">Loading collections…</p>;
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {collections.map((c) => (
        <Link key={c.name} href={`/inventory?collection=${encodeURIComponent(c.name)}`} className="block">
          <Card className="h-full transition-colors hover:bg-muted/30">
            <CardHeader>
              <CardTitle className="text-base">{c.name}</CardTitle>
              <CardDescription>
                {c.itemCount} items • {c.lowStockCount} low stock
              </CardDescription>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              Last updated: {formatRelativeOrDate(c.lastUpdated)}
            </CardContent>
          </Card>
        </Link>
      ))}

      {collections.length === 0 ? (
        <Card className="sm:col-span-2 lg:col-span-3">
          <CardHeader>
            <CardTitle className="text-base">No collections yet</CardTitle>
            <CardDescription>Add items with a location to see collections here.</CardDescription>
          </CardHeader>
        </Card>
      ) : null}
    </div>
  );
}
