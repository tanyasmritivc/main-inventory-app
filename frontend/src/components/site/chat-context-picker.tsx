"use client";
import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import { type ChatSource } from "@/lib/chat-sources";
import styles from "./chat-sources.module.css";
export function ChatContextPicker({
  accountId,
  worldId,
  kind,
  onSelect,
  onClose,
}: {
  accountId: string;
  worldId: string;
  kind: "space" | "item" | "project" | "document";
  onSelect: (s: ChatSource) => void;
  onClose: () => void;
}) {
  const [inventories, setInventories] = useState<
      { inventory_id: string; name: string; workspace_name: string }[]
    >([]),
    [inventory, setInventory] = useState(""),
    [query, setQuery] = useState(""),
    [rows, setRows] = useState<ChatSource[]>([]),
    [offset, setOffset] = useState(0),
    [next, setNext] = useState<number | null>(null),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(true),
    [attempt, setAttempt] = useState(0);
  const prefix = `/worlds/${encodeURIComponent(worldId)}`;
  useEffect(() => {
    let live = true;
    void accountRequest<{ inventories: typeof inventories }>(
      accountId,
      `${prefix}/directory`,
    )
      .then((r) => {
        if (live) {
          setInventories(r.inventories);
          setInventory(r.inventories[0]?.inventory_id || "");
          if (!r.inventories.length) setLoading(false);
        }
      })
      .catch((e) => {
        if (live) {
          setError(userFacingError(e, "Could not load inventories."));
          setLoading(false);
        }
      });
    return () => {
      live = false;
    };
  }, [accountId, prefix, attempt]);
  useEffect(() => {
    if (!inventory) return;
    let live = true;
    const timer = setTimeout(() => {
      setLoading(true);
      setError("");
      void accountRequest<{
        sources: ChatSource[];
        next_offset: number | null;
      }>(
        accountId,
        `${prefix}/chat-sources?${new URLSearchParams({ inventory_id: inventory, kind, query, offset: String(offset) })}`,
      )
        .then((r) => {
          if (live) {
            setRows(r.sources);
            setNext(r.next_offset);
          }
        })
        .catch((e) => {
          if (live) setError(userFacingError(e, "Could not load context."));
        })
        .finally(() => {
          if (live) setLoading(false);
        });
    }, 200);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [accountId, prefix, kind, inventory, query, offset, attempt]);
  return (
    <Dialog
      open
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
    >
      <DialogContent className={styles.dialog}>
        <DialogTitle>
          Add{" "}
          {kind === "document"
            ? "documents and notes"
            : kind === "space"
              ? "Spaces"
              : `${kind}s`}
        </DialogTitle>
        <DialogDescription>
          Select a source for this message. Current permissions are checked
          again when you send.
        </DialogDescription>
        <div className={styles.stack}>
          <label>
            Inventory
            <select
              value={inventory}
              onChange={(e) => {
                setRows([]);
                setLoading(true);
                setInventory(e.target.value);
                setOffset(0);
              }}
            >
              {inventories.map((i) => (
                <option key={i.inventory_id} value={i.inventory_id}>
                  {i.workspace_name} / {i.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Search
            <input
              value={query}
              maxLength={100}
              onChange={(e) => {
                setRows([]);
                setLoading(true);
                setQuery(e.target.value);
                setOffset(0);
              }}
            />
          </label>
          {error && (
            <p role="alert">
              {error}{" "}
              <button onClick={() => setAttempt((v) => v + 1)}>
                Try again
              </button>
            </p>
          )}
          {loading ? (
            <p role="status">Loading sources...</p>
          ) : (
            <div className={styles.results}>
              {rows.map((s, i) => (
                <button key={i} onClick={() => onSelect(s)}>
                  {s.name}
                  <span>+</span>
                </button>
              ))}
              {!rows.length && !error && (
                <p>No sources found in this inventory.</p>
              )}
            </div>
          )}
          <div className={styles.actions}>
            {offset > 0 && (
              <button
                className="workspace-button"
                disabled={loading}
                onClick={() => {
                  setRows([]);
                  setLoading(true);
                  setOffset(Math.max(0, offset - 30));
                }}
              >
                Previous
              </button>
            )}
            {next !== null && (
              <button
                className="workspace-button"
                disabled={loading}
                onClick={() => {
                  setRows([]);
                  setLoading(true);
                  setOffset(next);
                }}
              >
                Next
              </button>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
