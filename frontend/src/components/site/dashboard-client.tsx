"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  ArrowRight,
  Boxes,
  FolderOpen,
  ScanLine,
  Sparkles,
  Users,
} from "lucide-react";
import {
  ActivityEntry,
  InventoryItem,
  Space,
  TeamData,
  getMyLimits,
  getMyTeams,
  getRecentActivity,
  getSpaces,
  searchItems,
} from "@/lib/api";
import { PILOT_COPY } from "@/lib/pilot";
import { useApiSession } from "@/lib/use-api-session";

function relativeTime(value: string) {
  const elapsed = Date.now() - new Date(value).getTime();
  const minutes = Math.max(1, Math.floor(elapsed / 60_000));
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export function DashboardClient() {
  const { token } = useApiSession();
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [spaces, setSpaces] = useState<Space[]>([]);
  const [teams, setTeams] = useState<TeamData[]>([]);
  const [activity, setActivity] = useState<ActivityEntry[]>([]);
  const [pilotNotice, setPilotNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!token) return;
    Promise.all([
      searchItems({ token, query: "" }),
      getSpaces({ token }),
      getMyTeams({ token }),
      getRecentActivity({ token, limit: 6 }),
      getMyLimits({ token }),
    ])
      .then(([inventory, spaceRows, teamRows, recent, limits]) => {
        setItems(inventory.items ?? []);
        setSpaces(spaceRows);
        setTeams(teamRows.teams ?? []);
        setActivity(recent.activities ?? []);
        if (limits.pilot_mode) setPilotNotice(limits.pilot_notice ?? PILOT_COPY.notice);
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

  return (
    <section className="product-page overview-page">
      <header className="product-page-header">
        <div><h1>Overview</h1><p>A clear snapshot of your inventory and team activity.</p></div>
        <div className="product-actions">
          <Link className="product-button" href="/scan"><ScanLine size={15} />Scan or import</Link>
          <Link className="product-button primary" href="/inventory">Open inventory <ArrowRight size={15} /></Link>
        </div>
      </header>

      {pilotNotice && <div className="overview-pilot"><span>Free pilot</span><p>{pilotNotice}</p></div>}
      {error && <div className="notice-error">{error}</div>}

      <div className="overview-stats" aria-busy={loading}>
        <article className="product-card"><Boxes size={18} /><div><strong>{loading ? "—" : items.length}</strong><span>Unique items</span></div><small>{totalUnits} total units</small></article>
        <article className="product-card"><FolderOpen size={18} /><div><strong>{loading ? "—" : spaces.length}</strong><span>My Spaces</span></div><small>{spaces.length === 1 ? spaces[0]?.name : "Personal inventory"}</small></article>
        <article className="product-card"><AlertTriangle size={18} /><div><strong>{loading ? "—" : lowStock.length}</strong><span>Low stock</span></div><small>{lowStock.length ? "Needs attention" : "All stocked"}</small></article>
        <article className="product-card"><Users size={18} /><div><strong>{loading ? "—" : teams.length}</strong><span>Teams</span></div><small>{teams.length ? "Connected workspaces" : "No teams yet"}</small></article>
      </div>

      <div className="overview-grid">
        <section className="product-card overview-section">
          <header><div><h2>Needs attention</h2><p>Items at one unit or less.</p></div><Link href="/inventory">View inventory <ArrowRight size={13} /></Link></header>
          <div className="overview-list">
            {lowStock.slice(0, 6).map((item) => <Link href={`/inventory?space=${encodeURIComponent(item.location || "Unsorted")}`} key={item.item_id}><span><strong>{item.name}</strong><small>{item.location || "Unsorted"}</small></span><b>{item.quantity}</b></Link>)}
            {!loading && lowStock.length === 0 && <div className="overview-empty"><span>Nothing is running low.</span></div>}
          </div>
        </section>

        <section className="product-card overview-section">
          <header><div><h2>Recent activity</h2><p>Latest changes across your teams.</p></div><Link href="/activity">View all <ArrowRight size={13} /></Link></header>
          <div className="overview-list activity">
            {activity.map((entry) => <div key={entry.activity_id ?? entry.id ?? `${entry.created_at}-${entry.summary}`}><span><strong>{entry.display_text || entry.summary}</strong><small>{entry.team_name || entry.activity_type || "FindEZ"}</small></span><time>{relativeTime(entry.created_at)}</time></div>)}
            {!loading && activity.length === 0 && <div className="overview-empty"><span>Team activity will appear here.</span></div>}
          </div>
        </section>
      </div>

      <section className="overview-shortcuts">
        <Link className="product-card" href="/assist"><Sparkles size={18} /><span><strong>Ask Assist</strong><small>Find items or update stock</small></span><ArrowRight size={14} /></Link>
        <Link className="product-card" href="/teams"><Users size={18} /><span><strong>Open Teams</strong><small>Spaces, board, people, and files</small></span><ArrowRight size={14} /></Link>
        <Link className="product-card" href="/project-kits"><FolderOpen size={18} /><span><strong>Check project readiness</strong><small>Compare a BOM with live inventory</small></span><ArrowRight size={14} /></Link>
      </section>
    </section>
  );
}
