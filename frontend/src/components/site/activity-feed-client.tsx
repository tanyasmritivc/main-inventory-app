"use client";

import { useCallback, useEffect, useState } from "react";
import { Bell, CheckCheck, History, RefreshCw } from "lucide-react";
import { ActivityEntry, getNotifications, getRecentActivity, markNotificationsRead } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

function relativeTime(value: string) {
  const seconds = Math.max(0, Math.floor((Date.now() - new Date(value).getTime()) / 1000));
  if (seconds < 60) return "just now";
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

export function ActivityFeedClient({ mode }: { mode: "activity" | "notifications" }) {
  const { token, loading: sessionLoading } = useApiSession();
  const [entries, setEntries] = useState<ActivityEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [unread, setUnread] = useState(0);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true); setError(null);
    try {
      if (mode === "notifications") {
        const result = await getNotifications({ token });
        setEntries(result.notifications ?? []); setUnread(result.unread_count ?? 0);
      } else {
        const result = await getRecentActivity({ token, limit: 100 });
        setEntries(result.activities ?? []);
      }
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Could not load this feed.");
    } finally { setLoading(false); }
  }, [mode, token]);

  useEffect(() => { void load(); }, [load]);

  async function markRead() {
    if (!token || unread === 0) return;
    await markNotificationsRead({ token });
    setEntries((current) => current.map((entry) => ({ ...entry, is_read: true })));
    setUnread(0);
  }

  const Icon = mode === "notifications" ? Bell : History;
  return (
    <section className="product-page">
      <header className="product-page-header">
        <div><h1>{mode === "notifications" ? "Notifications" : "Activity"}</h1><p>{mode === "notifications" ? "The last 14 days of team events, assignments, and inventory changes." : "A chronological audit trail of your FindEZ work."}</p></div>
        <div className="product-actions">
          {mode === "notifications" && unread > 0 && <button className="product-button" onClick={() => void markRead()}><CheckCheck size={15} />Mark all read</button>}
          <button className="product-button" onClick={() => void load()}><RefreshCw size={15} />Refresh</button>
        </div>
      </header>
      {error && <div className="notice-error">{error}</div>}
      <div className="product-card activity-feed">
        {(loading || sessionLoading) && <div className="product-empty">Loading…</div>}
        {!loading && !sessionLoading && entries.length === 0 && <div className="product-empty"><div><Icon size={25} /><strong>Nothing here yet</strong><span>New activity will appear here automatically.</span></div></div>}
        {!loading && entries.map((entry) => (
          <article className={`activity-row ${entry.is_read === false ? "is-unread" : ""}`} key={entry.activity_id ?? entry.id ?? `${entry.created_at}-${entry.summary}`}>
            <span className="activity-icon"><Icon size={15} /></span>
            <div><div className="activity-copy">{entry.display_text || entry.summary}</div><div className="activity-meta">{[entry.activity_type, entry.team_name, relativeTime(entry.created_at)].filter(Boolean).join(" · ")}</div></div>
            {entry.is_read === false && <span className="unread-dot" aria-label="Unread" />}
          </article>
        ))}
      </div>
    </section>
  );
}
