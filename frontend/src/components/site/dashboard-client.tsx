"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  ArrowRight,
  Boxes,
  FolderOpen,
  ScanLine,
} from "lucide-react";
import {
  InventoryItem,
  Space,
  getSpaces,
  searchItems,
} from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

export function DashboardClient() {
  const { token } = useApiSession();
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [spaces, setSpaces] = useState<Space[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!token) return;
    Promise.all([
      searchItems({ token, query: "" }),
      getSpaces({ token }),
    ])
      .then(([inventory, spaceRows]) => {
        setItems(inventory.items ?? []);
        setSpaces(spaceRows);
      })
      .catch(() => setError("Your overview could not be loaded. Try refreshing the page."))
      .finally(() => setLoading(false));
  }, [token]);

  const lowStock = useMemo(
    () => items.filter((item) => item.quantity <= 1).sort((a, b) => a.quantity - b.quantity),
    [items],
  );

  const totalUnits = useMemo(
    () => items.reduce((total, item) => total + Math.max(0, Number(item.quantity) || 0), 0),
    [items],
  );

  const spaceCount = useMemo(() => {
    const names = new Set(spaces.map((space) => space.name.trim().toLowerCase()).filter(Boolean));
    items.forEach((item) => names.add((item.location || "Unsorted").trim().toLowerCase()));
    return names.size;
  }, [items, spaces]);

  return (
    <section className="product-page overview-page">
      <header className="product-page-header">
        <div><h1>Overview</h1><p>{loading ? "Your inventory at a glance." : `${items.length} items across ${spaceCount} ${spaceCount === 1 ? "Space" : "Spaces"}.`}</p></div>
        <div className="product-actions">
          <Link className="product-button" href="/scan"><ScanLine size={15} />Scan or import</Link>
          <Link className="product-button primary" href="/inventory">Open inventory <ArrowRight size={15} /></Link>
        </div>
      </header>

      {error && <div className="notice-error">{error}</div>}

      <div className="overview-stats" aria-busy={loading}>
        <article className="product-card"><Boxes size={18} /><div><strong>{loading ? "—" : items.length}</strong><span>Unique items</span></div><small>{totalUnits} total units</small></article>
        <article className="product-card"><FolderOpen size={18} /><div><strong>{loading ? "—" : spaceCount}</strong><span>My Spaces</span></div><small>Including Unsorted</small></article>
        <article className="product-card"><AlertTriangle size={18} /><div><strong>{loading ? "—" : lowStock.length}</strong><span>Low stock</span></div><small>{lowStock.length ? "Needs attention" : "All stocked"}</small></article>
      </div>

      <section className="product-card overview-attention">
        <header><div><AlertTriangle size={17} /><span><h2>{lowStock.length ? `${lowStock.length} items need attention` : "Everything is stocked"}</h2><p>{lowStock.length ? "These items are at one unit or less." : "No low-stock items right now."}</p></span></div><Link href="/inventory">View inventory <ArrowRight size={13} /></Link></header>
        {lowStock.length > 0 && <div>{lowStock.slice(0, 3).map((item) => <Link href={`/inventory?space=${encodeURIComponent(item.location || "Unsorted")}`} key={item.item_id}><span><strong>{item.name}</strong><small>{item.location || "Unsorted"}</small></span><b>{item.quantity}</b></Link>)}</div>}
      </section>
    </section>
  );
}
