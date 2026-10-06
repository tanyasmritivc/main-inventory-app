"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Bell, CheckCheck, History, RefreshCw } from "lucide-react";
import { ActivityEntry } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";

function relativeTime(value: string) {
  const seconds = Math.max(
    0,
    Math.floor((Date.now() - new Date(value).getTime()) / 1000),
  );
  if (seconds < 60) return "just now";
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

export function ActivityFeedClient({
  mode,
}: {
  mode: "activity" | "notifications";
}) {
  const { accountId } = useApiSession();
  return <ActivityWorkspace key={accountId || "signed-out"} mode={mode} />;
}
function ActivityWorkspace({ mode }: { mode: "activity" | "notifications" }) {
  const {
    accountId,
    loading: sessionLoading,
    error: sessionError,
  } = useApiSession();
  const owner = useRef(accountId);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const generation = useRef(0);
  const [marking, setMarking] = useState(false);
  const [entries, setEntries] = useState<ActivityEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [unread, setUnread] = useState(0);

  const load = useCallback(async () => {
    if (!accountId) return;
    const account = accountId,
      ticket = ++generation.current;
    setLoading(true);
    setEntries([]);
    setError(null);
    try {
      if (mode === "notifications") {
        const result = await accountRequest<{
          notifications: ActivityEntry[];
          unread_count: number;
        }>(account, "/notifications");
        if (owner.current !== account || ticket !== generation.current) return;
        setEntries(result.notifications ?? []);
        setUnread(result.unread_count ?? 0);
      } else {
        const result = await accountRequest<{ activities: ActivityEntry[] }>(
          account,
          "/activity/recent?limit=100",
        );
        if (owner.current !== account || ticket !== generation.current) return;
        setEntries(result.activities ?? []);
      }
    } catch (reason) {
      if (owner.current === account && ticket === generation.current)
        setError(userFacingError(reason, "Could not load this feed."));
    } finally {
      if (owner.current === account && ticket === generation.current)
        setLoading(false);
    }
  }, [mode, accountId]);

  useEffect(() => {
    void load();
  }, [load]);

  async function markRead() {
    if (!accountId || unread === 0 || marking) return;
    const account = accountId;
    setMarking(true);
    setError(null);
    try {
      await accountRequest(account, "/notifications/read", { method: "POST" });
      if (owner.current === account) {
        setEntries((current) =>
          current.map((entry) => ({ ...entry, is_read: true })),
        );
        setUnread(0);
      }
    } catch (reason) {
      if (owner.current === account)
        setError(
          userFacingError(reason, "Could not mark notifications as read."),
        );
    } finally {
      setMarking(false);
    }
  }

  const Icon = mode === "notifications" ? Bell : History;
  return (
    <section className="product-page">
      <header className="product-page-header">
        <h1>{mode === "notifications" ? "Notifications" : "Activity"}</h1>
        <div className="product-actions">
          {mode === "notifications" && unread > 0 && (
            <button
              className="app-icon-button"
              disabled={marking}
              aria-label="Mark all read"
              onClick={() => void markRead()}
            >
              <CheckCheck size={16} />
            </button>
          )}
          <button
            className="app-icon-button"
            aria-label="Refresh"
            onClick={() => void load()}
          >
            <RefreshCw size={16} />
          </button>
        </div>
      </header>
      {(error || sessionError) && (
        <div className="notice-error" role="alert">
          {error || sessionError}
        </div>
      )}
      <div className="activity-feed">
        {(loading || sessionLoading) && (
          <div className="bare-empty">Loading…</div>
        )}
        {!loading &&
          !sessionLoading &&
          entries.length === 0 &&
          !error &&
          !sessionError && (
            <div className="bare-empty">
              <Icon size={23} />
              <strong>Nothing here</strong>
            </div>
          )}
        {!loading &&
          entries.map((entry) => (
            <article
              className={`activity-row ${entry.is_read === false ? "is-unread" : ""}`}
              key={
                entry.activity_id ??
                entry.id ??
                `${entry.created_at}-${entry.summary}`
              }
            >
              <span className="activity-icon">
                <Icon size={15} />
              </span>
              <div>
                <div className="activity-copy">
                  {entry.display_text || entry.summary}
                </div>
                <div className="activity-meta">
                  {[
                    entry.activity_type,
                    entry.team_name,
                    relativeTime(entry.created_at),
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                </div>
              </div>
              {entry.is_read === false && (
                <span className="unread-dot" aria-label="Unread" />
              )}
            </article>
          ))}
      </div>
    </section>
  );
}
