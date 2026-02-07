"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import type { InventoryItem } from "@/lib/api";
import { searchItems } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

export function HomeInventoryClient(props: { locationFilter?: string }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const [token, setToken] = useState<string | null>(null);
  const [allItems, setAllItems] = useState<InventoryItem[]>([]);
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [query, setQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
    refreshToken().then((t) => load(t, "")).catch(() => {
      setError("Authentication error. Please sign in again.");
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!query.trim()) return;
    const t = window.setTimeout(() => {
      void load(undefined, query);
    }, 400);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  const categories: string[] = Array.from(new Set(allItems.map((i) => i.category).filter(Boolean))).sort((a, b) =>
    a.localeCompare(b)
  );
  const visibleItems: InventoryItem[] = (() => {
    const byCategory = categoryFilter
      ? items.filter((i) => (i.category || "").toLowerCase() === categoryFilter.toLowerCase())
      : items;

    const loc = (props.locationFilter ?? "").trim();
    if (!loc) return byCategory;
    return byCategory.filter((i) => (i.location || "").trim().toLowerCase() === loc.toLowerCase());
  })();

  return (
    <Card>
      <CardHeader>
        <CardTitle>Inventory</CardTitle>
        <CardDescription>Search with natural language (powered by AI).</CardDescription>
      </CardHeader>
      <CardContent className="flex max-h-[70dvh] flex-col gap-4">
        <div className="flex flex-col gap-2 sm:flex-row">
          <Input
            placeholder='Try: "show me snacks" or "items low in stock"'
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") load();
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

          <Button variant="outline" onClick={() => load()} disabled={loading}>
            Search
          </Button>
          <Button
            variant="ghost"
            onClick={() => {
              setQuery("");
              setCategoryFilter("");
              setItems(allItems);
              void load(token || undefined, "");
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
              </TableRow>
            </TableHeader>
            <TableBody>
              {visibleItems.map((it) => (
                <TableRow key={it.item_id}>
                  <TableCell className="font-medium">{it.name}</TableCell>
                  <TableCell>{it.category}</TableCell>
                  <TableCell>{it.quantity}</TableCell>
                  <TableCell>{it.location}</TableCell>
                </TableRow>
              ))}

              {visibleItems.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="py-10 text-center text-sm text-muted-foreground">
                    <div className="space-y-2">
                      <div>You haven’t added any items yet.</div>
                      <div>Inventory helps you keep track of what you own and where it’s stored.</div>
                      <div>
                        <Button asChild variant="outline" size="sm">
                          <Link href="/dashboard">Add your first item</Link>
                        </Button>
                      </div>
                    </div>
                  </TableCell>
                </TableRow>
              ) : null}
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  );
}
