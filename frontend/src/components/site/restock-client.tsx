"use client";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { Plus, RefreshCw, ShoppingCart } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { itemDisplayName, type InventoryItem } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { useRestock } from "@/lib/use-restock";
import {
  recordRestockArrival,
  needsBuying,
  onOrder,
  quantityToBuy,
} from "@/lib/restock-plan";
import {
  PERSONAL_RESTOCK,
  joinedRestockScopes,
  restockItemsPath,
  stockWrite,
  type RestockScope,
} from "@/lib/restock-scope";
import { userFacingError } from "@/lib/user-facing-error";
export function RestockClient() {
  const { accountId } = useApiSession();
  return <RestockClientWorkspace key={accountId || "signed-out"} />;
}
function RestockClientWorkspace() {
  const { accountId, error: sessionError } = useApiSession(),
    restock = useRestock(accountId);
  const owner = useRef(accountId);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const loadTicket = useRef(0);
  const [scopes, setScopes] = useState<RestockScope[]>([PERSONAL_RESTOCK]),
    [scopeKey, setScopeKey] = useState("personal"),
    [scopeError, setScopeError] = useState("");
  const scope = scopes.find((s) => s.key === scopeKey) || PERSONAL_RESTOCK;
  const [items, setItems] = useState<InventoryItem[]>([]),
    [loading, setLoading] = useState(true),
    [error, setError] = useState("");
  const [tab, setTab] = useState<"buy" | "order">("buy"),
    [search, setSearch] = useState(""),
    [picker, setPicker] = useState(false),
    [busy, setBusy] = useState(false);
  const [edit, setEdit] = useState<{
      item: InventoryItem;
      action: "plan" | "threshold" | "receipt";
    } | null>(null),
    [count, setCount] = useState("1");
  const load = useCallback(async () => {
    if (!accountId) return;
    const account = accountId,
      ticket = ++loadTicket.current;
    setLoading(true);
    setItems([]);
    setError("");
    try {
      const result = await accountRequest<{ items: InventoryItem[] }>(
        account,
        restockItemsPath(scope),
        scope.kind === "personal"
          ? { method: "POST", body: { query: "" } }
          : {},
      );
      if (owner.current === account && ticket === loadTicket.current)
        setItems(result.items);
    } catch (e) {
      if (owner.current === account && ticket === loadTicket.current)
        setError(userFacingError(e, "Could not load this inventory."));
    } finally {
      if (owner.current === account && ticket === loadTicket.current)
        setLoading(false);
    }
  }, [accountId, scope]);
  useEffect(() => {
    setEdit(null);
    setPicker(false);
    void load();
  }, [load]);
  useEffect(() => {
    if (!accountId) return;
    const account = accountId;
    let active = true;
    void Promise.allSettled([
      accountRequest(account, "/sharing/joined"),
      accountRequest<{
        teams: { team_id: string; name?: string; team_name?: string }[];
      }>(account, "/teams"),
    ]).then(async ([joined, teams]) => {
      const result: RestockScope[] = [
        PERSONAL_RESTOCK,
        ...(joined.status === "fulfilled"
          ? joinedRestockScopes(joined.value)
          : []),
      ];
      let failed = joined.status === "rejected" || teams.status === "rejected";
      if (teams.status === "fulfilled") {
        const details = await Promise.allSettled(
          teams.value.teams.map(async (team) => {
            const [workspace, spaces] = await Promise.all([
              accountRequest<{ role: string }>(
                account,
                `/teams/${encodeURIComponent(team.team_id)}/workspace`,
              ),
              accountRequest<{ spaces: { id: string; name: string }[] }>(
                account,
                `/teams/${encodeURIComponent(team.team_id)}/spaces`,
              ),
            ]);
            return spaces.spaces.map((s) => ({
              key: `team:${team.team_id}:${s.id}`,
              label: `${team.name || team.team_name || "Team"} / ${s.name}`,
              kind: "team" as const,
              teamId: team.team_id,
              spaceId: s.id,
              canEdit: ["owner", "mentor", "member"].includes(workspace.role),
            }));
          }),
        );
        details.forEach((d) => {
          if (d.status === "fulfilled") result.push(...d.value);
          else failed = true;
        });
      }
      if (active && owner.current === account) {
        setScopes(result);
        setScopeError(
          failed
            ? "Some shared inventories could not load. Refresh this page to retry."
            : "",
        );
      }
    });
    return () => {
      active = false;
    };
  }, [accountId]);
  const buying = items.filter((i) =>
      needsBuying(restock.plan[i.item_id], i.quantity),
    ),
    ordered = items.filter((i) => onOrder(restock.plan[i.item_id]));
  const shown = (tab === "buy" ? buying : ordered).filter((i) =>
    `${itemDisplayName(i)} ${i.name} ${i.location}`
      .toLowerCase()
      .includes(search.toLowerCase()),
  );
  function open(item: InventoryItem, action: "plan" | "threshold" | "receipt") {
    const e = restock.plan[item.item_id] ?? {};
    setCount(
      String(
        action === "receipt"
          ? (e.receipt_total ??
              item.quantity + (e.order_quantity ?? e.buy_quantity ?? 1))
          : action === "threshold"
            ? (e.minimum ?? 0)
            : quantityToBuy(e, item.quantity),
      ),
    );
    setError("");
    setEdit({ item, action });
    setPicker(false);
  }
  async function perform(operation: () => Promise<void>) {
    setBusy(true);
    setError("");
    try {
      await operation();
    } catch (e) {
      setError(userFacingError(e, "Could not update your restock plan."));
    } finally {
      setBusy(false);
    }
  }
  async function save() {
    if (!edit || !accountId) return;
    const account = accountId,
      { item, action } = edit;
    const total = Number(count);
    if (
      !count.trim() ||
      !Number.isSafeInteger(total) ||
      total < (action === "plan" ? 1 : 0)
    ) {
      setError("Enter a whole number with a valid quantity.");
      return;
    }
    await perform(async () => {
      if (action === "receipt") {
        stockWrite(scope, item.item_id, total);
        const result = (await recordRestockArrival({
          id: item.item_id,
          total,
          read: () => restock.plan[item.item_id] ?? {},
          change: restock.change,
          write: (receipt) => {
            const mutation = stockWrite(scope, item.item_id, receipt);
            return accountRequest<{ item: InventoryItem }>(
              account,
              mutation.path,
              { method: "PATCH", body: mutation.body },
            );
          },
        })) as { item: InventoryItem };
        if (owner.current === account)
          setItems((current) =>
            current.map((i) => (i.item_id === item.item_id ? result.item : i)),
          );
      } else
        await restock.change(item.item_id, (e) =>
          action === "plan"
            ? { minimum: e.minimum, buy_quantity: total }
            : { ...e, minimum: total },
        );
      if (owner.current === account) setEdit(null);
    });
  }
  return (
    <section>
      <header className="workspace-heading">
        <div>
          <h1>Restock</h1>
          <p>Plan what to buy and confirm stock when it arrives.</p>
        </div>
        <div className="workspace-actions">
          <button
            className="workspace-button"
            onClick={() => void load()}
            disabled={busy}
          >
            <RefreshCw size={15} />
            Refresh
          </button>
          <button
            className="workspace-button primary"
            onClick={() => setPicker(true)}
            disabled={!restock.ready || busy}
          >
            <Plus size={15} />
            Add item
          </button>
        </div>
      </header>
      <p className="workspace-muted">
        Your purchase plan is saved for this account in this browser. Inventory
        counts sync with your other devices.
      </p>
      {(error || sessionError || restock.error) && (
        <div className="workspace-error" role="alert">
          {error || sessionError || restock.error}
        </div>
      )}
      <select
        className="workspace-input"
        style={{ maxWidth: 420, marginBottom: 12 }}
        aria-label="Restock inventory"
        value={scope.key}
        disabled={busy}
        onChange={(e) => {
          setScopeKey(e.target.value);
          setSearch("");
        }}
      >
        {scopes.map((s) => (
          <option key={s.key} value={s.key}>
            {s.label}
            {!s.canEdit ? " (view only)" : ""}
          </option>
        ))}
      </select>
      {scopeError && (
        <p className="workspace-error" role="alert">
          {scopeError}
        </p>
      )}
      {!scope.canEdit && (
        <p className="workspace-muted">
          You can plan purchases for this Space. An editor must record stock
          arrivals.
        </p>
      )}
      <div
        className="workspace-chips"
        role="group"
        aria-label="Purchase status"
      >
        <button
          className={tab === "buy" ? "is-active" : ""}
          onClick={() => setTab("buy")}
        >
          To buy {buying.length}
        </button>
        <button
          className={tab === "order" ? "is-active" : ""}
          onClick={() => setTab("order")}
        >
          On order {ordered.length}
        </button>
      </div>
      <input
        className="workspace-input"
        style={{ marginTop: 18, maxWidth: 440 }}
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        aria-label="Search restock items"
        placeholder="Search your plan"
      />
      {loading ? (
        <p className="workspace-muted" role="status">
          Loading inventory…
        </p>
      ) : (
        <div className="workspace-section">
          {shown.map((item) => {
            const entry = restock.plan[item.item_id] ?? {};
            return (
              <div className="workspace-list-row" key={item.item_id}>
                <span>
                  <Link
                    href={
                      scope.kind === "shared"
                        ? `/sharing/${encodeURIComponent(scope.shareId)}`
                        : scope.kind === "team"
                          ? "/teams"
                          : `/inventory?item=${encodeURIComponent(item.item_id)}`
                    }
                  >
                    <strong>{itemDisplayName(item)}</strong>
                  </Link>
                  <small>
                    {item.quantity} in stock · {item.location || "Unsorted"}
                    {entry.minimum !== undefined
                      ? ` · Minimum ${entry.minimum}`
                      : ""}
                  </small>
                  <small>
                    {onOrder(entry)
                      ? `Ordered ${entry.order_quantity ?? entry.buy_quantity ?? 1}`
                      : `Buy ${quantityToBuy(entry, item.quantity)}`}
                    {entry.receipt_total !== undefined
                      ? ` · Arrival pending confirmation: total ${entry.receipt_total}`
                      : ""}
                  </small>
                </span>
                <div className="workspace-actions">
                  {tab === "buy" ? (
                    <>
                      <button
                        className="workspace-button"
                        disabled={busy || !restock.ready}
                        onClick={() => open(item, "plan")}
                      >
                        Edit quantity
                      </button>
                      <button
                        className="workspace-button"
                        disabled={busy || !restock.ready}
                        onClick={() =>
                          void perform(() =>
                            restock.change(item.item_id, (e) => ({
                              ...e,
                              ordered: true,
                              order_quantity: quantityToBuy(e, item.quantity),
                            })),
                          )
                        }
                      >
                        Mark ordered
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        className="workspace-button primary"
                        disabled={busy || !restock.ready || !scope.canEdit}
                        onClick={() => open(item, "receipt")}
                      >
                        {entry.receipt_total !== undefined
                          ? "Retry arrival"
                          : "Record arrival"}
                      </button>
                      {entry.receipt_total === undefined && (
                        <button
                          className="workspace-button"
                          disabled={busy || !restock.ready}
                          onClick={() =>
                            void perform(() =>
                              restock.change(item.item_id, (e) => ({
                                minimum: e.minimum,
                                buy_quantity:
                                  e.order_quantity ?? e.buy_quantity ?? 1,
                              })),
                            )
                          }
                        >
                          Move to buy
                        </button>
                      )}
                    </>
                  )}
                  <button
                    className="workspace-button"
                    disabled={
                      busy ||
                      !restock.ready ||
                      entry.receipt_total !== undefined
                    }
                    onClick={() =>
                      void perform(() =>
                        restock.change(item.item_id, () => ({})),
                      )
                    }
                  >
                    Remove
                  </button>
                </div>
              </div>
            );
          })}
          {!shown.length && !error && (
            <div className="workspace-card">
              <ShoppingCart size={22} />
              <h2>
                {tab === "buy"
                  ? "Your purchase list is clear"
                  : "No items on order"}
              </h2>
              <p className="workspace-muted">
                Add an item to plan a purchase. Choose a minimum stock level to
                include it automatically.
              </p>
            </div>
          )}
        </div>
      )}
      <Dialog open={picker} onOpenChange={setPicker}>
        <DialogContent className="workspace-dialog">
          <DialogTitle>Add to Restock</DialogTitle>
          <DialogDescription>
            Choose an item from your inventory.
          </DialogDescription>
          <input
            className="workspace-input"
            aria-label="Find an item to restock"
            placeholder="Find an item"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <div style={{ maxHeight: 350, overflow: "auto" }}>
            {items
              .filter((i) =>
                `${i.name} ${i.part_number ?? ""}`
                  .toLowerCase()
                  .includes(search.toLowerCase()),
              )
              .map((i) => (
                <div
                  className="workspace-actions"
                  style={{ marginTop: 12, justifyContent: "space-between" }}
                  key={i.item_id}
                >
                  <span>{itemDisplayName(i)}</span>
                  <div>
                    <button
                      className="workspace-button"
                      onClick={() => open(i, "threshold")}
                    >
                      Set minimum
                    </button>
                    <button
                      className="workspace-button"
                      onClick={() => open(i, "plan")}
                    >
                      Plan purchase
                    </button>
                  </div>
                </div>
              ))}
          </div>
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!edit}
        onOpenChange={(open) => {
          if (!open && !busy) setEdit(null);
        }}
      >
        <DialogContent className="workspace-dialog">
          <DialogTitle>
            {edit?.action === "receipt"
              ? "Record arrival"
              : edit?.action === "threshold"
                ? "Minimum stock"
                : "Plan purchase"}
          </DialogTitle>
          <DialogDescription>
            {edit ? itemDisplayName(edit.item) : ""}
          </DialogDescription>
          <label htmlFor="restock-count">
            {edit?.action === "receipt"
              ? "Actual total now in stock"
              : edit?.action === "threshold"
                ? "Include in To buy at or below this count"
                : "Quantity to buy"}
          </label>
          <input
            id="restock-count"
            className="workspace-input"
            type="number"
            min={edit?.action === "plan" ? 1 : 0}
            step="1"
            value={count}
            disabled={
              busy ||
              (edit?.action === "receipt" &&
                restock.plan[edit.item.item_id]?.receipt_total !== undefined)
            }
            onChange={(e) => setCount(e.target.value)}
          />
          {edit?.action === "receipt" && (
            <p className="workspace-muted">
              Confirm the total including existing stock. A pending arrival
              always retries this same total.
            </p>
          )}
          {error && (
            <p className="workspace-error" role="alert">
              {error}
            </p>
          )}
          <div className="workspace-actions">
            <button
              className="workspace-button"
              disabled={busy}
              onClick={() => setEdit(null)}
            >
              Cancel
            </button>
            <button
              className="workspace-button primary"
              disabled={busy}
              onClick={() => void save()}
            >
              {busy ? "Saving…" : "Confirm"}
            </button>
          </div>
        </DialogContent>
      </Dialog>
    </section>
  );
}
