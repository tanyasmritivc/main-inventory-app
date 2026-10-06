"use client";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { ArrowUpRight, Camera, MapPin, RefreshCw, Search } from "lucide-react";
import { useRouter } from "next/navigation";
import { accountRequest } from "@/lib/account-request";
import { itemDisplayName, type InventoryItem, type Space } from "@/lib/api";
import {
  buildSpaceIndex,
  groupItemsBySpace,
  resolveDisplaySpaces,
} from "@/lib/spaces";
import { useApiSession } from "@/lib/use-api-session";
import { useRestock } from "@/lib/use-restock";
import { needsBuying, onOrder } from "@/lib/restock-plan";
export function HomeOverview() {
  const { accountId } = useApiSession();
  return <HomeOverviewWorkspace key={accountId || "signed-out"} />;
}
function HomeOverviewWorkspace() {
  const { accountId, error: sessionError } = useApiSession(),
    restock = useRestock(accountId),
    router = useRouter();
  const [checkedAt, setCheckedAt] = useState(0);
  const owner = useRef(accountId);
  const request = useRef(0);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const [data, setData] = useState<{
      items?: InventoryItem[];
      spaces?: Space[];
      review?: number;
      checkouts?: { due_back_at?: string }[];
      name?: string;
    }>({}),
    [failures, setFailures] = useState<string[]>([]),
    [loading, setLoading] = useState(true),
    [query, setQuery] = useState("");
  const load = useCallback(async () => {
    if (!accountId) return;
    const account = accountId,
      ticket = ++request.current;
    const results = await Promise.allSettled([
      accountRequest<{ items: InventoryItem[] }>(account, "/search_items", {
        method: "POST",
        body: { query: "" },
      }),
      accountRequest<Space[] | { spaces: Space[] }>(account, "/spaces"),
      accountRequest<{ pending_count: number }>(
        account,
        "/review-items?limit=1",
      ),
      accountRequest<{ checkouts: { due_back_at?: string }[] }>(
        account,
        "/checkouts/active",
      ),
      accountRequest<{ display_name?: string }>(account, "/profile/me"),
    ]);
    if (owner.current !== account || ticket !== request.current) return;
    const [inventory, spaces, review, checkouts, profile] = results;
    setData({
      items:
        inventory.status === "fulfilled" ? inventory.value.items : undefined,
      spaces:
        spaces.status === "fulfilled"
          ? Array.isArray(spaces.value)
            ? spaces.value
            : spaces.value.spaces
          : undefined,
      review:
        review.status === "fulfilled" ? review.value.pending_count : undefined,
      checkouts:
        checkouts.status === "fulfilled"
          ? checkouts.value.checkouts
          : undefined,
      name:
        profile.status === "fulfilled" ? profile.value.display_name : undefined,
    });
    setFailures(
      results
        .slice(0, 4)
        .flatMap((r, i) =>
          r.status === "rejected"
            ? [["inventory", "Spaces", "Review", "lent items"][i]]
            : [],
        ),
    );
    setCheckedAt(Date.now());
    setLoading(false);
  }, [accountId]);
  useEffect(() => {
    let active = true;
    void Promise.resolve().then(() => {
      if (active) return load();
    });
    return () => {
      active = false;
    };
  }, [load]);
  const recent = [...(data.items ?? [])]
    .sort(
      (a, b) =>
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    )
    .slice(0, 6);
  const groups = groupItemsBySpace(
      data.items ?? [],
      data.spaces ? buildSpaceIndex(data.spaces) : null,
    ),
    spaces = resolveDisplaySpaces(
      data.spaces ?? [],
      data.items ?? [],
      !data.spaces,
    );
  const overdue = data.checkouts?.filter(
    (c) => c.due_back_at && new Date(c.due_back_at).getTime() < checkedAt,
  ).length;
  const toBuy = data.items?.filter((i) =>
    needsBuying(restock.plan[i.item_id], i.quantity),
  ).length;
  const ordered = data.items?.filter((i) =>
    onOrder(restock.plan[i.item_id]),
  ).length;
  function ask(e: React.FormEvent) {
    e.preventDefault();
    if (query.trim())
      router.push(`/assist?q=${encodeURIComponent(query.trim())}`);
  }
  return (
    <section>
      <header className="workspace-heading">
        <div>
          <h1>
            {data.name
              ? `Hello, ${data.name.split(" ")[0]}.`
              : "Your physical memory"}
          </h1>
          <p>
            {data.items ? `${data.items.length} items` : "Your items"}
            {data.spaces ? ` across ${data.spaces.length} Spaces.` : "."}
          </p>
        </div>
        <div className="workspace-actions">
          <button
            className="workspace-button"
            onClick={() => {
              setLoading(true);
              setFailures([]);
              void load();
            }}
            aria-label="Refresh Home"
          >
            <RefreshCw size={15} />
          </button>
          <Link className="workspace-button primary" href="/scan">
            <Camera size={15} />
            Capture
          </Link>
        </div>
      </header>
      <form className="workspace-search" onSubmit={ask}>
        <Search size={18} />
        <input
          aria-label="Ask FindEZ"
          placeholder="Where did I put it?"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <button
          className="workspace-button"
          type="submit"
          disabled={!query.trim()}
          aria-label="Ask your question"
        >
          <ArrowUpRight size={16} />
        </button>
      </form>
      <div className="workspace-chips">
        {[
          "Where is my soldering iron?",
          "Do I already own a USB-C hub?",
          "What is missing from my project kit?",
        ].map((q) => (
          <button key={q} onClick={() => setQuery(q)}>
            {q}
          </button>
        ))}
      </div>
      {(sessionError || failures.length > 0) && (
        <div role="alert" className="workspace-error">
          {sessionError || `Could not load ${failures.join(", ")}.`}{" "}
          <button
            className="workspace-button"
            onClick={() => {
              setLoading(true);
              setFailures([]);
              void load();
            }}
          >
            Try again
          </button>
        </div>
      )}
      {loading && (
        <p role="status" className="workspace-muted">
          Loading your overview…
        </p>
      )}
      <section className="workspace-section">
        <div className="workspace-section-heading">
          <h2>Needs your attention</h2>
        </div>
        <div className="home-attention">
          <Link href="/review">
            <strong>{data.review ?? "…"}</strong>
            <span>captures to review</span>
          </Link>
          <Link href="/restock">
            <strong>{restock.ready && data.items ? toBuy : "…"}</strong>
            <span>to buy</span>
          </Link>
          <Link href="/restock">
            <strong>{restock.ready && data.items ? ordered : "…"}</strong>
            <span>on order</span>
          </Link>
          <Link href="/checkout">
            <strong>{overdue ?? "…"}</strong>
            <span>overdue lent items</span>
          </Link>
        </div>
        {restock.error && (
          <p className="workspace-error" role="alert">
            {restock.error}
          </p>
        )}
      </section>
      <section className="workspace-section">
        <div className="workspace-section-heading">
          <h2>Recently added</h2>
          <Link href="/inventory">Find all items</Link>
        </div>
        <div className="home-recent">
          {recent.map((item) => (
            <Link
              key={item.item_id}
              href={`/inventory?item=${encodeURIComponent(item.item_id)}`}
            >
              {item.image_url ? (
                <img src={item.image_url} alt={itemDisplayName(item)} />
              ) : (
                <span className="photo-placeholder">
                  <Camera size={22} />
                </span>
              )}
              <strong>{itemDisplayName(item)}</strong>
              <small>
                {item.quantity} · {item.location || "Unsorted"}
              </small>
            </Link>
          ))}
        </div>
        {data.items?.length === 0 && (
          <div className="workspace-card">
            <h2>Start with a photo</h2>
            <p className="workspace-muted">
              Capture what you have, then give it a Space.
            </p>
            <Link href="/scan" className="workspace-button">
              Capture your first items
            </Link>
          </div>
        )}
      </section>
      <section className="workspace-section">
        <div className="workspace-section-heading">
          <h2>Your Spaces</h2>
          <Link href="/spaces">Open Spaces</Link>
        </div>
        {spaces.map((name) => (
          <Link
            className="workspace-list-row"
            key={name}
            href={`/inventory?space=${encodeURIComponent(name)}`}
          >
            <span className="workspace-actions">
              <MapPin size={16} />
              <strong>{name}</strong>
            </span>
            <span className="workspace-muted">
              {data.items ? (groups[name]?.length ?? 0) : "…"} items
            </span>
          </Link>
        ))}
        {data.spaces?.length === 0 && (
          <Link href="/spaces" className="workspace-button">
            Create a Space
          </Link>
        )}
      </section>
    </section>
  );
}
