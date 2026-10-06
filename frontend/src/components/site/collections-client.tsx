"use client";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { Search, ShoppingCart, Camera } from "lucide-react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { beforeBuyMatches, type BeforeIBuyMatch } from "@/lib/before-buy";
import {
  itemDisplayName,
  itemDisplayDescription,
  type InventoryItem,
} from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";

export function CollectionsClient() {
  const { accountId } = useApiSession();
  return <CollectionsWorkspace key={accountId || "signed-out"} />;
}
function CollectionsWorkspace() {
  const { accountId, error: sessionError } = useApiSession();
  const owner = useRef(accountId);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<BeforeIBuyMatch[] | null>(null);
  const [checkedQuery, setCheckedQuery] = useState("");
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  async function check(e: React.FormEvent) {
    e.preventDefault();
    if (!accountId || !query.trim() || busy) return;
    const account = accountId,
      question = query.trim();
    setBusy(true);
    setError("");
    try {
      const [intent, inventory] = await Promise.all([
        accountRequest<{
          items: InventoryItem[];
          parsed?: Record<string, unknown>;
        }>(account, "/search_items", {
          method: "POST",
          body: { query: question },
        }),
        accountRequest<{ items: InventoryItem[] }>(account, "/search_items", {
          method: "POST",
          body: { query: "" },
        }),
      ]);
      if (owner.current !== account) return;
      setResults(beforeBuyMatches(question, inventory.items, intent.parsed));
      setCheckedQuery(question);
    } catch (e) {
      if (owner.current === account)
        setError(
          userFacingError(e, "Your inventory could not be checked. Try again."),
        );
    } finally {
      if (owner.current === account) setBusy(false);
    }
  }
  return (
    <section>
      <header className="workspace-heading">
        <div>
          <h1>Smart collections</h1>
          <p>Check what you own and plan what to buy.</p>
        </div>
      </header>
      <section className="workspace-section">
        <div className="workspace-section-heading">
          <h2>Before I buy</h2>
          <Link href="/assist?q=Do%20I%20already%20own%20this%3F">
            <Camera size={14} /> Ask with a photo
          </Link>
        </div>
        <p className="workspace-muted">
          Search your inventory before buying another one. Related matches may
          share a name, category, or location.
        </p>
        <form className="workspace-search" onSubmit={check}>
          <Search size={18} />
          <input
            aria-label="What are you thinking of buying?"
            placeholder="A USB-C hub, a drill, more batteries…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <button
            className="workspace-button primary"
            disabled={busy || !query.trim() || !accountId}
          >
            {busy ? "Checking…" : "Check"}
          </button>
        </form>
        {(error || sessionError) && (
          <div role="alert" className="workspace-error">
            {error || sessionError}
          </div>
        )}
        {results && (
          <div className="workspace-section">
            <div className="workspace-section-heading">
              <h2>Matches for {checkedQuery}</h2>
              <span className="workspace-muted">
                {results.filter((r) => r.kind === "exact").length} exact ·{" "}
                {results.filter((r) => r.kind === "similar").length} related
              </span>
            </div>
            {results.length === 0 && (
              <p className="workspace-muted">
                No match was found in your personal inventory. Try another name
                or ask with a photo.
              </p>
            )}
            {results.map(({ item, reasons, kind }) => (
              <Link
                key={item.item_id}
                className="workspace-list-row"
                href={`/inventory?item=${encodeURIComponent(item.item_id)}`}
              >
                <span>
                  <strong>{itemDisplayName(item)}</strong>
                  <small>
                    {itemDisplayDescription(item) ||
                      item.location ||
                      "Unsorted"}
                  </small>
                  <small>{[...new Set(reasons)].join(" · ")}</small>
                </span>
                <span className="workspace-actions">
                  <span className="workspace-badge">
                    {kind === "exact" ? "Exact" : "Related"}
                  </span>
                  <span>{item.quantity} owned</span>
                </span>
              </Link>
            ))}
          </div>
        )}
      </section>
      <section className="workspace-section">
        <Link className="workspace-list-row" href="/restock">
          <span>
            <strong className="workspace-actions">
              <ShoppingCart size={17} />
              Restock
            </strong>
            <small>
              Set minimum stock, plan purchases, and confirm arrivals.
            </small>
          </span>
          <span>Open →</span>
        </Link>
      </section>
    </section>
  );
}
