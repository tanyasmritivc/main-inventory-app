"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export type HomeInventoryRow = {
  name: string;
  quantity: number;
  location: string;
  created_at: string;
};

export function HomeHouseholdFeaturesClient(props: { items: HomeInventoryRow[]; staleCutoffMs: number }) {
  const router = useRouter();
  const [query, setQuery] = useState("");

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return (props.items || [])
      .filter((it) => (it.name || "").toLowerCase().includes(q))
      .slice(0, 8);
  }, [props.items, query]);

  const lowCount = useMemo(() => {
    return (props.items || []).filter((it) => typeof it.quantity === "number" && it.quantity <= 1).length;
  }, [props.items]);

  const staleCount = useMemo(() => {
    return (props.items || []).filter((it) => {
      const ts = typeof it.created_at === "string" ? Date.parse(it.created_at) : NaN;
      return Number.isFinite(ts) && ts < props.staleCutoffMs;
    }).length;
  }, [props.items, props.staleCutoffMs]);

  const showQuickCheck = lowCount > 0 || staleCount > 0;

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Input
          placeholder="Search your tools…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />

        {filtered.length > 0 ? (
          <div className="rounded-md border">
            {filtered.map((it) => (
              <button
                key={`${it.name}-${it.location}`}
                type="button"
                className="flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm hover:bg-muted/30"
                onClick={() => router.push("/inventory")}
              >
                <span className="font-medium">{it.name}</span>
                <span className="text-muted-foreground">
                  {it.quantity} · {it.location}
                </span>
              </button>
            ))}
          </div>
        ) : null}
      </div>

      {showQuickCheck ? (
        <div className="space-y-2">
          <div className="text-sm font-medium">Quick check</div>
          <div className="space-y-1">
            {lowCount > 0 ? (
              <Link href="/inventory" className="block text-sm text-muted-foreground hover:underline">
                ⚠️ {lowCount} items are low or out of stock
              </Link>
            ) : null}
            {staleCount > 0 ? (
              <Link href="/inventory" className="block text-sm text-muted-foreground hover:underline">
                🕒 {staleCount} older items you may want to review
              </Link>
            ) : null}
          </div>
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-2">
        <Button asChild variant="outline">
          <Link href="/dashboard">Add a tool</Link>
        </Button>
        <Button asChild variant="outline">
          <Link href="/dashboard">Bulk add / scan</Link>
        </Button>
      </div>
    </div>
  );
}
